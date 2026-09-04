const DEFAULT_PII_FIELDS = ["name", "street", "city", "state", "zip", "dob"]
const PII_FIELD_SPEC = Dict(
    "name" => :name,
    "street" => :street,
    "city" => :city,
    "state" => :state,
    "zip" => :zip,
    "dob" => :dob,
)

struct PIIConfigError <: Exception
    msg::String
end
Base.showerror(io::IO, e::PIIConfigError) = print(io, "PIIConfigError: ", e.msg)

function _corruption_rng(pii_cfg::Dict, handle::String, site_id::String, field::String)::Random.MersenneTwister
    seed = pii_cfg["seed"]
    hbytes = SHA.sha256(string(seed) * ":corrupt:" * handle * ":" * site_id * ":" * field)[1:8]
    return Random.MersenneTwister(reinterpret(UInt64, hbytes)[1])
end

function _apply_typo(s::String, rng::AbstractRNG)::String
    isempty(s) && return s
    chars = collect(s)
    pos = rand(rng, 1:length(chars))
    op = rand(rng, 1:3)
    if op == 1 && length(chars) > 1
        deleteat!(chars, pos)
    elseif op == 2
        chars[pos] = Char(rand(rng, 'a':'z'))
    elseif op == 3 && pos < length(chars)
        chars[pos], chars[pos + 1] = chars[pos + 1], chars[pos]
    else
        chars[pos] = Char(rand(rng, 'a':'z'))
    end
    return String(chars)
end

function _corrupt(value, ctype::String, rng::AbstractRNG)
    ctype == "missing" && return ""
    ctype == "uppercase" && return uppercase(string(value))
    ctype == "lowercase" && return lowercase(string(value))
    ctype == "typo" && return _apply_typo(string(value), rng)
    return value
end

function _build_override_map(overrides, handle::String, site_id::String)::Dict{String, String}
    result = Dict{String, String}()
    overrides === nothing && return result
    for entry in overrides
        string(get(entry, "handle", "")) == handle || continue
        for app in get(entry, "appearances", [])
            string(get(app, "site", "")) == site_id || continue
            for c in get(app, "corrupt", [])
                result[string(c["field"])] = string(c["type"])
            end
        end
    end
    return result
end

function apply_corruptions!(pii_data::Dict, pii_cfg::Dict, handle::String, site_id::String)
    corruptions = get(pii_cfg, "corruptions", nothing)
    overrides = get(pii_cfg, "overrides", nothing)
    (corruptions === nothing && overrides === nothing) && return pii_data

    override_map = _build_override_map(overrides, handle, site_id)

    for field_sym in collect(keys(pii_data))
        field_str = string(field_sym)
        field_str ∈ PII_CORRUPTIBLE_FIELDS || continue

        rng = _corruption_rng(pii_cfg, handle, site_id, field_str)

        if haskey(override_map, field_str)
            pii_data[field_sym] = _corrupt(pii_data[field_sym], override_map[field_str], rng)
        elseif corruptions !== nothing && haskey(corruptions, field_str)
            spec = corruptions[field_str]
            if rand(rng) < spec["rate"]
                pii_data[field_sym] = _corrupt(pii_data[field_sym], string(spec["type"]), rng)
            end
        end
    end
    return pii_data
end

function build_pii(cfg::Dict)
    pii_cfg = get(cfg, "pii", nothing)
    pii_cfg !== nothing || throw(PIIConfigError("Missing 'pii' section in config"))

    sites = get(cfg, "sites", nothing)
    sites !== nothing || throw(PIIConfigError("Missing 'sites' for PII generation"))
    site_ids = [string(s["id"]) for s in sites]

    fields = get(pii_cfg, "fields", nothing)
    if fields === nothing
        fields = DEFAULT_PII_FIELDS
    end
    fields = [string(f) for f in fields]
    for f in fields
        haskey(PII_FIELD_SPEC, f) || throw(PIIConfigError("PII field '$f' is not recognized"))
    end

    patients = get(cfg, "patients", [])
    if haskey(pii_cfg, "topology")
        topo_patients = expand_topology(pii_cfg["topology"], site_ids)
        patients = vcat(topo_patients, patients)
    end

    handles = Set{String}()
    for p in patients
        h = get(p, "person_source_value", nothing)
        h === nothing && continue
        h ∉ handles || throw(PIIConfigError("Duplicate patient handle for PII: '$h'"))
        push!(handles, h)
    end

    site_tables = Dict{String, DataFrame}()
    linkage_rows = []
    for site_id in site_ids
        rows = NamedTuple[]
        for patient in patients
            appearances = get(patient, "appearances", [])
            for app in appearances
                if string(get(app, "site", "")) != site_id
                    continue
                end
                handle = patient["person_source_value"]
                seed = per_patient_seed(pii_cfg, handle)
                pii_data = gen_pii_fields(seed)
                apply_corruptions!(pii_data, pii_cfg, handle, site_id)
                row = build_pii_row(length(rows) + 1, site_id, fields, pii_data)
                push!(rows, row)
                push!(linkage_rows, (person_source_value = handle, site_id = site_id, row_id = length(rows)))
            end
        end
        site_tables[site_id] = DataFrame(rows)
    end
    linkage_df = DataFrame(linkage_rows)
    return (site_tables, linkage_df)
