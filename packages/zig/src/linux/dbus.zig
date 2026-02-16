const std = @import("std");
const io_context = @import("../io_context.zig");
const c = @cImport({
    @cInclude("gio/gio.h");
});

// ============================================
// D-Bus Type Definitions
// ============================================

pub const GDBusConnection = c.GDBusConnection;
pub const GDBusProxy = c.GDBusProxy;
pub const GDBusMessage = c.GDBusMessage;
pub const GVariant = c.GVariant;
pub const GError = c.GError;

pub const BusType = enum(c_int) {
    starter = c.G_BUS_TYPE_STARTER,
    none = c.G_BUS_TYPE_NONE,
    system = c.G_BUS_TYPE_SYSTEM,
    session = c.G_BUS_TYPE_SESSION,
};

pub const DBusCallFlags = enum(c_int) {
    none = c.G_DBUS_CALL_FLAGS_NONE,
    no_auto_start = c.G_DBUS_CALL_FLAGS_NO_AUTO_START,
    allow_interactive_authorization = c.G_DBUS_CALL_FLAGS_ALLOW_INTERACTIVE_AUTHORIZATION,
};

// ============================================
// D-Bus Connection
// ============================================

pub const Connection = struct {
    const Self = @This();

    connection: *GDBusConnection,

    /// Get the session bus connection
    pub fn getSession() !Self {
        var err: ?*GError = null;
        const conn = c.g_bus_get_sync(c.G_BUS_TYPE_SESSION, null, &err);

        if (err) |e| {
            defer c.g_error_free(e);
            return error.DBusConnectionFailed;
        }

        if (conn == null) return error.DBusConnectionFailed;

        return Self{ .connection = conn.? };
    }

    /// Get the system bus connection
    pub fn getSystem() !Self {
        var err: ?*GError = null;
        const conn = c.g_bus_get_sync(c.G_BUS_TYPE_SYSTEM, null, &err);

        if (err) |e| {
            defer c.g_error_free(e);
            return error.DBusConnectionFailed;
        }

        if (conn == null) return error.DBusConnectionFailed;

        return Self{ .connection = conn.? };
    }

    /// Close the connection
    pub fn close(self: *Self) void {
        var err: ?*GError = null;
        _ = c.g_dbus_connection_close_sync(self.connection, null, &err);
        if (err) |e| {
            c.g_error_free(e);
        }
    }

    /// Call a D-Bus method
    pub fn call(
        self: *Self,
        bus_name: [*:0]const u8,
        object_path: [*:0]const u8,
        interface_name: [*:0]const u8,
        method_name: [*:0]const u8,
        parameters: ?*GVariant,
        reply_type: ?*const c.GVariantType,
        timeout_ms: c_int,
    ) !?*GVariant {
        var err: ?*GError = null;
        const result = c.g_dbus_connection_call_sync(
            self.connection,
            bus_name,
            object_path,
            interface_name,
            method_name,
            parameters,
            reply_type,
            c.G_DBUS_CALL_FLAGS_NONE,
            timeout_ms,
            null,
            &err,
        );

        if (err) |e| {
            defer c.g_error_free(e);
            return error.DBusCallFailed;
        }

        return result;
    }

    /// Emit a signal
    pub fn emitSignal(
        self: *Self,
        destination: ?[*:0]const u8,
        object_path: [*:0]const u8,
        interface_name: [*:0]const u8,
        signal_name: [*:0]const u8,
        parameters: ?*GVariant,
    ) !void {
        var err: ?*GError = null;
        _ = c.g_dbus_connection_emit_signal(
            self.connection,
            destination,
            object_path,
            interface_name,
            signal_name,
            parameters,
            &err,
        );

        if (err) |e| {
            defer c.g_error_free(e);
            return error.DBusSignalFailed;
        }
    }

    /// Subscribe to a signal
    pub fn subscribeSignal(
        self: *Self,
        sender: ?[*:0]const u8,
        interface_name: ?[*:0]const u8,
        member: ?[*:0]const u8,
        object_path: ?[*:0]const u8,
        arg0: ?[*:0]const u8,
        callback: c.GDBusSignalCallback,
        user_data: ?*anyopaque,
    ) c_uint {
        return c.g_dbus_connection_signal_subscribe(
            self.connection,
            sender,
            interface_name,
            member,
            object_path,
            arg0,
            c.G_DBUS_SIGNAL_FLAGS_NONE,
            callback,
            user_data,
            null,
        );
    }

    /// Unsubscribe from a signal
    pub fn unsubscribeSignal(self: *Self, subscription_id: c_uint) void {
        c.g_dbus_connection_signal_unsubscribe(self.connection, subscription_id);
    }

    /// Register an object
    pub fn registerObject(
        self: *Self,
        object_path: [*:0]const u8,
        interface_info: *c.GDBusInterfaceInfo,
        vtable: *const c.GDBusInterfaceVTable,
        user_data: ?*anyopaque,
    ) !c_uint {
        var err: ?*GError = null;
        const id = c.g_dbus_connection_register_object(
            self.connection,
            object_path,
            interface_info,
            vtable,
            user_data,
            null,
            &err,
        );

        if (err) |e| {
            defer c.g_error_free(e);
            return error.DBusRegisterFailed;
        }

        return id;
    }

    /// Unregister an object
    pub fn unregisterObject(self: *Self, registration_id: c_uint) bool {
        return c.g_dbus_connection_unregister_object(self.connection, registration_id) != 0;
    }

    /// Own a bus name
    pub fn ownName(
        bus_type: BusType,
        name: [*:0]const u8,
        flags: c.GBusNameOwnerFlags,
        bus_acquired: ?c.GBusAcquiredCallback,
        name_acquired: ?c.GBusNameAcquiredCallback,
        name_lost: ?c.GBusNameLostCallback,
        user_data: ?*anyopaque,
    ) c_uint {
        return c.g_bus_own_name(
            @intFromEnum(bus_type),
            name,
            flags,
            bus_acquired,
            name_acquired,
            name_lost,
            user_data,
            null,
        );
    }

    /// Release owned name
    pub fn unownName(owner_id: c_uint) void {
        c.g_bus_unown_name(owner_id);
    }
};

