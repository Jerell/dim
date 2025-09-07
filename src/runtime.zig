const std = @import("std");
const Dimension = @import("Dimension.zig").Dimension;
const Format = @import("format.zig");

pub const DisplayQuantity = struct {
    value: f64, // canonical
    dim: Dimension,
    unit: []const u8, // preferred display unit symbol (owned string)
    mode: Format.FormatMode = .none,
    is_delta: bool = false,

    pub fn format(self: DisplayQuantity, writer: *std.Io.Writer) !void {
        try writer.print("{d:.3} {s}", .{ self.value, self.unit });
    }

    pub fn deinit(self: *DisplayQuantity, allocator: std.mem.Allocator) void {
        allocator.free(self.unit);
        self.* = undefined;
    }
};

pub fn addDisplay(a: DisplayQuantity, b: DisplayQuantity) error{InvalidOperands}!DisplayQuantity {
    if (!Dimension.eql(a.dim, b.dim)) return error.InvalidOperands;
    return DisplayQuantity{
        .value = a.value + b.value,
        .dim = a.dim,
        .unit = a.unit, // keep left's preferred unit
        .mode = a.mode,
        .is_delta = a.is_delta or b.is_delta,
    };
}

pub fn subDisplay(a: DisplayQuantity, b: DisplayQuantity) error{InvalidOperands}!DisplayQuantity {
    if (!Dimension.eql(a.dim, b.dim)) return error.InvalidOperands;
    return DisplayQuantity{
        .value = a.value - b.value,
        .dim = a.dim,
        .unit = a.unit,
        .mode = a.mode,
        .is_delta = a.is_delta or b.is_delta,
    };
}

pub fn mulDisplay(a: DisplayQuantity, b: DisplayQuantity) DisplayQuantity {
    const new_dim = Dimension.add(a.dim, b.dim);
    return DisplayQuantity{
        .value = a.value * b.value,
        .dim = new_dim,
        .unit = a.unit, // preserve left's unit symbol for display
        .mode = .none,
        .is_delta = false,
    };
}

pub fn divDisplay(a: DisplayQuantity, b: DisplayQuantity) DisplayQuantity {
    const new_dim = Dimension.sub(a.dim, b.dim);
    return DisplayQuantity{
        .value = a.value / b.value,
        .dim = new_dim,
        .unit = a.unit,
        .mode = .none,
        .is_delta = false,
    };
}


