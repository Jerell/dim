const dim = @import("../root.zig");

pub const Pa = dim.Unit{ .dim = dim.DIM.Pressure, .scale = 1.0, .symbol = "Pa" };
pub const bar = dim.Unit{ .dim = dim.DIM.Pressure, .scale = 1e5, .symbol = "bar" };

pub const Registry = [_]dim.Unit{
    Pa,
    bar,
    // add more here...
};
