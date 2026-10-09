const std = @import("std");
const Dimension = @import("dimension.zig").Dimension;
const Dimensions = @import("dimension.zig").Dimensions;
const Rational = @import("rational.zig").Rational;
const Format = @import("format.zig");
const Unit = @import("unit.zig").Unit;
const SiRegistry = @import("registry/si.zig").Registry;
const ImperialRegistry = @import("registry/imperial.zig").Registry;
const CgsRegistry = @import("registry/cgs.zig").Registry;
const IndustrialRegistry = @import("registry/industrial.zig").Registry;

pub const ValueSpace = enum {
    canonical,
    display,
};

/// Rounds a value to 15 significant digits for display. Values are stored
/// canonically, so a unit whose scale is not exact in binary shows round-trip
/// noise: 500 ppm is 500 * 1e-6 / 1e-6 = 500.00000000000006. Fifteen digits is
/// the precision every double carries, so no real digit is lost.
pub fn displayRounded(value: f64) f64 {
    if (value == 0 or !std.math.isFinite(value)) return value;
    const magnitude = @floor(std.math.log10(@abs(value)));
    const factor = std.math.pow(f64, 10, 14 - magnitude);
    if (!std.math.isFinite(factor) or factor == 0) return value;
    const rounded = @round(value * factor) / factor;
    return if (std.math.isFinite(rounded)) rounded else value;
}

pub const DisplayQuantity = struct {
    value: f64,
    dim: Dimension,
    unit: []const u8, // preferred display unit symbol
    // Values returned by the evaluator and runtime helpers own their unit
    // string. Struct literals remain borrowed by default, which makes the
    // public type safe to construct with string literals.
    owns_unit: bool = false,
    mode: Format.FormatMode = .none,
    is_delta: bool = false,
    value_space: ValueSpace = .canonical,
    // Canonical size of one display unit, for a display-space value whose
    // unit is a compound expression and so has no registry entry.
    display_factor: f64 = 1.0,

    pub fn format(self: DisplayQuantity, writer: *std.Io.Writer) !void {
        const display_value = displayRounded(self.valueForCurrentUnit());
        const delta_prefix: []const u8 = if (self.is_delta) "Δ" else "";
        const show_unit = !self.dim.isDimensionless() or !std.mem.eql(u8, self.unit, "1");
        switch (self.mode) {
            .none => {
                if (show_unit) {
                    try writer.print("{s}{d} {s}", .{ delta_prefix, display_value, self.unit });
                } else {
                    try writer.print("{s}{d}", .{ delta_prefix, display_value });
                }
            },
            .auto => {
                if (show_unit) {
                    try writer.print("{s}{d:.3} {s}", .{ delta_prefix, display_value, self.unit });
                } else {
                    try writer.print("{s}{d:.3}", .{ delta_prefix, display_value });
                }
            },
            .scientific => {
                if (show_unit) {
                    try writer.print("{s}{e:.3} {s}", .{ delta_prefix, display_value, self.unit });
                } else {
                    try writer.print("{s}{e:.3}", .{ delta_prefix, display_value });
                }
            },
            .engineering => {
                if (display_value == 0.0) {
                    if (show_unit) {
                        try writer.print("{s}0.000 {s}", .{ delta_prefix, self.unit });
                    } else {
                        try writer.print("{s}0.000", .{delta_prefix});
                    }
                } else {
                    const exp_f64 = @floor(std.math.log10(@abs(display_value)));
                    const exp = @as(i32, @intFromFloat(exp_f64));
                    const eng_exp = exp - @mod(exp, 3);
                    const scaled = display_value / std.math.pow(f64, 10.0, @floatFromInt(eng_exp));
                    if (show_unit) {
                        try writer.print("{s}{d:.3}e{d} {s}", .{ delta_prefix, scaled, eng_exp, self.unit });
                    } else {
                        try writer.print("{s}{d:.3}e{d}", .{ delta_prefix, scaled, eng_exp });
                    }
                }
            },
        }
    }

    pub fn canonicalValue(self: DisplayQuantity) f64 {
        if (self.value_space == .canonical) return self.value;
        if (findBuiltinUnit(self.unit)) |u| {
            return u.toCanonicalValue(self.value, self.is_delta);
        }
        return self.value * self.display_factor;
    }

    pub fn valueForCurrentUnit(self: DisplayQuantity) f64 {
        if (self.value_space == .display) return self.value;
        if (findBuiltinUnit(self.unit)) |u| {
            return u.fromCanonicalValue(self.value, self.is_delta);
        }
        return self.value;
    }

    /// Release an owned result. Treat an owned value as move-only until this
    /// call; borrowed struct literals are safe no-ops.
    pub fn deinit(self: *DisplayQuantity, allocator: std.mem.Allocator) void {
        if (self.owns_unit) allocator.free(self.unit);
        self.* = undefined;
    }
};

