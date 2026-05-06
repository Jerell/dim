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

pub const DisplayQuantity = struct {
    value: f64,
    dim: Dimension,
    unit: []const u8, // preferred display unit symbol (owned string)
    mode: Format.FormatMode = .none,
    is_delta: bool = false,
    value_space: ValueSpace = .canonical,

    pub fn format(self: DisplayQuantity, writer: *std.Io.Writer) !void {
        const display_value = self.valueForCurrentUnit();
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
        return self.value;
    }

    pub fn valueForCurrentUnit(self: DisplayQuantity) f64 {
        if (self.value_space == .display) return self.value;
        if (findBuiltinUnit(self.unit)) |u| {
            return u.fromCanonicalValue(self.value, self.is_delta);
        }
        return self.value;
    }

    pub fn deinit(self: *DisplayQuantity, allocator: std.mem.Allocator) void {
        allocator.free(self.unit);
        self.* = undefined;
    }
};

pub fn scaleDisplay(dq: DisplayQuantity, factor: f64) DisplayQuantity {
    return DisplayQuantity{
        .value = dq.value * factor,
        .dim = dq.dim,
        .unit = dq.unit,
        .mode = dq.mode,
        .is_delta = dq.is_delta,
        .value_space = dq.value_space,
    };
}

pub fn addDisplay(a: DisplayQuantity, b: DisplayQuantity) error{InvalidOperands}!DisplayQuantity {
    if (!Dimension.eql(a.dim, b.dim)) return error.InvalidOperands;
    const canonical_value = a.canonicalValue() + b.canonicalValue();
    const result_is_delta = inferAddDeltaState(a.dim, a.is_delta, b.is_delta);
    return displayResultFromCanonical(canonical_value, a.dim, a.unit, a.mode, result_is_delta);
}

pub fn subDisplay(a: DisplayQuantity, b: DisplayQuantity) error{InvalidOperands}!DisplayQuantity {
    if (!Dimension.eql(a.dim, b.dim)) return error.InvalidOperands;
    const canonical_value = a.canonicalValue() - b.canonicalValue();
    const result_is_delta = inferSubDeltaState(a.dim, a.is_delta, b.is_delta);
    return displayResultFromCanonical(canonical_value, a.dim, a.unit, a.mode, result_is_delta);
}

pub fn mulDisplay(allocator: std.mem.Allocator, a: DisplayQuantity, b: DisplayQuantity) !DisplayQuantity {
    const new_dim = Dimension.add(a.dim, b.dim);

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
        .mode = .none,
        .is_delta = false,
        .value_space = .canonical,
    };
}

pub fn divDisplay(allocator: std.mem.Allocator, a: DisplayQuantity, b: DisplayQuantity) !DisplayQuantity {
    const new_dim = Dimension.sub(a.dim, b.dim);

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
        .mode = .none,
        .is_delta = false,
        .value_space = .canonical,
    };
}

pub fn powDisplayInt(allocator: std.mem.Allocator, a: DisplayQuantity, exp_int: i32) !DisplayQuantity {
    const new_dim = Dimension.mulByInt(a.dim, exp_int);

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
        .mode = .none,
        .is_delta = false,
        .value_space = .canonical,
    };
}

pub fn powDisplayRational(allocator: std.mem.Allocator, a: DisplayQuantity, exp: Rational) !DisplayQuantity {
    const new_dim = Dimension.mulByRational(a.dim, exp);

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
    canonical_value: f64,
    dim: Dimension,
    preferred_unit: []const u8,
    mode: Format.FormatMode,
    is_delta: bool,
) DisplayQuantity {
    const result_unit = if (is_delta and isPressureDim(dim) and isPressureBarFamilySymbol(preferred_unit))
        "bar"
    else
        preferred_unit;

    if (findBuiltinUnit(result_unit)) |u| {
        return .{
            .value = u.fromCanonicalValue(canonical_value, is_delta),
            .dim = dim,
            .unit = result_unit,
            .mode = mode,
            .is_delta = is_delta,
            .value_space = .display,
        };
    }

    return .{
        .value = canonical_value,
        .dim = dim,
        .unit = result_unit,
        .mode = mode,
        .is_delta = is_delta,
        .value_space = .canonical,
    };
}
