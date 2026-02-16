//! Cross-platform crash reporting and analytics module
//! Provides abstractions for Crashlytics, Sentry, Bugsnag, and native crash handlers

const std = @import("std");

/// Crash reporting provider
pub const CrashProvider = enum {
    firebase_crashlytics,
    sentry,
    bugsnag,
    appcenter,
    raygun,
    rollbar,
    native, // Platform native crash reporting

    pub fn toString(self: CrashProvider) []const u8 {
        return switch (self) {
            .firebase_crashlytics => "Firebase Crashlytics",
            .sentry => "Sentry",
            .bugsnag => "Bugsnag",
            .appcenter => "App Center",
            .raygun => "Raygun",
            .rollbar => "Rollbar",
            .native => "Native",
        };
    }

    pub fn supportsNDK(self: CrashProvider) bool {
        return switch (self) {
            .firebase_crashlytics, .sentry, .bugsnag => true,
            else => false,
        };
    }

    pub fn supportsSourceMaps(self: CrashProvider) bool {
        return switch (self) {
            .sentry, .bugsnag, .rollbar => true,
            else => false,
        };
    }
};

/// Crash severity level
pub const Severity = enum {
    debug,
    info,
    warning,
    error_level,
    fatal,

    pub fn toString(self: Severity) []const u8 {
        return switch (self) {
            .debug => "Debug",
            .info => "Info",
            .warning => "Warning",
            .error_level => "Error",
            .fatal => "Fatal",
        };
    }

    pub fn toNumeric(self: Severity) u8 {
        return switch (self) {
            .debug => 0,
            .info => 1,
            .warning => 2,
            .error_level => 3,
            .fatal => 4,
        };
    }

    pub fn isCritical(self: Severity) bool {
        return self == .error_level or self == .fatal;
    }
};

/// Exception type
pub const ExceptionType = enum {
    runtime,
    null_pointer,
    out_of_bounds,
    out_of_memory,
    assertion,
    signal,
    anr, // Application Not Responding
    native,
    custom,

    pub fn toString(self: ExceptionType) []const u8 {
        return switch (self) {
            .runtime => "RuntimeException",
            .null_pointer => "NullPointerException",
            .out_of_bounds => "IndexOutOfBoundsException",
            .out_of_memory => "OutOfMemoryError",
            .assertion => "AssertionError",
            .signal => "Signal",
            .anr => "ANR",
            .native => "NativeException",
            .custom => "CustomException",
        };
    }

    pub fn isNative(self: ExceptionType) bool {
        return self == .signal or self == .native;
    }
};

/// Stack frame information
pub const StackFrame = struct {
    function_name: ?[]const u8,
    file_name: ?[]const u8,
    line_number: ?u32,
    column_number: ?u32,
    address: ?u64,
    module_name: ?[]const u8,
    is_in_app: bool,

    pub fn init() StackFrame {
        return .{
            .function_name = null,
            .file_name = null,
            .line_number = null,
            .column_number = null,
            .address = null,
            .module_name = null,
            .is_in_app = true,
        };
    }

    pub fn withFunction(self: StackFrame, name: []const u8) StackFrame {
        var frame = self;
        frame.function_name = name;
        return frame;
    }

    pub fn withLocation(self: StackFrame, file: []const u8, line: u32) StackFrame {
        var frame = self;
        frame.file_name = file;
        frame.line_number = line;
        return frame;
    }

    pub fn withAddress(self: StackFrame, addr: u64) StackFrame {
        var frame = self;
        frame.address = addr;
        return frame;
    }

    pub fn withModule(self: StackFrame, module: []const u8) StackFrame {
        var frame = self;
        frame.module_name = module;
        return frame;
    }

    pub fn asSystemFrame(self: StackFrame) StackFrame {
        var frame = self;
        frame.is_in_app = false;
        return frame;
    }

    pub fn hasSymbols(self: *const StackFrame) bool {
        return self.function_name != null;
    }
};

