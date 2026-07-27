module Schema

"""Column names for all OMOP CDM 5.4 tables, in canonical field order."""

const PERSON = Symbol[
    :person_id, :gender_concept_id, :year_of_birth, :month_of_birth,
    :day_of_birth, :birth_datetime, :race_concept_id, :ethnicity_concept_id,
    :location_id, :provider_id, :care_site_id, :person_source_value,
    :gender_source_value, :gender_source_concept_id, :race_source_value,
    :race_source_concept_id, :ethnicity_source_value, :ethnicity_source_concept_id,
]

const OBSERVATION_PERIOD = Symbol[
    :observation_period_id, :person_id,
    :observation_period_start_date, :observation_period_end_date,
    :period_type_concept_id,
]

const VISIT_OCCURRENCE = Symbol[
    :visit_occurrence_id, :person_id, :visit_concept_id,
    :visit_start_date, :visit_start_datetime, :visit_end_date, :visit_end_datetime,
    :visit_type_concept_id, :provider_id, :care_site_id,
    :visit_source_value, :visit_source_concept_id,
    :admitted_from_concept_id, :admitted_from_source_value,
    :discharged_to_concept_id, :discharged_to_source_value,
    :preceding_visit_occurrence_id,
]

const VISIT_DETAIL = Symbol[
    :visit_detail_id, :person_id, :visit_detail_concept_id,
    :visit_detail_start_date, :visit_detail_start_datetime,
    :visit_detail_end_date, :visit_detail_end_datetime,
    :visit_detail_type_concept_id, :provider_id, :care_site_id,
    :discharge_to_concept_id, :admitted_from_concept_id,
    :visit_detail_source_value, :visit_detail_source_concept_id,
    :visit_occurrence_id, :parent_visit_detail_id,
]

const CONDITION_OCCURRENCE = Symbol[
    :condition_occurrence_id, :person_id, :condition_concept_id,
    :condition_start_date, :condition_start_datetime,
    :condition_end_date, :condition_end_datetime,
    :condition_type_concept_id, :condition_status_concept_id, :stop_reason,
    :provider_id, :visit_occurrence_id, :visit_detail_id,
    :condition_source_value, :condition_source_concept_id,
    :condition_status_source_value,
]

const DRUG_EXPOSURE = Symbol[
    :drug_exposure_id, :person_id, :drug_concept_id,
    :drug_exposure_start_date, :drug_exposure_start_datetime,
    :drug_exposure_end_date, :drug_exposure_end_datetime,
    :verbatim_end_date, :drug_type_concept_id, :stop_reason,
    :refills, :quantity, :days_supply, :sig,
    :route_concept_id, :lot_number, :provider_id,
    :visit_occurrence_id, :visit_detail_id,
    :drug_source_value, :drug_source_concept_id,
    :route_source_value, :dose_unit_source_value,
]

const PROCEDURE_OCCURRENCE = Symbol[
    :procedure_occurrence_id, :person_id, :procedure_concept_id,
    :procedure_date, :procedure_datetime,
    :procedure_end_date, :procedure_end_datetime,
    :procedure_type_concept_id, :modifier_concept_id, :quantity,
    :provider_id, :visit_occurrence_id, :visit_detail_id,
    :procedure_source_value, :procedure_source_concept_id,
    :modifier_source_value,
]

const DEVICE_EXPOSURE = Symbol[
    :device_exposure_id, :person_id, :device_concept_id,
    :device_exposure_start_date, :device_exposure_start_datetime,
    :device_exposure_end_date, :device_exposure_end_datetime,
    :device_type_concept_id, :unique_device_id, :production_id,
    :quantity, :provider_id, :visit_occurrence_id, :visit_detail_id,
    :device_source_value, :device_source_concept_id,
    :unit_concept_id, :unit_source_value, :unit_source_concept_id,
]

const MEASUREMENT = Symbol[
    :measurement_id, :person_id, :measurement_concept_id,
    :measurement_date, :measurement_datetime, :measurement_time,
    :measurement_type_concept_id, :operator_concept_id,
    :value_as_number, :value_as_concept_id, :unit_concept_id,
    :range_low, :range_high, :provider_id,
    :visit_occurrence_id, :visit_detail_id,
    :measurement_source_value, :measurement_source_concept_id,
    :unit_source_value, :unit_source_concept_id, :value_source_value,
    :measurement_event_id, :meas_event_field_concept_id,
]

