module Config

using YAML

struct ConfigError <: Exception
    msg::String
end

Base.showerror(io::IO, e::ConfigError) = print(io, "ConfigError: ", e.msg)

"""Load and validate a YAML scenario config file, returning the parsed Dict."""
function load(path::String)::Dict
    isfile(path) || throw(ConfigError("File not found: $path"))
    raw = try
        YAML.load_file(path; dicttype = Dict{String,Any})
    catch e
        throw(ConfigError("YAML parse error: $(sprint(showerror, e))"))
    end
    validate(raw)
    raw
end

function validate(cfg::Dict)
    if haskey(cfg, "sites")
        _validate_multi(cfg)
    else
        _validate_single(cfg)
    end
end

function _validate_single(cfg::Dict)
    patients = get(cfg, "patients", nothing)
    patients isa Vector || throw(ConfigError("'patients' must be a non-empty list"))
    isempty(patients) && throw(ConfigError("'patients' must not be empty"))

    seen = Set{String}()
    for (i, p) in enumerate(patients)
        p isa Dict || throw(ConfigError("patients[$i] must be a mapping"))
        h = get(p, "handle", nothing)
        h isa String && !isempty(h) ||
            throw(ConfigError("patients[$i] missing non-empty 'handle'"))
        h ∉ seen || throw(ConfigError("Duplicate patient handle: '$h'"))
        push!(seen, h)
        for (j, v) in enumerate(get(p, "visits", []))
            v isa Dict || throw(ConfigError("patients[$i].visits[$j] must be a mapping"))
            haskey(v, "start_date") ||
                throw(ConfigError("patients[$i].visits[$j] missing 'start_date'"))
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

    patients = get(cfg, "patients", nothing)
    patients isa Vector || throw(ConfigError("'patients' must be a non-empty list"))
    isempty(patients) && throw(ConfigError("'patients' must not be empty"))

    seen = Set{String}()
    for (i, p) in enumerate(patients)
        p isa Dict || throw(ConfigError("patients[$i] must be a mapping"))
        h = get(p, "handle", nothing)
        h isa String && !isempty(h) ||
            throw(ConfigError("patients[$i] missing non-empty 'handle'"))
        h ∉ seen || throw(ConfigError("Duplicate patient handle: '$h'"))
        push!(seen, h)

        appearances = get(p, "appearances", nothing)
        appearances isa Vector ||
            throw(ConfigError("patients[$i] must have an 'appearances' list in multi-site mode"))

        for (j, app) in enumerate(appearances)
            app isa Dict || throw(ConfigError("patients[$i].appearances[$j] must be a mapping"))
            sid = get(app, "site", nothing)
            sid isa String && !isempty(sid) ||
                throw(ConfigError("patients[$i].appearances[$j] missing non-empty 'site'"))
            sid ∈ site_ids ||
                throw(ConfigError("patients[$i].appearances[$j] references unknown site: '$sid'"))
            for (k, v) in enumerate(get(app, "visits", []))
                v isa Dict || throw(ConfigError("patients[$i].appearances[$j].visits[$k] must be a mapping"))
                haskey(v, "start_date") ||
                    throw(ConfigError("patients[$i].appearances[$j].visits[$k] missing 'start_date'"))
            end
        end
    end
end

end # module Config

