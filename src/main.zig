const std = @import("std");
const dim = @import("dim");
const Io = @import("./Io.zig").Io;
const Scanner = @import("parser/Scanner.zig").Scanner;
const Parser = @import("parser/Parser.zig").Parser;

pub fn main() !void {
    var io = Io.init();
    defer io.flushAll() catch |e| io.eprintf("flush error: {s}\n", .{@errorName(e)}) catch {};

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 2) {
        try io.eprintf("Usage: dim [script]\n", .{});
        std.process.exit(64);
    } else if (args.len == 2) {
        try runFile(&io, allocator, args[1]);
    } else {
        try runPrompt(&io, allocator);
    }
}

fn runFile(io: *Io, allocator: std.mem.Allocator, path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(bytes);

    try run(io, allocator, bytes);
}

fn runPrompt(io: *Io, allocator: std.mem.Allocator) !void {
    while (true) {
        try io.writeAll("> ");
        try io.flushAll();
        const line = io.readLineAlloc(allocator, 4096) catch |err| {
            if (err == error.EndOfStream) return; // exit on EOF
            return err;
        };
        defer allocator.free(line);

        try run(io, allocator, line);
        try io.flushAll();
    }
}

fn run(io: *Io, allocator: std.mem.Allocator, source: []const u8) !void {
    // 1. Scan
    var scanner = try Scanner.init(allocator, io, source);
    const tokens = try scanner.scanTokens();

    // 2. Parse
    var parser = Parser.init(allocator, tokens, io);
    const maybe_expr = parser.parse();

    if (parser.hadError or maybe_expr == null) {
        return; // errors already reported
    }

    const expr = maybe_expr.?;

    // 3. Evaluate
    const result = expr.evaluate(allocator) catch |err| {
        try io.eprintf("Runtime error: {any}\n", .{err});
        return;
    };

    // 4. Print
    switch (result) {
        .number => |n| try io.printf("{d}\n", .{n}),
        .string => |s| try io.printf("{s}\n", .{s}),
        .boolean => |b| try io.printf("{}\n", .{b}),
        .display_quantity => |dq| {
            try dq.format(io.writer());
            try io.writeAll("\n");
        },
        .nil => try io.writeAll("nil\n"),
    }
    try io.flushAll();
}
