const Rational = @import("rational.zig").Rational;

pub const Dimension = struct {
    L: Rational, // length
    M: Rational, // mass
    T: Rational, // time
    I: Rational, // electric current
    Th: Rational, // temperature (theta)
    N: Rational, // amount of substance
    J: Rational, // luminous intensity

    pub fn init(l: i32, m: i32, t: i32, i: i32, th: i32, n: i32, j: i32) Dimension {
        return initInts(l, m, t, i, th, n, j);
    }

    pub fn initInts(l: i32, m: i32, t: i32, i: i32, th: i32, n: i32, j: i32) Dimension {
        return .{
            .L = Rational.fromInt(l),
            .M = Rational.fromInt(m),
            .T = Rational.fromInt(t),
            .I = Rational.fromInt(i),
            .Th = Rational.fromInt(th),
            .N = Rational.fromInt(n),
            .J = Rational.fromInt(j),
        };
    }

    pub fn initRationals(l: Rational, m: Rational, t: Rational, i: Rational, th: Rational, n: Rational, j: Rational) Dimension {
        return .{ .L = l, .M = m, .T = t, .I = i, .Th = th, .N = n, .J = j };
    }

    pub fn add(a: Dimension, b: Dimension) Dimension {
        return .{
            .L = Rational.add(a.L, b.L),
            .M = Rational.add(a.M, b.M),
            .T = Rational.add(a.T, b.T),
            .I = Rational.add(a.I, b.I),
            .Th = Rational.add(a.Th, b.Th),
            .N = Rational.add(a.N, b.N),
            .J = Rational.add(a.J, b.J),
        };
    }

    pub fn sub(a: Dimension, b: Dimension) Dimension {
        return .{
            .L = Rational.sub(a.L, b.L),
            .M = Rational.sub(a.M, b.M),
            .T = Rational.sub(a.T, b.T),
            .I = Rational.sub(a.I, b.I),
            .Th = Rational.sub(a.Th, b.Th),
            .N = Rational.sub(a.N, b.N),
            .J = Rational.sub(a.J, b.J),
        };
    }

    pub fn eql(a: Dimension, b: Dimension) bool {
        return Rational.eql(a.L, b.L) and Rational.eql(a.M, b.M) and Rational.eql(a.T, b.T) and
            Rational.eql(a.I, b.I) and Rational.eql(a.Th, b.Th) and Rational.eql(a.N, b.N) and Rational.eql(a.J, b.J);
    }

    pub fn pow(self: Dimension, exponent: i32) Dimension {
        return self.mulByInt(exponent);
    }

    pub fn mulByInt(self: Dimension, exponent: i32) Dimension {
        return .{
            .L = Rational.mul(self.L, Rational.fromInt(exponent)),
            .M = Rational.mul(self.M, Rational.fromInt(exponent)),
            .T = Rational.mul(self.T, Rational.fromInt(exponent)),
            .I = Rational.mul(self.I, Rational.fromInt(exponent)),
            .Th = Rational.mul(self.Th, Rational.fromInt(exponent)),
            .N = Rational.mul(self.N, Rational.fromInt(exponent)),
            .J = Rational.mul(self.J, Rational.fromInt(exponent)),
        };
    }

    pub fn mulByRational(self: Dimension, exponent: Rational) Dimension {
        return .{
            .L = Rational.mul(self.L, exponent),
            .M = Rational.mul(self.M, exponent),
            .T = Rational.mul(self.T, exponent),
            .I = Rational.mul(self.I, exponent),
            .Th = Rational.mul(self.Th, exponent),
            .N = Rational.mul(self.N, exponent),
            .J = Rational.mul(self.J, exponent),
        };
    }

    pub fn hasFractional(self: Dimension) bool {
        return !self.L.isInteger() or !self.M.isInteger() or !self.T.isInteger() or
            !self.I.isInteger() or !self.Th.isInteger() or !self.N.isInteger() or !self.J.isInteger();
    }

    pub fn isDimensionless(self: Dimension) bool {
        return self.L.isZero() and self.M.isZero() and self.T.isZero() and
            self.I.isZero() and self.Th.isZero() and self.N.isZero() and self.J.isZero();
    }
};

pub const Dimensions = struct {
    // Base dimensions
    pub const Dimensionless = Dimension.init(0, 0, 0, 0, 0, 0, 0);
    pub const Length = Dimension.init(1, 0, 0, 0, 0, 0, 0);
    pub const Mass = Dimension.init(0, 1, 0, 0, 0, 0, 0);
    pub const Time = Dimension.init(0, 0, 1, 0, 0, 0, 0);
    pub const Current = Dimension.init(0, 0, 0, 1, 0, 0, 0);
    pub const Temperature = Dimension.init(0, 0, 0, 0, 1, 0, 0);
    pub const Amount = Dimension.init(0, 0, 0, 0, 0, 1, 0);
    pub const Luminous = Dimension.init(0, 0, 0, 0, 0, 0, 1);

    // Common derived
    pub const Area = Dimension.init(2, 0, 0, 0, 0, 0, 0); // L^2
    pub const Volume = Dimension.init(3, 0, 0, 0, 0, 0, 0); // L^3
    pub const Velocity = Dimension.init(1, 0, -1, 0, 0, 0, 0); // L T^-1
    pub const Acceleration = Dimension.init(1, 0, -2, 0, 0, 0, 0); // L T^-2
    pub const Force = Dimension.init(1, 1, -2, 0, 0, 0, 0); // M L T^-2
    pub const Pressure = Dimension.init(-1, 1, -2, 0, 0, 0, 0); // M L^-1 T^-2
    pub const Energy = Dimension.init(2, 1, -2, 0, 0, 0, 0); // M L^2 T^-2
    pub const Power = Dimension.init(2, 1, -3, 0, 0, 0, 0); // M L^2 T^-3
    pub const Charge = Dimension.init(0, 0, 1, 1, 0, 0, 0); // T I
    pub const Voltage = Dimension.init(2, 1, -3, -1, 0, 0, 0); // M L^2 T^-3 I^-1
    pub const Resistance = Dimension.init(2, 1, -3, -2, 0, 0, 0); // M L^2 T^-3 I^-2

    pub const Viscosity = Dimension.init(-1, 1, -1, 0, 0, 0, 0); // M L^-1 T^-1
    pub const KinematicViscosity = Dimension.init(2, 0, -1, 0, 0, 0, 0); // L^2 T^-1
    pub const MassFlowRate = Dimension.init(0, 1, -1, 0, 0, 0, 0); // M T^-1
    pub const SpecificHeatCapacity = Dimension.init(2, 0, -2, 0, -1, 0, 0); // L^2 T^-2 Θ^-1
};
