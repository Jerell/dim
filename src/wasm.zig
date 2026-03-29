const std = @import("std");
const dim = @import("dim");

pub const DimStatus = enum(i32) {
    ok = 0,
    eval_error = 1,
    invalid_argument = 2,
    wrong_kind = 3,
    out_of_memory = 4,
};

pub const DimValueKind = enum(u32) {
    number = 0,
    boolean = 1,
    string = 2,
    quantity = 3,
    nil = 4,
};

pub const DimFormatMode = enum(u32) {
    none = 0,
    auto = 1,
    scientific = 2,
    engineering = 3,
};

pub const DimSlice = extern struct {
    ptr: usize,
    len: usize,
};

pub const DimEvalResult = extern struct {
    kind: u32,
    bool_value: u32,
    mode: u32,
    is_delta: u32,
    number_value: f64,
    quantity_value: f64,
    dim_L_num: i32,
    dim_L_den: u32,
    dim_M_num: i32,
    dim_M_den: u32,
    dim_T_num: i32,
    dim_T_den: u32,
    dim_I_num: i32,
    dim_I_den: u32,
    dim_Th_num: i32,
    dim_Th_den: u32,
    dim_N_num: i32,
    dim_N_den: u32,
    dim_J_num: i32,
    dim_J_den: u32,
    string_ptr: usize,
    string_len: usize,
    unit_ptr: usize,
    unit_len: usize,
};

pub const DimQuantityResult = extern struct {
    mode: u32,
    is_delta: u32,
    value: f64,
    dim_L_num: i32,
    dim_L_den: u32,
    dim_M_num: i32,
    dim_M_den: u32,
    dim_T_num: i32,
    dim_T_den: u32,
    dim_I_num: i32,
    dim_I_den: u32,
    dim_Th_num: i32,
    dim_Th_den: u32,
    dim_N_num: i32,
    dim_N_den: u32,
    dim_J_num: i32,
    dim_J_den: u32,
    unit_ptr: usize,
    unit_len: usize,
};

fn statusCode(status: DimStatus) i32 {
    return @intFromEnum(status);
}

fn formatModeValue(mode: dim.Format.FormatMode) u32 {
    return @intFromEnum(switch (mode) {
        .none => DimFormatMode.none,
        .auto => DimFormatMode.auto,
        .scientific => DimFormatMode.scientific,
        .engineering => DimFormatMode.engineering,
    });
}

fn ensureContext(ctx: ?*dim.DimContext) ?*dim.DimContext {
    return ctx;
}

fn evaluateOwned(ctx: *dim.DimContext, input: []const u8) !dim.LiteralValue {
    return dim.evaluateWithContext(ctx, std.heap.page_allocator, input, null) orelse error.EvalError;
}

fn literalDimension(value: dim.LiteralValue) ?dim.Dimension {
    return switch (value) {
        .number => dim.Dimensions.Dimensionless,
        .display_quantity => |dq| dq.dim,
        else => null,
    };
}

fn fillDimensionRational(value: dim.Rational, out_num: *i32, out_den: *u32) void {
    out_num.* = value.num;
    out_den.* = value.den;
}

fn fillDimensionsEval(dim_value: dim.Dimension, out: *DimEvalResult) void {
    fillDimensionRational(dim_value.L, &out.dim_L_num, &out.dim_L_den);
    fillDimensionRational(dim_value.M, &out.dim_M_num, &out.dim_M_den);
    fillDimensionRational(dim_value.T, &out.dim_T_num, &out.dim_T_den);
    fillDimensionRational(dim_value.I, &out.dim_I_num, &out.dim_I_den);
    fillDimensionRational(dim_value.Th, &out.dim_Th_num, &out.dim_Th_den);
    fillDimensionRational(dim_value.N, &out.dim_N_num, &out.dim_N_den);
    fillDimensionRational(dim_value.J, &out.dim_J_num, &out.dim_J_den);
}

