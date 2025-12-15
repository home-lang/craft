//! Cross-platform background tasks module
//! Provides abstractions for BGTaskScheduler (iOS), WorkManager (Android), and system schedulers

const std = @import("std");

/// Background task platform
pub const TaskPlatform = enum {
    bg_task_scheduler, // iOS 13+
    work_manager, // Android
    windows_task_scheduler,
    systemd, // Linux
    launchd, // macOS

    pub fn toString(self: TaskPlatform) []const u8 {
        return switch (self) {
            .bg_task_scheduler => "BGTaskScheduler",
            .work_manager => "WorkManager",
            .windows_task_scheduler => "Task Scheduler",
            .systemd => "systemd",
            .launchd => "launchd",
        };
    }

    pub fn supportsExactTiming(self: TaskPlatform) bool {
        return switch (self) {
            .windows_task_scheduler, .systemd, .launchd => true,
            .bg_task_scheduler, .work_manager => false,
        };
    }
};

/// Task type
pub const TaskType = enum {
    processing, // Short background processing
    app_refresh, // Periodic app refresh
    connectivity, // Network dependent
    charging, // Requires charging
    low_battery_ok, // Can run on low battery

    pub fn toString(self: TaskType) []const u8 {
        return switch (self) {
            .processing => "Processing",
            .app_refresh => "App Refresh",
            .connectivity => "Connectivity",
            .charging => "Charging",
            .low_battery_ok => "Low Battery OK",
        };
    }

    pub fn defaultTimeoutSeconds(self: TaskType) u32 {
        return switch (self) {
            .processing => 30,
            .app_refresh => 30,
            .connectivity => 600,
            .charging => 1800,
            .low_battery_ok => 60,
        };
    }
};

/// Task state
pub const TaskState = enum {
    pending,
    scheduled,
    running,
    completed,
    failed,
    cancelled,
    expired,

    pub fn toString(self: TaskState) []const u8 {
        return switch (self) {
            .pending => "Pending",
            .scheduled => "Scheduled",
            .running => "Running",
            .completed => "Completed",
            .failed => "Failed",
            .cancelled => "Cancelled",
            .expired => "Expired",
        };
    }

    pub fn isTerminal(self: TaskState) bool {
        return switch (self) {
            .completed, .failed, .cancelled, .expired => true,
            else => false,
        };
    }

    pub fn isActive(self: TaskState) bool {
        return self == .running;
    }
};

/// Task priority
pub const TaskPriority = enum {
    low,
    normal,
    high,
    expedited,

    pub fn toString(self: TaskPriority) []const u8 {
        return switch (self) {
            .low => "Low",
            .normal => "Normal",
            .high => "High",
            .expedited => "Expedited",
        };
    }

    pub fn toNumeric(self: TaskPriority) u8 {
        return switch (self) {
            .low => 1,
            .normal => 5,
            .high => 8,
            .expedited => 10,
        };
    }
};

/// Network type requirement
pub const NetworkType = enum {
    none, // No network required
    connected, // Any connection
    unmetered, // WiFi only
    not_roaming, // Not roaming
    metered, // Cellular OK

    pub fn toString(self: NetworkType) []const u8 {
        return switch (self) {
            .none => "None",
            .connected => "Connected",
            .unmetered => "Unmetered",
            .not_roaming => "Not Roaming",
            .metered => "Metered",
        };
    }

    pub fn requiresNetwork(self: NetworkType) bool {
        return self != .none;
    }
};

/// Backoff policy for retries
pub const BackoffPolicy = enum {
    linear,
    exponential,

    pub fn toString(self: BackoffPolicy) []const u8 {
        return switch (self) {
            .linear => "Linear",
            .exponential => "Exponential",
        };
    }

    pub fn calculateDelay(self: BackoffPolicy, base_delay_ms: u64, attempt: u32) u64 {
        return switch (self) {
            .linear => base_delay_ms * @as(u64, attempt),
            .exponential => base_delay_ms * std.math.pow(u64, 2, attempt),
        };
    }
};

