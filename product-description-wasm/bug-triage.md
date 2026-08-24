# Bug triage

A consolidated list of suspected defects raised while describing the public TypeScript/WASM wrapper. These entries are source-based; Node assertions passed, but browser and concurrency verification has not run.

## Summary

Two API design risks remain: predicate operations collapse invalid input into false, and the module-level runtime is shared across callers while recovery can replace it. Both are recoverable but may surprise integrators and require product/API decisions.

| ID | Title | Severity | Area | Decision needed | Issue |
| --- | --- | --- | --- | --- | --- |
| B-01 | Predicate APIs hide invalid-input failures | medium | compatibility | product call | — |
| B-02 | Recovery can replace shared runtime state | medium | lifecycle/concurrency | product call | — |

## Medium

### B-01: Predicate APIs hide invalid-input failures

- **Where the user meets it:** A caller uses `isCompatible` or `sameDimension` with malformed expressions or an unavailable runtime.
- **What happens / what was expected:** The wrapper returns false for any non-OK status. The caller cannot tell false compatibility from invalid input or runtime failure.
- **Reproduce:** Initialize, call a predicate with malformed expression text, and compare it with a valid incompatible expression.
- **Why (from the code):** `wasm/dim.ts` returns false whenever the predicate export status is not OK.
- **Severity:** `medium`. The boolean is convenient but can hide operational failures.
- **Decision needed:** `product call`. Add a throwing/detailed predicate variant or document false as the complete failure contract.
- **Raised by:** [conversions](api/conversions.md#open-questions-and-verification), [conversions](api/conversions.md#open-questions-and-verification)

### B-02: Recovery can replace shared runtime state

- **Where the user meets it:** Multiple browser callers use the wrapper while one caller invokes `recoverDim`.
- **What happens / what was expected:** The wrapper has one module-level runtime/context. Recovery frees it, emits not-ready, and initializes a new context for every caller. A concurrent call may fail or observe changed constants.
- **Reproduce:** Initialize, start a long or repeated caller, invoke recovery from another caller, and observe operations during the transition.
- **Why (from the code):** `wasm/dim.ts` stores `runtime` and `initPromise` at module scope and `recoverDim` frees/replaces them.
- **Severity:** `medium`. Single-caller use is straightforward, but shared module state can make multi-consumer behavior surprising.
- **Decision needed:** `product call`. Document single-owner use, expose contexts, or serialize/reject recovery while calls are active.
- **Raised by:** [runtime lifecycle](foundations/runtime-lifecycle.md#open-questions-and-verification), [recovery](api/recovery.md#open-questions-and-verification), [browser loading](cross-cutting/browser-loading.md#open-questions-and-verification)

## Open observations

- Browser URL resolution and service-worker cache behavior need an HTTP harness.
- Large batch memory limits are not established.
- No browser or worker verification pass has confirmed either entry.
