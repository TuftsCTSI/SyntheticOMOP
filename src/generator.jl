const TYPE_EHR = 32817
const VISIT_OUTPATIENT = 9202
const CDM_VERSION = "v5.4"
const CDM_VERSION_CONCEPT_ID = 756265
const DEFAULT_OBSERVATION_DATE = Date(1970, 1, 1)

mutable struct Counter
    n::Int
end
Counter() = Counter(0)
next!(c::Counter)::Int = (c.n += 1; c.n)

mutable struct BuildState
    counters::Dict{Symbol,Counter}
    accum::Dict{Symbol,Vector}
    concepts::Dict
    location_map::Dict{String,Int}
end

function BuildState(concepts::Dict, location_map::Dict{String,Int} = Dict{String,Int}())
    counters = Dict{Symbol,Counter}(
        :observation_period   => Counter(),
        :visit_occurrence     => Counter(),
        :condition_occurrence => Counter(),
        :drug_exposure        => Counter(),
        :procedure_occurrence => Counter(),
        :device_exposure      => Counter(),
        :measurement          => Counter(),
        :observation          => Counter(),
        :note                 => Counter(),
    )
    accum = Dict{Symbol,Vector}(
        :person               => [],
        :observation_period   => [],
        :visit_occurrence     => [],
        :condition_occurrence => [],
        :drug_exposure        => [],
        :procedure_occurrence => [],
        :device_exposure      => [],
        :measurement          => [],
        :observation          => [],
        :note                 => [],
        :death                => [],
        :location             => [],
        :concept_ancestor     => [],
    )
    BuildState(counters, accum, concepts, location_map)
end

function parse_date(s)::Date
    s isa Date && return s
    Date(s, dateformat"yyyy-mm-dd")
end

function parse_date_opt(s)::Union{Date,Missing}
    s === nothing ? missing : parse_date(s)
end

function to_df(rows::Vector, schema::Vector{Symbol})::DataFrame
    df = isempty(rows) ? DataFrame() : DataFrame(rows)
    for col in schema
        if !hasproperty(df, col)
            df[!, col] = fill(missing, nrow(df))
        end
    end
    select(df, schema)
end

function resolve(concepts::Dict, value)::Union{Int,Missing}
    value === nothing && return missing
    key = string(value)
    haskey(concepts, key) ||
        throw(ConfigError("Unknown concept alias: '$value'"))
    concepts[key]
end

function resolve_opt(concepts::Dict, node::Dict, key::String)::Union{Int,Missing}
    value = get(node, key, nothing)
    value === nothing ? missing : resolve(concepts, value)
end

function resolve_type(concepts::Dict, node::Dict)::Int
    value = get(node, "type_concept_id", nothing)
    value === nothing ? TYPE_EHR : resolve(concepts, value)
end

function _always_write_tables(cfg::Dict)::Vector{Symbol}
    raw = get(cfg, "always_write_tables", nothing)
    raw === nothing && return DEFAULT_ALWAYS_WRITE_TABLES
    [Symbol(name) for name in raw]
end

function _finalize(state::BuildState, cfg::Dict)::Dict{String,DataFrame}
    result = Dict{String,DataFrame}()
    always_write = Set(_always_write_tables(cfg))

    for (key, schema) in ROW_TABLES
        rows = get(state.accum, key, [])
        if key in always_write || !isempty(rows)
            result[string(key)] = to_df(rows, schema)
        end
    end

    src_cfg = get(cfg, "cdm_source", Dict())
    if !isempty(src_cfg)
        today = string(Dates.today())
        result["cdm_source"] = to_df([(
            cdm_source_name                = get(src_cfg, "name",                    "Synthetic OMOP Dataset"),
            cdm_source_abbreviation        = get(src_cfg, "abbreviation",            "SYNTH"),
            cdm_holder                     = get(src_cfg, "holder",                  ""),
            source_description             = get(src_cfg, "description",             ""),
            source_documentation_reference = get(src_cfg, "documentation_reference", ""),
            cdm_etl_reference              = "SyntheticOMOP/generate.jl",
            source_release_date            = today,
            cdm_release_date               = today,
            cdm_version                    = CDM_VERSION,
            cdm_version_concept_id         = CDM_VERSION_CONCEPT_ID,
            vocabulary_version             = "none (synthetic)",
        )], CDM_SOURCE)
    end

    result
end

function _birth_datetime(patient)
    y  = get(patient, "birth_year",  nothing)
    mo = get(patient, "birth_month", nothing)
    d  = get(patient, "birth_day",   nothing)
    (y === nothing || mo === nothing || d === nothing) && return missing
    DateTime(y, mo, d)