/// Task result
pub const TaskResult = enum {
    success,
    failure,
    retry,

    pub fn toString(self: TaskResult) []const u8 {
        return switch (self) {
            .success => "Success",
            .failure => "Failure",
            .retry => "Retry",
        };
    }

    pub fn shouldRetry(self: TaskResult) bool {
        return self == .retry;
    }
};

/// Task constraints
pub const TaskConstraints = struct {
    network_type: NetworkType,
    requires_charging: bool,
    requires_device_idle: bool,
    requires_battery_not_low: bool,
    requires_storage_not_low: bool,
    trigger_content_uri: ?[]const u8, // Content change trigger (Android)

    pub fn defaults() TaskConstraints {
        return .{
            .network_type = .none,
            .requires_charging = false,
            .requires_device_idle = false,
            .requires_battery_not_low = false,
            .requires_storage_not_low = false,
            .trigger_content_uri = null,
        };
    }

    pub fn withNetwork(self: TaskConstraints, network_type: NetworkType) TaskConstraints {
        var constraints = self;
        constraints.network_type = network_type;
        return constraints;
    }

    pub fn withCharging(self: TaskConstraints, required: bool) TaskConstraints {
        var constraints = self;
        constraints.requires_charging = required;
        return constraints;
    }

    pub fn withDeviceIdle(self: TaskConstraints, required: bool) TaskConstraints {
        var constraints = self;
        constraints.requires_device_idle = required;
        return constraints;
    }

    pub fn withBatteryNotLow(self: TaskConstraints, required: bool) TaskConstraints {
        var constraints = self;
        constraints.requires_battery_not_low = required;
        return constraints;
    }

    pub fn withStorageNotLow(self: TaskConstraints, required: bool) TaskConstraints {
        var constraints = self;
        constraints.requires_storage_not_low = required;
        return constraints;
    }

    pub fn isSatisfied(self: *const TaskConstraints, context: *const TaskContext) bool {
        if (self.network_type.requiresNetwork() and !context.has_network) {
            return false;
        }
        if (self.requires_charging and !context.is_charging) {
            return false;
        }
        if (self.requires_battery_not_low and context.battery_level < 20) {
            return false;
        }
        return true;
    }

    pub fn hasConstraints(self: *const TaskConstraints) bool {
        return self.network_type != .none or
            self.requires_charging or
            self.requires_device_idle or
            self.requires_battery_not_low or
            self.requires_storage_not_low;
    }
};

/// Task context (runtime information)
pub const TaskContext = struct {
    has_network: bool,
    is_charging: bool,
    is_device_idle: bool,
    battery_level: u8, // 0-100
    available_storage_mb: u64,

    pub fn defaults() TaskContext {
        return .{
            .has_network = true,
            .is_charging = false,
            .is_device_idle = false,
            .battery_level = 100,
            .available_storage_mb = 1000,
        };
    }

    pub fn withNetwork(self: TaskContext, has_network: bool) TaskContext {
        var ctx = self;
        ctx.has_network = has_network;
        return ctx;
    }

    pub fn withCharging(self: TaskContext, is_charging: bool) TaskContext {
        var ctx = self;
        ctx.is_charging = is_charging;
        return ctx;
    }

    pub fn withBatteryLevel(self: TaskContext, level: u8) TaskContext {
        var ctx = self;
        ctx.battery_level = @min(100, level);
        return ctx;
    }
};

/// Periodic task interval
pub const PeriodicInterval = struct {
    minutes: u32,
    flex_minutes: ?u32, // Flexibility window

    pub fn every(minutes: u32) PeriodicInterval {
        return .{
            .minutes = @max(15, minutes), // Minimum 15 minutes on most platforms
            .flex_minutes = null,
        };
    }

    pub fn everyHours(hours: u32) PeriodicInterval {
        return every(hours * 60);
    }

    pub fn everyDays(days: u32) PeriodicInterval {
        return every(days * 24 * 60);
    }

    pub fn withFlexibility(self: PeriodicInterval, flex_minutes: u32) PeriodicInterval {
        var interval = self;
        interval.flex_minutes = @min(flex_minutes, self.minutes / 2);
        return interval;
    }

    pub fn toMilliseconds(self: PeriodicInterval) u64 {
        return @as(u64, self.minutes) * 60 * 1000;
    }

    pub fn getEarliestRunTime(self: PeriodicInterval) u64 {
        if (self.flex_minutes) |flex| {
            return (@as(u64, self.minutes) - flex) * 60 * 1000;
        }
        return self.toMilliseconds();
    }
};

