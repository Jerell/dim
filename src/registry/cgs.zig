const dim = @import("../root.zig");

/// CGS Units
pub const cm = dim.Unit{ .dim = dim.DIM.Length, .scale = 0.01, .symbol = "cm" };
pub const mm = dim.Unit{ .dim = dim.DIM.Length, .scale = 0.001, .symbol = "mm" };

pub const g = dim.Unit{ .dim = dim.DIM.Mass, .scale = 0.001, .symbol = "g" };

pub const s = dim.Unit{ .dim = dim.DIM.Time, .scale = 1.0, .symbol = "s" };

pub const dyn = dim.Unit{ .dim = dim.DIM.Force, .scale = 1e-5, .symbol = "dyn" }; // 1 dyn = 1e-5 N
pub const erg = dim.Unit{ .dim = dim.DIM.Energy, .scale = 1e-7, .symbol = "erg" }; // 1 erg = 1e-7 J
pub const Ba = dim.Unit{ .dim = dim.DIM.Pressure, .scale = 0.1, .symbol = "Ba" }; // 1 Ba = 0.1 Pa

pub const P = dim.Unit{ .dim = dim.DIM.Viscosity, .scale = 0.1, .symbol = "P" }; // poise
pub const St = dim.Unit{ .dim = dim.DIM.KinematicViscosity, .scale = 1e-4, .symbol = "St" }; // stokes

const units = [_]dim.Unit{
    cm,  mm,
    g,   s,
    dyn, erg,
    Ba,  P,
    St,
};

const aliases = [_]dim.Alias{}; // no aliases for now
const prefixes = [_]dim.Prefix{}; // CGS doesn’t use SI prefixes

pub const Registry = dim.UnitRegistry{
    .units = &units,
    .aliases = &aliases,
    .prefixes = &prefixes,
};
