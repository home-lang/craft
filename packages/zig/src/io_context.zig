const std = @import("std");
const global_state = @import("global_state.zig");

/// Global Io context for the Craft framework.
/// Initialized once at program startup via init(), then accessible everywhere via get().
/// Thread-safe access is provided through global_state.
/// Initialize the global Io context. Must be called once at startup from main().
pub fn init(io: std.Io) void {
    global_state.instance.setIo(io);
}

/// Get the global Io context.
/// In test mode, creates a default Threaded Io if not explicitly initialized.
pub fn get() std.Io {
    return global_state.instance.getIo();
}

/// Get the current working directory handle.
pub fn cwd() std.Io.Dir {
    return std.Io.Dir.cwd();
}