/// Task request
pub const TaskRequest = struct {
    identifier: []const u8,
    task_type: TaskType,
    priority: TaskPriority,
    constraints: TaskConstraints,
    initial_delay_ms: u64,
    periodic_interval: ?PeriodicInterval,
    max_retries: u32,
    backoff_policy: BackoffPolicy,
    backoff_delay_ms: u64,
    tags: std.ArrayListUnmanaged([]const u8),
    input_data: ?[]const u8,

    pub fn oneTime(identifier: []const u8) TaskRequest {
        return .{
            .identifier = identifier,
            .task_type = .processing,
            .priority = .normal,
            .constraints = TaskConstraints.defaults(),
            .initial_delay_ms = 0,
            .periodic_interval = null,
            .max_retries = 3,
            .backoff_policy = .exponential,
            .backoff_delay_ms = 30000,
            .tags = .{},
            .input_data = null,
        };
    }

    pub fn periodic(identifier: []const u8, interval: PeriodicInterval) TaskRequest {
        return .{
            .identifier = identifier,
            .task_type = .app_refresh,
            .priority = .normal,
            .constraints = TaskConstraints.defaults(),
            .initial_delay_ms = 0,
            .periodic_interval = interval,
            .max_retries = 0,
            .backoff_policy = .exponential,
            .backoff_delay_ms = 30000,
            .tags = .{},
            .input_data = null,
        };
    }

    pub fn deinit(self: *TaskRequest, allocator: std.mem.Allocator) void {
        self.tags.deinit(allocator);
    }

    pub fn withTaskType(self: TaskRequest, task_type: TaskType) TaskRequest {
        var request = self;
        request.task_type = task_type;
        return request;
    }

    pub fn withPriority(self: TaskRequest, priority: TaskPriority) TaskRequest {
        var request = self;
        request.priority = priority;
        return request;
    }

    pub fn withConstraints(self: TaskRequest, constraints: TaskConstraints) TaskRequest {
        var request = self;
        request.constraints = constraints;
        return request;
    }

    pub fn withInitialDelay(self: TaskRequest, delay_ms: u64) TaskRequest {
        var request = self;
        request.initial_delay_ms = delay_ms;
        return request;
    }

    pub fn withRetries(self: TaskRequest, max_retries: u32, policy: BackoffPolicy, delay_ms: u64) TaskRequest {
        var request = self;
        request.max_retries = max_retries;
        request.backoff_policy = policy;
        request.backoff_delay_ms = delay_ms;
        return request;
    }

    pub fn withInputData(self: TaskRequest, data: []const u8) TaskRequest {
        var request = self;
        request.input_data = data;
        return request;
    }

    pub fn addTag(self: *TaskRequest, allocator: std.mem.Allocator, tag: []const u8) !void {
        try self.tags.append(allocator, tag);
    }

    pub fn isPeriodic(self: *const TaskRequest) bool {
        return self.periodic_interval != null;
    }

    pub fn getNextRunTime(self: *const TaskRequest) u64 {
        const now = getCurrentTimestamp();
        return now + self.initial_delay_ms;
    }

    fn getCurrentTimestamp() u64 {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        return @intCast(ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000));
    }
};

/// Background task info
pub const TaskInfo = struct {
    id: u64,
    identifier: []const u8,
    state: TaskState,
    run_attempt_count: u32,
    scheduled_time: u64,
    last_run_time: ?u64,
    next_run_time: ?u64,
    output_data: ?[]const u8,

    pub fn init(id: u64, identifier: []const u8) TaskInfo {
        return .{
            .id = id,
            .identifier = identifier,
            .state = .pending,
            .run_attempt_count = 0,
            .scheduled_time = getCurrentTimestamp(),
            .last_run_time = null,
            .next_run_time = null,
            .output_data = null,
        };
    }

    pub fn markRunning(self: *TaskInfo) void {
        self.state = .running;
        self.last_run_time = getCurrentTimestamp();
        self.run_attempt_count += 1;
    }

    pub fn markCompleted(self: *TaskInfo) void {
        self.state = .completed;
    }

    pub fn markFailed(self: *TaskInfo) void {
        self.state = .failed;
    }

    pub fn markCancelled(self: *TaskInfo) void {
        self.state = .cancelled;
    }

    pub fn isFinished(self: *const TaskInfo) bool {
        return self.state.isTerminal();
    }

    pub fn canRetry(self: *const TaskInfo, max_retries: u32) bool {
        return !self.isFinished() and self.run_attempt_count < max_retries;
    }

    fn getCurrentTimestamp() u64 {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        return @intCast(ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000));
    }
};

