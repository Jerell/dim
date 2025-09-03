//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

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

pub fn Quantity(comptime Dim: Dimension) type {
    return struct {
        value: f64,

        pub fn init(v: f64) Quantity(Dim) {
            return .{ .value = v };
        }

        pub fn add(a: Quantity(Dim), b: Quantity(Dim)) Quantity(Dim) {
            return .{ .value = a.value + b.value };
        }

        pub fn sub(a: Quantity(Dim), b: Quantity(Dim)) Quantity(Dim) {
            return .{ .value = a.value - b.value };
        }

        pub fn mul(
            comptime OtherDim: Dimension,
            a: Quantity(Dim),
            b: Quantity(OtherDim),
        ) Quantity(Dimension.add(Dim, OtherDim)) {
            return .{ .value = a.value * b.value };
        }

        pub fn div(
            comptime OtherDim: Dimension,
            a: Quantity(Dim),
            b: Quantity(OtherDim),
        ) Quantity(Dimension.sub(Dim, OtherDim)) {
            return .{ .value = a.value / b.value };
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
    const v = LengthQ.div(DIM.Time, d, t);

    try std.testing.expectApproxEqAbs(10.0, v.value, 1e-9);
    comptime {
        // Ensure type is correct at compile time
        _ = SpeedQ.init(1.0);
        // Uncommenting this should fail to compile:
        // _ = LengthQ.add(d, t);
    }
}

test "force = mass * acceleration" {
    const MassQ = Quantity(DIM.Mass);
    const AccelQ = Quantity(DIM.Acceleration);
    const ForceQ = Quantity(DIM.Force);

    const m = MassQ.init(2.0); // 2 kg
    const a = AccelQ.init(9.81); // 9.81 m/s^2
    const f = MassQ.mul(DIM.Acceleration, m, a);

    comptime {
        _ = ForceQ.init(f.value);
    }

    try std.testing.expectApproxEqAbs(19.62, f.value, 1e-9);
}
