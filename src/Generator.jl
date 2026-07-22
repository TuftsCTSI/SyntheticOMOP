module Generator

using DataFrames
using Dates

include("Schema.jl")
using .Schema

const TYPE_EHR = 32817
const CDM_VERSION = "v5.4"
const CDM_VERSION_CONCEPT_ID = 756265

const _SCHEMA_MAP = Dict(
    :person               => Schema.PERSON,
    :observation_period   => Schema.OBSERVATION_PERIOD,
    :visit_occurrence     => Schema.VISIT_OCCURRENCE,
    :condition_occurrence => Schema.CONDITION_OCCURRENCE,
    :drug_exposure        => Schema.DRUG_EXPOSURE,
    :procedure_occurrence => Schema.PROCEDURE_OCCURRENCE,
    :device_exposure      => Schema.DEVICE_EXPOSURE,
    :measurement          => Schema.MEASUREMENT,
    :observation          => Schema.OBSERVATION,
    :note                 => Schema.NOTE,
    :death                => Schema.DEATH,
)

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

mutable struct Counter
    n::Int
end
Counter() = Counter(0)
next!(c::Counter)::Int = (c.n += 1; c.n)

function parse_date(s)::Date
    Date(string(s), dateformat"yyyy-mm-dd")
end

function parse_date_opt(s)::Union{Date,Missing}
    s === nothing ? missing : parse_date(s)
end

function _birth_datetime(patient)::Union{DateTime,Missing}
    y  = get(patient, "birth_year",  nothing)
    mo = get(patient, "birth_month", nothing)
    d  = get(patient, "birth_day",   nothing)
    (y !== nothing && mo !== nothing && d !== nothing) ? DateTime(y, mo, d) : missing
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

