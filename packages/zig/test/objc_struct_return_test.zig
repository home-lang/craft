const std = @import("std");
const objc = @import("objc_runtime").objc;

extern fn craftStructReturnFixtureCreate() objc.id;

fn fixture() !objc.id {
    return craftStructReturnFixtureCreate() orelse error.FixtureUnavailable;
}

fn release(object: objc.id) void {
    objc.msgSend(object, objc.sel_registerName("release"));
}

test "small native structure return preserves floating-point fields" {
    const object = try fixture();
    defer release(object);
    const point = objc.msgSendStret(objc.CGPoint, object, objc.sel_registerName("smallPoint"));
    try std.testing.expectEqual(@as(f64, -17.5), point.x);
    try std.testing.expectEqual(@as(f64, 0.25), point.y);
}

test "native rectangle return preserves origin and size" {
    const object = try fixture();
    defer release(object);
    const rect = objc.msgSendStret(objc.CGRect, object, objc.sel_registerName("largeRect"));
    try std.testing.expectEqual(@as(f64, -17.5), rect.origin.x);
    try std.testing.expectEqual(@as(f64, 0.25), rect.origin.y);
    try std.testing.expectEqual(@as(f64, 200.0), rect.size.width);
    try std.testing.expectEqual(@as(f64, 64.5), rect.size.height);
}

test "native homogeneous floating aggregate return preserves all three doubles" {
    const Vector3 = extern struct { x: f64, y: f64, z: f64 };
    const object = try fixture();
    defer release(object);
    const vector = objc.msgSendStret(Vector3, object, objc.sel_registerName("acceleration"));
    try std.testing.expectEqual(@as(f64, -17.5), vector.x);
    try std.testing.expectEqual(@as(f64, 0.25), vector.y);
    try std.testing.expectEqual(@as(f64, 64.5), vector.z);
}

test "large native memory return preserves all nine matrix elements" {
    const Matrix3 = extern struct { values: [9]f64 };
    const object = try fixture();
    defer release(object);
    const matrix = objc.msgSendStret(Matrix3, object, objc.sel_registerName("largeMatrix"));
    try std.testing.expectEqualSlices(f64, &.{ 1.25, -2.5, 3.75, 4.5, -5.25, 6.0, 7.5, -8.75, 9.25 }, &matrix.values);
}
