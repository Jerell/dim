const Dimension = @import("dimension.zig").Dimension;
const Quantity = @import("quantity.zig").Quantity;

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

    pub fn from(self: Unit, v: f64) Quantity(self.dim) {
        return Quantity(self.dim){ .value = self.toCanonical(v), .is_delta = false };
    }

    pub fn to(self: Unit, q: anytype) f64 {
        // Ensure dimensions match
        if (!Dimension.eql(self.dim, @TypeOf(q).dim)) {
            @compileError("Unit dimension does not match Quantity dimension");
        }
        return self.fromCanonical(q.value);
    }
};
