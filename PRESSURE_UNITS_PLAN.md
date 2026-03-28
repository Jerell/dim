# Pressure Units Plan

## Goal

Add native support for `atm`, `bara`, and `barg` to `dim` without breaking existing `bar` behavior, while making pressure deltas display as `bar` rather than `bara` or `barg`.

## Current State

- The built-in SI registry only defines `Pa` and `bar` for pressure in [src/registry/si.zig](/Users/jerell/Repos/dim/src/registry/si.zig#L27) and [src/registry/si.zig](/Users/jerell/Repos/dim/src/registry/si.zig#L28).
- `Unit` already supports affine conversions through `scale` and `offset` in [src/unit.zig](/Users/jerell/Repos/dim/src/unit.zig#L6), so `barg` is mechanically representable.
- Pressure-specific absolute-vs-delta semantics are not modeled today.
  - Formatting always uses `fromCanonical(...)`, even for deltas, in [src/format.zig](/Users/jerell/Repos/dim/src/format.zig#L75).
  - Quantity arithmetic only special-cases temperature dimensions in [src/quantity.zig](/Users/jerell/Repos/dim/src/quantity.zig#L116).
- `mor05` currently handles `bara`, `barg`, and `atm` at the application layer instead of in `dim`.
  - Frontend tooltip logic derives them manually from `bar` in [frontend/src/lib/quantity-tooltip.ts](/Users/jerell/Repos/Pace/mor05/frontend/src/lib/quantity-tooltip.ts#L51).
  - The BFF maps snapshot `bara` to plain `bar` in [bff/src/services/snapshot/request-adapter.ts](/Users/jerell/Repos/Pace/mor05/bff/src/services/snapshot/request-adapter.ts#L513).

## Desired Semantics

- `atm` should be a regular multiplicative pressure unit.
  - `1 atm = 101325 Pa = 1.01325 bar`
- `bara` should represent absolute pressure in bar.
  - Numerically it is the same unit as absolute `bar`.
  - It should be available as an explicit input and output unit.
- `barg` should represent gauge pressure referenced to standard atmosphere.
  - `0 barg = 1.01325 bara = 101325 Pa`
- Existing `bar` behavior should remain backwards-compatible.
  - Existing expressions using `bar` should continue to work as absolute bar.
  - We should not reinterpret plain `bar` input as delta-only.
- Pressure deltas should display as `bar`.
  - Example: `5 bara - 2 bara` should format as `3 bar`.
  - Example: `5 barg - 2 barg` should also format as `3 bar`.

## Recommendation

Implement this in phases. `atm` and `bara` are straightforward. `barg` should only land together with delta-aware affine conversion and formatting, otherwise we will get incorrect results for pressure differences.

## Proposed Design

### 1. Add `atm`

- Add `atm` as a first-class unit in the SI registry.
- Suggested definition:
  - `dim = Pressure`
  - `scale = 101325.0`
  - `offset = 0.0`
  - `symbol = "atm"`
- This is a low-risk additive change.

### 2. Add `bara`

- Add `bara` as a first-class unit, not just an alias.
- Suggested definition:
  - `dim = Pressure`
  - `scale = 1e5`
  - `offset = 0.0`
  - `symbol = "bara"`
- Recommendation: keep `bar` unchanged for backwards compatibility and add `bara` as an explicit absolute-pressure spelling.
- Why not only an alias:
  - The current alias model resolves to the target unit and loses the original symbol.
  - If `as bara` should preserve `bara` as the requested display unit, it needs to be a real unit or a display-preserving alias mechanism.

### 3. Add `barg`

- Add `barg` as a first-class affine unit.
- Suggested definition:
  - `dim = Pressure`
  - `scale = 1e5`
  - `offset = 1.01325`
  - `symbol = "barg"`
- This keeps canonical pressure in absolute `Pa`.
- With the current `Unit` math, `toCanonical(v)` for `barg` would produce:
  - `(v + 1.01325) * 1e5`

### 4. Add Delta-Aware Affine Conversion

- Extend the conversion helpers so absolute values and deltas do not use the same offset behavior.
- Proposed API shape inside `Unit`:
  - `toCanonicalValue(v: f64, is_delta: bool) f64`
  - `fromCanonicalValue(v: f64, is_delta: bool) f64`
- Behavior:
  - Absolute value: `(v + offset) * scale`
  - Delta value: `v * scale`
- This matters for `barg` because:
  - `1 barg` absolute should convert to `2.01325 bar(a)` worth of absolute pressure.
  - A delta of `1 bar` should stay `1e5 Pa`, not pick up atmospheric offset.
- Update formatting code in [src/format.zig](/Users/jerell/Repos/dim/src/format.zig#L75) to use delta-aware conversion when `q.is_delta` is true.

### 5. Add Pressure Delta Display Rules

- When a pressure quantity is a delta, its preferred display symbol should be `bar` for the `bar`/`bara`/`barg` family.
- Recommendation for the first implementation:
  - Keep this pressure-specific instead of trying to solve all affine families generically at once.
  - Add a small helper in formatting or unit selection that maps:
    - absolute `bar` -> `bar`
    - absolute `bara` -> `bara`
    - absolute `barg` -> `barg`
    - delta in any of those families -> `bar`
- This matches the product rule you called out without forcing a larger abstraction before we need it.

### 6. Revisit Arithmetic Semantics

- Today only temperature gets absolute-vs-delta arithmetic rules in [src/quantity.zig](/Users/jerell/Repos/dim/src/quantity.zig#L116).
- Pressure will need similar semantics once `barg` is first-class.
- Minimum rules we want:
  - absolute + delta -> absolute
  - delta + absolute -> absolute
  - absolute - absolute -> delta
  - absolute - delta -> absolute
  - delta - delta -> delta
- Recommendation:
  - Start with a pressure-specific implementation if that keeps the patch small.
  - If more affine unit families show up later, lift the logic into a generalized affine-family abstraction.

## Phased Rollout

### Phase 1

- Add `atm`
- Add tests for parse, eval, and conversion

### Phase 2

- Add `bara` as a first-class display-preserving unit
- Keep `bar` working exactly as it does today
- Add tests for `bar` and `bara` equivalence

### Phase 3

- Add delta-aware affine conversion helpers
- Update formatting paths to respect `is_delta`
- Add `barg`
- Add pressure-specific delta display rule mapping pressure deltas to `bar`

### Phase 4

- Update quantity arithmetic so absolute pressure subtraction produces deltas
- Remove the `mor05` pressure workarounds after runtime parity is confirmed

## Test Plan

- Registry and parsing:
  - `1 atm as Pa`
  - `1 atm as bar`
  - `1 bara as bar`
  - `1 bar as bara`
  - `0 barg as bara`
  - `0 barg as Pa`
- Formatting:
  - `1 atm` formats as `1 atm` when explicitly requested
  - `1 bara as bara` preserves `bara`
  - `1 barg as barg` preserves `barg`
- Delta behavior:
  - `5 bara - 2 bara` formats as `3 bar`
  - `5 barg - 2 barg` formats as `3 bar`
  - converting a pressure delta through the `bar` family does not add atmospheric offset
- Compatibility and structured eval:
  - `atm`, `bara`, `barg`, `bar`, and `Pa` all interoperate under the pressure dimension

## Migration Notes

- Do not remove the current `mor05` tooltip and BFF workarounds until `dim` covers:
  - direct `atm` conversion
  - direct `bara` conversion with preserved display symbol
  - direct `barg` conversion
  - correct delta formatting as `bar`
- Once runtime support is in place, the app-layer pressure special cases should be removable.

## Open Questions

- Should `bara` be allowed as both input and explicit output from day one, or only as an input synonym initially?
- Should `bar` remain the default absolute output for pressure unless `bara` was explicitly requested?
- Do we want the pressure delta rule to stay pressure-specific, or should we add a more general unit-family concept now?
- Do we want `atm` included in auto-formatting choices, or only as an explicit conversion target?

## Suggested First Patch

If we want the safest first follow-up:

1. Add `atm`
2. Add `bara` as a first-class unit
3. Add tests proving `bar` and `bara` are numerically identical for absolute pressure
4. Leave `barg` for the next patch together with delta-aware affine handling

That sequence gives immediate value without locking in the wrong semantics for gauge pressure.
