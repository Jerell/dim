const std = @import("std");
const dim = @import("dim");

fn evalToOwnedString(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = dim.evaluate(allocator, input, null) orelse return error.ParseError;

    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(std.heap.page_allocator);
    const w = buf.writer(std.heap.page_allocator);

    switch (result) {
        .number => |n| try w.print("{d}", .{n}),
        .string => |s| try w.print("{s}", .{s}),
        .boolean => |b| try w.print("{}", .{b}),
        .display_quantity => |dq| {
            const delta_prefix: []const u8 = if (dq.is_delta) "\xce\x94" else "";
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
    const assignment_src = try std.fmt.allocPrint(allocator, "{s}=( {s} )", .{ name, expr_src });
    defer allocator.free(assignment_src);

    _ = dim.evaluate(allocator, assignment_src, null) orelse return error.ParseError;
}

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

pub export fn dim_free(ptr: [*]u8, len: usize) void {
    std.heap.page_allocator.free(ptr[0..len]);
}

pub export fn dim_alloc(n: usize) ?[*]u8 {
    const buf = std.heap.page_allocator.alloc(u8, n) catch return null;
    return buf.ptr;
}
