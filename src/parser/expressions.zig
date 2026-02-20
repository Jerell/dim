const std = @import("std");
const TokenType = @import("token_type.zig").TokenType;
const Token = @import("token.zig").Token;
const dim = @import("dim");
const DisplayQuantity = dim.DisplayQuantity;
const rt = dim;
const findUnitAllDynamic = dim.findUnitAllDynamic;
const Dimension = dim.Dimension;
const SiRegistry = dim.Registries.si;
const Format = dim.Format;

pub const RuntimeError = error{
    InvalidOperands,
    InvalidOperand,
    DivisionByZero,
    UnsupportedOperator,
    OutOfMemory,
    UndefinedVariable,
};

pub const LiteralValue = union(enum) {
    number: f64,
    string: []const u8,
    boolean: bool,
    display_quantity: DisplayQuantity,
    nil,
};

pub const Literal = struct {
    value: LiteralValue,

    pub fn print(self: Literal, writer: *std.Io.Writer) anyerror!void {
        switch (self.value) {
            .number => |n| try writer.print("{}", .{n}),
            .string => |s| try writer.print("\"{s}\"", .{s}),
            .boolean => |b| try writer.print("{}", .{b}),
            .display_quantity => |dq| try dq.format(writer),
            .nil => try writer.print("nil", .{}),
        }
    }

    pub fn evaluate(
        self: *Literal,
        allocator: std.mem.Allocator,
    ) RuntimeError!LiteralValue {
        _ = allocator;
        return self.value;
    }
};

pub const Grouping = struct {
    expression: *Expr,

    pub fn print(self: Grouping, writer: *std.Io.Writer) anyerror!void {
        try writer.print("(group ", .{});
        try self.expression.print(writer);
        try writer.print(")", .{});
    }

    pub fn evaluate(
        self: *Grouping,
        allocator: std.mem.Allocator,
    ) RuntimeError!LiteralValue {
        return self.expression.evaluate(allocator);
    }
};

pub const Unary = struct {
    operator: Token,
    right: *Expr,

    pub fn print(self: Unary, writer: *std.Io.Writer) anyerror!void {
        try writer.print("({s} ", .{self.operator.lexeme});
        try self.right.print(writer);
        try writer.print(")", .{});
    }

    pub fn evaluate(self: *Unary, allocator: std.mem.Allocator) RuntimeError!LiteralValue {
        const rv = try self.right.evaluate(allocator);
        switch (self.operator.type) {
            .Minus => {
                if (rv == .number) return .{ .number = -rv.number };
                if (rv == .display_quantity) {
                    var dq = rv.display_quantity;
                    dq.value = -dq.value;
                    return .{ .display_quantity = dq };
                }
                return RuntimeError.InvalidOperand;
            },
            .Bang => {
                const truthy = switch (rv) {
                    .boolean => |b| b,
                    .nil => false,
                    .number => |n| n != 0,
                    .string => |s| s.len != 0,
                    .display_quantity => |q| q.value != 0, // treat non-zero as true
                };
                return .{ .boolean = !truthy };
            },
            else => unreachable,
        }
    }
};