// ============================================
// D-Bus Proxy
// ============================================

pub const Proxy = struct {
    const Self = @This();

    proxy: *GDBusProxy,

    /// Create a new proxy synchronously
    pub fn init(
        bus_type: BusType,
        name: [*:0]const u8,
        object_path: [*:0]const u8,
        interface_name: [*:0]const u8,
    ) !Self {
        var err: ?*GError = null;
        const proxy = c.g_dbus_proxy_new_for_bus_sync(
            @intFromEnum(bus_type),
            c.G_DBUS_PROXY_FLAGS_NONE,
            null,
            name,
            object_path,
            interface_name,
            null,
            &err,
        );

        if (err) |e| {
            defer c.g_error_free(e);
            return error.DBusProxyFailed;
        }

        if (proxy == null) return error.DBusProxyFailed;

        return Self{ .proxy = proxy.? };
    }

    pub fn deinit(self: *Self) void {
        c.g_object_unref(@ptrCast(self.proxy));
    }

    /// Call a method
    pub fn call(
        self: *Self,
        method_name: [*:0]const u8,
        parameters: ?*GVariant,
        timeout_ms: c_int,
    ) !?*GVariant {
        var err: ?*GError = null;
        const result = c.g_dbus_proxy_call_sync(
            self.proxy,
            method_name,
            parameters,
            c.G_DBUS_CALL_FLAGS_NONE,
            timeout_ms,
            null,
            &err,
        );

        if (err) |e| {
            defer c.g_error_free(e);
            return error.DBusCallFailed;
        }

        return result;
    }

    /// Get a cached property
    pub fn getProperty(self: *Self, property_name: [*:0]const u8) ?*GVariant {
        return c.g_dbus_proxy_get_cached_property(self.proxy, property_name);
    }

    /// Set a cached property
    pub fn setProperty(self: *Self, property_name: [*:0]const u8, value: *GVariant) void {
        c.g_dbus_proxy_set_cached_property(self.proxy, property_name, value);
    }

    /// Get the name owner
    pub fn getNameOwner(self: *Self) ?[*:0]const u8 {
        return c.g_dbus_proxy_get_name_owner(self.proxy);
    }
};

// ============================================
// XDG Desktop Portal Integration
// ============================================

