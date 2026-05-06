const std = @import("std");
const dim = @import("dim");
const Scanner = dim.Scanner;
const Parser = dim.Parser;

const TestError = error{ParseFailed};

fn readLineAlloc(reader: *std.Io.Reader, allocator: std.mem.Allocator, limit: usize) ![]u8 {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    errdefer list.deinit(allocator);

    var read_count: usize = 0;
    while (read_count < limit) {
        const byte = (reader.takeArray(1) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        })[0];

        if (byte == '\n') break;

        try list.append(allocator, byte);
        read_count += 1;
    }

    if (read_count == limit) return error.StreamTooLong;
    return list.toOwnedSlice(allocator);
}

fn flushAll(out: *std.Io.Writer, err: *std.Io.Writer) !void {
    try out.flush();
    try err.flush();
}

pub fn main(init: std.process.Init) !void {
    const default_io = init.io;
    const allocator = init.arena.allocator();
    var out_buf: [4096]u8 = undefined;
    var out_file_writer = std.Io.File.stdout().writer(default_io, &out_buf);
    const out = &out_file_writer.interface;

    var err_buf: [2048]u8 = undefined;
    var err_file_writer = std.Io.File.stderr().writer(default_io, &err_buf);
    const err = &err_file_writer.interface;

    var in_buf: [4096]u8 = undefined;
    var in_file_reader = std.Io.File.stdin().reader(default_io, &in_buf);
    const in = &in_file_reader.interface;

    defer flushAll(out, err) catch |e| err.print("flush error: {s}\n", .{@errorName(e)}) catch {};

    const args = try init.minimal.args.toSlice(allocator);

    if (args.len == 1) {
        // No args: if stdin is a TTY, start REPL; otherwise, read from stdin once
        if (try std.Io.File.stdin().isTty(default_io)) {
            try runPrompt(allocator, in, out, err);
        } else {
            try runStdin(allocator, in, out, err);
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
        try out.writeAll(
            "Usage:\n" ++ "  dim                 Start REPL (or read from stdin if piped)\n" ++ "  dim \"<expr>\"       Evaluate a single expression\n" ++ "  dim --file <path>   Evaluate each line in file\n" ++ "  dim -               Read expressions from stdin (one per line)\n",
        );
        return;
    }

    if (std.mem.eql(u8, arg1, "-")) {
        try runStdin(allocator, in, out, err);
        return;
    }

    if (std.mem.eql(u8, arg1, "--file") or std.mem.eql(u8, arg1, "-f")) {
        if (args.len != 3) {
            try err.print("Error: --file requires a path.\n", .{});
            try out.writeAll(
                "Usage:\n" ++ "  dim                 Start REPL (or read from stdin if piped)\n" ++ "  dim \"<expr>\"       Evaluate a single expression\n" ++ "  dim --file <path>   Evaluate each line in file\n" ++ "  dim -               Read expressions from stdin (one per line)\n",
            );
            std.process.exit(64);
        }
        try runFile(allocator, default_io, out, err, args[2]);
        return;
    }

    if (args.len == 2) {
        // Treat the sole arg as an expression to evaluate
        try run(allocator, out, err, arg1);
        return;
    }

    // Anything else -> usage error
    try err.print("Invalid arguments. Use --help.\n", .{});
    std.process.exit(64);
}

fn runStdin(allocator: std.mem.Allocator, in: *std.Io.Reader, out: *std.Io.Writer, err: *std.Io.Writer) !void {
    const bytes = try in.allocRemaining(allocator, .unlimited);
    defer allocator.free(bytes);

    var it = std.mem.tokenizeAny(u8, bytes, "\r\n");
    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        try run(allocator, out, err, trimmed);
    }
}

fn evalTestExpr(allocator: std.mem.Allocator, line: []const u8) (TestError || dim.RuntimeError || error{OutOfMemory})!dim.LiteralValue {
    var scanner = try Scanner.init(allocator, null, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, null);
    const maybe_expr = parser.parse();
    if (parser.hadError or maybe_expr == null) return error.ParseFailed;

    return maybe_expr.?.evaluate(allocator);
}

fn parseFails(allocator: std.mem.Allocator, line: []const u8) !bool {
    var scanner = try Scanner.init(allocator, null, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, null);
    const maybe_expr = parser.parse();
    return parser.hadError or maybe_expr == null;
}

