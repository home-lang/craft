const std = @import("std");
const memory = @import("memory.zig");
const io_context = @import("io_context.zig");

pub const ProfileEntry = struct {
    name: []const u8,
    start_time: ?std.Io.Timestamp,
    end_time: ?std.Io.Timestamp,
    duration_ms: f64,
    memory_before: usize,
    memory_after: usize,
};

pub const Profiler = struct {
    entries: std.ArrayList(ProfileEntry),
    active_profiles: std.StringHashMap(std.Io.Timestamp),
    memory_tracker: ?*memory.TrackingAllocator,
    allocator: std.mem.Allocator,
    enabled: bool = true,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .entries = .{},
            .active_profiles = std.StringHashMap(std.Io.Timestamp).init(allocator),
            .memory_tracker = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.entries.deinit(self.allocator);
        self.active_profiles.deinit();
    }

    pub fn setMemoryTracker(self: *Self, tracker: *memory.TrackingAllocator) void {
        self.memory_tracker = tracker;
    }

    pub fn start(self: *Self, name: []const u8) !void {
        if (!self.enabled) return;

        const start_time = std.Io.Timestamp.now(io_context.get(), .awake);
        try self.active_profiles.put(name, start_time);
    }

    pub fn end(self: *Self, name: []const u8) !void {
        if (!self.enabled) return;

        const end_time = std.Io.Timestamp.now(io_context.get(), .awake);
        const start_time = self.active_profiles.get(name) orelse return;
        _ = self.active_profiles.remove(name);

        const duration = start_time.durationTo(end_time);
        const elapsed_ns = @as(u64, @intCast(duration.nanoseconds));
        const duration_ms = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));

        const memory_before: usize = 0;
        var memory_after: usize = 0;

        if (self.memory_tracker) |tracker| {
            const stats = tracker.getStats();
            memory_after = stats.current_memory;
        }

        try self.entries.append(self.allocator, .{
            .name = name,
            .start_time = start_time,
            .end_time = end_time,
            .duration_ms = duration_ms,
            .memory_before = memory_before,
            .memory_after = memory_after,
        });
    }

    pub fn measure(self: *Self, comptime name: []const u8, comptime func: anytype, args: anytype) MeasureReturnType(@TypeOf(func)) {
        self.start(name) catch {};
        defer self.end(name) catch {};
        return @call(.auto, func, args);
    }

    fn MeasureReturnType(comptime FnType: type) type {
        const ReturnType = @typeInfo(FnType).@"fn".return_type.?;
        return switch (@typeInfo(ReturnType)) {
            .error_union => ReturnType,
            else => ReturnType,
        };
    }

    pub fn getReport(self: Self) ![]const u8 {
        var report: std.ArrayList(u8) = .{};
        errdefer report.deinit(self.allocator);

        try report.appendSlice(self.allocator, "\n=== Performance Profile Report ===\n\n");

        if (self.entries.items.len == 0) {
            try report.appendSlice(self.allocator, "No profiling data collected.\n");
            return report.toOwnedSlice(self.allocator);
        }

        // Calculate totals and averages
        var total_time: f64 = 0;
        var slowest: ?ProfileEntry = null;
        var fastest: ?ProfileEntry = null;

        for (self.entries.items) |entry| {
            total_time += entry.duration_ms;

            if (slowest == null or entry.duration_ms > slowest.?.duration_ms) {
                slowest = entry;
            }
            if (fastest == null or entry.duration_ms < fastest.?.duration_ms) {
                fastest = entry;
            }
        }

        const avg_time = total_time / @as(f64, @floatFromInt(self.entries.items.len));

        const stats = try std.fmt.allocPrint(self.allocator, "Total entries: {d}\nTotal time: {d:.2}ms\nAverage time: {d:.2}ms\n\n", .{ self.entries.items.len, total_time, avg_time });
        defer self.allocator.free(stats);
        try report.appendSlice(self.allocator, stats);

        if (slowest) |s| {
            const slowest_str = try std.fmt.allocPrint(self.allocator, "Slowest: {s} ({d:.2}ms)\n", .{ s.name, s.duration_ms });
            defer self.allocator.free(slowest_str);
            try report.appendSlice(self.allocator, slowest_str);
        }
        if (fastest) |f| {
            const fastest_str = try std.fmt.allocPrint(self.allocator, "Fastest: {s} ({d:.2}ms)\n\n", .{ f.name, f.duration_ms });
            defer self.allocator.free(fastest_str);
            try report.appendSlice(self.allocator, fastest_str);
        }

        try report.appendSlice(self.allocator, "Individual Entries:\n------------------\n");

        for (self.entries.items) |entry| {
            const entry_str = if (entry.memory_after > 0)
                try std.fmt.allocPrint(self.allocator, "{s:30} {d:8.2}ms  (mem: {d} bytes)\n", .{ entry.name, entry.duration_ms, entry.memory_after })
            else
                try std.fmt.allocPrint(self.allocator, "{s:30} {d:8.2}ms\n", .{ entry.name, entry.duration_ms });
            defer self.allocator.free(entry_str);
            try report.appendSlice(self.allocator, entry_str);
        }

        return report.toOwnedSlice(self.allocator);
    }

    pub fn printReport(self: Self) !void {
        const report = try self.getReport();
        defer self.allocator.free(report);
        std.debug.print("{s}\n", .{report});
    }

    pub fn clear(self: *Self) void {
        self.entries.clearRetainingCapacity();
        self.active_profiles.clearRetainingCapacity();
    }

    pub fn getHTMLDashboard(self: Self) ![]const u8 {
        var html: std.ArrayList(u8) = .{};
        errdefer html.deinit(self.allocator);

        const html_header =
            \\<!DOCTYPE html>
            \\<html>
            \\<head>
            \\  <meta charset="UTF-8">
            \\  <title>Craft Performance Dashboard</title>
            \\  <style>
            \\    * { margin: 0; padding: 0; box-sizing: border-box; }
            \\    body { font-family: -apple-system, system-ui, sans-serif; background: #1a1a1a; color: #e0e0e0; padding: 20px; }
            \\    .container { max-width: 1200px; margin: 0 auto; }
            \\    h1 { color: #00ffff; margin-bottom: 20px; }
            \\    .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
            \\    .stat-card { background: #2a2a2a; padding: 20px; border-radius: 8px; border-left: 4px solid #00ffff; }
            \\    .stat-label { color: #888; font-size: 14px; margin-bottom: 5px; }
            \\    .stat-value { font-size: 32px; font-weight: bold; color: #00ff00; }
            \\    table { width: 100%; background: #2a2a2a; border-radius: 8px; overflow: hidden; }
            \\    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #3a3a3a; }
            \\    th { background: #333; color: #00ffff; }
            \\    tr:hover { background: #333; }
            \\    .slow { color: #ff4444; }
            \\    .fast { color: #00ff00; }
            \\  </style>
            \\</head>
            \\<body>
            \\  <div class="container">
            \\    <h1>Craft Performance Dashboard</h1>
        ;
        try html.appendSlice(self.allocator, html_header);

        // Calculate stats
        var total_time: f64 = 0;
        for (self.entries.items) |entry| {
            total_time += entry.duration_ms;
        }

        const avg_time = if (self.entries.items.len > 0)
            total_time / @as(f64, @floatFromInt(self.entries.items.len))
        else
            0;

        const stats_html = try std.fmt.allocPrint(self.allocator,
            \\    <div class="stats">
            \\      <div class="stat-card"><div class="stat-label">Total Entries</div><div class="stat-value">{d}</div></div>
            \\      <div class="stat-card"><div class="stat-label">Total Time</div><div class="stat-value">{d:.2}ms</div></div>
            \\      <div class="stat-card"><div class="stat-label">Average Time</div><div class="stat-value">{d:.2}ms</div></div>
            \\    </div>
            \\    <table><thead><tr><th>Operation</th><th>Duration</th><th>Memory</th><th>Status</th></tr></thead><tbody>
        , .{ self.entries.items.len, total_time, avg_time });
        defer self.allocator.free(stats_html);
        try html.appendSlice(self.allocator, stats_html);

        for (self.entries.items) |entry| {
            const status_class = if (entry.duration_ms > 16.67) "slow" else "fast";
            const status_text = if (entry.duration_ms > 16.67) "Slow" else "Fast";
            const row = try std.fmt.allocPrint(self.allocator, "<tr><td>{s}</td><td>{d:.2}ms</td><td>{d} bytes</td><td class=\"{s}\">{s}</td></tr>", .{ entry.name, entry.duration_ms, entry.memory_after, status_class, status_text });
            defer self.allocator.free(row);
            try html.appendSlice(self.allocator, row);
        }

        try html.appendSlice(self.allocator, "</tbody></table></div></body></html>");

        return html.toOwnedSlice(self.allocator);
    }
};

// Global profiler instance
var global_profiler: ?Profiler = null;

pub fn initGlobalProfiler(allocator: std.mem.Allocator) void {
    global_profiler = Profiler.init(allocator);
}

pub fn deinitGlobalProfiler() void {
    if (global_profiler) |*p| {
        p.deinit();
        global_profiler = null;
    }
}

pub fn start(name: []const u8) !void {
    if (global_profiler) |*p| {
        try p.start(name);
    }
}

pub fn end(name: []const u8) !void {
    if (global_profiler) |*p| {
        try p.end(name);
    }
}

pub fn printReport() !void {
    if (global_profiler) |*p| {
        try p.printReport();
    }
}
