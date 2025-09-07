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

    if (args.len == 1) {
        // No args: if stdin is a TTY, start REPL; otherwise, read from stdin once
        if (std.posix.isatty(std.posix.STDIN_FILENO)) {
            try runPrompt(&io, allocator);
        } else {
            try runStdin(&io, allocator);
        }
        return;
    }

    // With args: support
    // - dim "<expr>"
    // - dim --file|-f <path>
    // - dim -            (read from stdin)
    // - dim --help|-h
    const arg1 = args[1];
    if (std.mem.eql(u8, arg1, "--help") or std.mem.eql(u8, arg1, "-h")) {
        try io.writeAll(
            "Usage:\n" ++ "  dim                 Start REPL (or read from stdin if piped)\n" ++ "  dim \"<expr>\"       Evaluate a single expression\n" ++ "  dim --file <path>   Evaluate each line in file\n" ++ "  dim -               Read expressions from stdin (one per line)\n",
        );
        return;
    }

    if (std.mem.eql(u8, arg1, "-")) {
        try runStdin(&io, allocator);
        return;
    }

    if (std.mem.eql(u8, arg1, "--file") or std.mem.eql(u8, arg1, "-f")) {
        if (args.len != 3) {
            try io.eprintf("Error: --file requires a path.\n", .{});
            try io.writeAll(
                "Usage:\n" ++ "  dim                 Start REPL (or read from stdin if piped)\n" ++ "  dim \"<expr>\"       Evaluate a single expression\n" ++ "  dim --file <path>   Evaluate each line in file\n" ++ "  dim -               Read expressions from stdin (one per line)\n",
            );
            std.process.exit(64);
        }
        try runFile(&io, allocator, args[2]);
        return;
    }

    if (args.len == 2) {
        // Treat the sole arg as an expression to evaluate
        try run(&io, allocator, arg1);
        return;
    }

    // Anything else -> usage error
    try io.eprintf("Invalid arguments. Use --help.\n", .{});
    std.process.exit(64);
}

fn runStdin(io: *Io, allocator: std.mem.Allocator) !void {
    const stdin_file = std.fs.File.stdin();
    const bytes = try stdin_file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(bytes);

    var it = std.mem.tokenizeAny(u8, bytes, "\r\n");
    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        try run(io, allocator, trimmed);
    }
}

fn runFile(io: *Io, allocator: std.mem.Allocator, path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(bytes);

    var it = std.mem.tokenizeAny(u8, bytes, "\r\n");
    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        try run(io, allocator, trimmed);
    }
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
            if (dim.findUnitAll(dq.unit)) |u| {
                try dim.Format.formatQuantityAsUnit(io.writer(), dq, u, dq.mode);
                try io.writeAll("\n");
            } else {
                // Fallback: use DisplayQuantity.format to respect mode
                try dq.format(io.writer());
                try io.writeAll("\n");
            }
        },
        .nil => try io.writeAll("nil\n"),
    }
    try io.flushAll();
}
