const std = @import("std");
const Unit = @import("unit.zig").Unit;
const UnitRegistry = @import("unit.zig").UnitRegistry;
const Dimension = @import("dimension.zig").Dimension;
const Rational = @import("rational.zig").Rational;
const SiPrefixes = @import("registry/si.zig").Registry.prefixes;

pub const FormatMode = enum { auto, none, scientific, engineering };

/// Format a value + dimension using a registry
pub fn formatQuantity(
    writer: *std.Io.Writer,
    value: f64,
    dim: Dimension,
    is_delta: bool,
    reg: UnitRegistry,
    mode: FormatMode,
) !void {
    // 1. Find a base unit in the registry that matches this dimension
    var base: ?Unit = null;
    for (reg.units) |u| {
        if (Dimension.eql(u.dim, dim)) {
            base = u;
            break;
        }
    }
    if (base == null) {
        return writer.print("{d} [{any}]", .{ value, dim });
    }

    const u = base.?;
    const val = u.fromCanonical(value);

    // Prefix for deltas
    const delta_prefix: []const u8 = if (is_delta) "Δ" else "";

    // 2. Format according to mode
    switch (mode) {
        .none => try writer.print("{s}{d} {s}", .{ delta_prefix, val, u.symbol }),
        .scientific => try writer.print("{s}{e:.3} {s}", .{ delta_prefix, val, u.symbol }),
        .engineering => {
            if (val == 0.0) {
                try writer.print("{s}0.000 {s}", .{ delta_prefix, u.symbol });
            } else {
                const exp_f64 = @floor(std.math.log10(@abs(val)));
                const exp = @as(i32, @intFromFloat(exp_f64));
                const eng_exp = exp - @mod(exp, 3);
                const scaled = val / std.math.pow(f64, 10.0, @floatFromInt(eng_exp));
                try writer.print("{s}{d:.3}e{d} {s}", .{ delta_prefix, scaled, eng_exp, u.symbol });
            }
        },
        .auto => {
            if (val == 0.0) {
                try writer.print("{s}0.000 {s}", .{ delta_prefix, u.symbol });
            } else {
                var scaled_val = val;
                var matched = false;
                for (reg.prefixes) |p| {
                    const v = val / p.factor;
                    if (v >= 1.0 and v < 1000.0) {
                        scaled_val = v;
                        try writer.print("{s}{d:.3} {s}{s}", .{ delta_prefix, scaled_val, p.symbol, u.symbol });
                        matched = true;
                        break;
                    }
                }
                if (!matched) {
                    try writer.print("{s}{d:.3} {s}", .{ delta_prefix, val, u.symbol });
                }
            }
        },
    }
}

/// Format a quantity using a specific display unit (not a registry).
pub fn formatQuantityAsUnit(
    writer: *std.Io.Writer,
    q: anytype, // Quantity(Dim) or DisplayQuantity
    display_unit: Unit,
    mode: FormatMode,
) !void {
    // Extract canonical value
    const val = display_unit.fromCanonical(q.value);

    const delta_prefix: []const u8 = if (q.is_delta) "Δ" else "";

    switch (mode) {
        .none => try writer.print("{s}{d} {s}", .{ delta_prefix, val, display_unit.symbol }),
        .scientific => try writer.print("{s}{e:.3} {s}", .{ delta_prefix, val, display_unit.symbol }),
        .engineering => {
            if (val == 0.0) {
                try writer.print("{s}0.000 {s}", .{ delta_prefix, display_unit.symbol });
            } else {
                const exp_f64 = @floor(std.math.log10(@abs(val)));
                const exp = @as(i32, @intFromFloat(exp_f64));
                const eng_exp = exp - @mod(exp, 3);
                const scaled = val / std.math.pow(f64, 10.0, @floatFromInt(eng_exp));
                try writer.print("{s}{d:.3}e{d} {s}", .{ delta_prefix, scaled, eng_exp, display_unit.symbol });
            }
        },
        .auto => try writer.print("{s}{d:.3} {s}", .{ delta_prefix, val, display_unit.symbol }),
    }
}

pub fn normalizeUnitString(
    allocator: std.mem.Allocator,
    dim: Dimension,
    fallback: []const u8,
    reg: UnitRegistry,
) ![]u8 {
    _ = fallback;

    if (findExactDimensionSymbol(reg, dim)) |sym| {
        return try std.fmt.allocPrint(allocator, "{s}", .{sym});
    }

    const base = detectBaseSymbols(reg);
    if (dim.hasFractional()) {
        return formatSignedProduct(allocator, dim, base);
    }

    const numerator = positiveIntegerPart(dim);
    const denominator = negativeIntegerPart(dim);

    const numerator_str = try formatIntegerPart(allocator, numerator, base, reg);
    defer if (numerator_str) |s| allocator.free(s);
    const denominator_str = try formatIntegerPart(allocator, denominator, base, reg);
    defer if (denominator_str) |s| allocator.free(s);

    if (numerator_str == null and denominator_str == null) {
        return try std.fmt.allocPrint(allocator, "1", .{});
    }
    if (denominator_str == null) {
        return try std.fmt.allocPrint(allocator, "{s}", .{numerator_str.?});
    }
    if (numerator_str == null) {
        return try std.fmt.allocPrint(allocator, "1/{s}", .{denominator_str.?});
    }
    return try std.fmt.allocPrint(allocator, "{s}/{s}", .{ numerator_str.?, denominator_str.? });
}

