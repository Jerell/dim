const std = @import("std");
const Dimension = @import("Dimension.zig").Dimension;
const Quantity = @import("quantity.zig").Quantity;
const DisplayQuantity = @import("runtime.zig").DisplayQuantity;

pub const Unit = struct {
    dim: Dimension,
    scale: f64,
    offset: f64 = 0.0,
    symbol: []const u8,

    pub fn toCanonical(self: Unit, v: f64) f64 {
        return (v + self.offset) * self.scale;
    }

    pub fn fromCanonical(self: Unit, v: f64) f64 {
        return v / self.scale - self.offset;
    }

    pub fn from(self: Unit, v: f64) DisplayQuantity {
        return DisplayQuantity{
            .value = self.toCanonical(v),
            .dim = self.dim,
            .unit = self.symbol, // Use the unit's symbol as display unit
            .mode = .none,
            .is_delta = false,
        };
    }

    pub fn to(self: Unit, q: anytype) f64 {
        // Ensure dimensions match
        if (!Dimension.eql(self.dim, @TypeOf(q).dim)) {
            @compileError("Unit dimension does not match Quantity dimension");
        }
        return self.fromCanonical(q.value);
    }
};

pub const UnitRegistry = struct {
    units: []const Unit,
    aliases: []const Alias,
    prefixes: []const Prefix,

    pub fn find(self: UnitRegistry, symbol: []const u8) ?Unit {
        // 1. Exact match
        for (self.units) |u| {
            if (std.mem.eql(u8, u.symbol, symbol)) return u;
        }
        // 2. Alias match
        for (self.aliases) |a| {
            if (std.mem.eql(u8, a.symbol, symbol)) return a.target.*;
        }
        // 3. Prefix + base unit
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
