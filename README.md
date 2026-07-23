# SyntheticOMOP

A config-driven generator for synthetic [OMOP CDM 5.4](https://ohdsi.github.io/CommonDataModel/cdm54.html) datasets.
The input is a YAML scenario file describing patients and their clinical events, and the output is a set of CSVs.

## Purpose

This tool allows us to create custom datasets with very specific patient scenarios, which is useful for regression tests.
The config file serves as a design artifact, preserving the intent of each patient scenario, which could be unclear if we instead crafted datasets directly.

Multi-site configs produce one dataset per site plus a linkage manifest, supporting record linkage testing across sites with known ground-truth matches.

## Usage

```
julia --project generate.jl <input.yml> [output_dir]
```

Example configs are in `assets/scenarios/`. Output defaults to `out/omop_synth/`.
Table names are upper-cased (`PERSON.csv`, `VISIT_OCCURRENCE.csv`, etc.).
Only non-empty tables are written.

## Config format

`cdm_source` (optional) sets provenance metadata written to `CDM_SOURCE.csv`.

`patients` (required) is a list of patient records.

### Single-site

Each patient has demographic fields and an optional `visits` list.
Each visit supports nested `conditions`, `drugs`, `measurements`, `observations`, `procedures`, `devices`, and `notes` lists.
A patient may also have a `death` entry.
All tables are written directly to `output_dir`.

See `assets/scenarios/example.yml` for a fully annotated example.

### Multi-site

Add a top-level `sites` list, each entry with an `id` field.
Replace each patient's `visits` and demographics with an `appearances` list.
Each appearance specifies a `site` and that patient's demographics and visits at that site.
Appearance-level fields take precedence over patient-level defaults, so per-site demographic variation is supported.

A patient with no appearance at a given site is simply absent from that site's dataset.
`person_id` is assigned sequentially per site and is not consistent across sites by design.
`person_source_value` holds the patient handle and is the ground-truth join key.

Output is written to `output_dir/<site_id>/` per site.
A `LINKAGE.csv` is written to `output_dir/` with columns `handle`, `site_id`, and `person_id`.

See `assets/scenarios/multi_site_example.yml` for a fully annotated example.
