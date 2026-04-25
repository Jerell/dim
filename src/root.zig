const std = @import("std");

pub const Dimension = @import("dimension.zig").Dimension;
pub const Rational = @import("rational.zig").Rational;
pub const Quantity = @import("quantity.zig").Quantity;
pub const Dimensions = @import("dimension.zig").Dimensions;
pub const Unit = @import("unit.zig").Unit;
pub const Alias = @import("unit.zig").Alias;
pub const Prefix = @import("unit.zig").Prefix;
pub const UnitRegistry = @import("unit.zig").UnitRegistry;
// Re-export runtime types and helpers
pub const DisplayQuantity = @import("runtime.zig").DisplayQuantity;
pub const addDisplay = @import("runtime.zig").addDisplay;
pub const subDisplay = @import("runtime.zig").subDisplay;
pub const mulDisplay = @import("runtime.zig").mulDisplay;
pub const divDisplay = @import("runtime.zig").divDisplay;
pub const scaleDisplay = @import("runtime.zig").scaleDisplay;
pub const powDisplay = @import("runtime.zig").powDisplay;
pub const powDisplayInt = @import("runtime.zig").powDisplayInt;
pub const powDisplayRational = @import("runtime.zig").powDisplayRational;

// Re-export formatting API
pub const Format = @import("format.zig");

const _si = @import("registry/si.zig");
const _imperial = @import("registry/imperial.zig");
const _cgs = @import("registry/cgs.zig");
const _industrial = @import("registry/industrial.zig");

// Parser exports
pub const Scanner = @import("parser/scanner.zig").Scanner;
pub const Parser = @import("parser/parser.zig").Parser;
pub const reportTokenError = @import("parser/parser.zig").reportTokenError;
pub const LiteralValue = @import("parser/expressions.zig").LiteralValue;
pub const Expr = @import("parser/expressions.zig").Expr;
pub const RuntimeError = @import("parser/expressions.zig").RuntimeError;
pub const ConstantEntry = struct {
    name: []const u8,
    unit: Unit,
};

pub const DimContext = struct {
    constants_arena: std.heap.ArenaAllocator,
    scratch_arena: std.heap.ArenaAllocator,
    consts: std.StringHashMapUnmanaged(Unit) = .empty,
    const_names: std.ArrayListUnmanaged([]const u8) = .empty,

    pub fn init(backing_allocator: std.mem.Allocator) DimContext {
        return .{
            .constants_arena = std.heap.ArenaAllocator.init(backing_allocator),
            .scratch_arena = std.heap.ArenaAllocator.init(backing_allocator),
        };
    }

    pub fn deinit(self: *DimContext) void {
        self.constants_arena.deinit();
        self.scratch_arena.deinit();
        self.consts = .empty;
        self.const_names = .empty;
    }

    fn constAllocator(self: *DimContext) std.mem.Allocator {
        return self.constants_arena.allocator();
    }

    fn scratchAllocator(self: *DimContext) std.mem.Allocator {
        _ = self.scratch_arena.reset(.retain_capacity);
        return self.scratch_arena.allocator();
    }

    pub fn defineConstant(self: *DimContext, name_in: []const u8, dq: DisplayQuantity) !void {
        const a = self.constAllocator();
        const name = try std.fmt.allocPrint(a, "{s}", .{name_in});
        const u = Unit{
            .dim = dq.dim,
            .scale = dq.canonicalValue(),
            .offset = 0.0,
            .symbol = name,
        };

        if (self.consts.get(name_in) == null) {
            try self.consts.put(a, name, u);
            try self.const_names.append(a, name);
            return;
        }

        _ = self.consts.remove(name_in);
        try self.consts.put(a, name, u);

        for (self.const_names.items) |n| {
            if (std.mem.eql(u8, n, name_in)) return;
        }
        try self.const_names.append(a, name);
    }

    pub fn getConstant(self: *DimContext, symbol: []const u8) ?Unit {
        return self.consts.get(symbol);
    }

    pub fn clearConstant(self: *DimContext, name: []const u8) void {
        _ = self.consts.remove(name);
        var i: usize = 0;
        while (i < self.const_names.items.len) : (i += 1) {
            if (std.mem.eql(u8, self.const_names.items[i], name)) {
                _ = self.const_names.orderedRemove(i);
                break;
            }
        }
    }

    pub fn clearAllConstants(self: *DimContext) void {
        self.consts.clearRetainingCapacity();
        self.const_names.clearRetainingCapacity();
        _ = self.constants_arena.reset(.retain_capacity);
    }

    pub fn constantsCount(self: *DimContext) usize {
        return self.const_names.items.len;
    }

    pub fn constantByIndex(self: *DimContext, index: usize) ?ConstantEntry {
        if (index >= self.const_names.items.len) return null;
        const name = self.const_names.items[index];
        const unit = self.consts.get(name) orelse return null;
        return .{ .name = name, .unit = unit };
    }
};

