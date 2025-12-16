const std = @import("std");
const plugin_security = @import("plugin_security.zig");
const wasm = @import("wasm.zig");

/// Unified Plugin System
/// Integrates WASM runtime with security sandbox and permission management

pub const PluginManifest = struct {
    id: []const u8,
    name: []const u8,
    version: []const u8,
    author: []const u8,
    description: []const u8,
    homepage: ?[]const u8 = null,
    repository: ?[]const u8 = null,
    license: ?[]const u8 = null,
    main: []const u8, // Entry point (WASM file or JS file)
    permissions: []const []const u8 = &.{},
    hooks: []const []const u8 = &.{}, // Event hooks this plugin handles

    pub fn parseJson(allocator: std.mem.Allocator, json: []const u8) !PluginManifest {
        _ = allocator;
        _ = json;
        // Simplified JSON parsing - would use a proper JSON parser
        return PluginManifest{
            .id = "unknown",
            .name = "Unknown",
            .version = "0.0.0",
            .author = "Unknown",
            .description = "",
            .main = "main.wasm",
        };
    }

    pub fn getSecurityPolicy(self: *const PluginManifest) plugin_security.SecurityPolicy {
        // Determine security policy based on requested permissions
        var has_elevated = false;
        var has_dangerous = false;

        for (self.permissions) |perm| {
            if (std.mem.eql(u8, perm, "execute_commands") or
                std.mem.eql(u8, perm, "native_modules"))
            {
                has_elevated = true;
            }
            if (std.mem.eql(u8, perm, "unrestricted")) {
                has_dangerous = true;
            }
        }

        if (has_dangerous) return .unrestricted;
        if (has_elevated) return .elevated;
        if (self.permissions.len > 4) return .standard;
        return .minimal;
    }
};

/// Plugin event types
pub const PluginEvent = enum {
    // Lifecycle events
    app_ready,
    app_will_quit,
    window_created,
    window_closed,
    window_focused,
    window_blurred,

    // File events
    file_opened,
    file_saved,
    file_closed,

    // Editor events
    text_changed,
    selection_changed,
    cursor_moved,

    // UI events
    menu_clicked,
    shortcut_pressed,
    context_menu,

    // Custom events
    custom,
};

pub const EventData = struct {
    event_type: PluginEvent,
    payload: ?[]const u8 = null,
    source: ?[]const u8 = null,
    timestamp: i64,

    pub fn init(event_type: PluginEvent) EventData {
        return .{
            .event_type = event_type,
            .timestamp = std.time.milliTimestamp(),
        };
    }

    pub fn withPayload(self: EventData, payload: []const u8) EventData {
        var copy = self;
        copy.payload = payload;
        return copy;
    }
};

/// Plugin host API - functions exposed to plugins
pub const HostAPI = struct {
    // Logging
    pub fn log(level: LogLevel, message: []const u8) void {
        const level_str = switch (level) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
        };
        std.debug.print("[Plugin {s}] {s}\n", .{ level_str, message });
    }

    pub const LogLevel = enum { debug, info, warn, err };

    // Config storage
    pub fn getConfig(plugin_id: []const u8, key: []const u8) ?[]const u8 {
        _ = plugin_id;
        _ = key;
        // Would load from persistent storage
        return null;
    }

    pub fn setConfig(plugin_id: []const u8, key: []const u8, value: []const u8) !void {
        _ = plugin_id;
        _ = key;
        _ = value;
        // Would save to persistent storage
    }

    // UI integration
    pub fn showNotification(title: []const u8, body: []const u8) void {
        std.debug.print("[Notification] {s}: {s}\n", .{ title, body });
    }

    pub fn showQuickPick(items: []const []const u8) !?usize {
        _ = items;
        return null;
    }

    pub fn showInputBox(prompt: []const u8, default_value: ?[]const u8) !?[]const u8 {
        _ = prompt;
        _ = default_value;
        return null;
    }

    // Editor integration
    pub fn getCurrentDocument() ?[]const u8 {
        return null;
    }

    pub fn getSelection() ?struct { start: usize, end: usize } {
        return null;
    }

    pub fn insertText(text: []const u8, position: ?usize) !void {
        _ = text;
        _ = position;
    }

    pub fn replaceSelection(text: []const u8) !void {
        _ = text;
    }

    // Command registration
    pub fn registerCommand(name: []const u8, callback: *const fn () void) !void {
        _ = name;
        _ = callback;
    }

    // Menu integration
    pub fn addMenuItem(menu_id: []const u8, item: MenuItem) !void {
        _ = menu_id;
        _ = item;
    }

    pub const MenuItem = struct {
        id: []const u8,
        label: []const u8,
        shortcut: ?[]const u8 = null,
        action: []const u8,
    };

    // Status bar
    pub fn setStatusBarItem(id: []const u8, text: []const u8, tooltip: ?[]const u8) void {
        _ = id;
        _ = text;
        _ = tooltip;
    }

    pub fn removeStatusBarItem(id: []const u8) void {
        _ = id;
    }
};

