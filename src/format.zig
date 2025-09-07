const std = @import("std");
const Unit = @import("Unit.zig").Unit;
const UnitRegistry = @import("Unit.zig").UnitRegistry;
const Dimension = @import("Dimension.zig").Dimension;
const SiPrefixes = @import("registry/Si.zig").Registry.prefixes;

pub const FormatMode = enum { auto, none, scientific, engineering };

/// Format a value + dimension using a registry
pub fn formatQuantity(
    writer: *std.Io.Writer,
    value: f64,
    dim: Dimension,
    is_delta: bool,
    reg: UnitRegistry,
    mode: FormatMode,
) !void {
    // 1. Find a base unit in the registry that matches this dimension
    var base: ?Unit = null;
    for (reg.units) |u| {
        if (Dimension.eql(u.dim, dim)) {
            base = u;
            break;
        }
    }
    if (base == null) {
        return writer.print("{d} [{any}]", .{ value, dim });
    }

    const u = base.?;
    const val = u.fromCanonical(value);

    // Prefix for deltas
    const delta_prefix: []const u8 = if (is_delta) "Δ" else "";

    // 2. Format according to mode
    switch (mode) {
        .none => try writer.print("{s}{d:.3} {s}", .{ delta_prefix, val, u.symbol }),
        .scientific => try writer.print("{s}{e:.3} {s}", .{ delta_prefix, val, u.symbol }),
        .engineering => {
            if (val == 0.0) {
                try writer.print("{s}0.000 {s}", .{ delta_prefix, u.symbol });
            } else {
                const exp_f64 = @floor(std.math.log10(@abs(val)));
                const exp = @as(i32, @intFromFloat(exp_f64));
                const eng_exp = exp - @mod(exp, 3);
                const scaled = val / std.math.pow(f64, 10.0, @floatFromInt(eng_exp));
                try writer.print("{s}{d:.3}e{d} {s}", .{ delta_prefix, scaled, eng_exp, u.symbol });
            }
        },
        .auto => {
            if (val == 0.0) {
                try writer.print("{s}0.000 {s}", .{ delta_prefix, u.symbol });
            } else {
                var scaled_val = val;
                var matched = false;
                for (reg.prefixes) |p| {
                    const v = val / p.factor;
                    if (v >= 1.0 and v < 1000.0) {
                        scaled_val = v;
                        try writer.print("{s}{d:.3} {s}{s}", .{ delta_prefix, scaled_val, p.symbol, u.symbol });
                        matched = true;
                        break;
                    }
                }
                if (!matched) {
                    try writer.print("{s}{d:.3} {s}", .{ delta_prefix, val, u.symbol });
                }
            }
        },
    }
}

/// Format a quantity using a specific display unit (not a registry).
pub fn formatQuantityAsUnit(
    writer: *std.Io.Writer,
    q: anytype, // Quantity(Dim) or DisplayQuantity
    display_unit: Unit,
    mode: FormatMode,
) !void {
    // Extract canonical value
    const val = display_unit.fromCanonical(q.value);

    const delta_prefix: []const u8 = if (q.is_delta) "Δ" else "";

    switch (mode) {
        .none => try writer.print("{s}{d:.3} {s}", .{ delta_prefix, val, display_unit.symbol }),
        .scientific => try writer.print("{s}{e:.3} {s}", .{ delta_prefix, val, display_unit.symbol }),
        .engineering => {
            if (val == 0.0) {
                try writer.print("{s}0.000 {s}", .{ delta_prefix, display_unit.symbol });
            } else {
                const exp_f64 = @floor(std.math.log10(@abs(val)));
                const exp = @as(i32, @intFromFloat(exp_f64));
                const eng_exp = exp - @mod(exp, 3);
                const scaled = val / std.math.pow(f64, 10.0, @floatFromInt(eng_exp));
                try writer.print("{s}{d:.3}e{d} {s}", .{ delta_prefix, scaled, eng_exp, display_unit.symbol });
            }
        },
        .auto => try writer.print("{s}{d:.3} {s}", .{ delta_prefix, val, display_unit.symbol }),
    }
}

