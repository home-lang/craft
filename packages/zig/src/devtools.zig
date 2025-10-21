const std = @import("std");

/// Developer Tools Enhancement System
/// Provides debugging, profiling, network inspection, and memory leak detection

pub const DevToolsConfig = struct {
    enabled: bool = true,
    port: u16 = 9222, // Chrome DevTools Protocol port
    enable_profiling: bool = true,
    enable_network_inspector: bool = true,
    enable_memory_inspector: bool = true,
    enable_console: bool = true,
    enable_sources: bool = true,
    enable_performance: bool = true,
};

/// Chrome DevTools Protocol implementation
pub const CDP = struct {
    port: u16,
    server: ?std.net.StreamServer = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, port: u16) CDP {
        return CDP{
            .port = port,
            .allocator = allocator,
        };
    }

    pub fn start(self: *CDP) !void {
        const address = try std.net.Address.parseIp("127.0.0.1", self.port);
        self.server = std.net.StreamServer.init(.{});
        try self.server.?.listen(address);
        std.debug.print("DevTools listening on http://127.0.0.1:{}\n", .{self.port});
    }

    pub fn stop(self: *CDP) void {
        if (self.server) |*server| {
            server.deinit();
            self.server = null;
        }
    }

    pub fn sendEvent(self: *CDP, method: []const u8, params: anytype) !void {
        _ = self;
        _ = method;
        _ = params;
        // Would serialize and send CDP event
    }
};