pub const Binary = struct {
    left: *Expr,
    operator: Token,
    right: *Expr,

    pub fn print(self: Binary, writer: *std.Io.Writer) anyerror!void {
        try writer.print("({s} ", .{self.operator.lexeme});
        try self.left.print(writer);
        try writer.print(" ", .{});
        try self.right.print(writer);
        try writer.print(")", .{});
    }

    pub fn evaluate(self: *Binary, allocator: std.mem.Allocator) RuntimeError!LiteralValue {
        const left = try self.left.evaluate(allocator);
        const right = try self.right.evaluate(allocator);

        const both_numbers = (left == .number) and (right == .number);
        const both_quant = (left == .display_quantity) and (right == .display_quantity);

        switch (self.operator.type) {
            .Plus => {
                if (both_numbers) return .{ .number = left.number + right.number };
                if (both_quant) {
                    const dq = try rt.addDisplay(left.display_quantity, right.display_quantity);
                    return .{ .display_quantity = dq };
                }
                return RuntimeError.InvalidOperands;
            },
            .Minus => {
                if (both_numbers) return .{ .number = left.number - right.number };
                if (both_quant) {
                    const dq = try rt.subDisplay(left.display_quantity, right.display_quantity);
                    return .{ .display_quantity = dq };
                }
                return RuntimeError.InvalidOperands;
            },
            .Star => {
                if (both_numbers) return .{ .number = left.number * right.number };
                if (both_quant) {
                    const dq = try rt.mulDisplay(allocator, left.display_quantity, right.display_quantity);
                    return .{ .display_quantity = dq };
                }
                if (left == .display_quantity and right == .number) {
                    const dq = rt.scaleDisplay(left.display_quantity, right.number);
                    return .{ .display_quantity = dq };
                }
                if (left == .number and right == .display_quantity) {
                    const dq = rt.scaleDisplay(right.display_quantity, left.number);
                    return .{ .display_quantity = dq };
                }
                return RuntimeError.InvalidOperands;
            },
            .Slash => {
                if (both_numbers) {
                    if (right.number == 0) return RuntimeError.DivisionByZero;
                    return .{ .number = left.number / right.number };
                }
                if (both_quant) {
                    if (right.display_quantity.value == 0) return RuntimeError.DivisionByZero;
                    const dq = try rt.divDisplay(allocator, left.display_quantity, right.display_quantity);
                    return .{ .display_quantity = dq };
                }
                if (left == .display_quantity and right == .number) {
                    if (right.number == 0) return RuntimeError.DivisionByZero;
                    const dq = rt.scaleDisplay(left.display_quantity, 1.0 / right.number);
                    return .{ .display_quantity = dq };
                }
                return RuntimeError.InvalidOperands;
            },
            .Caret => {
                // Right must be a number; base can be number or display_quantity
                if (right != .number) return RuntimeError.InvalidOperands;
                const exp = right.number;

                if (left == .number) {
                    return .{ .number = std.math.pow(f64, left.number, exp) };
                }
                if (left == .display_quantity) {
                    // Try integer exponent fast-path
                    const exp_int: i32 = @intFromFloat(exp);
                    if (@as(f64, @floatFromInt(exp_int)) == exp) {
                        const dq_int = try rt.powDisplay(allocator, left.display_quantity, exp_int);
                        return .{ .display_quantity = dq_int };
                    }
                    // Fallback to fractional exponent; will error if dimensions don't reduce to integers
                    const dq = try rt.powDisplayFloat(allocator, left.display_quantity, exp);
                    return .{ .display_quantity = dq };
                }
                return RuntimeError.InvalidOperands;
            },
            .EqualEqual, .Equal => return .{ .boolean = isEqual(left, right) },
            .BangEqual => return .{ .boolean = !isEqual(left, right) },
            .Greater, .GreaterEqual, .Less, .LessEqual => {
                // Comparisons: allow for numbers; for quantities require same dimension and compare canonical values
                if (both_numbers) {
                    const a = left.number;
                    const b = right.number;
                    const r = switch (self.operator.type) {
                        .Greater => a > b,
                        .GreaterEqual => a >= b,
                        .Less => a < b,
                        .LessEqual => a <= b,
                        else => false,
                    };
                    return .{ .boolean = r };
                }
                if (both_quant and Dimension.eql(left.display_quantity.dim, right.display_quantity.dim)) {
                    const a = left.display_quantity.value;
                    const b = right.display_quantity.value;
                    const r = switch (self.operator.type) {
                        .Greater => a > b,
                        .GreaterEqual => a >= b,
                        .Less => a < b,
                        .LessEqual => a <= b,
                        else => false,
                    };
                    return .{ .boolean = r };
                }
                return RuntimeError.InvalidOperands;
            },
            else => unreachable,
        }
    }
};

