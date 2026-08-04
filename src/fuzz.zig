const std = @import("std");
const dim = @import("dim");

const max_input_len = 4096;

fn encodedSeed(comptime source: []const u8) [source.len + 4]u8 {
    var result: [source.len + 4]u8 = undefined;
    result[0] = @intCast(source.len);
    result[1] = @intCast(source.len >> 8);
    result[2] = @intCast(source.len >> 16);
    result[3] = @intCast(source.len >> 24);
    @memcpy(result[4..], source);
    return result;
}

const seed_scientific = encodedSeed("1.5e3 m");
const seed_signed_scientific = encodedSeed("2E-3 km");
const seed_superscripts = encodedSeed("(2 m)³ + 10 s⁻¹");
const seed_repl = encodedSeed("foo = (24 h)\nshow foo\n1e6 s as foo\nclear foo");
const seed_compound_unit = encodedSeed("1 J/(kg·K)");
const seed_dimension_overflow = encodedSeed("1 m^2147483647*m^2147483647");
const fuzz_corpus = [_][]const u8{
    &seed_scientific,
    &seed_signed_scientific,
    &seed_superscripts,
    &seed_repl,
    &seed_compound_unit,
    &seed_dimension_overflow,
};

fn evaluateAndRelease(context: *dim.DimContext, input: []const u8) void {
    if (dim.evaluateWithContext(context, std.testing.allocator, input, null)) |value| {
        var owned = value;
        dim.deinitLiteralValue(std.testing.allocator, &owned);
    }
}

fn fuzzDimInput(_: void, smith: *std.testing.Smith) !void {
    var input: [max_input_len]u8 = undefined;
    const input_len: usize = @intCast(smith.slice(&input));
    const source = input[0..input_len];

    var context = dim.DimContext.init(std.testing.allocator);
    defer context.deinit();
    evaluateAndRelease(&context, source);

    var repl_context = dim.DimContext.init(std.testing.allocator);
    defer repl_context.deinit();
    var lines = std.mem.splitScalar(u8, source, '\n');
    var line_count: usize = 0;
    while (lines.next()) |line| : (line_count += 1) {
        if (line_count == 64) break;
        evaluateAndRelease(&repl_context, line);
    }

    const unit_len: usize = @min(input_len, max_input_len);

    var expression: [max_input_len + 2]u8 = undefined;
    @memcpy(expression[0..2], "1 ");
    @memcpy(expression[2 .. 2 + unit_len], input[0..unit_len]);

    var unit_context = dim.DimContext.init(std.testing.allocator);
    defer unit_context.deinit();
    evaluateAndRelease(&unit_context, expression[0 .. 2 + unit_len]);
}

test "fuzz dim input" {
    try std.testing.fuzz({}, fuzzDimInput, .{ .corpus = &fuzz_corpus });
}
