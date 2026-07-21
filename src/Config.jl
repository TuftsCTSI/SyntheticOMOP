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
    patients = get(cfg, "patients", nothing)
    patients isa Vector || throw(ConfigError("'patients' must be a non-empty list"))
    isempty(patients) && throw(ConfigError("'patients' must not be empty"))

    seen_handles = Set{String}()
    for (i, p) in enumerate(patients)
        p isa Dict || throw(ConfigError("patients[$i] must be a mapping"))
        h = get(p, "handle", nothing)
        h isa String && !isempty(h) ||
            throw(ConfigError("patients[$i] missing non-empty 'handle'"))
        h ∉ seen_handles || throw(ConfigError("Duplicate patient handle: '$h'"))
        push!(seen_handles, h)

        for (j, v) in enumerate(get(p, "visits", []))
            v isa Dict || throw(ConfigError("patients[$i].visits[$j] must be a mapping"))
            haskey(v, "start_date") ||
                throw(ConfigError("patients[$i].visits[$j] missing 'start_date'"))
        end
    end
end

end # module Config

