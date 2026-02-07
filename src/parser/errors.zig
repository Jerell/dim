const std = @import("std");

pub var had_error: bool = false;

pub fn reportError(err_writer: ?*std.Io.Writer, line: usize, message: []const u8) void {
    report(err_writer, line, "", message);
}

pub fn report(err_writer: ?*std.Io.Writer, line: usize, where_: []const u8, message: []const u8) void {
    if (err_writer) |w| {
        w.print("[line {d}] Error{s}: {s}\n", .{ line, where_, message }) catch {};
    }
    had_error = true;
}
