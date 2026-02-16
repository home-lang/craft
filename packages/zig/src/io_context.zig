const std = @import("std");

/// Global Io context for the Craft framework.
/// Initialized once at program startup via init(), then accessible everywhere via get().
var global_io: ?std.Io = null;

/// Initialize the global Io context. Must be called once at startup from main().
pub fn init(io: std.Io) void {
    global_io = io;
}

/// Get the global Io context. Panics if not initialized.
pub fn get() std.Io {
    return global_io.?;
}

/// Get the current working directory handle.
pub fn cwd() std.Io.Dir {
    return std.Io.Dir.cwd();
}