pub fn scaleDisplay(allocator: std.mem.Allocator, dq: DisplayQuantity, factor: f64) !DisplayQuantity {
    if (isOffsetPoint(dq)) return error.OffsetUnitArithmetic;
    return DisplayQuantity{
        .value = dq.value * factor,
        .dim = dq.dim,
        .unit = try allocator.dupe(u8, dq.unit),
        .owns_unit = true,
        .mode = dq.mode,
        .is_delta = dq.is_delta,
        .value_space = dq.value_space,
        .display_factor = dq.display_factor,
    };
}

/// Read a quantity as a difference: "Δ20 °C" is twenty degrees, not the
/// temperature 20 °C.
pub fn deltaDisplay(allocator: std.mem.Allocator, dq: DisplayQuantity) !DisplayQuantity {
    if (isOffsetPoint(dq)) {
        return displayResultFromCanonical(allocator, offsetStep(dq), dq.dim, dq.unit, dq.mode, true);
    }
    return DisplayQuantity{
        .value = dq.value,
        .dim = dq.dim,
        .unit = try allocator.dupe(u8, dq.unit),
        .owns_unit = true,
        .mode = dq.mode,
        .is_delta = true,
        .value_space = dq.value_space,
        .display_factor = dq.display_factor,
    };
}

pub fn addDisplay(allocator: std.mem.Allocator, a: DisplayQuantity, b: DisplayQuantity) !DisplayQuantity {
    if (!Dimension.eql(a.dim, b.dim)) return error.InvalidOperands;
    // "20 °C + 10 °C" is a temperature plus a change, so a point on an offset
    // scale added to an absolute value contributes its step, not its offset.
    const addend = if (!a.is_delta and isOffsetPoint(b)) offsetStep(b) else b.canonicalValue();
    const canonical_value = a.canonicalValue() + addend;
    const result_is_delta = inferAddDeltaState(a.dim, a.is_delta, b.is_delta);
    return displayResultFromCanonical(allocator, canonical_value, a.dim, a.unit, a.mode, result_is_delta);
}

pub fn subDisplay(allocator: std.mem.Allocator, a: DisplayQuantity, b: DisplayQuantity) !DisplayQuantity {
    if (!Dimension.eql(a.dim, b.dim)) return error.InvalidOperands;
    const canonical_value = a.canonicalValue() - b.canonicalValue();
    const result_is_delta = inferSubDeltaState(a.dim, a.is_delta, b.is_delta);
    return displayResultFromCanonical(allocator, canonical_value, a.dim, a.unit, a.mode, result_is_delta);
}

pub fn mulDisplay(allocator: std.mem.Allocator, a: DisplayQuantity, b: DisplayQuantity) !DisplayQuantity {
    if (isOffsetPoint(a) or isOffsetPoint(b)) return error.OffsetUnitArithmetic;

    const new_dim = Dimension.checkedAdd(a.dim, b.dim) orelse return error.DimensionOverflow;

    const fallback = try std.fmt.allocPrint(allocator, "{s}*{s}", .{ a.unit, b.unit });
    defer allocator.free(fallback);
    const normalized_unit = try Format.normalizeUnitString(
        allocator,
        new_dim,
        fallback,
        SiRegistry,
    );

    return DisplayQuantity{
        .value = a.canonicalValue() * b.canonicalValue(),
        .dim = new_dim,
        .unit = normalized_unit,
        .owns_unit = true,
        .mode = .none,
        .is_delta = false,
        .value_space = .canonical,
    };
}

pub fn divDisplay(allocator: std.mem.Allocator, a: DisplayQuantity, b: DisplayQuantity) !DisplayQuantity {
    if (isOffsetPoint(a) or isOffsetPoint(b)) return error.OffsetUnitArithmetic;

    const new_dim = Dimension.checkedSub(a.dim, b.dim) orelse return error.DimensionOverflow;

    const fallback = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ a.unit, b.unit });
    defer allocator.free(fallback);
    const normalized_unit = try Format.normalizeUnitString(
        allocator,
        new_dim,
        fallback,
        SiRegistry,
    );

    return DisplayQuantity{
        .value = a.canonicalValue() / b.canonicalValue(),
        .dim = new_dim,
        .unit = normalized_unit,
        .owns_unit = true,
        .mode = .none,
        .is_delta = false,
        .value_space = .canonical,
    };
}

pub fn powDisplayInt(allocator: std.mem.Allocator, a: DisplayQuantity, exp_int: i32) !DisplayQuantity {
    if (isOffsetPoint(a)) return error.OffsetUnitArithmetic;
    const new_dim = Dimension.checkedMulByRational(a.dim, Rational.fromInt(exp_int)) orelse return error.DimensionOverflow;

    const fallback = try std.fmt.allocPrint(allocator, "{s}^{d}", .{ a.unit, exp_int });
    defer allocator.free(fallback);
    const normalized_unit = try Format.normalizeUnitString(
        allocator,
        new_dim,
        fallback,
        SiRegistry,
    );

    const exponent = @as(f64, @floatFromInt(exp_int));
    return DisplayQuantity{
        .value = std.math.pow(f64, a.canonicalValue(), exponent),
        .dim = new_dim,
        .unit = normalized_unit,
        .owns_unit = true,
        .mode = .none,
        .is_delta = false,
        .value_space = .canonical,
    };
}

