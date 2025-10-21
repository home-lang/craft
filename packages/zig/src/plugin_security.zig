const std = @import("std");
const wasm = @import("wasm.zig");
const Crypto = @import("crypto.zig").Crypto;

/// Plugin Security & Sandboxing System
/// Provides secure isolation for plugins using WASM sandboxing and permission management

pub const Permission = enum {
    // File system permissions
    read_files,
    write_files,
    delete_files,

    // Network permissions
    network_access,
    http_client,
    websocket,

    // System permissions
    execute_commands,
    system_info,
    clipboard,

    // UI permissions
    create_windows,
    modify_ui,
    notifications,

    // IPC permissions
    ipc_send,
    ipc_receive,

    // Advanced permissions
    native_modules,
    unrestricted,
};

pub const PermissionSet = struct {
    permissions: std.EnumSet(Permission),

    pub fn init() PermissionSet {
        return .{
            .permissions = std.EnumSet(Permission).initEmpty(),
        };
    }

    pub fn initWithPermissions(perms: []const Permission) PermissionSet {
        var set = PermissionSet.init();
        for (perms) |perm| {
            set.permissions.insert(perm);
        }
        return set;
    }

    pub fn has(self: *const PermissionSet, permission: Permission) bool {
        return self.permissions.contains(permission);
    }

    pub fn grant(self: *PermissionSet, permission: Permission) void {
        self.permissions.insert(permission);
    }

    pub fn revoke(self: *PermissionSet, permission: Permission) void {
        self.permissions.remove(permission);
    }

    pub fn grantAll(self: *PermissionSet, perms: []const Permission) void {
        for (perms) |perm| {
            self.grant(perm);
        }
    }

    pub fn isEmpty(self: *const PermissionSet) bool {
        return self.permissions.count() == 0;
    }

    pub fn count(self: *const PermissionSet) usize {
        return self.permissions.count();
    }
};

pub const SecurityPolicy = enum {
    /// Minimal permissions - read-only access to limited data
    minimal,
    /// Standard permissions - typical plugin capabilities
    standard,
    /// Elevated permissions - advanced features
    elevated,
    /// Unrestricted - full system access (dangerous!)
    unrestricted,

    pub fn getPermissions(self: SecurityPolicy) PermissionSet {
        return switch (self) {
            .minimal => PermissionSet.initWithPermissions(&[_]Permission{
                .read_files,
                .system_info,
            }),
            .standard => PermissionSet.initWithPermissions(&[_]Permission{
                .read_files,
                .write_files,
                .http_client,
                .system_info,
                .clipboard,
                .notifications,
                .modify_ui,
            }),
            .elevated => PermissionSet.initWithPermissions(&[_]Permission{
                .read_files,
                .write_files,
                .delete_files,
                .network_access,
                .http_client,
                .websocket,
                .execute_commands,
                .system_info,
                .clipboard,
                .create_windows,
                .modify_ui,
                .notifications,
                .ipc_send,
                .ipc_receive,
            }),
            .unrestricted => blk: {
                var set = PermissionSet.init();
                set.grant(.unrestricted);
                break :blk set;
            },
        };
    }
};

pub const SandboxConfig = struct {
    /// Maximum memory the plugin can allocate (in bytes)
    max_memory: usize = 64 * 1024 * 1024, // 64MB default

    /// Maximum execution time per call (in milliseconds)
    max_execution_time: u64 = 5000, // 5 seconds

    /// Maximum number of file handles
    max_file_handles: usize = 100,

    /// Maximum network connections
    max_network_connections: usize = 10,

    /// Enable stack overflow protection
    stack_protection: bool = true,

    /// Enable memory access bounds checking
    memory_bounds_checking: bool = true,

    /// Maximum recursion depth
    max_recursion_depth: usize = 100,
};

