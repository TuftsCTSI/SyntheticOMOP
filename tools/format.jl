using Runic

FILE_LIST = [
	"generate.jl",
	"src/config.jl",
	"src/generator.jl",
	"src/schema.jl",
	"src/SyntheticOMOP.jl",
	"src/templates.jl",
	"src/writer.jl",
	"test/runtests.jl",
	"test/update_expected.jl",
	"tools/format.jl",
	]

[ Runic.format_file(FILE, inplace = true) for FILE in FILE_LIST ]

