# Bug triage

A consolidated list of suspected defects raised while describing the public Zig library API. The two entries from the initial snapshot were fixed in merged PRs #16 and #17; they remain here as historical traceability rather than open defects.

## Summary

| ID | Title | Severity | Area | Decision needed | Issue |
| --- | --- | --- | --- | --- | --- |
| B-01 | Convenience evaluation hid failure category | medium | runtime evaluation | fix | [PR #16](https://github.com/Jerell/dim/pull/16) |
| B-02 | Unchecked affine unit composition could assert | medium | unit construction | fix | [PR #17](https://github.com/Jerell/dim/pull/17) |

## Medium

### B-01: Convenience evaluation hid failure category

- **Where the user met it:** A consumer called `evaluate` and received null for malformed syntax, runtime failure, or allocation failure.
- **What happened vs. expected:** The original convenience API collapsed failures to null. The current API returns `EvaluationError!LiteralValue`, preserving granular parse errors, runtime errors, and allocation failure.
- **Reproduce:** On the pre-#16 snapshot, call `evaluate` with malformed input, division by zero, and an allocator that fails.
- **Cause and fix:** The original `src/root.zig` convenience path caught scanner, parser, evaluation, and result-copy failures. PR #16 introduced the typed error union, parser diagnostics, and downstream consumer updates.
- **Severity:** `medium` at discovery time.
- **Decision needed:** `fix` — completed in [PR #16](https://github.com/Jerell/dim/pull/16).
- **Raised by:** [runtime evaluation](library/runtime-evaluation.md#open-questions-and-verification), [ownership and errors](foundations/ownership-and-errors.md#open-questions-and-verification)
- **Status:** fixed by merged PR #16; CI and regression tests pass. The current verification checklist still needs a hand/external-consumer pass.

### B-02: Unchecked affine unit composition could assert

- **Where the user met it:** A consumer composed an affine unit such as Celsius or Fahrenheit with multiplication, division, or powers through an unchecked Unit method.
- **What happened vs. expected:** The original Unit methods used debug assertions. The current `mul`, `div`, `pow`, and `powRational` return `UnitCompositionError!Unit` with `error.AffineUnitCombination`.
- **Reproduce:** On the pre-#17 snapshot, call an affine composition in a debug build, such as `C.div(h, "C/h")` or `F.pow(2, "F^2")`.
- **Cause and fix:** The original `src/unit.zig` asserted non-affine preconditions. PR #17 made the default Unit composition methods fallible, removed the `*Checked` Unit aliases, bumped the package to 0.3.0, and made `pow` the sole integer-power method.
- **Severity:** `medium` at discovery time.
- **Decision needed:** `fix` — completed in [PR #17](https://github.com/Jerell/dim/pull/17).
- **Raised by:** [unit construction](library/unit-construction.md#open-questions-and-verification), [compile-time safety](cross-cutting/compile-time-safety.md#open-questions-and-verification)
- **Status:** fixed by merged PR #17; external consumer and CI regression coverage pass. The current verification checklist still needs a hand/external-consumer pass.

## Open observations

- Exact compiler diagnostics vary with Zig version.
- Allocator-failure behavior needs instrumentation.
- No new unverified defect is recorded by this revision.