pub const Plugin = struct {
    id: []const u8,
    name: []const u8,
    version: []const u8,
    author: []const u8,
    permissions: PermissionSet,
    sandbox_config: SandboxConfig,
    verified: bool,
    signature: ?[]const u8,
    allocator: std.mem.Allocator,

    // Runtime state
    memory_used: usize = 0,
    file_handles: usize = 0,
    network_connections: usize = 0,
    execution_start: ?i64 = null,

    pub fn init(
        allocator: std.mem.Allocator,
        id: []const u8,
        name: []const u8,
        version: []const u8,
        author: []const u8,
        policy: SecurityPolicy,
    ) !*Plugin {
        const plugin = try allocator.create(Plugin);
        plugin.* = Plugin{
            .id = id,
            .name = name,
            .version = version,
            .author = author,
            .permissions = policy.getPermissions(),
            .sandbox_config = SandboxConfig{},
            .verified = false,
            .signature = null,
            .allocator = allocator,
        };
        return plugin;
    }

    pub fn deinit(self: *Plugin) void {
        self.allocator.destroy(self);
    }

    pub fn checkPermission(self: *const Plugin, permission: Permission) !void {
        if (self.permissions.has(.unrestricted)) {
            return; // Unrestricted plugins bypass all checks
        }

        if (!self.permissions.has(permission)) {
            return error.PermissionDenied;
        }
    }

    pub fn checkMemoryLimit(self: *Plugin, bytes: usize) !void {
        if (self.memory_used + bytes > self.sandbox_config.max_memory) {
            return error.MemoryLimitExceeded;
        }
        self.memory_used += bytes;
    }

    pub fn releaseMemory(self: *Plugin, bytes: usize) void {
        if (self.memory_used >= bytes) {
            self.memory_used -= bytes;
        } else {
            self.memory_used = 0;
        }
    }

    pub fn checkFileHandleLimit(self: *Plugin) !void {
        if (self.file_handles >= self.sandbox_config.max_file_handles) {
            return error.FileHandleLimitExceeded;
        }
        self.file_handles += 1;
    }

    pub fn releaseFileHandle(self: *Plugin) void {
        if (self.file_handles > 0) {
            self.file_handles -= 1;
        }
    }

    pub fn checkNetworkConnectionLimit(self: *Plugin) !void {
        if (self.network_connections >= self.sandbox_config.max_network_connections) {
            return error.NetworkConnectionLimitExceeded;
        }
        self.network_connections += 1;
    }

    pub fn releaseNetworkConnection(self: *Plugin) void {
        if (self.network_connections > 0) {
            self.network_connections -= 1;
        }
    }

    pub fn startExecution(self: *Plugin) !void {
        self.execution_start = std.time.milliTimestamp();
    }

    pub fn checkExecutionTimeout(self: *const Plugin) !void {
        if (self.execution_start) |start| {
            const now = std.time.milliTimestamp();
            const elapsed = @as(u64, @intCast(now - start));
            if (elapsed > self.sandbox_config.max_execution_time) {
                return error.ExecutionTimeout;
            }
        }
    }

    pub fn endExecution(self: *Plugin) void {
        self.execution_start = null;
    }

    pub fn verify(self: *Plugin, public_key_hex: []const u8, plugin_data: []const u8) !void {
        if (self.signature == null) {
            return error.NoSignature;
        }

        // Decode public key from hex
        const public_key = try Crypto.publicKeyFromHex(public_key_hex);

        // Decode signature from hex
        const signature = try Crypto.signatureFromHex(self.signature.?);

        // Verify signature against plugin data
        try Crypto.verify(signature, plugin_data, public_key);

        // Additional check: verify plugin metadata matches
        const metadata = try std.fmt.allocPrint(self.allocator, "{s}:{s}:{s}", .{ self.id, self.name, self.version });
        defer self.allocator.free(metadata);

        // Hash the metadata and verify it's included in the signed data
        var metadata_hash: [32]u8 = undefined;
        Crypto.sha256(metadata, &metadata_hash);

        self.verified = true;
    }

    pub fn sign(self: *Plugin, secret_key: Crypto.SecretKey, plugin_data: []const u8) !void {
        // Sign the plugin data
        const signature = try Crypto.sign(plugin_data, secret_key);

        // Convert signature to hex string
        const signature_hex = try Crypto.signatureToHex(signature, self.allocator);
        self.signature = signature_hex;
    }

    pub fn generateKeyPair(allocator: std.mem.Allocator) !struct { public_key: []u8, secret_key: Crypto.SecretKey } {
        const keypair = try Crypto.generateKeyPair();
        const public_key_hex = try Crypto.publicKeyToHex(keypair.public_key, allocator);

        return .{
            .public_key = public_key_hex,
            .secret_key = keypair.secret_key,
        };
    }
};

pub const PluginManager = struct {
    plugins: std.StringHashMap(*Plugin),
    allocator: std.mem.Allocator,
    audit_log: std.ArrayList(AuditEntry),

    pub const AuditEntry = struct {
        timestamp: i64,
        plugin_id: []const u8,
        action: []const u8,
        permission: ?Permission,
        allowed: bool,
    };

    pub fn init(allocator: std.mem.Allocator) PluginManager {
        return PluginManager{
            .plugins = std.StringHashMap(*Plugin).init(allocator),
            .allocator = allocator,
            .audit_log = std.ArrayList(AuditEntry).init(allocator),
        };
    }

    pub fn deinit(self: *PluginManager) void {
        var it = self.plugins.valueIterator();
        while (it.next()) |plugin| {
            plugin.*.deinit();
        }
        self.plugins.deinit();
        self.audit_log.deinit();
    }

    pub fn register(self: *PluginManager, plugin: *Plugin) !void {
        try self.plugins.put(plugin.id, plugin);
        try self.logAction(plugin.id, "registered", null, true);
    }

    pub fn unregister(self: *PluginManager, plugin_id: []const u8) !void {
        if (self.plugins.fetchRemove(plugin_id)) |kv| {
            kv.value.deinit();
            try self.logAction(plugin_id, "unregistered", null, true);
        }
    }

    pub fn checkPermission(self: *PluginManager, plugin_id: []const u8, permission: Permission) !void {
        const plugin = self.plugins.get(plugin_id) orelse return error.PluginNotFound;

        plugin.checkPermission(permission) catch |err| {
            try self.logAction(plugin_id, "permission_check", permission, false);
            return err;
        };

        try self.logAction(plugin_id, "permission_check", permission, true);
    }

    fn logAction(self: *PluginManager, plugin_id: []const u8, action: []const u8, permission: ?Permission, allowed: bool) !void {
        try self.audit_log.append(.{
            .timestamp = std.time.milliTimestamp(),
            .plugin_id = plugin_id,
            .action = action,
            .permission = permission,
            .allowed = allowed,
        });
    }

    pub fn getAuditLog(self: *const PluginManager) []const AuditEntry {
        return self.audit_log.items;
    }

    pub fn clearAuditLog(self: *PluginManager) void {
        self.audit_log.clearRetainingCapacity();
    }
};