/// Stack trace
pub const StackTrace = struct {
    frames: std.ArrayListUnmanaged(StackFrame),
    thread_id: ?u64,
    thread_name: ?[]const u8,
    is_crashed_thread: bool,

    pub fn init() StackTrace {
        return .{
            .frames = .{},
            .thread_id = null,
            .thread_name = null,
            .is_crashed_thread = true,
        };
    }

    pub fn deinit(self: *StackTrace, allocator: std.mem.Allocator) void {
        self.frames.deinit(allocator);
    }

    pub fn addFrame(self: *StackTrace, allocator: std.mem.Allocator, frame: StackFrame) !void {
        try self.frames.append(allocator, frame);
    }

    pub fn withThread(self: StackTrace, id: u64, name: ?[]const u8) StackTrace {
        var trace = self;
        trace.thread_id = id;
        trace.thread_name = name;
        return trace;
    }

    pub fn frameCount(self: *const StackTrace) usize {
        return self.frames.items.len;
    }

    pub fn getTopFrame(self: *const StackTrace) ?StackFrame {
        if (self.frames.items.len == 0) return null;
        return self.frames.items[0];
    }

    pub fn getInAppFrames(self: *const StackTrace) usize {
        var count: usize = 0;
        for (self.frames.items) |frame| {
            if (frame.is_in_app) count += 1;
        }
        return count;
    }
};

/// Breadcrumb for crash context
pub const Breadcrumb = struct {
    timestamp: u64,
    category: []const u8,
    message: []const u8,
    level: Severity,
    breadcrumb_type: BreadcrumbType,
    data: std.StringHashMapUnmanaged([]const u8),

    pub const BreadcrumbType = enum {
        navigation,
        http,
        user,
        system,
        query,
        log,
        custom,

        pub fn toString(self: BreadcrumbType) []const u8 {
            return switch (self) {
                .navigation => "navigation",
                .http => "http",
                .user => "user",
                .system => "system",
                .query => "query",
                .log => "log",
                .custom => "custom",
            };
        }
    };

    pub fn init(category: []const u8, message: []const u8) Breadcrumb {
        return .{
            .timestamp = getCurrentTimestamp(),
            .category = category,
            .message = message,
            .level = .info,
            .breadcrumb_type = .custom,
            .data = .{},
        };
    }

    pub fn deinit(self: *Breadcrumb, allocator: std.mem.Allocator) void {
        self.data.deinit(allocator);
    }

    pub fn navigation(from: []const u8, to: []const u8) Breadcrumb {
        _ = from;
        return .{
            .timestamp = getCurrentTimestamp(),
            .category = "navigation",
            .message = to,
            .level = .info,
            .breadcrumb_type = .navigation,
            .data = .{},
        };
    }

    pub fn http(method: []const u8, url: []const u8, status: u16) Breadcrumb {
        _ = method;
        _ = status;
        return .{
            .timestamp = getCurrentTimestamp(),
            .category = "http",
            .message = url,
            .level = .info,
            .breadcrumb_type = .http,
            .data = .{},
        };
    }

    pub fn user(action: []const u8) Breadcrumb {
        return .{
            .timestamp = getCurrentTimestamp(),
            .category = "user",
            .message = action,
            .level = .info,
            .breadcrumb_type = .user,
            .data = .{},
        };
    }

    pub fn withLevel(self: Breadcrumb, level: Severity) Breadcrumb {
        var crumb = self;
        crumb.level = level;
        return crumb;
    }

    pub fn setData(self: *Breadcrumb, allocator: std.mem.Allocator, key: []const u8, value: []const u8) !void {
        try self.data.put(allocator, key, value);
    }

    fn getCurrentTimestamp() u64 {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            return @intCast(ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000));
        }
        return 0;
    }
};

