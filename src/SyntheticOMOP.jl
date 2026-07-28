module SyntheticOMOP

include("Schema.jl")
include("Config.jl")
include("Generator.jl")
include("Writer.jl")

using .Schema
using .Config
using .Generator
using .Writer

"""
Generate OMOP CDM 5.4 CSV files from a YAML scenario config.

When the config contains a top-level `sites` key, one subdirectory is written
per site and a linkage.csv manifest is written to `output_dir`. Otherwise a
single flat set of tables is written directly to `output_dir`.

If `output_dir` is omitted, defaults to `out/<config_basename>/`.
"""
function generate(config_path::String, output_dir::String = joinpath("out", splitext(basename(config_path))[1]))
    println("Config:  $config_path")
    println("Output:  $output_dir")
    println()
    cfg = Config.load(config_path)
    if haskey(cfg, "sites")
        site_tables, linkage_df = Generator.build_all_sites(cfg)
        Writer.write_sites(site_tables, linkage_df, output_dir)
    else
        tables = Generator.build_all(cfg)
        Writer.write_tables(tables, output_dir)
    end
end

export generate

end # module SyntheticOMOP

