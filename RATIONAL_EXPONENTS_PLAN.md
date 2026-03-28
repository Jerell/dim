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
- `1 as m^(1/2)`
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
- Irrational or non-representable exponents on dimensional quantities should still error.
  - Example: `m^pi` should not silently produce an approximate dimension.
- Formatting should preserve rational exponents in a stable canonical form.
- The C ABI should have a versioned path for exposing rational dimensions without losing information.

## Recommendation

Implement this as exact rational arithmetic, not as `f64` exponents with tolerance checks.

Recommendation for the core model:

- add a small `Rational` type
- make each `Dimension` component a normalized `Rational`
- keep integer-focused convenience constructors and constants so existing code stays readable

This is a deeper change than the pressure-units work. It touches the type system, parser, formatting, and ABI all at once, so it should land in phases.

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
- `Unit.powInt(...)`
- `Unit.powRational(...)`
- `DisplayQuantity.powInt(...)`
- `DisplayQuantity.powRational(...)`

Then layer convenience overloads on top:

- integers keep using the int path
- decimal literals or `a/b` literals can lower into `Rational`
- pure number bases can still use normal `f64` power rules

This keeps dimensional math exact while leaving scalar math flexible.

### 4. Add Exact Rational Exponent Parsing

There are two separate parser surfaces to update.

#### Expression powers

For general expressions in [src/parser/expressions.zig](/Users/jerell/Repos/dim/src/parser/expressions.zig#L175):

- keep `number ^ number` as normal floating-point numeric math
- for `quantity ^ exponent`, require the exponent to be extractable as an exact rational
- if the exponent is not exactly representable as a rational under the supported syntax, return a dimensional-power error

Recommended supported exponent syntax for dimensional powers:

- integer literal: `2`
- decimal literal: `0.5`
- grouped ratio of integers: `(1/2)`, `(-3/2)`

Recommendation:

- parse and preserve exact rational exponents from syntax, instead of reconstructing them heuristically from already-evaluated `f64`

#### Unit-expression powers

For unit expressions after `as`, [src/parser/parser.zig](/Users/jerell/Repos/dim/src/parser/parser.zig#L353) currently stores `i32 exponent`.

Update this so unit expressions can accept and preserve:

- `m^0.5`
- `m^(1/2)`
- `s^(-3/2)`

Recommendation for normalized output:

- use `^(num/den)` for non-integer exponents
- keep superscripts only for integer exponents

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
- `kg*m^(1/2)/s`

Recommendation for factoring:

- keep derived-unit factoring conservative for the first patch
- only factor a registry unit when its dimension exactly matches a rational remainder target
- avoid trying to invent algebraically clever factorizations until the exact-rational base path is stable

### 6. Keep Affine Units Out of Fractional Powers

[src/Unit.zig](/Users/jerell/Repos/dim/src/Unit.zig#L50) already forbids powers of affine units.

That should stay true.

Examples:

- `C^2` should remain invalid
- `F^(1/2)` should remain invalid
- `barg^(1/2)` should remain invalid once gauge pressure lands

Fractional exponent support should not weaken affine-unit safety.

### 7. Add a Versioned ABI for Rational Dimensions

The current ABI in [dim.h](/Users/jerell/Repos/dim/dim.h#L46) and [src/wasm.zig](/Users/jerell/Repos/dim/src/wasm.zig#L32) cannot represent rational exponents.

Recommendation:

- do not silently overload the existing `dim_L`, `dim_M`, etc. integer fields
- add a new versioned ABI surface instead

Suggested shape:

```c
typedef struct DimRational {
  int32_t num;
  uint32_t den;
} DimRational;
```

Then introduce new result structs or v2 functions, for example:

- `DimEvalResultV2`
- `DimQuantityResultV2`
- `dim_ctx_eval_v2(...)`
- `dim_ctx_convert_expr_v2(...)`

This keeps existing consumers working while providing a correct path for rational dimensions in the exported ABI.

## Phased Rollout

### Phase 1

- Add `Rational`
- Convert `Dimension` internals to exact rationals
- Preserve all existing integer-based APIs via helper constructors
- Keep behavior unchanged for existing integer-dimension operations

### Phase 2

- Replace `powDimFloat(...)` with exact rational dimension multiplication
- Add runtime and compile-time rational power helpers
- Keep current integer-power callers working

### Phase 3

- Extend unit-expression parsing to accept rational exponents
- Extend general expression power handling so dimensional powers require exact rational exponents
- Normalize non-integer exponents to `^(num/den)`

### Phase 4

- Update `format.normalizeUnitString(...)` and related formatting paths for rational dimensions
- Add tests for canonical output strings

### Phase 5

- Add versioned ABI structs and functions for rational dimensions
- Keep the current ABI available for existing consumers
- Update wrapper guidance docs after the new ABI lands

## Test Plan

### Compile-time quantity tests

- `Quantity(Area).pow(0.5)` yields `Quantity(Length)`
- `Quantity(Volume).pow(1.0 / 3.0)` yields `Quantity(Length)` if the exponent is provided via exact rational syntax/helper
- `Quantity(Length).pow(0.5)` yields a rational-dimension quantity rather than compile-erroring

### Runtime expression tests

- `(16 m^2)^0.5 -> 4 m`
- `(9 m)^0.5 -> 3 m^(1/2)`
- `(1 m/s)^0.5 -> 1 m^(1/2)/s^(1/2)`
- `(1 m)^1.5 -> 1 m^(3/2)`
- `1 Pa^0.5`

### Unit-expression parsing tests

- `1 as m^(1/2)`
- `1 as s^(-1/2)`
- `1 as kg*m^(1/2)/s`
- round-tripping normalized strings with rational exponents

### Rejection tests

- `1 C^0.5`
- `1 barg^0.5` once gauge pressure exists
- `1 m^pi`
- `1 m^(sqrt(2))`

### ABI tests

- `dim_ctx_eval_v2(...)` returns `1/2` and `3/2` exponents correctly
- existing `dim_ctx_eval(...)` behavior remains unchanged for integer-dimension quantities

## Migration Notes

- Existing code that only uses integer-dimension quantities should continue to behave the same.
- Existing formatting should remain stable for integer exponents.
- Existing ABI consumers should not be forced onto the rational-dimension path immediately.
- ABI docs should explicitly call out that:
  - legacy ABI exposes only integer dimensions
  - v2 ABI is required for exact rational dimensions

## Open Questions

- Do we want exact rational exponent syntax only, or should we also support best-effort conversion from arbitrary `f64` exponents?
  - Recommendation: exact syntax only for dimensional powers.
- Should normalized output always use fractional notation for non-integers, or allow decimal output when it terminates exactly?
  - Recommendation: always normalize to `^(num/den)`.
- Do we want to add convenience functions like `sqrt(...)` and `cbrt(...)` once rational exponents exist?
- Should derived-unit factoring ever produce rational powers of aliases, or should the first version stay base-unit oriented unless an exact alias match exists?

## Suggested First Patch

If we want the safest first implementation sequence:

1. Add `Rational`
2. Convert `Dimension` to exact rationals with integer-compatible helpers
3. Replace the current float-rounding dimension power logic in [src/quantity.zig](/Users/jerell/Repos/dim/src/quantity.zig#L26) and [src/runtime.zig](/Users/jerell/Repos/dim/src/runtime.zig#L135)
4. Leave parser syntax and ABI versioning for the next patch

That would remove the current “fractional exponent, but only if it rounds back to ints” limitation at the core model level first, which is the right foundation for the parser, formatter, and wrapper work that comes after.
