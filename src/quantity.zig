const std = @import("std");
const Dimension = @import("Dimension.zig").Dimension;
const UnitRegistry = @import("Unit.zig").UnitRegistry;
const Unit = @import("Unit.zig").Unit;
const Format = @import("format.zig");

const QuantityError = error{
    AbsPlusAbsTemperature,
    DeltaMinusAbsTemperature,
    MulDivTemperatureDelta,
};

fn quantityDim(comptime T: type) Dimension {
    // Require that T is a Quantity(...); we check it has a public const dim.
    if (@hasDecl(T, "dim")) {
        const d = @field(T, "dim");
        if (@TypeOf(d) == Dimension) return d;
    }
    @compileError("Expected a Quantity(...) type as operand");
}

fn isTemperatureDim(comptime D: Dimension) bool {
    return D.L == 0 and D.M == 0 and D.T == 0 and D.I == 0 and D.Th == 1 and D.N == 0 and D.J == 0;
}

fn powDimFloat(comptime D: Dimension, comptime exp: f64) Dimension {
    const eps: f64 = 1e-9;
    const to_i32 = struct {
        fn call(x: f64) i32 {
            const r = @round(x);
            if (@abs(x - r) > eps) @compileError("quantity.pow: fractional exponent produces non-integer dimension exponents");
            return @as(i32, @intFromFloat(r));
        }
    }.call;

    const new_L = to_i32(@as(f64, @floatFromInt(D.L)) * exp);
    const new_M = to_i32(@as(f64, @floatFromInt(D.M)) * exp);
    const new_T = to_i32(@as(f64, @floatFromInt(D.T)) * exp);
    const new_I = to_i32(@as(f64, @floatFromInt(D.I)) * exp);
    const new_Th = to_i32(@as(f64, @floatFromInt(D.Th)) * exp);
    const new_N = to_i32(@as(f64, @floatFromInt(D.N)) * exp);
    const new_J = to_i32(@as(f64, @floatFromInt(D.J)) * exp);

    return Dimension.init(new_L, new_M, new_T, new_I, new_Th, new_N, new_J);
}

