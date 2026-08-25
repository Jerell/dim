# Goal: complete the dim browser API product description

You are working in the `product-description-wasm` repo. Read `README.md`, `glossary.md`, the foundation documents, and the pilot first. The README coverage table is the work list. Describe the TypeScript/WASM wrapper from a browser integrator's point of view.

## Source of truth

The source repo is `/Users/jerell/Repos/dim`, commit `5d9cf0d`. The surface is `wasm/dim.ts` plus the generated `dim_wasm.wasm` artifact and its shipped base64 copy. Zig internals, CLI, C ABI, React, and application UI are out of scope.

Read in this order:

1. `wasm/dim.ts` for initialization sources, readiness, memory marshalling, operations, formatting, and recovery.
2. `src/wasm.zig` for status/result behavior and exported context operations.
3. `tests/wasm_wrapper.test.mjs` for executable wrapper expectations.
4. `build.zig`, `public/dim/`, and `registry/assets/` for artifact construction and distribution forms.
5. `package.json` and the source README for commands and supported usage examples.

Describe calls, returned JavaScript objects, thrown errors, runtime state, and cleanup. Use `> Technical note:` only when pointer lifetime, normalization, or WASI behavior changes what a browser caller expects.

## Writing rules

- Every feature follows the eight-section skeleton in README.md.
- Every feature uses the same browser-operation phases, variant rows, interrupt rows, and cross-cutting order.
- State when an operation is synchronous after initialization and when initialization/recovery is asynchronous.
- Cross-reference lifecycle, memory, and normalization foundations rather than repeating them.
- Include one Mermaid `stateDiagram-v2` per interaction.
- End with `## Open questions and verification` and `Verified against /Users/jerell/Repos/dim commit \`5d9cf0d\`.`
- Do not modify source code while drafting.

## Things already established

- `initDim` is asynchronous and creates one module-level runtime/context; operations require it to be ready.
- `recoverDim` frees the current context, clears the initialization promise, emits not-ready, and initializes again.
- Default browser loading tries module-relative and root `/dim/` binary/base64 sources; explicit bytes, base64, or URL take precedence.
- Single operations copy result values and strings before `dim_ffi_reset` runs in `finally`.
- Text inputs are UTF-8 encoded and normalized for middle dots, superscripts, and scientific notation before WASM receives them.
- Batch conversion returns an empty array without requiring a runtime for an empty input array; non-empty batches require readiness and check each item status.
- `isCompatible` and `sameDimension` return false for non-OK status rather than throwing; other status-checked operations throw `DimWasmError` with a numeric `status` that distinguishes parse, runtime, and allocation failures.
- Constants belong to the current runtime context and disappear after recovery.

## Order of work

1. Pilot: `api/initialization-and-evaluation.md`.
2. Foundations: runtime lifecycle, result/memory model, input normalization.
3. Hardest area: conversions, batches, and recovery.
4. Remaining constants, formatting, browser loading, verification, and triage.

Update README coverage as documents land. Commit coherent groups with `docs: add {path}` or `docs: revise {path}`. Do not mark documents verified from Node assertions alone where browser lifecycle behavior remains unobserved.