end

function build_person(patient, pid::Int, concepts::Dict, location_map::Dict{String,Int})
    loc_ref = get(patient, "location", nothing)
    loc_id = if loc_ref !== nothing
        get(location_map, string(loc_ref), missing)
    else
        missing
    end
    (
        person_id                   = pid,
        gender_concept_id           = resolve_opt(concepts, patient, "gender_concept_id"),
        year_of_birth               = get(patient, "birth_year",  missing),
        month_of_birth              = get(patient, "birth_month", missing),
        day_of_birth                = get(patient, "birth_day",   missing),
        birth_datetime              = _birth_datetime(patient),
        race_concept_id             = resolve_opt(concepts, patient, "race_concept_id"),
        ethnicity_concept_id        = resolve_opt(concepts, patient, "ethnicity_concept_id"),
        location_id                 = loc_id,
        provider_id                 = missing,
        care_site_id                = missing,
        person_source_value         = patient["person_source_value"],
        gender_source_value         = missing,
        gender_source_concept_id    = 0,
        race_source_value           = missing,
        race_source_concept_id      = 0,
        ethnicity_source_value      = missing,
        ethnicity_source_concept_id = 0,
    )
end

function build_observation_period(pid::Int, dates::Vector{Date}, obs_id::Int)
    obs_start = isempty(dates) ? DEFAULT_OBSERVATION_DATE : minimum(dates)
    obs_end   = isempty(dates) ? DEFAULT_OBSERVATION_DATE : maximum(dates)
    (
        observation_period_id         = obs_id,
        person_id                     = pid,
        observation_period_start_date = obs_start,
        observation_period_end_date   = obs_end,
        period_type_concept_id        = TYPE_EHR,
    )
end

function build_visit(pid::Int, vid::Int, v_start::Date, v_end::Date, visit_concept_id::Int)
    (
        visit_occurrence_id           = vid,
        person_id                     = pid,
        visit_concept_id              = visit_concept_id,
        visit_start_date              = v_start,
        visit_start_datetime          = missing,
        visit_end_date                = v_end,
        visit_end_datetime            = missing,
        visit_type_concept_id         = TYPE_EHR,
        provider_id                   = missing,
        care_site_id                  = missing,
        visit_source_value            = missing,
        visit_source_concept_id       = 0,
        admitted_from_concept_id      = 0,
        admitted_from_source_value    = missing,
        discharged_to_concept_id      = 0,
        discharged_to_source_value    = missing,
        preceding_visit_occurrence_id = missing,
    )
end

function build_condition(spec, pid::Int, vid::Int, concepts::Dict, ctr::Counter)
    (
        condition_occurrence_id       = next!(ctr),
        person_id                     = pid,
        condition_concept_id          = resolve(concepts, spec["concept_id"]),
        condition_start_date          = parse_date(spec["date"]),
        condition_start_datetime      = missing,
        condition_end_date            = parse_date_opt(get(spec, "end_date", nothing)),
        condition_end_datetime        = missing,
        condition_type_concept_id     = resolve_type(concepts, spec),
        condition_status_concept_id   = missing,
        stop_reason                   = missing,
        provider_id                   = missing,
        visit_occurrence_id           = vid,
        visit_detail_id               = missing,
        condition_source_value        = missing,
        condition_source_concept_id   = 0,
        condition_status_source_value = missing,
    )
end

function build_drug(spec, pid::Int, vid::Int, concepts::Dict, ctr::Counter)
    (
        drug_exposure_id             = next!(ctr),
        person_id                    = pid,
        drug_concept_id              = resolve(concepts, spec["concept_id"]),
        drug_exposure_start_date     = parse_date(spec["date"]),
        drug_exposure_start_datetime = missing,
        drug_exposure_end_date       = parse_date(get(spec, "end_date", spec["date"])),
        drug_exposure_end_datetime   = missing,
        verbatim_end_date            = missing,
        drug_type_concept_id         = resolve_type(concepts, spec),
        stop_reason                  = missing,
        refills                      = get(spec, "refills",      missing),
        quantity                     = get(spec, "quantity",     missing),
        days_supply                  = get(spec, "days_supply",  missing),
        sig                          = missing,
        route_concept_id             = resolve_opt(concepts, spec, "route_concept_id"),
        lot_number                   = get(spec, "lot_number",   missing),
        provider_id                  = missing,
        visit_occurrence_id          = vid,
        visit_detail_id              = missing,
        drug_source_value            = missing,
        drug_source_concept_id       = 0,
        route_source_value           = missing,
        dose_unit_source_value       = missing,
    )