/// Device information
pub const DeviceInfo = struct {
    model: ?[]const u8,
    manufacturer: ?[]const u8,
    os_name: ?[]const u8,
    os_version: ?[]const u8,
    arch: ?[]const u8,
    memory_total: ?u64,
    memory_free: ?u64,
    storage_total: ?u64,
    storage_free: ?u64,
    is_emulator: bool,
    is_rooted: bool,

    pub fn init() DeviceInfo {
        return .{
            .model = null,
            .manufacturer = null,
            .os_name = null,
            .os_version = null,
            .arch = null,
            .memory_total = null,
            .memory_free = null,
            .storage_total = null,
            .storage_free = null,
            .is_emulator = false,
            .is_rooted = false,
        };
    }

    pub fn withModel(self: DeviceInfo, model: []const u8, manufacturer: []const u8) DeviceInfo {
        var info = self;
        info.model = model;
        info.manufacturer = manufacturer;
        return info;
    }

    pub fn withOS(self: DeviceInfo, name: []const u8, version: []const u8) DeviceInfo {
        var info = self;
        info.os_name = name;
        info.os_version = version;
        return info;
    }

    pub fn withArch(self: DeviceInfo, arch: []const u8) DeviceInfo {
        var info = self;
        info.arch = arch;
        return info;
    }

    pub fn withMemory(self: DeviceInfo, total: u64, free: u64) DeviceInfo {
        var info = self;
        info.memory_total = total;
        info.memory_free = free;
        return info;
    }

    pub fn getMemoryUsagePercent(self: *const DeviceInfo) ?f32 {
        if (self.memory_total) |total| {
            if (self.memory_free) |free| {
                if (total > 0) {
                    return @as(f32, @floatFromInt(total - free)) / @as(f32, @floatFromInt(total)) * 100.0;
                }
            }
        }
        return null;
    }
};

/// App information
pub const AppInfo = struct {
    name: ?[]const u8,
    version: ?[]const u8,
    build: ?[]const u8,
    bundle_id: ?[]const u8,
    environment: Environment,

    pub const Environment = enum {
        development,
        staging,
        production,

        pub fn toString(self: Environment) []const u8 {
            return switch (self) {
                .development => "development",
                .staging => "staging",
                .production => "production",
            };
        }
    };

    pub fn init() AppInfo {
        return .{
            .name = null,
            .version = null,
            .build = null,
            .bundle_id = null,
            .environment = .development,
        };
    }

    pub fn withVersion(self: AppInfo, version: []const u8, build: []const u8) AppInfo {
        var info = self;
        info.version = version;
        info.build = build;
        return info;
    }

    pub fn withBundleId(self: AppInfo, bundle_id: []const u8) AppInfo {
        var info = self;
        info.bundle_id = bundle_id;
        return info;
    }

    pub fn withEnvironment(self: AppInfo, env: Environment) AppInfo {
        var info = self;
        info.environment = env;
        return info;
    }

    pub fn getFullVersion(self: *const AppInfo) ?[]const u8 {
        if (self.version) |v| {
            return v;
        }
        return null;
    }
};

/// User information for crash reports
pub const UserInfo = struct {
    id: ?[]const u8,
    email: ?[]const u8,
    username: ?[]const u8,
    custom_data: std.StringHashMapUnmanaged([]const u8),

    pub fn init() UserInfo {
        return .{
            .id = null,
            .email = null,
            .username = null,
            .custom_data = .{},
        };
    }

    pub fn deinit(self: *UserInfo, allocator: std.mem.Allocator) void {
        self.custom_data.deinit(allocator);
    }

    pub fn withId(self: UserInfo, id: []const u8) UserInfo {
        var info = self;
        info.id = id;
        return info;
    }

    pub fn withEmail(self: UserInfo, email: []const u8) UserInfo {
        var info = self;
        info.email = email;
        return info;
    }

    pub fn withUsername(self: UserInfo, username: []const u8) UserInfo {
        var info = self;
        info.username = username;
        return info;
    }

    pub fn setCustomData(self: *UserInfo, allocator: std.mem.Allocator, key: []const u8, value: []const u8) !void {
        try self.custom_data.put(allocator, key, value);
    }

    pub fn isIdentified(self: *const UserInfo) bool {
        return self.id != null or self.email != null;
    }
};

