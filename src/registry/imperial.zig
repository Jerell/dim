const dim = @import("../root.zig");

pub const ft = dim.Unit{ .dim = dim.Dimensions.Length, .scale = 0.3048, .symbol = "ft" };
pub const in = dim.Unit{ .dim = dim.Dimensions.Length, .scale = 0.0254, .symbol = "in" };
pub const yd = dim.Unit{ .dim = dim.Dimensions.Length, .scale = 0.9144, .symbol = "yd" };
pub const mi = dim.Unit{ .dim = dim.Dimensions.Length, .scale = 1609.34, .symbol = "mi" };

pub const lb = dim.Unit{ .dim = dim.Dimensions.Mass, .scale = 0.453592, .symbol = "lb" };
pub const oz = dim.Unit{ .dim = dim.Dimensions.Mass, .scale = 0.0283495, .symbol = "oz" };

pub const F = dim.Unit{ .dim = dim.Dimensions.Temperature, .scale = 5.0 / 9.0, .offset = 459.67, .symbol = "°F" };

pub const s = dim.Unit{ .dim = dim.Dimensions.Time, .scale = 1.0, .symbol = "s" };
pub const min = dim.Unit{ .dim = dim.Dimensions.Time, .scale = 60.0, .symbol = "min" };
pub const h = dim.Unit{ .dim = dim.Dimensions.Time, .scale = 3600.0, .symbol = "h" };

pub const psi = dim.Unit{ .dim = dim.Dimensions.Pressure, .scale = 6894.757, .symbol = "psi" };

/// US liquid gallon: exactly 231 in³, so 3.785411784e-3 m³. The US and
/// imperial gallons differ by about 20%, so a bare `gal` has to commit to one
/// of them. It resolves to the US liquid gallon because that is the gallon in
/// `gal/min` flow rates and in valve flow coefficients. Spell the imperial
/// gallon `galUK`; `galUS` is available when a reader should not have to know
/// this rule.
pub const gal = dim.Unit{ .dim = dim.Dimensions.Volume, .scale = 3.785411784e-3, .symbol = "gal" };
/// Imperial gallon: exactly 4.54609 L.
pub const galUK = dim.Unit{ .dim = dim.Dimensions.Volume, .scale = 4.54609e-3, .symbol = "galUK" };

pub const Units = [_]dim.Unit{ ft, in, yd, mi, lb, oz, F, s, min, h, psi, gal, galUK };
const aliases = [_]dim.Alias{
    .{ .symbol = "F", .target = &F },
    .{ .symbol = "degF", .target = &F },
    .{ .symbol = "Fahrenheit", .target = &F },
    .{ .symbol = "fahrenheit", .target = &F },
    .{ .symbol = "galUS", .target = &gal },
    .{ .symbol = "gallon", .target = &gal },
    .{ .symbol = "galImp", .target = &galUK },
};
const prefixes = [_]dim.Prefix{};

pub const Registry = dim.UnitRegistry{
    .units = &Units,
    .aliases = &aliases,
    .prefixes = &prefixes,
};
