"""
Generate OMOP CDM 5.4 CSV files from a YAML scenario config.

Usage:
    julia --project generate.jl <config.yml> [output_dir]

If output_dir is omitted, files are written to out/omop_synth/.
Table names are lower-cased (person.csv, visit_occurrence.csv, etc.).
"""

using Pkg
Pkg.activate(@__DIR__)

include(joinpath(@__DIR__, "src", "SyntheticOMOP.jl"))
using .SyntheticOMOP

function main(args = ARGS)
    if isempty(args) || length(args) > 2
        println(stderr, "Usage: julia --project generate.jl <config.yml> [output_dir]")
        exit(1)
    end
    config_path = args[1]
    output_dir  = length(args) == 2 ? args[2] : "out/omop_synth"
    try
        SyntheticOMOP.generate(config_path, output_dir)
    catch e
        println(stderr, sprint(showerror, e))
        exit(1)
    end
end

main()