fn fillDimensionsQuantity(dim_value: dim.Dimension, out: *DimQuantityResult) void {
    fillDimensionRational(dim_value.L, &out.dim_L_num, &out.dim_L_den);
    fillDimensionRational(dim_value.M, &out.dim_M_num, &out.dim_M_den);
    fillDimensionRational(dim_value.T, &out.dim_T_num, &out.dim_T_den);
    fillDimensionRational(dim_value.I, &out.dim_I_num, &out.dim_I_den);
    fillDimensionRational(dim_value.Th, &out.dim_Th_num, &out.dim_Th_den);
    fillDimensionRational(dim_value.N, &out.dim_N_num, &out.dim_N_den);
    fillDimensionRational(dim_value.J, &out.dim_J_num, &out.dim_J_den);
}

fn fillQuantityResult(out: *DimQuantityResult, dq: dim.DisplayQuantity) void {
    out.* = std.mem.zeroes(DimQuantityResult);
    out.mode = formatModeValue(dq.mode);
    out.is_delta = if (dq.is_delta) 1 else 0;
    out.value = dq.value;
    fillDimensionsQuantity(dq.dim, out);
    out.unit_ptr = @intFromPtr(dq.unit.ptr);
    out.unit_len = dq.unit.len;
}

fn fillEvalResult(out: *DimEvalResult, value: dim.LiteralValue) void {
    out.* = std.mem.zeroes(DimEvalResult);
    switch (value) {
        .number => |n| {
            out.kind = @intFromEnum(DimValueKind.number);
            out.number_value = n;
        },
        .boolean => |b| {
            out.kind = @intFromEnum(DimValueKind.boolean);
            out.bool_value = if (b) 1 else 0;
        },
        .string => |s| {
            out.kind = @intFromEnum(DimValueKind.string);
            out.string_ptr = @intFromPtr(s.ptr);
            out.string_len = s.len;
        },
        .display_quantity => |dq| {
            out.kind = @intFromEnum(DimValueKind.quantity);
            out.mode = formatModeValue(dq.mode);
            out.is_delta = if (dq.is_delta) 1 else 0;
            out.quantity_value = dq.value;
            fillDimensionsEval(dq.dim, out);
            out.unit_ptr = @intFromPtr(dq.unit.ptr);
            out.unit_len = dq.unit.len;
        },
        .nil => {
            out.kind = @intFromEnum(DimValueKind.nil);
        },
    }
}

fn buildConvertValueExpression(
    allocator: std.mem.Allocator,
    value: f64,
    from_unit: []const u8,
    to_unit: []const u8,
) ![]u8 {
    return std.fmt.allocPrint(allocator, "{d} {s} as {s}", .{ value, from_unit, to_unit });
}

fn buildUnitExpression(allocator: std.mem.Allocator, unit: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "1 {s}", .{unit});
}

fn zeroF64Slice(ptr: [*]f64, count: usize) void {
    for (ptr[0..count]) |*value| {
        value.* = std.math.nan(f64);
    }
}

fn slicePtr(slice: DimSlice) [*]const u8 {
    return @ptrFromInt(slice.ptr);
}

fn freeQuantityResult(result: *DimQuantityResult) void {
    if (result.unit_ptr != 0 and result.unit_len != 0) {
        dim_free(@ptrFromInt(result.unit_ptr), result.unit_len);
    }
    result.* = std.mem.zeroes(DimQuantityResult);
}

fn freeEvalResult(result: *DimEvalResult) void {
    if (result.string_ptr != 0 and result.string_len != 0) {
        dim_free(@ptrFromInt(result.string_ptr), result.string_len);
    }
    if (result.unit_ptr != 0 and result.unit_len != 0) {
        dim_free(@ptrFromInt(result.unit_ptr), result.unit_len);
    }
    result.* = std.mem.zeroes(DimEvalResult);
}

pub export fn dim_ctx_new() ?*dim.DimContext {
    const ctx = std.heap.page_allocator.create(dim.DimContext) catch return null;
    ctx.* = dim.DimContext.init(std.heap.page_allocator);
    return ctx;
}

pub export fn dim_ctx_free(ctx: ?*dim.DimContext) void {
    const actual = ctx orelse return;
    actual.deinit();
    std.heap.page_allocator.destroy(actual);
}

