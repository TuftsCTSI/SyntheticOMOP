struct ConfigError <: Exception
    msg::String
end

Base.showerror(io::IO, e::ConfigError) = print(io, "ConfigError: ", e.msg)

function load_config(path::String)::Dict
    isfile(path) || throw(ConfigError("File not found: $path"))
    raw = try
        YAML.load_file(path; dicttype = Dict{String,Any})
    catch e
        throw(ConfigError("YAML parse error: $(sprint(showerror, e))"))
    end
    _validate(raw)
    raw
end

function _validate(cfg::Dict)
    _validate_concepts(cfg)
    _validate_always_write_tables(cfg)
    if haskey(cfg, "sites")
        _validate_multi(cfg)
    end
    has_patients  = haskey(cfg, "patients") && !isempty(get(cfg, "patients", []))
    has_templates = haskey(cfg, "templates") && !isempty(get(cfg, "templates", Dict()))
    has_patients || has_templates ||
        throw(ConfigError("Config must have at least one of 'patients' or 'templates'"))
    has_patients && _validate_patients(cfg)
    has_templates && _validate_templates(cfg)
end

function _validate_concepts(cfg::Dict)
    concepts = get(cfg, "concepts", nothing)
    concepts !== nothing || throw(ConfigError("'concepts' section is required"))
    concepts isa Dict || throw(ConfigError("'concepts' must be a mapping"))
    for (name, id) in concepts
        name isa String && !isempty(name) ||
            throw(ConfigError("Concept alias must be a non-empty string"))
        id isa Integer ||
            throw(ConfigError("Concept '$name' must map to an integer, got: $(typeof(id))"))
    end
end

function _validate_always_write_tables(cfg::Dict)
    tables = get(cfg, "always_write_tables", nothing)
    tables === nothing && return
    tables isa Vector || throw(ConfigError("'always_write_tables' must be a list"))
    for (i, name) in enumerate(tables)
        name isa String && !isempty(name) ||
            throw(ConfigError("always_write_tables[$i] must be a non-empty string"))
        haskey(TABLE_SCHEMAS, Symbol(name)) ||
            throw(ConfigError("always_write_tables[$i] references unknown table: '$name'"))
    end
end

function _validate_patients(cfg::Dict)
    patients = cfg["patients"]
    patients isa Vector || throw(ConfigError("'patients' must be a list"))
    concepts = cfg["concepts"]
    is_multi = haskey(cfg, "sites")

    seen = Set{String}()
    for (i, p) in enumerate(patients)
        p isa Dict || throw(ConfigError("patients[$i] must be a mapping"))
        psv = get(p, "person_source_value", nothing)
        psv isa String && !isempty(psv) ||
            throw(ConfigError("patients[$i] missing non-empty 'person_source_value'"))
        psv ∉ seen || throw(ConfigError("Duplicate person_source_value: '$psv'"))
        push!(seen, psv)

        if is_multi
            appearances = get(p, "appearances", nothing)
            appearances isa Vector ||
                throw(ConfigError("patients[$i] ('$psv') must have 'appearances' in multi-site mode"))
            isempty(appearances) &&
                throw(ConfigError("patients[$i] ('$psv') has empty 'appearances' list"))
            site_ids = Set(string(s["id"]) for s in cfg["sites"])
            for (j, app) in enumerate(appearances)
                app isa Dict ||
                    throw(ConfigError("patients[$i].appearances[$j] must be a mapping"))
                sid = get(app, "site", nothing)
                sid isa String && !isempty(sid) ||
                    throw(ConfigError("patients[$i].appearances[$j] missing 'site'"))
                sid ∈ site_ids ||
                    throw(ConfigError("patients[$i].appearances[$j] references unknown site: '$sid'"))
                _validate_events(app, "patients[$i].appearances[$j]", concepts)
            end
        else
            _validate_events(p, "patients[$i]", concepts)
        end
    end
end

