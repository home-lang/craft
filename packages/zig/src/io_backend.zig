//! Craft's platform policy for the standard threaded I/O backend.
//! Sandboxed Apple apps cannot replace their running process. Apply that
//! restriction when constructing the vtable, before desktop process code is
//! instantiated; file, network and concurrency operations remain unchanged.
const std = @import("std");
const builtin = @import("builtin");

pub fn threadedIo(threaded: *std.Io.Threaded) std.Io {
    return switch (builtin.os.tag) {
        .ios, .tvos, .visionos, .watchos => sandboxedIo(threaded),
        else => threaded.io(),
    };
}

fn sandboxedIo(threaded: *std.Io.Threaded) std.Io {
    const vtable = comptime blk: {
        var table = std.Io.Threaded.io(undefined).vtable.*;
        table.processReplace = processReplaceUnsupported;
        break :blk table;
    };
    return .{ .userdata = threaded, .vtable = &vtable };
}

fn processReplaceUnsupported(_: ?*anyopaque, _: std.process.ReplaceOptions) std.process.ReplaceError {
    return error.OperationUnsupported;
}

test "sandboxed Io refuses process replacement without accessing backend state" {
    try std.testing.expectEqual(error.OperationUnsupported, processReplaceUnsupported(null, .{ .argv = &.{"/never-executed"} }));
    var threaded: std.Io.Threaded = undefined;
    const io = sandboxedIo(&threaded);
    try std.testing.expectEqual(error.OperationUnsupported, std.process.replace(io, .{ .argv = &.{"/never-executed"} }));
    try std.testing.expectEqual(@as(?*anyopaque, &threaded), io.userdata);
}

test "sandboxed Io retains standard file network and concurrency operations" {
    var threaded: std.Io.Threaded = undefined;
    const standard = threaded.io();
    const sandboxed = sandboxedIo(&threaded);
    inline for (.{ "fileReadPositional", "fileWritePositional", "dirOpenDir", "netConnectIp", "async", "sleep" }) |name| {
        try std.testing.expectEqual(@field(standard.vtable, name), @field(sandboxed.vtable, name));
    }
    if (comptime builtin.os.tag != .ios and builtin.os.tag != .tvos and builtin.os.tag != .visionos and builtin.os.tag != .watchos) {
        try std.testing.expectEqual(standard.vtable, threadedIo(&threaded).vtable);
    }
}
