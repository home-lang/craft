const std = @import("std");
const io_context = @import("io_context.zig");

pub const LogLevel = enum {
    Debug,
    Info,
    Warning,
    Error,
    Fatal,

    pub fn toString(self: LogLevel) []const u8 {
        return switch (self) {
            .Debug => "DEBUG",
            .Info => "INFO",
            .Warning => "WARN",
            .Error => "ERROR",
            .Fatal => "FATAL",
        };
    }

    pub fn color(self: LogLevel) []const u8 {
        return switch (self) {
            .Debug => "\x1B[36m", // Cyan
            .Info => "\x1B[32m", // Green
            .Warning => "\x1B[33m", // Yellow
            .Error => "\x1B[31m", // Red
            .Fatal => "\x1B[35m", // Magenta
        };
    }
};

pub const LogConfig = struct {
    min_level: LogLevel = .Info,
    enable_colors: bool = true,
    enable_timestamps: bool = true,
    output_file: ?[]const u8 = null,
    json_output: bool = false,
    filter_pattern: ?[]const u8 = null,
};

var current_config: LogConfig = .{};
var log_file: ?std.Io.File = null;

pub fn init(config: LogConfig) !void {
    // Close any previously opened log file. Previously, calling `init` twice
    // would overwrite `log_file` and silently leak the old file handle.
    if (log_file) |f| {
        f.close(io_context.get());
        log_file = null;
    }

    current_config = config;

    if (config.output_file) |path| {
        log_file = try std.Io.Dir.cwd().createFile(io_context.get(), path, .{
            .truncate = false,
            .read = true,
        });
    }
}

pub fn deinit() void {
    if (log_file) |file| {
        file.close(io_context.get());
        log_file = null;
    }
}

pub fn setLevel(level: LogLevel) void {
    current_config.min_level = level;
}

pub fn getLevel() LogLevel {
    return current_config.min_level;
}

pub fn shouldLog(level: LogLevel) bool {
    return @intFromEnum(level) >= @intFromEnum(current_config.min_level);
}

pub fn log(
    comptime level: LogLevel,
    comptime format: []const u8,
    args: anytype,
) void {
    if (!shouldLog(level)) return;

    // Format message
    var msg_buf: [2048]u8 = undefined;
    const message = std.fmt.bufPrint(&msg_buf, format, args) catch return;

    // Apply filter if configured
    if (current_config.filter_pattern) |pattern| {
        if (std.mem.indexOf(u8, message, pattern) == null) {
            return; // Skip messages that don't match filter
        }
    }

    var output_buf: [4096]u8 = undefined;
    var output_len: usize = 0;

    // Each call owns its own timestamp buffer — safe for concurrent logging.
    var ts_buf: [8]u8 = undefined;
    const timestamp = formatTimestamp(&ts_buf);

    if (current_config.json_output) {
        // JSON output — escape the message so that quotes, newlines, and
        // backslashes don't produce invalid JSON. Previously a message like
        // `foo "bar"\nbaz` would corrupt every log consumer parsing the stream.
        var esc_buf: [4096]u8 = undefined;
        var esc_len: usize = 0;
        for (message) |c| {
            const esc: []const u8 = switch (c) {
                '"' => "\\\"",
                '\\' => "\\\\",
                '\n' => "\\n",
                '\r' => "\\r",
                '\t' => "\\t",
                0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F => blk: {
                    var hex: [6]u8 = undefined;
                    const slice = std.fmt.bufPrint(&hex, "\\u{x:0>4}", .{c}) catch break :blk "";
                    if (esc_len + slice.len > esc_buf.len) break :blk "";
                    @memcpy(esc_buf[esc_len..][0..slice.len], slice);
                    esc_len += slice.len;
                    break :blk "";
                },
                else => &[_]u8{c},
            };
            if (esc.len == 0) continue;
            if (esc_len + esc.len > esc_buf.len) break;
            @memcpy(esc_buf[esc_len..][0..esc.len], esc);
            esc_len += esc.len;
        }

        const result = std.fmt.bufPrint(&output_buf, "{{\"timestamp\":\"{s}\",\"level\":\"{s}\",\"message\":\"{s}\"}}\n", .{ timestamp, level.toString(), esc_buf[0..esc_len] }) catch return;
        output_len = result.len;
    } else {
        // Standard output
        const reset = "\x1B[0m";
        const dim = "\x1B[2m";

        if (current_config.enable_timestamps and current_config.enable_colors) {
            const result = std.fmt.bufPrint(&output_buf, "{s}[{s}]{s} {s}{s}{s} {s}\n", .{ dim, timestamp, reset, level.color(), level.toString(), reset, message }) catch return;
            output_len = result.len;
        } else if (current_config.enable_timestamps) {
            const result = std.fmt.bufPrint(&output_buf, "[{s}] {s} {s}\n", .{ timestamp, level.toString(), message }) catch return;
            output_len = result.len;
        } else if (current_config.enable_colors) {
            const result = std.fmt.bufPrint(&output_buf, "{s}{s}{s} {s}\n", .{ level.color(), level.toString(), reset, message }) catch return;
            output_len = result.len;
        } else {
            const result = std.fmt.bufPrint(&output_buf, "{s} {s}\n", .{ level.toString(), message }) catch return;
            output_len = result.len;
        }
    }

    const output = output_buf[0..output_len];

    // Write to stderr
    _ = std.Io.File.stderr().writeStreamingAll(io_context.get(), output) catch return;

    // Write to file if configured
    if (log_file) |file| {
        _ = file.writeStreamingAll(io_context.get(), output) catch return;
    }
}

pub fn debug(comptime format: []const u8, args: anytype) void {
    log(.Debug, format, args);
}

pub fn info(comptime format: []const u8, args: anytype) void {
    log(.Info, format, args);
}

pub fn warn(comptime format: []const u8, args: anytype) void {
    log(.Warning, format, args);
}

pub fn err(comptime format: []const u8, args: anytype) void {
    log(.Error, format, args);
}

pub fn fatal(comptime format: []const u8, args: anytype) void {
    log(.Fatal, format, args);
}

/// Format a HH:MM:SS timestamp into caller-provided buffer.
/// Caller owns the buffer; returning a slice into it avoids the previous
/// thread-unsafe shared static buffer that could be corrupted under concurrent logging.
fn formatTimestamp(buf: *[8]u8) []const u8 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) != 0) {
        @memcpy(buf, "00:00:00");
        return buf[0..];
    }
    const total_seconds: u64 = @intCast(ts.sec);
    const seconds = @mod(total_seconds, 60);
    const minutes = @mod(@divFloor(total_seconds, 60), 60);
    const hours = @mod(@divFloor(total_seconds, 3600), 24);

    const slice = std.fmt.bufPrint(buf, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds }) catch {
        @memcpy(buf, "00:00:00");
        return buf[0..];
    };
    return slice;
}
