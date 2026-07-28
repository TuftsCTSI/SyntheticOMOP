.PHONY: all test deps update-expected clean

all: test

deps:
	julia --project --threads=auto -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

test:
	julia --project --threads=auto test/runtests.jl

update-expected:
	julia --project test/update_expected.jl

clean:
	rm -rf out/
	rm -rf test/expected/