pub fn normalizeUnitString(
    allocator: std.mem.Allocator,
    dim: Dimension,
    fallback: []const u8,
    reg: UnitRegistry,
) ![]u8 {
    // 1) Prefer aliases that match the full dimension
    for (reg.aliases) |alias| {
        if (Dimension.eql(alias.target.dim, dim)) {
            return try std.fmt.allocPrint(allocator, "{s}", .{alias.symbol});
        }
    }

    // 2) Prefer a registry unit that matches the full dimension (e.g., m/s, m/s², N)
    // Prefer canonical symbols (scale == 1.0). If none, still fall back to the first match.
    var any_match: ?[]const u8 = null;
    for (reg.units) |u| {
        if (Dimension.eql(u.dim, dim)) {
            if (u.scale == 1.0) {
                return try std.fmt.allocPrint(allocator, "{s}", .{u.symbol});
            }
            if (any_match == null) any_match = u.symbol;
        }
    }
    if (any_match) |sym| {
        return try std.fmt.allocPrint(allocator, "{s}", .{sym});
    }

    // 3) Build a canonical SI expression from the dimension, with a simple greedy
    //    factoring of one derived unit (if it reduces complexity), then base units.
    var rem = dim;

    // Detect base units from registry by looking for scale==1.0 and basis dimensions.
    var baseL: ?[]const u8 = null;
    var baseM: ?[]const u8 = null;
    var baseT: ?[]const u8 = null;
    var baseI: ?[]const u8 = null;
    var baseTh: ?[]const u8 = null;
    var baseN: ?[]const u8 = null;
    var baseJ: ?[]const u8 = null;

    const isBasis = struct {
        fn call(d: Dimension, l: i32, m: i32, t: i32, i: i32, th: i32, n: i32, j: i32) bool {
            return d.L == l and d.M == m and d.T == t and d.I == i and d.Th == th and d.N == n and d.J == j;
        }
    }.call;

    for (reg.units) |u| {
        if (u.scale != 1.0) continue;
        const d = u.dim;
        if (baseL == null and isBasis(d, 1, 0, 0, 0, 0, 0, 0)) baseL = u.symbol;
        if (baseM == null and isBasis(d, 0, 1, 0, 0, 0, 0, 0)) baseM = u.symbol;
        if (baseT == null and isBasis(d, 0, 0, 1, 0, 0, 0, 0)) baseT = u.symbol;
        if (baseI == null and isBasis(d, 0, 0, 0, 1, 0, 0, 0)) baseI = u.symbol;
        if (baseTh == null and isBasis(d, 0, 0, 0, 0, 1, 0, 0)) baseTh = u.symbol;
        if (baseN == null and isBasis(d, 0, 0, 0, 0, 0, 1, 0)) baseN = u.symbol;
        if (baseJ == null and isBasis(d, 0, 0, 0, 0, 0, 0, 1)) baseJ = u.symbol;
    }

    // Try picking one non-base derived unit that reduces complexity (N, J, W, Pa, m/s, m/s², etc.)
    const absI32 = struct {
        fn call(x: i32) i32 {
            return if (x >= 0) x else -x;
        }
    }.call;
    const complexitySum = struct {
        fn call(d: Dimension) i32 {
            return absI32(d.L) + absI32(d.M) + absI32(d.T) + absI32(d.I) + absI32(d.Th) + absI32(d.N) + absI32(d.J);
        }
    }.call;

    var picked: ?[]const u8 = null;
    var best_reduction: i32 = 0;
    var best_priority: i32 = 1000;
    const preferred_symbols = [_][]const u8{ "N", "J", "W", "Pa", "m/s²", "m/s", "m²", "m³" };
    const getPriority = struct {
        fn call(sym: []const u8) i32 {
            var i: usize = 0;
            while (i < preferred_symbols.len) : (i += 1) {
                if (std.mem.eql(u8, sym, preferred_symbols[i])) return @as(i32, @intCast(i));
            }
            return 999;
        }
    }.call;

    const curr_c = complexitySum(rem);
    for (reg.units) |u| {
        if (u.scale != 1.0) continue; // avoid picking cm, km, etc.
        // Skip pure base units (basis vectors)
        const d = u.dim;
        const is_base = (d.L == 1 and d.M == 0 and d.T == 0 and d.I == 0 and d.Th == 0 and d.N == 0 and d.J == 0) or
            (d.L == 0 and d.M == 1 and d.T == 0 and d.I == 0 and d.Th == 0 and d.N == 0 and d.J == 0) or
            (d.L == 0 and d.M == 0 and d.T == 1 and d.I == 0 and d.Th == 0 and d.N == 0 and d.J == 0) or
            (d.L == 0 and d.M == 0 and d.T == 0 and d.I == 1 and d.Th == 0 and d.N == 0 and d.J == 0) or
            (d.L == 0 and d.M == 0 and d.T == 0 and d.I == 0 and d.Th == 1 and d.N == 0 and d.J == 0) or
            (d.L == 0 and d.M == 0 and d.T == 0 and d.I == 0 and d.Th == 0 and d.N == 1 and d.J == 0) or
            (d.L == 0 and d.M == 0 and d.T == 0 and d.I == 0 and d.Th == 0 and d.N == 0 and d.J == 1);
        if (is_base) continue;

        const d_after = Dimension.sub(rem, d);
        const reduction = curr_c - complexitySum(d_after);
        if (reduction <= 0) continue;

        const pr = getPriority(u.symbol);
        if (pr < best_priority or (pr == best_priority and reduction > best_reduction)) {
            best_priority = pr;
            best_reduction = reduction;
            picked = u.symbol;
        }
    }

    // If we picked a derived unit, subtract its dimension from the remainder now
    if (picked) |sym_pick| {
        for (reg.units) |u| {
            if (u.scale == 1.0 and std.mem.eql(u8, u.symbol, sym_pick)) {
                rem = Dimension.sub(rem, u.dim);
                break;
            }
        }
    }

    // Compose result
    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);
    var w = buf.writer(allocator);

    var wrote_any = false;
    if (picked) |sym| {
        try w.print("{s}", .{sym});
        wrote_any = true;
    }

    // Emit numerator base units
    if (rem.M > 0) {
        if (wrote_any) try w.writeAll("*");
        try w.writeAll(baseM orelse "kg");
        if (rem.M != 1) try w.print("^{d}", .{rem.M});
        wrote_any = true;
    }
    if (rem.L > 0) {
        if (wrote_any) try w.writeAll("*");
        try w.writeAll(baseL orelse "m");
        if (rem.L != 1) try w.print("^{d}", .{rem.L});
        wrote_any = true;
    }
    if (rem.T > 0) {
        if (wrote_any) try w.writeAll("*");
        try w.writeAll(baseT orelse "s");
        if (rem.T != 1) try w.print("^{d}", .{rem.T});
        wrote_any = true;
    }
    if (rem.I > 0) {
        if (wrote_any) try w.writeAll("*");
        try w.writeAll(baseI orelse "A");
        if (rem.I != 1) try w.print("^{d}", .{rem.I});
        wrote_any = true;
    }
    if (rem.Th > 0) {
        if (wrote_any) try w.writeAll("*");
        try w.writeAll(baseTh orelse "K");
        if (rem.Th != 1) try w.print("^{d}", .{rem.Th});
        wrote_any = true;
    }
    if (rem.N > 0) {
        if (wrote_any) try w.writeAll("*");
        try w.writeAll(baseN orelse "mol");
        if (rem.N != 1) try w.print("^{d}", .{rem.N});
        wrote_any = true;
    }
    if (rem.J > 0) {
        if (wrote_any) try w.writeAll("*");
        try w.writeAll(baseJ orelse "cd");
        if (rem.J != 1) try w.print("^{d}", .{rem.J});
        wrote_any = true;
    }

    // Emit denominator base units
    const has_den = (rem.M < 0) or (rem.L < 0) or (rem.T < 0) or (rem.I < 0) or (rem.Th < 0) or (rem.N < 0) or (rem.J < 0);
    if (has_den) {
        if (!wrote_any) {
            try w.writeAll("1");
            wrote_any = true;
        }
        try w.writeAll("/");
        var need_sep = false;
        if (rem.M < 0) {
            if (need_sep) try w.writeAll("*");
            try w.writeAll(baseM orelse "kg");
            const p = -rem.M;
            if (p != 1) try w.print("^{d}", .{p});
            need_sep = true;
        }
        if (rem.L < 0) {
            if (need_sep) try w.writeAll("*");
            try w.writeAll(baseL orelse "m");
            const p = -rem.L;
            if (p != 1) try w.print("^{d}", .{p});
            need_sep = true;
        }
        if (rem.T < 0) {
            if (need_sep) try w.writeAll("*");
            try w.writeAll(baseT orelse "s");
            const p = -rem.T;
            if (p != 1) try w.print("^{d}", .{p});
            need_sep = true;
        }
        if (rem.I < 0) {
            if (need_sep) try w.writeAll("*");
            try w.writeAll(baseI orelse "A");
            const p = -rem.I;
            if (p != 1) try w.print("^{d}", .{p});
            need_sep = true;
        }
        if (rem.Th < 0) {
            if (need_sep) try w.writeAll("*");
            try w.writeAll(baseTh orelse "K");
            const p = -rem.Th;
            if (p != 1) try w.print("^{d}", .{p});
            need_sep = true;
        }
        if (rem.N < 0) {
            if (need_sep) try w.writeAll("*");
            try w.writeAll(baseN orelse "mol");
            const p = -rem.N;
            if (p != 1) try w.print("^{d}", .{p});
            need_sep = true;
        }
        if (rem.J < 0) {
            if (need_sep) try w.writeAll("*");
            try w.writeAll(baseJ orelse "cd");
            const p = -rem.J;
            if (p != 1) try w.print("^{d}", .{p});
            need_sep = true;
        }
    }

    if (!wrote_any) {
        // Dimensionless
        return try std.fmt.allocPrint(allocator, "{s}", .{fallback});
    }

    return buf.toOwnedSlice(allocator);
}
