using Test
using SyntheticOMOP

const VALID_DIR = joinpath(@__DIR__, "configs", "valid")
const INVALID_DIR = joinpath(@__DIR__, "configs", "invalid")
const EXPECTED_DIR = joinpath(@__DIR__, "expected")

function collect_files(dir::String)::Vector{String}
    files = String[]
    for (root, _, filenames) in walkdir(dir)
        for f in filenames
            push!(files, relpath(joinpath(root, f), dir))
        end
    end
    sort(files)
end

function parse_expected_error(config_path::String)::String
    first_line = readline(config_path)
    m = match(r"^# expect: (.+)$", first_line)
    m === nothing && error("Invalid test config: missing '# expect:' on line 1 of $config_path")
    m.captures[1]
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

function run_valid_config(filename::String)
    name = splitext(filename)[1]
    config_path = joinpath(VALID_DIR, filename)
    expected_dir = joinpath(EXPECTED_DIR, name)

    if !isdir(expected_dir)
        return ValidResult(name, -1, "no expected output", [], [], [])
    end

    tmpdir = mktempdir()
    exit_code = 0
    err = ""
    try
        SyntheticOMOP.generate(config_path, tmpdir)
    catch e
        exit_code = 1
        err = sprint(showerror, e)
    end

    actual_files = collect_files(tmpdir)
    expected_files = collect_files(expected_dir)
    mismatches = String[]
    for f in expected_files
        af = joinpath(tmpdir, f)
        isfile(af) || continue
        read(af, String) != read(joinpath(expected_dir, f), String) && push!(mismatches, f)
    end
    rm(tmpdir; recursive = true, force = true)
    ValidResult(name, exit_code, err, actual_files, expected_files, mismatches)
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
    InvalidResult(name, exit_code, err, expected_msg)
end

t0 = time()

valid_configs = filter(f -> endswith(f, ".yml"), readdir(VALID_DIR))
invalid_configs = filter(f -> endswith(f, ".yml"), readdir(INVALID_DIR))

t1 = time()
valid_results = Vector{ValidResult}(undef, length(valid_configs))
Threads.@threads for i in eachindex(valid_configs)
    valid_results[i] = run_valid_config(valid_configs[i])
end
t2 = time()

invalid_results = Vector{InvalidResult}(undef, length(invalid_configs))
Threads.@threads for i in eachindex(invalid_configs)
    invalid_results[i] = run_invalid_config(invalid_configs[i])
end
t3 = time()

@testset "SyntheticOMOP" begin
    @testset "Valid configs" begin
        @test !isempty(valid_configs)
        for r in valid_results
            @testset "$(r.name)" begin
                if r.exit_code == -1
                    @warn "No expected output for $(r.name); run `make update-golden`"
                    @test false
                    continue
                end
                @test r.exit_code == 0
                r.exit_code != 0 && @info r.stderr
                @test r.actual_files == r.expected_files
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
                    @info "Expected: $(r.expected_msg)" actual=r.stderr
                end
            end
        end
    end
end
t4 = time()

@info "Valid generation ($(length(valid_configs)) configs, $(Threads.nthreads()) threads): $(round(t2 - t1; digits=2))s"
@info "Invalid validation ($(length(invalid_configs)) configs): $(round(t3 - t2; digits=2))s"
@info "Assertions: $(round(t4 - t3; digits=2))s"
@info "Total (post-import): $(round(t4 - t0; digits=2))s"
