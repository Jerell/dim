const std = @import("std");

pub const Rational = struct {
    num: i32,
    den: u32,

    pub fn init(num_in: i32, den_in: u32) Rational {
        if (den_in == 0) @panic("Rational denominator cannot be zero");
        if (num_in == 0) return .{ .num = 0, .den = 1 };

        const num64 = @as(i64, num_in);
        const den64 = @as(i64, den_in);
        const abs_num = if (num64 < 0) -num64 else num64;
        const g = gcd(abs_num, den64);

        return .{
            .num = @as(i32, @intCast(@divExact(num64, g))),
            .den = @as(u32, @intCast(@divExact(den64, g))),
        };
    }

    pub fn fromInt(value: i32) Rational {
        return .{ .num = value, .den = 1 };
    }

    pub fn eql(a: Rational, b: Rational) bool {
        return a.num == b.num and a.den == b.den;
    }

    pub fn eqlInt(self: Rational, value: i32) bool {
        return self.den == 1 and self.num == value;
    }

    pub fn isZero(self: Rational) bool {
        return self.num == 0;
    }

    pub fn isInteger(self: Rational) bool {
        return self.den == 1;
    }

    pub fn isPositive(self: Rational) bool {
        return self.num > 0;
    }

    pub fn isNegative(self: Rational) bool {
        return self.num < 0;
    }

    pub fn sign(self: Rational) i2 {
        return if (self.num > 0) 1 else if (self.num < 0) -1 else 0;
    }

    pub fn negate(self: Rational) Rational {
        return .{ .num = -self.num, .den = self.den };
    }

    pub fn abs(self: Rational) Rational {
        return if (self.num < 0) self.negate() else self;
    }

    pub fn add(a: Rational, b: Rational) Rational {
        const num = @as(i64, a.num) * @as(i64, b.den) + @as(i64, b.num) * @as(i64, a.den);
        const den = @as(i64, a.den) * @as(i64, b.den);
        return Rational.init(@as(i32, @intCast(num)), @as(u32, @intCast(den)));
    }

    pub fn sub(a: Rational, b: Rational) Rational {
        return add(a, b.negate());
    }

    pub fn mul(a: Rational, b: Rational) Rational {
        const num = @as(i64, a.num) * @as(i64, b.num);
        const den = @as(i64, a.den) * @as(i64, b.den);
        return Rational.init(@as(i32, @intCast(num)), @as(u32, @intCast(den)));
    }

    pub fn div(a: Rational, b: Rational) Rational {
        if (b.num == 0) @panic("Division by zero rational");

        var num = @as(i64, a.num) * @as(i64, b.den);
        const den = @as(i64, a.den) * @as(i64, if (b.num < 0) -b.num else b.num);

        if (b.num < 0) num = -num;

        return Rational.init(@as(i32, @intCast(num)), @as(u32, @intCast(den)));
    }

    pub fn cmp(a: Rational, b: Rational) std.math.Order {
        const left = @as(i64, a.num) * @as(i64, b.den);
        const right = @as(i64, b.num) * @as(i64, a.den);
        return std.math.order(left, right);
    }

    pub fn toInt(self: Rational) ?i32 {
        if (!self.isInteger()) return null;
        return self.num;
    }

    pub fn toF64(self: Rational) f64 {
        return @as(f64, @floatFromInt(self.num)) / @as(f64, @floatFromInt(self.den));
    }

    pub fn parseExactLiteral(text: []const u8) !Rational {
        if (text.len == 0) return error.InvalidLiteral;

        var parsed_sign: i32 = 1;
        var index: usize = 0;
        if (text[index] == '+') {
            index += 1;
        } else if (text[index] == '-') {
            parsed_sign = -1;
            index += 1;
        }

        if (index >= text.len) return error.InvalidLiteral;

        var dot_index: ?usize = null;
        var i = index;
        while (i < text.len) : (i += 1) {
            const c = text[i];
            if (c == '.') {
                if (dot_index != null) return error.InvalidLiteral;
                dot_index = i;
                continue;
            }
            if (c < '0' or c > '9') return error.InvalidLiteral;
        }

        if (dot_index == null) {
            const parsed = try std.fmt.parseInt(i32, text, 10);
            return Rational.fromInt(parsed);
        }

        const dot = dot_index.?;
        const integer_part = text[index..dot];
        const fractional_part = text[dot + 1 ..];
        if (fractional_part.len == 0) return error.InvalidLiteral;

        var digits_buf: [64]u8 = undefined;
        if (integer_part.len + fractional_part.len > digits_buf.len) return error.InvalidLiteral;

        @memcpy(digits_buf[0..integer_part.len], integer_part);
        @memcpy(digits_buf[integer_part.len .. integer_part.len + fractional_part.len], fractional_part);
        const digits = digits_buf[0 .. integer_part.len + fractional_part.len];

        const magnitude = try std.fmt.parseInt(i32, digits, 10);
        var den: u32 = 1;
        var frac_index: usize = 0;
        while (frac_index < fractional_part.len) : (frac_index += 1) den *= 10;

        return Rational.init(parsed_sign * magnitude, den);
    }

    pub fn formatExponent(self: Rational, writer: anytype) !void {
        if (self.eqlInt(1)) return;
        if (self.isInteger()) {
            if (self.num < 0) {
                try writer.print("^({d})", .{self.num});
            } else {
                try writer.print("^{d}", .{self.num});
            }
            return;
        }
        try writer.print("^({d}/{d})", .{ self.num, self.den });
    }
};

fn gcd(a: i64, b: i64) i64 {
    var x = a;
    var y = b;
    while (y != 0) {
        const r = @mod(x, y);
        x = y;
        y = r;
    }
    return if (x == 0) 1 else x;
}

test "parse exact rational literal" {
    try std.testing.expect(Rational.eql(Rational.fromInt(2), try Rational.parseExactLiteral("2")));
    try std.testing.expect(Rational.eql(Rational.init(1, 2), try Rational.parseExactLiteral("0.5")));
    try std.testing.expect(Rational.eql(Rational.init(-3, 2), try Rational.parseExactLiteral("-1.5")));
}