/// Task execution policy
pub const ExecutionPolicy = enum {
    replace, // Replace existing task with same ID
    keep, // Keep existing task
    append, // Allow multiple with same ID

    pub fn toString(self: ExecutionPolicy) []const u8 {
        return switch (self) {
            .replace => "Replace",
            .keep => "Keep",
            .append => "Append",
        };
    }
};

/// Background task scheduler
pub const TaskScheduler = struct {
    allocator: std.mem.Allocator,
    tasks: std.ArrayListUnmanaged(TaskInfo),
    requests: std.ArrayListUnmanaged(TaskRequest),
    next_id: u64,
    is_enabled: bool,
    context: TaskContext,

    pub fn init(allocator: std.mem.Allocator) TaskScheduler {
        return .{
            .allocator = allocator,
            .tasks = .{},
            .requests = .{},
            .next_id = 1,
            .is_enabled = true,
            .context = TaskContext.defaults(),
        };
    }

    pub fn deinit(self: *TaskScheduler) void {
        self.tasks.deinit(self.allocator);
        for (self.requests.items) |*request| {
            request.deinit(self.allocator);
        }
        self.requests.deinit(self.allocator);
    }

    pub fn schedule(self: *TaskScheduler, request: TaskRequest, policy: ExecutionPolicy) !*TaskInfo {
        // Handle existing task policy
        if (policy == .replace) {
            _ = self.cancel(request.identifier);
        } else if (policy == .keep) {
            if (self.getTaskByIdentifier(request.identifier) != null) {
                return error.TaskAlreadyExists;
            }
        }

        const id = self.next_id;
        self.next_id += 1;

        var info = TaskInfo.init(id, request.identifier);
        info.state = .scheduled;
        info.next_run_time = request.getNextRunTime();

        try self.tasks.append(self.allocator, info);
        try self.requests.append(self.allocator, request);

        return &self.tasks.items[self.tasks.items.len - 1];
    }

    pub fn cancel(self: *TaskScheduler, identifier: []const u8) bool {
        for (self.tasks.items) |*task| {
            if (std.mem.eql(u8, task.identifier, identifier) and !task.isFinished()) {
                task.markCancelled();
                return true;
            }
        }
        return false;
    }

    pub fn cancelAll(self: *TaskScheduler) u32 {
        var count: u32 = 0;
        for (self.tasks.items) |*task| {
            if (!task.isFinished()) {
                task.markCancelled();
                count += 1;
            }
        }
        return count;
    }

    pub fn cancelByTag(self: *TaskScheduler, tag: []const u8) u32 {
        var count: u32 = 0;
        for (self.tasks.items, 0..) |*task, i| {
            if (task.isFinished()) continue;

            if (i < self.requests.items.len) {
                for (self.requests.items[i].tags.items) |t| {
                    if (std.mem.eql(u8, t, tag)) {
                        task.markCancelled();
                        count += 1;
                        break;
                    }
                }
            }
        }
        return count;
    }

    pub fn getTaskByIdentifier(self: *const TaskScheduler, identifier: []const u8) ?*const TaskInfo {
        for (self.tasks.items) |*task| {
            if (std.mem.eql(u8, task.identifier, identifier)) {
                return task;
            }
        }
        return null;
    }

    pub fn getTaskById(self: *const TaskScheduler, id: u64) ?*const TaskInfo {
        for (self.tasks.items) |*task| {
            if (task.id == id) {
                return task;
            }
        }
        return null;
    }

    pub fn getPendingTasks(self: *const TaskScheduler) usize {
        var count: usize = 0;
        for (self.tasks.items) |task| {
            if (task.state == .pending or task.state == .scheduled) {
                count += 1;
            }
        }
        return count;
    }

    pub fn getRunningTasks(self: *const TaskScheduler) usize {
        var count: usize = 0;
        for (self.tasks.items) |task| {
            if (task.state == .running) {
                count += 1;
            }
        }
        return count;
    }

    pub fn getCompletedTasks(self: *const TaskScheduler) usize {
        var count: usize = 0;
        for (self.tasks.items) |task| {
            if (task.state == .completed) {
                count += 1;
            }
        }
        return count;
    }

    pub fn setContext(self: *TaskScheduler, context: TaskContext) void {
        self.context = context;
    }

    pub fn setEnabled(self: *TaskScheduler, enabled: bool) void {
        self.is_enabled = enabled;
    }

    pub fn pruneCompletedTasks(self: *TaskScheduler) u32 {
        var removed: u32 = 0;
        var i: usize = 0;
        while (i < self.tasks.items.len) {
            if (self.tasks.items[i].state.isTerminal()) {
                _ = self.tasks.orderedRemove(i);
                if (i < self.requests.items.len) {
                    var req = self.requests.orderedRemove(i);
                    req.deinit(self.allocator);
                }
                removed += 1;
            } else {
                i += 1;
            }
        }
        return removed;
    }

    pub fn taskCount(self: *const TaskScheduler) usize {
        return self.tasks.items.len;
    }
};