function _fresh_counters()
    Dict(
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
end

function _fresh_accum()
    Dict{Symbol,Vector}(
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
    )
end

function _finalize(accum::Dict, src_cfg::Dict)::Dict{String,DataFrame}
    today = string(Dates.today())
    cdm_rows = [(
        cdm_source_name                = get(src_cfg, "name", "Synthetic OMOP Dataset"),
        cdm_source_abbreviation        = get(src_cfg, "abbreviation", "SYNTH"),
        cdm_holder                     = get(src_cfg, "holder", ""),
        source_description             = get(src_cfg, "description", ""),
        source_documentation_reference = get(src_cfg, "documentation_reference", ""),
        cdm_etl_reference              = "SyntheticOMOP/generate.jl",
        source_release_date            = today,
        cdm_release_date               = today,
        cdm_version                    = CDM_VERSION,
        cdm_version_concept_id         = CDM_VERSION_CONCEPT_ID,
        vocabulary_version             = "none (synthetic)",
    )]
    result = Dict{String,DataFrame}()
    result["cdm_source"] = to_df(cdm_rows, Schema.CDM_SOURCE)
    for (key, rows) in accum
        isempty(rows) && continue
        result[string(key)] = to_df(rows, _SCHEMA_MAP[key])
    end
    result
end

# ---------------------------------------------------------------------------
# Row builders
# ---------------------------------------------------------------------------

function build_person(patient, pid::Int)
    (
        person_id                   = pid,
        gender_concept_id           = get(patient, "gender_concept_id", 0),
        year_of_birth               = get(patient, "birth_year", missing),
        month_of_birth              = get(patient, "birth_month", missing),
        day_of_birth                = get(patient, "birth_day", missing),
        birth_datetime              = _birth_datetime(patient),
        race_concept_id             = get(patient, "race_concept_id", 0),
        ethnicity_concept_id        = get(patient, "ethnicity_concept_id", 0),
        location_id                 = missing,
        provider_id                 = missing,
        care_site_id                = missing,
        person_source_value         = patient["handle"],
        gender_source_value         = missing,
        gender_source_concept_id    = 0,
        race_source_value           = missing,
        race_source_concept_id      = 0,
        ethnicity_source_value      = missing,
        ethnicity_source_concept_id = 0,
    )
end

function build_observation_period(pid::Int, visit_starts::Vector{Date}, visit_ends::Vector{Date}, obs_id::Int)
    obs_start = isempty(visit_starts) ? Dates.today() : minimum(visit_starts)
    obs_end   = isempty(visit_ends)   ? Dates.today() : maximum(visit_ends)
    (
        observation_period_id         = obs_id,
        person_id                     = pid,
        observation_period_start_date = obs_start,
        observation_period_end_date   = obs_end,
        period_type_concept_id        = TYPE_EHR,
    )
end

function build_visit(v_spec, pid::Int, vid::Int, v_start::Date, v_end::Date)
    (
        visit_occurrence_id           = vid,
        person_id                     = pid,
        visit_concept_id              = get(v_spec, "visit_concept_id", 0),
        visit_start_date              = v_start,
        visit_start_datetime          = missing,
        visit_end_date                = v_end,
        visit_end_datetime            = missing,
        visit_type_concept_id         = TYPE_EHR,
        provider_id                   = missing,
        care_site_id                  = missing,
        visit_source_value            = get(v_spec, "handle", missing),
        visit_source_concept_id       = 0,
        admitted_from_concept_id      = 0,
        admitted_from_source_value    = missing,
        discharged_to_concept_id      = 0,
        discharged_to_source_value    = missing,
        preceding_visit_occurrence_id = missing,
    )
end

function build_condition(spec, pid::Int, vid::Int, v_start::Date, ctr::Counter)
    (
        condition_occurrence_id       = next!(ctr),
        person_id                     = pid,
        condition_concept_id          = get(spec, "condition_concept_id", 0),
        condition_start_date          = parse_date(get(spec, "start_date", string(v_start))),
        condition_start_datetime      = missing,
        condition_end_date            = parse_date_opt(get(spec, "end_date", nothing)),
        condition_end_datetime        = missing,
        condition_type_concept_id     = get(spec, "type_concept_id", TYPE_EHR),
        condition_status_concept_id   = 0,
        stop_reason                   = missing,
        provider_id                   = missing,
        visit_occurrence_id           = vid,
        visit_detail_id               = missing,
        condition_source_value        = missing,
        condition_source_concept_id   = 0,
        condition_status_source_value = missing,
    )
end

function build_drug(spec, pid::Int, vid::Int, v_start::Date, v_end::Date, ctr::Counter)
    (
        drug_exposure_id             = next!(ctr),
        person_id                    = pid,
        drug_concept_id              = get(spec, "drug_concept_id", 0),
        drug_exposure_start_date     = parse_date(get(spec, "start_date", string(v_start))),
        drug_exposure_start_datetime = missing,
        drug_exposure_end_date       = parse_date(get(spec, "end_date", string(v_end))),
        drug_exposure_end_datetime   = missing,
        verbatim_end_date            = missing,
        drug_type_concept_id         = get(spec, "type_concept_id", TYPE_EHR),
        stop_reason                  = missing,
        refills                      = get(spec, "refills", missing),
        quantity                     = get(spec, "quantity", missing),
        days_supply                  = get(spec, "days_supply", missing),
        sig                          = missing,
        route_concept_id             = get(spec, "route_concept_id", 0),
        lot_number                   = get(spec, "lot_number", missing),
        provider_id                  = missing,
        visit_occurrence_id          = vid,
        visit_detail_id              = missing,
        drug_source_value            = missing,
        drug_source_concept_id       = 0,
        route_source_value           = missing,
        dose_unit_source_value       = missing,
    )
end

function build_procedure(spec, pid::Int, vid::Int, v_start::Date, ctr::Counter)
    (
        procedure_occurrence_id     = next!(ctr),
        person_id                   = pid,
        procedure_concept_id        = get(spec, "procedure_concept_id", 0),
        procedure_date              = parse_date(get(spec, "date", string(v_start))),
        procedure_datetime          = missing,
        procedure_end_date          = parse_date_opt(get(spec, "end_date", nothing)),
        procedure_end_datetime      = missing,
        procedure_type_concept_id   = get(spec, "type_concept_id", TYPE_EHR),
        modifier_concept_id         = 0,
        quantity                    = get(spec, "quantity", missing),
        provider_id                 = missing,
        visit_occurrence_id         = vid,
        visit_detail_id             = missing,
        procedure_source_value      = missing,
        procedure_source_concept_id = 0,
        modifier_source_value       = missing,
    )
end

function build_device(spec, pid::Int, vid::Int, v_start::Date, ctr::Counter)
    (
        device_exposure_id             = next!(ctr),
        person_id                      = pid,
        device_concept_id              = get(spec, "device_concept_id", 0),
        device_exposure_start_date     = parse_date(get(spec, "start_date", string(v_start))),
        device_exposure_start_datetime = missing,
        device_exposure_end_date       = parse_date_opt(get(spec, "end_date", nothing)),
        device_exposure_end_datetime   = missing,
        device_type_concept_id         = get(spec, "type_concept_id", TYPE_EHR),
        unique_device_id               = missing,
        production_id                  = missing,
        quantity                       = get(spec, "quantity", missing),
        provider_id                    = missing,
        visit_occurrence_id            = vid,
        visit_detail_id                = missing,
        device_source_value            = missing,
        device_source_concept_id       = 0,
        unit_concept_id                = get(spec, "unit_concept_id", 0),
        unit_source_value              = missing,
        unit_source_concept_id         = 0,
    )
end

function build_measurement(spec, pid::Int, vid::Int, v_start::Date, ctr::Counter)
    (
        measurement_id                = next!(ctr),
        person_id                     = pid,
        measurement_concept_id        = get(spec, "measurement_concept_id", 0),
        measurement_date              = parse_date(get(spec, "date", string(v_start))),
        measurement_datetime          = missing,
        measurement_time              = missing,
        measurement_type_concept_id   = get(spec, "type_concept_id", TYPE_EHR),
        operator_concept_id           = get(spec, "operator_concept_id", 0),
        value_as_number               = get(spec, "value_as_number", missing),
        value_as_concept_id           = get(spec, "value_as_concept_id", 0),
        unit_concept_id               = get(spec, "unit_concept_id", 0),
        range_low                     = get(spec, "range_low", missing),
        range_high                    = get(spec, "range_high", missing),
        provider_id                   = missing,
        visit_occurrence_id           = vid,
        visit_detail_id               = missing,
        measurement_source_value      = missing,
        measurement_source_concept_id = 0,
        unit_source_value             = missing,
        unit_source_concept_id        = 0,
        value_source_value            = missing,
        measurement_event_id          = missing,
        meas_event_field_concept_id   = 0,
    )
end

function build_observation(spec, pid::Int, vid::Int, v_start::Date, ctr::Counter)
    (
        observation_id                = next!(ctr),
        person_id                     = pid,
        observation_concept_id        = get(spec, "observation_concept_id", 0),
        observation_date              = parse_date(get(spec, "date", string(v_start))),
        observation_datetime          = missing,
        observation_type_concept_id   = get(spec, "type_concept_id", TYPE_EHR),
        value_as_number               = get(spec, "value_as_number", missing),
        value_as_string               = get(spec, "value_as_string", missing),
        value_as_concept_id           = get(spec, "value_as_concept_id", 0),
        qualifier_concept_id          = 0,
        unit_concept_id               = get(spec, "unit_concept_id", 0),
        provider_id                   = missing,
        visit_occurrence_id           = vid,
        visit_detail_id               = missing,
        observation_source_value      = missing,
        observation_source_concept_id = 0,
        unit_source_value             = missing,
        qualifier_source_value        = missing,
        value_source_value            = missing,
        observation_event_id          = missing,
        obs_event_field_concept_id    = 0,
    )
end

function build_note(spec, pid::Int, vid::Int, v_start::Date, ctr::Counter)
    (
        note_id                     = next!(ctr),
        person_id                   = pid,
        note_date                   = parse_date(get(spec, "date", string(v_start))),
        note_datetime               = missing,
        note_type_concept_id        = get(spec, "type_concept_id", TYPE_EHR),
        note_class_concept_id       = get(spec, "class_concept_id", 0),
        note_title                  = get(spec, "title", missing),
        note_text                   = get(spec, "text", missing),
        encoding_concept_id         = 0,
        language_concept_id         = 0,
        provider_id                 = missing,
        visit_occurrence_id         = vid,
        visit_detail_id             = missing,
        note_source_value           = missing,
        note_event_id               = missing,
        note_event_field_concept_id = 0,
    )
end

function build_death(spec, pid::Int)
    (
        person_id               = pid,
        death_date              = parse_date(spec["date"]),
        death_datetime          = missing,
        death_type_concept_id   = get(spec, "type_concept_id", TYPE_EHR),
        cause_concept_id        = get(spec, "cause_concept_id", 0),
        cause_source_value      = missing,
        cause_source_concept_id = 0,
    )
end

# ---------------------------------------------------------------------------
# Core patient loop (shared by single-site and multi-site paths)
# ---------------------------------------------------------------------------

function process_patient!(accum::Dict, counters::Dict, patient::Dict, pid::Int)
    visits = get(patient, "visits", [])

    push!(accum[:person], build_person(patient, pid))

    v_starts = [parse_date(v["start_date"]) for v in visits]
    v_ends   = [parse_date(get(v, "end_date", v["start_date"])) for v in visits]
    push!(accum[:observation_period],
        build_observation_period(pid, v_starts, v_ends, next!(counters[:observation_period])))

    for v_spec in visits
        vid     = next!(counters[:visit_occurrence])
        v_start = parse_date(v_spec["start_date"])
        v_end   = parse_date(get(v_spec, "end_date", v_spec["start_date"]))
        push!(accum[:visit_occurrence], build_visit(v_spec, pid, vid, v_start, v_end))
        for spec in get(v_spec, "conditions",   []) push!(accum[:condition_occurrence], build_condition(spec,    pid, vid, v_start, counters[:condition_occurrence]))   end
        for spec in get(v_spec, "drugs",        []) push!(accum[:drug_exposure],        build_drug(spec,        pid, vid, v_start, v_end, counters[:drug_exposure]))    end
        for spec in get(v_spec, "procedures",   []) push!(accum[:procedure_occurrence], build_procedure(spec,   pid, vid, v_start, counters[:procedure_occurrence]))   end
        for spec in get(v_spec, "devices",      []) push!(accum[:device_exposure],      build_device(spec,      pid, vid, v_start, counters[:device_exposure]))      end
        for spec in get(v_spec, "measurements", []) push!(accum[:measurement],          build_measurement(spec, pid, vid, v_start, counters[:measurement]))          end
        for spec in get(v_spec, "observations", []) push!(accum[:observation],          build_observation(spec, pid, vid, v_start, counters[:observation]))          end
        for spec in get(v_spec, "notes",        []) push!(accum[:note],                 build_note(spec,        pid, vid, v_start, counters[:note]))                 end
    end

    death_spec = get(patient, "death", nothing)
    death_spec !== nothing && push!(accum[:death], build_death(death_spec, pid))
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

function build_all(cfg::Dict)::Dict{String,DataFrame}
    patients = cfg["patients"]
    counters = _fresh_counters()
    accum    = _fresh_accum()
    for (i, patient) in enumerate(patients)
        process_patient!(accum, counters, patient, i)
    end
    _finalize(accum, get(cfg, "cdm_source", Dict()))
end

function build_all_sites(cfg::Dict)::Tuple{Dict{String,Dict{String,DataFrame}},DataFrame}
    site_ids  = [string(s["id"]) for s in cfg["sites"]]
    patients  = cfg["patients"]
    src_cfg   = get(cfg, "cdm_source", Dict())

    site_tables  = Dict{String,Dict{String,DataFrame}}()
    linkage_rows = []

    for site_id in site_ids
        entries = Tuple{Dict{String,Any},Int}[]
        for patient in patients
            appearances = get(patient, "appearances", [])
            idx = findfirst(a -> string(get(a, "site", "")) == site_id, appearances)
            if idx !== nothing
                merged = merge(patient, appearances[idx])
                merged["handle"] = patient["handle"]
                push!(entries, (merged, length(entries) + 1))
            end
        end

        counters = _fresh_counters()
        accum    = _fresh_accum()
        for (merged, pid) in entries
            process_patient!(accum, counters, merged, pid)
            push!(linkage_rows, (handle = merged["handle"], site_id = site_id, person_id = pid))
        end
        site_tables[site_id] = _finalize(accum, src_cfg)
    end

    linkage_df = isempty(linkage_rows) ?
        DataFrame(handle = String[], site_id = String[], person_id = Int[]) :
        DataFrame(linkage_rows)
    (site_tables, linkage_df)
end

end # module Generator