/// Network request/response inspector
pub const NetworkInspector = struct {
    requests: std.ArrayList(NetworkRequest),
    allocator: std.mem.Allocator,
    enabled: bool = true,

    pub const NetworkRequest = struct {
        id: u64,
        url: []const u8,
        method: []const u8,
        status: ?u16 = null,
        start_time: i64,
        end_time: ?i64 = null,
        request_headers: std.StringHashMap([]const u8),
        response_headers: std.StringHashMap([]const u8),
        request_body: ?[]const u8 = null,
        response_body: ?[]const u8 = null,
        size: usize = 0,
        from_cache: bool = false,
        error_message: ?[]const u8 = null,

        pub fn duration(self: *const NetworkRequest) i64 {
            if (self.end_time) |end| {
                return end - self.start_time;
            }
            return std.time.milliTimestamp() - self.start_time;
        }
    };

    pub fn init(allocator: std.mem.Allocator) NetworkInspector {
        return NetworkInspector{
            .requests = std.ArrayList(NetworkRequest).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *NetworkInspector) void {
        for (self.requests.items) |*req| {
            req.request_headers.deinit();
            req.response_headers.deinit();
        }
        self.requests.deinit();
    }

    pub fn recordRequest(self: *NetworkInspector, url: []const u8, method: []const u8) !u64 {
        if (!self.enabled) return 0;

        const id = @as(u64, @intCast(self.requests.items.len + 1));
        try self.requests.append(.{
            .id = id,
            .url = url,
            .method = method,
            .start_time = std.time.milliTimestamp(),
            .request_headers = std.StringHashMap([]const u8).init(self.allocator),
            .response_headers = std.StringHashMap([]const u8).init(self.allocator),
        });
        return id;
    }

    pub fn recordResponse(self: *NetworkInspector, id: u64, status: u16, size: usize) !void {
        if (!self.enabled) return;

        for (self.requests.items) |*req| {
            if (req.id == id) {
                req.status = status;
                req.end_time = std.time.milliTimestamp();
                req.size = size;
                return;
            }
        }
    }

    pub fn getRequests(self: *const NetworkInspector) []const NetworkRequest {
        return self.requests.items;
    }

    pub fn getTotalSize(self: *const NetworkInspector) usize {
        var total: usize = 0;
        for (self.requests.items) |req| {
            total += req.size;
        }
        return total;
    }

    pub fn getTotalRequests(self: *const NetworkInspector) usize {
        return self.requests.items.len;
    }

    pub fn clear(self: *NetworkInspector) void {
        for (self.requests.items) |*req| {
            req.request_headers.deinit();
            req.response_headers.deinit();
        }
        self.requests.clearRetainingCapacity();
    }
};

/// Memory leak detection and analysis
pub const MemoryInspector = struct {
    allocations: std.ArrayList(Allocation),
    snapshots: std.ArrayList(MemorySnapshot),
    allocator: std.mem.Allocator,
    enabled: bool = true,
    next_allocation_id: u64 = 1,

    pub const Allocation = struct {
        id: u64,
        address: usize,
        size: usize,
        timestamp: i64,
        freed: bool = false,
        stack_trace: ?[]const usize = null,
    };

    pub const MemorySnapshot = struct {
        timestamp: i64,
        total_allocated: usize,
        total_freed: usize,
        live_allocations: usize,
        allocation_count: usize,
    };

    pub fn init(allocator: std.mem.Allocator) MemoryInspector {
        return MemoryInspector{
            .allocations = std.ArrayList(Allocation).init(allocator),
            .snapshots = std.ArrayList(MemorySnapshot).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MemoryInspector) void {
        self.allocations.deinit();
        self.snapshots.deinit();
    }

    pub fn recordAllocation(self: *MemoryInspector, address: usize, size: usize) !void {
        if (!self.enabled) return;

        const id = self.next_allocation_id;
        self.next_allocation_id += 1;

        try self.allocations.append(.{
            .id = id,
            .address = address,
            .size = size,
            .timestamp = std.time.milliTimestamp(),
        });
    }

    pub fn recordFree(self: *MemoryInspector, address: usize) !void {
        if (!self.enabled) return;

        for (self.allocations.items) |*alloc| {
            if (alloc.address == address and !alloc.freed) {
                alloc.freed = true;
                return;
            }
        }
    }

    pub fn takeSnapshot(self: *MemoryInspector) !void {
        var total_allocated: usize = 0;
        var total_freed: usize = 0;
        var live_allocations: usize = 0;

        for (self.allocations.items) |alloc| {
            total_allocated += alloc.size;
            if (alloc.freed) {
                total_freed += alloc.size;
            } else {
                live_allocations += 1;
            }
        }

        try self.snapshots.append(.{
            .timestamp = std.time.milliTimestamp(),
            .total_allocated = total_allocated,
            .total_freed = total_freed,
            .live_allocations = live_allocations,
            .allocation_count = self.allocations.items.len,
        });
    }

    pub fn detectLeaks(self: *const MemoryInspector) []const Allocation {
        var leaks = std.ArrayList(Allocation).init(self.allocator);
        defer leaks.deinit();

        for (self.allocations.items) |alloc| {
            if (!alloc.freed) {
                leaks.append(alloc) catch continue;
            }
        }

        return leaks.items;
    }

    pub fn getSnapshots(self: *const MemoryInspector) []const MemorySnapshot {
        return self.snapshots.items;
    }

    pub fn clear(self: *MemoryInspector) void {
        self.allocations.clearRetainingCapacity();
        self.snapshots.clearRetainingCapacity();
        self.next_allocation_id = 1;
    }
};

/// Performance profiler
pub const Profiler = struct {
    sessions: std.ArrayList(ProfileSession),
    allocator: std.mem.Allocator,
    enabled: bool = true,

    pub const ProfileSession = struct {
        name: []const u8,
        start_time: i64,
        end_time: ?i64 = null,
        cpu_samples: std.ArrayList(CPUSample),
        memory_samples: std.ArrayList(MemorySample),

        pub const CPUSample = struct {
            timestamp: i64,
            cpu_usage: f64,
        };

        pub const MemorySample = struct {
            timestamp: i64,
            heap_used: usize,
            heap_total: usize,
        };

        pub fn duration(self: *const ProfileSession) i64 {
            if (self.end_time) |end| {
                return end - self.start_time;
            }
            return std.time.milliTimestamp() - self.start_time;
        }
    };

    pub fn init(allocator: std.mem.Allocator) Profiler {
        return Profiler{
            .sessions = std.ArrayList(ProfileSession).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Profiler) void {
        for (self.sessions.items) |*session| {
            session.cpu_samples.deinit();
            session.memory_samples.deinit();
        }
        self.sessions.deinit();
    }

    pub fn startSession(self: *Profiler, name: []const u8) !void {
        if (!self.enabled) return;

        try self.sessions.append(.{
            .name = name,
            .start_time = std.time.milliTimestamp(),
            .cpu_samples = std.ArrayList(ProfileSession.CPUSample).init(self.allocator),
            .memory_samples = std.ArrayList(ProfileSession.MemorySample).init(self.allocator),
        });
    }

    pub fn endSession(self: *Profiler) !void {
        if (self.sessions.items.len == 0) return;

        var session = &self.sessions.items[self.sessions.items.len - 1];
        session.end_time = std.time.milliTimestamp();
    }

    pub fn sampleCPU(self: *Profiler, cpu_usage: f64) !void {
        if (self.sessions.items.len == 0) return;

        var session = &self.sessions.items[self.sessions.items.len - 1];
        try session.cpu_samples.append(.{
            .timestamp = std.time.milliTimestamp(),
            .cpu_usage = cpu_usage,
        });
    }

    pub fn sampleMemory(self: *Profiler, heap_used: usize, heap_total: usize) !void {
        if (self.sessions.items.len == 0) return;

        var session = &self.sessions.items[self.sessions.items.len - 1];
        try session.memory_samples.append(.{
            .timestamp = std.time.milliTimestamp(),
            .heap_used = heap_used,
            .heap_total = heap_total,
        });
    }

    pub fn getSessions(self: *const Profiler) []const ProfileSession {
        return self.sessions.items;
    }

    pub fn clear(self: *Profiler) void {
        for (self.sessions.items) |*session| {
            session.cpu_samples.clearRetainingCapacity();
            session.memory_samples.clearRetainingCapacity();
        }
        self.sessions.clearRetainingCapacity();
    }
};

/// Main DevTools coordinator
pub const DevTools = struct {
    config: DevToolsConfig,
    cdp: ?CDP = null,
    network_inspector: NetworkInspector,
    memory_inspector: MemoryInspector,
    profiler: Profiler,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: DevToolsConfig) DevTools {
        return DevTools{
            .config = config,
            .network_inspector = NetworkInspector.init(allocator),
            .memory_inspector = MemoryInspector.init(allocator),
            .profiler = Profiler.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DevTools) void {
        if (self.cdp) |*cdp| {
            cdp.stop();
        }
        self.network_inspector.deinit();
        self.memory_inspector.deinit();
        self.profiler.deinit();
    }

    pub fn start(self: *DevTools) !void {
        if (!self.config.enabled) return;

        // Start Chrome DevTools Protocol server
        var cdp = CDP.init(self.allocator, self.config.port);
        try cdp.start();
        self.cdp = cdp;

        // Enable inspectors based on config
        self.network_inspector.enabled = self.config.enable_network_inspector;
        self.memory_inspector.enabled = self.config.enable_memory_inspector;
        self.profiler.enabled = self.config.enable_profiling;
    }

    pub fn stop(self: *DevTools) void {
        if (self.cdp) |*cdp| {
            cdp.stop();
        }
    }

    pub fn getReport(self: *const DevTools, allocator: std.mem.Allocator) ![]u8 {
        var report = std.ArrayList(u8).init(allocator);
        const writer = report.writer();

        try writer.writeAll("=== Zyte DevTools Report ===\n\n");

        // Network report
        try writer.print("Network Requests: {}\n", .{self.network_inspector.getTotalRequests()});
        try writer.print("Total Data Transferred: {} bytes\n\n", .{self.network_inspector.getTotalSize()});

        // Memory report
        const snapshots = self.memory_inspector.getSnapshots();
        if (snapshots.len > 0) {
            const latest = snapshots[snapshots.len - 1];
            try writer.print("Memory Allocations: {}\n", .{latest.allocation_count});
            try writer.print("Live Allocations: {}\n", .{latest.live_allocations});
            try writer.print("Total Allocated: {} bytes\n", .{latest.total_allocated});
            try writer.print("Total Freed: {} bytes\n\n", .{latest.total_freed});
        }

        // Performance report
        const sessions = self.profiler.getSessions();
        if (sessions.len > 0) {
            try writer.print("Profiling Sessions: {}\n", .{sessions.len});
            for (sessions) |session| {
                try writer.print("  - {s}: {}ms\n", .{ session.name, session.duration() });
            }
        }

        return report.toOwnedSlice();
    }
};

test "network inspector" {
    const allocator = std.testing.allocator;
    var inspector = NetworkInspector.init(allocator);
    defer inspector.deinit();

    const id = try inspector.recordRequest("https://example.com", "GET");
    try std.testing.expect(id == 1);

    try inspector.recordResponse(id, 200, 1024);

    const requests = inspector.getRequests();
    try std.testing.expect(requests.len == 1);
    try std.testing.expect(requests[0].status.? == 200);
    try std.testing.expect(requests[0].size == 1024);
}

test "memory inspector" {
    const allocator = std.testing.allocator;
    var inspector = MemoryInspector.init(allocator);
    defer inspector.deinit();

    try inspector.recordAllocation(0x1000, 100);
    try inspector.recordAllocation(0x2000, 200);
    try inspector.recordFree(0x1000);

    try inspector.takeSnapshot();

    const snapshots = inspector.getSnapshots();
    try std.testing.expect(snapshots.len == 1);
    try std.testing.expect(snapshots[0].live_allocations == 1);
}

test "profiler" {
    const allocator = std.testing.allocator;
    var profiler = Profiler.init(allocator);
    defer profiler.deinit();

    try profiler.startSession("test");
    try profiler.sampleCPU(45.5);
    try profiler.sampleMemory(1024, 2048);
    try profiler.endSession();

    const sessions = profiler.getSessions();
    try std.testing.expect(sessions.len == 1);
    try std.testing.expect(sessions[0].cpu_samples.items.len == 1);
}
