# Hand verification

These checklists compare the Zig library documents with consumer code compiled and run against the source checkout.

## What is here

| File | Covers |
| --- | --- |
| [zig-library.md](zig-library.md) | foundations, public library capabilities, and compile-time safety |

## How to run a pass

1. From `/Users/jerell/Repos/dim`, run `zig build test`.
2. Confirm the source commit matches the feature footers (`5d9cf0d` for this revision).
3. Run scripted checks first, then compile external-style examples and inspect compiler failures for compile-time claims.
4. Record `pass`, `fail`, or `blocked`. A failed claim may indicate an incorrect document rather than a library defect.
5. Mark a document verified only when its P1/P2 items pass or are filed.

## Devices and conditions

- **Zig compiler:** use the repository's Zig 0.16 toolchain; compiler diagnostics are version-sensitive.
- **Consumer fixture:** use a temporary external-style Zig file importing the `dim` module, not only internal tests.
- **Allocator instrumentation:** use a failing or counting allocator for ownership claims.
- **Multiple contexts:** create two explicit contexts and use separate threads only if testing concurrency.

## Driving the product from a script

The public library has no standalone UI. `zig build test` and consumer fixtures are the primary driver. Scripts can observe values, error unions, ownership cleanup, and compilation success/failure. They cannot decide whether compiler diagnostics are understandable or whether unchecked APIs are sufficiently discoverable.

## Results so far

An automated pass for this revision ran on 2026-08-25: `zig build test` passed, including the external consumer's fallible Unit composition checks and typed evaluation errors. No standalone compile-failure fixture, allocator-instrumented pass, or hand verification has run, so no document is marked verified.
