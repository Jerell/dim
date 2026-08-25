# Verification: browser API

Build with `npm run build:wasm`; use Node assertions and a real browser harness served over HTTP.

## foundations/runtime-lifecycle.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| LIFE-01 | P1 | Node | `initDim` resolves with explicit bytes and enables calls ([simple case](../foundations/runtime-lifecycle.md#the-simple-case)). | Built `zig-out/bin/dim_wasm.wasm`. | 1. Read bytes.<br>2. Await `initDim({ wasmBytes })`.<br>3. Evaluate an expression. | Initialization resolves and evaluation succeeds. | — |
| LIFE-02 | P1 | browser | Failed initialization can be retried ([edge cases](../foundations/runtime-lifecycle.md#edge-cases)). | Browser harness with missing URL. | 1. Initialize missing asset.<br>2. Restore asset.<br>3. Call recovery. | First promise rejects; later initialization can succeed. | — |

## foundations/result-and-memory.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MEM-01 | P1 | Node | Returned strings remain usable after wrapper reset ([read and format](../foundations/result-and-memory.md#read-and-format)). | Initialized runtime. | 1. Evaluate a quantity.<br>2. Format returned object after call. | Unit/value remain available after call returns. | — |

## foundations/input-normalization.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| NORM-01 | P1 | Node | Scientific notation and middle-dot syntax are accepted ([compute](../foundations/input-normalization.md#compute)). | Initialized runtime. | 1. Evaluate `1.5e3 m`.<br>2. Evaluate a middle-dot expression. | Results match equivalent decimal/asterisk expressions. | — |

## api/initialization-and-evaluation.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EVAL-01 | P1 | Node | Structured evaluation returns quantity fields ([read and format](../api/initialization-and-evaluation.md#read-and-format)). | Explicit binary initialized. | 1. Evaluate `100 km/h as m/s`. | Kind is quantity; value and unit are correct; dimensions are present. | — |
| EVAL-02 | P1 | Node | Calling evaluation before initialization throws ([invoke](../api/initialization-and-evaluation.md#invoke)). | Fresh module state. | 1. Call `evalStructured` before `initDim`. | Error says the runtime is not initialized. | — |

## api/conversions.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CONV-01 | P1 | Node | Direct value conversion returns the converted number ([simple case](../api/conversions.md#the-simple-case)). | Ready runtime. | 1. Convert 1 bar to Pa. | Result is 100000. | — |
| CONV-02 | P2 | Node | Compatibility returns true for compatible dimensions ([simple case](../api/conversions.md#the-simple-case)). | Ready runtime. | 1. Check `1 m` against `km`. | Result is true. | — |

## api/batch-operations.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| BATCH-01 | P1 | Node | Empty batch returns empty without runtime work ([simple case](../api/batch-operations.md#the-simple-case)). | Fresh module. | 1. Call empty batch conversion. | Result is `[]`; no initialization error. | — |
| BATCH-02 | P1 | Node | Non-empty batch preserves input order ([compute](../api/batch-operations.md#compute)). | Ready runtime. | 1. Convert two different items.<br>2. Compare output indexes. | Outputs match corresponding input order. | — |

## api/constants-and-contexts.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CONST-01 | P1 | Node | Defined constants affect later evaluation ([simple case](../api/constants-and-contexts.md#the-simple-case)). | Ready runtime. | 1. Define `workday` as `8 h`.<br>2. Evaluate `2 workday as h`. | Result is 16 h. | — |
| CONST-02 | P2 | Node | Recovery removes constants ([release or recover](../api/constants-and-contexts.md#release-or-recover)). | Constant defined. | 1. Recover with same asset.<br>2. Evaluate using old name. | Old constant is unavailable. | — |

## api/recovery.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| RECOVER-01 | P1 | Node | Recovery creates a usable fresh runtime ([simple case](../api/recovery.md#the-simple-case)). | Ready runtime. | 1. Call `recoverDim`.<br>2. Convert 1 km to m. | Recovery resolves and conversion returns 1000. | — |

## api/formatting.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FORMAT-01 | P2 | Node | Pure formatting works on copied results ([release or recover](../api/formatting.md#release-or-recover)). | Structured quantity result. | 1. Recover runtime.<br>2. Format old result. | Formatting still returns text after recovery. | — |

## cross-cutting/browser-loading.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| LOAD-01 | P1 | browser | Browser URL loading finds the served asset ([simple case](../cross-cutting/browser-loading.md#the-simple-case)). | HTTP harness serving `/dim/dim_wasm.wasm`. | 1. Initialize with URL.<br>2. Evaluate expression. | Fetch and initialization succeed. | — |
| LOAD-02 | P1 | browser | Missing/non-OK assets reject initialization ([compute](../cross-cutting/browser-loading.md#compute)). | Harness returns 404. | 1. Initialize missing URL. | Promise rejects with a loading/HTTP error. | — |

Not checkable by hand:

- Whether a shared module-level runtime is an acceptable concurrency contract.
- Whether predicate APIs should expose detailed invalid-input errors instead of false.