/// Integrated plugin instance
pub const Plugin = struct {
    manifest: PluginManifest,
    security_plugin: *plugin_security.Plugin,
    wasm_module: ?*wasm.WasmModule,
    sandbox: plugin_security.Sandbox,
    event_subscriptions: std.EnumSet(PluginEvent),
    enabled: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, manifest: PluginManifest) !*Plugin {
        const policy = manifest.getSecurityPolicy();
        const security_plugin = try plugin_security.Plugin.init(
            allocator,
            manifest.id,
            manifest.name,
            manifest.version,
            manifest.author,
            policy,
        );

        const plugin = try allocator.create(Plugin);
        plugin.* = Plugin{
            .manifest = manifest,
            .security_plugin = security_plugin,
            .wasm_module = null,
            .sandbox = plugin_security.Sandbox.init(allocator, security_plugin),
            .event_subscriptions = std.EnumSet(PluginEvent).initEmpty(),
            .enabled = false,
            .allocator = allocator,
        };

        // Subscribe to declared hooks
        for (manifest.hooks) |hook| {
            if (hookFromString(hook)) |event| {
                plugin.event_subscriptions.insert(event);
            }
        }

        return plugin;
    }

    pub fn deinit(self: *Plugin) void {
        self.sandbox.deinit();
        self.security_plugin.deinit();
        if (self.wasm_module) |module| {
            module.deinit();
        }
        self.allocator.destroy(self);
    }

    pub fn load(self: *Plugin, wasm_bytes: []const u8) !void {
        _ = wasm_bytes;
        // Would load WASM module here
        self.enabled = true;
    }

    pub fn unload(self: *Plugin) void {
        if (self.wasm_module) |module| {
            // Call cleanup function if exists
            if (module.getExport("plugin_deinit")) |_| {
                _ = module.call("plugin_deinit", &.{}) catch {};
            }
            module.deinit();
            self.wasm_module = null;
        }
        self.enabled = false;
    }

    pub fn handleEvent(self: *Plugin, event: EventData) !void {
        if (!self.enabled) return;
        if (!self.event_subscriptions.contains(event.event_type)) return;

        // Would call WASM function with event data
        if (self.wasm_module) |module| {
            const event_name = eventToString(event.event_type);
            if (module.getExport(event_name)) |_| {
                // Serialize event data and call
                _ = try module.call(event_name, &.{});
            }
        }
    }

    pub fn callFunction(self: *Plugin, name: []const u8, args: []const wasm.WasmValue) ![]const wasm.WasmValue {
        if (!self.enabled) return error.PluginDisabled;

        try self.security_plugin.startExecution();
        defer self.security_plugin.endExecution();

        if (self.wasm_module) |module| {
            return try module.call(name, args);
        }

        return error.ModuleNotLoaded;
    }

    fn hookFromString(hook: []const u8) ?PluginEvent {
        const hooks = .{
            .{ "app_ready", PluginEvent.app_ready },
            .{ "app_will_quit", PluginEvent.app_will_quit },
            .{ "window_created", PluginEvent.window_created },
            .{ "window_closed", PluginEvent.window_closed },
            .{ "file_opened", PluginEvent.file_opened },
            .{ "file_saved", PluginEvent.file_saved },
            .{ "text_changed", PluginEvent.text_changed },
            .{ "selection_changed", PluginEvent.selection_changed },
        };

        inline for (hooks) |entry| {
            if (std.mem.eql(u8, hook, entry[0])) {
                return entry[1];
            }
        }
        return null;
    }

    fn eventToString(event: PluginEvent) []const u8 {
        return switch (event) {
            .app_ready => "onAppReady",
            .app_will_quit => "onAppWillQuit",
            .window_created => "onWindowCreated",
            .window_closed => "onWindowClosed",
            .window_focused => "onWindowFocused",
            .window_blurred => "onWindowBlurred",
            .file_opened => "onFileOpened",
            .file_saved => "onFileSaved",
            .file_closed => "onFileClosed",
            .text_changed => "onTextChanged",
            .selection_changed => "onSelectionChanged",
            .cursor_moved => "onCursorMoved",
            .menu_clicked => "onMenuClicked",
            .shortcut_pressed => "onShortcutPressed",
            .context_menu => "onContextMenu",
            .custom => "onCustomEvent",
        };
    }
};

