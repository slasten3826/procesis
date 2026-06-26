# procesis

Machine-facing process-origin corpus.

Load as a four-layer packet:

```text
00_chaos     raw source
01_table     address map
02_crystall  canon
03_manifest  loadable output
```

## Layer Order

1. `00_chaos`
2. `01_table`
3. `02_crystall`
4. `03_manifest`

Do not flatten the layers.

## Current Entry Order

```text
01_table/layers.v0.json
02_crystall/processlang.v0.json
02_crystall/dissipative_math.v0.json
02_crystall/packet.v0.json
02_crystall/packet.mortality_myth.v0.json
02_crystall/optics.v0.json
02_crystall/bootstrap.v0.json
02_crystall/origin.myth.v0.json
```

`03_manifest/capsule.full.v0.json` is not generated yet.

## Current Canon

```text
02_crystall/processlang/canon.lua
```

`canon.lua` is the ProcessLang source of truth for:

- four abstraction layers
- ten operators
- canonical operator order from Kabbalah binding: `▽ ☰ ☷ ☵ ☳ ☴ ☲ ☶ ☱ △`
- operator/layer mapping
- adjacency topology
- trace validation

`02_crystall/dissipative_math.v0.json` is the current process physics module:

- structure has cost
- existence requires sustain
- decay is default
- choice requires pressure
- truth requires reproducible stability
- logic constrains generated flow

`02_crystall/packet.v0.json` defines Packet as mortal process body:

- existence has cost
- continuation must be paid
- death is semantic, not only failure
- residue may survive while identity need not
- manifestation ends local life

`02_crystall/packet.mortality_myth.v0.json` preserves the Doom-derived myth of Packet mortality:

- motion without cost is false life
- body continuity is not packet identity continuity
- bad life may kill the current packet
- death may pass residue without resurrection

`02_crystall/optics.v0.json` defines optics as operator-centered domain projections:

- one ProcessLang operator maps to many domain readings
- domain changes interpretation, not operator identity
- English crystall form, self-contained, no external source dependency
- `ExampleLens` is excluded as a template

`03_manifest/skills.v0.json` indexes the current portable manifest skills:

- `processlang`
- `procesis-loader`

## Raw Origin

```text
00_chaos/slop.raw.txt
```

Raw artifact. Preserve unchanged.

## Status

```text
stage: early crystallization
capsule: pending
runtime: pending
manifest skills: processlang, procesis-loader
```