/// Crash event
pub const CrashEvent = struct {
    id: u64,
    timestamp: u64,
    exception_type: ExceptionType,
    message: []const u8,
    severity: Severity,
    stack_trace: StackTrace,
    device_info: DeviceInfo,
    app_info: AppInfo,
    user_info: ?UserInfo,
    tags: std.StringHashMapUnmanaged([]const u8),
    extra: std.StringHashMapUnmanaged([]const u8),
    is_handled: bool,
    is_fatal: bool,

    pub fn init(allocator: std.mem.Allocator, id: u64, message: []const u8) CrashEvent {
        _ = allocator;
        return .{
            .id = id,
            .timestamp = getCurrentTimestamp(),
            .exception_type = .runtime,
            .message = message,
            .severity = .error_level,
            .stack_trace = StackTrace.init(),
            .device_info = DeviceInfo.init(),
            .app_info = AppInfo.init(),
            .user_info = null,
            .tags = .{},
            .extra = .{},
            .is_handled = true,
            .is_fatal = false,
        };
    }

    pub fn deinit(self: *CrashEvent, allocator: std.mem.Allocator) void {
        self.stack_trace.deinit(allocator);
        self.tags.deinit(allocator);
        self.extra.deinit(allocator);
        if (self.user_info) |*user| {
            user.deinit(allocator);
        }
    }

    pub fn withExceptionType(self: CrashEvent, exception_type: ExceptionType) CrashEvent {
        var event = self;
        event.exception_type = exception_type;
        return event;
    }

    pub fn withSeverity(self: CrashEvent, severity: Severity) CrashEvent {
        var event = self;
        event.severity = severity;
        if (severity == .fatal) {
            event.is_fatal = true;
        }
        return event;
    }

    pub fn unhandled(self: CrashEvent) CrashEvent {
        var event = self;
        event.is_handled = false;
        event.is_fatal = true;
        event.severity = .fatal;
        return event;
    }

    pub fn setTag(self: *CrashEvent, allocator: std.mem.Allocator, key: []const u8, value: []const u8) !void {
        try self.tags.put(allocator, key, value);
    }

    pub fn setExtra(self: *CrashEvent, allocator: std.mem.Allocator, key: []const u8, value: []const u8) !void {
        try self.extra.put(allocator, key, value);
    }

    pub fn addStackFrame(self: *CrashEvent, allocator: std.mem.Allocator, frame: StackFrame) !void {
        try self.stack_trace.addFrame(allocator, frame);
    }

    fn getCurrentTimestamp() u64 {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            return @intCast(ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000));
        }
        return 0;
    }
};

/// Crash reporter configuration
pub const CrashConfig = struct {
    provider: CrashProvider,
    dsn: ?[]const u8, // Data Source Name (Sentry)
    api_key: ?[]const u8,
    is_enabled: bool,
    collect_device_info: bool,
    collect_breadcrumbs: bool,
    max_breadcrumbs: u32,
    attach_screenshots: bool,
    attach_logs: bool,
    sample_rate: f32, // 0.0 - 1.0
    environment: AppInfo.Environment,

    pub fn defaults(provider: CrashProvider) CrashConfig {
        return .{
            .provider = provider,
            .dsn = null,
            .api_key = null,
            .is_enabled = true,
            .collect_device_info = true,
            .collect_breadcrumbs = true,
            .max_breadcrumbs = 100,
            .attach_screenshots = false,
            .attach_logs = true,
            .sample_rate = 1.0,
            .environment = .production,
        };
    }

    pub fn withDSN(self: CrashConfig, dsn: []const u8) CrashConfig {
        var config = self;
        config.dsn = dsn;
        return config;
    }

    pub fn withApiKey(self: CrashConfig, key: []const u8) CrashConfig {
        var config = self;
        config.api_key = key;
        return config;
    }

    pub fn withSampleRate(self: CrashConfig, rate: f32) CrashConfig {
        var config = self;
        config.sample_rate = std.math.clamp(rate, 0.0, 1.0);
        return config;
    }

    pub fn withEnvironment(self: CrashConfig, env: AppInfo.Environment) CrashConfig {
        var config = self;
        config.environment = env;
        return config;
    }

    pub fn withScreenshots(self: CrashConfig, enabled: bool) CrashConfig {
        var config = self;
        config.attach_screenshots = enabled;
        return config;
    }

    pub fn isConfigured(self: *const CrashConfig) bool {
        return self.dsn != null or self.api_key != null;
    }
};