pub const Portal = struct {
    const PORTAL_BUS_NAME = "org.freedesktop.portal.Desktop";
    const PORTAL_OBJECT_PATH = "/org/freedesktop/portal/desktop";

    /// Open a file with the default application
    pub fn openFile(uri: [*:0]const u8) !void {
        var conn = try Connection.getSession();
        defer conn.close();

        const params = c.g_variant_new("(ss)", "", uri);
        _ = try conn.call(
            PORTAL_BUS_NAME,
            PORTAL_OBJECT_PATH,
            "org.freedesktop.portal.OpenURI",
            "OpenURI",
            params,
            null,
            -1,
        );
    }

    /// Open a directory in the file manager
    pub fn openDirectory(uri: [*:0]const u8) !void {
        var conn = try Connection.getSession();
        defer conn.close();

        const params = c.g_variant_new("(ss)", "", uri);
        _ = try conn.call(
            PORTAL_BUS_NAME,
            PORTAL_OBJECT_PATH,
            "org.freedesktop.portal.OpenURI",
            "OpenDirectory",
            params,
            null,
            -1,
        );
    }

    /// Show a notification
    pub fn showNotification(
        app_id: [*:0]const u8,
        notification_id: [*:0]const u8,
        title: [*:0]const u8,
        body: [*:0]const u8,
    ) !void {
        var conn = try Connection.getSession();
        defer conn.close();

        // Build notification dict
        var builder: c.GVariantBuilder = undefined;
        c.g_variant_builder_init(&builder, c.G_VARIANT_TYPE("a{sv}"));
        c.g_variant_builder_add(&builder, "{sv}", "title", c.g_variant_new_string(title));
        c.g_variant_builder_add(&builder, "{sv}", "body", c.g_variant_new_string(body));

        const notification = c.g_variant_builder_end(&builder);
        const params = c.g_variant_new("(ss@a{sv})", app_id, notification_id, notification);

        _ = try conn.call(
            PORTAL_BUS_NAME,
            PORTAL_OBJECT_PATH,
            "org.freedesktop.portal.Notification",
            "AddNotification",
            params,
            null,
            -1,
        );
    }

    /// Close a notification
    pub fn closeNotification(app_id: [*:0]const u8, notification_id: [*:0]const u8) !void {
        var conn = try Connection.getSession();
        defer conn.close();

        const params = c.g_variant_new("(ss)", app_id, notification_id);
        _ = try conn.call(
            PORTAL_BUS_NAME,
            PORTAL_OBJECT_PATH,
            "org.freedesktop.portal.Notification",
            "RemoveNotification",
            params,
            null,
            -1,
        );
    }

    /// Request camera access
    pub fn requestCamera(callback: c.GAsyncReadyCallback, user_data: ?*anyopaque) !void {
        var conn = try Connection.getSession();

        var builder: c.GVariantBuilder = undefined;
        c.g_variant_builder_init(&builder, c.G_VARIANT_TYPE("a{sv}"));
        const options = c.g_variant_builder_end(&builder);

        c.g_dbus_connection_call(
            conn.connection,
            PORTAL_BUS_NAME,
            PORTAL_OBJECT_PATH,
            "org.freedesktop.portal.Camera",
            "AccessCamera",
            c.g_variant_new("(@a{sv})", options),
            null,
            c.G_DBUS_CALL_FLAGS_NONE,
            -1,
            null,
            callback,
            user_data,
        );
    }

    /// Request location access
    pub fn requestLocation(callback: c.GAsyncReadyCallback, user_data: ?*anyopaque) !void {
        var conn = try Connection.getSession();

        var builder: c.GVariantBuilder = undefined;
        c.g_variant_builder_init(&builder, c.G_VARIANT_TYPE("a{sv}"));
        const options = c.g_variant_builder_end(&builder);

        c.g_dbus_connection_call(
            conn.connection,
            PORTAL_BUS_NAME,
            PORTAL_OBJECT_PATH,
            "org.freedesktop.portal.Location",
            "CreateSession",
            c.g_variant_new("(@a{sv})", options),
            null,
            c.G_DBUS_CALL_FLAGS_NONE,
            -1,
            null,
            callback,
            user_data,
        );
    }
};

// ============================================
// MPRIS Media Player Integration
// ============================================

