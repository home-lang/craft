//! Secure UUIDs come from each platform's UUID implementation. Recorders and
//! the public Crypto service share these primitives; no clock or JS PRNG.
const std = @import("std");
const builtin = @import("builtin");
const Jni = @import("jni.zig").Jni;
const objc = @import("objc_runtime.zig").objc;

pub fn darwin(allocator: std.mem.Allocator) ![]u8 {
    if (!builtin.target.os.tag.isDarwin()) return error.UnsupportedPlatform;
    const cls = objc.objc_getClass("NSUUID") orelse return error.ClassNotFound;
    const create = objc.sel_registerName("UUID") orelse return error.SelectorNotFound;
    const uuid = objc.msgSendId(cls, create) orelse return error.NativeCallFailed;
    const describe = objc.sel_registerName("UUIDString") orelse return error.SelectorNotFound;
    const text = objc.msgSendId(uuid, describe) orelse return error.NativeCallFailed;
    const bytes = objc.getNSStringUTF8(text) orelse return error.NativeCallFailed;
    return std.ascii.allocLowerString(allocator, std.mem.span(bytes));
}

pub fn android(j: Jni, allocator: std.mem.Allocator) ![]u8 {
    try j.pushLocalFrame(8);
    defer _ = j.popLocalFrame(null);
    const cls = try j.findClass("java/util/UUID");
    const uuid = try j.callStaticObjectMethodA(cls, try j.staticMethodId(cls, "randomUUID", "()Ljava/util/UUID;"), &.{});
    const text = try j.callObjectMethod(uuid, try j.methodId(cls, "toString", "()Ljava/lang/String;"));
    return j.stringToUtf8(allocator, text);
}

test "Darwin UUIDs use Foundation and preserve RFC version and variant" {
    if (!builtin.target.os.tag.isDarwin()) return error.SkipZigTest;
    const a = std.testing.allocator;
    const first = try darwin(a);
    defer a.free(first);
    const second = try darwin(a);
    defer a.free(second);
    try std.testing.expectEqual(@as(usize, 36), first.len);
    try std.testing.expect(first[14] == '4');
    try std.testing.expect(std.mem.indexOfScalar(u8, "89ab", first[19]) != null);
    try std.testing.expect(!std.mem.eql(u8, first, second));
}
