# Bug triage

A consolidated list of suspected defects raised while describing the `dim` CLI. A scripted first pass confirmed one status-related observation; no hand-verification pass has run. The list exists so the product team can decide whether to fix, document as intended, or leave each behavior.

## Summary

Two possible issues remain after the source review: line-level errors appear to return without explicitly setting a nonzero process status, and command recognition may accept trailing tokens. Both are medium-severity product calls until verified against the built binary and the intended scripting contract.

| ID | Title | Severity | Area | Decision needed | Issue |
| --- | --- | --- | --- | --- | --- |
| B-01 | Expression errors may exit successfully | medium | errors/output | product call | — |
| B-02 | Constant commands may ignore trailing tokens | low | constants | fix | — |

## Medium

### B-01: Expression errors may exit successfully

- **Where the user meets it:** A malformed or unevaluable expression in a direct CLI invocation or batch input.
- **What happens / what was expected:** The handler prints a scanner, parser, or runtime diagnostic and returns from the line handler. It does not visibly set a nonzero status. Script users may expect any failed expression to produce a failure exit status.
- **Reproduce:** 1. Run `zig-out/bin/dim '1e'` and print `$?`. 2. Repeat with `1 m / 0 m`.
- **Why (from the code):** `src/main.zig`, `run`, returns after scanner, parser, and evaluation errors; only invalid top-level argument paths call `std.process.exit(64)`.
- **Severity:** `medium`. The diagnostic is visible and recoverable, but scripts may accept a bad result.
- **Decision needed:** `product call`. Decide whether line errors should set a nonzero final status, especially when multiple batch lines mix success and failure.
- **Raised by:** [errors](cross-cutting/errors.md#open-questions-and-verification), [output](foundations/output.md#open-questions-and-verification), [invocation](foundations/invocation.md#open-questions-and-verification)
- **Status:** confirmed by scripted commands on 2026-08-24; `1e` and `1 m / 0 m` printed diagnostics but returned status 0.

## Low

### B-02: Constant commands may ignore trailing tokens

- **Where the user meets it:** A user enters a command such as `clear all extra` or `show d extra`.
- **What happens / what was expected:** The command handler checks only the first command tokens and can perform the command without rejecting the trailing input. A user may expect an invalid-argument diagnostic for the extra text.
- **Reproduce:** 1. Start the REPL. 2. Define `d = (24 h)`. 3. Enter `show d extra` or `clear d extra`.
- **Why (from the code):** `src/main.zig`, command handling after tokenization, recognizes `list`, `show`, `clear all`, and `clear identifier` without checking that the remaining tokens are only EOF.
- **Severity:** `low`. The operation is recoverable, but accepted text may hide a typo.
- **Decision needed:** `fix`. Reject trailing tokens or document command-prefix behavior explicitly.
- **Raised by:** [constants](cli/constants.md#open-questions-and-verification)

## Open observations

- Exact process statuses for line errors and file read failures still need a verification pass; these are not additional triage entries until reproduced.
- Signal behavior, Unicode rendering, and prompt flushing are unconfirmed rather than known defects.
