const std = @import("std");
const dim = @import("dim");
const Io = @import("./io.zig").Io;

pub fn main() !void {
    var io = Io.init();
    defer io.flushAll() catch |e| std.debug.print("flush error: {s}\n", .{@errorName(e)});

    const LengthQ = dim.Quantity(dim.DIM.Length);
    const TimeQ = dim.Quantity(dim.DIM.Time);

    const d = LengthQ.init(100.0);
    const t = TimeQ.init(9.58);
    const v = d.div(t);

    try io.printf("Usain Bolt speed: {f} m/s\n", .{v});
    try io.printf("Usain Bolt speed: {f}\n", .{v.With(dim.Registries.si, .engineering)});

    const u = dim.findUnitAllDynamic("erg", null);
    if (u) |val| {
        try io.printf("{s}, dim {any}\n", .{ val.symbol, val.dim });
    } else {
        try io.printf("No unit\n", .{});
    }
}
