const std = @import("std");
const Dimension = @import("dimension.zig").Dimension;
const Rational = @import("rational.zig").Rational;
const UnitRegistry = @import("unit.zig").UnitRegistry;
const Unit = @import("unit.zig").Unit;
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
    return D.L.eqlInt(0) and D.M.eqlInt(0) and D.T.eqlInt(0) and D.I.eqlInt(0) and D.Th.eqlInt(1) and D.N.eqlInt(0) and D.J.eqlInt(0);
}

pub fn Quantity(comptime Dim: Dimension) type {
    return struct {
        pub const dim: Dimension = Dim;
        value: f64,
        is_delta: bool,

        pub fn init(v: f64) Quantity(Dim) {
            return .{ .value = v, .is_delta = false };
        }

        pub fn from(v: f64, comptime u: Unit) Quantity(Dim) {
            if (comptime !Dimension.eql(u.dim, Dim)) @compileError("unit dimension mismatch");
            return .{ .value = u.toCanonical(v), .is_delta = false };
        }

        pub fn fromDynamic(v: f64, u: Unit) error{DimensionMismatch}!Quantity(Dim) {
            if (!Dimension.eql(u.dim, Dim)) return error.DimensionMismatch;
            return .{ .value = u.toCanonical(v), .is_delta = false };
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
        pub fn with(self: Quantity(Dim), reg: UnitRegistry, mode: Format.FormatMode) FormatWrapper {
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

        pub fn asUnit(self: Quantity(Dim), u: Unit, mode: Format.FormatMode) FormatUnitWrapper {
            return .{ .q = self, .u = u, .mode = mode };
        }

        pub const FormatUnitWrapper = struct {
            q: Quantity(Dim),
            u: Unit,
            mode: Format.FormatMode,

            pub fn format(self: @This(), writer: anytype) !void {
                if (!Dimension.eql(self.u.dim, Dim)) return error.DimensionMismatch;
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

        pub fn powInt(self: Quantity(Dim), comptime exponent: i32) Quantity(Dimension.mulByInt(Dim, exponent)) {
            return .{ .value = std.math.pow(f64, self.value, @as(f64, @floatFromInt(exponent))), .is_delta = false };
        }

        pub fn powRational(self: Quantity(Dim), comptime exponent: Rational) Quantity(Dimension.mulByRational(Dim, exponent)) {
            return .{ .value = std.math.pow(f64, self.value, exponent.toF64()), .is_delta = false };
        }

        pub fn pow(self: Quantity(Dim), comptime exponent: anytype) Quantity(blk: {
            const ti = @typeInfo(@TypeOf(exponent));
            switch (ti) {
                .Int, .ComptimeInt => break :blk Dimension.mulByInt(Dim, @as(i32, @intCast(exponent))),
                else => @compileError("Quantity.pow only supports integer exponents; use powRational for rational dimensions"),
            }
        }) {
            const e: i32 = @as(i32, @intCast(exponent));
            return self.powInt(e);
        }
    };
}
