# dim

**dim** is a dimensional analysis and unit conversion library for [Zig](https://ziglang.org), with an optional CLI tool for quick calculations.

It provides **compile-time dimensional safety** (you can’t add a pressure to a temperature), **unit conversions**, and **pretty-printing with SI prefixes and aliases**. The CLI lets you do quick calculations like:

```bash
$ dim 10 celsius + 20 fahrenheit in kelvin
293.15 K

$ dim 1 bar in psi
14.5038 psi

$ dim 5 m / 2 s in km/h
9.0 km/h
```

---

## ✨ Features (planned)

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
  - Default output in canonical SI units with smart formatting.
  - Optional `in <unit>` to force output in a specific unit.
  - REPL mode for interactive calculations.
  - Configurable formatting (`--scientific`, `--engineering`).

---

## 📚 Roadmap

### Library

- [x] Define base dimensions (M, L, T, Θ).
- [x] Implement `Quantity(Dim, Registry)` generic type.
- [x] Add unit constructors for common units (Pa, bar, K, °C, m, s).
- [x] Implement arithmetic (`add`, `sub`, `mul`, `div`) with compile-time dimensional analysis.
- [x] Implement formatting:
  - [x] SI prefixes (auto, none, scientific, engineering).
  - [x] Derived unit aliases (N, J, W, Hz).
- [x] Implement configurable `UnitRegistry` (aliases + prefixes).
- [x] Provide built-in registries:
  - [x] SI (default).
  - [x] Imperial (psi, °F, miles, …).
  - [x] CGS (cm, g, dynes, …).

### CLI

- [ ] Tokenizer for numbers, units, operators, `in`.
- [ ] Parser for arithmetic expressions + optional `in <unit>`.
- [ ] AST nodes:
  - [ ] `Literal`
  - [ ] `UnitExpr` (e.g. `10 celsius`)
  - [ ] `BinaryExpr` (`+`, `-`, `*`, `/`)
  - [ ] `ConversionExpr` (`in kelvin`)
- [ ] Evaluator that maps AST → `Quantity` operations.
- [ ] Default output in canonical SI units.
- [ ] Implement `in <unit>` conversion.
- [ ] Add REPL mode (`dim>` prompt).
- [ ] Add CLI flags for formatting (`--scientific`, `--engineering`).

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

```bash
$ dim 10 celsius + 20 fahrenheit
293.15 K

$ dim 1 bar + 50 kPa
150.0 kPa

$ dim 5 m / 2 s in km/h
9.0 km/h
```

---

## 📖 Inspiration

- [Rust `uom`](https://crates.io/crates/uom) — type-safe zero-cost units of measure.
- [Julia `Unitful`](https://github.com/PainterQubits/Unitful.jl) and [DynamicQuantities](https://github.com/JuliaPhysics/DynamicQuantities.jl).
- [Crafting Interpreters](https://craftinginterpreters.com/) — for the CLI parser design.

---

## 🔮 Future Ideas

- Runtime parsing of unit strings (`"10 kPa"` → `Quantity(Pressure)`).
- Configurable default output units (e.g. always show pressure in bar).
- Support for physical constants (`c`, `G`, `R`, …).
- More advanced CLI features:
  - Parentheses in expressions.
  - Exponents (`m^2`, `s^-1`).
  - Unit simplification (`N·m` → `J`).
- Integration with plotting/visualization tools.

---

## 📜 License

MIT — see [LICENSE](./LICENSE) for details.
