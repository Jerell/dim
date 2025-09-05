const dim = @import("../root.zig");
const si = @import("../registry/si.zig");

pub const Units = struct {
    pub fn K(v: f64) dim.Quantity(dim.DIM.Temperature) {
        return si.K.from(v);
    }

    pub fn C(v: f64) dim.Quantity(dim.DIM.Temperature) {
        return si.C.from(v);
    }

    pub fn F(v: f64) dim.Quantity(dim.DIM.Temperature) {
        return .{
            .value = (v - 32.0) * 5.0 / 9.0 + 273.15,
            .is_delta = false,
        };
    }

    pub fn deltaC(v: f64) dim.Quantity(dim.DIM.Temperature) {
        return dim.Quantity(dim.DIM.Temperature){ .value = v, .is_delta = true };
    }

    pub fn deltaF(v: f64) dim.Quantity(dim.DIM.Temperature) {
        return dim.Quantity(dim.DIM.Temperature){ .value = v * 5.0 / 9.0, .is_delta = true };
    }

    pub fn toC(q: dim.Quantity(dim.DIM.Temperature)) f64 {
        return q.value - 273.15;
    }

    pub fn toF(q: dim.Quantity(dim.DIM.Temperature)) f64 {
        return (q.value - 273.15) * 9.0 / 5.0 + 32.0;
    }

    pub fn toDeltaC(q: dim.Quantity(dim.DIM.Temperature)) f64 {
        return q.value; // 1 K = 1 °C delta
    }

    pub fn toDeltaF(q: dim.Quantity(dim.DIM.Temperature)) f64 {
        return q.value * 9.0 / 5.0;
    }
};