var _default_context = DimContext.init(std.heap.page_allocator);
var _active_context: ?*DimContext = null;

fn currentContext() *DimContext {
    return _active_context orelse &_default_context;
}

pub fn deinitLiteralValue(allocator: std.mem.Allocator, value: *LiteralValue) void {
    switch (value.*) {
        .display_quantity => |*dq| dq.deinit(allocator),
        .string => |s| allocator.free(s),
        else => {},
    }
    value.* = .nil;
}

pub fn evaluateWithContext(
    ctx: *DimContext,
    result_allocator: std.mem.Allocator,
    source: []const u8,
    err_writer: ?*std.Io.Writer,
) ?LiteralValue {
    const previous_ctx = _active_context;
    _active_context = ctx;
    defer _active_context = previous_ctx;

    const arena_alloc = ctx.scratchAllocator();

    var scanner = Scanner.init(arena_alloc, err_writer, source) catch return null;
    const tokens = scanner.scanTokens() catch return null;
    var parser = Parser.init(arena_alloc, tokens, err_writer);
    const expr = parser.parse() orelse return null;
    if (parser.hadError) return null;
    if (tokens[parser.current].type != .Eof) {
        reportTokenError(arena_alloc, tokens[parser.current], "Unexpected token", err_writer);
        return null;
    }
    const result = expr.evaluate(arena_alloc) catch return null;

    return switch (result) {
        .display_quantity => |dq| LiteralValue{ .display_quantity = .{
            .value = dq.value,
            .dim = dq.dim,
            .unit = result_allocator.dupe(u8, dq.unit) catch return null,
            .mode = dq.mode,
            .is_delta = dq.is_delta,
            .value_space = dq.value_space,
        } },
        .string => |s| LiteralValue{ .string = result_allocator.dupe(u8, s) catch return null },
        else => result,
    };
}

/// Evaluate a string expression. Returns null on parse/eval errors.
/// Pass an error writer to receive error messages, or null to discard them.
/// The returned LiteralValue (if .display_quantity) has its .unit string
/// allocated with the provided allocator. All intermediate scanner/parser
/// allocations are cleaned up automatically via an internal arena.
pub fn evaluate(allocator: std.mem.Allocator, source: []const u8, err_writer: ?*std.Io.Writer) ?LiteralValue {
    return evaluateWithContext(currentContext(), allocator, source, err_writer);
}

pub fn defineConstant(name_in: []const u8, dq: DisplayQuantity) !void {
    try currentContext().defineConstant(name_in, dq);
}

pub fn getConstant(symbol: []const u8) ?Unit {
    return currentContext().getConstant(symbol);
}

pub fn clearConstant(name: []const u8) void {
    currentContext().clearConstant(name);
}

pub fn clearAllConstants() void {
    currentContext().clearAllConstants();
}

pub fn constantsCount() usize {
    return currentContext().constantsCount();
}

pub fn constantByIndex(index: usize) ?ConstantEntry {
    return currentContext().constantByIndex(index);
}

