.PHONY: test boston update-expected format review-boston

test:
	julia --project test/runtests.jl

boston:
	julia --project generate.jl assets/boston.yml

update-expected:
	julia --project test/update_expected.jl

format:
	julia --project=tools tools/format.jl

