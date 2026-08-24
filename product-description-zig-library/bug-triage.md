# Bug triage

A consolidated list of suspected defects raised while describing the public Zig library API. These entries are source-based; the scripted test pass has not confirmed a product defect in a hand/external pass.

## Summary

Two API clarity risks remain: the convenience evaluator collapses distinct failures to null, and unchecked affine unit operations assert despite checked alternatives. Both may be intentional API trade-offs, so they require a product/documentation call before filing.

| ID | Title | Severity | Area | Decision needed | Issue |
| --- | --- | --- | --- | --- | --- |
| B-01 | Convenience evaluation hides failure category | medium | runtime evaluation | product call | — |
| B-02 | Unchecked affine unit composition can assert | medium | unit construction | product call | — |

## Medium

### B-01: Convenience evaluation hides failure category

- **Where the user meets it:** A consumer calls `evaluate` and receives null for malformed syntax, runtime failure, or allocation failure.
- **What happens / what was expected:** The API returns no result and may write a diagnostic, but does not expose a typed reason. Consumers may expect to distinguish invalid input from resource failure.
- **Reproduce:** Call `evaluate` with malformed input, a division by zero expression, and an allocator that fails.
- **Why (from the code):** `src/root.zig` catches scanner, parser, evaluation, and result-copy failures and returns null from the convenience path.
- **Severity:** `medium`. The caller can recover by using diagnostics or lower-level APIs, but ordinary integrations cannot reliably classify failures.
- **Decision needed:** `product call`. Add a typed error API, document null semantics, or keep the convenience surface intentionally minimal.
- **Raised by:** [runtime evaluation](library/runtime-evaluation.md#open-questions-and-verification), [ownership and errors](foundations/ownership-and-errors.md#open-questions-and-verification)

### B-02: Unchecked affine unit composition can assert

- **Where the user meets it:** A consumer composes an affine unit such as Celsius or Fahrenheit with multiplication, division, or powers through an unchecked method.
- **What happens / what was expected:** The unchecked path uses a debug assertion rather than returning an error. A consumer may expect a safe runtime failure from a public method named as an operation.
- **Reproduce:** Call an unchecked affine composition in a debug build, such as `C.div(h, "C/h")` or `F.pow(2, "F^2")`.
- **Why (from the code):** `src/Unit.zig` asserts non-affine preconditions in `mul`, `div`, and `pow`; checked variants return `AffineUnitCombination`.
- **Severity:** `medium`. The safe API exists, but the unchecked public path can terminate a debug program when used incorrectly.
- **Decision needed:** `product call`. Keep the unchecked performance/assumption path, rename/document it more strongly, or make the default operation return an error.
- **Raised by:** [unit construction](library/unit-construction.md#open-questions-and-verification), [compile-time safety](cross-cutting/compile-time-safety.md#open-questions-and-verification)

## Open observations

- Exact compiler diagnostics vary with Zig version.
- Allocator-failure behavior needs instrumentation.
- No issue is confirmed by an external hand-verification pass yet.
