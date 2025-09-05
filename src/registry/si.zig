const dim = @import("../root.zig");

/// SI Units
pub const m = dim.Unit{ .dim = dim.DIM.Length, .scale = 1.0, .symbol = "m" };
pub const km = dim.Unit{ .dim = dim.DIM.Length, .scale = 1000.0, .symbol = "km" };
pub const cm = dim.Unit{ .dim = dim.DIM.Length, .scale = 0.01, .symbol = "cm" };
pub const mm = dim.Unit{ .dim = dim.DIM.Length, .scale = 0.001, .symbol = "mm" };

pub const g = dim.Unit{ .dim = dim.DIM.Mass, .scale = 0.001, .symbol = "g" };
pub const kg = dim.Unit{ .dim = dim.DIM.Mass, .scale = 1.0, .symbol = "kg" };

pub const s = dim.Unit{ .dim = dim.DIM.Time, .scale = 1.0, .symbol = "s" };
pub const min = dim.Unit{ .dim = dim.DIM.Time, .scale = 60.0, .symbol = "min" };
pub const h = dim.Unit{ .dim = dim.DIM.Time, .scale = 3600.0, .symbol = "h" };

pub const A = dim.Unit{ .dim = dim.DIM.Current, .scale = 1.0, .symbol = "A" };

pub const K = dim.Unit{ .dim = dim.DIM.Temperature, .scale = 1.0, .offset = 0.0, .symbol = "K" };
pub const C = dim.Unit{ .dim = dim.DIM.Temperature, .scale = 1.0, .offset = 273.15, .symbol = "C" };
pub const F = dim.Unit{ .dim = dim.DIM.Temperature, .scale = 5.0 / 9.0, .offset = 459.67 * 5.0 / 9.0, .symbol = "F" };

pub const mol = dim.Unit{ .dim = dim.DIM.Amount, .scale = 1.0, .symbol = "mol" };

pub const cd = dim.Unit{ .dim = dim.DIM.Luminous, .scale = 1.0, .symbol = "cd" };

pub const Pa = dim.Unit{ .dim = dim.DIM.Pressure, .scale = 1.0, .symbol = "Pa" };
pub const bar = dim.Unit{ .dim = dim.DIM.Pressure, .scale = 1e5, .symbol = "bar" };

pub const J = dim.Unit{ .dim = dim.DIM.Energy, .scale = 1.0, .symbol = "J" };
pub const W = dim.Unit{ .dim = dim.DIM.Power, .scale = 1.0, .symbol = "W" };
pub const N = dim.Unit{ .dim = dim.DIM.Force, .scale = 1.0, .symbol = "N" };

/// Array of all SI units for runtime lookup
pub const Registry = [_]dim.Unit{
    m,   km,  cm, mm,
    g,   kg,  s,  min,
    h,   A,   K,  C,
    F,   mol, cd, Pa,
    bar, J,   W,  N,
};

/// Ergonomic constructors
pub const Units = struct {
    pub fn m(v: f64) dim.Quantity(dim.DIM.Length) {
        return @This().m.from(v);
    }
    pub fn km(v: f64) dim.Quantity(dim.DIM.Length) {
        return @This().km.from(v);
    }
    pub fn cm(v: f64) dim.Quantity(dim.DIM.Length) {
        return @This().cm.from(v);
    }
    pub fn mm(v: f64) dim.Quantity(dim.DIM.Length) {
        return @This().mm.from(v);
    }

    pub fn g(v: f64) dim.Quantity(dim.DIM.Mass) {
        return @This().g.from(v);
    }
    pub fn kg(v: f64) dim.Quantity(dim.DIM.Mass) {
        return @This().kg.from(v);
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

    pub fn A(v: f64) dim.Quantity(dim.DIM.Current) {
        return @This().A.from(v);
    }

    pub fn K(v: f64) dim.Quantity(dim.DIM.Temperature) {
        return @This().K.from(v);
    }
    pub fn C(v: f64) dim.Quantity(dim.DIM.Temperature) {
        return @This().C.from(v);
    }
    pub fn F(v: f64) dim.Quantity(dim.DIM.Temperature) {
        return @This().F.from(v);
    }

    pub fn mol(v: f64) dim.Quantity(dim.DIM.Amount) {
        return @This().mol.from(v);
    }

    pub fn cd(v: f64) dim.Quantity(dim.DIM.Luminous) {
        return @This().cd.from(v);
    }

    pub fn Pa(v: f64) dim.Quantity(dim.DIM.Pressure) {
        return @This().Pa.from(v);
    }
    pub fn bar(v: f64) dim.Quantity(dim.DIM.Pressure) {
        return @This().bar.from(v);
    }

    pub fn J(v: f64) dim.Quantity(dim.DIM.Energy) {
        return @This().J.from(v);
    }
    pub fn W(v: f64) dim.Quantity(dim.DIM.Power) {
        return @This().W.from(v);
    }
    pub fn N(v: f64) dim.Quantity(dim.DIM.Force) {
        return @This().N.from(v);
    }
};
