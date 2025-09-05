const std = @import("std");

pub const Dimension = @import("dimension.zig").Dimension;
pub const Quantity = @import("quantity.zig").Quantity;
pub const DIM = @import("dimension.zig").DIM;
pub const Unit = @import("unit.zig").Unit;

const units = struct {
    pub const pressure = @import("units/pressure.zig");
    pub const temperature = @import("units/temperature.zig");
};

pub const Units = struct {
    // Pressure
    pub const Pa = units.pressure.Units.Pa;
    pub const bar = units.pressure.Units.bar;

    // Temperature
    pub const K = units.temperature.Units.K;
    pub const C = units.temperature.Units.C;
    pub const F = units.temperature.Units.F;
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
