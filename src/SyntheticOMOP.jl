module SyntheticOMOP

using CSV
using DataFrames
using Dates
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

end # module SyntheticOMOP
