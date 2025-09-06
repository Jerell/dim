//! I need to take a closer look at what kind of statements I'm using
//! I don't plan to have variable assignment or a print keyword

const std = @import("std");
const ast_expr = @import("Expressions.zig");
const Token = @import("Token.zig").Token;

pub const Stmt = union(enum) {
    expression: ExpressionStmt,
    print: PrintStmt,
    var_decl: VarDeclStmt,

    pub fn execute(
        self: *Stmt,
        allocator: std.mem.Allocator,
        writer: *std.Io.Writer,
    ) anyerror!void {
        switch (self.*) {
            .expression => |*stmt_variant| try stmt_variant.execute(allocator, writer),
            .print => |*stmt_variant| try stmt_variant.execute(allocator, writer),
            .var_decl => |*stmt_variant| try stmt_variant.execute(allocator),
        }
    }
};

pub const ExpressionStmt = struct {
    expression: *ast_expr.Expr,

    pub fn execute(
        self: *ExpressionStmt,
        allocator: std.mem.Allocator,
        writer: *std.Io.Writer,
    ) anyerror!void {
        _ = writer;
        _ = try self.expression.evaluate(allocator);
    }
};

pub const PrintStmt = struct {
    expression: *ast_expr.Expr,

    pub fn execute(
        self: *PrintStmt,
        allocator: std.mem.Allocator,
        writer: *std.Io.Writer,
    ) anyerror!void {
        const value = try self.expression.evaluate(allocator);

        switch (value) {
            .number => |n| try writer.print("{d}\n", .{n}),
            .string => |s| try writer.print("{s}\n", .{s}),
            .boolean => |b| try writer.print("{}\n", .{b}),
            .nil => try writer.print("nil\n", .{}),
        }
    }
};

pub const VarDeclStmt = struct {
    name: Token,
    initializer: ?*ast_expr.Expr,

    pub fn execute(
        self: *VarDeclStmt,
        allocator: std.mem.Allocator,
    ) anyerror!void {
        var value_to_store: ast_expr.LiteralValue = .{ .nil = {} }; // Default to Lox nil

        if (self.initializer) |init_expr_ptr| {
            // init_expr_ptr is now a non-optional *ast_expr.Expr
            value_to_store = try init_expr_ptr.evaluate(allocator);
        }

        // TODO: Define the variable in the environment
        // env.define(self.name.lexeme, value_to_store);
        std.debug.print("TODO: Define variable '{s}' with value {any} (allocator: {any})\n", .{
            self.name.lexeme, value_to_store, allocator,
        });
    }
};
