module Schema

const PERSON = [
    :person_id, :gender_concept_id, :year_of_birth, :month_of_birth, :day_of_birth,
    :birth_datetime, :race_concept_id, :ethnicity_concept_id, :location_id,
    :provider_id, :care_site_id, :person_source_value, :gender_source_value,
    :gender_source_concept_id, :race_source_value, :race_source_concept_id,
    :ethnicity_source_value, :ethnicity_source_concept_id,
]

const OBSERVATION_PERIOD = [
    :observation_period_id, :person_id, :observation_period_start_date,
    :observation_period_end_date, :period_type_concept_id,
]

const VISIT_OCCURRENCE = [
    :visit_occurrence_id, :person_id, :visit_concept_id,
    :visit_start_date, :visit_start_datetime, :visit_end_date, :visit_end_datetime,
    :visit_type_concept_id, :provider_id, :care_site_id, :visit_source_value,
    :visit_source_concept_id, :admitted_from_concept_id, :admitted_from_source_value,
    :discharged_to_concept_id, :discharged_to_source_value, :preceding_visit_occurrence_id,
]

const CONDITION_OCCURRENCE = [
    :condition_occurrence_id, :person_id, :condition_concept_id,
    :condition_start_date, :condition_start_datetime,
    :condition_end_date, :condition_end_datetime,
    :condition_type_concept_id, :condition_status_concept_id, :stop_reason,
    :provider_id, :visit_occurrence_id, :visit_detail_id,
    :condition_source_value, :condition_source_concept_id, :condition_status_source_value,
]

const DRUG_EXPOSURE = [
    :drug_exposure_id, :person_id, :drug_concept_id,
    :drug_exposure_start_date, :drug_exposure_start_datetime,
    :drug_exposure_end_date, :drug_exposure_end_datetime, :verbatim_end_date,
    :drug_type_concept_id, :stop_reason, :refills, :quantity, :days_supply, :sig,
    :route_concept_id, :lot_number, :provider_id, :visit_occurrence_id, :visit_detail_id,
    :drug_source_value, :drug_source_concept_id, :route_source_value, :dose_unit_source_value,
]

const PROCEDURE_OCCURRENCE = [
    :procedure_occurrence_id, :person_id, :procedure_concept_id,
    :procedure_date, :procedure_datetime, :procedure_end_date, :procedure_end_datetime,
    :procedure_type_concept_id, :modifier_concept_id, :quantity, :provider_id,
    :visit_occurrence_id, :visit_detail_id,
    :procedure_source_value, :procedure_source_concept_id, :modifier_source_value,
]

const DEVICE_EXPOSURE = [
    :device_exposure_id, :person_id, :device_concept_id,
    :device_exposure_start_date, :device_exposure_start_datetime,
    :device_exposure_end_date, :device_exposure_end_datetime,
    :device_type_concept_id, :unique_device_id, :production_id, :quantity,
    :provider_id, :visit_occurrence_id, :visit_detail_id,
    :device_source_value, :device_source_concept_id,
    :unit_concept_id, :unit_source_value, :unit_source_concept_id,
]

const MEASUREMENT = [
    :measurement_id, :person_id, :measurement_concept_id,
    :measurement_date, :measurement_datetime, :measurement_time,
    :measurement_type_concept_id, :operator_concept_id,
    :value_as_number, :value_as_concept_id, :unit_concept_id,
    :range_low, :range_high, :provider_id, :visit_occurrence_id, :visit_detail_id,
    :measurement_source_value, :measurement_source_concept_id,
    :unit_source_value, :unit_source_concept_id, :value_source_value,
    :measurement_event_id, :meas_event_field_concept_id,
]

const OBSERVATION = [
    :observation_id, :person_id, :observation_concept_id,
    :observation_date, :observation_datetime, :observation_type_concept_id,
    :value_as_number, :value_as_string, :value_as_concept_id,
    :qualifier_concept_id, :unit_concept_id, :provider_id,
    :visit_occurrence_id, :visit_detail_id,
    :observation_source_value, :observation_source_concept_id,
    :unit_source_value, :qualifier_source_value, :value_source_value,
    :observation_event_id, :obs_event_field_concept_id,
]

const NOTE = [
    :note_id, :person_id, :note_date, :note_datetime,
    :note_type_concept_id, :note_class_concept_id,
    :note_title, :note_text, :encoding_concept_id, :language_concept_id,
    :provider_id, :visit_occurrence_id, :visit_detail_id,
    :note_source_value, :note_event_id, :note_event_field_concept_id,
]

const DEATH = [
    :person_id, :death_date, :death_datetime,
    :death_type_concept_id, :cause_concept_id,
    :cause_source_value, :cause_source_concept_id,
]

const CDM_SOURCE = [
    :cdm_source_name, :cdm_source_abbreviation, :cdm_holder,
    :source_description, :source_documentation_reference, :cdm_etl_reference,
    :source_release_date, :cdm_release_date,
    :cdm_version, :cdm_version_concept_id, :vocabulary_version,
]

const LOCATION = [
    :location_id, :address_1, :address_2, :city, :state, :zip, :county,
    :location_source_value, :country_concept_id, :country_source_value,
    :latitude, :longitude,
]

const CONCEPT = [
    :concept_id, :concept_name, :domain_id, :vocabulary_id, :concept_class_id,
    :standard_concept, :concept_code, :valid_start_date, :valid_end_date,
    :invalid_reason,
]

end # module Schema

