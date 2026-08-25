# Glossary

The vocabulary used across these documents. When a document uses one of these words, it means exactly this.

## The browser runtime

**Browser API operation.** One call or lifecycle action through `wasm/dim.ts`, such as initialization, evaluation, conversion, constant definition, or recovery.

**WASM runtime.** The instantiated `dim_wasm.wasm` module plus its JavaScript wrapper state, memory, context, and WASI imports.

**Initialization.** Loading a WASM source, instantiating it, checking required exports, and creating the wrapper's runtime context.

**Readiness.** Whether initialization has produced a usable runtime. Before readiness, operations that need a runtime throw an initialization error.

**Recovery.** Releasing the current runtime, clearing the initialization promise, and initializing again from a new or repeated source.

**Asset source.** The bytes, base64 text, URL, or default candidate path from which the WASM module is loaded.

## Calls and results

**Expression.** A string accepted by the dim evaluator, such as `100 km/h as m/s`.

**Structured result.** A JavaScript discriminated union with kind `number`, `boolean`, `string`, `quantity`, or `nil`. A quantity result also includes value, unit, dimensions, delta status, and format mode.

**Quantity result.** A structured result whose kind is `quantity` and whose fields describe a dimensional value.

**Conversion.** A request to convert an expression or numeric value into a target unit.

**Compatibility.** A boolean answer indicating whether an expression has the requested dimension/unit compatibility.

**Batch operation.** One wrapper call that converts an array of expressions or values and returns an array of numbers. Empty batches return an empty array without invoking the runtime.

**Runtime constant.** A named unit-like value stored in the current WASM context. It is defined, cleared, or cleared in bulk through wrapper functions and is not persistent across recovery.

**Format mode.** `none`, `auto`, `scientific`, or `engineering`, used when formatting a quantity result into text.

## Memory and transport

**FFI arena.** The WASM-side scratch allocation area whose returned strings and temporary buffers remain valid until `dim_ffi_reset` is called.

**Result copy.** The JavaScript object created by reading a WASM result before the wrapper resets the FFI arena. The caller owns the copied JavaScript strings and numbers, not the WASM pointers.

**FFI reset.** The cleanup step performed in a `finally` block after a single wrapper operation. It makes the current scratch allocations reusable and invalidates raw WASM pointers.

**UTF-8 normalization.** The wrapper's conversion of JavaScript strings to UTF-8 and its input rewriting for middle dots, superscripts, and scientific notation before sending text to WASM.

**WASI import.** A browser-provided implementation of the WASI functions requested by the module. Unsupported filesystem, clock, polling, and process operations return `ENOTSUP` or throw for process exit.

## Events that end or interrupt a browser API operation

**Call before initialization.** An operation requiring a runtime is invoked while no runtime exists; it throws instead of beginning a WASM call.

**Recovery interrupt.** `recoverDim` releases the current context and makes existing runtime state unavailable while a new initialization runs.

**Runtime failure.** Loading, export validation, context creation, status checking, or WASM execution fails. Status-checked calls throw `DimWasmError` with a numeric category; compatibility predicates retain their boolean false failure contract.

**Page teardown.** A page, worker, or module lifetime ends before a promise or call completes. The wrapper does not persist runtime state.

**Context change.** Constants or runtime state change between operations, changing later results without changing copied earlier results.

**Concurrent caller.** Multiple callers use the shared module-level runtime or recovery path at the same time. The wrapper does not expose a separate context per caller.