pub const Unit = struct {
    value: *Expr, // the numeric expression (usually a Literal)
    unit_expr: *Expr, // the unit expression (e.g., UnitExpr or CompoundUnit)

    pub fn print(self: Unit, writer: *std.Io.Writer) anyerror!void {
        try writer.print("(unit ", .{});
        try self.value.print(writer);
        try writer.print(" ", .{});
        try self.unit_expr.print(writer);
        try writer.print(")", .{});
    }

    pub fn evaluate(
        self: *Unit,
        allocator: std.mem.Allocator,
    ) RuntimeError!LiteralValue {
        const val = try self.value.evaluate(allocator);
        if (val != .number) return RuntimeError.InvalidOperand;

        const num = val.number;

        const unit_val = try self.unit_expr.evaluate(allocator);
        if (unit_val != .display_quantity) return RuntimeError.InvalidOperand;
        const unit_dq = unit_val.display_quantity;

        // Determine canonical value:
        // - For simple unit expressions (single unit, exponent 1), use the unit's affine-aware conversion.
        // - Otherwise (compound units or exponents), treat as pure multiplicative factor.
        var canonical_value: f64 = undefined;
        switch (self.unit_expr.*) {
            .unit_expr => |ue| {
                if (ue.exponent == 1) {
                    const u = findUnitAllDynamic(ue.name, null) orelse return RuntimeError.UndefinedVariable;
                    canonical_value = u.toCanonical(num);
                } else {
                    canonical_value = num * unit_dq.value;
                }
            },
            else => {
                canonical_value = num * unit_dq.value;
            },
        }

        const fallback = try self.unit_expr.toUnitString(allocator);
        defer allocator.free(fallback);
        const normalized_unit = try Format.normalizeUnitString(
            allocator,
            unit_dq.dim,
            fallback,
            SiRegistry,
        );
        return LiteralValue{ .display_quantity = DisplayQuantity{
            .value = canonical_value,
            .dim = unit_dq.dim,
            .unit = normalized_unit,
            .mode = .none,
            .is_delta = false,
        } };
    }
};

pub const Display = struct {
    expr: *Expr,
    unit_expr: *Expr, // unit expression after 'as' (supports *, /, ^)
    mode: ?Format.FormatMode = null, // optional

    pub fn print(self: Display, writer: *std.Io.Writer) anyerror!void {
        try writer.print("(display ", .{});
        try self.expr.print(writer);
        try writer.print(" as ", .{});
        try self.unit_expr.print(writer);
        if (self.mode) |m| {
            try writer.print(":{s}", .{@tagName(m)});
        }
        try writer.print(")", .{});
    }

    pub fn evaluate(
        self: *Display,
        allocator: std.mem.Allocator,
    ) RuntimeError!LiteralValue {
        const val = try self.expr.evaluate(allocator);
        if (val != .display_quantity) return RuntimeError.InvalidOperand;

        const dq = val.display_quantity;

        // Evaluate the unit expression to a DisplayQuantity representing the target unit
        const unit_val = try self.unit_expr.evaluate(allocator);
        if (unit_val != .display_quantity) return RuntimeError.InvalidOperand;
        const target = unit_val.display_quantity;

        // Ensure dimensions match
        if (!Dimension.eql(dq.dim, target.dim)) {
            return RuntimeError.InvalidOperands;
        }

        // Convert canonical value to the requested unit.
        // - For simple unit expressions (single unit, exponent 1), use the unit's affine-aware fromCanonical().
        // - Otherwise, divide by multiplicative conversion factor.
        var converted_value: f64 = undefined;
        switch (self.unit_expr.*) {
            .unit_expr => |ue| {
                if (ue.exponent == 1) {
                    const u = findUnitAllDynamic(ue.name, null) orelse return RuntimeError.UndefinedVariable;
                    converted_value = u.fromCanonical(dq.value);
                } else {
                    converted_value = dq.value / target.value;
                }
            },
            else => {
                converted_value = dq.value / target.value;
            },
        }

        // Printing will use the stored value directly with the chosen unit symbol and mode.
        const unit_copy = try std.fmt.allocPrint(allocator, "{s}", .{target.unit});
        return LiteralValue{ .display_quantity = rt.DisplayQuantity{
            .value = converted_value,
            .dim = dq.dim,
            .unit = unit_copy,
            .mode = self.mode orelse .none,
            .is_delta = dq.is_delta,
        } };
    }
};

pub const Assignment = struct {
    name: []const u8,
    value: *Expr, // expected to be a grouping containing a unit expression

    pub fn print(self: Assignment, writer: *std.Io.Writer) !void {
        try writer.print("(assign {s} ", .{self.name});
        try self.value.print(writer);
        try writer.print(")", .{});
    }

    pub fn evaluate(self: *Assignment, allocator: std.mem.Allocator) RuntimeError!LiteralValue {
        const val = try self.value.evaluate(allocator);
        if (val != .display_quantity) return RuntimeError.InvalidOperand;
        // Define constant in runtime registry; returns void on success
        try dim.defineConstant(self.name, val.display_quantity);
        // Evaluate to the right-hand value to support chaining semantics
        return val;
    }
};

