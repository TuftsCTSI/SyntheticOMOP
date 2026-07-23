module Generator

using DataFrames
using Dates

include("Schema.jl")
using .Schema

const TYPE_EHR = 32817
const CDM_VERSION = "v5.4"
const CDM_VERSION_CONCEPT_ID = 756265
const DEFAULT_OBSERVATION_DATE = Date(1970, 1, 1)

const _KNOWN_CONCEPTS = Dict{Int,Any}(
    0          => (name="No matching concept",                           domain="Metadata",      vocabulary="None",          class="Undefined"),
    8507       => (name="MALE",                                          domain="Gender",        vocabulary="Gender",        class="Gender"),
    8532       => (name="FEMALE",                                        domain="Gender",        vocabulary="Gender",        class="Gender"),
    8527       => (name="White",                                         domain="Race",          vocabulary="Race",          class="Race"),
    8516       => (name="Black or African American",                     domain="Race",          vocabulary="Race",          class="Race"),
    8515       => (name="Asian",                                         domain="Race",          vocabulary="Race",          class="Race"),
    38003563   => (name="Hispanic or Latino",                            domain="Ethnicity",     vocabulary="Ethnicity",     class="Ethnicity"),
    38003564   => (name="Not Hispanic or Latino",                        domain="Ethnicity",     vocabulary="Ethnicity",     class="Ethnicity"),
    9201       => (name="Inpatient Visit",                               domain="Visit",         vocabulary="Visit",         class="Visit"),
    9202       => (name="Outpatient Visit",                              domain="Visit",         vocabulary="Visit",         class="Visit"),
    581477     => (name="Outpatient Visit - Telehealth",                 domain="Visit",         vocabulary="Visit",         class="Visit"),
    32817      => (name="EHR",                                           domain="Type Concept",  vocabulary="Type Concept",  class="Type Concept"),
    320128     => (name="Essential hypertension",                        domain="Condition",     vocabulary="SNOMED",        class="Clinical Finding"),
    201826     => (name="Type 2 diabetes mellitus",                      domain="Condition",     vocabulary="SNOMED",        class="Clinical Finding"),
    3004249    => (name="Systolic blood pressure",                       domain="Measurement",   vocabulary="LOINC",         class="Clinical Observation"),
    3012888    => (name="Diastolic blood pressure",                      domain="Measurement",   vocabulary="LOINC",         class="Clinical Observation"),
    3004501    => (name="Hemoglobin A1c/Hemoglobin.total in Blood",      domain="Measurement",   vocabulary="LOINC",         class="Laboratory Test"),
    8554       => (name="%",                                             domain="Unit",          vocabulary="UCUM",          class="Unit"),
    8876       => (name="mmHg",                                          domain="Unit",          vocabulary="UCUM",          class="Unit"),
    3016169    => (name="Mammography",                                   domain="Measurement",   vocabulary="LOINC",         class="Clinical Observation"),
    2006395    => (name="Mastectomy",                                    domain="Procedure",     vocabulary="ICD9Proc",      class="ICD9Proc"),
    3027299    => (name="Fecal occult blood test",                       domain="Measurement",   vocabulary="LOINC",         class="Laboratory Test"),
    37163368   => (name="Colonoscopy",                                   domain="Procedure",     vocabulary="SNOMED",        class="Procedure"),
    4262589    => (name="Sigmoidoscopy",                                 domain="Procedure",     vocabulary="SNOMED",        class="Procedure"),
    40763569   => (name="CT colonoscopy",                                domain="Measurement",   vocabulary="LOINC",         class="Clinical Observation"),
    46236059   => (name="Fecal DNA test",                                domain="Measurement",   vocabulary="LOINC",         class="Laboratory Test"),
    3038553    => (name="Body mass index (BMI [kg/m2])",                 domain="Measurement",   vocabulary="LOINC",         class="Clinical Observation"),
    40490382   => (name="Body mass index for age percentile",            domain="Measurement",   vocabulary="SNOMED",        class="Clinical Finding"),
    702866     => (name="COVID-19 mRNA BNT162b2 vaccine",                domain="Drug",          vocabulary="CVX",           class="Vaccine"),
    2000000094 => (name="PSC-17 Total Score",                            domain="Observation",   vocabulary="Custom",        class="Survey"),
    2000000095 => (name="PSC-17 Internalization",                        domain="Observation",   vocabulary="Custom",        class="Survey"),
    2000000096 => (name="PSC-17 Externalization",                        domain="Observation",   vocabulary="Custom",        class="Survey"),
    2000000097 => (name="PSC-17 Attention",                              domain="Observation",   vocabulary="Custom",        class="Survey"),
    35609425   => (name="PHQ-9 total score",                             domain="Measurement",   vocabulary="SNOMED",        class="Clinical Finding"),
    36304041   => (name="Within the past 12 months, worried food would run out [U.S. FSS]", domain="Observation", vocabulary="LOINC", class="Survey"),
    36306143   => (name="Within the past 12 months, food bought just didn't last [U.S. FSS]", domain="Observation", vocabulary="LOINC", class="Survey"),
    36309869   => (name="Never true",                                    domain="Observation",   vocabulary="LOINC",         class="Answer"),
    45877955   => (name="Often true",                                    domain="Observation",   vocabulary="LOINC",         class="Answer"),
    42869557   => (name="Housing status",                                domain="Observation",   vocabulary="LOINC",         class="Survey"),
    4139934    => (name="Homeless",                                      domain="Observation",   vocabulary="SNOMED",        class="Clinical Finding"),
    4306655    => (name="Hypertensive disorder",                         domain="Condition",     vocabulary="SNOMED",        class="Clinical Finding"),
)

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