pub const MPRIS = struct {
    const MPRIS_PATH = "/org/mpris/MediaPlayer2";
    const MPRIS_INTERFACE = "org.mpris.MediaPlayer2.Player";
    const MPRIS_ROOT_INTERFACE = "org.mpris.MediaPlayer2";

    bus_name: [*:0]const u8,
    proxy: ?Proxy,

    pub fn init(player_name: [*:0]const u8) !MPRIS {
        // Construct bus name like "org.mpris.MediaPlayer2.playerName"
        const proxy = try Proxy.init(.session, player_name, MPRIS_PATH, MPRIS_INTERFACE);

        return MPRIS{
            .bus_name = player_name,
            .proxy = proxy,
        };
    }

    pub fn deinit(self: *MPRIS) void {
        if (self.proxy) |*p| {
            p.deinit();
        }
    }

    /// Play
    pub fn play(self: *MPRIS) !void {
        if (self.proxy) |*p| {
            _ = try p.call("Play", null, -1);
        }
    }

    /// Pause
    pub fn pause(self: *MPRIS) !void {
        if (self.proxy) |*p| {
            _ = try p.call("Pause", null, -1);
        }
    }

    /// Play/Pause toggle
    pub fn playPause(self: *MPRIS) !void {
        if (self.proxy) |*p| {
            _ = try p.call("PlayPause", null, -1);
        }
    }

    /// Stop
    pub fn stop(self: *MPRIS) !void {
        if (self.proxy) |*p| {
            _ = try p.call("Stop", null, -1);
        }
    }

    /// Next track
    pub fn next(self: *MPRIS) !void {
        if (self.proxy) |*p| {
            _ = try p.call("Next", null, -1);
        }
    }

    /// Previous track
    pub fn previous(self: *MPRIS) !void {
        if (self.proxy) |*p| {
            _ = try p.call("Previous", null, -1);
        }
    }

    /// Seek
    pub fn seek(self: *MPRIS, offset_microseconds: i64) !void {
        if (self.proxy) |*p| {
            const params = c.g_variant_new("(x)", offset_microseconds);
            _ = try p.call("Seek", params, -1);
        }
    }

    /// Set position
    pub fn setPosition(self: *MPRIS, track_id: [*:0]const u8, position_microseconds: i64) !void {
        if (self.proxy) |*p| {
            const params = c.g_variant_new("(ox)", track_id, position_microseconds);
            _ = try p.call("SetPosition", params, -1);
        }
    }

    /// Get playback status
    pub fn getPlaybackStatus(self: *MPRIS) ?[*:0]const u8 {
        if (self.proxy) |*p| {
            if (p.getProperty("PlaybackStatus")) |variant| {
                defer c.g_variant_unref(variant);
                return c.g_variant_get_string(variant, null);
            }
        }
        return null;
    }

    /// Get current metadata
    pub fn getMetadata(self: *MPRIS) ?*GVariant {
        if (self.proxy) |*p| {
            return p.getProperty("Metadata");
        }
        return null;
    }

    /// Get volume (0.0 to 1.0)
    pub fn getVolume(self: *MPRIS) ?f64 {
        if (self.proxy) |*p| {
            if (p.getProperty("Volume")) |variant| {
                defer c.g_variant_unref(variant);
                return c.g_variant_get_double(variant);
            }
        }
        return null;
    }
};

// ============================================
// Secret Service (Keyring) Integration
// ============================================

