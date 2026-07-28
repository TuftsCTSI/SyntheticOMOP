module Writer

using CSV
using DataFrames

function write_tables(tables::Dict{String,DataFrame}, output_dir::String)
    mkpath(output_dir)
    written = String[]
    for name in sort(collect(keys(tables)))
        df = tables[name]
        path = joinpath(output_dir, "$name.csv")
        CSV.write(path, df; missingstring = "")
        push!(written, name)
        println("  $name.csv  ($(nrow(df)) row$(nrow(df) == 1 ? "" : "s"))")
    end
    println("Wrote $(length(written)) table$(length(written) == 1 ? "" : "s") to $output_dir/")
end

function write_sites(
    site_tables::Dict{String,Dict{String,DataFrame}},
    linkage_df::DataFrame,
    output_dir::String,
)
    mkpath(output_dir)
    total_tables = 0
    for site_id in sort(collect(keys(site_tables)))
        println("[$site_id]")
        write_tables(site_tables[site_id], joinpath(output_dir, site_id))
        total_tables += length(site_tables[site_id])
        println()
    end
    linkage_path = joinpath(output_dir, "linkage.csv")
    CSV.write(linkage_path, linkage_df)
    println("linkage.csv  ($(nrow(linkage_df)) row$(nrow(linkage_df) == 1 ? "" : "s"))")
    println("Total: $(total_tables) table$(total_tables == 1 ? "" : "s") across $(length(site_tables)) site$(length(site_tables) == 1 ? "" : "s")")
end

end # module Writer