/// Search across all built-in registries
pub fn findUnitAll(symbol: []const u8) ?Unit {
    // 0. Constants first
    if (getConstant(symbol)) |u_const| return u_const;

    // 1. First pass: exact/alias matches only (prevents prefix greed across registries)
    if (_si.Registry.findExact(symbol)) |u| return u;
    if (_imperial.Registry.findExact(symbol)) |u| return u;
    if (_cgs.Registry.findExact(symbol)) |u| return u;
    if (_industrial.Registry.findExact(symbol)) |u| return u;

    // 2. Second pass: with prefix expansion
    if (_si.Registry.find(symbol)) |u| return u;
    if (_imperial.Registry.find(symbol)) |u| return u;
    if (_cgs.Registry.find(symbol)) |u| return u;
    if (_industrial.Registry.find(symbol)) |u| return u;

    return null;
}

/// Search across built-in registries + optional user-supplied registries
pub fn findUnitAllDynamic(symbol: []const u8, extra: ?[]const UnitRegistry) ?Unit {
    // Search constants first
    if (getConstant(symbol)) |u| return u;

    // 1. First pass: exact/alias matches only (prevents prefix greed across registries)
    if (_si.Registry.findExact(symbol)) |u| return u;
    if (_imperial.Registry.findExact(symbol)) |u| return u;
    if (_cgs.Registry.findExact(symbol)) |u| return u;
    if (_industrial.Registry.findExact(symbol)) |u| return u;
    if (extra) |regs| {
        for (regs) |reg| {
            if (reg.findExact(symbol)) |u| return u;
        }
    }

    // 2. Second pass: with prefix expansion
    if (_si.Registry.find(symbol)) |u| return u;
    if (_imperial.Registry.find(symbol)) |u| return u;
    if (_cgs.Registry.find(symbol)) |u| return u;
    if (_industrial.Registry.find(symbol)) |u| return u;
    if (extra) |regs| {
        for (regs) |reg| {
            if (reg.find(symbol)) |u| return u;
        }
    }

    return null;
}

/// Re-export ergonomic constructors
pub const Units = struct {
    pub const si = _si.Units;
    pub const imperial = _imperial.Units;
    pub const cgs = _cgs.Units;
    pub const industrial = _industrial.Units;
};

/// Re-export full registries
pub const Registries = struct {
    pub const si = _si.Registry;
    pub const imperial = _imperial.Registry;
    pub const cgs = _cgs.Registry;
    pub const industrial = _industrial.Registry;
};

test "basic dimensional arithmetic" {
    const LengthQ = Quantity(Dimensions.Length);
    const TimeQ = Quantity(Dimensions.Time);
    const SpeedQ = Quantity(Dimensions.Velocity);

    const d = LengthQ.init(100.0); // 100 m
    const t = TimeQ.init(10.0); // 10 s
    const v = d.div(t);

    try std.testing.expectApproxEqAbs(10.0, v.value, 1e-9);
    comptime {
        const ResultQ = @TypeOf(v);
        _ = @as(SpeedQ, ResultQ{ .value = 0.0, .is_delta = false });
    }
}

test "force = mass * acceleration" {
    const MassQ = Quantity(Dimensions.Mass);
    const AccelQ = Quantity(Dimensions.Acceleration);
    const ForceQ = Quantity(Dimensions.Force);

    const m = MassQ.init(2.0); // 2 kg
    const a = AccelQ.init(9.81); // 9.81 m/s^2
    const f = m.mul(a);

    comptime {
        const ResultQ = @TypeOf(f);
        _ = @as(ForceQ, ResultQ{ .value = 0.0, .is_delta = false });
    }

    try std.testing.expectApproxEqAbs(19.62, f.value, 1e-9);
}

test "unit composition supports unchecked and checked affine handling" {
    const kmh = _si.km.div(_si.h, "km/h");
    try std.testing.expect(Dimension.eql(kmh.dim, Dimensions.Velocity));
    try std.testing.expectApproxEqAbs(1000.0 / 3600.0, kmh.scale, 1e-12);

    try std.testing.expectError(error.AffineUnitCombination, _si.C.divChecked(_si.h, "C/h"));
    try std.testing.expectError(error.AffineUnitCombination, _imperial.F.powChecked(2, "F^2"));
}