fn expectDisplayQuantity(
    allocator: std.mem.Allocator,
    line: []const u8,
    expected_value: f64,
    expected_unit: []const u8,
    expected_is_delta: bool,
) !void {
    const eval_result = try evalTestExpr(allocator, line);
    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(expected_value, dq.value, 1e-9);
            try std.testing.expectEqual(expected_is_delta, dq.is_delta);
            try std.testing.expect(std.mem.eql(u8, dq.unit, expected_unit));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "unicode middle dot as multiplication for numbers" {
    const err_writer: ?*std.Io.Writer = null;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const line = "2·3";

    var scanner = try Scanner.init(allocator, err_writer, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, err_writer);
    const maybe_expr = parser.parse();
    try std.testing.expect(maybe_expr != null);

    const expr = maybe_expr.?;
    const eval_result = try expr.evaluate(allocator);
    switch (eval_result) {
        .number => |n| try std.testing.expectApproxEqAbs(6.0, n, 1e-9),
        else => std.debug.panic("expected numeric result", .{}),
    }
}

test "unicode dot operator as multiplication for numbers" {
    const err_writer: ?*std.Io.Writer = null;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const line = "2⋅3";

    var scanner = try Scanner.init(allocator, err_writer, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, err_writer);
    const maybe_expr = parser.parse();
    try std.testing.expect(maybe_expr != null);

    const expr = maybe_expr.?;
    const eval_result = try expr.evaluate(allocator);
    switch (eval_result) {
        .number => |n| try std.testing.expectApproxEqAbs(6.0, n, 1e-9),
        else => std.debug.panic("expected numeric result", .{}),
    }
}

test "dimensionless quotient does not print pseudo-unit" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const result = try evalTestExpr(allocator, "5 m / 2 m");
    switch (result) {
        .display_quantity => |dq| {
            var aw: std.Io.Writer.Allocating = .init(allocator);
            defer aw.deinit();

            try dq.format(&aw.writer);
            try std.testing.expectEqualStrings("2.5", aw.written());
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "middle dot works inside unit expressions after 'as' (J/kg·K)" {
    const err_writer: ?*std.Io.Writer = null;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Dimension matches on both sides: Energy/(Mass*Temperature)
    const line = "1 J/kg/K as J/(kg·K)";

    var scanner = try Scanner.init(allocator, err_writer, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, err_writer);
    const maybe_expr = parser.parse();
    try std.testing.expect(maybe_expr != null);

    const expr = maybe_expr.?;
    const eval_result = try expr.evaluate(allocator);
    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(1.0, dq.value, 1e-9);
            // 'as' conversion preserves the target unit format
            try std.testing.expect(std.mem.eql(u8, dq.unit, "J/kg*K"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "unit grouping parentheses inside 'as' (J/(kg·K))" {
    const err_writer: ?*std.Io.Writer = null;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const line = "1 J/kg/K as J/(kg·K)";

    var scanner = try Scanner.init(allocator, err_writer, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, err_writer);
    const maybe_expr = parser.parse();
    try std.testing.expect(maybe_expr != null);

    const expr = maybe_expr.?;
    const eval_result = try expr.evaluate(allocator);
    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(1.0, dq.value, 1e-9);
            // 'as' conversion preserves the target unit format
            try std.testing.expect(std.mem.eql(u8, dq.unit, "J/kg*K"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "unit grouping parentheses in quantity literal (1 J/(kg·K))" {
    const err_writer: ?*std.Io.Writer = null;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const line = "1 J/(kg·K)";

    var scanner = try Scanner.init(allocator, err_writer, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, err_writer);
    const maybe_expr = parser.parse();
    try std.testing.expect(maybe_expr != null);

    const expr = maybe_expr.?;
    const eval_result = try expr.evaluate(allocator);
    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(1.0, dq.value, 1e-9);
            // Specific heat capacity unit
            try std.testing.expect(std.mem.eql(u8, dq.unit, "J/(kg·K)"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

fn runFile(allocator: std.mem.Allocator, io: std.Io, out: *std.Io.Writer, err: *std.Io.Writer, path: []const u8) !void {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .unlimited);
    defer allocator.free(bytes);

    var it = std.mem.tokenizeAny(u8, bytes, "\r\n");
    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        try run(allocator, out, err, trimmed);
    }
}

fn runPrompt(allocator: std.mem.Allocator, in: *std.Io.Reader, out: *std.Io.Writer, err: *std.Io.Writer) !void {
    while (true) {
        try out.writeAll("> ");
        try flushAll(out, err);
        const line = readLineAlloc(in, allocator, 4096) catch |read_err| {
            if (read_err == error.EndOfStream) return; // exit on EOF
            return read_err;
        };
        defer allocator.free(line);

        try run(allocator, out, err, line);
        try flushAll(out, err);
    }
}

fn run(allocator: std.mem.Allocator, out: *std.Io.Writer, err: *std.Io.Writer, source: []const u8) !void {
    const trimmed = std.mem.trim(u8, source, " \t\r\n");
    if (trimmed.len == 0) return;
    const err_writer: ?*std.Io.Writer = err;

    // Commands will be handled after scanning using tokens

    // 1. Scan
    var scanner = try Scanner.init(allocator, err_writer, trimmed);
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
                try out.print("{s}: dim {any}, 1 {s} = {d:.6} {s}\n", .{ entry.name, entry.unit.dim, entry.name, entry.unit.scale, unit_str });
            }
        }
        return;
    }
    if (tokens.len >= 2 and tokens[0].type == .Show and tokens[1].type == .Identifier) {
        const name = tokens[1].lexeme;
        if (dim.getConstant(name)) |u| {
            const unit_str = try dim.Format.normalizeUnitString(allocator, u.dim, name, dim.Registries.si);
            defer allocator.free(unit_str);
            try out.print("{s}: dim {any}, 1 {s} = {d:.6} {s}\n", .{ name, u.dim, name, u.scale, unit_str });
        } else {
            try err.print("Unknown constant '{s}'\n", .{name});
        }
        return;
    }
    if (tokens.len >= 2 and tokens[0].type == .Clear and tokens[1].type == .All) {
        dim.clearAllConstants();
        try out.writeAll("ok\n");
        return;
    }
    if (tokens.len >= 2 and tokens[0].type == .Clear and tokens[1].type == .Identifier) {
        dim.clearConstant(tokens[1].lexeme);
        try out.writeAll("ok\n");
        return;
    }

    // No special-case parsing for constant declarations; handled by parser as assignment

    // 2. Parse
    var parser = Parser.init(allocator, tokens, err_writer);
    const maybe_expr = parser.parse();

    if (parser.hadError or maybe_expr == null) {
        return; // errors already reported
    }

    const expr = maybe_expr.?;

    // 3. Evaluate
    const result = expr.evaluate(allocator) catch |eval_err| {
        try err_writer.?.print("Runtime error: {any}\n", .{eval_err});
        return;
    };

    // 4/5. If there is a trailing expression after the first parse (common with assignment + expr),
    // skip printing the first result and only print the trailing result. Otherwise, print the first result.
    var has_trailing = false;
    if (tokens.len > parser.current + 1) {
        const remaining = tokens[parser.current..tokens.len];
        has_trailing = !(remaining.len == 1 and remaining[0].type == .Eof);
        if (has_trailing and expr.* != .assignment) {
            dim.reportTokenError(allocator, tokens[parser.current], "Unexpected token", err_writer);
            return;
        }
        if (has_trailing) {
            var trail_parser = Parser.init(allocator, remaining, err_writer);
            const maybe_expr2 = trail_parser.parse();
            if (maybe_expr2) |expr2| {
                const res2 = expr2.evaluate(allocator) catch |eval_err| {
                    try err_writer.?.print("Runtime error: {any}\n", .{eval_err});
                    return;
                };
                switch (res2) {
                    .number => |n| try out.print("{d}\n", .{n}),
                    .string => |s| try out.print("{s}\n", .{s}),
                    .boolean => |b| try out.print("{}\n", .{b}),
                    .display_quantity => |dq| {
                        try dq.format(out);
                        try out.writeAll("\n");
                    },
                    .nil => try out.writeAll("nil\n"),
                }
                try flushAll(out, err);
                return;
            }
        }
    }

    if (!has_trailing) {
        switch (result) {
            .number => |n| try out.print("{d}\n", .{n}),
            .string => |s| try out.print("{s}\n", .{s}),
            .boolean => |b| try out.print("{}\n", .{b}),
            .display_quantity => |dq| {
                try dq.format(out);
                try out.writeAll("\n");
            },
            .nil => try out.writeAll("nil\n"),
        }
        try flushAll(out, err);
    }
}

test "fractional exponent on squared quantity works (sqrt area -> length)" {
    const err_writer: ?*std.Io.Writer = null;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const line = "(16 m^2)^0.5";

    // Scan and parse
    var scanner = try Scanner.init(allocator, err_writer, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, err_writer);
    const maybe_expr = parser.parse();
    try std.testing.expect(maybe_expr != null);

    const expr = maybe_expr.?;
    const eval_result = try expr.evaluate(allocator);

    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(4.0, dq.value, 1e-9);
            try std.testing.expect(dim.Dimension.eql(dq.dim, dim.Dimensions.Length));
            try std.testing.expect(std.mem.eql(u8, dq.unit, "m"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "fractional exponent on length yields rational dimension output" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const eval_result = try evalTestExpr(allocator, "(9 m)^0.5");
    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(3.0, dq.value, 1e-9);
            try std.testing.expect(dim.Rational.eql(dq.dim.L, dim.Rational.init(1, 2)));
            try std.testing.expect(std.mem.eql(u8, dq.unit, "m^(1/2)"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "fractional exponent preserves signed rational output for compound dimensions" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const eval_result = try evalTestExpr(allocator, "(1 m/s)^0.5");
    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(1.0, dq.value, 1e-9);
            try std.testing.expect(std.mem.eql(u8, dq.unit, "m^(1/2)*s^(-1/2)"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "fractional exponent with numerator greater than one formats canonically" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const eval_result = try evalTestExpr(allocator, "(1 m)^1.5");
    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(1.0, dq.value, 1e-9);
            try std.testing.expect(std.mem.eql(u8, dq.unit, "m^(3/2)"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "fractional unit literal normalizes to signed exponents" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const eval_result = try evalTestExpr(allocator, "1 Pa^0.5");
    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(1.0, dq.value, 1e-9);
            try std.testing.expect(std.mem.eql(u8, dq.unit, "kg^(1/2)*m^(-1/2)*s^(-1)"));
            try std.testing.expect(dim.Rational.eql(dq.dim.M, dim.Rational.init(1, 2)));
            try std.testing.expect(dim.Rational.eql(dq.dim.L, dim.Rational.init(-1, 2)));
            try std.testing.expect(dq.dim.T.eqlInt(-1));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "rational exponents round-trip through as conversions" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const sqrt_meter = try evalTestExpr(allocator, "1 m^(1/2) as m^(1/2)");
    switch (sqrt_meter) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(1.0, dq.value, 1e-9);
            try std.testing.expect(std.mem.eql(u8, dq.unit, "m^(1/2)"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }

    const inv_sqrt_second = try evalTestExpr(allocator, "1 s^(-1/2) as s^(-1/2)");
    switch (inv_sqrt_second) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(1.0, dq.value, 1e-9);
            try std.testing.expect(std.mem.eql(u8, dq.unit, "s^(-1/2)"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "non-literal dimensional exponent expressions are rejected" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try std.testing.expectError(dim.RuntimeError.NonRationalDimensionalExponent, evalTestExpr(allocator, "(1 m)^((1/2)+0)"));
}

test "affine units reject fractional exponents" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try std.testing.expectError(dim.RuntimeError.AffineUnitExponentiation, evalTestExpr(allocator, "1 C^0.5"));
    try std.testing.expectError(dim.RuntimeError.AffineUnitExponentiation, evalTestExpr(allocator, "1 C^(1/2)"));
}

test "unit-expression grammar rejects non-rational exponents" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try std.testing.expect(try parseFails(allocator, "1 m as m^pi"));
    try std.testing.expect(try parseFails(allocator, "1 m as m^(sqrt(2))"));
}

test "unit conversion C to F" {
    const err_writer: ?*std.Io.Writer = null;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const line = "100 C as F";

    // Scan and parse
    var scanner = try Scanner.init(allocator, err_writer, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, err_writer);
    const maybe_expr = parser.parse();
    try std.testing.expect(maybe_expr != null);

    const expr = maybe_expr.?;
    const eval_result = try expr.evaluate(allocator);

    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(212.0, dq.value, 1e-9);
            try std.testing.expect(dim.Dimension.eql(dq.dim, dim.Dimensions.Temperature));
            try std.testing.expect(std.mem.eql(u8, dq.unit, "F"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "unit conversion K to C" {
    const err_writer: ?*std.Io.Writer = null;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const line = "100 K as C";

    // Scan and parse
    var scanner = try Scanner.init(allocator, err_writer, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, err_writer);
    const maybe_expr = parser.parse();
    try std.testing.expect(maybe_expr != null);

    const expr = maybe_expr.?;
    const eval_result = try expr.evaluate(allocator);

    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(-173.15, dq.value, 1e-9);
            try std.testing.expect(dim.Dimension.eql(dq.dim, dim.Dimensions.Temperature));
            try std.testing.expect(std.mem.eql(u8, dq.unit, "C"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "unit conversion 10 C to C" {
    const err_writer: ?*std.Io.Writer = null;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const line = "10 C as C";

    // Scan and parse
    var scanner = try Scanner.init(allocator, err_writer, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, err_writer);
    const maybe_expr = parser.parse();
    try std.testing.expect(maybe_expr != null);

    const expr = maybe_expr.?;
    const eval_result = try expr.evaluate(allocator);

    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(10.0, dq.value, 1e-9);
            try std.testing.expect(dim.Dimension.eql(dq.dim, dim.Dimensions.Temperature));
            try std.testing.expect(std.mem.eql(u8, dq.unit, "C"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "unit conversion -20 C to C" {
    const err_writer: ?*std.Io.Writer = null;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const line = "-20 C as C";

    // Scan and parse
    var scanner = try Scanner.init(allocator, err_writer, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, err_writer);
    const maybe_expr = parser.parse();
    try std.testing.expect(maybe_expr != null);

    const expr = maybe_expr.?;
    const eval_result = try expr.evaluate(allocator);

    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(-20.0, dq.value, 1e-9);
            try std.testing.expect(dim.Dimension.eql(dq.dim, dim.Dimensions.Temperature));
            try std.testing.expect(std.mem.eql(u8, dq.unit, "C"));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}

test "pressure unit conversions preserve explicit pressure symbols" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try expectDisplayQuantity(allocator, "1 atm as Pa", 101325.0, "Pa", false);
    try expectDisplayQuantity(allocator, "1 atm as bar", 1.01325, "bar", false);
    try expectDisplayQuantity(allocator, "1 atm as atm", 1.0, "atm", false);
    try expectDisplayQuantity(allocator, "1 bara as bar", 1.0, "bar", false);
    try expectDisplayQuantity(allocator, "1 bar as bara", 1.0, "bara", false);
    try expectDisplayQuantity(allocator, "0 barg as bara", 1.01325, "bara", false);
    try expectDisplayQuantity(allocator, "0 barg as Pa", 101325.0, "Pa", false);
    try expectDisplayQuantity(allocator, "1 barg as barg", 1.0, "barg", false);
}

test "pressure subtraction yields pressure deltas in bar" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try expectDisplayQuantity(allocator, "5 bara - 2 bara", 3.0, "bar", true);
    try expectDisplayQuantity(allocator, "5 barg - 2 barg", 3.0, "bar", true);
    try expectDisplayQuantity(allocator, "2 barg - 1 bara", 2.01325, "bar", true);
    try expectDisplayQuantity(allocator, "2 bara - 1 barg", -0.01325, "bar", true);
    try expectDisplayQuantity(allocator, "(5 bara - 2 bara) as barg", 3.0, "bar", true);
}

test "mixing superscript and caret notation (kg/m³ + kg/m^3)" {
    const err_writer: ?*std.Io.Writer = null;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const line = "1 kg/m³ + 1 kg/m^3";

    // Scan and parse
    var scanner = try Scanner.init(allocator, err_writer, line);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, err_writer);
    const maybe_expr = parser.parse();
    try std.testing.expect(maybe_expr != null);

    const expr = maybe_expr.?;
    const eval_result = try expr.evaluate(allocator);

    switch (eval_result) {
        .display_quantity => |dq| {
            try std.testing.expectApproxEqAbs(2.0, dq.value, 1e-9);
            // Both should have the same dimension (density: M/L³)
            try std.testing.expect(dq.dim.M.eqlInt(1));
            try std.testing.expect(dq.dim.L.eqlInt(-3));
        },
        else => std.debug.panic("expected display_quantity result", .{}),
    }
}
