struct Axis
    path::Vector{Any}
    values::Vector{Any}
end

function _find_axes(node, path::Vector{Any} = Any[])::Vector{Axis}
    axes = Axis[]
    if node isa Dict
        for (key, value) in node
            if value isa Vector && !isempty(value) && value[1] isa Dict
                for (i, event) in enumerate(value)
                    append!(axes, _find_axes(event, Any[path..., key, i]))
                end
            elseif value isa Vector && !isempty(value) && !(value[1] isa Dict)
                push!(axes, Axis(Any[path..., key], value))
            elseif value isa Dict
                append!(axes, _find_axes(value, Any[path..., key]))
            end
        end
    end
    axes
end

function _get_at_path(node, path::Vector{Any})
    for key in path
        node = node[key]
    end
    node
end

function _set_at_path!(node, path::Vector{Any}, value)
    for key in path[1:end-1]
        node = node[key]
    end
    node[path[end]] = value
end

function _deepcopy_template(tmpl::Dict)::Dict{String,Any}
    result = Dict{String,Any}()
    for (k, v) in tmpl
        if v isa Dict
            result[k] = _deepcopy_template(v)
        elseif v isa Vector
            result[k] = [item isa Dict ? _deepcopy_template(item) : item for item in v]
        else
            result[k] = v
        end
    end
    result
end

function expand_templates(cfg::Dict)::Vector{Dict{String,Any}}
    templates = get(cfg, "templates", nothing)
    templates === nothing && return Dict{String,Any}[]
    patients = Dict{String,Any}[]

    for (name, tmpl) in templates
        axes = _find_axes(tmpl)
        if isempty(axes)
            patient = _deepcopy_template(tmpl)
            if !haskey(patient, "person_source_value")
                patient["person_source_value"] = "$(name)_1"
            end
            push!(patients, patient)
            continue
        end

        ranges = [1:length(ax.values) for ax in axes]
        idx = 0
        for combo in Iterators.product(ranges...)
            idx += 1
            patient = _deepcopy_template(tmpl)
            for (ax, val_idx) in zip(axes, combo)
                _set_at_path!(patient, ax.path, ax.values[val_idx])
            end
            if !haskey(patient, "person_source_value")
                patient["person_source_value"] = "$(name)_$idx"
            elseif patient["person_source_value"] isa Vector
                error("Template '$name': person_source_value must not remain a list after expansion")
            end
            push!(patients, patient)
        end
    end

    patients
end