pub const SecretService = struct {
    const SECRET_BUS_NAME = "org.freedesktop.secrets";
    const SECRET_OBJECT_PATH = "/org/freedesktop/secrets";
    const SECRET_INTERFACE = "org.freedesktop.Secret.Service";

    /// Store a secret
    pub fn store(
        collection: [*:0]const u8,
        label: [*:0]const u8,
        secret: [*:0]const u8,
        attributes: []const struct { key: [*:0]const u8, value: [*:0]const u8 },
    ) !void {
        var conn = try Connection.getSession();
        defer conn.close();

        // Build attributes dict
        var attr_builder: c.GVariantBuilder = undefined;
        c.g_variant_builder_init(&attr_builder, c.G_VARIANT_TYPE("a{ss}"));
        for (attributes) |attr| {
            c.g_variant_builder_add(&attr_builder, "{ss}", attr.key, attr.value);
        }

        // Build properties dict
        var props_builder: c.GVariantBuilder = undefined;
        c.g_variant_builder_init(&props_builder, c.G_VARIANT_TYPE("a{sv}"));
        c.g_variant_builder_add(&props_builder, "{sv}", "org.freedesktop.Secret.Item.Label", c.g_variant_new_string(label));
        c.g_variant_builder_add(&props_builder, "{sv}", "org.freedesktop.Secret.Item.Attributes", c.g_variant_builder_end(&attr_builder));

        // Secret structure: (oayays) - session path, parameters, secret, content_type
        const secret_variant = c.g_variant_new("(oayays)", "/", null, secret, "text/plain");

        const params = c.g_variant_new("(o@a{sv}@(oayays)b)", collection, c.g_variant_builder_end(&props_builder), secret_variant, @as(c_int, 1));

        _ = try conn.call(
            SECRET_BUS_NAME,
            SECRET_OBJECT_PATH,
            "org.freedesktop.Secret.Collection",
            "CreateItem",
            params,
            null,
            -1,
        );
    }

    /// Lookup a secret
    pub fn lookup(
        attributes: []const struct { key: [*:0]const u8, value: [*:0]const u8 },
    ) !?[]const u8 {
        var conn = try Connection.getSession();
        defer conn.close();

        // Build attributes dict
        var builder: c.GVariantBuilder = undefined;
        c.g_variant_builder_init(&builder, c.G_VARIANT_TYPE("a{ss}"));
        for (attributes) |attr| {
            c.g_variant_builder_add(&builder, "{ss}", attr.key, attr.value);
        }

        const params = c.g_variant_new("(@a{ss})", c.g_variant_builder_end(&builder));

        const result = try conn.call(
            SECRET_BUS_NAME,
            SECRET_OBJECT_PATH,
            SECRET_INTERFACE,
            "SearchItems",
            params,
            null,
            -1,
        );

        if (result) |r| {
            defer c.g_variant_unref(r);
            // Parse result to get secret
            // This is simplified - real implementation would need to unlock and retrieve
        }

        return null;
    }

    /// Delete a secret
    pub fn delete(item_path: [*:0]const u8) !void {
        var conn = try Connection.getSession();
        defer conn.close();

        _ = try conn.call(
            SECRET_BUS_NAME,
            item_path,
            "org.freedesktop.Secret.Item",
            "Delete",
            null,
            null,
            -1,
        );
    }
};

// ============================================
// Power Management Integration
// ============================================

pub const PowerManagement = struct {
    const UPOWER_BUS_NAME = "org.freedesktop.UPower";
    const UPOWER_PATH = "/org/freedesktop/UPower";
    const UPOWER_INTERFACE = "org.freedesktop.UPower";

    const LOGIN1_BUS_NAME = "org.freedesktop.login1";
    const LOGIN1_PATH = "/org/freedesktop/login1";
    const LOGIN1_INTERFACE = "org.freedesktop.login1.Manager";

    /// Get battery percentage
    pub fn getBatteryPercentage() !?f64 {
        const proxy = try Proxy.init(.system, UPOWER_BUS_NAME, "/org/freedesktop/UPower/devices/DisplayDevice", "org.freedesktop.UPower.Device");
        defer @constCast(&proxy).deinit();

        if (@constCast(&proxy).getProperty("Percentage")) |variant| {
            defer c.g_variant_unref(variant);
            return c.g_variant_get_double(variant);
        }
        return null;
    }

    /// Check if on battery power
    pub fn isOnBattery() !bool {
        const proxy = try Proxy.init(.system, UPOWER_BUS_NAME, UPOWER_PATH, UPOWER_INTERFACE);
        defer @constCast(&proxy).deinit();

        if (@constCast(&proxy).getProperty("OnBattery")) |variant| {
            defer c.g_variant_unref(variant);
            return c.g_variant_get_boolean(variant) != 0;
        }
        return false;
    }

    /// Inhibit suspend/sleep
    pub fn inhibitSleep(reason: [*:0]const u8) !u32 {
        var conn = try Connection.getSystem();
        defer conn.close();

        // what, who, why, mode
        const params = c.g_variant_new("(ssss)", "sleep", "craft", reason, "block");

        const result = try conn.call(
            LOGIN1_BUS_NAME,
            LOGIN1_PATH,
            LOGIN1_INTERFACE,
            "Inhibit",
            params,
            c.G_VARIANT_TYPE("(h)"),
            -1,
        );

        if (result) |r| {
            defer c.g_variant_unref(r);
            var fd: c_int = 0;
            c.g_variant_get(r, "(h)", &fd);
            return @intCast(fd);
        }

        return error.InhibitFailed;
    }

    /// Suspend the system
    pub fn suspend() !void {
        var conn = try Connection.getSystem();
        defer conn.close();

        const params = c.g_variant_new("(b)", @as(c_int, 0)); // interactive = false
        _ = try conn.call(
            LOGIN1_BUS_NAME,
            LOGIN1_PATH,
            LOGIN1_INTERFACE,
            "Suspend",
            params,
            null,
            -1,
        );
    }

    /// Reboot the system
    pub fn reboot() !void {
        var conn = try Connection.getSystem();
        defer conn.close();

        const params = c.g_variant_new("(b)", @as(c_int, 0));
        _ = try conn.call(
            LOGIN1_BUS_NAME,
            LOGIN1_PATH,
            LOGIN1_INTERFACE,
            "Reboot",
            params,
            null,
            -1,
        );
    }

    /// Power off the system
    pub fn powerOff() !void {
        var conn = try Connection.getSystem();
        defer conn.close();

        const params = c.g_variant_new("(b)", @as(c_int, 0));
        _ = try conn.call(
            LOGIN1_BUS_NAME,
            LOGIN1_PATH,
            LOGIN1_INTERFACE,
            "PowerOff",
            params,
            null,
            -1,
        );
    }
};

