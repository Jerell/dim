# Bug triage

A consolidated list of suspected defects raised while describing the `dim` CLI. B-02 was fixed before this revision; B-01 remains an open product decision. The list exists so the product team can decide whether to fix, document as intended, or leave each behavior.

## Summary

| ID | Title | Severity | Area | Decision needed | Issue |
| --- | --- | --- | --- | --- | --- |
| B-01 | Expression errors may exit successfully | medium | errors/output | product call | — |
| B-02 | Constant commands may ignore trailing tokens | low | constants | fix | [PR #14](https://github.com/Jerell/dim/pull/14) |

## Medium

### B-01: Expression errors may exit successfully

- **Where the user meets it:** A malformed or unevaluable expression in a direct CLI invocation or batch input.
- **What happens / what was expected:** The handler prints a scanner, parser, or runtime diagnostic and returns from the line handler. It does not visibly set a nonzero status. Script users may expect any failed expression to produce a failure exit status.
- **Reproduce:** 1. Run `zig-out/bin/dim '1e'` and print `$?`. 2. Repeat with `1 m / 0 m`.
- **Why (from the code):** `src/main.zig`, `run`, returns after scanner, parser, and evaluation errors; only invalid top-level argument paths call `std.process.exit(64)`.
- **Severity:** `medium`. The diagnostic is visible and recoverable, but scripts may accept a bad result.
- **Decision needed:** `product call`. Decide whether line errors should set a nonzero final status, especially when multiple batch lines mix success and failure.
- **Raised by:** [errors](cross-cutting/errors.md#open-questions-and-verification), [output](foundations/output.md#open-questions-and-verification), [invocation](foundations/invocation.md#open-questions-and-verification)
- **Status:** confirmed by scripted commands on 2026-08-24; `1e` and `1 m / 0 m` printed diagnostics but returned status 0. No fix has been filed.

## Low

### B-02: Constant commands may ignore trailing tokens

- **Where the user met it:** A user entered a command such as `clear all extra` or `show d extra`.
- **What happened vs. expected:** The original command handler could perform the command without rejecting trailing input. The expected behavior is now implemented: trailing command tokens are rejected.
- **Reproduce:** On the pre-PR #14 snapshot, enter `show d extra` or `clear d extra` after defining `d`.
- **Cause and fix:** `src/main.zig` originally recognized command prefixes without consuming the complete line. PR #14 requires the remaining tokens to be EOF and added regression coverage.
- **Severity:** `low` at discovery time.
- **Decision needed:** `fix` — completed in [PR #14](https://github.com/Jerell/dim/pull/14).
- **Raised by:** [constants](cli/constants.md#open-questions-and-verification)
- **Status:** fixed before this revision; the current source test `constant commands reject trailing tokens` passes. A hand CLI pass remains useful.

## Open observations

- Exact process statuses for line errors and file read failures still need a verification pass; these are not additional triage entries until reproduced.
- Signal behavior, Unicode rendering, and prompt flushing are unconfirmed rather than known defects.
