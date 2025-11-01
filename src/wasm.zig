const std = @import("std");
const dim = @import("dim");
const Io = @import("parser/../Io.zig").Io;
const Scanner = @import("parser/Scanner.zig").Scanner;
const Parser = @import("parser/Parser.zig").Parser;
const Exprs = @import("parser/Expressions.zig");

fn evalToOwnedString(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var io = Io.init();

    var scanner = try Scanner.init(allocator, &io, input);
    const tokens = try scanner.scanTokens();

    var parser = Parser.init(allocator, tokens, &io);
    const maybe_expr = parser.parse();
    if (parser.hadError or maybe_expr == null) return error.ParseError;
    const expr = maybe_expr.?;

    const value = expr.evaluate(allocator) catch |err| switch (err) {
        error.InvalidOperands, error.InvalidOperand, error.DivisionByZero, error.UnsupportedOperator, error.OutOfMemory, error.UndefinedVariable => return error.RuntimeError,
    };

    // Render the result to a string using an ArrayList backed by page_allocator so JS can free via dim_free.
    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(std.heap.page_allocator);
    var w = buf.writer(std.heap.page_allocator);

    switch (value) {
        .number => |n| try w.print("{d}", .{n}),
        .string => |s| try w.print("{s}", .{s}),
        .boolean => |b| try w.print("{}", .{b}),
        .display_quantity => |dq| {
            const delta_prefix: []const u8 = if (dq.is_delta) "Δ" else "";
            switch (dq.mode) {
                .none => try w.print("{s}{d} {s}", .{ delta_prefix, dq.value, dq.unit }),
                .auto => try w.print("{s}{d:.3} {s}", .{ delta_prefix, dq.value, dq.unit }),
                .scientific => try w.print("{s}{e:.3} {s}", .{ delta_prefix, dq.value, dq.unit }),
                .engineering => {
                    if (dq.value == 0.0) {
                        try w.print("{s}0.000 {s}", .{ delta_prefix, dq.unit });
                    } else {
                        const exp_f64 = @floor(std.math.log10(@abs(dq.value)));
                        const exp = @as(i32, @intFromFloat(exp_f64));
                        const eng_exp = exp - @mod(exp, 3);
                        const scaled = dq.value / std.math.pow(f64, 10.0, @floatFromInt(eng_exp));
                        try w.print("{s}{d:.3}e{d} {s}", .{ delta_prefix, scaled, eng_exp, dq.unit });
                    }
                },
            }
        },
        .nil => try w.print("nil", .{}),
    }

    return buf.toOwnedSlice(std.heap.page_allocator);
}

fn defineConstantFromExpr(allocator: std.mem.Allocator, name: []const u8, expr_src: []const u8) !void {
    // Build an assignment form: name=(expr)
    const assignment_src = try std.fmt.allocPrint(allocator, "{s}=( {s} )", .{ name, expr_src });
    defer allocator.free(assignment_src);

    var io = Io.init();
    var scanner = try Scanner.init(allocator, &io, assignment_src);
    const tokens = try scanner.scanTokens();
    var parser = Parser.init(allocator, tokens, &io);
    const maybe_expr = parser.parse();
    if (parser.hadError or maybe_expr == null) return error.ParseError;
    const expr = maybe_expr.?;

    // Evaluate; Assignment node will register the constant via dim.defineConstant
    _ = expr.evaluate(allocator) catch |err| switch (err) {
        error.InvalidOperands, error.InvalidOperand, error.DivisionByZero, error.UnsupportedOperator, error.OutOfMemory, error.UndefinedVariable => return error.RuntimeError,
    };
}

// Exported C-ABI helpers for JS FFI
// Returns 0 on success, non-zero on failure. On success, *out_ptr/*out_len point to an owned buffer
// that must be freed by dim_free().
pub export fn dim_eval(input_ptr: [*]const u8, input_len: usize, out_ptr: *[*]u8, out_len: *usize) i32 {
    const input = input_ptr[0..input_len];
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const result = evalToOwnedString(allocator, input) catch return 1;
    out_ptr.* = result.ptr;
    out_len.* = result.len;
    return 0;
}

pub export fn dim_define(name_ptr: [*]const u8, name_len: usize, expr_ptr: [*]const u8, expr_len: usize) i32 {
    const name = name_ptr[0..name_len];
    const expr_src = expr_ptr[0..expr_len];
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    defineConstantFromExpr(allocator, name, expr_src) catch return 1;
    return 0;
}

pub export fn dim_clear(name_ptr: [*]const u8, name_len: usize) void {
    const name = name_ptr[0..name_len];
    dim.clearConstant(name);
}

pub export fn dim_clear_all() void {
    dim.clearAllConstants();
}

// Free memory returned by dim_eval
pub export fn dim_free(ptr: [*]u8, len: usize) void {
    // Use the same allocator family as eval (GPA) to free; we cannot reconstruct it here easily,
    // so fall back to page_allocator which is compatible for owned slices created by FixedBufferAllocator.
    // If this ever mismatches, switch to exporting an explicit allocator arena handle.
    std.heap.page_allocator.free(ptr[0..len]);
}

// General-purpose allocator for JS to get scratch space inside WASM memory
pub export fn dim_alloc(n: usize) ?[*]u8 {
    const buf = std.heap.page_allocator.alloc(u8, n) catch return null;
    return buf.ptr;
}

// Provide an empty entrypoint for WASI builds; loaders should not call it.
pub fn main() void {}