/// Foreground service type (Android)
pub const ForegroundServiceType = enum {
    data_sync,
    media_playback,
    phone_call,
    location,
    connected_device,
    media_projection,
    camera,
    microphone,
    health,
    remote_messaging,
    system_exempted,
    short_service,

    pub fn toString(self: ForegroundServiceType) []const u8 {
        return switch (self) {
            .data_sync => "Data Sync",
            .media_playback => "Media Playback",
            .phone_call => "Phone Call",
            .location => "Location",
            .connected_device => "Connected Device",
            .media_projection => "Media Projection",
            .camera => "Camera",
            .microphone => "Microphone",
            .health => "Health",
            .remote_messaging => "Remote Messaging",
            .system_exempted => "System Exempted",
            .short_service => "Short Service",
        };
    }

    pub fn requiresPermission(self: ForegroundServiceType) bool {
        return switch (self) {
            .location, .camera, .microphone, .media_projection => true,
            else => false,
        };
    }
};

/// Background mode (iOS)
pub const BackgroundMode = enum {
    audio,
    location,
    voip,
    fetch,
    remote_notification,
    newsstand_content,
    external_accessory,
    bluetooth_central,
    bluetooth_peripheral,
    processing,

    pub fn toString(self: BackgroundMode) []const u8 {
        return switch (self) {
            .audio => "audio",
            .location => "location",
            .voip => "voip",
            .fetch => "fetch",
            .remote_notification => "remote-notification",
            .newsstand_content => "newsstand-content",
            .external_accessory => "external-accessory",
            .bluetooth_central => "bluetooth-central",
            .bluetooth_peripheral => "bluetooth-peripheral",
            .processing => "processing",
        };
    }

    pub fn plistKey(self: BackgroundMode) []const u8 {
        return self.toString();
    }
};

/// Check if background tasks are available
pub fn isBackgroundTasksAvailable() bool {
    return true; // Stub for platform check
}

/// Get current platform
pub fn currentPlatform() TaskPlatform {
    return .bg_task_scheduler; // Would detect at runtime
}

/// Get minimum periodic interval (platform-specific)
pub fn minimumPeriodicInterval() u32 {
    return 15; // 15 minutes minimum on iOS/Android
}

// ============================================================================
// Tests
// ============================================================================

test "TaskPlatform properties" {
    try std.testing.expectEqualStrings("BGTaskScheduler", TaskPlatform.bg_task_scheduler.toString());
    try std.testing.expect(!TaskPlatform.bg_task_scheduler.supportsExactTiming());
    try std.testing.expect(TaskPlatform.launchd.supportsExactTiming());
}

