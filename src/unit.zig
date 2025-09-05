const Dimension = @import("dimension.zig").Dimension;

pub const Unit = struct {
    dim: Dimension,
    scale: f64,
    symbol: []const u8,

    pub fn toCanonical(self: Unit, v: f64) f64 {
        return v * self.scale;
    }

    pub fn fromCanonical(self: Unit, v: f64) f64 {
        return v / self.scale;
    }
};
