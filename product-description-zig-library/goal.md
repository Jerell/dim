# Goal: complete the dim Zig library product description

You are working in the `product-description-zig-library` repo. Read `README.md`, `glossary.md`, the foundation documents, and the pilot first. The README coverage table is the work list. Describe the public Zig package as a consumer experiences it through compilation, runtime calls, returned values, and cleanup.

## Source of truth

The source repo is `/Users/jerell/Repos/dim`, commit `811dcf0`. The surface is the public `dim` module rooted at `src/root.zig`, with default built-in registries. CLI, C ABI, WASM, React, and registry installation are out of scope.

Read in this order:

1. `src/root.zig` for public exports, contexts, constants, evaluation, lookup, and ownership boundaries.
2. `src/quantity.zig`, `src/Unit.zig`, and `src/Dimension.zig` for typed arithmetic, units, dimensions, and rational exponents.
3. `src/format.zig` and `src/runtime.zig` for formatting and allocator-owned display quantities.
4. `src/registry/*.zig` for built-in symbols, aliases, prefixes, and affine units.
5. `tests/consumer.zig` for external-consumer behavior and `src/root.zig` tests for arithmetic/context edge cases.
6. `build.zig` and the source README only for public build and example expectations.

Use the glossary's terms. Describe what the consumer can observe; use `> Technical note:` only when the mechanism changes the expected compile/runtime boundary.

## Writing rules

- Every feature document follows the eight-section skeleton in README.md.
- Every feature uses the same operation phases, variant rows, interrupt rows, and cross-cutting order.
- Distinguish compile-time rejection, runtime error, panic/assertion, and successful return.
- Cross-reference foundations rather than restating dimensions, ownership, or context rules.
- Include one Mermaid `stateDiagram-v2` per interaction.
- End with `## Open questions and verification` and `Verified against /Users/jerell/Repos/dim commit \`811dcf0\`.`
- Do not modify source code while drafting.

## Things already established

- `Quantity(Dimension)` carries a canonical `f64` value and `is_delta` state.
- Quantity dimensions are represented in the type returned by the generic `Quantity` constructor.
- `from` checks comptime unit dimensions; `fromDynamic` returns `DimensionMismatch` at runtime.
- Checked affine operations return errors; unchecked unit composition asserts rather than returning an error.
- `evaluateWithContext` isolates runtime constants and scratch storage in an explicit `DimContext`; convenience evaluation uses a thread-local default context.
- Returned display quantities and strings copied into a caller allocator must be released with their corresponding deinitializers.
- Built-in unit lookup checks constants first, exact/alias matches before prefixes, and then prefix expansion.

## Order of work

1. Pilot: `library/quantity-arithmetic.md`.
2. Foundations: type and dimension model, unit and registry model, ownership and errors.
3. Hardest area: runtime evaluation, contexts/constants, and display quantities.
4. Remaining unit construction and formatting documents, compile-time safety, verification, and triage.

Update README coverage as documents land. Commit coherent groups using `docs: add {path}` or `docs: revise {path}`. Do not mark a document verified from compilation alone where a consumer-facing decision still needs review.