test "TaskType properties" {
    try std.testing.expectEqualStrings("Processing", TaskType.processing.toString());
    try std.testing.expectEqual(@as(u32, 30), TaskType.processing.defaultTimeoutSeconds());
}

test "TaskState properties" {
    try std.testing.expectEqualStrings("Running", TaskState.running.toString());
    try std.testing.expect(TaskState.completed.isTerminal());
    try std.testing.expect(!TaskState.running.isTerminal());
    try std.testing.expect(TaskState.running.isActive());
}

test "TaskPriority properties" {
    try std.testing.expectEqualStrings("High", TaskPriority.high.toString());
    try std.testing.expectEqual(@as(u8, 10), TaskPriority.expedited.toNumeric());
}

test "NetworkType properties" {
    try std.testing.expectEqualStrings("Unmetered", NetworkType.unmetered.toString());
    try std.testing.expect(NetworkType.connected.requiresNetwork());
    try std.testing.expect(!NetworkType.none.requiresNetwork());
}

test "BackoffPolicy calculateDelay" {
    try std.testing.expectEqual(@as(u64, 3000), BackoffPolicy.linear.calculateDelay(1000, 3));
    try std.testing.expectEqual(@as(u64, 8000), BackoffPolicy.exponential.calculateDelay(1000, 3));
}

test "TaskResult properties" {
    try std.testing.expectEqualStrings("Success", TaskResult.success.toString());
    try std.testing.expect(TaskResult.retry.shouldRetry());
    try std.testing.expect(!TaskResult.success.shouldRetry());
}

test "TaskConstraints builder" {
    const constraints = TaskConstraints.defaults()
        .withNetwork(.unmetered)
        .withCharging(true)
        .withBatteryNotLow(true);
    try std.testing.expectEqual(NetworkType.unmetered, constraints.network_type);
    try std.testing.expect(constraints.requires_charging);
    try std.testing.expect(constraints.hasConstraints());
}

test "TaskConstraints isSatisfied" {
    const constraints = TaskConstraints.defaults()
        .withNetwork(.connected)
        .withCharging(true);

    var ctx = TaskContext.defaults();
    try std.testing.expect(!constraints.isSatisfied(&ctx)); // Not charging

    ctx = ctx.withCharging(true);
    try std.testing.expect(constraints.isSatisfied(&ctx));
}

test "TaskContext builder" {
    const ctx = TaskContext.defaults()
        .withNetwork(false)
        .withBatteryLevel(50);
    try std.testing.expect(!ctx.has_network);
    try std.testing.expectEqual(@as(u8, 50), ctx.battery_level);
}

test "PeriodicInterval creation" {
    const interval = PeriodicInterval.every(30);
    try std.testing.expectEqual(@as(u32, 30), interval.minutes);

    const hours = PeriodicInterval.everyHours(2);
    try std.testing.expectEqual(@as(u32, 120), hours.minutes);

    const days = PeriodicInterval.everyDays(1);
    try std.testing.expectEqual(@as(u32, 1440), days.minutes);
}

test "PeriodicInterval minimum" {
    const interval = PeriodicInterval.every(5); // Below minimum
    try std.testing.expectEqual(@as(u32, 15), interval.minutes); // Should be clamped
}

test "PeriodicInterval flexibility" {
    const interval = PeriodicInterval.every(60).withFlexibility(15);
    try std.testing.expectEqual(@as(?u32, 15), interval.flex_minutes);
}

test "PeriodicInterval toMilliseconds" {
    const interval = PeriodicInterval.every(15);
    try std.testing.expectEqual(@as(u64, 900000), interval.toMilliseconds());
}

test "TaskRequest oneTime" {
    const request = TaskRequest.oneTime("myTask");
    try std.testing.expectEqualStrings("myTask", request.identifier);
    try std.testing.expect(!request.isPeriodic());
}

test "TaskRequest periodic" {
    const request = TaskRequest.periodic("refreshTask", PeriodicInterval.everyHours(1));
    try std.testing.expect(request.isPeriodic());
    try std.testing.expectEqual(@as(u32, 60), request.periodic_interval.?.minutes);
}

