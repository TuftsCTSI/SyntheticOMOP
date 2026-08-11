function build_expected(cfg::Dict)::DataFrame
    patients = get(cfg, "patients", [])
    rows = NamedTuple[]
    for patient in patients
        psv = patient["person_source_value"]
        desc = get(patient, "description", "")
        expected = get(patient, "expected", nothing)
        expected === nothing && continue
        for (group, outcome) in expected
            present = get(outcome, "present", true)
            status = present ? get(outcome, "status", missing) : missing
            push!(rows, (
                person_source_value = psv,
                description = desc,
                group = string(group),
                present = present,
                status = status,
            ))
        end
    end
    return DataFrame(rows)
end

function write_expected(cfg::Dict, output_dir::String)
    df = build_expected(cfg)
    isempty(df) && return
    CSV.write(joinpath(output_dir, "expected.csv"), df; missingstring = "")
end