pub fn Quantity(comptime Dim: Dimension) type {
    return struct {
        pub const dim: Dimension = Dim;
        value: f64,
        is_delta: bool,

        pub fn init(v: f64) Quantity(Dim) {
            return .{ .value = v, .is_delta = false };
        }

        pub fn format(
            self: Quantity(Dim),
            writer: *std.Io.Writer,
        ) !void {
            if (self.is_delta) {
                try writer.print("Δ{d}", .{self.value});
            } else {
                try writer.print("{d}", .{self.value});
            }
        }

        /// Wrapper type for custom formatting
        pub fn With(self: Quantity(Dim), reg: UnitRegistry, mode: Format.FormatMode) FormatWrapper {
            return .{ .q = self, .reg = reg, .mode = mode };
        }

        pub const FormatWrapper = struct {
            q: Quantity(Dim),
            reg: UnitRegistry,
            mode: Format.FormatMode,

            pub fn format(self: @This(), writer: anytype) !void {
                try Format.formatQuantity(
                    writer,
                    self.q.value,
                    @TypeOf(self.q).dim,
                    self.q.is_delta,
                    self.reg,
                    self.mode,
                );
            }
        };

        pub fn AsUnit(self: Quantity(Dim), u: Unit, mode: Format.FormatMode) FormatUnitWrapper {
            return .{ .q = self, .u = u, .mode = mode };
        }

        pub const FormatUnitWrapper = struct {
            q: Quantity(Dim),
            u: Unit,
            mode: Format.FormatMode,

            pub fn format(self: @This(), writer: anytype) !void {
                try Format.formatQuantityAsUnit(writer, self.q, self.u, self.mode);
            }
        };

        pub fn add(self: Quantity(Dim), other: Quantity(Dim)) Quantity(Dim) {
            if (comptime isTemperatureDim(Dim)) {
                // Always treat RHS as delta if it's not already
                if (self.is_delta and other.is_delta) {
                    return .{ .value = self.value + other.value, .is_delta = true };
                }
                if (self.is_delta and !other.is_delta) {
                    return .{ .value = self.value + other.value, .is_delta = false };
                }
                // self is abs
                return .{ .value = self.value + other.value, .is_delta = false };
            } else {
                return .{ .value = self.value + other.value, .is_delta = self.is_delta or other.is_delta };
            }
        }

        pub fn sub(self: Quantity(Dim), other: Quantity(Dim)) Quantity(Dim) {
            if (comptime isTemperatureDim(Dim)) {
                if (!self.is_delta and !other.is_delta) {
                    // abs - abs = delta
                    return .{ .value = self.value - other.value, .is_delta = true };
                }
                if (!self.is_delta and other.is_delta) {
                    return .{ .value = self.value - other.value, .is_delta = false };
                }
                if (self.is_delta and other.is_delta) {
                    return .{ .value = self.value - other.value, .is_delta = true };
                }
                // delta - abs → treat RHS as delta
                return .{ .value = self.value - other.value, .is_delta = true };
            } else {
                return .{ .value = self.value - other.value, .is_delta = self.is_delta or other.is_delta };
            }
        }

        pub fn mul(self: Quantity(Dim), other: anytype) Quantity(Dimension.add(Dim, quantityDim(@TypeOf(other)))) {
            const Other = @TypeOf(other);
            const OtherDim = comptime quantityDim(Other);
            // Conservative rule: forbid multiplying if either operand is a temperature delta.
            if ((comptime isTemperatureDim(Dim) and self.is_delta) or
                (comptime isTemperatureDim(OtherDim) and other.is_delta))
            {
                @compileError("Multiplying temperature deltas is not supported.");
            }
            return .{ .value = self.value * other.value, .is_delta = false };
        }

        pub fn div(self: Quantity(Dim), other: anytype) Quantity(Dimension.sub(Dim, quantityDim(@TypeOf(other)))) {
            const Other = @TypeOf(other);
            const OtherDim = comptime quantityDim(Other);
            if ((comptime isTemperatureDim(Dim) and self.is_delta) or
                (comptime isTemperatureDim(OtherDim) and other.is_delta))
            {
                @compileError("Dividing temperature deltas is not supported.");
            }
            return .{ .value = self.value / other.value, .is_delta = false };
        }

        pub fn scale(self: Quantity(Dim), k: f64) Quantity(Dim) {
            return .{ .value = self.value * k };
        }

        pub fn unscale(self: Quantity(Dim), k: f64) Quantity(Dim) {
            return .{ .value = self.value / k };
        }

        /// Raise this quantity to a compile-time exponent. Supports integer and
        /// floating exponents. For floating exponents, the resulting dimension
        /// exponents must be integers (e.g., (L^2)^0.5 -> L).
        pub fn pow(self: Quantity(Dim), comptime exponent: anytype) Quantity(blk: {
            const TI = @typeInfo(@TypeOf(exponent));
            switch (TI) {
                .Int, .ComptimeInt => {
                    const e: i32 = @as(i32, @intCast(exponent));
                    break :blk Dimension.pow(Dim, e);
                },
                .Float, .ComptimeFloat => {
                    const e: f64 = @as(f64, exponent);
                    break :blk powDimFloat(Dim, e);
                },
                else => @compileError("Quantity.pow: exponent must be int or float and known at comptime"),
            }
        }) {
            const TI = @typeInfo(@TypeOf(exponent));
            switch (TI) {
                .Int, .ComptimeInt => {
                    const e: i32 = @as(i32, @intCast(exponent));
                    return .{ .value = std.math.pow(f64, self.value, @as(f64, @floatFromInt(e))), .is_delta = false };
                },
                .Float, .ComptimeFloat => {
                    const e: f64 = @as(f64, exponent);
                    return .{ .value = std.math.pow(f64, self.value, e), .is_delta = false };
                },
                else => unreachable,
            }
        }
    };
}
