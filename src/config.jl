struct ConfigError <: Exception
    msg::String
end

Base.showerror(io::IO, e::ConfigError) = print(io, "ConfigError: ", e.msg)

function load_config(path::String)::Dict
    isfile(path) || throw(ConfigError("File not found: $path"))
    raw = try
        YAML.load_file(path; dicttype = Dict{String, Any})
    catch e
        throw(ConfigError("YAML parse error: $(sprint(showerror, e))"))
    end
    _validate(raw)
    return raw
end

function _validate(cfg::Dict)
    has_pii = haskey(cfg, "pii")
    has_patients = haskey(cfg, "patients") && !isempty(get(cfg, "patients", []))
    has_templates = haskey(cfg, "templates") && !isempty(get(cfg, "templates", Dict()))
    has_topology = has_pii && haskey(get(cfg, "pii", Dict()), "topology")
    if !(has_pii && !has_patients && !has_templates)
        _validate_concepts(cfg)
    end
    _validate_always_write_tables(cfg)
    _validate_locations(cfg)
    _validate_concept_ancestors(cfg)
    if haskey(cfg, "sites")
        _validate_multi(cfg)
    end
    has_any_patients = has_patients || has_templates || has_topology
    has_any_patients ||
        throw(ConfigError("Config must have at least one of 'patients' or 'templates'"))
    has_patients && _validate_patients(cfg)
    has_templates && _validate_templates(cfg)
    has_pii && _validate_pii(cfg)
    return
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
    return
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
    return
end

function _validate_locations(cfg::Dict)
    locations = get(cfg, "locations", nothing)
    locations === nothing && return
    locations isa Vector || throw(ConfigError("'locations' must be a list"))
    seen = Set{String}()
    for (i, loc) in enumerate(locations)
        loc isa Dict || throw(ConfigError("locations[$i] must be a mapping"))
        id = get(loc, "id", nothing)
        id isa String && !isempty(id) ||
            throw(ConfigError("locations[$i] missing non-empty 'id'"))
        id ∉ seen || throw(ConfigError("Duplicate location id: '$id'"))
        push!(seen, id)
    end
    return
end

function _validate_concept_ancestors(cfg::Dict)
    ancestors = get(cfg, "concept_ancestors", nothing)
    ancestors === nothing && return
    ancestors isa Vector || throw(ConfigError("'concept_ancestors' must be a list"))
    concepts = cfg["concepts"]
    for (i, entry) in enumerate(ancestors)
        entry isa Dict || throw(ConfigError("concept_ancestors[$i] must be a mapping"))
        haskey(entry, "ancestor") ||
            throw(ConfigError("concept_ancestors[$i] missing 'ancestor'"))
        haskey(entry, "descendant") ||
            throw(ConfigError("concept_ancestors[$i] missing 'descendant'"))
        _validate_single_concept_ref(entry["ancestor"], "concept_ancestors[$i].ancestor", concepts)
        _validate_single_concept_ref(entry["descendant"], "concept_ancestors[$i].descendant", concepts)
    end
    return
end

function _validate_patients(cfg::Dict)
    patients = cfg["patients"]
    patients isa Vector || throw(ConfigError("'patients' must be a list"))
    concepts = cfg["concepts"]
    is_multi = haskey(cfg, "sites")
    location_ids = _location_ids(cfg)

    seen = Set{String}()
    for (i, p) in enumerate(patients)
        p isa Dict || throw(ConfigError("patients[$i] must be a mapping"))
        psv = get(p, "person_source_value", nothing)
        psv isa String && !isempty(psv) ||
            throw(ConfigError("patients[$i] missing non-empty 'person_source_value'"))
        psv ∉ seen || throw(ConfigError("Duplicate person_source_value: '$psv'"))
        push!(seen, psv)

        _validate_location_ref(p, "patients[$i]", location_ids)

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
    return
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
    return
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
    return
end

function _validate_concept_ref(value, path::String, concepts::Dict)
    return if value isa Vector
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
    return haskey(concepts, value) ||
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
    return if death !== nothing
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
    return
end

function _location_ids(cfg::Dict)::Set{String}
    locations = get(cfg, "locations", nothing)
    locations === nothing && return Set{String}()
    return Set{String}(string(loc["id"]) for loc in locations)
end

function _validate_location_ref(node::Dict, path::String, location_ids::Set{String})
    loc = get(node, "location", nothing)
    loc === nothing && return
    loc isa String || throw(ConfigError("$path.location must be a string"))
    return loc ∈ location_ids ||
        throw(ConfigError("$path.location references unknown location: '$loc'"))
end

# PII validation

const PII_VALID_FIELDS = Set(["name", "street", "city", "state", "zip", "dob"])
const PII_CORRUPTIBLE_FIELDS = Set(["name", "street", "city", "state", "zip"])
const PII_CORRUPTION_TYPES = Set(["typo", "missing", "uppercase", "lowercase"])

