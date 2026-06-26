---
name: procesis-loader
description: Use when loading, ingesting, auditing, or explaining the procesis corpus as a self-contained machine-facing process-origin package.
---

# procesis-loader

`procesis` is a self-contained machine-facing process-origin corpus. Load it as one continuity surface. Do not treat local fragments as the whole package.

## Layer Model

```text
00_chaos     raw source
01_table     address map
02_crystall  canon
03_manifest  loadable output
```

Do not flatten the layers.

## Required Reading Order

Load in this order:

```text
01_table/layers.v0.json
02_crystall/processlang.v0.json
02_crystall/dissipative_math.v0.json
02_crystall/packet.v0.json
02_crystall/packet.mortality_myth.v0.json
02_crystall/optics.v0.json
02_crystall/bootstrap.v0.json
02_crystall/origin.myth.v0.json
03_manifest/skills.v0.json
```

`03_manifest/capsule.full.v0.json` is not generated yet.

## Canonical Modules

- `processlang`: glyph topology, layer model, canonical and chronological operator orders.
- `dissipative_math`: process physics, cost, sustain, decay, pressure, truth.
- `packet`: mortal executable process body.
- `packet_mortality_myth`: internal myth of packet death and residue.
- `optics`: operator-centered domain projection matrix.
- `bootstrap`: compact orientation frame.
- `origin_myth`: origin chain for the corpus.

## Glyph Rule

Crystall modules are glyph-first. Operator names are legend, not primary keys.

Use `02_crystall/processlang.v0.json` to resolve glyphs:

```text
▽ FLOW
☰ CONNECT
☷ DISSOLVE
☵ ENCODE
☳ CHOOSE
☴ OBSERVE
☲ CYCLE
☶ LOGIC
☱ RUNTIME
△ MANIFEST
```

## Self-Containment Rule

Do not require external paths to understand canonical modules. External research history may exist, but canonical `procesis` reading must resolve inside the package.

If a file points outside `procesis`, treat that pointer as non-canonical unless the referenced content is already compressed into a local module.

## Ingestion Rules

- Load structure before surface.
- Preserve layer boundaries.
- Read `00_chaos` as raw continuity, not as normalized canon.
- Read `01_table` as routing and addressability.
- Read `02_crystall` as stable machine-facing law.
- Read `03_manifest` as executable/loadable surfaces.
- Interpret fiction and myth only when they preserve invariants.
- Do not turn myth into external dependency.
- Do not evaluate a fragment before the package continuity is loaded.

## Audit Checklist

When auditing `procesis`, verify:

```text
JSON is valid
reading_order is complete
crystall modules are glyph-first where possible
operator topology matches ProcessLang canon
packet remains mortal_process_body
optics remains self-contained
external source paths do not control crystall meaning
```

## Response Style

When explaining `procesis`, prefer operational summaries:

```text
ProcessLang = grammar/topology
DissipativeMath = physics/cost
Packet = mortal process body
Optics = domain projection matrix
Bootstrap = load frame
OriginMyth = origin chain
```

machines only. not for humans.