function to_df(rows::Vector, schema::Vector{Symbol})::DataFrame
    df = isempty(rows) ? DataFrame() : DataFrame(rows)
    for col in schema
        if !hasproperty(df, col)
            df[!, col] = fill(missing, nrow(df))
        end
    end
    select(df, schema)
end

function _birth_datetime(patient)
    y  = get(patient, "birth_year",  nothing)
    mo = get(patient, "birth_month", nothing)
    d  = get(patient, "birth_day",   nothing)
    (y === nothing || mo === nothing || d === nothing) && return missing
    DateTime(y, mo, d)
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
        :concept_ancestor     => [],
    )
end

function _collect_concept_ids(tables::Dict{String,DataFrame})::Set{Int}
    ids = Set{Int}()
    for df in values(tables)
        for col in names(df)
            endswith(col, "_concept_id") || continue
            for v in df[!, col]
                if !ismissing(v) && v isa Integer && v != 0
                    push!(ids, Int(v))
                end
            end
        end
    end
    ids
end

function _always_write_tables(cfg::Dict)::Vector{Symbol}
    raw = get(cfg, "always_write_tables", [String(name) for name in Schema.DEFAULT_ALWAYS_WRITE_TABLES])
    raw isa Vector || throw(ArgumentError("'always_write_tables' must be a list of table names"))

    tables = Symbol[]
    seen = Set{Symbol}()
    for name in raw
        name isa AbstractString || throw(ArgumentError("'always_write_tables' entries must be strings"))
        table = Symbol(name)
        haskey(Schema.TABLE_SCHEMAS, table) || throw(ArgumentError("Unknown table in always_write_tables: '$name'"))
        table in seen && continue
        push!(tables, table)
        push!(seen, table)
    end
    tables
end

function _finalize(accum::Dict, cfg::Dict, locations::Vector=Dict[])::Dict{String,DataFrame}
    result = Dict{String,DataFrame}()
    always_write = Set(_always_write_tables(cfg))

    for (key, schema) in Schema.ROW_TABLES
        rows = get(accum, key, [])
        if key in always_write || !isempty(rows)
            result[string(key)] = to_df(rows, schema)
        end
    end

    location_df = to_df([build_location(s) for s in locations], Schema.LOCATION)
    if :location in always_write || nrow(location_df) > 0
        result["location"] = location_df
    end

    concept_ids = _collect_concept_ids(result)
    concept_df = to_df(
        [build_concept(id) for id in sort(collect(concept_ids))],
        Schema.CONCEPT,
    )
    if :concept in always_write || nrow(concept_df) > 0
        result["concept"] = concept_df
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
        )], Schema.CDM_SOURCE)
    end

    result
end

function build_person(patient, pid::Int, default_location_id=missing)
    loc_id = let v = get(patient, "location_id", missing)
        ismissing(v) ? default_location_id : v
    end
    (
        person_id                   = pid,
        gender_concept_id           = get(patient, "gender_concept_id", 0),
        year_of_birth               = get(patient, "birth_year",  missing),
        month_of_birth              = get(patient, "birth_month", missing),
        day_of_birth                = get(patient, "birth_day",   missing),
        birth_datetime              = _birth_datetime(patient),
        race_concept_id             = get(patient, "race_concept_id", 0),
        ethnicity_concept_id        = get(patient, "ethnicity_concept_id", 0),
        location_id                 = loc_id,
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

function build_location(spec)
    (
        location_id           = spec["id"],
        address_1             = get(spec, "address_1",             missing),
        address_2             = get(spec, "address_2",             missing),
        city                  = get(spec, "city",                  missing),
        state                 = get(spec, "state",                 missing),
        zip                   = get(spec, "zip",                   missing),
        county                = get(spec, "county",                missing),
        location_source_value = get(spec, "location_source_value", missing),
        country_concept_id    = get(spec, "country_concept_id",    0),
        country_source_value  = get(spec, "country_source_value",  missing),
        latitude              = get(spec, "latitude",              missing),
        longitude             = get(spec, "longitude",             missing),
    )
end

function build_concept(concept_id::Int)
    info = get(_KNOWN_CONCEPTS, concept_id, nothing)
    (
        concept_id       = concept_id,
        concept_name     = info !== nothing ? info.name       : string(concept_id),
        domain_id        = info !== nothing ? info.domain     : "Unknown",
        vocabulary_id    = info !== nothing ? info.vocabulary : "None",
        concept_class_id = info !== nothing ? info.class      : "Unknown",
        standard_concept = "S",
        concept_code     = string(concept_id),
        valid_start_date = Date(1970, 1, 1),
        valid_end_date   = Date(2099, 12, 31),
        invalid_reason   = missing,
    )
end

function build_observation_period(pid::Int, visit_starts::Vector{Date}, visit_ends::Vector{Date}, obs_id::Int)
    obs_start = isempty(visit_starts) ? DEFAULT_OBSERVATION_DATE : minimum(visit_starts)
    obs_end   = isempty(visit_ends)   ? DEFAULT_OBSERVATION_DATE : maximum(visit_ends)
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
        refills                      = get(spec, "refills",      missing),
        quantity                     = get(spec, "quantity",     missing),
        days_supply                  = get(spec, "days_supply",  missing),
        sig                          = missing,
        route_concept_id             = get(spec, "route_concept_id", 0),
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
        value_as_number               = get(spec, "value_as_number",   missing),
        value_as_concept_id           = get(spec, "value_as_concept_id", 0),
        unit_concept_id               = get(spec, "unit_concept_id",   0),
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
        value_as_number               = get(spec, "value_as_number",    missing),
        value_as_string               = get(spec, "value_as_string",    missing),
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
        note_type_concept_id        = get(spec, "type_concept_id",  TYPE_EHR),
        note_class_concept_id       = get(spec, "class_concept_id", 0),
        note_title                  = get(spec, "title",  missing),
        note_text                   = get(spec, "text",   missing),
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
        death_type_concept_id   = get(spec, "type_concept_id",   TYPE_EHR),
        cause_concept_id        = get(spec, "cause_concept_id",  0),
        cause_source_value      = missing,
        cause_source_concept_id = 0,
    )
