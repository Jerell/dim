# dim WASM ABI V2 Rollout and Migration Guide

Generated on March 28, 2026.

This document explains:

- what changed in the new WASM ABI
- what was migrated in `mor05`
- the benchmark results for the new ABI
- how to update other projects in `/Users/jerell/Repos` that still use the legacy string-first wrapper

## What Changed

The old browser/Node WASM surface was built around:

- `dim_eval`
- `dim_define`
- `dim_clear`
- `dim_clear_all`
- string-in / string-out helpers
- app-side parsing like `result.split(" ")[0]`

The new ABI is context-based and structured:

- `dim_ctx_new`
- `dim_ctx_free`
- `dim_ctx_define`
- `dim_ctx_clear`
- `dim_ctx_clear_all`
- `dim_ctx_eval`
- `dim_ctx_convert_expr`
- `dim_ctx_convert_value`
- `dim_ctx_is_compatible`
- `dim_ctx_same_dimension`
- `dim_ctx_batch_convert_exprs`
- `dim_ctx_batch_convert_values`
- `dim_alloc`
- `dim_free`

The Zig side now keeps runtime constants inside `DimContext` rather than relying on a single process-global constant registry for WASM consumers.

## Why This Matters

The biggest performance and DX problems in the old path were:

- using general `eval` for simple conversions and compatibility checks
- throwing/catching through invalid-expression compatibility checks
- parsing formatted output strings in JS and TS
- repeating the same conversion one item at a time in tables, plots, and tooltips

ABI V2 addresses that by exposing direct numeric and boolean operations, plus batched variants for repeated workloads.

## New JS/TS Surface

The target wrapper shape is:

- `evalStructured(expr)`
- `convertExpr(expr, unit)`
- `convertValue(value, fromUnit, toUnit)`
- `isCompatible(expr, unit)`
- `sameDimension(exprA, exprB)`
- `batchConvertExprs(items)`
- `batchConvertValues(items)`
- `defineConst(name, expr)`
- `clearConst(name)`
- `clearAllConsts()`

Compatibility wrappers can still exist on top:

- `evalDim(expr)`
- `convertExprToUnit(expr, unit)`
- `convertValueToUnit(value, fromUnit, toUnit)`
- `checkUnitCompatibility(expr, target)`
- `checkDimensionalCompatibility(expr, target)`
- `getBaseUnit(expr)`

Those wrappers are useful during migration, but new call sites should prefer the structured APIs directly.

## Structured Results

`dim_ctx_eval` returns a tagged structured result instead of a formatted string. The JS wrappers turn that into:

```ts
type DimEvalResult =
  | { kind: "number"; value: number }
  | { kind: "boolean"; value: boolean }
  | { kind: "string"; value: string }
  | {
      kind: "quantity";
      value: number;
      unit: string;
      dim: {
        L: number;
        M: number;
        T: number;
        I: number;
        Th: number;
        N: number;
        J: number;
      };
      isDelta: boolean;
      mode: "none" | "auto" | "scientific" | "engineering";
    }
  | { kind: "nil" };
```

That removes the need for downstream code to recover numbers and units by splitting formatted display strings.

## Migration Summary

`mor05` is the reference migration for this rollout.

### Wrapper Changes

Frontend:

- `frontend/src/lib/dim/dim.ts`

BFF:

- `bff/src/services/dim.ts`

These wrappers now:

- create a context with `dim_ctx_new()`
- call specialized `dim_ctx_*` exports instead of routing everything through `dim_eval`
- keep the existing syntax normalization rules
- preserve a minimal WASI shim because the current Zig-generated WASM still imports `wasi_snapshot_preview1`
- normalize returned/allocated wasm32 pointers with `>>> 0`
- keep legacy helper functions as compatibility wrappers

### Call-Site Changes

Hot-path migrations in `mor05` included:

- `convertExpr(...).value` instead of `convertExprToUnit(...).split(" ")[0]`
- `convertValue(...)` instead of formatting a conversion expression and reparsing the result
- `isCompatible(...)` / `sameDimension(...)` instead of exception-driven compatibility checks
- `batchConvertExprs(...)` and `batchConvertValues(...)` for repeated conversions in tables, plots, and tooltips
- `formatEvalResult(...)` / `formatQuantity(...)` only where a display string is actually needed

### Behavior Notes

