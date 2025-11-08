const std = @import("std");
const dim = @import("dim");
const Io = @import("./Io.zig").Io;
const Scanner = @import("parser/Scanner.zig").Scanner;
const Parser = @import("parser/Parser.zig").Parser;
const Expressions = @import("parser/Expressions.zig");

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
    const trimmed = std.mem.trim(u8, source, " \t\r\n");
    if (trimmed.len == 0) return;

    // Commands will be handled after scanning using tokens

    // 1. Scan
    var scanner = try Scanner.init(allocator, io, trimmed);
    const tokens = try scanner.scanTokens();

    // Handle commands using tokens (post-tokenization)
    if (tokens.len >= 1 and tokens[0].type == .List) {
        const count = dim.constantsCount();
        var i: usize = 0;
        while (i < count) : (i += 1) {
            if (dim.constantByIndex(i)) |entry| {
                const fallback = entry.name;
                const unit_str = try dim.Format.normalizeUnitString(allocator, entry.unit.dim, fallback, dim.Registries.si);
                defer allocator.free(unit_str);
                try io.printf("{s}: dim {any}, 1 {s} = {d:.6} {s}\n", .{ entry.name, entry.unit.dim, entry.name, entry.unit.scale, unit_str });
            }
        }
        return;
    }
    if (tokens.len >= 2 and tokens[0].type == .Show and tokens[1].type == .Identifier) {
        const name = tokens[1].lexeme;
        if (dim.getConstant(name)) |u| {
            const unit_str = try dim.Format.normalizeUnitString(allocator, u.dim, name, dim.Registries.si);
            defer allocator.free(unit_str);
            try io.printf("{s}: dim {any}, 1 {s} = {d:.6} {s}\n", .{ name, u.dim, name, u.scale, unit_str });
        } else {
            try io.eprintf("Unknown constant '{s}'\n", .{name});
        }
        return;
    }
    if (tokens.len >= 2 and tokens[0].type == .Clear and tokens[1].type == .All) {
        dim.clearAllConstants();
        try io.writeAll("ok\n");
        return;
    }
    if (tokens.len >= 2 and tokens[0].type == .Clear and tokens[1].type == .Identifier) {
        dim.clearConstant(tokens[1].lexeme);
        try io.writeAll("ok\n");
        return;
    }

    // No special-case parsing for constant declarations; handled by parser as assignment

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

    // 4/5. If there is a trailing expression after the first parse (common with assignment + expr),
    // skip printing the first result and only print the trailing result. Otherwise, print the first result.
    var has_trailing = false;
    if (tokens.len > parser.current + 1) {
        const remaining = tokens[parser.current..tokens.len];
        has_trailing = !(remaining.len == 1 and remaining[0].type == .Eof);
        if (has_trailing) {
            var trail_parser = Parser.init(allocator, remaining, io);
            const maybe_expr2 = trail_parser.parse();
            if (maybe_expr2) |expr2| {
                const res2 = expr2.evaluate(allocator) catch |err| {
                    try io.eprintf("Runtime error: {any}\n", .{err});
                    return;
                };
                switch (res2) {
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
                return;
            }
        }
    }

    if (!has_trailing) {
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
}

test "fractional exponent on squared quantity works (sqrt area -> length)" {
    var io = Io.init();
    defer io.flushAll() catch |e| io.eprintf("flush error: {s}\n", .{@errorName(e)}) catch {};

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const line = "(16 m^2)^0.5";

    // Scan and parse
    var scanner = try Scanner.init(allocator, &io, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, &io);
    const maybe_expr = parser.parse();
    try std.testing.expect(maybe_expr != null);

    const expr = maybe_expr.?;
    const eval_result = try expr.evaluate(allocator);

    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(4.0, dq.value, 1e-9);
            try std.testing.expect(dim.Dimension.eql(dq.dim, dim.DIM.Length));
            try std.testing.expect(std.mem.eql(u8, dq.unit, "m"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "unit conversion" {
    var io = Io.init();
    defer io.flushAll() catch |e| io.eprintf("flush error: {s}\n", .{@errorName(e)}) catch {};

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const line = "100 C as F";

    // Scan and parse
    var scanner = try Scanner.init(allocator, &io, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, &io);
    const maybe_expr = parser.parse();
    try std.testing.expect(maybe_expr != null);

    const expr = maybe_expr.?;
    const eval_result = try expr.evaluate(allocator);

    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(212.0, dq.value, 1e-9);
            try std.testing.expect(dim.Dimension.eql(dq.dim, dim.DIM.Temperature));
            try std.testing.expect(std.mem.eql(u8, dq.unit, "F"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}
