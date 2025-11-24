const std = @import("std");

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
var log_file: ?std.fs.File = null;

pub fn init(config: LogConfig) !void {
    current_config = config;

    if (config.output_file) |path| {
        log_file = try std.fs.cwd().createFile(path, .{
            .truncate = false,
            .read = true,
        });
    }
}

pub fn deinit() void {
    if (log_file) |file| {
        file.close();
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

    var buf: [4096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    // Format message
    var msg_buf: [2048]u8 = undefined;
    const message = std.fmt.bufPrint(&msg_buf, format, args) catch return;

    // Apply filter if configured
    if (current_config.filter_pattern) |pattern| {
        if (std.mem.indexOf(u8, message, pattern) == null) {
            return; // Skip messages that don't match filter
        }
    }

    if (current_config.json_output) {
        // JSON output
        writer.writeAll("{") catch return;
        writer.print("\"timestamp\":\"{s}\",", .{getTimestamp()}) catch return;
        writer.print("\"level\":\"{s}\",", .{level.toString()}) catch return;
        writer.print("\"message\":\"{s}\"", .{message}) catch return;
        writer.writeAll("}\n") catch return;
    } else {
        // Standard output
        const reset = "\x1B[0m";
        const dim = "\x1B[2m";

        if (current_config.enable_timestamps) {
            const timestamp = getTimestamp();
            writer.print("{s}[{s}]{s} ", .{ dim, timestamp, reset }) catch return;
        }

        if (current_config.enable_colors) {
            writer.print("{s}{s}{s} ", .{ level.color(), level.toString(), reset }) catch return;
        } else {
            writer.print("{s} ", .{level.toString()}) catch return;
        }

        writer.writeAll(message) catch return;
        writer.writeByte('\n') catch return;
    }

    // Write to stderr
    const stderr = std.io.getStdErr().writer();
    stderr.writeAll(stream.getWritten()) catch return;

    // Write to file if configured
    if (log_file) |file| {
        file.writeAll(stream.getWritten()) catch return;
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
    const timestamp = std.time.timestamp();
    const seconds = @mod(timestamp, 60);
    const minutes = @mod(@divFloor(timestamp, 60), 60);
    const hours = @mod(@divFloor(timestamp, 3600), 24);

    var buf: [8]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds }) catch unreachable;
    return &buf;
}
