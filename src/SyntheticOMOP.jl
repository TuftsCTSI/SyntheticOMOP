module SyntheticOMOP

using CSV
using DataFrames
using Dates
using PrecompileTools
using YAML

include("schema.jl")
include("config.jl")
include("templates.jl")
include("generator.jl")
include("writer.jl")
include("expected.jl")

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
Returns the generated tables.
"""
function generate(config_path::String, output_dir::String = joinpath("out", splitext(basename(config_path))[1]))
    cfg = load_config(config_path)
    return if haskey(cfg, "sites")
        site_tables, linkage_df = build_all_sites(cfg)
        write_sites(site_tables, linkage_df, output_dir)
        write_expected(cfg, output_dir)
        (site_tables, linkage_df)
    else
        tables = build_all(cfg)
        write_tables(tables, output_dir)
        write_expected(cfg, output_dir)
        tables
    end
end

export build, generate, review_table

@setup_workload begin
    _pc_single = joinpath(tempdir(), "_syntheticomop_pc_single.yml")
    _pc_multi = joinpath(tempdir(), "_syntheticomop_pc_multi.yml")
    write(
        _pc_single, """
        concepts:
          c1: 1
          c2: 2
        templates:
          t1:
            gender_concept_id: [c1, c2]
            birth_year: [1980, 1990]
            conditions:
              - concept_id: c1
                date: "2023-01-01"
                end_date: "2023-06-01"
            drugs:
              - concept_id: c1
                date: "2023-01-01"
                end_date: "2023-03-01"
                days_supply: 30
                quantity: 30
                route_concept_id: c2
            procedures:
              - concept_id: c1
                date: "2023-02-01"
            devices:
              - concept_id: c1
                date: "2023-01-01"
                end_date: "2023-12-31"
            measurements:
              - concept_id: c1
                date: "2023-03-01"
                value_as_number: 120
                unit_concept_id: c2
            observations:
              - concept_id: c1
                date: "2023-01-01"
                value_as_string: "x"
            notes:
              - concept_id: c1
                date: "2023-01-01"
                title: "t"
                text: "n"
        patients:
          - person_source_value: pc1
            gender_concept_id: c1
            birth_year: 2000
            birth_month: 1
            birth_day: 1
            death:
              date: "2024-01-01"
              cause_concept_id: c1
            conditions:
              - concept_id: c1
                date: "2023-01-01"
        """
    )
    write(
        _pc_multi, """
        concepts:
          c1: 1
        sites:
          - id: s1
          - id: s2
        patients:
          - person_source_value: pc1
            appearances:
              - site: s1
                gender_concept_id: c1
                birth_year: 2000
                birth_month: 1
                birth_day: 1
                conditions:
                  - concept_id: c1
                    date: "2023-01-01"
              - site: s2
                gender_concept_id: c1
                birth_year: 2000
                birth_month: 1
                birth_day: 1
                measurements:
                  - concept_id: c1
                    date: "2023-06-01"
                    value_as_number: 99
        """
    )
    @compile_workload begin
        generate(_pc_single, mktempdir())
        generate(_pc_multi, mktempdir())
    end
    rm(_pc_single; force = true)
    rm(_pc_multi; force = true)
end

end # module SyntheticOMOP
