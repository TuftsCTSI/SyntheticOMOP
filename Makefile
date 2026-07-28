.PHONY: all test deps update-expected clean

all: phx

deps:
	julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

test:
	julia --project test/runtests.jl

phx:
	julia --project generate.jl assets/phx.yml

update-expected:
	julia --project test/update_expected.jl

clean:
	rm -rf out/
	rm -rf test/expected/
