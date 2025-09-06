const std = @import("std");
const Io = @import("../Io.zig").Io;

pub var had_error: bool = false;

pub fn reportError(io: *Io, line: usize, message: []const u8) void {
    report(io, line, "", message);
}

pub fn report(io: *Io, line: usize, where_: []const u8, message: []const u8) void {
    const err_writer = io.errWriter(); // returns *std.Io.Writer
    err_writer.print("[line {d}] Error{s}: {s}\n", .{ line, where_, message }) catch {};
    had_error = true;
}
