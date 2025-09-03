const std = @import("std");

const QuantityError = error{
    AbsPlusAbsTemperature,
    DeltaMinusAbsTemperature,
    MulDivTemperatureDelta,
};

pub const Dimension = struct {
    L: i32, // length
    M: i32, // mass
    T: i32, // time
    I: i32, // electric current
    Th: i32, // temperature (theta)
    N: i32, // amount of substance
    J: i32, // luminous intensity

    pub fn init(l: i32, m: i32, t: i32, i: i32, th: i32, n: i32, j: i32) Dimension {
        return .{ .L = l, .M = m, .T = t, .I = i, .Th = th, .N = n, .J = j };
    }

    pub fn add(a: Dimension, b: Dimension) Dimension {
        return .{
            .L = a.L + b.L,
            .M = a.M + b.M,
            .T = a.T + b.T,
            .I = a.I + b.I,
            .Th = a.Th + b.Th,
            .N = a.N + b.N,
            .J = a.J + b.J,
        };
    }

    pub fn sub(a: Dimension, b: Dimension) Dimension {
        return .{
            .L = a.L - b.L,
            .M = a.M - b.M,
            .T = a.T - b.T,
            .I = a.I - b.I,
            .Th = a.Th - b.Th,
            .N = a.N - b.N,
            .J = a.J - b.J,
        };
    }

    pub fn eql(a: Dimension, b: Dimension) bool {
        return a.L == b.L and a.M == b.M and a.T == b.T and
            a.I == b.I and a.Th == b.Th and a.N == b.N and a.J == b.J;
    }
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

        // pub fn format(
        //     self: Quantity(Dim),
        //     comptime fmt: []const u8,
        //     options: std.fmt.FormatOptions,
        //     writer: anytype,
        // ) !void {
        //     _ = fmt;
        //     _ = options;
        //     if (self.is_delta) {
        //         try std.fmt.format(writer, "Δ{d}", .{self.value});
        //     } else {
        //         try std.fmt.format(writer, "{d}", .{self.value});
        //     }
        // }

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
    };
}

pub const DIM = struct {
    // Base dimensions
    pub const Dimensionless = Dimension.init(0, 0, 0, 0, 0, 0, 0);
    pub const Length = Dimension.init(1, 0, 0, 0, 0, 0, 0);
    pub const Mass = Dimension.init(0, 1, 0, 0, 0, 0, 0);
    pub const Time = Dimension.init(0, 0, 1, 0, 0, 0, 0);
    pub const Current = Dimension.init(0, 0, 0, 1, 0, 0, 0);
    pub const Temperature = Dimension.init(0, 0, 0, 0, 1, 0, 0);
    pub const Amount = Dimension.init(0, 0, 0, 0, 0, 1, 0);
    pub const Luminous = Dimension.init(0, 0, 0, 0, 0, 0, 1);

    // Common derived
    pub const Area = Dimension.init(2, 0, 0, 0, 0, 0, 0); // L^2
    pub const Volume = Dimension.init(3, 0, 0, 0, 0, 0, 0); // L^3
    pub const Velocity = Dimension.init(1, 0, -1, 0, 0, 0, 0); // L T^-1
    pub const Acceleration = Dimension.init(1, 0, -2, 0, 0, 0, 0); // L T^-2
    pub const Force = Dimension.init(1, 1, -2, 0, 0, 0, 0); // M L T^-2
    pub const Pressure = Dimension.init(-1, 1, -2, 0, 0, 0, 0); // M L^-1 T^-2
    pub const Energy = Dimension.init(2, 1, -2, 0, 0, 0, 0); // M L^2 T^-2
    pub const Power = Dimension.init(2, 1, -3, 0, 0, 0, 0); // M L^2 T^-3
    pub const Charge = Dimension.init(0, 0, 1, 1, 0, 0, 0); // T I
    pub const Voltage = Dimension.init(2, 1, -3, -1, 0, 0, 0); // M L^2 T^-3 I^-1
    pub const Resistance = Dimension.init(2, 1, -3, -2, 0, 0, 0); // M L^2 T^-3 I^-2
};

