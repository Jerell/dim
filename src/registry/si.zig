const dim = @import("../root.zig");

pub const m = dim.Unit{ .dim = dim.DIM.Length, .scale = 1.0, .symbol = "m" };
pub const km = dim.Unit{ .dim = dim.DIM.Length, .scale = 1000.0, .symbol = "km" };
pub const cm = dim.Unit{ .dim = dim.DIM.Length, .scale = 0.01, .symbol = "cm" };
pub const mm = dim.Unit{ .dim = dim.DIM.Length, .scale = 0.001, .symbol = "mm" };

pub const m2 = dim.Unit{ .dim = dim.DIM.Area, .scale = 1.0, .symbol = "m²" };
pub const m3 = dim.Unit{ .dim = dim.DIM.Volume, .scale = 1.0, .symbol = "m³" };

pub const g = dim.Unit{ .dim = dim.DIM.Mass, .scale = 0.001, .symbol = "g" };
pub const kg = dim.Unit{ .dim = dim.DIM.Mass, .scale = 1.0, .symbol = "kg" };
pub const t = dim.Unit{ .dim = dim.DIM.Mass, .scale = 1000.0, .symbol = "t" };

pub const s = dim.Unit{ .dim = dim.DIM.Time, .scale = 1.0, .symbol = "s" };
pub const min = dim.Unit{ .dim = dim.DIM.Time, .scale = 60.0, .symbol = "min" };
pub const h = dim.Unit{ .dim = dim.DIM.Time, .scale = 3600.0, .symbol = "h" };

pub const A = dim.Unit{ .dim = dim.DIM.Current, .scale = 1.0, .symbol = "A" };

pub const K = dim.Unit{ .dim = dim.DIM.Temperature, .scale = 1.0, .offset = 0.0, .symbol = "K" };
pub const C = dim.Unit{ .dim = dim.DIM.Temperature, .scale = 1.0, .offset = 273.15, .symbol = "°C" };

pub const mol = dim.Unit{ .dim = dim.DIM.Amount, .scale = 1.0, .symbol = "mol" };
pub const cd = dim.Unit{ .dim = dim.DIM.Luminous, .scale = 1.0, .symbol = "cd" };

pub const Pa = dim.Unit{ .dim = dim.DIM.Pressure, .scale = 1.0, .symbol = "Pa" };
pub const bar = dim.Unit{ .dim = dim.DIM.Pressure, .scale = 1e5, .symbol = "bar" };

pub const J = dim.Unit{ .dim = dim.DIM.Energy, .scale = 1.0, .symbol = "J" };
pub const W = dim.Unit{ .dim = dim.DIM.Power, .scale = 1.0, .symbol = "W" };
pub const N = dim.Unit{ .dim = dim.DIM.Force, .scale = 1.0, .symbol = "N" };

pub const mps = dim.Unit{ .dim = dim.DIM.Velocity, .scale = 1.0, .symbol = "m/s" };
pub const mps2 = dim.Unit{ .dim = dim.DIM.Acceleration, .scale = 1.0, .symbol = "m/s²" };

pub const kgps = dim.Unit{ .dim = dim.DIM.MassFlowRate, .scale = 1.0, .symbol = "kg/s" };

pub const Units = [_]dim.Unit{
    m,    km,   cm, mm,
    g,    kg,   t,  s,
    min,  h,    A,  K,
    C,    mol,  cd, Pa,
    bar,  J,    W,  N,
    mps,  mps2, m2, m3,
    kgps,
};

const aliases = [_]dim.Alias{
    .{ .symbol = "Newton", .target = &N },
    .{ .symbol = "sec", .target = &s },
    .{ .symbol = "m/s2", .target = &mps2 },
    .{ .symbol = "C", .target = &C }, // allow "10 C" input
    .{ .symbol = "degC", .target = &C }, // allow "10 degC"
    .{ .symbol = "celsius", .target = &C },
    .{ .symbol = "Celsius", .target = &C },
    .{ .symbol = "kelvin", .target = &K },
    .{ .symbol = "Kelvin", .target = &K },
};

const prefixes = [_]dim.Prefix{
    .{ .symbol = "Y", .factor = 1e24 },
    .{ .symbol = "Z", .factor = 1e21 },
    .{ .symbol = "E", .factor = 1e18 },
    .{ .symbol = "P", .factor = 1e15 },
    .{ .symbol = "T", .factor = 1e12 },
    .{ .symbol = "G", .factor = 1e9 },
    .{ .symbol = "M", .factor = 1e6 },
    .{ .symbol = "k", .factor = 1e3 },
    .{ .symbol = "h", .factor = 1e2 },
    .{ .symbol = "da", .factor = 1e1 },
    .{ .symbol = "d", .factor = 1e-1 },
    .{ .symbol = "c", .factor = 1e-2 },
    .{ .symbol = "m", .factor = 1e-3 },
    .{ .symbol = "µ", .factor = 1e-6 },
    .{ .symbol = "n", .factor = 1e-9 },
    .{ .symbol = "p", .factor = 1e-12 },
    .{ .symbol = "f", .factor = 1e-15 },
    .{ .symbol = "a", .factor = 1e-18 },
    .{ .symbol = "z", .factor = 1e-21 },
    .{ .symbol = "y", .factor = 1e-24 },
};

pub const Registry = dim.UnitRegistry{
    .units = &Units,
    .aliases = &aliases,
    .prefixes = &prefixes,
};