/// Plugin Manager - manages all plugins
pub const PluginManager = struct {
    plugins: std.StringHashMap(*Plugin),
    security_manager: plugin_security.PluginManager,
    event_queue: std.ArrayList(EventData),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PluginManager {
        return .{
            .plugins = std.StringHashMap(*Plugin).init(allocator),
            .security_manager = plugin_security.PluginManager.init(allocator),
            .event_queue = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PluginManager) void {
        var iter = self.plugins.valueIterator();
        while (iter.next()) |plugin| {
            plugin.*.deinit();
        }
        self.plugins.deinit();
        self.security_manager.deinit();
        self.event_queue.deinit(self.allocator);
    }

    pub fn installPlugin(self: *PluginManager, manifest: PluginManifest, wasm_bytes: ?[]const u8) !void {
        const plugin = try Plugin.init(self.allocator, manifest);
        errdefer plugin.deinit();

        if (wasm_bytes) |bytes| {
            try plugin.load(bytes);
        }

        try self.plugins.put(manifest.id, plugin);
        try self.security_manager.register(plugin.security_plugin);
    }

    pub fn uninstallPlugin(self: *PluginManager, plugin_id: []const u8) !void {
        if (self.plugins.fetchRemove(plugin_id)) |kv| {
            kv.value.unload();
            kv.value.deinit();
            try self.security_manager.unregister(plugin_id);
        }
    }

    pub fn enablePlugin(self: *PluginManager, plugin_id: []const u8) !void {
        if (self.plugins.get(plugin_id)) |plugin| {
            plugin.enabled = true;
        }
    }

    pub fn disablePlugin(self: *PluginManager, plugin_id: []const u8) !void {
        if (self.plugins.get(plugin_id)) |plugin| {
            plugin.enabled = false;
        }
    }

    pub fn getPlugin(self: *PluginManager, plugin_id: []const u8) ?*Plugin {
        return self.plugins.get(plugin_id);
    }

    pub fn listPlugins(self: *const PluginManager) []const []const u8 {
        _ = self;
        // Would return list of plugin IDs
        return &.{};
    }

    /// Dispatch event to all subscribed plugins
    pub fn dispatchEvent(self: *PluginManager, event: EventData) !void {
        var iter = self.plugins.valueIterator();
        while (iter.next()) |plugin| {
            plugin.*.handleEvent(event) catch |err| {
                HostAPI.log(.err, "Plugin event handler failed");
                _ = err;
            };
        }
    }

    /// Queue event for later dispatch
    pub fn queueEvent(self: *PluginManager, event: EventData) !void {
        try self.event_queue.append(self.allocator, event);
    }

    /// Process queued events
    pub fn processEvents(self: *PluginManager) !void {
        for (self.event_queue.items) |event| {
            try self.dispatchEvent(event);
        }
        self.event_queue.clearRetainingCapacity();
    }

    /// Call a specific function on a plugin
    pub fn callPlugin(
        self: *PluginManager,
        plugin_id: []const u8,
        function: []const u8,
        args: []const wasm.WasmValue,
    ) ![]const wasm.WasmValue {
        const plugin = self.plugins.get(plugin_id) orelse return error.PluginNotFound;
        return try plugin.callFunction(function, args);
    }

    /// Check if plugin has permission
    pub fn checkPermission(self: *PluginManager, plugin_id: []const u8, permission: plugin_security.Permission) !void {
        try self.security_manager.checkPermission(plugin_id, permission);
    }
};

/// Plugin loader - handles loading plugins from disk
pub const PluginLoader = struct {
    plugins_dir: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, plugins_dir: []const u8) PluginLoader {
        return .{
            .plugins_dir = plugins_dir,
            .allocator = allocator,
        };
    }

    pub fn loadFromDirectory(self: *PluginLoader, manager: *PluginManager, plugin_name: []const u8) !void {
        // Build paths
        const manifest_path = try std.fs.path.join(self.allocator, &.{ self.plugins_dir, plugin_name, "manifest.json" });
        defer self.allocator.free(manifest_path);

        // Read manifest
        const manifest_file = try std.fs.cwd().openFile(manifest_path, .{});
        defer manifest_file.close();

        const stat = try manifest_file.stat();
        const manifest_json = try self.allocator.alloc(u8, @intCast(stat.size));
        defer self.allocator.free(manifest_json);
        _ = try manifest_file.read(manifest_json);

        const manifest = try PluginManifest.parseJson(self.allocator, manifest_json);

        // Read WASM bytes if applicable
        if (std.mem.endsWith(u8, manifest.main, ".wasm")) {
            const wasm_path = try std.fs.path.join(self.allocator, &.{ self.plugins_dir, plugin_name, manifest.main });
            defer self.allocator.free(wasm_path);

            const wasm_file = try std.fs.cwd().openFile(wasm_path, .{});
            defer wasm_file.close();

            const wasm_stat = try wasm_file.stat();
            const wasm_bytes = try self.allocator.alloc(u8, @intCast(wasm_stat.size));
            defer self.allocator.free(wasm_bytes);
            _ = try wasm_file.read(wasm_bytes);

            try manager.installPlugin(manifest, wasm_bytes);
        } else {
            try manager.installPlugin(manifest, null);
        }
    }

    pub fn discoverPlugins(self: *PluginLoader) ![]const []const u8 {
        var plugins = std.ArrayList([]const u8).init(self.allocator);
        errdefer plugins.deinit();

        var dir = std.fs.cwd().openDir(self.plugins_dir, .{ .iterate = true }) catch {
            return plugins.toOwnedSlice();
        };
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .directory) {
                const name = try self.allocator.dupe(u8, entry.name);
                try plugins.append(name);
            }
        }

        return try plugins.toOwnedSlice();
    }
};