// ============================================
// Network Manager Integration
// ============================================

pub const NetworkManager = struct {
    const NM_BUS_NAME = "org.freedesktop.NetworkManager";
    const NM_PATH = "/org/freedesktop/NetworkManager";
    const NM_INTERFACE = "org.freedesktop.NetworkManager";

    pub const ConnectivityState = enum(u32) {
        unknown = 0,
        none = 1,
        portal = 2,
        limited = 3,
        full = 4,
    };

    pub const DeviceState = enum(u32) {
        unknown = 0,
        unmanaged = 10,
        unavailable = 20,
        disconnected = 30,
        prepare = 40,
        config = 50,
        need_auth = 60,
        ip_config = 70,
        ip_check = 80,
        secondaries = 90,
        activated = 100,
        deactivating = 110,
        failed = 120,
    };

    /// Get network connectivity state
    pub fn getConnectivity() !ConnectivityState {
        const proxy = try Proxy.init(.system, NM_BUS_NAME, NM_PATH, NM_INTERFACE);
        defer @constCast(&proxy).deinit();

        if (@constCast(&proxy).getProperty("Connectivity")) |variant| {
            defer c.g_variant_unref(variant);
            const state = c.g_variant_get_uint32(variant);
            return @enumFromInt(state);
        }
        return .unknown;
    }

    /// Check if networking is enabled
    pub fn isNetworkingEnabled() !bool {
        const proxy = try Proxy.init(.system, NM_BUS_NAME, NM_PATH, NM_INTERFACE);
        defer @constCast(&proxy).deinit();

        if (@constCast(&proxy).getProperty("NetworkingEnabled")) |variant| {
            defer c.g_variant_unref(variant);
            return c.g_variant_get_boolean(variant) != 0;
        }
        return false;
    }

    /// Check if wireless is enabled
    pub fn isWirelessEnabled() !bool {
        const proxy = try Proxy.init(.system, NM_BUS_NAME, NM_PATH, NM_INTERFACE);
        defer @constCast(&proxy).deinit();

        if (@constCast(&proxy).getProperty("WirelessEnabled")) |variant| {
            defer c.g_variant_unref(variant);
            return c.g_variant_get_boolean(variant) != 0;
        }
        return false;
    }

    /// Enable/disable wireless
    pub fn setWirelessEnabled(enabled: bool) !void {
        var conn = try Connection.getSystem();
        defer conn.close();

        const params = c.g_variant_new("(ssv)", NM_INTERFACE, "WirelessEnabled", c.g_variant_new_boolean(if (enabled) 1 else 0));

        _ = try conn.call(
            NM_BUS_NAME,
            NM_PATH,
            "org.freedesktop.DBus.Properties",
            "Set",
            params,
            null,
            -1,
        );
    }

    /// Get primary connection
    pub fn getPrimaryConnection() !?[*:0]const u8 {
        const proxy = try Proxy.init(.system, NM_BUS_NAME, NM_PATH, NM_INTERFACE);
        defer @constCast(&proxy).deinit();

        if (@constCast(&proxy).getProperty("PrimaryConnection")) |variant| {
            defer c.g_variant_unref(variant);
            return c.g_variant_get_string(variant, null);
        }
        return null;
    }
};