end

function per_patient_seed(pii_cfg, handle::String)
    seed = get(pii_cfg, "seed", nothing)
    seed !== nothing || throw(PIIConfigError("'pii.seed' not specified"))
    hbytes = SHA.sha256(string(seed) * ":" * handle)[1:8]
    return reinterpret(UInt64, hbytes)[1]
end

function gen_pii_fields(seed::UInt64)
    Random.seed!(seed)
    fname = Faker.first_name()
    lname = Faker.last_name()
    streetnum = rand(1:9999)
    street = string(streetnum, " ", Faker.street_name())
    city = Faker.city()
    state = Faker.state_abbr()
    zip = lpad(string(rand(0:99999)), 5, '0')
    dob = gen_dob()
    return Dict(
        :name => string(fname, " ", lname),
        :street => street,
        :city => city,
        :state => state,
        :zip => zip,
        :dob => dob,
    )
end

function gen_dob()
    y = rand(1926:2025)
    m = rand(1:12)
    d = rand(1:28)
    return Dates.Date(y, m, d)
end

function build_pii_row(row_id, site_id, fields, pii_data)
    out = Dict{Symbol, Any}()
    out[:row_id] = row_id
    out[:source] = site_id
    for f in fields
        out[PII_FIELD_SPEC[f]] = pii_data[PII_FIELD_SPEC[f]]
    end
    return (; out...)
end

function expand_topology(topo, site_ids)
    patients = Dict[]
    count = 0
    n_all = get(topo, "all_sites", 0)
    pairs = get(topo, "pairs", [])
    ups = get(topo, "unique_per_site", 0)
    pair_total = isempty(pairs) ? 0 : sum(Int(pair[3]) for pair in pairs)
    total = n_all + pair_total + ups * length(site_ids)

    for _ in 1:n_all
        count += 1
        handle = gen_handle(count, total)
        appearances = [Dict("site" => s) for s in site_ids]
        push!(patients, Dict("person_source_value" => handle, "appearances" => appearances))
    end

    for pair in pairs
        s1, s2, k = string(pair[1]), string(pair[2]), Int(pair[3])
        for _ in 1:k
            count += 1
            handle = gen_handle(count, total)
            appearances = [Dict("site" => s1), Dict("site" => s2)]
            push!(patients, Dict("person_source_value" => handle, "appearances" => appearances))
        end
    end

    for sid in site_ids
        for _ in 1:ups
            count += 1
            handle = gen_handle(count, total)
            appearances = [Dict("site" => sid)]
            push!(patients, Dict("person_source_value" => handle, "appearances" => appearances))
        end
    end
    return patients
end

function gen_handle(idx, total)
    pad = max(length(string(total)), 2)
    return string("pii_", lpad(string(idx), pad, '0'))
end

function write_pii(pii_tables::Dict{String, DataFrame}, pii_linkage::DataFrame, pii_dir::String)
    mkpath(pii_dir)
    for site_id in sort(collect(keys(pii_tables)))
        site_dir = joinpath(pii_dir, site_id)
        mkpath(site_dir)
        CSV.write(joinpath(site_dir, "patients.csv"), pii_tables[site_id]; missingstring = "")
    end
    CSV.write(joinpath(pii_dir, "linkage.csv"), pii_linkage; missingstring = "")
    return
end

function write_pii_summary(pii_tables::Dict{String, DataFrame}, pii_linkage::DataFrame, cfg::Dict, pii_dir::String)
    site_ids = sort(collect(keys(pii_tables)))
    patient_sites = Dict{String, Set{String}}()
    for row in eachrow(pii_linkage)
        psv = row.person_source_value
        if !haskey(patient_sites, psv)
            patient_sites[psv] = Set{String}()
        end
        push!(patient_sites[psv], row.site_id)
    end
    total_patients = length(patient_sites)

    open(joinpath(pii_dir, "summary.txt"), "w") do io
        println(io, "Total patients: $total_patients")
        println(io, "")
        println(io, "Per-site record counts:")
        for sid in site_ids
            println(io, "  $sid: $(nrow(pii_tables[sid]))")
        end
        println(io, "")
        println(io, "Overlap statistics:")
        all_count = count(v -> length(v) == length(site_ids), values(patient_sites))
        println(io, "  All $(length(site_ids)) sites: $all_count")
        for i in 1:length(site_ids)
            for j in (i + 1):length(site_ids)
                s1, s2 = site_ids[i], site_ids[j]
                n = count(v -> s1 ∈ v && s2 ∈ v, values(patient_sites))
                println(io, "  $s1 + $s2: $n")
            end
        end
        for sid in site_ids
            n = count(v -> v == Set([sid]), values(patient_sites))
            println(io, "  $sid only: $n")
        end
    end
    return
end
