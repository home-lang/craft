const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

// libc dirent — see comment in `list()`. Layout is platform-specific
// but the d_name field is at a stable offset on macOS and Linux for
// our usage pattern (read filename, ignore the rest).
const Dirent = extern struct {
    d_ino: u64,
    d_seekoff: u64,
    d_reclen: u16,
    d_namlen: u16,
    d_type: u8,
    d_name: [1024]u8,
};

extern "c" fn opendir(name: [*:0]const u8) ?*anyopaque;
extern "c" fn readdir(dirp: ?*anyopaque) ?*Dirent;
extern "c" fn closedir(dirp: ?*anyopaque) c_int;

/// Serial-port I/O for IoT / Arduino / printer apps.
///
/// macOS exposes serial ports under `/dev/cu.*` (call-out, app-side)
/// and `/dev/tty.*` (terminal, line-side); we list both so apps can
/// surface the ones they care about. Open + read + write go through
/// regular libc `open` / `read` / `write` plus a `termios` baud-rate
/// configuration step.
///
/// What's wired today:
///   - `list()`         — enumerate `/dev/cu.*` + `/dev/tty.*` entries
///   - `open(path, baud)` — placeholder; real implementation needs
///                          termios + non-blocking flag + read poll
///                          thread, similar to local-server's listener
///   - `write(id, data)` / `close(id)` / `read` event — same.
///
/// The list call works today and is what UIs need to show "select a
/// device." Open/write/read are stubs awaiting the termios + thread
/// scaffolding.
pub const SerialBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, _: []const u8) !void {
        if (std.mem.eql(u8, action, "list")) try self.list()
        else if (std.mem.eql(u8, action, "open") or
                 std.mem.eql(u8, action, "write") or
                 std.mem.eql(u8, action, "close"))
        {
            bridge_error.sendResultToJS(self.allocator, action, "{\"ok\":false,\"reason\":\"open/read/write wiring pending\"}");
        } else return BridgeError.UnknownAction;
    }

    fn list(self: *Self) !void {
        if (builtin.os.tag != .macos and builtin.os.tag != .linux) {
            bridge_error.sendResultToJS(self.allocator, "list", "{\"ports\":[]}");
            return;
        }

        // Walk /dev for entries matching the platform's serial-port
        // naming. We use libc opendir/readdir directly because the
        // zig-0.17 std.fs surface for directory iteration shifted in
        // a way that's not stable across nightly releases yet.
        const d = opendir("/dev");
        if (d == null) {
            bridge_error.sendResultToJS(self.allocator, "list", "{\"ports\":[]}");
            return;
        }
        defer _ = closedir(d);

        var buf: std.ArrayListUnmanaged(u8) = .empty;
        defer buf.deinit(self.allocator);
        try buf.appendSlice(self.allocator, "{\"ports\":[");

        var first = true;
        while (true) {
            const entry = readdir(d) orelse break;
            const name_z = std.mem.span(@as([*:0]const u8, @ptrCast(&entry.d_name)));
            const matches = if (builtin.os.tag == .macos)
                std.mem.startsWith(u8, name_z, "cu.") or std.mem.startsWith(u8, name_z, "tty.")
            else
                std.mem.startsWith(u8, name_z, "ttyUSB") or
                    std.mem.startsWith(u8, name_z, "ttyACM") or
                    std.mem.startsWith(u8, name_z, "ttyS");
            if (!matches) continue;

            if (!first) try buf.append(self.allocator, ',');
            first = false;
            try buf.appendSlice(self.allocator, "{\"path\":\"/dev/");
            for (name_z) |b| {
                switch (b) {
                    '"' => try buf.appendSlice(self.allocator, "\\\""),
                    '\\' => try buf.appendSlice(self.allocator, "\\\\"),
                    else => try buf.append(self.allocator, b),
                }
            }
            try buf.appendSlice(self.allocator, "\"}");
        }
        try buf.appendSlice(self.allocator, "]}");

        const owned = try buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(owned);
        bridge_error.sendResultToJS(self.allocator, "list", owned);
    }
};