const OBSERVATION = Symbol[
    :observation_id, :person_id, :observation_concept_id,
    :observation_date, :observation_datetime,
    :observation_type_concept_id,
    :value_as_number, :value_as_string, :value_as_concept_id,
    :qualifier_concept_id, :unit_concept_id,
    :provider_id, :visit_occurrence_id, :visit_detail_id,
    :observation_source_value, :observation_source_concept_id,
    :unit_source_value, :qualifier_source_value, :value_source_value,
    :observation_event_id, :obs_event_field_concept_id,
]

const DEATH = Symbol[
    :person_id, :death_date, :death_datetime,
    :death_type_concept_id, :cause_concept_id,
    :cause_source_value, :cause_source_concept_id,
]

const NOTE = Symbol[
    :note_id, :person_id, :note_date, :note_datetime,
    :note_type_concept_id, :note_class_concept_id,
    :note_title, :note_text, :encoding_concept_id,
    :language_concept_id, :provider_id,
    :visit_occurrence_id, :visit_detail_id,
    :note_source_value, :note_event_id, :note_event_field_concept_id,
]

const NOTE_NLP = Symbol[
    :note_nlp_id, :note_id, :section_concept_id,
    :snippet, :offset, :lexical_variant,
    :note_nlp_concept_id, :note_nlp_source_concept_id,
    :nlp_system, :nlp_date, :nlp_datetime,
    :term_exists, :term_temporal, :term_modifiers,
]

const SPECIMEN = Symbol[
    :specimen_id, :person_id, :specimen_concept_id,
    :specimen_type_concept_id, :specimen_date, :specimen_datetime,
    :quantity, :unit_concept_id, :anatomic_site_concept_id,
    :disease_status_concept_id, :specimen_source_id,
    :specimen_source_value, :unit_source_value,
    :anatomic_site_source_value, :disease_status_source_value,
]

const FACT_RELATIONSHIP = Symbol[
    :domain_concept_id_1, :fact_id_1,
    :domain_concept_id_2, :fact_id_2,
    :relationship_concept_id,
]

const SURVEY_CONDUCT = Symbol[
    :survey_conduct_id, :person_id, :survey_concept_id,
    :survey_start_date, :survey_start_datetime,
    :survey_end_date, :survey_end_datetime,
    :provider_id, :assisted_concept_id, :respondent_type_concept_id,
    :timing_concept_id, :collection_method_concept_id,
    :assisted_source_value, :respondent_type_source_value,
    :timing_source_value, :collection_method_source_value,
    :survey_source_value, :survey_source_concept_id,
    :validated_survey_concept_id, :validated_survey_source_value,
    :survey_version_number, :visit_occurrence_id, :visit_detail_id,
    :response_visit_occurrence_id,
]

const LOCATION = Symbol[
    :location_id, :address_1, :address_2, :city, :state, :zip,
    :county, :location_source_value, :country_concept_id,
    :country_source_value, :latitude, :longitude,
]

const CARE_SITE = Symbol[
    :care_site_id, :care_site_name, :place_of_service_concept_id,
    :location_id, :care_site_source_value,
    :place_of_service_source_value,
]

const PROVIDER = Symbol[
    :provider_id, :provider_name, :npi, :dea,
    :specialty_concept_id, :care_site_id, :year_of_birth, :gender_concept_id,
    :provider_source_value, :specialty_source_value,
    :specialty_source_concept_id, :gender_source_value,
    :gender_source_concept_id,
]

const PAYER_PLAN_PERIOD = Symbol[
    :payer_plan_period_id, :person_id,
    :payer_plan_period_start_date, :payer_plan_period_end_date,
    :payer_concept_id, :payer_source_value, :payer_source_concept_id,
    :plan_concept_id, :plan_source_value, :plan_source_concept_id,
    :sponsor_concept_id, :sponsor_source_value, :sponsor_source_concept_id,
    :family_source_value, :stop_reason_concept_id, :stop_reason_source_value,
    :stop_reason_source_concept_id,
]

const COST = Symbol[
    :cost_id, :cost_event_id, :cost_domain_id, :cost_type_concept_id,
    :currency_concept_id, :total_charge, :total_cost, :total_paid,
    :paid_by_payer, :paid_by_patient, :paid_patient_copay,
    :paid_patient_coinsurance, :paid_patient_deductible,
    :paid_by_primary, :paid_ingredient_cost, :paid_dispensing_fee,
    :payer_plan_period_id, :amount_allowed,
    :revenue_code_concept_id, :revenue_code_source_value,
    :drg_concept_id, :drg_source_value,
]

