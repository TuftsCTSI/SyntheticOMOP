function build_expected(cfg::Dict)::DataFrame
    patients = get(cfg, "patients", [])
    rows = NamedTuple[]
    for patient in patients
        psv = patient["person_source_value"]
        desc = get(patient, "description", "")
        expected = get(patient, "expected", nothing)
        expected === nothing && continue
        for (group, year_map) in expected
            for (year, status) in year_map
                push!(rows, (
                    person_source_value = psv,
                    description = desc,
                    group = string(group),
                    year = string(year),
                    status = status isa Number ? string(Int(status)) : string(status),
                ))
            end
        end
    end
    return DataFrame(rows)
end

function write_expected(cfg::Dict, output_dir::String)
    df = build_expected(cfg)
    isempty(df) && return
    CSV.write(joinpath(output_dir, "expected.csv"), df; quotestrings = true)
end
