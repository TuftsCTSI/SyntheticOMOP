using Runic

const FILE_LIST = [
    "generate.jl",
    "src/config.jl",
    "src/expected.jl",
    "src/generator.jl",
    "src/pii.jl",
    "src/schema.jl",
    "src/SyntheticOMOP.jl",
    "src/templates.jl",
    "src/writer.jl",
    "test/runtests.jl",
    "test/update_expected.jl",
    "tools/format.jl",
]

foreach(FILE_LIST) do file
    Runic.format_file(file, inplace = true)
end