pub export fn dim_ctx_define(
    ctx: ?*dim.DimContext,
    name_ptr: [*]const u8,
    name_len: usize,
    expr_ptr: [*]const u8,
    expr_len: usize,
) i32 {
    const actual = ensureContext(ctx) orelse return statusCode(.invalid_argument);
    const name = name_ptr[0..name_len];
    const expr_src = expr_ptr[0..expr_len];
    const assignment_src = std.fmt.allocPrint(std.heap.page_allocator, "{s}=( {s} )", .{ name, expr_src }) catch {
        return statusCode(.out_of_memory);
    };
    defer std.heap.page_allocator.free(assignment_src);

    var result = evaluateOwned(actual, assignment_src) catch return statusCode(.eval_error);
    defer dim.deinitLiteralValue(std.heap.page_allocator, &result);
    return statusCode(.ok);
}

pub export fn dim_ctx_clear(ctx: ?*dim.DimContext, name_ptr: [*]const u8, name_len: usize) void {
    const actual = ensureContext(ctx) orelse return;
    actual.clearConstant(name_ptr[0..name_len]);
}

pub export fn dim_ctx_clear_all(ctx: ?*dim.DimContext) void {
    const actual = ensureContext(ctx) orelse return;
    actual.clearAllConstants();
}

pub export fn dim_ctx_eval(
    ctx: ?*dim.DimContext,
    input_ptr: [*]const u8,
    input_len: usize,
    out_result: *DimEvalResult,
) i32 {
    const actual = ensureContext(ctx) orelse return statusCode(.invalid_argument);
    const input = input_ptr[0..input_len];
    const value = evaluateOwned(actual, input) catch {
        out_result.* = std.mem.zeroes(DimEvalResult);
        return statusCode(.eval_error);
    };
    fillEvalResult(out_result, value);
    return statusCode(.ok);
}

pub export fn dim_ctx_convert_expr(
    ctx: ?*dim.DimContext,
    expr_ptr: [*]const u8,
    expr_len: usize,
    unit_ptr: [*]const u8,
    unit_len: usize,
    out_result: *DimQuantityResult,
) i32 {
    const actual = ensureContext(ctx) orelse return statusCode(.invalid_argument);
    const expr = expr_ptr[0..expr_len];
    const unit = unit_ptr[0..unit_len];
    const source = std.fmt.allocPrint(std.heap.page_allocator, "{s} as {s}", .{ expr, unit }) catch {
        out_result.* = std.mem.zeroes(DimQuantityResult);
        return statusCode(.out_of_memory);
    };
    defer std.heap.page_allocator.free(source);

    var value = evaluateOwned(actual, source) catch {
        out_result.* = std.mem.zeroes(DimQuantityResult);
        return statusCode(.eval_error);
    };
    switch (value) {
        .display_quantity => |dq| {
            fillQuantityResult(out_result, dq);
            return statusCode(.ok);
        },
        else => {
            dim.deinitLiteralValue(std.heap.page_allocator, &value);
            out_result.* = std.mem.zeroes(DimQuantityResult);
            return statusCode(.wrong_kind);
        },
    }
}

pub export fn dim_ctx_convert_value(
    ctx: ?*dim.DimContext,
    value: f64,
    from_ptr: [*]const u8,
    from_len: usize,
    to_ptr: [*]const u8,
    to_len: usize,
    out_value: *f64,
) i32 {
    const actual = ensureContext(ctx) orelse return statusCode(.invalid_argument);
    const source = buildConvertValueExpression(
        std.heap.page_allocator,
        value,
        from_ptr[0..from_len],
        to_ptr[0..to_len],
    ) catch return statusCode(.out_of_memory);
    defer std.heap.page_allocator.free(source);

    var result = evaluateOwned(actual, source) catch return statusCode(.eval_error);
    defer dim.deinitLiteralValue(std.heap.page_allocator, &result);

    switch (result) {
        .display_quantity => |dq| {
            out_value.* = dq.value;
            return statusCode(.ok);
        },
        else => return statusCode(.wrong_kind),
    }
}