pub const UnitExpr = struct {
    name: []const u8, // e.g. "m", "s"
    exponent: i32 = 1,

    pub fn print(self: UnitExpr, writer: *std.Io.Writer) !void {
        if (self.exponent == 1) {
            try writer.print("{s}", .{self.name});
        } else {
            try writer.print("{s}^{d}", .{ self.name, self.exponent });
        }
    }

    pub fn evaluate(
        self: *UnitExpr,
        allocator: std.mem.Allocator,
    ) RuntimeError!LiteralValue {
        // Look up the unit definition
        const u = findUnitAllDynamic(self.name, null) orelse {
            return RuntimeError.UndefinedVariable;
        };

        // Raise the unit’s dimension to the exponent
        var dim_accum = u.dim;
        if (self.exponent != 1) {
            dim_accum = Dimension.pow(u.dim, self.exponent);
        }

        // Compute conversion factor to canonical for this unit (raised to exponent)
        const base_factor = u.toCanonical(1.0);
        const factor = if (self.exponent == 1)
            base_factor
        else
            std.math.pow(f64, base_factor, @as(f64, @floatFromInt(self.exponent)));

        return LiteralValue{
            .display_quantity = rt.DisplayQuantity{
                .value = factor,
                .dim = dim_accum,
                // Preserve user-specified unit expression (e.g., "in^2")
                .unit = try self.toString(allocator),
                .mode = .none,
                .is_delta = false,
            },
        };
    }

    pub fn toString(self: UnitExpr, allocator: std.mem.Allocator) ![]u8 {
        if (self.exponent == 1) {
            return try std.fmt.allocPrint(allocator, "{s}", .{self.name});
        } else {
            return try std.fmt.allocPrint(allocator, "{s}^{d}", .{ self.name, self.exponent });
        }
    }
};

pub const CompoundUnit = struct {
    left: *Expr,
    op: Token, // Star or Slash
    right: *Expr,

    pub fn print(self: CompoundUnit, writer: *std.Io.Writer) anyerror!void {
        try self.left.print(writer);
        try writer.print(" {s} ", .{self.op.lexeme});
        try self.right.print(writer);
    }

    pub fn evaluate(
        self: *CompoundUnit,
        allocator: std.mem.Allocator,
    ) RuntimeError!LiteralValue {
        const left_val = try self.left.evaluate(allocator);
        const right_val = try self.right.evaluate(allocator);

        if (left_val != .display_quantity or right_val != .display_quantity) {
            return RuntimeError.InvalidOperand;
        }

        const lq = left_val.display_quantity;
        const rq = right_val.display_quantity;

        var new_dim: Dimension = undefined;
        var new_val: f64 = undefined;

        switch (self.op.type) {
            .Star => {
                new_dim = Dimension.add(lq.dim, rq.dim);
                new_val = lq.value * rq.value;
            },
            .Slash => {
                new_dim = Dimension.sub(lq.dim, rq.dim);
                new_val = lq.value / rq.value;
            },
            else => return RuntimeError.UnsupportedOperator,
        }

        const unit_str = try self.toString(allocator);
        defer allocator.free(unit_str);
        const unit_copy = try std.fmt.allocPrint(allocator, "{s}", .{unit_str});

        return LiteralValue{
            .display_quantity = rt.DisplayQuantity{
                .value = new_val,
                .dim = new_dim,
                .unit = unit_copy,
                .mode = .none,
                .is_delta = false,
            },
        };
    }

    pub fn toString(self: CompoundUnit, allocator: std.mem.Allocator) error{OutOfMemory}![]u8 {
        const left_str = try self.left.toUnitString(allocator);
        defer allocator.free(left_str);

        const right_str = try self.right.toUnitString(allocator);
        defer allocator.free(right_str);

        return try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
            left_str,
            if (self.op.type == .Star) "*" else "/",
            right_str,
        });
    }
};

