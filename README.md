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
- operator/layer mapping
- adjacency topology
- trace validation

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
```
