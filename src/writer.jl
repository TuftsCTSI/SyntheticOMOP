function write_tables(tables::Dict{String,DataFrame}, output_dir::String)
    mkpath(output_dir)
    for name in sort(collect(keys(tables)))
        CSV.write(joinpath(output_dir, "$name.csv"), tables[name]; missingstring = "")
    end
end

function write_sites(
    site_tables::Dict{String,Dict{String,DataFrame}},
    linkage_df::DataFrame,
    output_dir::String,
)
    mkpath(output_dir)
    for site_id in sort(collect(keys(site_tables)))
        write_tables(site_tables[site_id], joinpath(output_dir, site_id))
    end
    CSV.write(joinpath(output_dir, "linkage.csv"), linkage_df)
end
