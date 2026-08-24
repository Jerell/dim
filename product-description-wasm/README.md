# dim browser API product description

A written description of the browser-facing TypeScript/WASM API shipped by `wasm/dim.ts`: how a caller loads the runtime, evaluates expressions, converts values, manages constants, reads structured results, and resets or recovers the runtime.

## Purpose

The browser API is a state chart driven by initialization, API calls, result reads, and runtime recovery. A caller supplies WASM bytes, base64, a URL, or the default asset; the wrapper creates a context, marshals strings and numbers, invokes exported operations, copies structured results, and resets the FFI arena. The observable behavior is spread across the TypeScript wrapper, the WASM exports, wrapper tests, and generated assets.

This project describes the public TypeScript wrapper in a browser-like client, using the default runtime behavior and the shipped WASM artifact. It is written for browser integrators and maintainers.

### What this is not

- Not the Zig library API, the native CLI, the C ABI, or the React `QuantityInput` component.
- Not a WASM ABI layout reference. Exact structs and exports belong in the source API documentation; this description covers what a caller experiences.
- Not a server or application product with routes, accounts, or persistence.

## Conventions

- Describe calls, promises, returned values, thrown errors, runtime state, and memory lifetime from the caller's point of view.
- Technical details appear only in `> Technical note:` blocks when they explain surprising behavior such as FFI reset timing.
- Use the vocabulary in [glossary.md](glossary.md).
- Every document ends with open questions and the source commit.

## The work to be done

Each document describes one API capability. The unit of interaction is a **browser API operation** with phases **prepare**, **invoke**, **compute**, **read and format**, and **release or recover**.

### Document template

1. **Summary.** What the API operation lets a caller do and how it is reached.
2. **The simple case.** The common initialized call and returned value.
3. **The interaction, event by event.** The five browser-operation phases: prepare, invoke, compute, read and format, and release or recover.
4. **Modifiers.** The fixed variant axis: initialization source, operation kind, runtime/context state, syntax normalization, single versus batch call, and format mode.
5. **Cancel and interrupt.** The fixed rows are: call before initialization; another API call or recovery begins; a call returns immediately; fetch/WASM/runtime failure; page unload or worker termination; input bytes or context state changes; and concurrent callers or a second runtime.
6. **Interactions with other systems.** Initialization and readiness; WASM memory and FFI reset; errors and status codes; contexts and constants; text encoding and syntax normalization; numeric and format behavior; browser/Node asset loading; batch operations; and concurrency/resource cleanup.
7. **Edge cases.** Empty batches, invalid expressions, malformed assets, scientific notation normalization, base64 loading, repeated recovery, and result-copy lifetime.
8. **Open questions and verification.** Unconfirmed browser behavior, suspected defects, and source commit.

### Method

Read `wasm/dim.ts` first, then `src/wasm.zig` for exported operation behavior, `tests/wasm_wrapper.test.mjs`, WASM build configuration, and shipped assets. Verify with `npm run build:wasm`, `node tests/wasm_wrapper.test.mjs`, and a minimal browser harness that calls the wrapper through real browser APIs.

### Verification

The `verification/` directory contains one checklist for initialization, evaluation, conversions, batches, constants, and recovery. Node tests can confirm values and errors but cannot establish browser fetch behavior, worker lifecycle, or result lifetime after a caller waits. Those require a browser or worker harness.

## Order of work

1. **Pilot: [initialization and evaluation](api/initialization-and-evaluation.md).** Load shipped bytes and evaluate one structured expression.
2. **Foundations: [runtime lifecycle](foundations/runtime-lifecycle.md), [result and memory model](foundations/result-and-memory.md), and [input normalization](foundations/input-normalization.md).**
3. **Hardest area: [conversions](api/conversions.md), [batch operations](api/batch-operations.md), and [recovery](api/recovery.md).**
4. **Everything else: [constants and contexts](api/constants-and-contexts.md), [formatting](api/formatting.md), and [browser loading](cross-cutting/browser-loading.md).**

### Scope decisions

- **Surface.** The public TypeScript wrapper in `wasm/dim.ts` and the shipped `dim_wasm.wasm` runtime, called from a browser-like client.
- **Defaults.** Default loading behavior, no custom fetch headers, no React provider, and the default runtime context created by `initDim`.
- **Interaction shape.** A browser API operation has phases prepare, invoke, compute, read and format, and release or recover. The modifier axis, interrupt rows, and cross-cutting order above are fixed.
- **Out of scope.** The Zig library's direct API, native CLI, React provider/component, C ABI callers, server-side persistence, and application-specific UI.
- **Run surface.** Build the artifact with `npm run build:wasm`; run wrapper assertions with `node tests/wasm_wrapper.test.mjs`; use a minimal browser harness for browser-only verification.
- **Source.** `/Users/jerell/Repos/dim` at commit `811dcf0` when this description was scaffolded.
- **Repository location.** This is a separate description directory inside the source checkout.

## Structure

```
README.md                              this file
goal.md                                standing drafting instructions
glossary.md                            shared vocabulary
AGENTS.md, CLAUDE.md                    agent entry points
bug-triage.md                          suspected defects

verification/
  README.md                            verification protocol
  browser-api.md                       API claim checklists

foundations/
  runtime-lifecycle.md                  initialization, readiness, and context
  result-and-memory.md                 result copying and FFI reset lifetime
  input-normalization.md               UTF-8, Unicode, scientific notation, and modes

api/
  initialization-and-evaluation.md     pilot: initialize and evaluate
  conversions.md                       expression and direct-value conversion
  batch-operations.md                  batch conversion behavior
  constants-and-contexts.md            runtime constants and default context
  recovery.md                          reset, reinitialize, and failure recovery
  formatting.md                        structured result and text formatting

cross-cutting/
  browser-loading.md                   browser/Node asset sources and failures
```

## Coverage

Status is one of `not started`, `drafted`, or `verified`.

| Document | Status |
| --- | --- |
| glossary.md | drafted |
| foundations/runtime-lifecycle.md | drafted |
| foundations/result-and-memory.md | drafted |
| foundations/input-normalization.md | drafted |
| api/initialization-and-evaluation.md | drafted |
| api/conversions.md | drafted |
| api/batch-operations.md | drafted |
| api/constants-and-contexts.md | drafted |
| api/recovery.md | drafted |
| api/formatting.md | drafted |
| cross-cutting/browser-loading.md | drafted |
| verification/ (1 checklist) | not started |
| bug-triage.md | not started |

## Reference

The source of truth is `/Users/jerell/Repos/dim` at commit `811dcf0`.

- `wasm/dim.ts`: initialization, asset lookup, WASI imports, memory marshalling, evaluation, conversions, constants, formatting, and recovery.
- `src/wasm.zig`: exported context operations, structured result layouts, status codes, and batch behavior.
- `tests/wasm_wrapper.test.mjs`: binary initialization, structured evaluation, direct and batch conversion, compatibility, and base64 recovery assertions.
- `build.zig`: native and WASM artifact targets.
- `public/dim/dim_wasm.wasm`, `registry/assets/dim_wasm.wasm.base64`: shipped binary and text-safe assets.
- `package.json`: TypeScript and WASM build/test commands.
