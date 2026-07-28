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

"""
    build(config_path) -> Dict{String,DataFrame}
    build(config_path) -> (Dict{String,Dict{String,DataFrame}}, DataFrame)

Parse and generate OMOP tables in memory without writing to disk.
"""
function build(config_path::String)
    cfg = load_config(config_path)
    if haskey(cfg, "sites")
        build_all_sites(cfg)
    else
        build_all(cfg)
    end
end

"""
    generate(config_path, [output_dir])

Generate OMOP CDM 5.4 CSV files from a YAML scenario config.
"""
function generate(config_path::String, output_dir::String = joinpath("out", splitext(basename(config_path))[1]))
    cfg = load_config(config_path)
    if haskey(cfg, "sites")
        site_tables, linkage_df = build_all_sites(cfg)
        write_sites(site_tables, linkage_df, output_dir)
    else
        tables = build_all(cfg)
        write_tables(tables, output_dir)
    end
end

export build, generate

@setup_workload begin
    _pc_single = joinpath(tempdir(), "_syntheticomop_pc_single.yml")
    _pc_multi = joinpath(tempdir(), "_syntheticomop_pc_multi.yml")
    write(_pc_single, """
    concepts:
      c1: 1
    patients:
      - person_source_value: pc1
        gender_concept_id: c1
        birth_year: 2000
        birth_month: 1
        birth_day: 1
        conditions:
          - concept_id: c1
            date: "2023-01-01"
    """)
    write(_pc_multi, """
    concepts:
      c1: 1
    sites:
      - id: s1
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
    """)
    @compile_workload begin
        generate(_pc_single, mktempdir())
        generate(_pc_multi, mktempdir())
    end
    rm(_pc_single; force=true)
    rm(_pc_multi; force=true)
end

end # module SyntheticOMOP

