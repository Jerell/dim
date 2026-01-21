const dim = @import("../root.zig");

/// Million Tonnes Per Annum - standard unit for facility throughput in carbon/CCS industry
/// 1 MTPA = 1,000,000 tonnes/year = 1e9 kg / (365.25 * 24 * 3600 s) ≈ 31.69 kg/s
pub const MTPA = dim.Unit{
    .dim = dim.DIM.MassFlowRate,
    .scale = 1e9 / (365.25 * 24.0 * 3600.0),
    .symbol = "MTPA",
};

pub const Units = [_]dim.Unit{MTPA};

const aliases = [_]dim.Alias{
    .{ .symbol = "mtpa", .target = &MTPA },
};

const prefixes = [_]dim.Prefix{};

pub const Registry = dim.UnitRegistry{
    .units = &Units,
    .aliases = &aliases,
    .prefixes = &prefixes,
};
