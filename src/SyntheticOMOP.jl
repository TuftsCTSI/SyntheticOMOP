module SyntheticOMOP

include("Config.jl")
include("Schema.jl")
include("Generator.jl")
include("Writer.jl")

using .Config
using .Generator
using .Writer

"""
Generate OMOP CDM 5.4 CSV files from a YAML scenario config.

Writes one CSV per non-empty table to `output_dir`. Table names are
upper-cased to match the convention used by the existing DuckDB loader.
"""
function generate(config_path::String, output_dir::String = "out/omop_synth")
    println("Config:  $config_path")
    println("Output:  $output_dir")
    println()
    cfg    = Config.load(config_path)
    tables = Generator.build_all(cfg)
    Writer.write_tables(tables, output_dir)
end

export generate

end # module SyntheticOMOP

