# Verification: Zig library

Run `zig build test` from the source checkout. Use temporary consumer fixtures for compile-time claims and do not edit source fixtures.

## foundations/type-and-dimension-model.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DIM-01 | P1 | consumer fixture | Dividing length by time produces a velocity-typed value ([compile or return immediately](../foundations/type-and-dimension-model.md#compile-or-return-immediately)). | Temporary Zig consumer. | 1. Define Length and Time quantities.<br>2. Divide them.<br>3. Assign/use result as velocity. | Compilation succeeds and runtime value is correct. | — |
| DIM-02 | P1 | consumer fixture | Adding incompatible quantity types fails compilation ([compile or return immediately](../foundations/type-and-dimension-model.md#compile-or-return-immediately)). | Temporary intentionally failing fixture. | 1. Add length and time.<br>2. Compile fixture. | Compilation fails before execution. | — |

## foundations/unit-and-registry-model.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UNIT-01 | P1 | consumer fixture | Exact/alias/prefix lookup resolves built-in units ([begin execution](../foundations/unit-and-registry-model.md#begin-execution)). | Built library. | 1. Resolve `km`, an alias, and an affine unit.<br>2. Resolve a prefixed affine symbol. | Valid symbols resolve; prefixed affine symbol is absent. | — |

## foundations/ownership-and-errors.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| OWN-01 | P1 | allocator instrumentation | Returned display values can be deinitialized with the caller allocator ([return](../foundations/ownership-and-errors.md#return)). | Counting/failing allocator. | 1. Evaluate a display quantity.<br>2. Deinitialize it.<br>3. Check allocator balance. | Owned strings are released without a leak. | — |

## library/quantity-arithmetic.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| QTY-01 | P1 | consumer fixture | Typed arithmetic returns the derived numeric value ([return](../library/quantity-arithmetic.md#return)). | External consumer. | 1. Construct 100 m and 10 s.<br>2. Divide.<br>3. Read value. | Result is velocity with value 10. | — |
| QTY-02 | P1 | consumer fixture | Temperature delta multiplication through checked API returns an error ([while executing](../library/quantity-arithmetic.md#while-executing)). | Temperature delta and length. | 1. Call checked multiplication.<br>2. Inspect error. | Error is `MulDivTemperatureDelta`. | — |

## library/unit-construction.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| BUILD-01 | P2 | consumer fixture | Composed km/h has velocity dimension and expected scale ([return](../library/unit-construction.md#return)). | SI registry. | 1. Compose km and h.<br>2. Inspect dimension/scale. | Dimension is velocity and scale is 1000/3600. | — |

## library/runtime-evaluation.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EVAL-01 | P1 | consumer fixture | String evaluation returns a converted display quantity ([return](../library/runtime-evaluation.md#return)). | Allocator and expression. | 1. Evaluate `100 km/h as m/s`.<br>2. Format and deinitialize. | Result is approximately 27.7778 m/s and cleanup succeeds. | — |
| EVAL-02 | P1 | consumer fixture | Invalid expression returns a granular parse error ([compile or return immediately](../library/runtime-evaluation.md#compile-or-return-immediately)). | Error writer optional. | 1. Evaluate malformed source.<br>2. Inspect error and diagnostics. | No result is returned; the parse error and generic diagnostic are available. | — |

## library/contexts-and-constants.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CTX-01 | P1 | consumer fixture | Explicit contexts isolate constants ([the simple case](../library/contexts-and-constants.md#the-simple-case)). | Two contexts. | 1. Define `foo` in context A.<br>2. Resolve in A and B. | A resolves it; B does not. | — |

## library/display-quantities.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DISPLAY-01 | P2 | consumer fixture | Display arithmetic returns an owned result ([return](../library/display-quantities.md#return)). | Two display quantities and allocator. | 1. Add quantities.<br>2. Deinitialize result. | Combined value is returned and cleanup is required/succeeds. | — |

## library/formatting.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FORMAT-01 | P2 | consumer fixture | Scientific and explicit-unit formatting change emitted text without changing value ([while executing](../library/formatting.md#while-executing)). | Speed quantity and writer. | 1. Format scientific.<br>2. Format as km/h.<br>3. Compare quantity value. | Text differs; source quantity value is unchanged. | — |

## cross-cutting/compile-time-safety.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SAFE-01 | P1 | consumer fixture | Comptime mismatch and runtime mismatch fail at their documented boundaries ([compile or return immediately](../cross-cutting/compile-time-safety.md#compile-or-return-immediately)). | Two fixtures. | 1. Compile wrong comptime unit fixture.<br>2. Run wrong dynamic unit fixture. | First fails compilation; second returns `DimensionMismatch`. | — |

Not checkable by hand:

- Whether compiler diagnostics are understandable enough for consumers.
- Whether Quantity unchecked preconditions are sufficiently discoverable as unsafe.
