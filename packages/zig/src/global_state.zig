const std = @import("std");
const compat_mutex = @import("compat_mutex.zig");

// Bridge type imports
const bridge_fs = @import("bridge_fs.zig");
const bridge_shell = @import("bridge_shell.zig");
const bridge_shortcuts = @import("bridge_shortcuts.zig");
const bridge_system = @import("bridge_system.zig");
const bridge_network = @import("bridge_network.zig");
const bridge_bluetooth = @import("bridge_bluetooth.zig");
const bridge_power = @import("bridge_power.zig");
const bridge_touchbar = @import("bridge_touchbar.zig");
const bridge_updater = @import("bridge_updater.zig");
const bridge_marketplace = @import("bridge_marketplace.zig");
const events = @import("events.zig");
const devmode_mod = @import("devmode.zig");

/// Thread-safe global state for bridge instances and core framework state.
/// All bridge globals should be accessed through this module
/// to prevent data races from concurrent access.
///
/// Usage pattern for getters (lock is NOT held on return):
///     const bridge = global_state.instance.getFsBridge();
///     if (bridge) |b| b.handleMessage(action, data);
///
/// Usage pattern for setters (lock is acquired and released internally):
///     global_state.instance.setFsBridge(my_bridge);
pub const GlobalState = struct {
    mutex: compat_mutex.Mutex = .{},

    // Bridge instances
    fs_bridge: ?*bridge_fs.FSBridge = null,
    shell_bridge: ?*bridge_shell.ShellBridge = null,
    shortcuts_bridge: ?*bridge_shortcuts.ShortcutsBridge = null,
    system_bridge: ?*bridge_system.SystemBridge = null,
    network_bridge: ?*bridge_network.NetworkBridge = null,
    bluetooth_bridge: ?*bridge_bluetooth.BluetoothBridge = null,
    power_bridge: ?*bridge_power.PowerBridge = null,
    touchbar_bridge: ?*bridge_touchbar.TouchBarBridge = null,
    updater_bridge: ?*bridge_updater.UpdaterBridge = null,
    marketplace_bridge: ?*bridge_marketplace.MarketplaceBridge = null,

    // Core state
    io: ?std.Io = null,
    default_threaded: ?std.Io.Threaded = null,
    emitter: ?events.EventEmitter = null,
    devmode: ?devmode_mod.DevMode = null,

    const Self = @This();

    // -----------------------------------------------
    // Low-level lock/unlock (use sparingly)
    // -----------------------------------------------

    pub fn lock(self: *Self) void {
        self.mutex.lock();
    }

    pub fn unlock(self: *Self) void {
        self.mutex.unlock();
    }

    // -----------------------------------------------
    // Bridge getters — snapshot the pointer under lock
    // -----------------------------------------------

    pub fn getFsBridge(self: *Self) ?*bridge_fs.FSBridge {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.fs_bridge;
    }

    pub fn getShellBridge(self: *Self) ?*bridge_shell.ShellBridge {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.shell_bridge;
    }

    pub fn getShortcutsBridge(self: *Self) ?*bridge_shortcuts.ShortcutsBridge {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.shortcuts_bridge;
    }

    pub fn getSystemBridge(self: *Self) ?*bridge_system.SystemBridge {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.system_bridge;
    }

    pub fn getNetworkBridge(self: *Self) ?*bridge_network.NetworkBridge {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.network_bridge;
    }

    pub fn getBluetoothBridge(self: *Self) ?*bridge_bluetooth.BluetoothBridge {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.bluetooth_bridge;
    }

    pub fn getPowerBridge(self: *Self) ?*bridge_power.PowerBridge {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.power_bridge;
    }

    pub fn getTouchbarBridge(self: *Self) ?*bridge_touchbar.TouchBarBridge {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.touchbar_bridge;
    }

    pub fn getUpdaterBridge(self: *Self) ?*bridge_updater.UpdaterBridge {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.updater_bridge;
    }

    pub fn getMarketplaceBridge(self: *Self) ?*bridge_marketplace.MarketplaceBridge {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.marketplace_bridge;
    }

    // -----------------------------------------------
    // Bridge setters — store under lock
    // -----------------------------------------------

    pub fn setFsBridge(self: *Self, bridge: ?*bridge_fs.FSBridge) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.fs_bridge = bridge;
    }

    pub fn setShellBridge(self: *Self, bridge: ?*bridge_shell.ShellBridge) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.shell_bridge = bridge;
    }

    pub fn setShortcutsBridge(self: *Self, bridge: ?*bridge_shortcuts.ShortcutsBridge) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.shortcuts_bridge = bridge;
    }

    pub fn setSystemBridge(self: *Self, bridge: ?*bridge_system.SystemBridge) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.system_bridge = bridge;
    }

    pub fn setNetworkBridge(self: *Self, bridge: ?*bridge_network.NetworkBridge) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.network_bridge = bridge;
    }

    pub fn setBluetoothBridge(self: *Self, bridge: ?*bridge_bluetooth.BluetoothBridge) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.bluetooth_bridge = bridge;
    }

    pub fn setPowerBridge(self: *Self, bridge: ?*bridge_power.PowerBridge) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.power_bridge = bridge;
    }

    pub fn setTouchbarBridge(self: *Self, bridge: ?*bridge_touchbar.TouchBarBridge) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.touchbar_bridge = bridge;
    }

    pub fn setUpdaterBridge(self: *Self, bridge: ?*bridge_updater.UpdaterBridge) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.updater_bridge = bridge;
    }

    pub fn setMarketplaceBridge(self: *Self, bridge: ?*bridge_marketplace.MarketplaceBridge) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.marketplace_bridge = bridge;
    }

    // -----------------------------------------------
    // Io context
    // -----------------------------------------------

    pub fn getIo(self: *Self) std.Io {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.io) |io| return io;

        // Lazy init for test mode or when not explicitly initialized
        self.default_threaded = std.Io.Threaded.init(std.heap.c_allocator, .{ .environ = .empty });
        self.io = self.default_threaded.?.io();
        return self.io.?;
    }

    pub fn setIo(self: *Self, io: std.Io) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.io = io;
    }

    // -----------------------------------------------
    // Event emitter
    // -----------------------------------------------

    pub fn getEmitter(self: *Self) ?*events.EventEmitter {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.emitter != null) {
            return &self.emitter.?;
        }
        return null;
    }

    pub fn initEmitter(self: *Self, allocator: std.mem.Allocator) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.emitter = events.EventEmitter.init(allocator);
    }

    pub fn deinitEmitter(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.emitter) |*emitter| {
            emitter.deinit();
            self.emitter = null;
        }
    }

    // -----------------------------------------------
    // DevMode
    // -----------------------------------------------

    pub fn getDevMode(self: *Self) ?*devmode_mod.DevMode {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.devmode != null) {
            return &self.devmode.?;
        }
        return null;
    }

    pub fn initDevMode(self: *Self, allocator: std.mem.Allocator) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.devmode = devmode_mod.DevMode.init(allocator);
    }
};

/// Singleton instance of the global state.
pub var instance: GlobalState = .{};
