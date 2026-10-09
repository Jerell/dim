const std = @import("std");
const dim = @import("dim");

const ContainerKmH = dim.Units.si.km.div(dim.Units.si.h, "km/h") catch unreachable;

test "documented comptime unit namespace and typed arithmetic compile" {
    const Si = dim.Units.si;
    const Length = dim.Quantity(dim.Dimensions.Length);
    const Time = dim.Quantity(dim.Dimensions.Time);

    const distance = Length.from(2.0, Si.km);
    const elapsed = Time.from(1.0, Si.h);
    const speed = distance.div(elapsed);

    try std.testing.expectApproxEqAbs(2.0 / 3.6, speed.value, 1e-12);
    try std.testing.expectApproxEqAbs(6000.0, distance.scale(3.0).unscale(1.0).value, 1e-12);
}

test "README formatting and evaluation surface compiles" {
    const Si = dim.Units.si;
    const Length = dim.Quantity(dim.Dimensions.Length);
    const Time = dim.Quantity(dim.Dimensions.Time);
    const distance = Length.from(100.0, Si.km);
    const elapsed = Time.from(1.0, Si.h);
    const speed = distance.div(elapsed);
    const kmh = try Si.km.div(Si.h, "km/h");
    _ = ContainerKmH;

    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try speed.with(dim.Registries.si, .scientific).format(&output.writer);
    try speed.asUnit(kmh, .none).format(&output.writer);

    var result = try dim.evaluate(std.testing.allocator, "100 km/h as m/s", null);
    defer dim.deinitLiteralValue(std.testing.allocator, &result);

    try std.testing.expectApproxEqAbs(100.0, speed.asUnit(kmh, .none).q.value / kmh.scale, 1e-9);
    try std.testing.expectError(
        error.AffineUnitCombination,
        Si.C.div(Si.h, "C/h"),
    );
}

test "a temperature difference multiplies and scalar operations preserve state" {
    const Temp = dim.Quantity(dim.Dimensions.Temperature);
    const Length = dim.Quantity(dim.Dimensions.Length);
    const delta = (Temp{ .value = 10.0, .is_delta = true }).scale(2.0);

    try std.testing.expect(delta.is_delta);
    const product = delta.mul(Length.init(1.0));
    try std.testing.expectApproxEqAbs(20.0, product.value, 1e-12);
    try std.testing.expect(!product.is_delta);
}

test "display helpers return independently owned unit strings" {
    const allocator = std.testing.allocator;
    const length = dim.DisplayQuantity{
        .value = 2.0,
        .dim = dim.Dimensions.Length,
        .unit = "m",
    };

    var scaled = try dim.scaleDisplay(allocator, length, 3.0);
    defer scaled.deinit(allocator);
    try std.testing.expectEqualStrings("m", scaled.unit);
    try std.testing.expectApproxEqAbs(6.0, scaled.value, 1e-12);

    var sum = try dim.addDisplay(allocator, length, length);
    defer sum.deinit(allocator);
    try std.testing.expectApproxEqAbs(4.0, sum.value, 1e-12);
}

test "expression display helpers multiply a temperature difference and refuse a point on an offset scale" {
    const delta = dim.DisplayQuantity{
        .value = 1.0,
        .dim = dim.Dimensions.Temperature,
        .unit = "C",
        .is_delta = true,
    };
    const length = dim.DisplayQuantity{
        .value = 2.0,
        .dim = dim.Dimensions.Length,
        .unit = "m",
    };

    var product = try dim.mulDisplay(std.testing.allocator, delta, length);
    defer product.deinit(std.testing.allocator);
    try std.testing.expectApproxEqAbs(2.0, product.value, 1e-12);

    const point = dim.DisplayQuantity{
        .value = 283.15,
        .dim = dim.Dimensions.Temperature,
        .unit = "C",
    };
    try std.testing.expectError(
        error.OffsetUnitArithmetic,
        dim.mulDisplay(std.testing.allocator, point, length),
    );
    try std.testing.expectError(
        error.OffsetUnitArithmetic,
        dim.divDisplay(std.testing.allocator, length, point),
    );
    try std.testing.expectError(
        error.OffsetUnitArithmetic,
        dim.scaleDisplay(std.testing.allocator, point, 2.0),
    );
}

test "explicit contexts isolate constants without an active global context" {
    var first = dim.DimContext.init(std.testing.allocator);
    defer first.deinit();
    var second = dim.DimContext.init(std.testing.allocator);
    defer second.deinit();

    var defined = try dim.evaluateWithContext(&first, std.testing.allocator, "x = (2 m)", null);
    defer dim.deinitLiteralValue(std.testing.allocator, &defined);

    var resolved = try dim.evaluateWithContext(&first, std.testing.allocator, "1 x as m", null);
    defer dim.deinitLiteralValue(std.testing.allocator, &resolved);
    try std.testing.expectError(
        error.UndefinedVariable,
        dim.evaluateWithContext(&second, std.testing.allocator, "1 x as m", null),
    );
}