pub fn powDisplayRational(allocator: std.mem.Allocator, a: DisplayQuantity, exp: Rational) !DisplayQuantity {
    if (isOffsetPoint(a)) return error.OffsetUnitArithmetic;
    const new_dim = Dimension.checkedMulByRational(a.dim, exp) orelse return error.DimensionOverflow;

    const fallback = if (exp.isInteger())
        try std.fmt.allocPrint(allocator, "{s}^{d}", .{ a.unit, exp.num })
    else
        try std.fmt.allocPrint(allocator, "{s}^({d}/{d})", .{ a.unit, exp.num, exp.den });
    defer allocator.free(fallback);
    const normalized_unit = try Format.normalizeUnitString(
        allocator,
        new_dim,
        fallback,
        SiRegistry,
    );

    return DisplayQuantity{
        .value = std.math.pow(f64, a.canonicalValue(), exp.toF64()),
        .dim = new_dim,
        .unit = normalized_unit,
        .owns_unit = true,
        .mode = .none,
        .is_delta = false,
        .value_space = .canonical,
    };
}

pub fn powDisplay(allocator: std.mem.Allocator, a: DisplayQuantity, exp_int: i32) !DisplayQuantity {
    return powDisplayInt(allocator, a, exp_int);
}

fn findBuiltinUnit(symbol: []const u8) ?Unit {
    if (SiRegistry.findExact(symbol)) |u| return u;
    if (ImperialRegistry.findExact(symbol)) |u| return u;
    if (CgsRegistry.findExact(symbol)) |u| return u;
    if (IndustrialRegistry.findExact(symbol)) |u| return u;

    if (SiRegistry.find(symbol)) |u| return u;
    if (ImperialRegistry.find(symbol)) |u| return u;
    if (CgsRegistry.find(symbol)) |u| return u;
    if (IndustrialRegistry.find(symbol)) |u| return u;

    return null;
}

/// An absolute value in a unit with an offset (°C, °F, barg) is a point on a
/// scale. Multiplying, dividing or scaling it has two readings, on the scale
/// or from absolute zero, so those operations refuse it. Convert it first
/// ("25 °C as K") or use a difference ("30 °C - 20 °C").
pub fn isOffsetPoint(dq: DisplayQuantity) bool {
    if (dq.is_delta) return false;
    const unit = findBuiltinUnit(dq.unit) orelse return false;
    return unit.isAffine();
}

/// The size of an offset point read as a difference, in canonical units.
fn offsetStep(dq: DisplayQuantity) f64 {
    const unit = findBuiltinUnit(dq.unit) orelse return dq.canonicalValue();
    return unit.toCanonicalValue(dq.valueForCurrentUnit(), true);
}

fn isTemperatureDim(dim: Dimension) bool {
    return Dimension.eql(dim, Dimensions.Temperature);
}

fn isPressureDim(dim: Dimension) bool {
    return Dimension.eql(dim, Dimensions.Pressure);
}

fn isPressureBarFamilySymbol(symbol: []const u8) bool {
    return std.mem.eql(u8, symbol, "bar") or std.mem.eql(u8, symbol, "bara") or std.mem.eql(u8, symbol, "barg");
}

fn inferAddDeltaState(dim: Dimension, lhs_is_delta: bool, rhs_is_delta: bool) bool {
    if (isTemperatureDim(dim) or isPressureDim(dim)) {
        return lhs_is_delta and rhs_is_delta;
    }
    return lhs_is_delta or rhs_is_delta;
}

fn inferSubDeltaState(dim: Dimension, lhs_is_delta: bool, rhs_is_delta: bool) bool {
    if (isTemperatureDim(dim) or isPressureDim(dim)) {
        if (!lhs_is_delta and !rhs_is_delta) return true;
        if (!lhs_is_delta and rhs_is_delta) return false;
        if (lhs_is_delta and rhs_is_delta) return true;
        return true;
    }
    return lhs_is_delta or rhs_is_delta;
}

fn displayResultFromCanonical(
    allocator: std.mem.Allocator,
    canonical_value: f64,
    dim: Dimension,
    preferred_unit: []const u8,
    mode: Format.FormatMode,
    is_delta: bool,
) !DisplayQuantity {
    const result_unit = if (is_delta and isPressureDim(dim) and isPressureBarFamilySymbol(preferred_unit))
        "bar"
    else
        preferred_unit;

    if (findBuiltinUnit(result_unit)) |u| {
        return .{
            .value = u.fromCanonicalValue(canonical_value, is_delta),
            .dim = dim,
            .unit = try allocator.dupe(u8, result_unit),
            .owns_unit = true,
            .mode = mode,
            .is_delta = is_delta,
            .value_space = .display,
        };
    }

    return .{
        .value = canonical_value,
        .dim = dim,
        .unit = try allocator.dupe(u8, result_unit),
        .owns_unit = true,
        .mode = mode,
        .is_delta = is_delta,
        .value_space = .canonical,
    };
}
