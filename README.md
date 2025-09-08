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
100.000 kPa

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
  - Parse expressions like `10 celsius + 20 fahrenheit in kelvin`.
  - Support arithmetic (`+`, `-`, `*`, `/`).
  - Support derived units (`m/s`, `N`, `J`).
  - `in <unit>` to force output in a specific unit.
  - REPL mode for interactive calculations.
  - Configurable formatting (`:scientific`, `:engineering`, `:auto`, `:none`).

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

    const Length = dim.Quantity(dim.DIM.Length);
    const Time = dim.Quantity(dim.DIM.Time);

    // perform operations with quantities
    const d = Length.init(100.0);
    const t = Time.init(9.58);
    const v = d.div(t);

    // print a unit
    try io.printf("speed: {f} m/s\n", .{v});
    // print a unit with a chosen unit registry and formatting mode
    try io.printf("speed: {f}\n", .{v.With(dim.Registries.si, .scientific)});

    // search for a unit
    const u = dim.findUnitAllDynamic("erg", null);
    if (u) |val| {
        try io.printf("{s}, dim {any}\n", .{ val.symbol, val.dim });
    } else {
        try io.printf("No unit\n", .{});
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
3.000 m

$ printf "1 m + 2 m\n2 m in km\n" | dim
3.000 m
0.002 km

$ dim --file test.dim
# evaluates each non-empty line and prints a result per line

$ dim
> 1 m + 2 m
3.000 m
```

---

## 📖 Inspiration

- [Rust `uom`](https://crates.io/crates/uom) — type-safe zero-cost units of measure.
- [Julia `Unitful`](https://github.com/PainterQubits/Unitful.jl) and [DynamicQuantities](https://github.com/JuliaPhysics/DynamicQuantities.jl).
- [Crafting Interpreters](https://craftinginterpreters.com/) — for the CLI parser design.

---

## 📜 License

MIT — see [LICENSE](./LICENSE) for details.

## Plan

Add a runtime constants registry so users can define symbols that behave like units.

- Syntax (parentheses required to delimit the value):

  - `name = (Expr)`
  - Example: `d = (24 h)`
  - Example with expression: `d = (12 h + 12 h)`

- Semantics:

  - No type annotation in declarations; the dimension is inferred from the expression and stored with the constant.
  - Constants are defined in terms of base units; cycles are not possible.
  - Naming collisions are acceptable; constants take precedence over unit registries during lookup and formatting selection.

- Usage:

  - Constants can be used anywhere a unit symbol can be used.
  - Formatting/conversion precedence for `as` (or equivalent): try constants first, then fall back to configured unit registries (SI/CGS/Imperial, etc.).
  - Example: `d = (24 h) 1e6 s as d` displays one million seconds in days.

- REPL/CLI commands:
  - `list` — list all defined constants.
  - `show <name>` — show the constant’s base-unit expansion and dimension.
  - `clear <name>` — remove a specific constant.
  - `clear all` — remove all constants.

Notes:

- Parentheses are important to give an unambiguous end to the value in declarations.
