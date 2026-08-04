"""
Generate OMOP CDM 5.4 CSV files from a YAML scenario config.

Usage:
    julia --project generate.jl <config.yml> [output_dir]

If output_dir is omitted, files are written to out/<config_name>/.
Table names are lower-cased (person.csv, visit_occurrence.csv, etc.).
"""

using SyntheticOMOP
using SyntheticOMOP: DEFAULT_OBSERVATION_DATE
using Dates

function _read_version()::String
    path = joinpath(@__DIR__, "Project.toml")
    isfile(path) || return "unknown"
    for line in eachline(path)
        m = match(r"^version\s*=\s*\"(.+)\"$", line)
        m !== nothing && return String(m.captures[1])
    end
    # Reached when running under Pkg.test() where Project.toml exists but
    # the version line has already been stripped by the test environment.
    return "test"
end

function write_provenance(output_dir::String, config_path::String)
    version = _read_version()
    timestamp = string(Dates.now())
    content = string(
        "SyntheticOMOP_version_used: ", version, "\n",
        "input_file_used: ", basename(config_path), "\n",
        "generated_at: ", timestamp, "\n",
        "notice: All data in this directory is synthetic. No real patient data was used. Records are not guaranteed to be coherent.\n",
    )
    return open(joinpath(output_dir, "_provenance.yml"), "w") do io
        write(io, content)
    end
end

function warn_empty_obs(output_dir::String)
    obs_path = joinpath(output_dir, "observation_period.csv")
    isfile(obs_path) || return
    first_line = true
    date_col = 0
    empty_obs = String[]
    for line in eachline(obs_path)
        if first_line
            cols = split(line, ',')
            date_col = findfirst(==("observation_period_start_date"), cols)
            first_line = false
            continue
        end
        date_col === nothing && return
        fields = split(line, ',')
        if fields[date_col] == "1970-01-01"
            push!(empty_obs, "person_id=$(fields[1])")
        end
    end
    isempty(empty_obs) && return
    n = length(empty_obs)
    names = join(empty_obs[1:min(n, 5)], ", ")
    suffix = n > 5 ? " and $(n - 5) more" : ""
    return @warn "$n patient(s) have no events; observation_period uses fallback date $DEFAULT_OBSERVATION_DATE: $names$suffix"
end

function main(args = ARGS)
    if isempty(args) || length(args) > 2
        println(stderr, "Usage: julia --project generate.jl <config.yml> [output_dir]")
        exit(1)
    end
    config_path = args[1]
    output_dir = length(args) == 2 ? args[2] : joinpath("out", splitext(basename(config_path))[1])
    return try
        SyntheticOMOP.generate(config_path, output_dir)
        warn_empty_obs(output_dir)
        write_provenance(output_dir, config_path)
    catch e
        println(stderr, sprint(showerror, e))
        exit(1)
    end
end

main()