end

function build_procedure(spec, pid::Int, vid::Int, concepts::Dict, ctr::Counter)
    (
        procedure_occurrence_id     = next!(ctr),
        person_id                   = pid,
        procedure_concept_id        = resolve(concepts, spec["concept_id"]),
        procedure_date              = parse_date(spec["date"]),
        procedure_datetime          = missing,
        procedure_end_date          = parse_date_opt(get(spec, "end_date", nothing)),
        procedure_end_datetime      = missing,
        procedure_type_concept_id   = resolve_type(concepts, spec),
        modifier_concept_id         = missing,
        quantity                    = get(spec, "quantity", missing),
        provider_id                 = missing,
        visit_occurrence_id         = vid,
        visit_detail_id             = missing,
        procedure_source_value      = missing,
        procedure_source_concept_id = 0,
        modifier_source_value       = missing,
    )
end

function build_device(spec, pid::Int, vid::Int, concepts::Dict, ctr::Counter)
    (
        device_exposure_id             = next!(ctr),
        person_id                      = pid,
        device_concept_id              = resolve(concepts, spec["concept_id"]),
        device_exposure_start_date     = parse_date(spec["date"]),
        device_exposure_start_datetime = missing,
        device_exposure_end_date       = parse_date_opt(get(spec, "end_date", nothing)),
        device_exposure_end_datetime   = missing,
        device_type_concept_id         = resolve_type(concepts, spec),
        unique_device_id               = missing,
        production_id                  = missing,
        quantity                       = get(spec, "quantity", missing),
        provider_id                    = missing,
        visit_occurrence_id            = vid,
        visit_detail_id                = missing,
        device_source_value            = missing,
        device_source_concept_id       = 0,
        unit_concept_id                = resolve_opt(concepts, spec, "unit_concept_id"),
        unit_source_value              = missing,
        unit_source_concept_id         = 0,
    )
end

function build_measurement(spec, pid::Int, vid::Int, concepts::Dict, ctr::Counter)
    (
        measurement_id                = next!(ctr),
        person_id                     = pid,
        measurement_concept_id        = resolve(concepts, spec["concept_id"]),
        measurement_date              = parse_date(spec["date"]),
        measurement_datetime          = missing,
        measurement_time              = missing,
        measurement_type_concept_id   = resolve_type(concepts, spec),
        operator_concept_id           = resolve_opt(concepts, spec, "operator_concept_id"),
        value_as_number               = get(spec, "value_as_number",   missing),
        value_as_concept_id           = resolve_opt(concepts, spec, "value_as_concept_id"),
        unit_concept_id               = resolve_opt(concepts, spec, "unit_concept_id"),
        range_low                     = get(spec, "range_low",         missing),
        range_high                    = get(spec, "range_high",        missing),
        provider_id                   = missing,
        visit_occurrence_id           = vid,
        visit_detail_id               = missing,
        measurement_source_value      = missing,
        measurement_source_concept_id = 0,
        unit_source_value             = missing,
        unit_source_concept_id        = 0,
        value_source_value            = missing,
        measurement_event_id          = missing,
        meas_event_field_concept_id   = missing,
    )
end

function build_observation_row(spec, pid::Int, vid::Int, concepts::Dict, ctr::Counter)
    (
        observation_id                = next!(ctr),
        person_id                     = pid,
        observation_concept_id        = resolve(concepts, spec["concept_id"]),
        observation_date              = parse_date(spec["date"]),
        observation_datetime          = missing,
        observation_type_concept_id   = resolve_type(concepts, spec),
        value_as_number               = get(spec, "value_as_number",    missing),
        value_as_string               = get(spec, "value_as_string",    missing),
        value_as_concept_id           = resolve_opt(concepts, spec, "value_as_concept_id"),
        qualifier_concept_id          = missing,
        unit_concept_id               = resolve_opt(concepts, spec, "unit_concept_id"),
        provider_id                   = missing,
        visit_occurrence_id           = vid,
        visit_detail_id               = missing,
        observation_source_value      = missing,
        observation_source_concept_id = 0,
        unit_source_value             = missing,
        qualifier_source_value        = missing,
        value_source_value            = missing,
        observation_event_id          = missing,
        obs_event_field_concept_id    = missing,
    )
end

