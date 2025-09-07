const std = @import("std");

pub const Io = struct {
    // stdout
    out_buf: [4096]u8 = undefined,
    out_fw: std.fs.File.Writer,

    // stderr
    err_buf: [2048]u8 = undefined,
    err_fw: std.fs.File.Writer,

    // stdin
    in_buf: [4096]u8 = undefined,
    in_fr: std.fs.File.Reader,

    pub fn init() Io {
        var self: Io = undefined;
        self.out_fw = std.fs.File.stdout().writer(&self.out_buf);
        self.err_fw = std.fs.File.stderr().writer(&self.err_buf);
        self.in_fr = std.fs.File.stdin().reader(&self.in_buf);
        return self;
    }

    // stdout helpers
    pub fn printf(self: *Io, comptime fmt: []const u8, args: anytype) !void {
        // Callers must pass a tuple: .{...}
        try self.writer().print(fmt, args);
    }
    pub fn writeAll(self: *Io, bytes: []const u8) !void {
        try self.writer().writeAll(bytes);
    }

    // stderr helpers
    pub fn eprintf(self: *Io, comptime fmt: []const u8, args: anytype) !void {
        try self.errWriter().print(fmt, args);
    }
    pub fn ewriteAll(self: *Io, bytes: []const u8) !void {
        try self.errWriter().writeAll(bytes);
    }

    // stdin helpers
    pub fn readLineAlloc(
        self: *Io,
        allocator: std.mem.Allocator,
        limit: usize,
    ) ![]u8 {
        // Use the reader's takeDelimiterExclusive method which returns a slice
        // from the buffered data, or build it manually if needed
        var list = std.ArrayListUnmanaged(u8){};

        // Read bytes one by one until newline or limit
        var read_count: usize = 0;
        while (read_count < limit) {
            const byte = self.reader().*.takeByte() catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };

            if (byte == '\n') break;

            try list.append(allocator, byte);
            read_count += 1;
        }

        if (read_count == limit) return error.StreamTooLong;

        return list.toOwnedSlice(allocator);
    }

    pub fn flushAll(self: *Io) !void {
        try self.writer().flush();
        try self.errWriter().flush();
    }

    pub fn writer(self: *Io) *std.Io.Writer {
        return &self.out_fw.interface;
    }
    pub fn errWriter(self: *Io) *std.Io.Writer {
        return &self.err_fw.interface;
    }
    pub fn reader(self: *Io) *std.Io.Reader {
        return &self.in_fr.interface;
    }
};
