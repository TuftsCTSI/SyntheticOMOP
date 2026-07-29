# SyntheticOMOP

A deterministic config-driven generator for synthetic [OMOP CDM 5.4](https://ohdsi.github.io/CommonDataModel/cdm54.html) datasets.
Given a YAML file describing fictional patients and their clinical events, it produces a directory of CSV files that conform to the OMOP Common Data Model.

## Summary

- This tool is mainly intended for preparing datasets for use in software testing.
- The input file serves as a design artifact, preserving the intent of each patient scenario, which might be lost if we prepared the dataset directly.
- No randomness is used. Data generation is entirely deterministic.
- This tool creates entirely fictional test data. Assuming real patient records weren't used to make the input file, the output cannot contain protected health information (PHI).
- Coherence of medical records isn't a major design aim. Other tools exist for creating realistic patient data.

## Quickstart

```sh
git clone https://github.com/TuftsCTSI/SyntheticOMOP.git
cd SyntheticOMOP
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project generate.jl assets/example.yml
```

Output appears in `out/example/`. Along with the OMOP CSVs, the output directory will contains a `_provenance.yml` metadata file recording the generator version, source config filename, and generation timestamp.

## Minimal config

A complete working config needs only `concepts` and `patients`:

```yaml
concepts:
  female: 8532          # OMOP concept ID for "female"
  hypertension: 320128  # OMOP concept ID for hypertension

patients:
  - person_source_value: patient_1
    gender_concept_id: female
    birth_year: 1980
    conditions:
      - concept_id: hypertension
        date: "2023-06-01"
```

This produces one patient with one condition record, one auto-generated outpatient visit, and one observation period spanning that date.

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
Raw integer concept codes are not allowed in patient or template definitions.
This makes configs readable and reviewable: every medical code has a human-readable label, and all codes used in a scenario are declared in one place.

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
| `notes` | `title`, `text`, `class_concept_id`, `encoding_concept_id`, `language_concept_id`, `type_concept_id` |

Optional `visit_concept_id` overrides the default outpatient visit for that date.
Optional `visit_end_date` sets a multi-day visit end (for inpatient stays).

### Templates

Templates produce patients via deterministic Cartesian product over list-valued fields.
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

The Cartesian product is purely combinatorial.
Generated combinations are not guaranteed to be clinically plausible (for example, a template might produce a 3-year-old with a diagnosis typically seen in adults).
Design templates with awareness of which axes interact clinically.

Templates are supported in multi-site mode.
Each template must include an `appearances` list with the same structure as hand-crafted multi-site patients.
Axes inside appearances are expanded normally.

### Multi-site mode

Multi-site configs support testing record linkage across institutions.
The basic problem: the same patient may appear at multiple hospitals under different IDs.
Record linkage algorithms try to match these records back together.
To test such algorithms, you need datasets where the ground truth (which records belong to the same person) is known.

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
The `person_source_value` column is the ground-truth key linking the same person across sites.

When an appearance is merged with the patient record, appearance-level fields override patient-level fields (except `person_source_value`, which is always preserved from the patient).

### Visit generation

Visits are not declared in the config.
The generator groups same-date events into a single visit per date.
Visits default to outpatient (concept 9202).
To override, set `visit_concept_id` on any event for that date.
To create a multi-day visit, set `visit_end_date` on any event for that date.

## Scenario configs

Example configs are in `assets/`:

| File | Purpose |
|------|---------|
| `example.yml` | Basic demonstration of all event types (conditions, drugs, procedures, devices, measurements, observations) across three patients |
| `phx.yml` | PHX quality measures regression suite covering hypertension, diabetes, BMI, colorectal screening, breast cancer screening, depression, food security, housing, and immunization scenarios |
| `multi_site_example.yml` | Demonstrates multi-site mode with cross-site patient appearances and linkage output |

## Library usage

The module exports `build` and `generate`:

```julia
using SyntheticOMOP

# Generate CSVs to disk
SyntheticOMOP.generate("assets/example.yml", "out/example")

# Build in-memory DataFrames (no file I/O)
tables = SyntheticOMOP.build("assets/example.yml")
tables["person"]  # DataFrame
```

## Data governance

This tool is designed so that its output is provably synthetic:

* Input is a YAML config file which should not be based on real data.
* Every record in the output traces to a specific config entry or template expansion.
* All medical concept codes are declared as named aliases, making them more readily reviewable.
* Each output directory contains a `_provenance.yml` file recording the generator version and source config, providing an audit trail.
* The generator has no database connections, no file readers beyond the config, and no network access.