function build_note(spec, pid::Int, vid::Int, concepts::Dict, ctr::Counter)
    (
        note_id                     = next!(ctr),
        person_id                   = pid,
        note_date                   = parse_date(spec["date"]),
        note_datetime               = missing,
        note_type_concept_id        = resolve_type(concepts, spec),
        note_class_concept_id       = resolve_opt(concepts, spec, "class_concept_id"),
        note_title                  = get(spec, "title",  missing),
        note_text                   = get(spec, "text",   missing),
        encoding_concept_id         = coalesce(resolve_opt(concepts, spec, "encoding_concept_id"), 0),
        language_concept_id         = coalesce(resolve_opt(concepts, spec, "language_concept_id"), 0),
        provider_id                 = missing,
        visit_occurrence_id         = vid,
        visit_detail_id             = missing,
        note_source_value           = missing,
        note_event_id               = missing,
        note_event_field_concept_id = 0,
    )
end

function build_death(spec, pid::Int, concepts::Dict)
    (
        person_id               = pid,
        death_date              = parse_date(spec["date"]),
        death_datetime          = missing,
        death_type_concept_id   = resolve_type(concepts, spec),
        cause_concept_id        = resolve_opt(concepts, spec, "cause_concept_id"),
        cause_source_value      = missing,
        cause_source_concept_id = 0,
    )
end

function build_location_row(loc::Dict, loc_id::Int)
    (
        location_id            = loc_id,
        address_1              = get(loc, "address_1", missing),
        address_2              = get(loc, "address_2", missing),
        city                   = get(loc, "city",      missing),
        state                  = get(loc, "state",     missing),
        zip                    = get(loc, "zip",       missing),
        county                 = get(loc, "county",    missing),
        location_source_value  = get(loc, "id",        missing),
        country_concept_id     = 0,
        country_source_value   = missing,
        latitude               = get(loc, "latitude",  missing),
        longitude              = get(loc, "longitude", missing),
    )
end

mutable struct VisitGroup
    date::Date
    end_date::Date
    concept_id::Int
    conditions::Vector
    drugs::Vector
    procedures::Vector
    devices::Vector
    measurements::Vector
    observations::Vector
    notes::Vector
end

function _group_events_into_visits(patient::Dict, concepts::Dict)::Vector{VisitGroup}
    groups = Dict{Date,VisitGroup}()

    for key in EVENT_KEYS
        events = get(patient, key, nothing)
        events === nothing && continue
        for spec in events
            d = parse_date(spec["date"])
            if !haskey(groups, d)
                visit_cid = resolve_opt(concepts, spec, "visit_concept_id")
                if visit_cid === missing
                    visit_cid = VISIT_OUTPATIENT
                end
                visit_end = parse_date(get(spec, "visit_end_date", spec["date"]))
                groups[d] = VisitGroup(d, visit_end, visit_cid, [], [], [], [], [], [], [])
            else
                g = groups[d]
                ve = parse_date(get(spec, "visit_end_date", spec["date"]))
                if ve > g.end_date
                    g.end_date = ve
                end
                vc = resolve_opt(concepts, spec, "visit_concept_id")
                if vc !== missing && g.concept_id == VISIT_OUTPATIENT
                    g.concept_id = vc
                end
            end
            push!(getfield(groups[d], Symbol(key)), spec)
        end
    end

    sort(collect(values(groups)); by = g -> g.date)
end

function process_patient!(state::BuildState, patient::Dict, pid::Int)
    push!(state.accum[:person], build_person(patient, pid, state.concepts, state.location_map))

    visit_groups = _group_events_into_visits(patient, state.concepts)
    all_dates = [g.date for g in visit_groups]
    append!(all_dates, [g.end_date for g in visit_groups if g.end_date != g.date])

    death_spec = get(patient, "death", nothing)
    if death_spec !== nothing
        push!(all_dates, parse_date(death_spec["date"]))
    end

    push!(state.accum[:observation_period],
        build_observation_period(pid, all_dates, next!(state.counters[:observation_period])))

    for g in visit_groups
        vid = next!(state.counters[:visit_occurrence])
        push!(state.accum[:visit_occurrence], build_visit(pid, vid, g.date, g.end_date, g.concept_id))
        for spec in g.conditions     push!(state.accum[:condition_occurrence], build_condition(spec, pid, vid, state.concepts, state.counters[:condition_occurrence]))   end
        for spec in g.drugs          push!(state.accum[:drug_exposure],        build_drug(spec, pid, vid, state.concepts, state.counters[:drug_exposure]))              end
        for spec in g.procedures     push!(state.accum[:procedure_occurrence], build_procedure(spec, pid, vid, state.concepts, state.counters[:procedure_occurrence])) end
        for spec in g.devices        push!(state.accum[:device_exposure],      build_device(spec, pid, vid, state.concepts, state.counters[:device_exposure]))          end
        for spec in g.measurements   push!(state.accum[:measurement],          build_measurement(spec, pid, vid, state.concepts, state.counters[:measurement]))        end
        for spec in g.observations   push!(state.accum[:observation],          build_observation_row(spec, pid, vid, state.concepts, state.counters[:observation]))    end
        for spec in g.notes          push!(state.accum[:note],                 build_note(spec, pid, vid, state.concepts, state.counters[:note]))                      end
    end

    death_spec !== nothing && push!(state.accum[:death], build_death(death_spec, pid, state.concepts))