/// Crash reporter
pub const CrashReporter = struct {
    allocator: std.mem.Allocator,
    config: CrashConfig,
    breadcrumbs: std.ArrayListUnmanaged(Breadcrumb),
    events: std.ArrayListUnmanaged(CrashEvent),
    user_info: ?UserInfo,
    global_tags: std.StringHashMapUnmanaged([]const u8),
    is_initialized: bool,
    next_id: u64,

    pub fn init(allocator: std.mem.Allocator, config: CrashConfig) CrashReporter {
        return .{
            .allocator = allocator,
            .config = config,
            .breadcrumbs = .{},
            .events = .{},
            .user_info = null,
            .global_tags = .{},
            .is_initialized = false,
            .next_id = 1,
        };
    }

    pub fn deinit(self: *CrashReporter) void {
        for (self.breadcrumbs.items) |*crumb| {
            crumb.deinit(self.allocator);
        }
        self.breadcrumbs.deinit(self.allocator);
        for (self.events.items) |*event| {
            event.deinit(self.allocator);
        }
        self.events.deinit(self.allocator);
        if (self.user_info) |*user| {
            user.deinit(self.allocator);
        }
        self.global_tags.deinit(self.allocator);
    }

    pub fn start(self: *CrashReporter) !void {
        if (!self.config.is_enabled) return;
        if (!self.config.isConfigured()) return error.NotConfigured;
        self.is_initialized = true;
    }

    pub fn stop(self: *CrashReporter) void {
        self.is_initialized = false;
    }

    pub fn setUser(self: *CrashReporter, user: UserInfo) void {
        self.user_info = user;
    }

    pub fn clearUser(self: *CrashReporter) void {
        if (self.user_info) |*user| {
            user.deinit(self.allocator);
        }
        self.user_info = null;
    }

    pub fn setTag(self: *CrashReporter, key: []const u8, value: []const u8) !void {
        try self.global_tags.put(self.allocator, key, value);
    }

    pub fn addBreadcrumb(self: *CrashReporter, crumb: Breadcrumb) !void {
        if (!self.config.collect_breadcrumbs) return;

        if (self.breadcrumbs.items.len >= self.config.max_breadcrumbs) {
            var old = self.breadcrumbs.orderedRemove(0);
            old.deinit(self.allocator);
        }
        try self.breadcrumbs.append(self.allocator, crumb);
    }

    pub fn captureException(self: *CrashReporter, message: []const u8, exception_type: ExceptionType) !*CrashEvent {
        const id = self.next_id;
        self.next_id += 1;

        var event = CrashEvent.init(self.allocator, id, message)
            .withExceptionType(exception_type);

        if (self.user_info) |user| {
            event.user_info = user;
        }

        try self.events.append(self.allocator, event);
        return &self.events.items[self.events.items.len - 1];
    }

    pub fn captureMessage(self: *CrashReporter, message: []const u8, severity: Severity) !void {
        const id = self.next_id;
        self.next_id += 1;

        const event = CrashEvent.init(self.allocator, id, message)
            .withSeverity(severity);

        try self.events.append(self.allocator, event);
    }

    pub fn recordNonFatal(self: *CrashReporter, message: []const u8) !void {
        try self.captureMessage(message, .error_level);
    }

    pub fn recordFatal(self: *CrashReporter, message: []const u8) !*CrashEvent {
        const event = try self.captureException(message, .runtime);
        self.events.items[self.events.items.len - 1] = event.*.unhandled();
        return &self.events.items[self.events.items.len - 1];
    }

    pub fn breadcrumbCount(self: *const CrashReporter) usize {
        return self.breadcrumbs.items.len;
    }

    pub fn eventCount(self: *const CrashReporter) usize {
        return self.events.items.len;
    }

    pub fn clearBreadcrumbs(self: *CrashReporter) void {
        for (self.breadcrumbs.items) |*crumb| {
            crumb.deinit(self.allocator);
        }
        self.breadcrumbs.clearRetainingCapacity();
    }

    pub fn getUnsentEvents(self: *const CrashReporter) usize {
        return self.events.items.len;
    }
};

/// Signal handler types (for native crashes)
pub const Signal = enum {
    sigabrt,
    sigbus,
    sigfpe,
    sigill,
    sigsegv,
    sigtrap,

    pub fn toString(self: Signal) []const u8 {
        return switch (self) {
            .sigabrt => "SIGABRT",
            .sigbus => "SIGBUS",
            .sigfpe => "SIGFPE",
            .sigill => "SIGILL",
            .sigsegv => "SIGSEGV",
            .sigtrap => "SIGTRAP",
        };
    }

    pub fn toCode(self: Signal) i32 {
        return switch (self) {
            .sigabrt => 6,
            .sigbus => 10,
            .sigfpe => 8,
            .sigill => 4,
            .sigsegv => 11,
            .sigtrap => 5,
        };
    }

    pub fn description(self: Signal) []const u8 {
        return switch (self) {
            .sigabrt => "Abort signal",
            .sigbus => "Bus error",
            .sigfpe => "Floating-point exception",
            .sigill => "Illegal instruction",
            .sigsegv => "Segmentation fault",
            .sigtrap => "Trace/breakpoint trap",
        };
    }
};

