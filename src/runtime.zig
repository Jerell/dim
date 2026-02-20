const std = @import("std");
const Dimension = @import("dimension.zig").Dimension;
const Format = @import("format.zig");
const SiRegistry = @import("registry/si.zig").Registry;

pub const DisplayQuantity = struct {
    value: f64, // canonical
    dim: Dimension,
    unit: []const u8, // preferred display unit symbol (owned string)
    mode: Format.FormatMode = .none,
    is_delta: bool = false,

    pub fn format(self: DisplayQuantity, writer: *std.Io.Writer) !void {
        const delta_prefix: []const u8 = if (self.is_delta) "Δ" else "";
        switch (self.mode) {
            .none => try writer.print("{s}{d} {s}", .{ delta_prefix, self.value, self.unit }),
            .auto => try writer.print("{s}{d:.3} {s}", .{ delta_prefix, self.value, self.unit }),
            .scientific => try writer.print("{s}{e:.3} {s}", .{ delta_prefix, self.value, self.unit }),
            .engineering => {
                if (self.value == 0.0) {
                    try writer.print("{s}0.000 {s}", .{ delta_prefix, self.unit });
                } else {
                    const exp_f64 = @floor(std.math.log10(@abs(self.value)));
                    const exp = @as(i32, @intFromFloat(exp_f64));
                    const eng_exp = exp - @mod(exp, 3);
                    const scaled = self.value / std.math.pow(f64, 10.0, @floatFromInt(eng_exp));
                    try writer.print("{s}{d:.3}e{d} {s}", .{ delta_prefix, scaled, eng_exp, self.unit });
                }
            },
        }
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
    };
}

pub fn addDisplay(a: DisplayQuantity, b: DisplayQuantity) error{InvalidOperands}!DisplayQuantity {
    if (!Dimension.eql(a.dim, b.dim)) return error.InvalidOperands;
    return DisplayQuantity{
        .value = a.value + b.value,
        .dim = a.dim,
        .unit = a.unit, // keep left's preferred unit
        .mode = a.mode,
        .is_delta = a.is_delta or b.is_delta,
    };
}

pub fn subDisplay(a: DisplayQuantity, b: DisplayQuantity) error{InvalidOperands}!DisplayQuantity {
    if (!Dimension.eql(a.dim, b.dim)) return error.InvalidOperands;
    return DisplayQuantity{
        .value = a.value - b.value,
        .dim = a.dim,
        .unit = a.unit,
        .mode = a.mode,
        .is_delta = a.is_delta or b.is_delta,
    };
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
        .value = a.value * b.value,
        .dim = new_dim,
        .unit = normalized_unit,
        .mode = .none,
        .is_delta = false,
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
        .value = a.value / b.value,
        .dim = new_dim,
        .unit = normalized_unit,
        .mode = .none,
        .is_delta = false,
    };
}

pub fn powDisplay(allocator: std.mem.Allocator, a: DisplayQuantity, exp_int: i32) !DisplayQuantity {
    const new_dim = Dimension.pow(a.dim, exp_int);

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
        .value = std.math.pow(f64, a.value, exponent),
        .dim = new_dim,
        .unit = normalized_unit,
        .mode = .none,
        .is_delta = false,
    };
}

pub fn powDisplayFloat(allocator: std.mem.Allocator, a: DisplayQuantity, exp: f64) error{ InvalidOperands, OutOfMemory }!DisplayQuantity {
    // Multiply each base dimension exponent by exp and require an integer result.
    const eps: f64 = 1e-9;
    const roundToI32 = struct {
        fn call(x: f64) error{InvalidOperands}!i32 {
            const r = @round(x);
            if (@abs(x - r) > eps) return error.InvalidOperands;
            return @as(i32, @intFromFloat(r));
        }
    }.call;

    const new_L = try roundToI32(@as(f64, @floatFromInt(a.dim.L)) * exp);
    const new_M = try roundToI32(@as(f64, @floatFromInt(a.dim.M)) * exp);
    const new_T = try roundToI32(@as(f64, @floatFromInt(a.dim.T)) * exp);
    const new_I = try roundToI32(@as(f64, @floatFromInt(a.dim.I)) * exp);
    const new_Th = try roundToI32(@as(f64, @floatFromInt(a.dim.Th)) * exp);
    const new_N = try roundToI32(@as(f64, @floatFromInt(a.dim.N)) * exp);
    const new_J = try roundToI32(@as(f64, @floatFromInt(a.dim.J)) * exp);

    const new_dim = Dimension.init(new_L, new_M, new_T, new_I, new_Th, new_N, new_J);

    const fallback = try std.fmt.allocPrint(allocator, "{s}^{d}", .{ a.unit, exp });
    defer allocator.free(fallback);
    const normalized_unit = try Format.normalizeUnitString(
        allocator,
        new_dim,
        fallback,
        SiRegistry,
    );

    return DisplayQuantity{
        .value = std.math.pow(f64, a.value, exp),
        .dim = new_dim,
        .unit = normalized_unit,
        .mode = .none,
        .is_delta = false,
    };
}