end

function _process_locations!(state::BuildState, cfg::Dict)::Dict{String,Int}
    locations = get(cfg, "locations", nothing)
    locations === nothing && return Dict{String,Int}()
    location_map = Dict{String,Int}()
    for (i, loc) in enumerate(locations)
        loc_id = i
        id_key = string(loc["id"])
        location_map[id_key] = loc_id
        push!(state.accum[:location], build_location_row(loc, loc_id))
    end
    location_map
end

function _process_concept_ancestors!(state::BuildState, cfg::Dict)
    concepts = cfg["concepts"]
    for (_, cid) in concepts
        push!(state.accum[:concept_ancestor], (
            ancestor_concept_id      = cid,
            descendant_concept_id    = cid,
            min_levels_of_separation = 0,
            max_levels_of_separation = 0,
        ))
    end
    ancestors = get(cfg, "concept_ancestors", nothing)
    ancestors === nothing && return
    for entry in ancestors
        anc = resolve(concepts, entry["ancestor"])
        desc = resolve(concepts, entry["descendant"])
        push!(state.accum[:concept_ancestor], (
            ancestor_concept_id      = anc,
            descendant_concept_id    = desc,
            min_levels_of_separation = get(entry, "min_levels", 1),
            max_levels_of_separation = get(entry, "max_levels", 1),
        ))
    end
end

function build_all(cfg::Dict)::Dict{String,DataFrame}
    concepts = cfg["concepts"]
    state = BuildState(concepts)

    location_map = _process_locations!(state, cfg)
    state.location_map = location_map
    _process_concept_ancestors!(state, cfg)

    hand_crafted = get(cfg, "patients", Dict{String,Any}[])
    templated    = expand_templates(cfg)
    all_patients = vcat(hand_crafted, templated)

    for (i, patient) in enumerate(all_patients)
        process_patient!(state, patient, i)
    end
    _finalize(state, cfg)
end

function build_all_sites(cfg::Dict)::Tuple{Dict{String,Dict{String,DataFrame}},DataFrame}
    site_ids     = [string(s["id"]) for s in cfg["sites"]]
    concepts     = cfg["concepts"]
    hand_crafted = get(cfg, "patients", Dict{String,Any}[])
    templated    = expand_templates(cfg)
    all_patients = vcat(hand_crafted, templated)

    site_tables  = Dict{String,Dict{String,DataFrame}}()
    linkage_rows = []

    for site_id in site_ids
        entries = Tuple{Dict{String,Any},Int}[]
        for patient in all_patients
            appearances = get(patient, "appearances", nothing)
            if appearances === nothing
                psv = get(patient, "person_source_value", "<unknown>")
                @warn "Patient '$psv' has no appearances; skipped for site '$site_id'"
                continue
            end
            idx = findfirst(a -> string(get(a, "site", "")) == site_id, appearances)
            if idx !== nothing
                merged = merge(patient, appearances[idx])
                merged["person_source_value"] = patient["person_source_value"]
                delete!(merged, "appearances")
                push!(entries, (merged, length(entries) + 1))
            end
        end

        state = BuildState(concepts)
        _process_locations!(state, cfg)
        state.location_map = state.location_map
        _process_concept_ancestors!(state, cfg)
        for (merged, pid) in entries
            process_patient!(state, merged, pid)
            push!(linkage_rows, (
                person_source_value = merged["person_source_value"],
                site_id = site_id,
                person_id = pid,
            ))
        end
        site_tables[site_id] = _finalize(state, cfg)
    end

    linkage_df = isempty(linkage_rows) ?
        DataFrame(person_source_value = String[], site_id = String[], person_id = Int[]) :
        DataFrame(linkage_rows)
    (site_tables, linkage_df)
end
