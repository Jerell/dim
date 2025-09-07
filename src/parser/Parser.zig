const std = @import("std");
const Token = @import("Token.zig").Token;
const TokenType = @import("TokenType.zig").TokenType;
const dim = @import("dim");
const FormatMode = dim.Format.FormatMode;
const ast_expr = @import("Expressions.zig");
const errors = @import("errors.zig");
const Io = @import("../Io.zig").Io;

const ParseError = error{
    ExpectedToken,
    UnexpectedToken,
    ExpectedExpression,
    OutOfMemory,
};

pub const Parser = struct {
    tokens: []const Token,
    current: usize,
    allocator: std.mem.Allocator,
    hadError: bool = false,
    io: *Io,

    pub fn init(
        allocator: std.mem.Allocator,
        tokens: []const Token,
        io: *Io,
    ) Parser {
        return Parser{
            .tokens = tokens,
            .current = 0,
            .allocator = allocator,
            .io = io,
        };
    }

    pub fn parse(self: *Parser) ?*ast_expr.Expr {
        const expr = self.conversion() catch |err| {
            self.hadError = true;
            std.debug.print("Parse error: {any}\n", .{err});
            return null;
        };
        return expr;
    }

    fn conversion(self: *Parser) ParseError!*ast_expr.Expr {
        var expr_ptr = try self.expression();

        if (self.match(&.{TokenType.As})) {
            // Parse a full unit expression after 'as' that may include *, /, ^
            const unit_expr = try self.parseUnitExpr();
            var mode: ?FormatMode = null;

            if (self.match(&.{TokenType.Colon})) {
                const mode_tok = try self.consume(TokenType.Identifier, "Expected format mode after ':'");
                if (std.mem.eql(u8, mode_tok.lexeme, "scientific")) mode = .scientific else if (std.mem.eql(u8, mode_tok.lexeme, "engineering")) mode = .engineering else if (std.mem.eql(u8, mode_tok.lexeme, "auto")) mode = .auto else mode = .none;
            }

            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .display = ast_expr.Display{
                    .expr = expr_ptr,
                    .unit_expr = unit_expr,
                    .mode = mode,
                },
            };
            expr_ptr = node_ptr;
        }

        return expr_ptr;
    }

    fn expression(self: *Parser) ParseError!*ast_expr.Expr {
        return self.comparison();
    }

    fn comparison(self: *Parser) ParseError!*ast_expr.Expr {
        var expr_ptr = try self.term();

        while (self.match(&.{
            TokenType.Greater,
            TokenType.GreaterEqual,
            TokenType.Less,
            TokenType.LessEqual,
            TokenType.Equal,
            TokenType.EqualEqual,
            TokenType.BangEqual,
        })) {
            const op = self.previous();
            const right = try self.term();

            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .binary = ast_expr.Binary{
                    .left = expr_ptr,
                    .operator = op,
                    .right = right,
                },
            };
            expr_ptr = node_ptr;
        }
        return expr_ptr;
    }

    fn term(self: *Parser) ParseError!*ast_expr.Expr {
        var expr_ptr = try self.factor();

        while (self.match(&.{ TokenType.Plus, TokenType.Minus })) {
            const op = self.previous();
            const right = try self.factor();

            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .binary = ast_expr.Binary{
                    .left = expr_ptr,
                    .operator = op,
                    .right = right,
                },
            };
            expr_ptr = node_ptr;
        }
        return expr_ptr;
    }

    fn factor(self: *Parser) ParseError!*ast_expr.Expr {
        var expr_ptr = try self.power();

        while (self.match(&.{ TokenType.Star, TokenType.Slash })) {
            const op = self.previous();
            const right = try self.power();

            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .binary = ast_expr.Binary{
                    .left = expr_ptr,
                    .operator = op,
                    .right = right,
                },
            };
            expr_ptr = node_ptr;
        }
        return expr_ptr;
    }

    fn power(self: *Parser) ParseError!*ast_expr.Expr {
        var expr_ptr = try self.unary();

        if (self.match(&.{TokenType.Caret})) {
            const op = self.previous();
            const right = try self.power(); // right-associative
            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .binary = ast_expr.Binary{
                    .left = expr_ptr,
                    .operator = op,
                    .right = right,
                },
            };
            expr_ptr = node_ptr;
        }
        return expr_ptr;
    }

    fn unary(self: *Parser) ParseError!*ast_expr.Expr {
        if (self.match(&.{ TokenType.Minus, TokenType.Bang })) {
            const op = self.previous();
            const right = try self.unary();

            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .unary = ast_expr.Unary{
                    .operator = op,
                    .right = right,
                },
            };
            return node_ptr;
        }
        return self.primary();
    }

    fn primary(self: *Parser) ParseError!*ast_expr.Expr {
        if (self.match(&.{TokenType.Number})) {
            const lit = self.previous().literal.?;
            const num_node = try self.allocator.create(ast_expr.Expr);
            num_node.* = ast_expr.Expr{
                .literal = ast_expr.Literal{ .value = ast_expr.LiteralValue{ .number = lit.number } },
            };

            // If a unit follows, parse a full unit expression
            if (self.check(TokenType.Identifier)) {
                const unit_expr = try self.parseUnitExpr();
                const unit_node = try self.allocator.create(ast_expr.Expr);
                unit_node.* = ast_expr.Expr{
                    .unit = ast_expr.Unit{
                        .value = num_node,
                        .unit_expr = unit_expr,
                    },
                };
                return unit_node;
            }

            return num_node;
        }

        if (self.match(&.{TokenType.LParen})) {
            const inner = try self.expression();
            _ = try self.consume(TokenType.RParen, "Expect ')' after expression.");
            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .grouping = ast_expr.Grouping{ .expression = inner },
            };
            return node_ptr;
        }

        return self.reportParseError(self.peek(), "Expect expression.");
    }

    fn parseUnitExpr(self: *Parser) ParseError!*ast_expr.Expr {
        var expr_ptr = try self.parseUnitTerm();

        // Only consume '*' or '/' as part of a unit expression if they are
        // followed by another unit identifier. This avoids greedily swallowing
        // numeric multiplication/division like "2 m * 3 m" or "1 m / 2 s".
        while (true) {
            const is_mul = self.check(TokenType.Star);
            const is_div = self.check(TokenType.Slash);
            const is_pow = self.check(TokenType.Caret);
            if (!(is_mul or is_div or is_pow)) break;

            // Look ahead one token after the operator; if it's not an Identifier,
            // stop parsing the unit expression here and let higher-precedence
            // arithmetic handle the operator.
            const after_op_index = self.current + 1;
            if (after_op_index >= self.tokens.len) break;
            if (self.tokens[after_op_index].type != TokenType.Identifier) break;

            // Consume operator now that we know another unit term follows
            _ = self.advance();
            const op = self.previous();
            const right = try self.parseUnitTerm();

            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .compound_unit = ast_expr.CompoundUnit{
                    .left = expr_ptr,
                    .op = op,
                    .right = right,
                },
            };
            expr_ptr = node_ptr;
        }

        return expr_ptr;
    }

    fn parseUnitTerm(self: *Parser) ParseError!*ast_expr.Expr {
        const id_tok = try self.consume(TokenType.Identifier, "Expected unit identifier");
        var exponent: i32 = 1;

        if (self.match(&.{TokenType.Caret})) {
            const exp_tok = try self.consume(TokenType.Number, "Expected exponent after '^'");
            const lit = exp_tok.literal.?;
            if (lit != .number) return error.ExpectedToken;
            exponent = @intFromFloat(lit.number);
        }

        const node_ptr = try self.allocator.create(ast_expr.Expr);
        node_ptr.* = ast_expr.Expr{
            .unit_expr = ast_expr.UnitExpr{
                .name = id_tok.lexeme,
                .exponent = exponent,
            },
        };
        return node_ptr;
    }

    fn match(self: *Parser, types: []const TokenType) bool {
        for (types) |tt| {
            if (self.check(tt)) {
                _ = self.advance();
                return true;
            }
        }
        return false;
    }

    fn check(self: *const Parser, t: TokenType) bool {
        if (self.isAtEnd()) return false;
        return self.peek().type == t;
    }

    fn advance(self: *Parser) Token {
        if (!self.isAtEnd()) self.current += 1;
        return self.previous();
    }

    fn isAtEnd(self: *const Parser) bool {
        return self.peek().type == TokenType.Eof;
    }

    fn peek(self: *const Parser) Token {
        return self.tokens[self.current];
    }

    fn previous(self: *const Parser) Token {
        return self.tokens[self.current - 1];
    }

    fn consume(self: *Parser, t: TokenType, msg: []const u8) ParseError!Token {
        if (self.check(t)) return self.advance();
        return self.reportParseError(self.peek(), msg);
    }

    fn reportParseError(self: *Parser, token: Token, message: []const u8) ParseError {
        self.hadError = true;
        reportTokenError(self.allocator, token, message, self.io);
        return ParseError.ExpectedToken;
    }
};

pub fn reportTokenError(
    allocator: std.mem.Allocator,
    token: Token,
    message: []const u8,
    io: *Io,
) void {
    if (token.type == .Eof) {
        io.eprintf("[line {}] Error at end: {s}\n", .{ token.line, message }) catch {};
    } else {
        const msg_prefix = std.fmt.allocPrint(allocator, " at '{s}'", .{token.lexeme}) catch " at token";
        defer allocator.free(msg_prefix);
        io.eprintf("[line {}] Error{s}: {s}\n", .{ token.line, msg_prefix, message }) catch {};
    }
}