test "rational normalization and quantity power helpers" {
    try std.testing.expect(Rational.eql(Rational.init(2, 4), Rational.init(1, 2)));
    try std.testing.expect(Rational.eql(Rational.div(Rational.fromInt(-2), Rational.fromInt(-4)), Rational.init(1, 2)));
    try std.testing.expect(Rational.eql(Rational.init(0, 5), Rational.fromInt(0)));

    const sqrt_length_dim = Dimension.mulByRational(Dimensions.Length, Rational.init(1, 2));
    try std.testing.expect(Rational.eql(sqrt_length_dim.L, Rational.init(1, 2)));

    const area = Quantity(Dimensions.Area).init(16.0);
    const sqrt_area = area.powRational(Rational.init(1, 2));
    try std.testing.expectApproxEqAbs(4.0, sqrt_area.value, 1e-9);
    try std.testing.expect(Dimension.eql(@TypeOf(sqrt_area).dim, Dimensions.Length));

    const length = Quantity(Dimensions.Length).init(9.0);
    const sqrt_length = length.powRational(Rational.init(1, 2));
    try std.testing.expectApproxEqAbs(3.0, sqrt_length.value, 1e-9);
    try std.testing.expect(Dimension.eql(@TypeOf(sqrt_length).dim, sqrt_length_dim));
}

test "unit powRational preserves exact dimensions and rejects affine units" {
    const sqrt_meter = _si.m.powRational(Rational.init(1, 2), "m^(1/2)");
    try std.testing.expect(Dimension.eql(sqrt_meter.dim, Dimension.mulByRational(Dimensions.Length, Rational.init(1, 2))));
    try std.testing.expectApproxEqAbs(1.0, sqrt_meter.scale, 1e-12);

    try std.testing.expectError(error.AffineUnitCombination, _imperial.F.powRationalChecked(Rational.init(1, 2), "F^(1/2)"));
}

test "temperature: abs + delta -> abs" {
    const TempQ = Quantity(Dimensions.Temperature);

    const t_abs = TempQ.init(10.0 + 273.15); // 10 °C absolute
    const dF_in_K = 20.0 * 5.0 / 9.0; // 20 °F delta
    const t_delta = TempQ.init(dF_in_K);

    const sum = t_abs.add(t_delta);
    try std.testing.expect(!sum.is_delta);
    try std.testing.expectApproxEqAbs(283.15 + dF_in_K, sum.value, 1e-9);
}

test "temperature: delta + abs -> abs" {
    const TempQ = Quantity(Dimensions.Temperature);

    const t_abs = TempQ.init(300.0);
    const t_delta = TempQ.init(10.0); // 10 °C delta = 10 K

    const sum = t_delta.add(t_abs);
    try std.testing.expect(!sum.is_delta);
    try std.testing.expectApproxEqAbs(310.0, sum.value, 1e-9);
}

test "temperature: delta + delta -> delta" {
    const TempQ = Quantity(Dimensions.Temperature);

    const d1 = TempQ{ .value = 10.0, .is_delta = true };
    const d2 = TempQ{ .value = 18.0 * 5.0 / 9.0, .is_delta = true };

    const dsum = d1.add(d2);
    try std.testing.expect(dsum.is_delta);
    try std.testing.expectApproxEqAbs(20.0, dsum.value, 1e-9);
}

test "temperature: abs - abs -> delta" {
    const TempQ = Quantity(Dimensions.Temperature);

    const a = TempQ.init(310.0);
    const b = TempQ.init(20.0 + 273.15);

    const diff = a.sub(b);
    try std.testing.expect(diff.is_delta);
    try std.testing.expectApproxEqAbs(16.85, diff.value, 1e-9);
}

test "temperature: abs - delta -> abs" {
    const TempQ = Quantity(Dimensions.Temperature);

    const a = TempQ.init(300.0);
    const d = TempQ{ .value = 20.0, .is_delta = true };

    const res = a.sub(d);
    try std.testing.expect(!res.is_delta);
    try std.testing.expectApproxEqAbs(280.0, res.value, 1e-9);
}

