const std = @import("std");
const Dimension = @import("Dimension.zig").Dimension;
const Format = @import("format.zig");
const SiRegistry = @import("registry/Si.zig").Registry;

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

pub fn scaleDisplay(dq: DisplayQuantity, factor: f64) DisplayQuantity {
    return DisplayQuantity{
        .value = dq.value * factor,
        .dim = dq.dim,
        .unit = dq.unit,
        .mode = dq.mode,
        .is_delta = dq.is_delta,
    };
}

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

pub fn mulDisplay(allocator: std.mem.Allocator, a: DisplayQuantity, b: DisplayQuantity) !DisplayQuantity {
    const new_dim = Dimension.add(a.dim, b.dim);

    const fallback = try std.fmt.allocPrint(allocator, "{s}*{s}", .{ a.unit, b.unit });
    defer allocator.free(fallback);
    const normalized_unit = try Format.normalizeUnitString(
        allocator,
        new_dim,
        fallback,
        SiRegistry,
    );

    return DisplayQuantity{
        .value = a.value * b.value,
        .dim = new_dim,
        .unit = normalized_unit,
        .mode = .none,
        .is_delta = false,
    };
}

pub fn divDisplay(allocator: std.mem.Allocator, a: DisplayQuantity, b: DisplayQuantity) !DisplayQuantity {
    const new_dim = Dimension.sub(a.dim, b.dim);

    const fallback = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ a.unit, b.unit });
    defer allocator.free(fallback);
    const normalized_unit = try Format.normalizeUnitString(
        allocator,
        new_dim,
        fallback,
        SiRegistry,
    );

    return DisplayQuantity{
        .value = a.value / b.value,
        .dim = new_dim,
        .unit = normalized_unit,
        .mode = .none,
        .is_delta = false,
    };
}
