const std = @import("std");
const Dimension = @import("Dimension.zig").Dimension;
const UnitRegistry = @import("Unit.zig").UnitRegistry;
const Format = @import("Format.zig");

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
    };
}