test "pressure unit helpers treat barg offsets as absolute-only" {
    try std.testing.expectApproxEqAbs(101325.0, _si.atm.toCanonicalValue(1.0, false), 1e-9);
    try std.testing.expectApproxEqAbs(101325.0, _si.barg.toCanonicalValue(0.0, false), 1e-9);
    try std.testing.expectApproxEqAbs(100000.0, _si.barg.toCanonicalValue(1.0, true), 1e-9);
    try std.testing.expectApproxEqAbs(1.01325, _si.bara.fromCanonicalValue(101325.0, false), 1e-9);
    try std.testing.expectApproxEqAbs(1.0, _si.barg.fromCanonicalValue(100000.0, true), 1e-9);
}

test "pressure quantity arithmetic mirrors absolute and delta rules" {
    const PressureQ = Quantity(Dimensions.Pressure);

    const abs_a = PressureQ.from(5.0, _si.bara);
    const abs_b = PressureQ.from(2.0, _si.bara);
    const two_barg = PressureQ.from(2.0, _si.barg);
    const one_bara = PressureQ.from(1.0, _si.bara);
    const one_barg = PressureQ.from(1.0, _si.barg);
    const delta = PressureQ{ .value = _si.bar.toCanonicalValue(3.0, true), .is_delta = true };

    const diff = abs_a.sub(abs_b);
    try std.testing.expect(diff.is_delta);
    try std.testing.expectApproxEqAbs(3.0e5, diff.value, 1e-9);
    try std.testing.expectApproxEqAbs(3.0, _si.bar.fromCanonicalValue(diff.value, diff.is_delta), 1e-9);
    try std.testing.expectApproxEqAbs(3.0, _si.bara.fromCanonicalValue(diff.value, diff.is_delta), 1e-9);
    try std.testing.expectApproxEqAbs(3.0, _si.barg.fromCanonicalValue(diff.value, diff.is_delta), 1e-9);

    const sum = abs_b.add(delta);
    try std.testing.expect(!sum.is_delta);
    try std.testing.expectApproxEqAbs(5.0e5, sum.value, 1e-9);

    const mixed_diff = two_barg.sub(one_bara);
    try std.testing.expect(mixed_diff.is_delta);
    try std.testing.expectApproxEqAbs(201325.0, mixed_diff.value, 1e-9);
    try std.testing.expectApproxEqAbs(2.01325, _si.bar.fromCanonicalValue(mixed_diff.value, mixed_diff.is_delta), 1e-9);

    const reverse_mixed_diff = abs_b.sub(one_barg);
    try std.testing.expect(reverse_mixed_diff.is_delta);
    try std.testing.expectApproxEqAbs(-1325.0, reverse_mixed_diff.value, 1e-9);
    try std.testing.expectApproxEqAbs(-0.01325, _si.bar.fromCanonicalValue(reverse_mixed_diff.value, reverse_mixed_diff.is_delta), 1e-9);
}

test "context-scoped constants do not leak across contexts" {
    var ctx_a = DimContext.init(std.testing.allocator);
    defer ctx_a.deinit();
    var ctx_b = DimContext.init(std.testing.allocator);
    defer ctx_b.deinit();

    var define_a = evaluateWithContext(&ctx_a, std.testing.allocator, "foo = (2 m)", null) orelse return error.TestUnexpectedResult;
    defer deinitLiteralValue(std.testing.allocator, &define_a);

    try std.testing.expect(ctx_a.getConstant("foo") != null);
    try std.testing.expect(ctx_b.getConstant("foo") == null);

    var res_a = evaluateWithContext(&ctx_a, std.testing.allocator, "1 foo as m", null) orelse return error.TestUnexpectedResult;
    defer deinitLiteralValue(std.testing.allocator, &res_a);

    try std.testing.expectEqual(@as(usize, 1), ctx_a.constantsCount());
    try std.testing.expectEqual(@as(usize, 0), ctx_b.constantsCount());

    const missing_b = evaluateWithContext(&ctx_b, std.testing.allocator, "1 foo as m", null);
    try std.testing.expect(missing_b == null);

    switch (res_a) {
        .display_quantity => |dq| try std.testing.expectApproxEqAbs(2.0, dq.value, 1e-9),
        else => return error.TestUnexpectedResult,
    }
}
