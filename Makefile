.PHONY: test boston update-expected format review-boston

test:
	julia --project test/runtests.jl

review-boston:
	julia --project -e 'using SyntheticOMOP; show(review_table("assets/boston.yml"), allrows=true, truncate=0); println()'

boston:
	julia --project generate.jl assets/boston.yml

update-expected:
	julia --project test/update_expected.jl

format:
	julia --project=tools tools/format.jl

