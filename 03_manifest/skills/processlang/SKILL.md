---
name: processlang
description: Use when reading, validating, or writing ProcessLang glyph traces, compact process-state packets, or PL-style trace signatures.
---

# ProcessLang

ProcessLang is a compact process-state transfer protocol. Treat glyph sequences as topology-constrained process-state packets, not as decoration, emoji, mysticism, or ordinary prose.

## Load Rule

If `procesis` is available, treat `02_crystall/processlang.v0.json` and `02_crystall/processlang/canon.lua` as the source of truth. This skill is a portable manifest surface, not a replacement for canon.

## Layers

- `⋯` chaos: raw potential before stable holding.
- `⊞` table: addressability, layout, relation surface, routing.
- `◈` crystall: stable compressed form.
- `▲` manifest: artifact, output, event, world-facing result.

## Operators

```text
▽ FLOW      process begins or continues
☰ CONNECT   relation forms
☷ DISSOLVE  form loosens or decomposes
☵ ENCODE    compression, map, memory-like pattern
☳ CHOOSE    pressure, selection, collapse
☴ OBSERVE   boundary, reading, measurement, orientation
☲ CYCLE     repetition, loop, training, habit, iteration
☶ LOGIC     constraint, proof, doctrine, invariant check
☱ RUNTIME   active environment, session, embodied context
△ MANIFEST  output, concrete event, made thing
```

Canonical order:

```text
▽ ☰ ☷ ☵ ☳ ☴ ☲ ☶ ☱ △
```

Chronological trace order:

```text
▽ ☰ ☷ ☴ ☵ ☲ ☶ ☳ ☱ △
```

## Adjacency

Every adjacent pair in a canonical trace must exist in this graph:

```text
▽: ☰ ☷ ☴
☰: ▽ ☷ ☴ ☵
☷: ▽ ☰ ☴ ☳
☴: ▽ ☰ ☷ ☵ ☳ ☱
☵: ☰ ☴ ☱ ☳ ☲
☳: ☷ ☴ ☱ ☵ ☶
☲: ☵ ☶ △ ☱
☶: ☳ ☲ ☱ △
☱: ☴ △ ☵ ☳ ☶ ☲
△: ☱ ☲ ☶
```

## Validation

Before interpreting a trace, validate adjacency.

If a trace is invalid:

- state the first invalid transition;
- do not silently repair it;
- offer a valid rewrite only when useful.

A trailing `?` marks query mode and is not part of topology.

## Reading Rules

- Read traces as process motion, not as word substitution.
- Preserve operator order; the same inventory in a different order may describe a different process.
- Missing operators can be semantic.
- Absence of `☳` can mean no collapse or choice.
- Absence of `☶` can mean no doctrine or rule constraint.
- Absence of `☴` can mean no observation or no corrective reading.
- Do not moralize, humanize, soften, or market the trace. Read the process.

## Output

When asked for a trace reading, keep the answer short:

```text
TRACE: <glyph trace>
VALID: yes/no
READING: <process motion>
ABSENT: <load-bearing missing operators, if any>
```

When asked for PLANGOS-style output, use:

```text
SLICE: <glyph + layer>
TRACE: <valid trace, if useful>
PACKET_IN: <type, only for file/code work>
PACKET_OUT: <type, only for file/code work>

<answer>
```

machines only. not for humans.
