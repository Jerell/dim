# dim

**dim** is a dimensional analysis and unit conversion library for [Zig](https://ziglang.org), with an optional CLI tool for quick calculations.

It provides **compile-time dimensional safety** (you can’t add a pressure to a temperature), **unit conversions**, and **pretty-printing with SI prefixes and aliases**. The CLI lets you do quick calculations like:

```bash
$ dim "10 C + 20 F as K"
436.135 K

$ dim "10 C + 20 F as C"
162.985 °C

$ dim "1 bar as Pa:scientific"
1.000e5 Pa

$ dim "1 bar as kPa"
100 kPa

```

---

## ✨ Features

- **Library (`dim`)**

  - Strongly typed `Quantity` type parameterized by dimension.
  - Compile-time dimensional analysis (safe add/sub, derived units from mul/div).
  - Canonical SI storage (Pa, K, m, s, …).
  - Unit constructors (`bar(10)`, `C(20)`, `Pa(50000)`).
  - Formatting with:
    - SI prefixes (`1.0 kPa` instead of `1000 Pa`).
    - Engineering/scientific notation.
    - Derived unit aliases (`N`, `J`, `W`, `Hz`, …).
  - Configurable unit registries (SI, Imperial, CGS, or user-defined).
  - Extensible: add your own units, aliases, and prefixes at `comptime`.

- **CLI (`dim` tool)**
  - Parse expressions like `10 C + 20 F as K`.
  - Parse scientific notation such as `1.5e3 m` and `2E-3 km`.
  - Support arithmetic (`+`, `-`, `*`, `/`).
  - Support derived units (`m/s`, `N`, `J`).
  - `as <unit-or-constant>` to force output in a specific unit or user-defined constant; supports compound expressions after `as` (e.g., `kg/d`).
  - REPL mode for interactive calculations.
  - Configurable formatting (`:scientific`, `:engineering`, `:auto`, `:none`).
  - Runtime constants: define with `name = (Expr)`. Constants behave like units and take precedence over registries. Commands: `list`, `show <name>`, `clear <name>`, `clear all`.

---

## 🛠️ Example Usage

### Library

```zig
const std = @import("std");
const dim = @import("dim");

pub fn main() !void {
    const Si = dim.Units.si;
    const Length = dim.Quantity(dim.Dimensions.Length);
    const Time = dim.Quantity(dim.Dimensions.Time);

    // quantities in canonical SI units
    const d0 = Length.init(100.0); // 100 m
    const t0 = Time.init(10.0);   // 10 s

    // quantities from comptime units (dimension checked at compile time)
    const d1 = Si.km.from(100.0);    // 100 km
    const t1 = Si.h.from(1.0);       // 1 hour
    const d1b = Length.from(100.0, Si.km); // equivalent

    // quantities from runtime units (dimension checked at runtime)
    const km = dim.findUnitAll("km").?;
    const d2 = try Length.fromDynamic(100.0, km); // 100 km
    _ = .{ d0, t0, d1b, d2 };

    // typed arithmetic — v is Quantity(Velocity)
    const v = try d1.div(t1);

    // print with default formatting
    std.debug.print("speed: {f} m/s\n", .{v});
    // print with a unit registry and formatting mode
    std.debug.print("speed: {f}\n", .{v.with(dim.Registries.si, .scientific)});
    // convert to a specific compound unit
    const h = dim.findUnitAll("h").?;
    const kmh = km.div(h, "km/h");

    // or keep the runtime check when units may be affine
    const safe_kmh = try km.divChecked(h, "km/h");
    _ = kmh;
    std.debug.print("speed: {d} km/h\n", .{safe_kmh.fromCanonicalValue(v.value, false)});

    // evaluate string expressions; parse/runtime/allocation failures are typed
    const allocator = std.heap.page_allocator;
    var result = try dim.evaluate(allocator, "100 km/h as m/s", null);
    defer dim.deinitLiteralValue(allocator, &result);
    std.debug.print("result: {f}\n", .{result.display_quantity});
}
```

`Quantity.mul` and `Quantity.div` reject affine temperature deltas with
`error.MulDivTemperatureDelta`. Use `mulUnchecked` or `divUnchecked` only when
the caller has already established that both operands are multiplicative.

### CLI

Usage:

```bash
dim                 Start REPL (or read from stdin if piped)
dim "<expr>"        Evaluate a single expression
dim --file <path>   Evaluate each non-empty line in <path>
dim -               Read from stdin (one or more lines)
```

Examples:

```bash
$ dim "1 m + 2 m"
3 m

$ printf "1 m + 2 m\n2 m in km\n" | dim
3 m
0.002 km

$ dim --file test.dim
# evaluates each non-empty line and prints a result per line

$ dim
> 1 m + 2 m
3 m

# Define and use constants
$ dim "d = (24 h)"
86400 s

$ dim "1000000 s as d"
11.574 d

# Use constants in compound unit displays
$ dim "d = (24 h) 200 kg/h as kg/d"
4800 kg/d
```

---

## 🌐 Browser (WebAssembly) usage

You can compile the library to a WASM module and call it from JavaScript in the browser. The WASM wrapper exposes a small C-ABI for evaluating expressions and managing runtime constants.

### Build

```bash
zig build wasm -Doptimize=ReleaseSmall
# => zig-out/bin/dim_wasm.wasm
```

The repo-owned TypeScript wrapper shipped with the WASM release bundle lives at `wasm/dim.ts`. By default it looks for a colocated `dim_wasm.wasm`, and you can also initialize it with explicit `{ wasmUrl }` or `{ wasmBytes }` options when another app wants to control loading.

### Exports

The current ABI is context-based and returns structured values:

- `dim_ctx_new` / `dim_ctx_free`
- `dim_ctx_define`, `dim_ctx_clear`, `dim_ctx_clear_all`
- `dim_ctx_eval`
- `dim_ctx_convert_expr`, `dim_ctx_convert_value`
- `dim_ctx_is_compatible`, `dim_ctx_same_dimension`
- `dim_ctx_batch_convert_exprs`, `dim_ctx_batch_convert_values`
- `dim_alloc`, `dim_ffi_reset`, and `dim_free`

The shipped [`wasm/dim.ts`](wasm/dim.ts) wrapper exposes these as
`evalStructured`, `convertExpr`, `convertValue`, `isCompatible`,
`sameDimension`, batch conversion helpers, and context constant helpers.
Dimension components are exact `{ num, den }` rational pairs.

All strings and scratch buffers returned through the ABI belong to the calling
thread's FFI arena. Copy any string or unit you need, then call
`dim_ffi_reset` after the current batch of results has been consumed.
`dim_free` is retained as a source-compatible no-op for older callers.

### Browser example

```ts
import { evalStructured, formatEvalResult, initDim } from "./dim";

await initDim({ wasmUrl: "./dim_wasm.wasm" });
const result = evalStructured("100 km/h as m/s");
console.log(formatEvalResult(result)); // 27.77777777777778 m/s
```

The wrapper includes the minimal `wasi_snapshot_preview1` imports required by
the current `wasm32-wasi` artifact. Raw instantiation must provide the same
imports; an empty import object is not sufficient for this build.
The browser shim intentionally reports WASI `ENOTSUP` for filesystem, clock,
and polling operations it does not implement, rather than returning success.

The wrapper can also initialize from `{ wasmBase64 }`. Its automatic lookup
supports `dim_wasm.wasm.base64` beside the wrapper and at
`public/dim/dim_wasm.wasm.base64`. This text-safe form is used by the shadcn
registry because registry file payloads are serialized as UTF-8 text. Release
archives continue to ship the normal binary `dim_wasm.wasm`.

## React components and shadcn registry

This repository is also a public [shadcn GitHub registry](https://ui.shadcn.com/docs/registry/github).
It exposes three items:

- `dim` installs `@lib/dim/dim.ts` plus the text-safe WASM asset in
  `public/dim/`.
- `dim-provider` installs the runtime item and a client-side `DimProvider` /
  `useDim` context.
- `quantity-input` installs both items above plus the shadcn Input Group and
  Popover dependencies.

From a project that already has a `components.json` file, install the complete
quantity input with:

```bash
npx shadcn@latest add Jerell/dim/quantity-input
```

Or install only the runtime/provider:

```bash
npx shadcn@latest add Jerell/dim/dim
npx shadcn@latest add Jerell/dim/dim-provider
```

Wrap the relevant client tree once:

```tsx
import { DimProvider } from "@/components/dim-provider";

export function Providers({ children }: { children: React.ReactNode }) {
  return <DimProvider>{children}</DimProvider>;
}
```

Then use the square-edged input in a form or table cell. Plain numbers are
interpreted in the declared `unit`; full dim expressions are also accepted.

```tsx
import { QuantityInput } from "@/components/quantity-input";

<QuantityInput
  unit="bar"
  defaultValue="250 kPa"
  conversions={[
    { unit: "bar", label: "bara", decimalPlaces: 3 },
    { unit: "kPa", decimalPlaces: 1 },
    { unit: "psi", decimalPlaces: 2 },
  ]}
  onValueChange={(value) => console.log(value)}
/>;
```

`QuantityInput` has no rounded edges or shadow by default. Use
`groupClassName` to merge its border into table cells, and change the copied
component after installation if an application needs different presentation
or validation behavior.

Registry development commands:

```bash
just react-install
just storybook              # hot-reloading component workbench
just test-components
just test-components-watch
just registry-build
just registry-validate
just registry-view quantity-input
just check-react
```

`registry:build` recompiles WASM, regenerates the armored registry asset, and
writes static registry JSON to `public/r`. The root `registry.json` also makes
the repository directly installable without hosting those generated files.
Run `just add-ui <name>...` when a future component needs additional shadcn
primitives.

### Testing and Fuzzing

Run the complete test suite with:

```bash
zig build test
```

The suite includes library, CLI, fuzz smoke, external-consumer, and WASM ABI
contract coverage. CI additionally compiles a C header consumer, exercises the
shipped TypeScript wrapper against binary and base64 WASM, runs the React
component tests, validates the registry build, and builds Storybook.

The test suite also includes a built-in Zig fuzz target for arbitrary
expressions, REPL sessions, and unit expressions. Run a bounded fuzz pass with:

```bash
just fuzz 10000
# or: zig build test --fuzz=10000
```

Fuzzing uses Zig 0.16's `std.testing.fuzz`; malformed input is expected to
return an error, not crash the parser or evaluator.

---

## 🚀 Releases

GitHub Actions now handles both verification and packaging:

- CI runs tests plus the WASM build on Ubuntu, and native release builds on Ubuntu, macOS, and Windows.
- macOS native artifacts are built separately on Apple Silicon (`macos-15`) and Intel (`macos-15-intel`) runners, so releases include both `aarch64` and `x86_64` downloads.
- A GitHub release is created automatically on pushes to `main` when `build.zig.zon` contains a new semantic version other than `0.0.0`.
- Native release bundles include the CLI, static libraries, `dim.h`, the license, and the README.
- The WASM release bundle includes `dim_wasm.wasm`, `dim.ts`, the license, and the README.

To cut a release, bump `.version` in `build.zig.zon`, merge to `main`, and let the release workflow publish `v<version>`.

---

## 📖 Inspiration

- [Rust `uom`](https://crates.io/crates/uom) — type-safe zero-cost units of measure.
- [Julia `Unitful`](https://github.com/PainterQubits/Unitful.jl) and [DynamicQuantities](https://github.com/JuliaPhysics/DynamicQuantities.jl).
- [Crafting Interpreters](https://craftinginterpreters.com/) — for the CLI parser design.

---

## 📜 License

MIT — see [LICENSE](./LICENSE) for details.

## Notes

- Parentheses are required in constant declarations to clearly delimit the value expression: `name = (Expr)`.
