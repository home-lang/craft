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

    if (current_config.json_output) {
        // JSON output
        const result = std.fmt.bufPrint(&output_buf, "{{\"timestamp\":\"{s}\",\"level\":\"{s}\",\"message\":\"{s}\"}}\n", .{ getTimestamp(), level.toString(), message }) catch return;
        output_len = result.len;
    } else {
        // Standard output
        const reset = "\x1B[0m";
        const dim = "\x1B[2m";

        if (current_config.enable_timestamps and current_config.enable_colors) {
            const result = std.fmt.bufPrint(&output_buf, "{s}[{s}]{s} {s}{s}{s} {s}\n", .{ dim, getTimestamp(), reset, level.color(), level.toString(), reset, message }) catch return;
            output_len = result.len;
        } else if (current_config.enable_timestamps) {
            const result = std.fmt.bufPrint(&output_buf, "[{s}] {s} {s}\n", .{ getTimestamp(), level.toString(), message }) catch return;
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

fn getTimestamp() []const u8 {
    // Simple timestamp - hours:minutes:seconds
    // Note: Using static buffer - not thread-safe but acceptable for logging
    const Static = struct {
        var buf: [8]u8 = undefined;
    };

    // Use C clock_gettime for wall clock time
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) != 0) return "00:00:00";
    const total_seconds: u64 = @intCast(ts.sec);
    const seconds = @mod(total_seconds, 60);
    const minutes = @mod(@divFloor(total_seconds, 60), 60);
    const hours = @mod(@divFloor(total_seconds, 3600), 24);

    _ = std.fmt.bufPrint(&Static.buf, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds }) catch unreachable;
    return &Static.buf;
}
