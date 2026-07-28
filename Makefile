.PHONY: test update-golden

test:
	julia --project test/runtests.jl

update-golden:
	julia --project test/update_golden.jl