pub const Expr = union(enum) {
    binary: Binary,
    unary: Unary,
    literal: Literal,
    grouping: Grouping,
    unit: Unit,
    display: Display,
    compound_unit: CompoundUnit,
    unit_expr: UnitExpr,
    assignment: Assignment,

    pub fn toUnitString(self: *Expr, allocator: std.mem.Allocator) ![]u8 {
        return switch (self.*) {
            .unit_expr => |ue| try ue.toString(allocator),
            .compound_unit => |cu| cu.toString(allocator),
            else => std.fmt.allocPrint(allocator, "<?>", .{}),
        };
    }

    pub fn evaluate(
        self: *Expr,
        allocator: std.mem.Allocator,
    ) RuntimeError!LiteralValue {
        switch (self.*) {
            .binary => |*binary| return binary.evaluate(allocator),
            .unary => |*unary| return unary.evaluate(allocator),
            .literal => |*literal| return literal.evaluate(allocator),
            .grouping => |*grouping| return grouping.evaluate(allocator),
            .unit => |*unit| return unit.evaluate(allocator),
            .display => |*display| return display.evaluate(allocator),
            .compound_unit => |*cu| return cu.evaluate(allocator),
            .unit_expr => |*ue| return ue.evaluate(allocator),
            .assignment => |*asgn| return asgn.evaluate(allocator),
        }
    }

    pub fn print(self: Expr, writer: *std.Io.Writer) anyerror!void {
        switch (self) {
            .binary => |binary| return binary.print(writer),
            .unary => |unary| return unary.print(writer),
            .literal => |literal| return literal.print(writer),
            .grouping => |grouping| return grouping.print(writer),
            .unit => |unit| return unit.print(writer),
            .display => |display| return display.print(writer),
            .compound_unit => |cu| return cu.print(writer),
            .unit_expr => |ue| return ue.print(writer),
            .assignment => |a| return a.print(writer),
        }
    }
};

fn isEqual(left: LiteralValue, right: LiteralValue) bool {
    if (left == .nil and right == .nil) return true;
    if (left == .nil or right == .nil) return false;
    if (!std.mem.eql(u8, @tagName(left), @tagName(right))) return false;

    return switch (left) {
        .number => |ln| right.number == ln,
        .string => |ls| std.mem.eql(u8, ls, right.string),
        .boolean => |lb| right.boolean == lb,
        .display_quantity => |lq| Dimension.eql(lq.dim, right.display_quantity.dim) and (lq.value == right.display_quantity.value),
        else => unreachable,
    };
}

test "AST Printer test" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Build: (* (- 123) (group 45.67))
    const literal123_ptr = try allocator.create(Expr);
    literal123_ptr.* = Expr{
        .literal = Literal{ .value = LiteralValue{ .number = 123.0 } },
    };

    const unary_ptr = try allocator.create(Expr);
    unary_ptr.* = Expr{
        .unary = Unary{
            .operator = Token.init(TokenType.Minus, "-", null, 1),
            .right = literal123_ptr,
        },
    };

    const literal4567_ptr = try allocator.create(Expr);
    literal4567_ptr.* = Expr{
        .literal = Literal{ .value = LiteralValue{ .number = 45.67 } },
    };

    const grouping_ptr = try allocator.create(Expr);
    grouping_ptr.* = Expr{
        .grouping = Grouping{ .expression = literal4567_ptr },
    };

    const binary_ptr = try allocator.create(Expr);
    binary_ptr.* = Expr{
        .binary = Binary{
            .left = unary_ptr,
            .operator = Token.init(TokenType.Star, "*", null, 1),
            .right = grouping_ptr,
        },
    };
    // If you implement deinit(), uncomment:
    // defer binary_ptr.deinit(allocator);
    defer allocator.destroy(binary_ptr);

    // Use fixedBufferStream but adapt its GenericWriter to *std.Io.Writer
    var out_buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&out_buf);
    var gw = fbs.writer();
    var bridge_buf: [32]u8 = undefined;
    var adapter = gw.adaptToNewApi(&bridge_buf);
    const w: *std.Io.Writer = &adapter.new_interface;

    try binary_ptr.print(w);

    // Manually flush the adapted writer's buffered data into the fixed buffer stream
    while (true) {
        const pending = w.buffered();
        if (pending.len == 0) break;
        try gw.writeAll(pending);
        _ = w.consume(pending.len);
    }

    const result = fbs.getWritten();

    const expected = "(* (- 123) (group 45.67))";
    try std.testing.expectEqualStrings(expected, result);
}