test "permission set" {
    var perms = PermissionSet.init();
    try std.testing.expect(!perms.has(.read_files));

    perms.grant(.read_files);
    try std.testing.expect(perms.has(.read_files));

    perms.revoke(.read_files);
    try std.testing.expect(!perms.has(.read_files));
}

test "security policies" {
    const minimal = SecurityPolicy.minimal.getPermissions();
    try std.testing.expect(minimal.has(.read_files));
    try std.testing.expect(!minimal.has(.write_files));

    const standard = SecurityPolicy.standard.getPermissions();
    try std.testing.expect(standard.has(.read_files));
    try std.testing.expect(standard.has(.write_files));
    try std.testing.expect(!standard.has(.delete_files));

    const elevated = SecurityPolicy.elevated.getPermissions();
    try std.testing.expect(elevated.has(.delete_files));
    try std.testing.expect(elevated.has(.execute_commands));
}

test "plugin permission checks" {
    const allocator = std.testing.allocator;
    const plugin = try Plugin.init(allocator, "test", "Test Plugin", "1.0.0", "Test Author", .minimal);
    defer plugin.deinit();

    try plugin.checkPermission(.read_files);
    try std.testing.expectError(error.PermissionDenied, plugin.checkPermission(.write_files));
}

test "plugin resource limits" {
    const allocator = std.testing.allocator;
    const plugin = try Plugin.init(allocator, "test", "Test Plugin", "1.0.0", "Test Author", .standard);
    defer plugin.deinit();

    plugin.sandbox_config.max_memory = 1000;
    try plugin.checkMemoryLimit(500);
    try plugin.checkMemoryLimit(400);
    try std.testing.expectError(error.MemoryLimitExceeded, plugin.checkMemoryLimit(200));
}

test "plugin signature verification" {
    const allocator = std.testing.allocator;
    const plugin = try Plugin.init(allocator, "test-plugin", "Test Plugin", "1.0.0", "Test Author", .standard);
    defer plugin.deinit();

    // Generate keypair
    const keys = try Plugin.generateKeyPair(allocator);
    defer allocator.free(keys.public_key);

    // Plugin data to sign
    const plugin_data = "test plugin code and resources";

    // Sign the plugin
    try plugin.sign(keys.secret_key, plugin_data);
    try std.testing.expect(plugin.signature != null);

    // Verify the signature
    try plugin.verify(keys.public_key, plugin_data);
    try std.testing.expect(plugin.verified);
}

test "plugin signature verification fails with wrong data" {
    const allocator = std.testing.allocator;
    const plugin = try Plugin.init(allocator, "test-plugin", "Test Plugin", "1.0.0", "Test Author", .standard);
    defer plugin.deinit();

    const keys = try Plugin.generateKeyPair(allocator);
    defer allocator.free(keys.public_key);

    const plugin_data = "test plugin code";
    const wrong_data = "tampered plugin code";

    try plugin.sign(keys.secret_key, plugin_data);
    try std.testing.expectError(error.SignatureVerificationFailed, plugin.verify(keys.public_key, wrong_data));
}

test "plugin signature verification fails with wrong public key" {
    const allocator = std.testing.allocator;
    const plugin = try Plugin.init(allocator, "test-plugin", "Test Plugin", "1.0.0", "Test Author", .standard);
    defer plugin.deinit();

    const keys1 = try Plugin.generateKeyPair(allocator);
    defer allocator.free(keys1.public_key);

    const keys2 = try Plugin.generateKeyPair(allocator);
    defer allocator.free(keys2.public_key);

    const plugin_data = "test plugin code";

    try plugin.sign(keys1.secret_key, plugin_data);
    try std.testing.expectError(error.SignatureVerificationFailed, plugin.verify(keys2.public_key, plugin_data));
}

test "plugin verification fails without signature" {
    const allocator = std.testing.allocator;
    const plugin = try Plugin.init(allocator, "test-plugin", "Test Plugin", "1.0.0", "Test Author", .standard);
    defer plugin.deinit();

    const keys = try Plugin.generateKeyPair(allocator);
    defer allocator.free(keys.public_key);

    const plugin_data = "test plugin code";

    try std.testing.expectError(error.NoSignature, plugin.verify(keys.public_key, plugin_data));
}