// ============================================
// Screen Saver / Idle Inhibitor
// ============================================

pub const ScreenSaver = struct {
    const SCREENSAVER_BUS_NAME = "org.freedesktop.ScreenSaver";
    const SCREENSAVER_PATH = "/org/freedesktop/ScreenSaver";
    const SCREENSAVER_INTERFACE = "org.freedesktop.ScreenSaver";

    /// Inhibit screen saver
    pub fn inhibit(app_name: [*:0]const u8, reason: [*:0]const u8) !u32 {
        var conn = try Connection.getSession();
        defer conn.close();

        const params = c.g_variant_new("(ss)", app_name, reason);
        const result = try conn.call(
            SCREENSAVER_BUS_NAME,
            SCREENSAVER_PATH,
            SCREENSAVER_INTERFACE,
            "Inhibit",
            params,
            c.G_VARIANT_TYPE("(u)"),
            -1,
        );

        if (result) |r| {
            defer c.g_variant_unref(r);
            var cookie: c_uint = 0;
            c.g_variant_get(r, "(u)", &cookie);
            return cookie;
        }

        return error.InhibitFailed;
    }

    /// Uninhibit screen saver
    pub fn uninhibit(cookie: u32) !void {
        var conn = try Connection.getSession();
        defer conn.close();

        const params = c.g_variant_new("(u)", cookie);
        _ = try conn.call(
            SCREENSAVER_BUS_NAME,
            SCREENSAVER_PATH,
            SCREENSAVER_INTERFACE,
            "UnInhibit",
            params,
            null,
            -1,
        );
    }

    /// Simulate user activity
    pub fn simulateUserActivity() !void {
        var conn = try Connection.getSession();
        defer conn.close();

        _ = try conn.call(
            SCREENSAVER_BUS_NAME,
            SCREENSAVER_PATH,
            SCREENSAVER_INTERFACE,
            "SimulateUserActivity",
            null,
            null,
            -1,
        );
    }
};

// ============================================
// System Tray (StatusNotifierItem)
// ============================================

pub const StatusNotifierItem = struct {
    const Self = @This();

    const SNI_INTERFACE = "org.kde.StatusNotifierItem";

    connection: Connection,
    bus_name: []const u8,
    registration_id: c_uint,

    id: [*:0]const u8,
    category: [*:0]const u8,
    status: [*:0]const u8,
    title: [*:0]const u8,
    icon_name: [*:0]const u8,
    tooltip_title: [*:0]const u8,
    tooltip_body: [*:0]const u8,

    on_activate: ?*const fn (?*anyopaque) void,
    on_secondary_activate: ?*const fn (?*anyopaque) void,
    on_scroll: ?*const fn (i32, [*:0]const u8, ?*anyopaque) void,
    user_data: ?*anyopaque,

    pub fn init(
        id: [*:0]const u8,
        title: [*:0]const u8,
        icon_name: [*:0]const u8,
    ) !Self {
        const conn = try Connection.getSession();

        return Self{
            .connection = conn,
            .bus_name = "",
            .registration_id = 0,
            .id = id,
            .category = "ApplicationStatus",
            .status = "Active",
            .title = title,
            .icon_name = icon_name,
            .tooltip_title = title,
            .tooltip_body = "",
            .on_activate = null,
            .on_secondary_activate = null,
            .on_scroll = null,
            .user_data = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.registration_id != 0) {
            self.connection.unregisterObject(self.registration_id);
        }
        self.connection.close();
    }

    pub fn setStatus(self: *Self, status: [*:0]const u8) void {
        self.status = status;
        // Emit NewStatus signal
        self.connection.emitSignal(
            null,
            "/StatusNotifierItem",
            SNI_INTERFACE,
            "NewStatus",
            c.g_variant_new("(s)", status),
        ) catch {};
    }

    pub fn setTitle(self: *Self, title: [*:0]const u8) void {
        self.title = title;
        self.connection.emitSignal(
            null,
            "/StatusNotifierItem",
            SNI_INTERFACE,
            "NewTitle",
            null,
        ) catch {};
    }

    pub fn setIconName(self: *Self, icon_name: [*:0]const u8) void {
        self.icon_name = icon_name;
        self.connection.emitSignal(
            null,
            "/StatusNotifierItem",
            SNI_INTERFACE,
            "NewIcon",
            null,
        ) catch {};
    }

    pub fn setTooltip(self: *Self, title: [*:0]const u8, body: [*:0]const u8) void {
        self.tooltip_title = title;
        self.tooltip_body = body;
        self.connection.emitSignal(
            null,
            "/StatusNotifierItem",
            SNI_INTERFACE,
            "NewToolTip",
            null,
        ) catch {};
    }

    pub fn setOnActivate(self: *Self, callback: *const fn (?*anyopaque) void, user_data: ?*anyopaque) void {
        self.on_activate = callback;
        self.user_data = user_data;
    }

    pub fn setOnSecondaryActivate(self: *Self, callback: *const fn (?*anyopaque) void) void {
        self.on_secondary_activate = callback;
    }

    pub fn setOnScroll(self: *Self, callback: *const fn (i32, [*:0]const u8, ?*anyopaque) void) void {
        self.on_scroll = callback;
    }
};

