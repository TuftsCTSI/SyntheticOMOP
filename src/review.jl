"""
    review_table(config_path) -> DataFrame

Extract test metadata from a YAML config file into a flat DataFrame.
Each row represents one patient x test_suite combination.

Columns:
- `patient_source`: the person_source_value
- `test_status`: An indicator column (e.g., new vs. pre-existing)
- `test_suite`: the test_suite code (one row per suite when listed)
- `test_description`: text describing the patient scenario motivating the test
"""
function review_table(config_path::String)::DataFrame
    cfg = YAML.load_file(config_path; dicttype = Dict{String,Any})
    patients = get(cfg, "patients", Dict{String,Any}[])
    rows = NamedTuple{(:patient_source, :test_status, :test_suite, :test_description),Tuple{String,String,String,String}}[]
    for p in patients
        psv = get(p, "person_source_value", "")
        status = string(get(p, "test_status", ""))
        suite = get(p, "test_suite", "")
        desc = get(p, "test_description", "")
        suites = suite isa Vector ? string.(suite) : [string(suite)]
        for s in suites
            push!(rows, (patient_source = psv, test_status = status, test_suite = s, test_description = desc))
        end
    end
    return DataFrame(rows)
end
