const std = @import("std");
const TokenType = @import("tokentype.zig").TokenType;
const Token = @import("token.zig").Token;
const dim = @import("dim");
const Format = @import("../format.zig");

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
    quantity: dim.Quantity,
    display_quantity: dim.DisplayQuantity,
    nil,
};

pub const Literal = struct {
    value: LiteralValue,

    pub fn print(self: Literal, writer: *std.Io.Writer) !void {
        switch (self.value) {
            .number => |n| try writer.print("{}", .{n}),
            .string => |s| try writer.print("\"{s}\"", .{s}),
            .boolean => |b| try writer.print("{s}", .{b}),
            .quantity => |q| try q.format(writer),
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

    pub fn print(self: Grouping, writer: *std.Io.Writer) !void {
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

    pub fn print(self: Unary, writer: *std.Io.Writer) !void {
        try writer.print("({s} ", .{self.operator.lexeme});
        try self.right.print(writer);
        try writer.print(")", .{});
    }

    pub fn evaluate(
        self: *Unary,
        allocator: std.mem.Allocator,
    ) RuntimeError!LiteralValue {
        const right_val = try self.right.evaluate(allocator);
        switch (self.operator.type) {
            .MINUS => {
                if (right_val != .number) return RuntimeError.InvalidOperand;
                return LiteralValue{ .number = -right_val.number };
            },
            .BANG => {
                // Lox truthiness: false and nil are falsey, everything else is truthy
                const is_truthy = switch (right_val) {
                    .boolean => |b| b,
                    .nil => false,
                    else => true,
                };
                return LiteralValue{ .boolean = !is_truthy };
            },
            else => unreachable,
        }
    }
};

pub const Binary = struct {
    left: *Expr,
    operator: Token,
    right: *Expr,

    pub fn print(self: Binary, writer: *std.Io.Writer) !void {
        try writer.print("({s} ", .{self.operator.lexeme});
        try self.left.print(writer);
        try writer.print(" ", .{});
        try self.right.print(writer);
        try writer.print(")", .{});
    }

    pub fn evaluate(
        self: *Binary,
        allocator: std.mem.Allocator,
    ) RuntimeError!LiteralValue {
        const left_val = try self.left.evaluate(allocator);
        const right_val = try self.right.evaluate(allocator);

        switch (self.operator.type) {
            .MINUS => {
                if (left_val != .number or right_val != .number)
                    return RuntimeError.InvalidOperands;
                return LiteralValue{ .number = left_val.number - right_val.number };
            },
            .SLASH => {
                if (left_val != .number or right_val != .number)
                    return RuntimeError.InvalidOperands;
                if (right_val.number == 0) return RuntimeError.DivisionByZero;
                return LiteralValue{ .number = left_val.number / right_val.number };
            },
            .STAR => {
                if (left_val != .number or right_val != .number)
                    return RuntimeError.InvalidOperands;
                return LiteralValue{ .number = left_val.number * right_val.number };
            },
            .PLUS => {
                return switch (left_val) {
                    .number => |ln| switch (right_val) {
                        .number => |rn| LiteralValue{ .number = ln + rn },
                        else => RuntimeError.InvalidOperands,
                    },
                    .string => |ls| switch (right_val) {
                        .string => |rs| {
                            const new_str = try std.fmt.allocPrint(
                                allocator,
                                "{s}{s}",
                                .{ ls, rs },
                            );
                            return LiteralValue{ .string = new_str };
                        },
                        else => RuntimeError.InvalidOperands,
                    },
                    else => RuntimeError.InvalidOperands,
                };
            },
            .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL => {
                if (left_val != .number or right_val != .number) {
                    return RuntimeError.InvalidOperands;
                }
                const comparison_result = switch (self.operator.type) {
                    .GREATER => left_val.number > right_val.number,
                    .GREATER_EQUAL => left_val.number >= right_val.number,
                    .LESS => left_val.number < right_val.number,
                    .LESS_EQUAL => left_val.number <= right_val.number,
                    else => unreachable,
                };
                return LiteralValue{ .boolean = comparison_result };
            },
            .EQUAL_EQUAL => {
                return LiteralValue{ .boolean = isEqual(left_val, right_val) };
            },
            .BANG_EQUAL => {
                return LiteralValue{ .boolean = !isEqual(left_val, right_val) };
            },
            else => unreachable,
        }
    }
};

pub const Unit = struct {
    value: *Expr, // the numeric expression (usually a Literal)
    unit_name: []const u8, // e.g. "celsius", "bar"

    pub fn print(self: Unit, writer: *std.Io.Writer) !void {
        try writer.print("(unit ", .{});
        try self.value.print(writer);
        try writer.print(" {s})", .{self.unit_name});
    }

    pub fn evaluate(
        self: *Unit,
        allocator: std.mem.Allocator,
    ) RuntimeError!LiteralValue {
        const val = try self.value.evaluate(allocator);
        if (val != .number) return RuntimeError.InvalidOperand;

        const num = val.number;

        const u = dim.findUnitAllDynamic(self.unit_name, null) orelse {
            return RuntimeError.UndefinedVariable;
        };

        return LiteralValue{ .quantity = u.from(num) };
    }
};

pub const Display = struct {
    expr: *Expr,
    target_unit: []const u8,
    mode: ?Format.FormatMode = null, // optional

    pub fn print(self: Display, writer: *std.Io.Writer) !void {
        try writer.print("(display ", .{});
        try self.expr.print(writer);
        try writer.print(" in {s}", .{self.target_unit});
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
        if (val != .quantity) return RuntimeError.InvalidOperand;

        const q = val.quantity;

        // Ensure target unit exists
        const u = dim.findUnitAllDynamic(self.target_unit, null) orelse {
            return RuntimeError.UndefinedVariable;
        };

        // Ensure dimensions match
        if (!dim.Dimension.eql(q.dim, u.dim)) {
            return RuntimeError.InvalidOperands;
        }

        // Keep canonical value, but override display unit + mode
        return LiteralValue{ .quantity = dim.DisplayQuantity{
            .value = q.value,
            .dim = q.dim,
            .unit = self.target_unit,
            .mode = self.mode orelse .none,
            .is_delta = q.is_delta,
        } };
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
        _ = allocator;

        // Look up the unit definition
        const u = dim.findUnitAllDynamic(self.name, null) orelse {
            return RuntimeError.UndefinedVariable;
        };

        // Raise the unit’s dimension to the exponent
        var dim_accum = u.dim;
        if (self.exponent != 1) {
            dim_accum = dim.Dimension.pow(u.dim, self.exponent);
        }

        // Return a DisplayQuantity with value=1.0 (pure unit factor)
        return LiteralValue{ .display_quantity = dim.DisplayQuantity{
            .value = 1.0,
            .dim = dim_accum,
            .unit = self.name,
            .mode = .none,
            .is_delta = false,
        } };
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

    pub fn print(self: CompoundUnit, writer: *std.Io.Writer) !void {
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

        var new_dim: dim.Dimension = undefined;
        var new_val: f64 = undefined;

        switch (self.op.type) {
            .Star => {
                new_dim = dim.Dimension.add(lq.dim, rq.dim);
                new_val = lq.value * rq.value;
            },
            .Slash => {
                new_dim = dim.Dimension.sub(lq.dim, rq.dim);
                new_val = lq.value / rq.value;
            },
            else => return RuntimeError.UnsupportedOperator,
        }

        const unit_str = try self.toString(allocator);

        return LiteralValue{
            .display_quantity = dim.DisplayQuantity{
                .value = new_val,
                .dim = new_dim,
                .unit = unit_str, // you could build a string like "m/s^2"
                .mode = .none,
                .is_delta = false,
            },
        };
    }

    pub fn toString(self: CompoundUnit, allocator: std.mem.Allocator) ![]u8 {
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

    pub fn toUnitString(self: *Expr, allocator: std.mem.Allocator) ![]u8 {
        return switch (self.*) {
            .unit_expr => |ue| ue.toString(allocator),
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
        }
    }

    pub fn print(self: Expr, writer: *std.Io.Writer) !void {
        switch (self) {
            .binary => |binary| return binary.print(writer),
            .unary => |unary| return unary.print(writer),
            .literal => |literal| return literal.print(writer),
            .grouping => |grouping| return grouping.print(writer),
            .unit => |unit| return unit.print(writer),
            .display => |display| return display.print(writer),
            .compound_unit => |cu| return cu.print(writer),
            .unit_expr => |ue| return ue.print(writer),
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
        else => unreachable,
    };
}

test "AST Printer test" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Build: (* (- 123) (group 45.67))
    const literal123_ptr = try allocator.create(Expr);
    literal123_ptr.* = Expr{
        .literal = Literal{ .value = LiteralValue{ .number = 123.0 } },
    };

    const unary_ptr = try allocator.create(Expr);
    unary_ptr.* = Expr{
        .unary = Unary{
            .operator = Token.init(TokenType.MINUS, "-", null, 1),
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
            .operator = Token.init(TokenType.STAR, "*", null, 1),
            .right = grouping_ptr,
        },
    };
    // If you implement deinit(), uncomment:
    // defer binary_ptr.deinit(allocator);
    defer allocator.destroy(binary_ptr);

    // New: use AllocatingWriter instead of fixedBufferStream
    var aw = std.Io.AllocatingWriter.init(allocator);
    defer aw.deinit();
    const w: *std.Io.Writer = &aw.writer;

    try binary_ptr.print(w);

    const result = try aw.writtenOwned(); // owned by allocator
    defer allocator.free(result);

    const expected = "(* (- 1.23e2) (group 4.567e1))";
    try std.testing.expectEqualStrings(expected, result);
}
