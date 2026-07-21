# OmopTestData

A config-driven generator for synthetic [OMOP CDM 5.4](https://ohdsi.github.io/CommonDataModel/cdm54.html) datasets.
The input is a YAML scenario file describing patients and their clinical events, and the output is a set of CSVs.

## Purpose

This tool allows us to create custom datasets with very specific patient scenarios, which is useful for regression tests. The config file serves as a design artifact, preserving the intent of each patient scenario, which could be unclear if we instead crafted datasets directly.

## Usage

```
julia --project generate.jl <input.yml> [output_dir]
```

Any example inputs will found in `assets/scenarios/`. Output defaults to `out/omop_synth/`, where file names will be upper-case (`PERSON.csv`, `VISIT_OCCURRENCE.csv`, etc.).

## Config format

The config file has two top-level keys.

`cdm_source` (optional) sets provenance metadata written to `CDM_SOURCE.csv`.

`patients` (required) is a list of patient records. Each patient has demographic fields and an optional `visits` list. Each visit supports nested `conditions`, `drugs`, `measurements`, `observations`, `procedures`, `devices`, and `notes` lists. A patient may also have a `death` entry.

See `assets/scenarios/example.yml` for a fully annotated example with concept ID comments.

## Tables generated

All OMOP CDM 5.4 clinical tables are supported. Only non-empty tables are written:

| Table | Source |
| --- | --- |
| `CDM_SOURCE` | `cdm_source` config key |
| `PERSON` | one row per patient |
| `OBSERVATION_PERIOD` | derived from visit date range |
| `VISIT_OCCURRENCE` | patient `visits` list |
| `CONDITION_OCCURRENCE` | visit `conditions` list |
| `DRUG_EXPOSURE` | visit `drugs` list |
| `PROCEDURE_OCCURRENCE` | visit `procedures` list |
| `DEVICE_EXPOSURE` | visit `devices` list |
| `MEASUREMENT` | visit `measurements` list |
| `OBSERVATION` | visit `observations` list |
| `NOTE` | visit `notes` list |
| `DEATH` | patient `death` entry |

All columns for each table are written in canonical CDM 5.4 field order. Fields not populated by the config are left empty.
