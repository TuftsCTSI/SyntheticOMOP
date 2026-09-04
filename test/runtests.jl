using Test
using SyntheticOMOP
using SyntheticOMOP: CSV

const VALID_DIR = joinpath(@__DIR__, "configs", "valid")
const INVALID_DIR = joinpath(@__DIR__, "configs", "invalid")
const EXPECTED_DIR = joinpath(@__DIR__, "expected")

function collect_files(dir::String)::Vector{String}
    files = String[]
    for (root, _, filenames) in walkdir(dir)
        for f in filenames
            endswith(f, ".csv") || continue
            push!(files, relpath(joinpath(root, f), dir))
        end
    end
    return sort(files)
end

function parse_expected_error(config_path::String)::String
    first_line = readline(config_path)
    m = match(r"^# expect: (.+)$", first_line)
    m === nothing && error("Invalid test config: missing '# expect:' on line 1 of $config_path")
    return m.captures[1]
end

function table_to_string(df; kwargs...)::String
    buf = IOBuffer()
    CSV.write(buf, df; missingstring = "", kwargs...)
    return String(take!(buf))
end

struct ValidResult
    name::String
    exit_code::Int
    stderr::String
    actual_files::Vector{String}
    expected_files::Vector{String}
    mismatches::Vector{String}
end

struct InvalidResult
    name::String
    exit_code::Int
    stderr::String
    expected_msg::String
end

function compare_csv!(actual_files::Vector{String}, mismatches::Vector{String}, expected_dir::String, relfile::String, df; kwargs...)
    push!(actual_files, relfile)
    expected_path = joinpath(expected_dir, relfile)
    if isfile(expected_path)
        actual_str = table_to_string(df; kwargs...)
        actual_str != read(expected_path, String) && push!(mismatches, relfile)
    end
    return
end

function run_valid_config(filename::String)
    name = splitext(filename)[1]
    config_path = joinpath(VALID_DIR, filename)
    expected_dir = joinpath(EXPECTED_DIR, name)

    if !isdir(expected_dir)
        return ValidResult(name, -1, "no expected output", [], [], [])
    end

    exit_code = 0
    err = ""
    actual_files = String[]
    mismatches = String[]
    try
        cfg = SyntheticOMOP.load_config(config_path)
        has_patients = haskey(cfg, "patients") && !isempty(get(cfg, "patients", []))
        has_templates = haskey(cfg, "templates") && !isempty(get(cfg, "templates", Dict()))
        has_clinical = has_patients || has_templates

        if has_clinical
            result = SyntheticOMOP.build(config_path)
            if result isa Tuple
                site_tables, linkage_df = result
                for site_id in sort(collect(keys(site_tables)))
                    for tname in sort(collect(keys(site_tables[site_id])))
                        relfile = joinpath("OMOP", site_id, "$tname.csv")
                        compare_csv!(actual_files, mismatches, expected_dir, relfile, site_tables[site_id][tname])
                    end
                end
                compare_csv!(actual_files, mismatches, expected_dir, joinpath("OMOP", "linkage.csv"), linkage_df)
            else
                tables = result
                for tname in sort(collect(keys(tables)))
                    relfile = joinpath("OMOP", "$tname.csv")
                    compare_csv!(actual_files, mismatches, expected_dir, relfile, tables[tname])
                end
            end
        end

        expected_df = SyntheticOMOP.build_expected(cfg)
        if !isempty(expected_df)
            compare_csv!(actual_files, mismatches, expected_dir, "expected.csv", expected_df; quotestrings = true)
        end

        if haskey(cfg, "pii")
            pii_tables, pii_linkage_df = SyntheticOMOP.build_pii(cfg)
            for site_id in sort(collect(keys(pii_tables)))
                relfile = joinpath("PII", site_id, "patients.csv")
                compare_csv!(actual_files, mismatches, expected_dir, relfile, pii_tables[site_id])
            end
            compare_csv!(actual_files, mismatches, expected_dir, joinpath("PII", "linkage.csv"), pii_linkage_df)
        end

        sort!(actual_files)
    catch e
        exit_code = 1
        err = sprint(showerror, e)
    end

    expected_files = collect_files(expected_dir)
    return ValidResult(name, exit_code, err, actual_files, expected_files, mismatches)
end

function run_invalid_config(filename::String)
    name = splitext(filename)[1]
    config_path = joinpath(INVALID_DIR, filename)
    expected_msg = parse_expected_error(config_path)
    exit_code = 0
    err = ""
    try
        SyntheticOMOP.load_config(config_path)
    catch e
        exit_code = 1
        err = sprint(showerror, e)
    end
    return InvalidResult(name, exit_code, err, expected_msg)
end

t0 = time()

valid_configs = filter(f -> endswith(f, ".yml"), readdir(VALID_DIR))
invalid_configs = filter(f -> endswith(f, ".yml"), readdir(INVALID_DIR))

t1 = time()
valid_results = [run_valid_config(f) for f in valid_configs]
t2 = time()

invalid_results = [run_invalid_config(f) for f in invalid_configs]
t3 = time()

@testset "SyntheticOMOP" begin
    @testset "Valid configs" begin
        @test !isempty(valid_configs)
        for r in valid_results
            @testset "$(r.name)" begin
                if r.exit_code == -1
                    @warn "No expected output for $(r.name); run `make update-expected`"
                    @test false
                    continue
                end
                @test r.exit_code == 0
                r.exit_code != 0 && @info r.stderr
                @test setdiff(r.actual_files, r.expected_files) == []
                @test setdiff(r.expected_files, r.actual_files) == []
                @test isempty(r.mismatches)
                for f in r.mismatches
                    @info "Mismatch: $(r.name)/$f"
                end
            end
        end
    end

    @testset "Invalid configs" begin
        @test !isempty(invalid_configs)
        for r in invalid_results
            @testset "$(r.name)" begin
                @test r.exit_code != 0
                @test contains(r.stderr, r.expected_msg)
                if !contains(r.stderr, r.expected_msg)
                    @info "Expected: $(r.expected_msg)" actual = r.stderr
                end
            end
        end
    end
end
t4 = time()

@info "Valid generation ($(length(valid_configs)) configs): $(round(t2 - t1; digits = 2))s"
@info "Invalid validation ($(length(invalid_configs)) configs): $(round(t3 - t2; digits = 2))s"
@info "Assertions: $(round(t4 - t3; digits = 2))s"
@info "Total (post-import): $(round(t4 - t0; digits = 2))s"
