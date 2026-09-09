module SyntheticOMOP

using CSV
using DataFrames
using Dates
using Faker
using Random
using SHA
using YAML

include("schema.jl")
include("config.jl")
include("templates.jl")
include("generator.jl")
include("writer.jl")
include("expected.jl")
include("pii.jl")

"""
    build(config_path) -> Dict{String,DataFrame}
    build(config_path) -> (Dict{String,Dict{String,DataFrame}}, DataFrame)

Parse and generate OMOP tables in memory without writing to disk.
"""
function build(config_path::String)
    cfg = load_config(config_path)
    return if haskey(cfg, "sites")
        build_all_sites(cfg)
    else
        build_all(cfg)
    end
end

"""
    generate(config_path, [output_dir]) -> tables

Generate OMOP CDM 5.4 CSV files from a YAML scenario config.
When the config contains a `pii` section, PII CSVs are also written.
Returns the generated OMOP tables (or nothing for PII-only configs).
"""
function generate(
        config_path::String,
        output_dir::String = joinpath(
            "out",
            splitext(basename(config_path))[1]
        )
    )
    cfg = load_config(config_path)
    has_patients = haskey(cfg, "patients") && !isempty(get(cfg, "patients", []))
    has_templates = haskey(cfg, "templates") && !isempty(get(cfg, "templates", Dict()))
    has_clinical = has_patients || has_templates
    result = if has_clinical
        omop_dir = joinpath(output_dir, "OMOP")
        if haskey(cfg, "sites")
            site_tables, linkage_df = build_all_sites(cfg)
            write_sites(site_tables, linkage_df, omop_dir)
            write_expected(cfg, output_dir)
            (site_tables, linkage_df)
        else
            tables = build_all(cfg)
            write_tables(tables, omop_dir)
            write_expected(cfg, output_dir)
            tables
        end
    else
        nothing
    end
    if haskey(cfg, "pii")
        pii_tables, pii_linkage = build_pii(cfg)
        pii_dir = joinpath(output_dir, "PII")
        write_pii(pii_tables, pii_linkage, pii_dir)
        write_pii_summary(pii_tables, pii_linkage, cfg, pii_dir)
    end
    return result
end

export build, build_pii, generate

end # module SyntheticOMOP
