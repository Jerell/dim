const std = @import("std");

pub const Io = struct {
    // stdout
    out_buf: [4096]u8 = undefined,
    out_fw: std.fs.File.Writer,
    out: *std.Io.Writer,

    // stderr
    err_buf: [2048]u8 = undefined,
    err_fw: std.fs.File.Writer,
    err: *std.Io.Writer,

    // stdin
    in_buf: [4096]u8 = undefined,
    in_fr: std.fs.File.Reader,
    inp: *std.Io.Reader,

    pub fn init() Io {
        var self: Io = undefined;

        self.out_fw = std.fs.File.stdout().writer(&self.out_buf);
        self.out = &self.out_fw.interface;

        self.err_fw = std.fs.File.stderr().writer(&self.err_buf);
        self.err = &self.err_fw.interface;

        self.in_fr = std.fs.File.stdin().reader(&self.in_buf);
        self.inp = &self.in_fr.interface;

        return self;
    }

    // stdout helpers
    pub fn printf(self: *Io, comptime fmt: []const u8, args: anytype) !void {
        // Callers must pass a tuple: .{...}
        try self.out.print(fmt, args);
    }
    pub fn writeAll(self: *Io, bytes: []const u8) !void {
        try self.out.writeAll(bytes);
    }

    // stderr helpers
    pub fn eprintf(self: *Io, comptime fmt: []const u8, args: anytype) !void {
        try self.err.print(fmt, args);
    }
    pub fn ewriteAll(self: *Io, bytes: []const u8) !void {
        try self.err.writeAll(bytes);
    }

    // stdin helpers
    pub fn readLineAlloc(
        self: *Io,
        allocator: std.mem.Allocator,
        limit: usize,
    ) ![]u8 {
        var aw = std.Io.AllocatingWriter.init(allocator);
        defer aw.deinit();
        const w: *std.Io.Writer = &aw.writer;

        // streamDelimiterLimit writes the bytes before the delimiter into w.
        // Use .limited(limit) to bound the logical line length.
        _ = try self.inp.streamDelimiterLimit(w, '\n', .limited(limit));

        return aw.written(); // owned by allocator
    }

    pub fn flushAll(self: *Io) !void {
        try self.out.flush();
        try self.err.flush();
    }

    pub fn writer(self: *Io) *std.Io.Writer {
        return self.out;
    }
    pub fn errWriter(self: *Io) *std.Io.Writer {
        return self.err;
    }
    pub fn reader(self: *Io) *std.Io.Reader {
        return self.inp;
    }
};
