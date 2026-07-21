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
    println("\nWrote $(length(written)) table$(length(written) == 1 ? "" : "s") to $output_dir/")
end

end # module Writer

