const std = @import("std");

/// Global Io context for the Craft framework.
/// Initialized once at program startup via init(), then accessible everywhere via get().
/// In test mode, a default Threaded Io is created lazily.
var global_io: ?std.Io = null;
var default_threaded: ?std.Io.Threaded = null;

/// Initialize the global Io context. Must be called once at startup from main().
pub fn init(io: std.Io) void {
    global_io = io;
}

/// Get the global Io context.
/// In test mode, creates a default Threaded Io if not explicitly initialized.
pub fn get() std.Io {
    if (global_io) |io| return io;

    // Lazy init for test mode or when not explicitly initialized
    default_threaded = std.Io.Threaded.init(std.heap.c_allocator, .{ .environ = .empty });
    global_io = default_threaded.?.io();
    return global_io.?;
}

/// Get the current working directory handle.
pub fn cwd() std.Io.Dir {
    return std.Io.Dir.cwd();
}