test "basic dimensional arithmetic" {
    const LengthQ = Quantity(DIM.Length);
    const TimeQ = Quantity(DIM.Time);
    const SpeedQ = Quantity(DIM.Velocity);

    const d = LengthQ.init(100.0); // 100 m
    const t = TimeQ.init(10.0); // 10 s
    const v = d.div(t);

    try std.testing.expectApproxEqAbs(10.0, v.value, 1e-9);
    comptime {
        // Ensure type is correct at compile time
        const ResultQ = @TypeOf(v);
        _ = @as(SpeedQ, ResultQ{ .value = 0.0, .is_delta = false });
    }
}

test "force = mass * acceleration" {
    const MassQ = Quantity(DIM.Mass);
    const AccelQ = Quantity(DIM.Acceleration);
    const ForceQ = Quantity(DIM.Force);

    const m = MassQ.init(2.0); // 2 kg
    const a = AccelQ.init(9.81); // 9.81 m/s^2
    const f = m.mul(a);

    comptime {
        const ResultQ = @TypeOf(f);
        // If ResultQ is not ForceQ, the following cast will fail at comptime:
        _ = @as(ForceQ, ResultQ{ .value = 0.0, .is_delta = false });
    }

    try std.testing.expectApproxEqAbs(19.62, f.value, 1e-9);
}

test "temperature: abs + delta -> abs" {
    const TempQ = Quantity(DIM.Temperature);

    // 10 °C absolute = 283.15 K
    const t_abs = TempQ.init(10.0 + 273.15);

    // 20 °F delta => 20 * 5/9 K = 11.111... K
    const dF_in_K = 20.0 * 5.0 / 9.0;
    const t_delta = TempQ.init(dF_in_K);

    const sum = t_abs.add(t_delta); // abs + delta -> abs
    try std.testing.expect(!sum.is_delta);
    try std.testing.expectApproxEqAbs(283.15 + dF_in_K, sum.value, 1e-9);
}

test "temperature: delta + abs -> abs" {
    const TempQ = Quantity(DIM.Temperature);

    // 300 K absolute
    const t_abs = TempQ.init(300.0);

    // 10 °C delta = 10 K
    const t_delta = TempQ.init(10.0);

    const sum = t_delta.add(t_abs); // delta + abs -> abs
    try std.testing.expect(!sum.is_delta);
    try std.testing.expectApproxEqAbs(310.0, sum.value, 1e-9);
}

test "temperature: delta + delta -> delta" {
    const TempQ = Quantity(DIM.Temperature);

    // 10 °C delta = 10 K
    const d1 = TempQ{ .value = 10.0, .is_delta = true };
    // 18 °F delta = 10 K
    const d2 = TempQ{ .value = 18.0 * 5.0 / 9.0, .is_delta = true };

    const dsum = d1.add(d2); // delta + delta -> delta
    try std.testing.expect(dsum.is_delta);
    try std.testing.expectApproxEqAbs(20.0, dsum.value, 1e-9);
}

test "temperature: abs - abs -> delta" {
    const TempQ = Quantity(DIM.Temperature);

    // 310 K absolute
    const a = TempQ.init(310.0);
    // 20 °C absolute = 293.15 K
    const b = TempQ.init(20.0 + 273.15);

    const diff = a.sub(b); // abs - abs -> delta
    try std.testing.expect(diff.is_delta);
    try std.testing.expectApproxEqAbs(16.85, diff.value, 1e-9);
}

test "temperature: abs - delta -> abs" {
    const TempQ = Quantity(DIM.Temperature);

    // 300 K absolute
    const a = TempQ.init(300.0);
    // 20 °C delta = 20 K
    const d = TempQ{ .value = 20.0, .is_delta = true };

    const res = a.sub(d); // abs - delta -> abs
    try std.testing.expect(!res.is_delta);
    try std.testing.expectApproxEqAbs(280.0, res.value, 1e-9);
}