const BaseSymbols = struct {
    L: []const u8 = "m",
    M: []const u8 = "kg",
    T: []const u8 = "s",
    I: []const u8 = "A",
    Th: []const u8 = "K",
    N: []const u8 = "mol",
    J: []const u8 = "cd",
};

fn detectBaseSymbols(reg: UnitRegistry) BaseSymbols {
    var base = BaseSymbols{};
    for (reg.units) |u| {
        if (u.scale != 1.0) continue;
        const d = u.dim;
        if (Dimension.eql(d, Dimension.initInts(1, 0, 0, 0, 0, 0, 0))) base.L = u.symbol;
        if (Dimension.eql(d, Dimension.initInts(0, 1, 0, 0, 0, 0, 0))) base.M = u.symbol;
        if (Dimension.eql(d, Dimension.initInts(0, 0, 1, 0, 0, 0, 0))) base.T = u.symbol;
        if (Dimension.eql(d, Dimension.initInts(0, 0, 0, 1, 0, 0, 0))) base.I = u.symbol;
        if (Dimension.eql(d, Dimension.initInts(0, 0, 0, 0, 1, 0, 0))) base.Th = u.symbol;
        if (Dimension.eql(d, Dimension.initInts(0, 0, 0, 0, 0, 1, 0))) base.N = u.symbol;
        if (Dimension.eql(d, Dimension.initInts(0, 0, 0, 0, 0, 0, 1))) base.J = u.symbol;
    }
    return base;
}

fn findExactDimensionSymbol(reg: UnitRegistry, dim: Dimension) ?[]const u8 {
    var any_match: ?[]const u8 = null;
    for (reg.units) |u| {
        if (!Dimension.eql(u.dim, dim)) continue;
        if (u.scale == 1.0) return u.symbol;
        if (any_match == null) any_match = u.symbol;
    }
    return any_match;
}

fn positiveIntegerPart(dim: Dimension) Dimension {
    return Dimension.initInts(
        positiveInt(dim.L),
        positiveInt(dim.M),
        positiveInt(dim.T),
        positiveInt(dim.I),
        positiveInt(dim.Th),
        positiveInt(dim.N),
        positiveInt(dim.J),
    );
}

fn negativeIntegerPart(dim: Dimension) Dimension {
    return Dimension.initInts(
        negativeMagnitudeInt(dim.L),
        negativeMagnitudeInt(dim.M),
        negativeMagnitudeInt(dim.T),
        negativeMagnitudeInt(dim.I),
        negativeMagnitudeInt(dim.Th),
        negativeMagnitudeInt(dim.N),
        negativeMagnitudeInt(dim.J),
    );
}

fn positiveInt(r: Rational) i32 {
    const value = r.toInt().?;
    return if (value > 0) value else 0;
}

fn negativeMagnitudeInt(r: Rational) i32 {
    const value = r.toInt().?;
    return if (value < 0) -value else 0;
}

fn formatIntegerPart(
    allocator: std.mem.Allocator,
    dim: Dimension,
    base: BaseSymbols,
    reg: UnitRegistry,
) !?[]u8 {
    if (dim.isDimensionless()) return null;
    for (reg.units) |u| {
        if (u.scale == 1.0 and Dimension.eql(u.dim, dim)) {
            return try std.fmt.allocPrint(allocator, "{s}", .{u.symbol});
        }
    }

    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);
    var w = buf.writer(allocator);
    var wrote_any = false;

    try appendIntegerComponent(&w, &wrote_any, base.M, dim.M.toInt().?);
    try appendIntegerComponent(&w, &wrote_any, base.L, dim.L.toInt().?);
    try appendIntegerComponent(&w, &wrote_any, base.T, dim.T.toInt().?);
    try appendIntegerComponent(&w, &wrote_any, base.I, dim.I.toInt().?);
    try appendIntegerComponent(&w, &wrote_any, base.Th, dim.Th.toInt().?);
    try appendIntegerComponent(&w, &wrote_any, base.N, dim.N.toInt().?);
    try appendIntegerComponent(&w, &wrote_any, base.J, dim.J.toInt().?);

    if (!wrote_any) return null;
    return try buf.toOwnedSlice(allocator);
}

fn appendIntegerComponent(writer: anytype, wrote_any: *bool, symbol: []const u8, exponent: i32) !void {
    if (exponent == 0) return;
    if (wrote_any.*) try writer.writeAll("*");
    try writer.writeAll(symbol);
    if (exponent != 1) try writer.print("^{d}", .{exponent});
    wrote_any.* = true;
}

fn formatSignedProduct(
    allocator: std.mem.Allocator,
    dim: Dimension,
    base: BaseSymbols,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);
    var w = buf.writer(allocator);
    var wrote_any = false;

    try appendSignedComponent(&w, &wrote_any, base.M, dim.M);
    try appendSignedComponent(&w, &wrote_any, base.L, dim.L);
    try appendSignedComponent(&w, &wrote_any, base.T, dim.T);
    try appendSignedComponent(&w, &wrote_any, base.I, dim.I);
    try appendSignedComponent(&w, &wrote_any, base.Th, dim.Th);
    try appendSignedComponent(&w, &wrote_any, base.N, dim.N);
    try appendSignedComponent(&w, &wrote_any, base.J, dim.J);

    if (!wrote_any) try w.writeAll("1");
    return buf.toOwnedSlice(allocator);
}

fn appendSignedComponent(writer: anytype, wrote_any: *bool, symbol: []const u8, exponent: Rational) !void {
    if (exponent.isZero()) return;
    if (wrote_any.*) try writer.writeAll("*");
    try writer.writeAll(symbol);
    try exponent.formatExponent(writer);
    wrote_any.* = true;
}
