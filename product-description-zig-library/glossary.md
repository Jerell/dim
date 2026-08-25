# Glossary

The vocabulary used across these documents. When a document uses one of these words, it means exactly this.

## The package

**Library consumer.** Zig code that imports the package as `dim` and uses its public types, functions, registries, or formatting helpers.

**Public API.** A declaration re-exported from `src/root.zig` or a public method on a returned public type. Internal helpers are not part of this description unless their behavior is observable through the public API.

**Library operation.** One consumer action such as constructing a quantity, adding two quantities, composing units, evaluating an expression, or formatting a result.

**Compile-time.** The phase in which Zig resolves generic types, dimensions, comptime units, and declarations before the program runs. A compile-time rejection prevents an executable from being produced.

**Runtime.** The phase after compilation in which values, strings, allocators, contexts, and error unions are processed.

## Types and values

**Dimension.** Seven rational exponents representing length, mass, time, current, temperature, amount, and luminous intensity. Derived dimensions are formed by adding, subtracting, or multiplying these exponents.

**Rational.** An exact numerator/denominator pair used for dimensions and rational powers. Equivalent fractions are normalized for equality.

**Quantity.** A strongly typed numeric value parameterized by a `Dimension`. Its stored value is canonical and it also carries an `is_delta` marker.

**Canonical value.** The base value stored by a quantity or unit after conversion to the library's canonical scale. It is not necessarily the number a consumer typed or formats.

**Unit.** A scale, optional affine offset, dimension, and symbol. A unit can construct a typed quantity, convert a quantity, or compose with another unit.

**Affine unit.** A unit with a non-zero offset, such as Celsius, Fahrenheit, or gauge/absolute pressure variants. Affine units cannot be composed through checked unit multiplication or exponentiation.

**Delta.** A quantity representing a difference rather than an absolute measurement. Temperature and pressure arithmetic preserve or produce this marker according to their absolute/delta operands.

**Unit registry.** A collection of units, aliases, and prefixes that can resolve a symbol. The package supplies SI, Imperial, CGS, and industrial registries.

**Prefix.** A multiplicative symbol and factor such as `k` for 1000. Prefixes apply only to non-affine units.

**Alias.** An alternate symbol that resolves to an existing unit.

## Operations and state

**Typed arithmetic.** Quantity addition, subtraction, multiplication, division, scaling, and powers whose dimensions are represented in the Zig type system.

**Checked operation.** An operation that returns an error when runtime state makes an otherwise typed operation unsafe, such as multiplying a temperature delta or composing affine units.

**Unchecked operation.** An operation that skips a runtime safety check because the caller has already established that the operands are multiplicative and safe.

**Context.** A `DimContext` owning runtime constants and scratch storage. Explicit contexts isolate state between consumers or workers.

**Default context.** The calling thread's convenience context used by `evaluate`, `findUnitAll`, and global constant helpers. It is not shared across threads.

**Runtime constant.** A named unit-like value stored in a context and resolved before built-in registries. Constants are process memory, not persisted configuration.

**Display quantity.** An allocator-owned runtime value containing a numeric value, dimension, unit string, format mode, delta marker, and value-space marker.

**Expression evaluation.** Parsing and calculating a string expression through `evaluate` or `evaluateWithContext`, returning an optional `LiteralValue`.

## Formatting and resources

**Format mode.** `none`, `auto`, `scientific`, or `engineering`, controlling how a quantity is rendered.

**Explicit unit formatting.** Formatting a quantity through a chosen `Unit` rather than allowing registry-based unit selection.

**Allocator ownership.** The rule identifying which allocator owns returned strings or display quantities and must eventually release them.

**Deinitialization.** The consumer's explicit cleanup step, such as `deinit` on a context or `deinitLiteralValue` on a returned value.

## Events that end or interrupt a library operation

**Compile-time rejection.** A type or dimension rule prevents compilation; no runtime operation begins.

**Runtime error.** An error union result such as `DimensionMismatch`, `MulDivTemperatureDelta`, or `AffineUnitCombination` that the caller can handle.

**Panic or assertion.** An unrecoverable failure path, including an unchecked Quantity precondition or a failed allocation that the caller does not handle. Unit affine composition returns an error instead of asserting.

**Return.** The operation has produced a value or error and the caller regains control. A return does not imply that allocator-owned results have been deinitialized.

**Teardown.** The caller deinitializes a context or returned owned value, ending its associated storage lifetime.
