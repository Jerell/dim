const std = @import("std");
const Token = @import("Token.zig").Token;
const TokenType = @import("TokenType.zig").TokenType;
const ast_expr = @import("Expressions.zig");
const errors = @import("errors.zig");

pub const Parser = struct {
    tokens: []const Token,
    current: usize,
    allocator: std.mem.Allocator,
    hadError: bool = false,

    pub fn init(allocator: std.mem.Allocator, tokens: []const Token) Parser {
        return Parser{
            .tokens = tokens,
            .current = 0,
            .allocator = allocator,
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

    fn conversion(self: *Parser) !*ast_expr.Expr {
        var expr_ptr = try self.expression();

        if (self.match(&.{TokenType.In})) {
            const unit_tok = try self.consume(TokenType.Identifier, "Expected unit after 'in'");
            var mode: ?ast_expr.FormatMode = null;

            if (self.match(&.{TokenType.Colon})) {
                const mode_tok = try self.consume(TokenType.Identifier, "Expected format mode after ':'");
                if (std.mem.eql(u8, mode_tok.lexeme, "scientific")) mode = .scientific else if (std.mem.eql(u8, mode_tok.lexeme, "engineering")) mode = .engineering else if (std.mem.eql(u8, mode_tok.lexeme, "auto")) mode = .auto else mode = .none;
            }

            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .display = ast_expr.Display{
                    .expr = expr_ptr,
                    .target_unit = unit_tok.lexeme,
                    .mode = mode,
                },
            };
            expr_ptr = node_ptr;
        }

        return expr_ptr;
    }

    fn expression(self: *Parser) !*ast_expr.Expr {
        return self.comparison();
    }

    fn comparison(self: *Parser) !*ast_expr.Expr {
        var expr_ptr = try self.term();

        while (self.match(&.{
            TokenType.Greater,
            TokenType.GreaterEqual,
            TokenType.Less,
            TokenType.LessEqual,
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

    fn term(self: *Parser) !*ast_expr.Expr {
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

    fn factor(self: *Parser) !*ast_expr.Expr {
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

    fn power(self: *Parser) !*ast_expr.Expr {
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

    fn unary(self: *Parser) !*ast_expr.Expr {
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

    fn primary(self: *Parser) !*ast_expr.Expr {
        if (self.match(&.{TokenType.Number})) {
            const lit = self.previous().literal.?;
            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .literal = ast_expr.Literal{ .value = ast_expr.LiteralValue{ .number = lit.number } },
            };

            // optional unit after number
            if (self.match(&.{TokenType.Identifier})) {
                const unit_tok = self.previous();
                const unit_node_ptr = try self.allocator.create(ast_expr.Expr);
                unit_node_ptr.* = ast_expr.Expr{
                    .unit = ast_expr.Unit{
                        .value = node_ptr,
                        .unit_name = unit_tok.lexeme,
                    },
                };
                return unit_node_ptr;
            }

            return node_ptr;
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

    fn consume(self: *Parser, t: TokenType, msg: []const u8) !Token {
        if (self.check(t)) return self.advance();
        return self.reportParseError(self.peek(), msg);
    }

    fn reportParseError(self: *Parser, token: Token, message: []const u8) ParseError {
        self.hadError = true;
        reportTokenError(self.allocator, token, message);
        return ParseError.ExpectedToken;
    }
};

pub fn reportTokenError(
    allocator: std.mem.Allocator,
    token: Token,
    message: []const u8,
) void {
    if (token.type == .EOF) {
        errors.report(token.line, " at end", message);
    } else {
        const msg_prefix = std.fmt.allocPrint(allocator, " at '{s}'", .{token.lexeme}) catch " at token";
        defer allocator.free(msg_prefix);
        errors.report(token.line, msg_prefix, message);
    }
}

const ParseError = error{
    ExpectedToken,
    UnexpectedToken,
    ExpectedExpression,
    OutOfMemory,
};