const DRUG_ERA = Symbol[
    :drug_era_id, :person_id, :drug_concept_id,
    :drug_era_start_date, :drug_era_end_date,
    :drug_exposure_count, :gap_days,
]

const DOSE_ERA = Symbol[
    :dose_era_id, :person_id, :drug_concept_id,
    :unit_concept_id, :dose_value,
    :dose_era_start_date, :dose_era_end_date,
]

const CONDITION_ERA = Symbol[
    :condition_era_id, :person_id, :condition_concept_id,
    :condition_era_start_date, :condition_era_end_date,
    :condition_occurrence_count,
]

const EPISODE = Symbol[
    :episode_id, :person_id, :episode_concept_id,
    :episode_start_date, :episode_start_datetime,
    :episode_end_date, :episode_end_datetime,
    :episode_parent_id, :episode_number,
    :episode_object_concept_id, :episode_type_concept_id,
    :episode_source_value, :episode_source_concept_id,
]

const EPISODE_EVENT = Symbol[
    :episode_id, :event_id, :episode_event_field_concept_id,
]

const CONCEPT = Symbol[
    :concept_id, :concept_name, :domain_id, :vocabulary_id,
    :concept_class_id, :standard_concept, :concept_code,
    :valid_start_date, :valid_end_date, :invalid_reason,
]

const CONCEPT_ANCESTOR = Symbol[
    :ancestor_concept_id, :descendant_concept_id,
    :min_levels_of_separation, :max_levels_of_separation,
]

const CDM_SOURCE = Symbol[
    :cdm_source_name, :cdm_source_abbreviation, :cdm_holder,
    :source_description, :source_documentation_reference,
    :cdm_etl_reference, :source_release_date, :cdm_release_date,
    :cdm_version, :cdm_version_concept_id, :vocabulary_version,
]

"""Registry of all recognized OMOP CDM 5.4 table schemas."""
const TABLE_SCHEMAS = Dict{Symbol,Vector{Symbol}}(
    :person               => PERSON,
    :observation_period   => OBSERVATION_PERIOD,
    :visit_occurrence     => VISIT_OCCURRENCE,
    :visit_detail         => VISIT_DETAIL,
    :condition_occurrence => CONDITION_OCCURRENCE,
    :drug_exposure        => DRUG_EXPOSURE,
    :procedure_occurrence => PROCEDURE_OCCURRENCE,
    :device_exposure      => DEVICE_EXPOSURE,
    :measurement          => MEASUREMENT,
    :observation          => OBSERVATION,
    :death                => DEATH,
    :note                 => NOTE,
    :note_nlp             => NOTE_NLP,
    :specimen             => SPECIMEN,
    :fact_relationship    => FACT_RELATIONSHIP,
    :survey_conduct       => SURVEY_CONDUCT,
    :location             => LOCATION,
    :care_site            => CARE_SITE,
    :provider             => PROVIDER,
    :payer_plan_period    => PAYER_PLAN_PERIOD,
    :cost                 => COST,
    :drug_era             => DRUG_ERA,
    :dose_era             => DOSE_ERA,
    :condition_era        => CONDITION_ERA,
    :episode              => EPISODE,
    :episode_event        => EPISODE_EVENT,
    :concept              => CONCEPT,
    :concept_ancestor     => CONCEPT_ANCESTOR,
    :cdm_source           => CDM_SOURCE,
)

"""Tables built via row accumulators in Generator."""
const ROW_TABLES = Dict{Symbol,Vector{Symbol}}(
    :person               => PERSON,
    :observation_period   => OBSERVATION_PERIOD,
    :visit_occurrence     => VISIT_OCCURRENCE,
    :condition_occurrence => CONDITION_OCCURRENCE,
    :drug_exposure        => DRUG_EXPOSURE,
    :procedure_occurrence => PROCEDURE_OCCURRENCE,
    :device_exposure      => DEVICE_EXPOSURE,
    :measurement          => MEASUREMENT,
    :observation          => OBSERVATION,
    :death                => DEATH,
    :note                 => NOTE,
    :concept_ancestor     => CONCEPT_ANCESTOR,
)

const DEFAULT_ALWAYS_WRITE_TABLES = Symbol[
    :person,
    :observation_period,
    :visit_occurrence,
    :condition_occurrence,
    :drug_exposure,
    :procedure_occurrence,
    :measurement,
    :observation,
    :death,
    :location,
    :concept,
    :concept_ancestor,
]

end # module Schema
