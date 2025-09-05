const dim = @import("../root.zig");

pub const ft = dim.Unit{ .dim = dim.DIM.Length, .scale = 0.3048, .symbol = "ft" };
pub const in = dim.Unit{ .dim = dim.DIM.Length, .scale = 0.0254, .symbol = "in" };
pub const yd = dim.Unit{ .dim = dim.DIM.Length, .scale = 0.9144, .symbol = "yd" };
pub const mi = dim.Unit{ .dim = dim.DIM.Length, .scale = 1609.34, .symbol = "mi" };

pub const lb = dim.Unit{ .dim = dim.DIM.Mass, .scale = 0.453592, .symbol = "lb" };
pub const oz = dim.Unit{ .dim = dim.DIM.Mass, .scale = 0.0283495, .symbol = "oz" };

pub const F = dim.Unit{ .dim = dim.DIM.Temperature, .scale = 5.0 / 9.0, .offset = 459.67 * 5.0 / 9.0, .symbol = "°F" };

pub const s = dim.Unit{ .dim = dim.DIM.Time, .scale = 1.0, .symbol = "s" };
pub const min = dim.Unit{ .dim = dim.DIM.Time, .scale = 60.0, .symbol = "min" };
pub const h = dim.Unit{ .dim = dim.DIM.Time, .scale = 3600.0, .symbol = "h" };

pub const psi = dim.Unit{ .dim = dim.DIM.Pressure, .scale = 6894.757, .symbol = "psi" };

pub const Units = [_]dim.Unit{ ft, in, yd, mi, lb, oz, F, s, min, h, psi };
const aliases = [_]dim.Alias{
    .{ .symbol = "F", .target = &F },
    .{ .symbol = "degF", .target = &F },
    .{ .symbol = "Fahrenheit", .target = &F },
    .{ .symbol = "fahrenheit", .target = &F },
};
const prefixes = [_]dim.Prefix{};

pub const Registry = dim.UnitRegistry{
    .units = &Units,
    .aliases = &aliases,
    .prefixes = &prefixes,
};