pub export fn dim_ctx_is_compatible(
    ctx: ?*dim.DimContext,
    expr_ptr: [*]const u8,
    expr_len: usize,
    unit_ptr: [*]const u8,
    unit_len: usize,
    out_bool: *u32,
) i32 {
    const actual = ensureContext(ctx) orelse return statusCode(.invalid_argument);
    var expr_value = evaluateOwned(actual, expr_ptr[0..expr_len]) catch return statusCode(.eval_error);
    defer dim.deinitLiteralValue(std.heap.page_allocator, &expr_value);

    const unit_expr = buildUnitExpression(std.heap.page_allocator, unit_ptr[0..unit_len]) catch return statusCode(.out_of_memory);
    defer std.heap.page_allocator.free(unit_expr);

    var unit_value = evaluateOwned(actual, unit_expr) catch return statusCode(.eval_error);
    defer dim.deinitLiteralValue(std.heap.page_allocator, &unit_value);

    const expr_dim = literalDimension(expr_value) orelse return statusCode(.wrong_kind);
    const unit_dim = literalDimension(unit_value) orelse return statusCode(.wrong_kind);
    out_bool.* = if (dim.Dimension.eql(expr_dim, unit_dim)) 1 else 0;
    return statusCode(.ok);
}

pub export fn dim_ctx_same_dimension(
    ctx: ?*dim.DimContext,
    lhs_ptr: [*]const u8,
    lhs_len: usize,
    rhs_ptr: [*]const u8,
    rhs_len: usize,
    out_bool: *u32,
) i32 {
    const actual = ensureContext(ctx) orelse return statusCode(.invalid_argument);
    var lhs_value = evaluateOwned(actual, lhs_ptr[0..lhs_len]) catch return statusCode(.eval_error);
    defer dim.deinitLiteralValue(std.heap.page_allocator, &lhs_value);
    var rhs_value = evaluateOwned(actual, rhs_ptr[0..rhs_len]) catch return statusCode(.eval_error);
    defer dim.deinitLiteralValue(std.heap.page_allocator, &rhs_value);

    const lhs_dim = literalDimension(lhs_value) orelse return statusCode(.wrong_kind);
    const rhs_dim = literalDimension(rhs_value) orelse return statusCode(.wrong_kind);
    out_bool.* = if (dim.Dimension.eql(lhs_dim, rhs_dim)) 1 else 0;
    return statusCode(.ok);
}

pub export fn dim_ctx_batch_convert_exprs(
    ctx: ?*dim.DimContext,
    exprs_ptr: [*]const DimSlice,
    units_ptr: [*]const DimSlice,
    count: usize,
    out_values: [*]f64,
    out_statuses: [*]u32,
) i32 {
    const actual = ensureContext(ctx) orelse return statusCode(.invalid_argument);
    zeroF64Slice(out_values, count);

    for (exprs_ptr[0..count], units_ptr[0..count], 0..) |expr_slice, unit_slice, i| {
        var quantity = std.mem.zeroes(DimQuantityResult);
        const rc = dim_ctx_convert_expr(
            actual,
            slicePtr(expr_slice),
            expr_slice.len,
            slicePtr(unit_slice),
            unit_slice.len,
            &quantity,
        );
        out_statuses[i] = @intCast(rc);
        if (rc == statusCode(.ok)) {
            out_values[i] = quantity.value;
            freeQuantityResult(&quantity);
        }
    }

    return statusCode(.ok);
}

pub export fn dim_ctx_batch_convert_values(
    ctx: ?*dim.DimContext,
    values_ptr: [*]const f64,
    from_units_ptr: [*]const DimSlice,
    to_units_ptr: [*]const DimSlice,
    count: usize,
    out_values: [*]f64,
    out_statuses: [*]u32,
) i32 {
    const actual = ensureContext(ctx) orelse return statusCode(.invalid_argument);
    zeroF64Slice(out_values, count);

    for (values_ptr[0..count], from_units_ptr[0..count], to_units_ptr[0..count], 0..) |value, from_slice, to_slice, i| {
        var out_value: f64 = std.math.nan(f64);
        const rc = dim_ctx_convert_value(
            actual,
            value,
            slicePtr(from_slice),
            from_slice.len,
            slicePtr(to_slice),
            to_slice.len,
            &out_value,
        );
        out_statuses[i] = @intCast(rc);
        if (rc == statusCode(.ok)) {
            out_values[i] = out_value;
        }
    }

    return statusCode(.ok);
}

