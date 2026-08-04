.PHONY: all test deps update-expected boston format lint analyze tools-deps

all: test

deps:
	julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

test:
	julia --project test/runtests.jl

boston:
	julia --project generate.jl assets/boston.yml

update-expected:
	julia --project test/update_expected.jl

format:
	julia --project=tools tools/format.jl