// ============================================
// Flatpak Portal Integration
// ============================================

pub const FlatpakPortal = struct {
    const FLATPAK_BUS_NAME = "org.freedesktop.portal.Flatpak";
    const FLATPAK_PATH = "/org/freedesktop/portal/Flatpak";

    /// Spawn a process outside the sandbox
    pub fn spawn(
        cwd: [*:0]const u8,
        argv: [][*:0]const u8,
        fds: []const c_int,
        env: []const struct { key: [*:0]const u8, value: [*:0]const u8 },
    ) !u32 {
        var conn = try Connection.getSession();
        defer conn.close();

        // Build argv array
        var argv_builder: c.GVariantBuilder = undefined;
        c.g_variant_builder_init(&argv_builder, c.G_VARIANT_TYPE("as"));
        for (argv) |arg| {
            c.g_variant_builder_add(&argv_builder, "s", arg);
        }

        // Build fds array
        var fds_builder: c.GVariantBuilder = undefined;
        c.g_variant_builder_init(&fds_builder, c.G_VARIANT_TYPE("a{uh}"));
        for (fds, 0..) |fd, i| {
            c.g_variant_builder_add(&fds_builder, "{uh}", @as(c_uint, @intCast(i)), fd);
        }

        // Build env array
        var env_builder: c.GVariantBuilder = undefined;
        c.g_variant_builder_init(&env_builder, c.G_VARIANT_TYPE("a{ss}"));
        for (env) |e| {
            c.g_variant_builder_add(&env_builder, "{ss}", e.key, e.value);
        }

        const params = c.g_variant_new(
            "(say@as@a{uh}@a{ss}u)",
            cwd,
            c.g_variant_builder_end(&argv_builder),
            c.g_variant_builder_end(&fds_builder),
            c.g_variant_builder_end(&env_builder),
            @as(c_uint, 0), // flags
        );

        const result = try conn.call(
            FLATPAK_BUS_NAME,
            FLATPAK_PATH,
            "org.freedesktop.portal.Flatpak",
            "Spawn",
            params,
            c.G_VARIANT_TYPE("(u)"),
            -1,
        );

        if (result) |r| {
            defer c.g_variant_unref(r);
            var pid: c_uint = 0;
            c.g_variant_get(r, "(u)", &pid);
            return pid;
        }

        return error.SpawnFailed;
    }

    /// Check if running in Flatpak
    pub fn isRunningInFlatpak() bool {
        // Check for /.flatpak-info
        const io = io_context.get();
        const file = std.Io.Dir.cwd().openFile(io, "/.flatpak-info", .{}) catch return false;
        file.close(io);
        return true;
    }
};

// ============================================
// Tests
// ============================================

test "BusType enum values" {
    try std.testing.expectEqual(@as(c_int, c.G_BUS_TYPE_SESSION), @intFromEnum(BusType.session));
    try std.testing.expectEqual(@as(c_int, c.G_BUS_TYPE_SYSTEM), @intFromEnum(BusType.system));
}

test "NetworkManager ConnectivityState" {
    try std.testing.expectEqual(@as(u32, 0), @intFromEnum(NetworkManager.ConnectivityState.unknown));
    try std.testing.expectEqual(@as(u32, 4), @intFromEnum(NetworkManager.ConnectivityState.full));
}
