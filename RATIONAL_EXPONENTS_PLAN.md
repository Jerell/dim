# Rational Exponents Plan

## Goal

Add first-class rational exponent support to `dim` so dimensional quantities can carry exact non-integer powers like `L^(1/2)` or `T^(-3/2)` instead of only accepting fractional powers that collapse back to integer dimensions.

This should work across:

- compile-time `Quantity(...)` typing
- runtime expression evaluation
- unit parsing after `as`
- normalized unit formatting
- the exported C ABI

## Current State

- `Dimension` stores each base exponent as `i32` in [src/Dimension.zig](/Users/jerell/Repos/dim/src/Dimension.zig#L1).
- Compile-time `Quantity.pow(...)` accepts float exponents, but only if `D * exp` rounds to integers in [src/quantity.zig](/Users/jerell/Repos/dim/src/quantity.zig#L26) and [src/quantity.zig](/Users/jerell/Repos/dim/src/quantity.zig#L181).
- Runtime `display_quantity ^ number` follows the same rule in [src/runtime.zig](/Users/jerell/Repos/dim/src/runtime.zig#L135).
- There is already a regression test proving the current partial behavior: `(16 m^2)^0.5 -> 4 m` in [src/main.zig](/Users/jerell/Repos/dim/src/main.zig#L362).
- Unit expressions after `as` only accept integer exponents today because `UnitExpr.exponent` is `i32` and `parseUnitTerm(...)` truncates the parsed number in [src/parser/parser.zig](/Users/jerell/Repos/dim/src/parser/parser.zig#L353).
- Unit normalization and formatting assume integer exponents throughout [src/format.zig](/Users/jerell/Repos/dim/src/format.zig#L104).
- The C ABI exposes dimensions as seven `int32_t` fields in [dim.h](/Users/jerell/Repos/dim/dim.h#L46) and [src/wasm.zig](/Users/jerell/Repos/dim/src/wasm.zig#L32), so wrappers cannot observe rational dimensions even if the internals gained them.

## What Exists Today

Today `dim` supports this:

- `(16 m^2)^0.5 -> 4 m`
- `(1 / s^2)^0.5 -> 1 / s`

But not this:

- `1 m^0.5`
- `1 m^(1/2) as m^(1/2)`
- `(1 m)^0.5`
- `1 Pa^0.5`
- carrying exact `1/3`, `1/2`, or `-3/2` exponents through formatting and FFI

So the current behavior is better described as:

- fractional exponent support with integer-dimension closure

not:

- true rational exponent support

## Desired Semantics

- Dimensions should be exact, not float-approximated.
- `m^(1/2)`, `m^(3/2)`, `s^(-1/2)`, and similar units should be representable internally.
- Raising a dimensional quantity to a rational power should produce an exact rational dimension.
- Integer exponent behavior should remain unchanged.
- Runtime dimensional exponents should come from exact rational syntax or an explicit `Rational` API, not from best-effort reconstruction of arbitrary `f64` values.
- Irrational or non-representable exponents on dimensional quantities should still error.
  - Example: `(1 m)^pi` should not silently produce an approximate dimension.
- Formatting should preserve rational exponents in a stable canonical form.
- When a normalized unit contains any non-integer exponent, canonical output should use `*`-joined signed exponents rather than numerator/denominator rewriting.
  - Examples: `m^(1/2)`, `m^(1/2)*s^(-1/2)`, `kg^(1/2)*m^(-1/2)*s^(-1)`.
- The current structured ABI should expose rational dimensions directly, even if that changes the existing struct layout.
- `as` should remain a conversion operator, not a type annotation. Acceptance tests after `as` must start from a quantity that already has the target dimension.

## Recommendation

Implement this as exact rational arithmetic, not as `f64` exponents with tolerance checks.

Recommendation for scope:

- treat this as one coordinated breaking change in `dim`
- update local consumers under `/Users/jerell/Repos` as part of the same work
- use internal sequencing for safety, but consider the feature complete only when parser, formatting, ABI, and tests all pass together

Recommendation for the core model:

- add a small `Rational` type
- make each `Dimension` component a normalized `Rational`
- keep integer-focused convenience constructors and constants so existing code stays readable

This is a deeper change than the pressure-units work. It touches the type system, parser, formatting, and ABI all at once, so it should be implemented in phases internally even if it ships as one coordinated feature.

## Proposed Design

### 1. Add an Exact `Rational` Type

Introduce a small value type for exponents, for example:

```zig
pub const Rational = struct {
    num: i32,
    den: u32, // always > 0
};
```

Requirements:

- always normalized to lowest terms
- denominator always positive
- `0/x` canonicalizes to `0/1`
- helpers for `add`, `sub`, `mul`, `div`, `negate`, `eql`, `isInteger`

Why this shape:

- exact equality stays deterministic
- `Quantity(Dim)` can still use `Dimension` as a comptime parameter
- formatting can render fractions without guessing from floats

### 2. Change `Dimension` to Use Rational Components

Update [src/Dimension.zig](/Users/jerell/Repos/dim/src/Dimension.zig#L1) so each field is a `Rational`, not `i32`.

Recommended API shape:

- `Dimension.initInts(...)` for existing integer-based call sites
- `Dimension.initRationals(...)` for explicit non-integer use
- `Dimension.add(...)`
- `Dimension.sub(...)`
- `Dimension.mulByInt(...)`
- `Dimension.mulByRational(...)`
- `Dimension.eql(...)`

Keep the built-in constants in [src/Dimension.zig](/Users/jerell/Repos/dim/src/Dimension.zig#L56) using integer helpers so they remain easy to read.

### 3. Split Numeric Power From Dimensional Power

Today `Quantity.pow(...)` and runtime `powDisplayFloat(...)` use `f64` exponents and then try to coerce the resulting dimension back to integers in [src/quantity.zig](/Users/jerell/Repos/dim/src/quantity.zig#L26) and [src/runtime.zig](/Users/jerell/Repos/dim/src/runtime.zig#L135).

Recommended replacement:

- `Quantity.powInt(exponent: i32)`
- `Quantity.powRational(exponent: Rational)`
- `Unit.powInt(exponent: i32, symbol: []const u8)`
- `Unit.powRational(exponent: Rational, symbol: []const u8)`
- `powDisplayInt(...)`
- `powDisplayRational(...)`

Compatibility rule:

- keep an integer-only convenience wrapper like `pow(...)` only if it forwards to `powInt(...)`
- remove the current float-based dimensional `pow(...)` path
- pure number bases can still use normal `f64` power rules
- compile-time dimensional callers should use an explicit `Rational` helper such as `Rational.init(1, 2)` rather than float reconstruction

This keeps dimensional math exact while leaving scalar math flexible.

### 4. Add Exact Rational Exponent Parsing

There are two separate parser surfaces to update.

#### Expression powers

For general expressions in [src/parser/expressions.zig](/Users/jerell/Repos/dim/src/parser/expressions.zig#L175):

- keep `number ^ number` as normal floating-point numeric math
- for `quantity ^ exponent`, inspect the exponent syntax and require it to lower to an exact `Rational`
- if the exponent is not one of the supported exact-rational forms, return a dedicated dimensional-power error such as `NonRationalDimensionalExponent`

Supported v1 exponent syntax for dimensional powers:

- integer literal: `2`
- decimal literal: `0.5`
- grouped ratio of integers: `(1/2)`, `(-3/2)`

Recommendation:

- parse and preserve exact rational exponents from syntax, instead of reconstructing them heuristically from already-evaluated `f64`
- reject arbitrary exponent expressions like `pi`, `sqrt(2)`, or `(1/2 + 0)` for dimensional powers

#### Unit-expression powers

For unit expressions after `as`, [src/parser/parser.zig](/Users/jerell/Repos/dim/src/parser/parser.zig#L353) currently stores `i32 exponent`.

Update this so unit expressions can accept and preserve:

- `m^0.5`
- `m^(1/2)`
- `s^(-3/2)`

Unit-expression grammar rule:

- store the parsed exponent as `Rational`
- allow literal exact-rational syntax only
- treat `m^pi` and `m^(sqrt(2))` in unit expressions as parse errors, not best-effort runtime coercions

Recommendation for normalized output:

- use `^(num/den)` for non-integer exponents
- keep existing integer notation for integer-only exponents

That gives unambiguous output and avoids inventing Unicode fractional superscripts.

### 5. Update Formatting and Normalization

[src/format.zig](/Users/jerell/Repos/dim/src/format.zig#L104) currently assumes exponents are integers in matching, factoring, and string emission.

Minimum changes needed:

- base-unit and derived-unit matching must compare rational dimensions exactly
- normalization should still prefer exact registry matches first
- when no exact registry unit matches, canonical unit strings must emit rational exponents

Recommended canonical notation:

- `m^(1/2)`
- `s^(-3/2)`
- `m^(1/2)*s^(-1/2)`
- `kg^(1/2)*m^(-1/2)*s^(-1)`

Formatting rule for the first patch:

- if every exponent is an integer, keep existing integer-focused formatting behavior
- if any exponent is non-integer, emit the whole canonical unit string as a `*`-joined product with signed exponents
- do not rewrite rational outputs into `1/(...)` form in the first patch

Recommendation for factoring:

- keep derived-unit factoring conservative for the first patch
- only factor a registry unit when its dimension exactly matches the full target dimension
- do not emit rational powers of registry aliases in the first patch
- avoid trying to invent algebraically clever factorizations until the exact-rational base path is stable

### 6. Keep Affine Units Out of Fractional Powers

[src/Unit.zig](/Users/jerell/Repos/dim/src/Unit.zig#L50) already forbids powers of affine units.

That should stay true.

Examples:

- `C^2` should remain invalid
- `F^(1/2)` should remain invalid
- `barg^(1/2)` should remain invalid once gauge pressure lands

Fractional exponent support should not weaken affine-unit safety.

### 7. Update the Existing ABI for Rational Dimensions

The current ABI in [dim.h](/Users/jerell/Repos/dim/dim.h#L46) and [src/wasm.zig](/Users/jerell/Repos/dim/src/wasm.zig#L32) cannot represent rational exponents.

Recommendation:

- make breaking changes to the current `DimEvalResult` and `DimQuantityResult`
- update [dim.h](/Users/jerell/Repos/dim/dim.h), [src/wasm.zig](/Users/jerell/Repos/dim/src/wasm.zig), and local consumers together
- use flat numerator/denominator field pairs for each dimension component so the Wasm memory layout stays easy to consume from TypeScript and Rust
- encode every integer exponent as `n/1`

Suggested shape:

```c
typedef struct DimQuantityResult {
  uint32_t mode;
  uint32_t is_delta;
  double value;
  int32_t dim_L_num;
  uint32_t dim_L_den;
  int32_t dim_M_num;
  uint32_t dim_M_den;
  /* ... */
  uintptr_t unit_ptr;
  size_t unit_len;
} DimQuantityResult;
```

Important consequence:

- the local wrappers in `/Users/jerell/Repos/Pace/mor05/frontend`, `/Users/jerell/Repos/Pace/mor05/bff`, and `/Users/jerell/Repos/dagger` must be patched in the same implementation because they currently assume integer dimension fields and hardcoded struct sizes

## Implementation Sequence

This should ship as one coordinated feature, but the internal sequence should be:

- Add `Rational`
- Convert `Dimension` internals to exact rationals
- Preserve all existing integer-based APIs via helper constructors
- Replace `powDimFloat(...)` with exact rational dimension multiplication
- Add runtime and compile-time rational power helpers
- Extend unit-expression parsing to accept rational exponents
- Extend general expression power handling so dimensional powers require exact rational exponents
- Update `format.normalizeUnitString(...)` and related formatting paths for rational dimensions
- Break the current ABI field layout to expose rational dimensions directly
- Patch local consumers and wrapper docs alongside the ABI change
- Add and pass new tests for core logic, parser/formatter behavior, ABI, and local consumers

## Test Plan

New behavior is not complete until tests exist for the exact expected outputs below.

### Library tests in [src/root.zig](/Users/jerell/Repos/dim/src/root.zig)

- `Rational.init(2, 4)` normalizes to `1/2`
- `Rational.init(-2, -4)` normalizes to `1/2`
- `Rational.init(0, 5)` normalizes to `0/1`
- `Dimension.mulByRational(Dimensions.Length, Rational.init(1, 2))` yields `L^(1/2)`
- `Quantity(Dimensions.Area).init(16).powRational(Rational.init(1, 2))` has dimension `Length` and value `4`
- `Quantity(Dimensions.Length).init(9).powRational(Rational.init(1, 2))` has dimension `L^(1/2)` and value `3`
- `Unit.powRational(...)` computes exact rational dimensions and multiplicative scale correctly for non-affine units
- `Unit.powRational(...)` rejects affine units

### End-to-end parser, runtime, and formatting tests in [src/main.zig](/Users/jerell/Repos/dim/src/main.zig)

- `(16 m^2)^0.5` evaluates to value `4`, dimension `Length`, and unit string `m`
- `(9 m)^0.5` evaluates to value `3`, dimension `L^(1/2)`, and unit string `m^(1/2)`
- `(1 m/s)^0.5` evaluates to value `1` and unit string `m^(1/2)*s^(-1/2)`
- `(1 m)^1.5` evaluates to value `1` and unit string `m^(3/2)`
- `1 Pa^0.5` evaluates to value `1` and unit string `kg^(1/2)*m^(-1/2)*s^(-1)`
- `1 m^(1/2) as m^(1/2)` round-trips as value `1` with unit string `m^(1/2)`
- `1 s^(-1/2) as s^(-1/2)` round-trips as value `1` with unit string `s^(-1/2)`

### Rejection tests in [src/main.zig](/Users/jerell/Repos/dim/src/main.zig) and parser-focused tests where appropriate

- `1 C^0.5` errors because affine units cannot be exponentiated fractionally
- `1 C^(1/2)` errors for the same reason
- `1 barg^0.5` once gauge pressure exists
- `(1 m)^pi` returns `NonRationalDimensionalExponent`
- `(1 m)^(sqrt(2))` returns `NonRationalDimensionalExponent`
- `1 m as m^pi` is a parse error in unit-expression grammar
- `1 m as m^(sqrt(2))` is a parse error in unit-expression grammar

### ABI tests in [src/wasm.zig](/Users/jerell/Repos/dim/src/wasm.zig)

- integer dimensions are exposed as `n/1` in the updated result structs
- evaluating `(9 m)^0.5` exposes `dim_L_num = 1`, `dim_L_den = 2`
- evaluating `1 Pa^0.5` exposes `dim_M_num = 1`, `dim_M_den = 2`, `dim_L_num = -1`, `dim_L_den = 2`, `dim_T_num = -1`, `dim_T_den = 1`
- `dim_ctx_convert_expr(...)` returns rational dimensions correctly for rational target units

### Consumer verification

- patch and run the local wrappers in `/Users/jerell/Repos/Pace/mor05/frontend`, `/Users/jerell/Repos/Pace/mor05/bff`, and `/Users/jerell/Repos/dagger`
- update any hardcoded Wasm struct sizes and offsets in those consumers
- run their relevant unit or integration tests after the ABI change

## Migration Notes

- Existing code that only uses integer-dimension quantities should continue to behave the same.
- Existing formatting should remain stable for integer-only outputs.
- Code that currently relies on float-based dimensional `pow(...)` should migrate to `powRational(...)`.
- The ABI change is intentionally breaking. There is no legacy fallback in this plan.
- Local consumers in `/Users/jerell/Repos/Pace/mor05/frontend`, `/Users/jerell/Repos/Pace/mor05/bff`, and `/Users/jerell/Repos/dagger` should be updated in the same branch or coordinated set of branches.

## Deferred Questions

- Do we want to add convenience functions like `sqrt(...)` and `cbrt(...)` once `powRational(...)` exists?
- Should `Rational` be re-exported publicly from [src/root.zig](/Users/jerell/Repos/dim/src/root.zig)?
- Should derived-unit factoring ever produce rational powers of aliases, or should the first version stay base-unit oriented unless an exact alias match exists?

## Suggested Implementation Order

1. Add `Rational` and convert `Dimension` to exact rational components with integer-friendly helpers.
2. Replace float-based dimensional power logic with `powInt(...)` and `powRational(...)`.
3. Extend parser and AST paths to preserve exact rational exponents from source syntax.
4. Update normalization and formatting so rational dimensions emit canonical signed-exponent strings.
5. Change the ABI structs in place and patch the local consumers that depend on them.
6. Add and pass the new library, integration, ABI, and consumer tests before considering the feature done.