function _validate_templates(cfg::Dict)
    templates = cfg["templates"]
    templates isa Dict || throw(ConfigError("'templates' must be a mapping"))
    concepts = cfg["concepts"]
    is_multi = haskey(cfg, "sites")
    for (name, tmpl) in templates
        name isa String && !isempty(name) ||
            throw(ConfigError("Template name must be a non-empty string"))
        tmpl isa Dict ||
            throw(ConfigError("Template '$name' must be a mapping"))
        if is_multi
            haskey(tmpl, "appearances") ||
                throw(ConfigError("Template '$name' must have 'appearances' in multi-site mode"))
            appearances = tmpl["appearances"]
            appearances isa Vector ||
                throw(ConfigError("Template '$name'.appearances must be a list"))
            isempty(appearances) &&
                throw(ConfigError("Template '$name' has empty 'appearances' list"))
            site_ids = Set(string(s["id"]) for s in cfg["sites"])
            for (j, app) in enumerate(appearances)
                app isa Dict ||
                    throw(ConfigError("Template '$name'.appearances[$j] must be a mapping"))
                sid = get(app, "site", nothing)
                sid isa String && !isempty(sid) ||
                    throw(ConfigError("Template '$name'.appearances[$j] missing 'site'"))
                sid ∈ site_ids ||
                    throw(ConfigError("Template '$name'.appearances[$j] references unknown site: '$sid'"))
            end
        end
        _validate_template_concepts(tmpl, "templates.$name", concepts)
    end
end

function _validate_template_concepts(node::Dict, path::String, concepts::Dict)
    for (key, value) in node
        if value isa Vector && !isempty(value) && value[1] isa Dict
            for (i, event) in enumerate(value)
                event isa Dict ||
                    throw(ConfigError("$path.$key[$i] must be a mapping"))
                _validate_template_concepts(event, "$path.$key[$i]", concepts)
            end
        elseif endswith(key, "_concept_id") || key == "concept_id"
            _validate_concept_ref(value, "$path.$key", concepts)
        end
    end
end

function _validate_concept_ref(value, path::String, concepts::Dict)
    if value isa Vector
        for (i, v) in enumerate(value)
            _validate_single_concept_ref(v, "$path[$i]", concepts)
        end
    else
        _validate_single_concept_ref(value, path, concepts)
    end
end

function _validate_single_concept_ref(value, path::String, concepts::Dict)
    value isa Integer &&
        throw(ConfigError("$path: raw integers not allowed; use a concept alias"))
    value isa String || throw(ConfigError("$path must be a string alias"))
    haskey(concepts, value) ||
        throw(ConfigError("$path references unknown concept: '$value'"))
end

function _validate_events(node::Dict, path::String, concepts::Dict)
    for (k, v) in node
        if endswith(k, "_concept_id")
            _validate_single_concept_ref(v, "$path.$k", concepts)
        end
    end

    for key in EVENT_KEYS
        events = get(node, key, nothing)
        events === nothing && continue
        events isa Vector || throw(ConfigError("$path.$key must be a list"))
        for (i, event) in enumerate(events)
            event isa Dict ||
                throw(ConfigError("$path.$key[$i] must be a mapping"))
            haskey(event, "concept_id") ||
                throw(ConfigError("$path.$key[$i] missing 'concept_id'"))
            _validate_single_concept_ref(event["concept_id"], "$path.$key[$i].concept_id", concepts)
            haskey(event, "date") ||
                throw(ConfigError("$path.$key[$i] missing 'date'"))
            for (k, v) in event
                if endswith(k, "_concept_id")
                    _validate_single_concept_ref(v, "$path.$key[$i].$k", concepts)
                end
            end
        end
    end
    death = get(node, "death", nothing)
    if death !== nothing
        death isa Dict || throw(ConfigError("$path.death must be a mapping"))
        haskey(death, "date") || throw(ConfigError("$path.death missing 'date'"))
        for (k, v) in death
            if endswith(k, "_concept_id")
                _validate_single_concept_ref(v, "$path.death.$k", concepts)
            end
        end
    end
end

function _validate_multi(cfg::Dict)
    sites = cfg["sites"]
    sites isa Vector || throw(ConfigError("'sites' must be a list"))
    isempty(sites) && throw(ConfigError("'sites' must not be empty"))
    site_ids = Set{String}()
    for (i, s) in enumerate(sites)
        s isa Dict || throw(ConfigError("sites[$i] must be a mapping"))
        id = get(s, "id", nothing)
        id isa String && !isempty(id) ||
            throw(ConfigError("sites[$i] missing non-empty 'id'"))
        id ∉ site_ids || throw(ConfigError("Duplicate site id: '$id'"))
        push!(site_ids, id)
    end
end