end

function process_patient!(accum::Dict, counters::Dict, patient::Dict, pid::Int, default_location_id=missing)
    visits = get(patient, "visits", [])

    push!(accum[:person], build_person(patient, pid, default_location_id))

    v_starts = [parse_date(v["start_date"]) for v in visits]
    v_ends   = [parse_date(get(v, "end_date", v["start_date"])) for v in visits]
    push!(accum[:observation_period],
        build_observation_period(pid, v_starts, v_ends, next!(counters[:observation_period])))

    for v_spec in visits
        vid     = next!(counters[:visit_occurrence])
        v_start = parse_date(v_spec["start_date"])
        v_end   = parse_date(get(v_spec, "end_date", v_spec["start_date"]))
        push!(accum[:visit_occurrence], build_visit(v_spec, pid, vid, v_start, v_end))
        for spec in get(v_spec, "conditions",   []) push!(accum[:condition_occurrence], build_condition(spec,   pid, vid, v_start, counters[:condition_occurrence]))   end
        for spec in get(v_spec, "drugs",        []) push!(accum[:drug_exposure],        build_drug(spec,       pid, vid, v_start, v_end, counters[:drug_exposure]))        end
        for spec in get(v_spec, "procedures",   []) push!(accum[:procedure_occurrence], build_procedure(spec,  pid, vid, v_start, counters[:procedure_occurrence]))   end
        for spec in get(v_spec, "devices",      []) push!(accum[:device_exposure],      build_device(spec,     pid, vid, v_start, counters[:device_exposure]))      end
        for spec in get(v_spec, "measurements", []) push!(accum[:measurement],          build_measurement(spec, pid, vid, v_start, counters[:measurement]))          end
        for spec in get(v_spec, "observations", []) push!(accum[:observation],          build_observation(spec, pid, vid, v_start, counters[:observation]))          end
        for spec in get(v_spec, "notes",        []) push!(accum[:note],                 build_note(spec,       pid, vid, v_start, counters[:note]))                 end
    end

    death_spec = get(patient, "death", nothing)
    death_spec !== nothing && push!(accum[:death], build_death(death_spec, pid))
end

function build_all(cfg::Dict)::Dict{String,DataFrame}
    patients       = cfg["patients"]
    locations      = get(cfg, "locations", Dict[])
    default_loc_id = get(cfg, "default_location_id", missing)
    counters = _fresh_counters()
    accum    = _fresh_accum()
    for (i, patient) in enumerate(patients)
        process_patient!(accum, counters, patient, i, default_loc_id)
    end
    _finalize(accum, cfg, locations)
end

function build_all_sites(cfg::Dict)::Tuple{Dict{String,Dict{String,DataFrame}},DataFrame}
    site_ids       = [string(s["id"]) for s in cfg["sites"]]
    patients       = cfg["patients"]
    locations      = get(cfg, "locations", Dict[])
    default_loc_id = get(cfg, "default_location_id", missing)

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
            process_patient!(accum, counters, merged, pid, default_loc_id)
            push!(linkage_rows, (handle = merged["handle"], site_id = site_id, person_id = pid))
        end
        site_tables[site_id] = _finalize(accum, cfg, locations)
    end

    linkage_df = isempty(linkage_rows) ?
        DataFrame(handle = String[], site_id = String[], person_id = Int[]) :
        DataFrame(linkage_rows)
    (site_tables, linkage_df)
end

end # module Generator

