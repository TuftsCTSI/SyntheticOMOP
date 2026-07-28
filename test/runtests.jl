const ROOT = dirname(@__DIR__)

using Pkg
Pkg.activate(ROOT)

include(joinpath(ROOT, "src", "SyntheticOMOP.jl"))
using .SyntheticOMOP

using Test

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

@testset "SyntheticOMOP" begin
    @testset "Valid configs" begin
        configs = filter(f -> endswith(f, ".yml"), readdir(VALID_DIR))
        @test !isempty(configs)
        for filename in configs
            name = splitext(filename)[1]
            config_path = joinpath(VALID_DIR, filename)
            expected = joinpath(EXPECTED_DIR, name)
            @testset "$name" begin
                if !isdir(expected)
                    @warn "No expected output for $name; run `make update-golden`"
                    @test false
                    continue
                end
                mktempdir() do tmpdir
                    SyntheticOMOP.generate(config_path, tmpdir)

                    actual_files = collect_files(tmpdir)
                    expected_files = collect_files(expected)
                    @test actual_files == expected_files

                    for f in expected_files
                        actual_content = read(joinpath(tmpdir, f), String)
                        expected_content = read(joinpath(expected, f), String)
                        @test actual_content == expected_content
                    end
                end
            end
        end
    end

    @testset "Invalid configs" begin
        configs = filter(f -> endswith(f, ".yml"), readdir(INVALID_DIR))
        @test !isempty(configs)
        for filename in configs
            name = splitext(filename)[1]
            config_path = joinpath(INVALID_DIR, filename)
            expected_msg = parse_expected_error(config_path)
            @testset "$name" begin
                mktempdir() do tmpdir
                    err = try
                        SyntheticOMOP.generate(config_path, tmpdir)
                        nothing
                    catch e
                        sprint(showerror, e)
                    end
                    @test err !== nothing
                    @test contains(err, expected_msg)
                    if !contains(something(err, ""), expected_msg)
                        @info "Expected: $expected_msg" actual=err
                    end
                end
            end
        end
    end
end
