//! A scoped, user-requested activity that permits normal system/display sleep.
const builtin = @import("builtin");
const objc = @import("objc_runtime.zig").objc;

pub fn begin(reason: [:0]const u8) objc.id {
    if (comptime builtin.os.tag != .macos) return null;
    const macos = @import("macos.zig");
    const process = macos.msgSend0(macos.getClass("NSProcessInfo"), "processInfo");
    // NSActivityUserInitiatedAllowingIdleSystemSleep, Foundation/NSProcessInfo.h.
    const options: u64 = 0x00FFFFFF & ~@as(u64, 1 << 20);
    const token = macos.msgSend2(process, "beginActivityWithOptions:reason:", options, macos.createNSString(reason));
    if (token != null) _ = macos.msgSend0(token, "retain");
    return token;
}

pub fn end(token: objc.id) void {
    if (comptime builtin.os.tag != .macos) return;
    if (token == null) return;
    const macos = @import("macos.zig");
    const process = macos.msgSend0(macos.getClass("NSProcessInfo"), "processInfo");
    _ = macos.msgSend1(process, "endActivity:", token);
    _ = macos.msgSend0(token, "release");
}