// Tests
test "plugin manifest security policy" {
    const minimal_manifest = PluginManifest{
        .id = "test",
        .name = "Test",
        .version = "1.0.0",
        .author = "Test",
        .description = "",
        .main = "main.wasm",
        .permissions = &.{ "read_files", "system_info" },
    };

    try std.testing.expectEqual(plugin_security.SecurityPolicy.minimal, minimal_manifest.getSecurityPolicy());

    const elevated_manifest = PluginManifest{
        .id = "test",
        .name = "Test",
        .version = "1.0.0",
        .author = "Test",
        .description = "",
        .main = "main.wasm",
        .permissions = &.{ "read_files", "write_files", "execute_commands" },
    };

    try std.testing.expectEqual(plugin_security.SecurityPolicy.elevated, elevated_manifest.getSecurityPolicy());
}

test "plugin event subscriptions" {
    const allocator = std.testing.allocator;

    const manifest = PluginManifest{
        .id = "test",
        .name = "Test Plugin",
        .version = "1.0.0",
        .author = "Test",
        .description = "A test plugin",
        .main = "main.wasm",
        .hooks = &.{ "app_ready", "file_opened" },
    };

    const plugin = try Plugin.init(allocator, manifest);
    defer plugin.deinit();

    try std.testing.expect(plugin.event_subscriptions.contains(.app_ready));
    try std.testing.expect(plugin.event_subscriptions.contains(.file_opened));
    try std.testing.expect(!plugin.event_subscriptions.contains(.window_created));
}

test "plugin manager lifecycle" {
    const allocator = std.testing.allocator;

    var manager = PluginManager.init(allocator);
    defer manager.deinit();

    const manifest = PluginManifest{
        .id = "test-plugin",
        .name = "Test Plugin",
        .version = "1.0.0",
        .author = "Test",
        .description = "A test plugin",
        .main = "main.wasm",
    };

    try manager.installPlugin(manifest, null);
    try std.testing.expect(manager.getPlugin("test-plugin") != null);

    try manager.uninstallPlugin("test-plugin");
    try std.testing.expect(manager.getPlugin("test-plugin") == null);
}

test "event dispatch" {
    const allocator = std.testing.allocator;

    var manager = PluginManager.init(allocator);
    defer manager.deinit();

    const manifest = PluginManifest{
        .id = "test-plugin",
        .name = "Test Plugin",
        .version = "1.0.0",
        .author = "Test",
        .description = "",
        .main = "main.wasm",
        .hooks = &.{"app_ready"},
    };

    try manager.installPlugin(manifest, null);
    try manager.enablePlugin("test-plugin");

    const event = EventData.init(.app_ready);
    try manager.dispatchEvent(event);
}
