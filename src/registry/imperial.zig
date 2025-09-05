const dim = @import("../root.zig");

/// Imperial Units
pub const ft = dim.Unit{ .dim = dim.DIM.Length, .scale = 0.3048, .symbol = "ft" };
pub const in = dim.Unit{ .dim = dim.DIM.Length, .scale = 0.0254, .symbol = "in" };
pub const yd = dim.Unit{ .dim = dim.DIM.Length, .scale = 0.9144, .symbol = "yd" };
pub const mi = dim.Unit{ .dim = dim.DIM.Length, .scale = 1609.34, .symbol = "mi" };

pub const lb = dim.Unit{ .dim = dim.DIM.Mass, .scale = 0.453592, .symbol = "lb" };
pub const oz = dim.Unit{ .dim = dim.DIM.Mass, .scale = 0.0283495, .symbol = "oz" };

pub const s = dim.Unit{ .dim = dim.DIM.Time, .scale = 1.0, .symbol = "s" };
pub const min = dim.Unit{ .dim = dim.DIM.Time, .scale = 60.0, .symbol = "min" };
pub const h = dim.Unit{ .dim = dim.DIM.Time, .scale = 3600.0, .symbol = "h" };

pub const psi = dim.Unit{ .dim = dim.DIM.Pressure, .scale = 6894.757, .symbol = "psi" };

pub const Registry = [_]dim.Unit{
    ft, in,  yd, mi,
    lb, oz,  s,  min,
    h,  psi,
};

pub const Units = struct {
    pub fn ft(v: f64) dim.Quantity(dim.DIM.Length) {
        return @This().ft.from(v);
    }
    pub fn in(v: f64) dim.Quantity(dim.DIM.Length) {
        return @This().in.from(v);
    }
    pub fn yd(v: f64) dim.Quantity(dim.DIM.Length) {
        return @This().yd.from(v);
    }
    pub fn mi(v: f64) dim.Quantity(dim.DIM.Length) {
        return @This().mi.from(v);
    }

    pub fn lb(v: f64) dim.Quantity(dim.DIM.Mass) {
        return @This().lb.from(v);
    }
    pub fn oz(v: f64) dim.Quantity(dim.DIM.Mass) {
        return @This().oz.from(v);
    }

    pub fn s(v: f64) dim.Quantity(dim.DIM.Time) {
        return @This().s.from(v);
    }
    pub fn min(v: f64) dim.Quantity(dim.DIM.Time) {
        return @This().min.from(v);
    }
    pub fn h(v: f64) dim.Quantity(dim.DIM.Time) {
        return @This().h.from(v);
    }

    pub fn psi(v: f64) dim.Quantity(dim.DIM.Pressure) {
        return @This().psi.from(v);
    }
};