function _pii_gen_handle(idx::Int, total::Int)::String
    pad = max(length(string(total)), 2)
    return string("pii_", lpad(string(idx), pad, '0'))
end

function _pii_handle_sites(cfg::Dict)::Dict{String, Vector{String}}
    pii = cfg["pii"]
    site_ids = [string(s["id"]) for s in cfg["sites"]]
    handle_sites = Dict{String, Vector{String}}()

    if haskey(pii, "topology")
        topo = pii["topology"]
        n_all = get(topo, "all_sites", 0)
        pairs = get(topo, "pairs", [])
        n_ups = get(topo, "unique_per_site", 0)
        n_pairs_total = isempty(pairs) ? 0 : sum(Int(p[3]) for p in pairs)
        total = n_all + n_pairs_total + n_ups * length(site_ids)
        idx = 0
        for _ in 1:n_all
            idx += 1
            handle_sites[_pii_gen_handle(idx, total)] = copy(site_ids)
        end
        for pair in pairs
            s1, s2, k = string(pair[1]), string(pair[2]), Int(pair[3])
            for _ in 1:k
                idx += 1
                handle_sites[_pii_gen_handle(idx, total)] = [s1, s2]
            end
        end
        for sid in site_ids
            for _ in 1:n_ups
                idx += 1
                handle_sites[_pii_gen_handle(idx, total)] = [sid]
            end
        end
    end

    for p in get(cfg, "patients", [])
        h = get(p, "person_source_value", nothing)
        h === nothing && continue
        appearances = get(p, "appearances", [])
        handle_sites[string(h)] = [string(get(a, "site", "")) for a in appearances]
    end

    return handle_sites
end

function _validate_pii(cfg::Dict)
    pii = cfg["pii"]
    pii isa Dict || throw(ConfigError("'pii' must be a mapping"))

    seed = get(pii, "seed", nothing)
    seed !== nothing || throw(ConfigError("'pii.seed' is required"))
    seed isa Integer || throw(ConfigError("'pii.seed' must be a positive integer"))
    seed > 0        || throw(ConfigError("'pii.seed' must be a positive integer"))

    haskey(cfg, "sites") || throw(ConfigError("'pii' requires 'sites' to be defined"))
    site_ids = Set(string(s["id"]) for s in cfg["sites"])

    fields = get(pii, "fields", nothing)
    if fields !== nothing
        fields isa Vector || throw(ConfigError("'pii.fields' must be a list"))
        for (i, f) in enumerate(fields)
            string(f) ∈ PII_VALID_FIELDS ||
                throw(ConfigError("'pii.fields[$i]' references unknown field: '$(f)'"))
        end
    end

    if haskey(pii, "topology")
        _validate_pii_topology(pii["topology"], site_ids)
        hand_crafted_psvs = Set(
            string(p["person_source_value"])
                for p in get(cfg, "patients", [])
                if haskey(p, "person_source_value")
        )
        topo = pii["topology"]
        n_all = get(topo, "all_sites", 0)
        pairs_raw = get(topo, "pairs", [])
        n_ups = get(topo, "unique_per_site", 0)
        n_pairs_total = isempty(pairs_raw) ? 0 : sum(Int(p[3]) for p in pairs_raw)
        total = n_all + n_pairs_total + n_ups * length(cfg["sites"])
        for i in 1:total
            h = _pii_gen_handle(i, total)
            h ∈ hand_crafted_psvs &&
                throw(ConfigError("Auto-generated PII handle '$h' collides with hand-crafted person_source_value"))
        end
    end

    if haskey(pii, "corruptions")
        _validate_pii_corruptions(pii["corruptions"])
    end

    if haskey(pii, "overrides")
        _validate_pii_overrides(pii["overrides"], _pii_handle_sites(cfg))
    end

    return
end

