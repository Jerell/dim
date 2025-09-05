const std = @import("std");

pub const Dimension = @import("dimension.zig").Dimension;
pub const Quantity = @import("quantity.zig").Quantity;
pub const DIM = @import("dimension.zig").DIM;
pub const Unit = @import("unit.zig").Unit;
pub const Alias = @import("unit.zig").Alias;
pub const Prefix = @import("unit.zig").Prefix;
pub const UnitRegistry = @import("unit.zig").UnitRegistry;

const _si = @import("registry/si.zig");
const _imperial = @import("registry/imperial.zig");
const _cgs = @import("registry/cgs.zig");

/// Search across all built-in registries
pub fn findUnitAll(symbol: []const u8) ?Unit {
    if (_si.Registry.find(symbol)) |u| return u;
    if (_imperial.Registry.find(symbol)) |u| return u;
    if (_cgs.Registry.find(symbol)) |u| return u;
    return null;
}

/// Search across built-in registries + optional user-supplied registries
pub fn findUnitAllDynamic(symbol: []const u8, extra: ?[]const UnitRegistry) ?Unit {
    // Search built-in registries first
    if (findUnitAll(symbol)) |u| return u;

    // Then search user-supplied registries if provided
    if (extra) |regs| {
        for (regs) |reg| {
            if (reg.find(symbol)) |u| return u;
        }
    }

    return null;
}

/// Re-export ergonomic constructors
pub const Units = struct {
    pub const si = _si.Units;
    pub const imperial = _imperial.Units;
    pub const cgs = _cgs.Units;
};

/// Re-export full registries
pub const Registries = struct {
    pub const si = _si.Registry;
    pub const imperial = _imperial.Registry;
    pub const cgs = _cgs.Registry;
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
        _ = @as(ForceQ, ResultQ{ .value = 0.0, .is_delta = false });
    }

    try std.testing.expectApproxEqAbs(19.62, f.value, 1e-9);
}

test "temperature: abs + delta -> abs" {
    const TempQ = Quantity(DIM.Temperature);

    const t_abs = TempQ.init(10.0 + 273.15); // 10 °C absolute
    const dF_in_K = 20.0 * 5.0 / 9.0; // 20 °F delta
    const t_delta = TempQ.init(dF_in_K);

    const sum = t_abs.add(t_delta);
    try std.testing.expect(!sum.is_delta);
    try std.testing.expectApproxEqAbs(283.15 + dF_in_K, sum.value, 1e-9);
}

test "temperature: delta + abs -> abs" {
    const TempQ = Quantity(DIM.Temperature);

    const t_abs = TempQ.init(300.0);
    const t_delta = TempQ.init(10.0); // 10 °C delta = 10 K

    const sum = t_delta.add(t_abs);
    try std.testing.expect(!sum.is_delta);
    try std.testing.expectApproxEqAbs(310.0, sum.value, 1e-9);
}

test "temperature: delta + delta -> delta" {
    const TempQ = Quantity(DIM.Temperature);

    const d1 = TempQ{ .value = 10.0, .is_delta = true };
    const d2 = TempQ{ .value = 18.0 * 5.0 / 9.0, .is_delta = true };

    const dsum = d1.add(d2);
    try std.testing.expect(dsum.is_delta);
    try std.testing.expectApproxEqAbs(20.0, dsum.value, 1e-9);
}

test "temperature: abs - abs -> delta" {
    const TempQ = Quantity(DIM.Temperature);

    const a = TempQ.init(310.0);
    const b = TempQ.init(20.0 + 273.15);

    const diff = a.sub(b);
    try std.testing.expect(diff.is_delta);
    try std.testing.expectApproxEqAbs(16.85, diff.value, 1e-9);
}

test "temperature: abs - delta -> abs" {
    const TempQ = Quantity(DIM.Temperature);

    const a = TempQ.init(300.0);
    const d = TempQ{ .value = 20.0, .is_delta = true };

    const res = a.sub(d);
    try std.testing.expect(!res.is_delta);
    try std.testing.expectApproxEqAbs(280.0, res.value, 1e-9);
}