test "TaskRequest builder" {
    const request = TaskRequest.oneTime("task1")
        .withTaskType(.connectivity)
        .withPriority(.high)
        .withInitialDelay(5000)
        .withRetries(5, .linear, 10000);
    try std.testing.expectEqual(TaskType.connectivity, request.task_type);
    try std.testing.expectEqual(TaskPriority.high, request.priority);
    try std.testing.expectEqual(@as(u64, 5000), request.initial_delay_ms);
    try std.testing.expectEqual(@as(u32, 5), request.max_retries);
}

test "TaskInfo lifecycle" {
    var info = TaskInfo.init(1, "testTask");
    try std.testing.expectEqual(TaskState.pending, info.state);
    try std.testing.expect(!info.isFinished());

    info.markRunning();
    try std.testing.expectEqual(TaskState.running, info.state);
    try std.testing.expectEqual(@as(u32, 1), info.run_attempt_count);

    info.markCompleted();
    try std.testing.expect(info.isFinished());
}

test "TaskInfo canRetry" {
    var info = TaskInfo.init(1, "testTask");
    try std.testing.expect(info.canRetry(3));

    info.run_attempt_count = 3;
    try std.testing.expect(!info.canRetry(3));
}

test "ExecutionPolicy toString" {
    try std.testing.expectEqualStrings("Replace", ExecutionPolicy.replace.toString());
}

test "TaskScheduler init and deinit" {
    var scheduler = TaskScheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    try std.testing.expectEqual(@as(usize, 0), scheduler.taskCount());
    try std.testing.expect(scheduler.is_enabled);
}

test "TaskScheduler schedule" {
    var scheduler = TaskScheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    const request = TaskRequest.oneTime("task1");
    const info = try scheduler.schedule(request, .replace);

    try std.testing.expectEqual(@as(u64, 1), info.id);
    try std.testing.expectEqual(TaskState.scheduled, info.state);
    try std.testing.expectEqual(@as(usize, 1), scheduler.taskCount());
}

test "TaskScheduler cancel" {
    var scheduler = TaskScheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    _ = try scheduler.schedule(TaskRequest.oneTime("task1"), .replace);
    try std.testing.expect(scheduler.cancel("task1"));
    try std.testing.expect(!scheduler.cancel("nonexistent"));
}

test "TaskScheduler cancelAll" {
    var scheduler = TaskScheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    _ = try scheduler.schedule(TaskRequest.oneTime("task1"), .replace);
    _ = try scheduler.schedule(TaskRequest.oneTime("task2"), .replace);

    try std.testing.expectEqual(@as(u32, 2), scheduler.cancelAll());
}

test "TaskScheduler getPendingTasks" {
    var scheduler = TaskScheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    _ = try scheduler.schedule(TaskRequest.oneTime("task1"), .replace);
    _ = try scheduler.schedule(TaskRequest.oneTime("task2"), .replace);

    try std.testing.expectEqual(@as(usize, 2), scheduler.getPendingTasks());
}

test "TaskScheduler policy keep" {
    var scheduler = TaskScheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    _ = try scheduler.schedule(TaskRequest.oneTime("task1"), .replace);

    const result = scheduler.schedule(TaskRequest.oneTime("task1"), .keep);
    try std.testing.expectError(error.TaskAlreadyExists, result);
}

test "ForegroundServiceType properties" {
    try std.testing.expectEqualStrings("Location", ForegroundServiceType.location.toString());
    try std.testing.expect(ForegroundServiceType.location.requiresPermission());
    try std.testing.expect(!ForegroundServiceType.data_sync.requiresPermission());
}

test "BackgroundMode properties" {
    try std.testing.expectEqualStrings("audio", BackgroundMode.audio.toString());
    try std.testing.expectEqualStrings("remote-notification", BackgroundMode.remote_notification.plistKey());
}

test "isBackgroundTasksAvailable" {
    try std.testing.expect(isBackgroundTasksAvailable());
}

test "currentPlatform" {
    try std.testing.expectEqual(TaskPlatform.bg_task_scheduler, currentPlatform());
}

test "minimumPeriodicInterval" {
    try std.testing.expectEqual(@as(u32, 15), minimumPeriodicInterval());
}