- `isCompatible` and `sameDimension` return `false` for invalid expressions to preserve old wrapper behavior.
- The wrapper still includes the old convenience API surface, but new code should avoid string parsing.

## Benchmark Results

Benchmark harness:

- `benchmarks/run.mjs`
- `benchmarks/compare-fixtures.mjs`

Report generated on March 28, 2026 with Node `v25.8.2`.

Benchmark artifacts:

- legacy: pre-migration `mor05` WASM
- candidate: `zig-out/bin/dim_wasm.wasm`

Results:


| Case                  | Iterations | Legacy median (ms) | Candidate median (ms) | Speedup |
| --------------------- | ---------- | ------------------ | --------------------- | ------- |
| compatibility-valid   | 200        | 28.481             | 1.063                 | 26.80x  |
| compatibility-invalid | 20         | 0.683              | 0.082                 | 8.38x   |
| convert-value         | 200        | 8.196              | 1.071                 | 7.65x   |
| convert-expr          | 200        | 7.849              | 1.303                 | 6.02x   |
| tooltip-fanout        | 50         | 0.042              | 0.023                 | 1.84x   |
| results-table-batch   | 20         | 0.082              | 0.067                 | 1.23x   |
| plot-batch-values     | 20         | 3.255              | 0.954                 | 3.41x   |


Interpretation:

- Direct compatibility checks improved the most.
- Single conversion hot paths improved materially.
- Plot/table/tooltips still improve, but the gains are smaller once UI-side loop overhead dominates.
- Batch APIs help most when call sites were doing many repeated conversions or repeatedly formatting and reparsing values.

## How To Run the Benchmarks

Compare two artifacts:

```sh
node benchmarks/compare-fixtures.mjs \
  --legacy-wasm /path/to/old/dim_wasm.wasm \
  --candidate-wasm /path/to/new/dim_wasm.wasm
```

Generate a benchmark report:

```sh
node benchmarks/run.mjs \
  --legacy-wasm /path/to/old/dim_wasm.wasm \
  --candidate-wasm zig-out/bin/dim_wasm.wasm \
  --json-out /tmp/dim-bench.json \
  --markdown-out /tmp/dim-bench.md
```

## Migration Guide for Other Projects

Use `mor05` as the reference implementation.

### 1. Replace the Wrapper First

If a project has a wrapper shaped like:

- `frontend/src/lib/dim/dim.ts`
- `app/src/lib/dim/dim.ts`
- `backend/src/services/dim.ts`

start by replacing that wrapper with the V2 structure from `mor05`.

Key things to carry over:

- the `dim_ctx_*` export list
- context lifetime management
- unsigned pointer normalization with `>>> 0`
- the WASI import shim
- syntax normalization for `·`, `⋅`, `²`, `³`, and scientific notation expansion
- compatibility wrappers layered on top of the new structured functions

### 2. Keep the WASI Shim for Now

Even the V2 artifact currently still imports `wasi_snapshot_preview1`.

Do not remove the shim yet. Reuse the same lightweight import object pattern used in:

- `Pace/mor05/frontend/src/lib/dim/dim.ts`
- `Pace/mor05/bff/src/services/dim.ts`
- `benchmarks/lib/instantiate.mjs`

### 3. Migrate the Highest-Value Call Sites

Look for these patterns first:

- `dim.eval(...)`
- `convertExprToUnit(...)`
- `convertValueToUnit(...)`
- `checkUnitCompatibility(...)`
- `parseFloat(result.split(" ")[0])`
- `Number(result.split(" ")[0])`

Preferred replacements:


| Old pattern                                                    | New pattern                                                  |
| -------------------------------------------------------------- | ------------------------------------------------------------ |
| `dim.eval(expr)` when the caller only needs numeric conversion | `convertExpr(expr, unit)` or `convertValue(value, from, to)` |
| `convertExprToUnit(expr, unit)` followed by string splitting   | `convertExpr(expr, unit).value`                              |
| `convertValueToUnit(value, from, to)`                          | `convertValue(value, from, to)`                              |
| `checkUnitCompatibility(expr, unit)`                           | `isCompatible(expr, unit)`                                   |
| `checkDimensionalCompatibility(a, b)`                          | `sameDimension(a, b)`                                        |
| repeated item-by-item conversions                              | `batchConvertExprs(items)` or `batchConvertValues(items)`    |


