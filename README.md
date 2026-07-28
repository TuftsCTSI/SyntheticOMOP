# SyntheticOMOP

A config-driven generator for synthetic [OMOP CDM 5.4](https://ohdsi.github.io/CommonDataModel/cdm54.html) datasets.
The input is a YAML scenario file describing patients and their clinical events, and the output is a set of CSVs.

## Purpose

This tool creates custom datasets with specific patient scenarios for regression testing.
The config file serves as a design artifact, preserving the intent of each patient scenario.

Multi-site configs produce one dataset per site plus a linkage manifest, supporting record linkage testing across sites with known ground-truth matches.

## Usage

```
julia --project generate.jl <input.yml> [output_dir]
```

Example configs are in `assets/scenarios/`.
Output defaults to `out/omop_synth/`.

## Config format

### Top-level keys

| Key | Required | Purpose |
|-----|----------|---------|
| `concepts` | yes | Alias-to-integer mapping for all OMOP concept IDs |
| `patients` | * | List of hand-crafted patient records |
| `templates` | * | Named templates for deterministic bulk generation |
| `sites` | no | Enables multi-site mode |
| `cdm_source` | no | Provenance metadata for cdm_source.csv |
| `always_write_tables` | no | Table names to write even when empty |

\* At least one of `patients` or `templates` is required.

### Concepts

All concept references use string aliases defined in the `concepts` section.
Raw integer concept codes are not allowed.

```yaml
concepts:
  male: 8507
  female: 8532
  white: 8527
  outpatient: 9202
  inpatient: 9201
  hypertension: 320128
  systolic_bp: 3004249
  mmHg: 8876
```

### Patients

Each patient has demographics and flat event lists.
Events are not nested inside visits; the generator auto-groups same-date events into outpatient visits.

```yaml
patients:
  - person_source_value: alice
    gender_concept_id: female
    birth_year: 1975
    birth_month: 3
    birth_day: 15
    race_concept_id: white
    conditions:
      - concept_id: hypertension
        date: "2023-01-15"
    measurements:
      - concept_id: systolic_bp
        date: "2023-06-15"
        value_as_number: 139
        unit_concept_id: mmHg
```

#### Patient fields

| Field | Required | Notes |
|-------|----------|-------|
| `person_source_value` | yes | Unique patient identifier |
| `gender_concept_id` | no | Concept alias |
| `birth_year` | no | |
| `birth_month` | no | |
| `birth_day` | no | All three needed for `birth_datetime` |
| `race_concept_id` | no | Concept alias |
| `ethnicity_concept_id` | no | Concept alias |
| `death` | no | Death record with `date` and optional `cause_concept_id` |

#### Event types

All events require `concept_id` (alias) and `date` (YYYY-MM-DD).

| List key | Additional fields |
|----------|-------------------|
| `conditions` | `end_date`, `type_concept_id` |
| `drugs` | `end_date`, `days_supply`, `quantity`, `refills`, `route_concept_id`, `lot_number`, `type_concept_id` |
| `procedures` | `end_date`, `quantity`, `type_concept_id` |
| `devices` | `end_date`, `quantity`, `unit_concept_id`, `type_concept_id` |
| `measurements` | `value_as_number`, `value_as_concept_id`, `unit_concept_id`, `operator_concept_id`, `range_low`, `range_high`, `type_concept_id` |
| `observations` | `value_as_number`, `value_as_string`, `value_as_concept_id`, `unit_concept_id`, `type_concept_id` |
| `notes` | `title`, `text`, `class_concept_id`, `type_concept_id` |

Optional `visit_concept_id` overrides the default outpatient visit for that date.
Optional `visit_end_date` sets a multi-day visit end (for inpatient stays).

### Templates

Templates produce patients via deterministic cartesian product over list-valued fields.
Every field whose value is a list of scalars becomes a parameter axis.

```yaml
templates:
  htn_patient:
    gender_concept_id: [male, female]
    birth_year: [1940, 1970, 2000]
    conditions:
      - concept_id: hypertension
        date: "2023-01-15"
    measurements:
      - concept_id: systolic_bp
        date: "2023-06-15"
        value_as_number: [130, 140, 150]
        unit_concept_id: mmHg
```

This produces 2 x 3 x 3 = 18 patients.
`person_source_value` is auto-generated as `<template_name>_<index>` unless provided as a list (which becomes another axis).

### Multi-site mode

Add a `sites` list and replace each patient's events with an `appearances` list.
Each appearance specifies a `site` plus demographics and events for that site.

```yaml
sites:
  - id: hospital_a
  - id: hospital_b

patients:
  - person_source_value: alice
    appearances:
      - site: hospital_a
        gender_concept_id: female
        conditions:
          - concept_id: hypertension
            date: "2023-01-15"
      - site: hospital_b
        gender_concept_id: female
        measurements:
          - concept_id: systolic_bp
            date: "2023-06-10"
            value_as_number: 135
            unit_concept_id: mmHg
```

Output is written to `output_dir/<site_id>/` per site.
A `linkage.csv` is written to `output_dir/` with columns `person_source_value`, `site_id`, and `person_id`.
`person_id` is assigned sequentially per site and is not consistent across sites by design.

### Visit generation

Visits are not declared in the config.
The generator groups same-date events into a single visit per date.
Visits default to outpatient (concept 9202).
To override, set `visit_concept_id` on any event for that date.
To create a multi-day visit, set `visit_end_date` on any event for that date.
