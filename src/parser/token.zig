const std = @import("std");
const TokenType = @import("token_type.zig").TokenType;
const LiteralValue = @import("expressions.zig").LiteralValue;

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    literal: ?LiteralValue,
    line: usize,

    pub fn init(
        tokentype: TokenType,
        lexeme: []const u8,
        literal: ?LiteralValue,
        line: usize,
    ) Token {
        return .{
            .type = tokentype,
            .lexeme = lexeme,
            .literal = literal,
            .line = line,
        };
    }

    pub fn format(self: Token, writer: *std.Io.Writer) !void {
        try writer.print("{s} {s} {?}", .{ self.type, self.lexeme, self.literal });
    }
};
