const dim = @import("../root.zig");

/// Million Tonnes Per Annum - standard unit for facility throughput in carbon/CCS industry
/// 1 MTPA = 1,000,000 tonnes/year = 1e9 kg / (365.25 * 24 * 3600 s) ≈ 31.69 kg/s
pub const MTPA = dim.Unit{
    .dim = dim.Dimensions.MassFlowRate,
    .scale = 1e9 / (365.25 * 24.0 * 3600.0),
    .symbol = "MTPA",
};

/// The dimensionless unit, written as dim writes a dimensionless result, so a
/// conversion target of `1` ("500 ppm as 1") gives a plain fraction.
pub const one = dim.Unit{ .dim = dim.Dimensions.Dimensionless, .scale = 1.0, .symbol = "1" };

/// Dimensionless fractions as engineers state composition limits, such as
/// water in CO₂ at 500 ppm. Mole or mass basis is the caller's to record.
pub const percent = dim.Unit{ .dim = dim.Dimensions.Dimensionless, .scale = 1e-2, .symbol = "percent" };
pub const ppm = dim.Unit{ .dim = dim.Dimensions.Dimensionless, .scale = 1e-6, .symbol = "ppm" };
pub const ppb = dim.Unit{ .dim = dim.Dimensions.Dimensionless, .scale = 1e-9, .symbol = "ppb" };

pub const Units = [_]dim.Unit{ MTPA, one, percent, ppm, ppb };

const aliases = [_]dim.Alias{
    .{ .symbol = "mtpa", .target = &MTPA },
    .{ .symbol = "%", .target = &percent },
};

const prefixes = [_]dim.Prefix{};

pub const Registry = dim.UnitRegistry{
    .units = &Units,
    .aliases = &aliases,
    .prefixes = &prefixes,
};
