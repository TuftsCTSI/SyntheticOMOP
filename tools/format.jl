using Runic

const ROOT = dirname(@__DIR__)

for (root, _, filenames) in walkdir(ROOT)
    startswith(root, joinpath(ROOT, ".git")) && continue
    for f in filenames
        endswith(f, ".jl") || continue
        Runic.format_file(joinpath(root, f); inplace = true)
    end
end
