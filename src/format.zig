const std = @import("std");
const Unit = @import("Unit.zig").Unit;
const UnitRegistry = @import("Unit.zig").UnitRegistry;
const Dimension = @import("Dimension.zig").Dimension;
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
        .none => try writer.print("{s}{d:.3} {s}", .{ delta_prefix, val, u.symbol }),
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
    q: anytype, // Quantity(Dim) or AnyQuantity
    display_unit: Unit,
    mode: FormatMode,
) !void {
    // Extract canonical value
    const val = display_unit.fromCanonical(q.value);

    const delta_prefix: []const u8 = if (q.is_delta) "Δ" else "";

    switch (mode) {
        .none => try writer.print("{s}{d:.3} {s}", .{ delta_prefix, val, display_unit.symbol }),
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
