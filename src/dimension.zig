pub const Dimension = struct {
    L: i32, // length
    M: i32, // mass
    T: i32, // time
    I: i32, // electric current
    Th: i32, // temperature (theta)
    N: i32, // amount of substance
    J: i32, // luminous intensity

    pub fn init(l: i32, m: i32, t: i32, i: i32, th: i32, n: i32, j: i32) Dimension {
        return .{ .L = l, .M = m, .T = t, .I = i, .Th = th, .N = n, .J = j };
    }

    pub fn add(a: Dimension, b: Dimension) Dimension {
        return .{
            .L = a.L + b.L,
            .M = a.M + b.M,
            .T = a.T + b.T,
            .I = a.I + b.I,
            .Th = a.Th + b.Th,
            .N = a.N + b.N,
            .J = a.J + b.J,
        };
    }

    pub fn sub(a: Dimension, b: Dimension) Dimension {
        return .{
            .L = a.L - b.L,
            .M = a.M - b.M,
            .T = a.T - b.T,
            .I = a.I - b.I,
            .Th = a.Th - b.Th,
            .N = a.N - b.N,
            .J = a.J - b.J,
        };
    }

    pub fn eql(a: Dimension, b: Dimension) bool {
        return a.L == b.L and a.M == b.M and a.T == b.T and
            a.I == b.I and a.Th == b.Th and a.N == b.N and a.J == b.J;
    }
};

pub const DIM = struct {
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
};
