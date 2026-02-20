const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token_type.zig").TokenType;
const LiteralValue = @import("expressions.zig").LiteralValue;
const errors = @import("errors.zig");

pub const Scanner = struct {
    source: []const u8,
    tokens: std.ArrayListUnmanaged(Token),
    allocator: std.mem.Allocator,
    err_writer: ?*std.Io.Writer,
    start: usize,
    current: usize,
    line: usize,

    pub fn init(allocator: std.mem.Allocator, err_writer: ?*std.Io.Writer, source: []const u8) !Scanner {
        return .{
            .source = source,
            .tokens = .{},
            .allocator = allocator,
            .err_writer = err_writer,
            .start = 0,
            .current = 0,
            .line = 1,
        };
    }

    pub fn scanTokens(self: *Scanner) ![]Token {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }

        try self.addToken(TokenType.Eof, null);
        return self.tokens.items;
    }

    fn isAtEnd(self: *const Scanner) bool {
        return self.current >= self.source.len;
    }

    fn scanToken(self: *Scanner) !void {
        const c = self.advance();
        // Handle common Unicode multiplication symbols by normalizing to '*'
        // - U+00B7 MIDDLE DOT (UTF-8: C2 B7)
        // - U+22C5 DOT OPERATOR (UTF-8: E2 8B 85)
        // - U+00D7 MULTIPLICATION SIGN (UTF-8: C3 97)
        if (c == 0xC2 and self.peek() == 0xB7) {
            _ = self.advance(); // consume 0xB7
            try self.addToken(TokenType.Star, null);
            return;
        }
        if (c == 0xE2 and self.peek() == 0x8B and self.peekNext() == 0x85) {
            self.current += 2; // consume 0x8B 0x85
            try self.addToken(TokenType.Star, null);
            return;
        }
        if (c == 0xC3 and self.peek() == 0x97) {
            _ = self.advance(); // consume 0x97
            try self.addToken(TokenType.Star, null);
            return;
        }
        switch (c) {
            '(' => try self.addToken(TokenType.LParen, null),
            ')' => try self.addToken(TokenType.RParen, null),
            ',' => try self.addToken(TokenType.Comma, null),
            '.' => try self.addToken(TokenType.Dot, null),
            ':' => try self.addToken(TokenType.Colon, null),
            '-' => try self.addToken(TokenType.Minus, null),
            '+' => try self.addToken(TokenType.Plus, null),
            '*' => try self.addToken(TokenType.Star, null),
            '^' => try self.addToken(TokenType.Caret, null),
            '!' => try self.addToken(if (self.match('=')) TokenType.BangEqual else TokenType.Bang, null),
            '=' => try self.addToken(if (self.match('=')) TokenType.EqualEqual else TokenType.Equal, null),
            '<' => try self.addToken(if (self.match('=')) TokenType.LessEqual else TokenType.Less, null),
            '>' => try self.addToken(if (self.match('=')) TokenType.GreaterEqual else TokenType.Greater, null),
            '/' => {
                if (self.match('/')) {
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        _ = self.advance();
                    }
                } else {
                    try self.addToken(TokenType.Slash, null);
                }
            },
            ' ', '\r', '\t' => {},
            '\n' => {
                self.line += 1;
            },
            // '"' => try self.string(),

            else => {
                if (isDigit(c)) {
                    try self.number();
                } else if (isAlpha(c)) {
                    try self.identifier();
                } else {
                    errors.reportError(self.err_writer, self.line, "unexpected character");
                }
            },
        }
    }

    fn advance(self: *Scanner) u8 {
        self.current += 1;
        return self.source[self.current - 1];
    }

    fn addToken(self: *Scanner, token_type: TokenType, literal: ?LiteralValue) !void {
        const text = self.source[self.start..self.current];
        try self.tokens.append(self.allocator, Token.init(
            token_type,
            text,
            literal,
            self.line,
        ));
    }

    fn match(self: *Scanner, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != expected) return false;

        self.current += 1;
        return true;
    }

    fn peek(self: *const Scanner) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    fn peekNext(self: *const Scanner) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }

    // fn string(self: *Scanner) !void {
    //     while (self.peek() != '"' and !self.isAtEnd()) {
    //         if (self.peek() == '\n') self.line += 1;
    //         _ = self.advance();
    //     }
    //
    //     if (self.isAtEnd()) {
    //         errors.reportError(self.line, "Unterminated string.");
    //         return;
    //     }
    //
    //     // The closing "
    //     _ = self.advance();
    //
    //     // Trim the surrounding quotes
    //     const value = self.source[self.start + 1 .. self.current - 1];
    //     try self.addToken(TokenType.STRING, LiteralValue{ .string = value });
    // }

    fn number(self: *Scanner) !void {
        while (isDigit(self.peek())) {
            _ = self.advance();
        }

        // Look for a fractional part
        if (self.peek() == '.' and isDigit(self.peekNext())) {
            // Consume the "."
            _ = self.advance();

            while (isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        const num_str = self.source[self.start..self.current];
        const value = std.fmt.parseFloat(f64, num_str) catch {
            errors.reportError(self.err_writer, self.line, "Invalid number format");
            return;
        };

        try self.addToken(TokenType.Number, LiteralValue{ .number = value });
    }

    fn identifier(self: *Scanner) !void {
        while (true) {
            const c = self.peek();
            if (isAlphaNumeric(c)) {
                _ = self.advance();
            } else if (c == 0xC2) {
                // Could be superscript (¹, ², ³) or middle dot (·)
                // Check second byte to determine
                if (self.current + 1 < self.source.len) {
                    const second = self.source[self.current + 1];
                    if (second == 0xB9 or second == 0xB2 or second == 0xB3) {
                        // It's a superscript: ¹, ², or ³
                        _ = self.advance(); // consume 0xC2
                        _ = self.advance(); // consume second byte
                    } else {
                        // Not a superscript (could be middle dot 0xB7 or something else)
                        // Stop scanning identifier so it can be handled as a separate token
                        break;
                    }
                } else {
                    break;
                }
            } else if (c == 0xE2) {
                // Could be superscript (⁰, ⁴-⁹) or dot operator (·)
                // Check second and third bytes to determine
                if (self.current + 2 < self.source.len) {
                    const second = self.source[self.current + 1];
                    const third = self.source[self.current + 2];
                    if (second == 0x81 and (third == 0xB0 or (third >= 0xB4 and third <= 0xB9))) {
                        // It's a superscript: ⁰ or ⁴-⁹
                        _ = self.advance(); // consume 0xE2
                        _ = self.advance(); // consume 0x81
                        _ = self.advance(); // consume third byte
                    } else {
                        // Not a superscript (could be dot operator 0x8B 0x85 or something else)
                        // Stop scanning identifier so it can be handled as a separate token
                        break;
                    }
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        const text = self.source[self.start..self.current];
        const tokentype = identifierType(text);

        try self.addToken(tokentype, null);
    }
};

fn isDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

fn isAlpha(char: u8) bool {
    return (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z') or char == '_';
}

fn isAlphaNumeric(char: u8) bool {
    return isAlpha(char) or isDigit(char);
}

// Check if a byte is the start of a superscript character
// Common superscripts: ⁰ (U+2070), ¹ (U+00B9), ² (U+00B2), ³ (U+00B3), ⁴-⁹ (U+2074-2079)
fn isSuperscriptStart(char: u8) bool {
    // ³ (U+00B3) is encoded as 0xC2 0xB3 in UTF-8
    // ² (U+00B2) is encoded as 0xC2 0xB2 in UTF-8
    // ¹ (U+00B9) is encoded as 0xC2 0xB9 in UTF-8
    // ⁰ (U+2070) is encoded as 0xE2 0x81 0xB0 in UTF-8
    // ⁴-⁹ (U+2074-2079) are encoded as 0xE2 0x81 0xB4-0xB9 in UTF-8
    return char == 0xC2 or char == 0xE2;
}

const keywords = std.StaticStringMap(TokenType).initComptime(.{
    .{ "and", TokenType.And },
    .{ "or", TokenType.Or },
    .{ "as", TokenType.As },
    .{ "list", TokenType.List },
    .{ "show", TokenType.Show },
    .{ "clear", TokenType.Clear },
    .{ "all", TokenType.All },
});

fn identifierType(text: []const u8) TokenType {
    return keywords.get(text) orelse TokenType.Identifier;
}
