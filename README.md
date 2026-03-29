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
const Io = @import("./io.zig").Io;

pub fn main() !void {
    var io = Io.init();
    defer io.flushAll() catch |e| std.debug.print("flush error: {s}\n", .{@errorName(e)});

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

    // typed arithmetic — v is Quantity(Velocity)
    const v = d1.div(t1);

    // print with default formatting
    try io.printf("speed: {f} m/s\n", .{v});
    // print with a unit registry and formatting mode
    try io.printf("speed: {f}\n", .{v.with(dim.Registries.si, .scientific)});
    // print in a specific compound unit
    const h = dim.findUnitAll("h").?;
    const kmh = km.div(h, "km/h");
    try io.printf("speed: {f}\n", .{v.asUnit(kmh, .none)});

    // or keep the runtime check when units may be affine
    const safe_kmh = try km.divChecked(h, "km/h");
    try io.printf("speed: {f}\n", .{v.asUnit(safe_kmh, .none)});

    // evaluate string expressions
    const allocator = std.heap.page_allocator;
    if (dim.evaluate(allocator, "100 km/h as m/s", null)) |result| {
        try io.printf("result: {f}\n", .{result.display_quantity});
    }
}
```

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

### Exports

- `dim_eval(input_ptr, input_len, out_ptr_ptr, out_len_ptr) -> i32` (0 = ok)
- `dim_define(name_ptr, name_len, expr_ptr, expr_len) -> i32` (0 = ok)
- `dim_clear(name_ptr, name_len) -> void`
- `dim_clear_all() -> void`
- `dim_alloc(n) -> u8*` (returns module-owned memory)
- `dim_free(ptr, len) -> void` (free memory allocated by the module)

`dim_eval` returns an owned UTF-8 string; you must free it with `dim_free`.

### Browser example (WASI polyfill)

Below is a minimal example using `@wasmer/wasi` for WASI bindings in the browser:

```js
import { init, WASI } from "@wasmer/wasi";
import browserBindings from "@wasmer/wasi/lib/bindings/browser";

// 1) Load WASI runtime (required) and instantiate the module
await init();
const wasi = new WASI({ bindings: browserBindings });

const moduleBytes = fetch("zig-out/bin/dim_wasm.wasm");
const module = await WebAssembly.compileStreaming(moduleBytes);
const instance = await wasi.instantiate(module, {});
wasi.start(instance);

const { memory, dim_alloc, dim_free, dim_eval, dim_define } = instance.exports;
const enc = new TextEncoder();
const dec = new TextDecoder();

function writeUtf8(str) {
  const bytes = enc.encode(str);
  const ptr = dim_alloc(bytes.length);
  new Uint8Array(memory.buffer, ptr, bytes.length).set(bytes);
  return { ptr, len: bytes.length };
}

function readBytes(ptr, len) {
  return new Uint8Array(memory.buffer, ptr, len);
}

async function evalDim(expr) {
  const { ptr: inPtr, len: inLen } = writeUtf8(expr);
  const scratch = dim_alloc(8 /* out_ptr */ + 8 /* out_len */);

  // In wasm32-wasi, usize is 4 bytes. We'll treat out slots as 4 + 4.
  const outPtrPtr = scratch;
  const outLenPtr = scratch + 4;

  const rc = dim_eval(inPtr, inLen, outPtrPtr, outLenPtr);
  dim_free(inPtr, inLen);
  if (rc !== 0) {
    dim_free(scratch, 8);
    throw new Error("dim_eval failed");
  }

  const dv = new DataView(memory.buffer);
  const outPtr = dv.getUint32(outPtrPtr, true);
  const outLen = dv.getUint32(outLenPtr, true);
  dim_free(scratch, 8);

  const outBytes = readBytes(outPtr, outLen);
  const outStr = dec.decode(outBytes);
  dim_free(outPtr, outLen);
  return outStr;
}

async function defineConst(name, expr) {
  const n = writeUtf8(name);
  const v = writeUtf8(expr);
  const rc = dim_define(n.ptr, n.len, v.ptr, v.len);
  dim_free(n.ptr, n.len);
  dim_free(v.ptr, v.len);
  if (rc !== 0) throw new Error("dim_define failed");
}

// Examples
console.log(await evalDim("1 m"));
console.log(await evalDim("2 m * 3 m"));
await defineConst("c", "299792458 m/s");
console.log(await evalDim("c as m/s"));
```

Notes:

- Returned strings are module-owned; always free them with `dim_free(ptr, len)`.
- `dim_define(name, value_expr)` lets you create constants usable in expressions (e.g. `d = (24 h)` is equivalent to calling `dim_define("d", "24 h")`).
- The expression grammar is the same as the CLI (supports `as`, compound units, arithmetic, and formatting modes like `:engineering`).

### Minimal loader (no WASI required)

The exported functions do not depend on WASI. You can instantiate with an empty import object:

```js
// Browser
const mod = await WebAssembly.compileStreaming(
  fetch("zig-out/bin/dim_wasm.wasm")
);
const { exports } = await WebAssembly.instantiate(mod, {});

// Node
import { readFile } from "node:fs/promises";
const bytes = await readFile("zig-out/bin/dim_wasm.wasm");
const mod = await WebAssembly.compile(bytes);
const { exports } = await WebAssembly.instantiate(mod, {});

// exports contains: memory, dim_eval, dim_define, dim_clear, dim_clear_all, dim_alloc, dim_free
```

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
