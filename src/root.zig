const std = @import("std");

pub const Dimension = @import("Dimension.zig").Dimension;
pub const Quantity = @import("quantity.zig").Quantity;
pub const DIM = @import("Dimension.zig").DIM;
pub const Unit = @import("Unit.zig").Unit;
pub const Alias = @import("Unit.zig").Alias;
pub const Prefix = @import("Unit.zig").Prefix;
pub const UnitRegistry = @import("Unit.zig").UnitRegistry;
// Re-export runtime types and helpers
pub const DisplayQuantity = @import("runtime.zig").DisplayQuantity;
pub const addDisplay = @import("runtime.zig").addDisplay;
pub const subDisplay = @import("runtime.zig").subDisplay;
pub const mulDisplay = @import("runtime.zig").mulDisplay;
pub const divDisplay = @import("runtime.zig").divDisplay;
pub const scaleDisplay = @import("runtime.zig").scaleDisplay;
pub const powDisplay = @import("runtime.zig").powDisplay;
pub const powDisplayFloat = @import("runtime.zig").powDisplayFloat;

// Re-export formatting API
pub const Format = @import("format.zig");

const _si = @import("registry/Si.zig");
const _imperial = @import("registry/Imperial.zig");
const _cgs = @import("registry/Cgs.zig");
const _industrial = @import("registry/Industrial.zig");

// Runtime constants registry (session-scoped)
var _consts_arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var _consts: std.StringHashMapUnmanaged(Unit) = .{};
var _const_names: std.ArrayListUnmanaged([]const u8) = .{}; // for stable iteration order

fn constsAllocator() std.mem.Allocator {
    return _consts_arena.allocator();
}

pub fn defineConstant(name_in: []const u8, dq: DisplayQuantity) !void {
    const a = constsAllocator();
    // Copy symbol into arena to ensure lifetime
    const name = try std.fmt.allocPrint(a, "{s}", .{name_in});

    // Build Unit: 1 <name> equals dq.value canonical in dimension dq.dim
    const u = Unit{
        .dim = dq.dim,
        .scale = dq.value,
        .offset = 0.0,
        .symbol = name,
    };

    const gpa = a; // same allocator
    // Insert or update
    const existing = _consts.get(name_in);
    if (existing == null) {
        try _consts.put(gpa, name, u);
        try _const_names.append(gpa, name);
    } else {
        // Update in-place by re-put on same key slice; ensure we find the stored key
        // Overwrite by removing and inserting with arena-copied name to keep symbol stable
        _ = _consts.remove(name_in);
        try _consts.put(gpa, name, u);
        // Keep names list as-is if already present; ensure it's present once
        var found: bool = false;
        for (_const_names.items) |n| {
            if (std.mem.eql(u8, n, name_in)) {
                found = true;
                break;
            }
        }
        if (!found) try _const_names.append(gpa, name);
    }
}

pub fn getConstant(symbol: []const u8) ?Unit {
    if (_consts.get(symbol)) |u| return u;
    return null;
}

pub fn clearConstant(name: []const u8) void {
    _ = _consts.remove(name);
    // Remove from names list
    var i: usize = 0;
    while (i < _const_names.items.len) : (i += 1) {
        if (std.mem.eql(u8, _const_names.items[i], name)) {
            _ = _const_names.orderedRemove(i);
            break;
        }
    }
}

pub fn clearAllConstants() void {
    _consts.clearRetainingCapacity();
    _const_names.clearRetainingCapacity();
    _ = _consts_arena.reset(.retain_capacity);
}

pub fn constantsCount() usize {
    return _const_names.items.len;
}

pub fn constantByIndex(index: usize) ?struct { name: []const u8, unit: Unit } {
    if (index >= _const_names.items.len) return null;
    const n = _const_names.items[index];
    const u = _consts.get(n) orelse return null;
    return .{ .name = n, .unit = u };
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
    const LengthQ = Quantity(DIM.Length);
    const TimeQ = Quantity(DIM.Time);
    const SpeedQ = Quantity(DIM.Velocity);

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
    const MassQ = Quantity(DIM.Mass);
    const AccelQ = Quantity(DIM.Acceleration);
    const ForceQ = Quantity(DIM.Force);

    const m = MassQ.init(2.0); // 2 kg
    const a = AccelQ.init(9.81); // 9.81 m/s^2
    const f = m.mul(a);

    comptime {
        const ResultQ = @TypeOf(f);
        _ = @as(ForceQ, ResultQ{ .value = 0.0, .is_delta = false });
    }

    try std.testing.expectApproxEqAbs(19.62, f.value, 1e-9);
}

test "temperature: abs + delta -> abs" {
    const TempQ = Quantity(DIM.Temperature);

    const t_abs = TempQ.init(10.0 + 273.15); // 10 °C absolute
    const dF_in_K = 20.0 * 5.0 / 9.0; // 20 °F delta
    const t_delta = TempQ.init(dF_in_K);

    const sum = t_abs.add(t_delta);
    try std.testing.expect(!sum.is_delta);
    try std.testing.expectApproxEqAbs(283.15 + dF_in_K, sum.value, 1e-9);
}

test "temperature: delta + abs -> abs" {
    const TempQ = Quantity(DIM.Temperature);

    const t_abs = TempQ.init(300.0);
    const t_delta = TempQ.init(10.0); // 10 °C delta = 10 K

    const sum = t_delta.add(t_abs);
    try std.testing.expect(!sum.is_delta);
    try std.testing.expectApproxEqAbs(310.0, sum.value, 1e-9);
}

test "temperature: delta + delta -> delta" {
    const TempQ = Quantity(DIM.Temperature);

    const d1 = TempQ{ .value = 10.0, .is_delta = true };
    const d2 = TempQ{ .value = 18.0 * 5.0 / 9.0, .is_delta = true };

    const dsum = d1.add(d2);
    try std.testing.expect(dsum.is_delta);
    try std.testing.expectApproxEqAbs(20.0, dsum.value, 1e-9);
}

test "temperature: abs - abs -> delta" {
    const TempQ = Quantity(DIM.Temperature);

    const a = TempQ.init(310.0);
    const b = TempQ.init(20.0 + 273.15);

    const diff = a.sub(b);
    try std.testing.expect(diff.is_delta);
    try std.testing.expectApproxEqAbs(16.85, diff.value, 1e-9);
}

test "temperature: abs - delta -> abs" {
    const TempQ = Quantity(DIM.Temperature);

    const a = TempQ.init(300.0);
    const d = TempQ{ .value = 20.0, .is_delta = true };

    const res = a.sub(d);
    try std.testing.expect(!res.is_delta);
    try std.testing.expectApproxEqAbs(280.0, res.value, 1e-9);
}
