const dim = @import("../root.zig");
const Unit = @import("../unit.zig").Unit;
const si = @import("../registry/si.zig");

pub const Units = struct {
    pub fn Pa(v: f64) dim.Quantity(dim.DIM.Pressure) {
        return si.Pa.from(v);
    }

    pub fn bar(v: f64) dim.Quantity(dim.DIM.Pressure) {
        return si.bar.from(v);
    }
};