pub export fn dim_free(ptr: [*]u8, len: usize) void {
    std.heap.page_allocator.free(ptr[0..len]);
}

pub export fn dim_alloc(n: usize) ?[*]u8 {
    const buf = std.heap.page_allocator.alloc(u8, n) catch return null;
    return buf.ptr;
}

test "dim_ctx_eval returns structured quantity result" {
    var ctx = dim.DimContext.init(std.testing.allocator);
    defer ctx.deinit();

    var result = std.mem.zeroes(DimEvalResult);
    const rc = dim_ctx_eval(&ctx, "18 kJ / 3 kg as kJ/kg".ptr, "18 kJ / 3 kg as kJ/kg".len, &result);
    defer freeEvalResult(&result);

    try std.testing.expectEqual(statusCode(.ok), rc);
    try std.testing.expectEqual(@as(u32, @intFromEnum(DimValueKind.quantity)), result.kind);
    try std.testing.expectApproxEqAbs(6.0, result.quantity_value, 1e-9);
    try std.testing.expectEqual(@as(i32, 2), result.dim_L_num);
    try std.testing.expectEqual(@as(u32, 1), result.dim_L_den);
    try std.testing.expectEqual(@as(i32, -2), result.dim_T_num);
    try std.testing.expectEqual(@as(u32, 1), result.dim_T_den);
    try std.testing.expectEqualStrings("kJ/kg", (@as([*]const u8, @ptrFromInt(result.unit_ptr)))[0..result.unit_len]);
}

test "dim_ctx_eval exposes rational dimensions directly" {
    var ctx = dim.DimContext.init(std.testing.allocator);
    defer ctx.deinit();

    var result = std.mem.zeroes(DimEvalResult);
    const rc = dim_ctx_eval(&ctx, "(9 m)^0.5".ptr, "(9 m)^0.5".len, &result);
    defer freeEvalResult(&result);

    try std.testing.expectEqual(statusCode(.ok), rc);
    try std.testing.expectEqual(@as(i32, 1), result.dim_L_num);
    try std.testing.expectEqual(@as(u32, 2), result.dim_L_den);
    try std.testing.expectEqual(@as(i32, 0), result.dim_M_num);
    try std.testing.expectEqual(@as(u32, 1), result.dim_M_den);
}

test "dim_ctx_convert_expr exposes rational target dimensions" {
    var ctx = dim.DimContext.init(std.testing.allocator);
    defer ctx.deinit();

    var result = std.mem.zeroes(DimQuantityResult);
    const rc = dim_ctx_convert_expr(&ctx, "1 Pa^0.5".ptr, "1 Pa^0.5".len, "kg^(1/2)*m^(-1/2)*s^(-1)".ptr, "kg^(1/2)*m^(-1/2)*s^(-1)".len, &result);
    defer freeQuantityResult(&result);

    try std.testing.expectEqual(statusCode(.ok), rc);
    try std.testing.expectEqual(@as(i32, 1), result.dim_M_num);
    try std.testing.expectEqual(@as(u32, 2), result.dim_M_den);
    try std.testing.expectEqual(@as(i32, -1), result.dim_L_num);
    try std.testing.expectEqual(@as(u32, 2), result.dim_L_den);
    try std.testing.expectEqual(@as(i32, -1), result.dim_T_num);
    try std.testing.expectEqual(@as(u32, 1), result.dim_T_den);
}