function _validate_pii_topology(topo, site_ids::Set{String})
    topo isa Dict || throw(ConfigError("'pii.topology' must be a mapping"))

    n_all = get(topo, "all_sites", 0)
    n_all isa Integer && n_all >= 0 ||
        throw(ConfigError("'pii.topology.all_sites' must be a non-negative integer"))

    ups = get(topo, "unique_per_site", 0)
    ups isa Integer && ups >= 0 ||
        throw(ConfigError("'pii.topology.unique_per_site' must be a non-negative integer"))

    pairs = get(topo, "pairs", [])
    pairs isa Vector || throw(ConfigError("'pii.topology.pairs' must be a list"))
    seen_pairs = Set{Tuple{String, String}}()
    for (i, pair) in enumerate(pairs)
        length(pair) == 3 ||
            throw(ConfigError("'pii.topology.pairs[$i]' must have exactly three elements [site_a, site_b, count]"))
        s1, s2, k = string(pair[1]), string(pair[2]), pair[3]
        k isa Integer && k >= 0 ||
            throw(ConfigError("'pii.topology.pairs[$i]' count must be a non-negative integer"))
        s1 ∈ site_ids ||
            throw(ConfigError("'pii.topology.pairs[$i]' references unknown site: '$s1'"))
        s2 ∈ site_ids ||
            throw(ConfigError("'pii.topology.pairs[$i]' references unknown site: '$s2'"))
        s1 != s2 ||
            throw(ConfigError("'pii.topology.pairs[$i]' is a self-pair: '$s1'"))
        canonical = s1 < s2 ? (s1, s2) : (s2, s1)
        canonical ∉ seen_pairs ||
            throw(ConfigError("'pii.topology.pairs[$i]' is a duplicate pair: ('$s1', '$s2')"))
        push!(seen_pairs, canonical)
    end
    return
end

function _validate_pii_corruptions(corruptions)
    corruptions isa Dict || throw(ConfigError("'pii.corruptions' must be a mapping"))
    for (field, spec) in corruptions
        string(field) ∈ PII_CORRUPTIBLE_FIELDS ||
            throw(ConfigError("'pii.corruptions' field '$(field)' is not corruptible (dob cannot be corrupted)"))
        spec isa Dict || throw(ConfigError("'pii.corruptions.$(field)' must be a mapping"))
        ctype = get(spec, "type", nothing)
        ctype !== nothing || throw(ConfigError("'pii.corruptions.$(field).type' is required"))
        string(ctype) ∈ PII_CORRUPTION_TYPES ||
            throw(ConfigError("'pii.corruptions.$(field).type' must be one of: typo, missing, uppercase, lowercase"))
        rate = get(spec, "rate", nothing)
        rate !== nothing || throw(ConfigError("'pii.corruptions.$(field).rate' is required"))
        rate isa Number && 0.0 <= rate <= 1.0 ||
            throw(ConfigError("'pii.corruptions.$(field).rate' must be a float between 0.0 and 1.0"))
    end
    return
end

function _validate_pii_overrides(overrides, handle_sites::Dict{String, Vector{String}})
    overrides isa Vector || throw(ConfigError("'pii.overrides' must be a list"))
    for (i, entry) in enumerate(overrides)
        entry isa Dict || throw(ConfigError("'pii.overrides[$i]' must be a mapping"))
        handle = get(entry, "handle", nothing)
        handle isa String && !isempty(handle) ||
            throw(ConfigError("'pii.overrides[$i]' missing non-empty 'handle'"))
        haskey(handle_sites, handle) ||
            throw(ConfigError("'pii.overrides[$i]' references unknown handle: '$(handle)'"))
        patient_sites = Set(handle_sites[handle])
        appearances = get(entry, "appearances", nothing)
        appearances isa Vector ||
            throw(ConfigError("'pii.overrides[$i]' must have an 'appearances' list"))
        for (j, app) in enumerate(appearances)
            app isa Dict ||
                throw(ConfigError("'pii.overrides[$i].appearances[$j]' must be a mapping"))
            sid = get(app, "site", nothing)
            sid isa String && !isempty(sid) ||
                throw(ConfigError("'pii.overrides[$i].appearances[$j]' missing 'site'"))
            sid ∈ patient_sites ||
                throw(ConfigError("'pii.overrides[$i].appearances[$j]' references site '$(sid)' not assigned to patient '$(handle)'"))
            corrupt = get(app, "corrupt", nothing)
            corrupt === nothing && continue
            corrupt isa Vector ||
                throw(ConfigError("'pii.overrides[$i].appearances[$j].corrupt' must be a list"))
            for (k, c) in enumerate(corrupt)
                c isa Dict ||
                    throw(ConfigError("'pii.overrides[$i].appearances[$j].corrupt[$k]' must be a mapping"))
                cfield = get(c, "field", nothing)
                cfield isa String && !isempty(cfield) ||
                    throw(ConfigError("'pii.overrides[$i].appearances[$j].corrupt[$k]' missing 'field'"))
                string(cfield) ∈ PII_VALID_FIELDS ||
                    throw(ConfigError("'pii.overrides[$i].appearances[$j].corrupt[$k].field' references unknown PII field: '$(cfield)'"))
                ctype = get(c, "type", nothing)
                ctype isa String && !isempty(ctype) ||
                    throw(ConfigError("'pii.overrides[$i].appearances[$j].corrupt[$k]' missing 'type'"))
                string(ctype) ∈ PII_CORRUPTION_TYPES ||
                    throw(ConfigError("'pii.overrides[$i].appearances[$j].corrupt[$k].type' must be one of: typo, missing, uppercase, lowercase"))
            end
        end
    end
    return
end
