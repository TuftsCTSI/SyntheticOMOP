const ROOT = dirname(@__DIR__)

using Pkg
Pkg.activate(ROOT)

include(joinpath(ROOT, "src", "SyntheticOMOP.jl"))
using .SyntheticOMOP

const VALID_DIR = joinpath(@__DIR__, "configs", "valid")
const EXPECTED_DIR = joinpath(@__DIR__, "expected")

mkpath(EXPECTED_DIR)

for filename in readdir(VALID_DIR)
    endswith(filename, ".yml") || continue
    name = splitext(filename)[1]
    config_path = joinpath(VALID_DIR, filename)
    expected = joinpath(EXPECTED_DIR, name)
    rm(expected; recursive=true, force=true)
    println("Generating: $name...")
    SyntheticOMOP.generate(config_path, expected)
end

println("Expected output files updated in $EXPECTED_DIR")
