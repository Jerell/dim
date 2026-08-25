# dim Zig library product description

A written description of the public Zig library API in `dim`: what a library consumer declares, what the compiler accepts or rejects, what runtime operations return, and how units, dimensions, quantities, formatting, contexts, and errors behave.

## Purpose

The Zig library is a state chart experienced through declarations, compile-time type checking, runtime calls, and returned values. A consumer chooses a dimension and quantity type, constructs values from canonical numbers or units, combines them, formats them, or evaluates expressions through a context. The behavior is distributed across public types, registries, runtime helpers, and consumer tests.

This project describes the public Zig package at `/Users/jerell/Repos/dim`, using the documented API and default built-in registries. It is for library consumers and maintainers, and describes the observable compile-time and runtime experience rather than implementation structure.

### What this is not

- Not documentation of the native CLI, C ABI, WASM wrapper, React components, or registry installation.
- Not a package-by-package design document. Internal modules appear only when their behavior changes what a consumer observes.
- Not a promise that every public declaration is equally stable; the source API and release README remain authoritative for signatures.

## Conventions

- Describe what a consumer can write, compile, run, and observe.
- Technical detail goes in `> Technical note:` blocks only when it changes expectations.
- Use the vocabulary in [glossary.md](glossary.md).
- Compile-time failures are described as compile outcomes, not runtime errors. Runtime errors and allocator ownership are described separately.
- Every document ends with open questions and the source commit.

## The work to be done

Each document uses the same skeleton for one public capability. The unit of interaction is a **library operation** with phases **declare**, **compile or return immediately**, **begin execution**, **while executing**, and **return**.

### Document template

1. **Summary.** What the API capability lets a consumer do and which public type or function exposes it.
2. **The simple case.** The smallest compiling and running example.
3. **The interaction, event by event.** The five library-operation phases: declare, compile or return immediately, begin execution, while executing, and return.
4. **Modifiers.** The fixed API variant axis: compile-time or runtime unit, fallible or unchecked Quantity operation, dimension/quantity type, registry and format mode, affine/delta state, and allocator/context.
5. **Cancel and interrupt.** The fixed rows are: compile-time rejection; the caller doing another operation; an operation that completes before extension; runtime error or panic; allocator failure or resource teardown; input value/type/unit changing; and a second context or thread using the same state.
6. **Interactions with other systems.** Compile-time safety; dimensions and rational exponents; units and registries; affine/delta semantics; formatting; allocators and ownership; contexts and constants; concurrency; and release/build configuration.
7. **Edge cases.** Dimension mismatch, affine units, rational powers, empty or missing units, context isolation, and ownership boundaries.
8. **Open questions and verification.** Unconfirmed consumer-visible behavior and source commit.

### Method

Read `src/root.zig` first for the exported package, then `src/quantity.zig`, `src/Unit.zig`, `src/Dimension.zig`, `src/format.zig`, `src/runtime.zig`, and registry definitions. Read `tests/consumer.zig` as the executable consumer specification and the tests in `src/root.zig` for arithmetic and context edge cases. Verify with `zig build test` and small external-style Zig snippets where needed.

### Verification

The `verification/` directory contains checklists for public API claims. A scripted pass can confirm compilation, values, error unions, formatting, and context state. It cannot by itself establish whether an error message is understandable or whether a compile-time failure is ergonomically discoverable; those claims remain marked for review.

## Order of work

1. **Pilot: [quantity arithmetic](library/quantity-arithmetic.md).** A consumer constructs length and time quantities and derives speed.
2. **Foundations: [type and dimension model](foundations/type-and-dimension-model.md), [unit and registry model](foundations/unit-and-registry-model.md), and [ownership and errors](foundations/ownership-and-errors.md).**
3. **Hardest area: [runtime evaluation](library/runtime-evaluation.md), [contexts and constants](library/contexts-and-constants.md), and [display quantities](library/display-quantities.md).**
4. **Everything else: [unit construction](library/unit-construction.md), [formatting](library/formatting.md), and [compile-time safety](cross-cutting/compile-time-safety.md).**

### Scope decisions

- **Surface.** The public Zig library imported as `dim`, including typed quantities, units, registries, dimensions, formatting, runtime display helpers, string evaluation, and explicit contexts.
- **Defaults.** Built-in SI, Imperial, CGS, and industrial registries; standard Zig allocator behavior; no CLI, WASM, C ABI, or custom application wrapper.
- **Interaction shape.** A library operation has phases declare, compile or return immediately, begin execution, while executing, and return. The modifier axis, interrupt rows, and cross-cutting order above are fixed.
- **Out of scope.** CLI prompts and exit status, WebAssembly loading and JavaScript memory handling, React behavior, release packaging, and undocumented internal functions.
- **Source.** `/Users/jerell/Repos/dim` at revision commit `5d9cf0d`; this revision updates the description after merged API fixes.
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
  zig-library.md                       API claim checklists

foundations/
  type-and-dimension-model.md          typed dimensions and rational exponents
  unit-and-registry-model.md           units, aliases, prefixes, and registries
  ownership-and-errors.md              allocators, contexts, errors, and cleanup

library/
  quantity-arithmetic.md               pilot: typed quantity operations
  unit-construction.md                 constructing and composing units
  runtime-evaluation.md                evaluating expression strings
  contexts-and-constants.md            explicit context state and constants
  display-quantities.md               runtime display arithmetic
  formatting.md                        formatting quantities and units

cross-cutting/
  compile-time-safety.md               compile-time versus runtime failure boundaries
```

## Coverage

Status is one of `not started`, `drafted`, or `verified`.

| Document | Status |
| --- | --- |
| glossary.md | drafted |
| foundations/type-and-dimension-model.md | drafted |
| foundations/unit-and-registry-model.md | drafted |
| foundations/ownership-and-errors.md | drafted |
| library/quantity-arithmetic.md | drafted |
| library/unit-construction.md | drafted |
| library/runtime-evaluation.md | drafted |
| library/contexts-and-constants.md | drafted |
| library/display-quantities.md | drafted |
| library/formatting.md | drafted |
| cross-cutting/compile-time-safety.md | drafted |
| verification/ (1 checklist) | drafted |
| bug-triage.md | drafted |

## Reference

The source of truth for this revision is `/Users/jerell/Repos/dim` at commit `5d9cf0d`.

- `src/root.zig`: public exports, contexts, string evaluation, unit lookup, registries, and constants.
- `src/quantity.zig`: typed quantity construction, arithmetic, powers, scaling, and formatting wrappers.
- `src/Unit.zig`: unit conversion, composition, aliases, prefixes, and registries.
- `src/Dimension.zig`: base/derived dimensions, rational exponents, equality, and overflow-aware operations.
- `src/format.zig`: automatic, scientific, engineering, explicit-unit, and normalized-unit formatting.
- `src/runtime.zig`: allocator-owned display quantities and runtime arithmetic.
- `src/registry/*.zig`: built-in unit names, aliases, prefixes, and scales.
- `tests/consumer.zig`: external-consumer compilation and public API behavior.
- `build.zig`: library, CLI, test, and WASM build graph.