test "dim_ctx_convert_value handles affine conversion" {
    var ctx = dim.DimContext.init(std.testing.allocator);
    defer ctx.deinit();

    var out_value: f64 = 0.0;
    const rc = dim_ctx_convert_value(&ctx, 1.0, "C".ptr, "C".len, "F".ptr, "F".len, &out_value);

    try std.testing.expectEqual(statusCode(.ok), rc);
    try std.testing.expectApproxEqAbs(33.8, out_value, 1e-9);
}

test "dim_ctx_is_compatible and same_dimension preserve compatibility semantics" {
    var ctx = dim.DimContext.init(std.testing.allocator);
    defer ctx.deinit();

    var compatible: u32 = 0;
    var same_dim: u32 = 0;

    const compat_rc = dim_ctx_is_compatible(&ctx, "1 mm".ptr, "1 mm".len, "mi".ptr, "mi".len, &compatible);
    const same_dim_rc = dim_ctx_same_dimension(&ctx, "1 km".ptr, "1 km".len, "1 ft".ptr, "1 ft".len, &same_dim);

    try std.testing.expectEqual(statusCode(.ok), compat_rc);
    try std.testing.expectEqual(statusCode(.ok), same_dim_rc);
    try std.testing.expectEqual(@as(u32, 1), compatible);
    try std.testing.expectEqual(@as(u32, 1), same_dim);
}

test "dim_ctx_batch_convert_exprs matches repeated single conversions" {
    var ctx = dim.DimContext.init(std.testing.allocator);
    defer ctx.deinit();

    const expr_0 = "18 kJ / 3 kg";
    const expr_1 = "1 m";
    const unit_0 = "kJ/kg";
    const unit_1 = "km";

    const exprs = [_]DimSlice{
        .{ .ptr = @intFromPtr(expr_0.ptr), .len = expr_0.len },
        .{ .ptr = @intFromPtr(expr_1.ptr), .len = expr_1.len },
    };
    const units = [_]DimSlice{
        .{ .ptr = @intFromPtr(unit_0.ptr), .len = unit_0.len },
        .{ .ptr = @intFromPtr(unit_1.ptr), .len = unit_1.len },
    };
    var out_values = [_]f64{ 0.0, 0.0 };
    var out_statuses = [_]u32{ 0, 0 };

    const rc = dim_ctx_batch_convert_exprs(&ctx, &exprs, &units, exprs.len, &out_values, &out_statuses);
    try std.testing.expectEqual(statusCode(.ok), rc);
    try std.testing.expectEqual(@as(u32, @intCast(statusCode(.ok))), out_statuses[0]);
    try std.testing.expectEqual(@as(u32, @intCast(statusCode(.ok))), out_statuses[1]);
    try std.testing.expectApproxEqAbs(6.0, out_values[0], 1e-9);
    try std.testing.expectApproxEqAbs(0.001, out_values[1], 1e-12);
}

test "dim_ctx_batch_convert_values matches repeated single conversions" {
    var ctx = dim.DimContext.init(std.testing.allocator);
    defer ctx.deinit();

    const values = [_]f64{ 1.0, 1000.0 };
    const from_units = [_]DimSlice{
        .{ .ptr = @intFromPtr("m".ptr), .len = "m".len },
        .{ .ptr = @intFromPtr("Pa".ptr), .len = "Pa".len },
    };
    const to_units = [_]DimSlice{
        .{ .ptr = @intFromPtr("km".ptr), .len = "km".len },
        .{ .ptr = @intFromPtr("bar".ptr), .len = "bar".len },
    };
    var out_values = [_]f64{ 0.0, 0.0 };
    var out_statuses = [_]u32{ 0, 0 };

    const rc = dim_ctx_batch_convert_values(&ctx, &values, &from_units, &to_units, values.len, &out_values, &out_statuses);
    try std.testing.expectEqual(statusCode(.ok), rc);
    try std.testing.expectEqual(@as(u32, @intCast(statusCode(.ok))), out_statuses[0]);
    try std.testing.expectEqual(@as(u32, @intCast(statusCode(.ok))), out_statuses[1]);
    try std.testing.expectApproxEqAbs(0.001, out_values[0], 1e-12);
    try std.testing.expectApproxEqAbs(0.01, out_values[1], 1e-12);
}