/// Check if crash reporting is available
pub fn isCrashReportingAvailable() bool {
    return true; // Stub for platform check
}

/// Get current platform's native crash handler
pub fn nativeCrashHandler() CrashProvider {
    return .native;
}

// ============================================================================
// Tests
// ============================================================================

test "CrashProvider properties" {
    try std.testing.expectEqualStrings("Firebase Crashlytics", CrashProvider.firebase_crashlytics.toString());
    try std.testing.expect(CrashProvider.sentry.supportsNDK());
    try std.testing.expect(CrashProvider.sentry.supportsSourceMaps());
}

test "Severity properties" {
    try std.testing.expectEqualStrings("Error", Severity.error_level.toString());
    try std.testing.expectEqual(@as(u8, 4), Severity.fatal.toNumeric());
    try std.testing.expect(Severity.fatal.isCritical());
    try std.testing.expect(!Severity.warning.isCritical());
}

test "ExceptionType properties" {
    try std.testing.expectEqualStrings("NullPointerException", ExceptionType.null_pointer.toString());
    try std.testing.expect(ExceptionType.signal.isNative());
    try std.testing.expect(!ExceptionType.runtime.isNative());
}

test "StackFrame builder" {
    const frame = StackFrame.init()
        .withFunction("main")
        .withLocation("main.zig", 42)
        .withAddress(0x12345678);
    try std.testing.expectEqualStrings("main", frame.function_name.?);
    try std.testing.expectEqual(@as(u32, 42), frame.line_number.?);
    try std.testing.expect(frame.hasSymbols());
}

test "StackFrame system frame" {
    const frame = StackFrame.init().asSystemFrame();
    try std.testing.expect(!frame.is_in_app);
}

test "StackTrace operations" {
    var trace = StackTrace.init();
    defer trace.deinit(std.testing.allocator);

    try trace.addFrame(std.testing.allocator, StackFrame.init().withFunction("func1"));
    try trace.addFrame(std.testing.allocator, StackFrame.init().withFunction("func2").asSystemFrame());

    try std.testing.expectEqual(@as(usize, 2), trace.frameCount());
    try std.testing.expectEqual(@as(usize, 1), trace.getInAppFrames());
}

test "StackTrace thread" {
    const trace = StackTrace.init().withThread(123, "main");
    try std.testing.expectEqual(@as(?u64, 123), trace.thread_id);
    try std.testing.expectEqualStrings("main", trace.thread_name.?);
}

test "Breadcrumb init" {
    const crumb = Breadcrumb.init("test", "Test message");
    try std.testing.expectEqualStrings("test", crumb.category);
    try std.testing.expectEqualStrings("Test message", crumb.message);
    try std.testing.expect(crumb.timestamp > 0);
}

test "Breadcrumb navigation" {
    const crumb = Breadcrumb.navigation("/home", "/settings");
    try std.testing.expectEqual(Breadcrumb.BreadcrumbType.navigation, crumb.breadcrumb_type);
}

test "Breadcrumb user" {
    const crumb = Breadcrumb.user("button_click");
    try std.testing.expectEqual(Breadcrumb.BreadcrumbType.user, crumb.breadcrumb_type);
}

test "Breadcrumb withLevel" {
    const crumb = Breadcrumb.init("test", "msg").withLevel(.warning);
    try std.testing.expectEqual(Severity.warning, crumb.level);
}

test "DeviceInfo builder" {
    const info = DeviceInfo.init()
        .withModel("iPhone 15", "Apple")
        .withOS("iOS", "17.0")
        .withMemory(8000000000, 2000000000);
    try std.testing.expectEqualStrings("iPhone 15", info.model.?);
    try std.testing.expectEqualStrings("iOS", info.os_name.?);
}

test "DeviceInfo memory usage" {
    const info = DeviceInfo.init().withMemory(100, 25);
    const usage = info.getMemoryUsagePercent().?;
    try std.testing.expect(usage > 74.0 and usage < 76.0);
}