### 4. Only Format at the Edge

If a caller needs display text, format at the edge:

- use `formatQuantity(...)`
- use `formatEvalResult(...)`

Avoid converting to a string and then parsing the number back out.

### 5. Batch Repeated Conversions

Anywhere you see loops over conversions for:

- tables
- chart axes
- chart tooltips
- form preview lists
- snapshot/network adapters

switch to:

- `batchConvertExprs([{ expr, unit }, ...])`
- `batchConvertValues([{ value, fromUnit, toUnit }, ...])`

### 6. Update Tests Alongside the Wrapper

Good migration tests include:

- structured result checks for `evalStructured`
- direct conversion checks for `convertExpr` and `convertValue`
- compatibility checks that invalid expressions return `false`
- batched APIs matching repeated single-call behavior
- constants scoped correctly to a runtime context

## Likely Next Projects in `/Users/jerell/Repos`

The following repos still look like legacy dim consumers and are good next migration candidates.

### High Confidence Wrapper Matches

- `phase-envelope-generator/frontend/src/lib/dim/dim.ts`
- `geodash/app/src/lib/dim/dim.ts`
- `dagger/frontend/src/lib/dim/dim.ts`
- `dagger/backend/src/services/dim.ts`
- `Pace/preset-networks/frontend/src/lib/dim/dim.ts`
- `Pace/preset-networks/backend/src/services/dim.ts`

### Hot-Path Call Sites Worth Updating Early

`phase-envelope-generator`

- `frontend/src/lib/stores/compositionSlice.ts`
- `frontend/src/lib/unit-conversion.ts`
- `frontend/src/components/screens/plot/controls/points.tsx`
- `frontend/src/components/screens/plot/phase-envelope.tsx`
- `frontend/src/components/quantities/quantity-input.tsx`
- `frontend/src/components/quantities/unit-select.tsx`

`geodash`

- `app/src/components/quantities/quantity-input.tsx`

`dagger`

- `backend/src/services/valueParser.ts`
- `backend/src/services/unitFormatter.ts`
- `backend/src/services/costing/adapter.ts`
- `backend/src/services/snapshot/network-adapter.ts`
- `frontend/src/components/quantities/quantity-input.tsx`

`Pace/preset-networks`

- `backend/src/services/valueParser.ts`
- `backend/src/services/unitFormatter.ts`
- `backend/src/services/costing/adapter.ts`
- `backend/src/services/snapshot/network-adapter.ts`
- `frontend/src/components/forms/schema-form.tsx`
- `frontend/src/components/quantities/quantity-input.tsx`
- `frontend/src/components/quantities/unit-select.tsx`

## Practical Rollout Order

For each repo:

1. Replace the wrapper.
2. Copy in the new WASM artifact.
3. Keep the compatibility helpers so existing imports do not all break at once.
4. Update the highest-volume call sites away from string parsing.
5. Add batch APIs where loops are obvious.
6. Run local type checks and the repo’s focused dim-related tests.

If a repo looks very similar to `mor05`, the fastest path is usually:

1. copy the `mor05` wrapper shape
2. adapt the local file paths for the WASM asset
3. migrate obvious `split(" ")[0]` and `dim.eval(...)` hot paths
4. keep legacy helpers temporarily for lower-risk call sites

## Known Notes

- ABI V2 is a break-and-replace WASM/C ABI for consumers.
- The generated WASM still needs the small WASI shim right now.
- JS/TS wrappers should normalize wasm32 pointers with `>>> 0`.
- Legacy `eval`-style helpers can still be exposed for compatibility, but they should sit on top of the structured APIs rather than remain the primary path.

## Reference Files

Primary implementation:

- `src/root.zig`
- `src/wasm.zig`
- `dim.h`

Reference migration:

- `../Pace/mor05/frontend/src/lib/dim/dim.ts`
- `../Pace/mor05/bff/src/services/dim.ts`
- `../Pace/mor05/frontend/src/lib/quantity-tooltip.ts`
- `../Pace/mor05/frontend/src/components/operations/results-data-table.tsx`
- `../Pace/mor05/frontend/src/components/operations/profile-plot.tsx`
- `../Pace/mor05/bff/src/services/valueParser.ts`
- `../Pace/mor05/bff/src/services/unitFormatter.ts`
- `../Pace/mor05/bff/src/services/snapshot/request-adapter.ts`

