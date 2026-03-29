const std = @import("std");
const Dimension = @import("dimension.zig").Dimension;
const Rational = @import("rational.zig").Rational;
const Quantity = @import("quantity.zig").Quantity;
const DisplayQuantity = @import("runtime.zig").DisplayQuantity;

pub const Unit = struct {
    dim: Dimension,
    scale: f64,
    offset: f64 = 0.0,
    symbol: []const u8,

    pub fn isAffine(self: Unit) bool {
        return self.offset != 0.0;
    }

    pub fn toCanonicalValue(self: Unit, v: f64, is_delta: bool) f64 {
        if (is_delta) return v * self.scale;
        return (v + self.offset) * self.scale;
    }

    pub fn toCanonical(self: Unit, v: f64) f64 {
        return self.toCanonicalValue(v, false);
    }

    pub fn fromCanonicalValue(self: Unit, v: f64, is_delta: bool) f64 {
        if (is_delta) return v / self.scale;
        return v / self.scale - self.offset;
    }

    pub fn fromCanonical(self: Unit, v: f64) f64 {
        return self.fromCanonicalValue(v, false);
    }

    pub fn from(comptime self: Unit, v: f64) Quantity(self.dim) {
        return .{ .value = self.toCanonical(v), .is_delta = false };
    }

    pub fn to(self: Unit, q: anytype) f64 {
        // Ensure dimensions match
        if (!Dimension.eql(self.dim, @TypeOf(q).dim)) {
            @compileError("Unit dimension does not match Quantity dimension");
        }
        return self.fromCanonicalValue(q.value, q.is_delta);
    }

    pub fn mul(self: Unit, other: Unit, symbol: []const u8) Unit {
        std.debug.assert(!self.isAffine() and !other.isAffine());
        return .{
            .dim = Dimension.add(self.dim, other.dim),
            .scale = self.scale * other.scale,
            .symbol = symbol,
        };
    }

    pub fn mulChecked(self: Unit, other: Unit, symbol: []const u8) error{AffineUnitCombination}!Unit {
        if (self.isAffine() or other.isAffine()) return error.AffineUnitCombination;
        return self.mul(other, symbol);
    }

    pub fn powInt(self: Unit, exponent: i32, symbol: []const u8) Unit {
        std.debug.assert(!self.isAffine());
        return .{
            .dim = Dimension.mulByInt(self.dim, exponent),
            .scale = std.math.pow(f64, self.scale, @floatFromInt(exponent)),
            .symbol = symbol,
        };
    }

    pub fn powRational(self: Unit, exponent: Rational, symbol: []const u8) Unit {
        std.debug.assert(!self.isAffine());
        return .{
            .dim = Dimension.mulByRational(self.dim, exponent),
            .scale = std.math.pow(f64, self.scale, exponent.toF64()),
            .symbol = symbol,
        };
    }

    pub fn pow(self: Unit, exponent: i32, symbol: []const u8) Unit {
        return self.powInt(exponent, symbol);
    }

    pub fn powChecked(self: Unit, exponent: i32, symbol: []const u8) error{AffineUnitCombination}!Unit {
        if (self.isAffine()) return error.AffineUnitCombination;
        return self.powInt(exponent, symbol);
    }

    pub fn powRationalChecked(self: Unit, exponent: Rational, symbol: []const u8) error{AffineUnitCombination}!Unit {
        if (self.isAffine()) return error.AffineUnitCombination;
        return self.powRational(exponent, symbol);
    }

    pub fn div(self: Unit, other: Unit, symbol: []const u8) Unit {
        std.debug.assert(!self.isAffine() and !other.isAffine());
        return .{
            .dim = Dimension.sub(self.dim, other.dim),
            .scale = self.scale / other.scale,
            .symbol = symbol,
        };
    }

    pub fn divChecked(self: Unit, other: Unit, symbol: []const u8) error{AffineUnitCombination}!Unit {
        if (self.isAffine() or other.isAffine()) return error.AffineUnitCombination;
        return self.div(other, symbol);
    }
};

pub const UnitRegistry = struct {
    units: []const Unit,
    aliases: []const Alias,
    prefixes: []const Prefix,

    /// Find a unit by exact symbol or alias match only (no prefix expansion)
    pub fn findExact(self: UnitRegistry, symbol: []const u8) ?Unit {
        // 1. Exact match
        for (self.units) |u| {
            if (std.mem.eql(u8, u.symbol, symbol)) return u;
        }
        // 2. Alias match
        for (self.aliases) |a| {
            if (std.mem.eql(u8, a.symbol, symbol)) return a.target.*;
        }
        return null;
    }

    /// Find a unit by symbol, alias, or prefix + base unit
    pub fn find(self: UnitRegistry, symbol: []const u8) ?Unit {
        // 1. Exact/alias match first
        if (self.findExact(symbol)) |u| return u;
        // 2. Prefix + base unit
        for (self.prefixes) |p| {
            if (std.mem.startsWith(u8, symbol, p.symbol)) {
                const base = symbol[p.symbol.len..];
                if (self.find(base)) |u| {
                    return Unit{
                        .dim = u.dim,
                        .scale = u.scale * p.factor,
                        .offset = u.offset,
                        .symbol = symbol,
                    };
                }
            }
        }
        return null;
    }
};

pub const Alias = struct {
    symbol: []const u8, // e.g. "Newton"
    target: *const Unit, // points to N
};

pub const Prefix = struct {
    symbol: []const u8, // e.g. "k"
    factor: f64, // e.g. 1e3
};