test "AppInfo builder" {
    const info = AppInfo.init()
        .withVersion("1.0.0", "100")
        .withBundleId("com.example.app")
        .withEnvironment(.production);
    try std.testing.expectEqualStrings("1.0.0", info.version.?);
    try std.testing.expectEqual(AppInfo.Environment.production, info.environment);
}

test "UserInfo builder" {
    const info = UserInfo.init()
        .withId("user123")
        .withEmail("user@example.com");
    try std.testing.expect(info.isIdentified());
    try std.testing.expectEqualStrings("user123", info.id.?);
}

test "UserInfo not identified" {
    const info = UserInfo.init();
    try std.testing.expect(!info.isIdentified());
}

test "CrashEvent init" {
    var event = CrashEvent.init(std.testing.allocator, 1, "Test crash");
    defer event.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u64, 1), event.id);
    try std.testing.expectEqualStrings("Test crash", event.message);
    try std.testing.expect(event.is_handled);
}

test "CrashEvent unhandled" {
    var event = CrashEvent.init(std.testing.allocator, 1, "Fatal crash").unhandled();
    defer event.deinit(std.testing.allocator);

    try std.testing.expect(!event.is_handled);
    try std.testing.expect(event.is_fatal);
    try std.testing.expectEqual(Severity.fatal, event.severity);
}

test "CrashConfig defaults" {
    const config = CrashConfig.defaults(.sentry);
    try std.testing.expectEqual(CrashProvider.sentry, config.provider);
    try std.testing.expect(config.is_enabled);
    try std.testing.expectEqual(@as(f32, 1.0), config.sample_rate);
}

test "CrashConfig builder" {
    const config = CrashConfig.defaults(.sentry)
        .withDSN("https://key@sentry.io/123")
        .withSampleRate(0.5)
        .withEnvironment(.staging);
    try std.testing.expect(config.isConfigured());
    try std.testing.expectEqual(@as(f32, 0.5), config.sample_rate);
}

test "CrashReporter init and deinit" {
    const config = CrashConfig.defaults(.sentry).withDSN("test");
    var reporter = CrashReporter.init(std.testing.allocator, config);
    defer reporter.deinit();

    try std.testing.expect(!reporter.is_initialized);
}

test "CrashReporter start" {
    const config = CrashConfig.defaults(.sentry).withDSN("test");
    var reporter = CrashReporter.init(std.testing.allocator, config);
    defer reporter.deinit();

    try reporter.start();
    try std.testing.expect(reporter.is_initialized);
}

test "CrashReporter breadcrumbs" {
    const config = CrashConfig.defaults(.sentry).withDSN("test");
    var reporter = CrashReporter.init(std.testing.allocator, config);
    defer reporter.deinit();

    try reporter.addBreadcrumb(Breadcrumb.user("click"));
    try reporter.addBreadcrumb(Breadcrumb.navigation("/a", "/b"));

    try std.testing.expectEqual(@as(usize, 2), reporter.breadcrumbCount());
}

test "CrashReporter captureException" {
    const config = CrashConfig.defaults(.sentry).withDSN("test");
    var reporter = CrashReporter.init(std.testing.allocator, config);
    defer reporter.deinit();

    _ = try reporter.captureException("Test error", .runtime);
    try std.testing.expectEqual(@as(usize, 1), reporter.eventCount());
}

test "CrashReporter user" {
    const config = CrashConfig.defaults(.sentry).withDSN("test");
    var reporter = CrashReporter.init(std.testing.allocator, config);
    defer reporter.deinit();

    reporter.setUser(UserInfo.init().withId("user1"));
    try std.testing.expect(reporter.user_info != null);

    reporter.clearUser();
    try std.testing.expect(reporter.user_info == null);
}

test "Signal properties" {
    try std.testing.expectEqualStrings("SIGSEGV", Signal.sigsegv.toString());
    try std.testing.expectEqual(@as(i32, 11), Signal.sigsegv.toCode());
    try std.testing.expectEqualStrings("Segmentation fault", Signal.sigsegv.description());
}

test "isCrashReportingAvailable" {
    try std.testing.expect(isCrashReportingAvailable());
}

test "nativeCrashHandler" {
    try std.testing.expectEqual(CrashProvider.native, nativeCrashHandler());
}
