module Writer

using CSV
using DataFrames

"""
Write all DataFrames in `tables` to `output_dir` as CSV files.
Empty DataFrames are skipped. Prints a summary line for each file written.
"""
function write_tables(tables::Dict{String,DataFrame}, output_dir::String)
    mkpath(output_dir)
    written = String[]
    for name in sort(collect(keys(tables)))
        df = tables[name]
        isempty(df) && continue
        path = joinpath(output_dir, "$(uppercase(name)).csv")
        CSV.write(path, df; missingstring = "")
        push!(written, name)
        println("  $(uppercase(name)).csv  ($(nrow(df)) row$(nrow(df) == 1 ? "" : "s"))")
    end
    println("Wrote $(length(written)) table$(length(written) == 1 ? "" : "s") to $output_dir/")
end

"""
Write one subdirectory of OMOP CSVs per site, plus a LINKAGE.csv at the top
level of `output_dir`. The linkage manifest has columns `handle`, `site_id`,
and `person_id`, and is the authoritative cross-site join key.
"""
function write_sites(
    site_tables::Dict{String,Dict{String,DataFrame}},
    linkage_df::DataFrame,
    output_dir::String,
)
    mkpath(output_dir)
    for site_id in sort(collect(keys(site_tables)))
        println("[$site_id]")
        write_tables(site_tables[site_id], joinpath(output_dir, site_id))
        println()
    end
    linkage_path = joinpath(output_dir, "LINKAGE.csv")
    CSV.write(linkage_path, linkage_df)
    println("LINKAGE.csv  ($(nrow(linkage_df)) row$(nrow(linkage_df) == 1 ? "" : "s"))")
end

end # module Writer

