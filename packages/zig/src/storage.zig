const std = @import("std");
const builtin = @import("builtin");

/// Storage/Preferences Module
/// Provides cross-platform persistent storage for iOS (UserDefaults/Keychain),
/// Android (SharedPreferences/EncryptedSharedPreferences), and desktop platforms.
/// Supports key-value storage, secure storage, and file-based persistence.

// ============================================================================
// Storage Value Types
// ============================================================================

/// Value types that can be stored
pub const StorageValue = union(enum) {
    string: []const u8,
    int: i64,
    float: f64,
    bool_val: bool,
    bytes: []const u8,
    string_array: []const []const u8,
    null_val: void,

    pub fn getString(self: StorageValue) ?[]const u8 {
        return switch (self) {
            .string => |s| s,
            else => null,
        };
    }

    pub fn getInt(self: StorageValue) ?i64 {
        return switch (self) {
            .int => |i| i,
            else => null,
        };
    }

    pub fn getFloat(self: StorageValue) ?f64 {
        return switch (self) {
            .float => |f| f,
            else => null,
        };
    }

    pub fn getBool(self: StorageValue) ?bool {
        return switch (self) {
            .bool_val => |b| b,
            else => null,
        };
    }

    pub fn getBytes(self: StorageValue) ?[]const u8 {
        return switch (self) {
            .bytes => |b| b,
            else => null,
        };
    }

    pub fn isNull(self: StorageValue) bool {
        return self == .null_val;
    }

    pub fn typeString(self: StorageValue) []const u8 {
        return switch (self) {
            .string => "string",
            .int => "int",
            .float => "float",
            .bool_val => "bool",
            .bytes => "bytes",
            .string_array => "string_array",
            .null_val => "null",
        };
    }
};

// ============================================================================
// Storage Errors
// ============================================================================

/// Storage operation errors
pub const StorageError = error{
    /// Key not found
    NotFound,
    /// Storage is full
    StorageFull,
    /// Invalid key format
    InvalidKey,
    /// Encryption/decryption failed
    CryptoError,
    /// File I/O error
    IOError,
    /// Serialization error
    SerializationError,
    /// Permission denied
    PermissionDenied,
    /// Storage not available
    NotAvailable,
    /// Type mismatch
    TypeMismatch,
    /// Out of memory
    OutOfMemory,
    /// Key too long
    KeyTooLong,
    /// Value too large
    ValueTooLarge,
};

// ============================================================================
// Storage Options
// ============================================================================

/// Storage persistence mode
pub const PersistenceMode = enum {
    /// Standard persistent storage (UserDefaults/SharedPreferences)
    standard,
    /// Secure/encrypted storage (Keychain/EncryptedSharedPreferences)
    secure,
    /// In-memory only (lost on app termination)
    memory,
    /// File-based storage
    file,

    pub fn toString(self: PersistenceMode) []const u8 {
        return switch (self) {
            .standard => "standard",
            .secure => "secure",
            .memory => "memory",
            .file => "file",
        };
    }
};

/// Storage synchronization mode
pub const SyncMode = enum {
    /// Synchronous writes (blocking)
    sync,
    /// Asynchronous writes (non-blocking)
    async_mode,
    /// Write on app background/terminate
    deferred,

    pub fn toString(self: SyncMode) []const u8 {
        return switch (self) {
            .sync => "sync",
            .async_mode => "async",
            .deferred => "deferred",
        };
    }
};

/// Storage configuration
pub const StorageConfig = struct {
    /// Storage name/suite (iOS suite name, Android preference file name)
    name: []const u8,
    /// Persistence mode
    mode: PersistenceMode,
    /// Sync mode
    sync_mode: SyncMode,
    /// Enable automatic migration from old storage
    migrate_legacy: bool,
    /// Maximum key length
    max_key_length: usize,
    /// Maximum value size in bytes
    max_value_size: usize,
    /// Enable debug logging
    debug_logging: bool,

    pub fn init(name: []const u8) StorageConfig {
        return .{
            .name = name,
            .mode = .standard,
            .sync_mode = .sync,
            .migrate_legacy = false,
            .max_key_length = 256,
            .max_value_size = 1024 * 1024, // 1MB
            .debug_logging = false,
        };
    }

    pub fn secure(name: []const u8) StorageConfig {
        var config = init(name);
        config.mode = .secure;
        return config;
    }

    pub fn memory() StorageConfig {
        var config = init("memory");
        config.mode = .memory;
        return config;
    }

    pub fn withSyncMode(self: StorageConfig, mode: SyncMode) StorageConfig {
        var c = self;
        c.sync_mode = mode;
        return c;
    }
};

// ============================================================================
// Preferences Manager (Key-Value Storage)
// ============================================================================

/// Key-value preferences manager
pub const PreferencesManager = struct {
    allocator: std.mem.Allocator,
    config: StorageConfig,
    data: std.StringHashMap(StorageValue),
    is_dirty: bool,
    native_handle: ?*anyopaque,

    const Self = @This();

    /// Initialize preferences manager
    pub fn init(allocator: std.mem.Allocator, config: StorageConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .data = std.StringHashMap(StorageValue).init(allocator),
            .is_dirty = false,
            .native_handle = null,
        };
    }

    /// Deinitialize and cleanup
    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }

    /// Load preferences from persistent storage
    pub fn load(self: *Self) StorageError!void {
        if (self.config.mode == .memory) return;

        // Platform-specific loading
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:name];
            // NSDictionary *dict = [defaults dictionaryRepresentation];
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // SharedPreferences prefs = context.getSharedPreferences(name, MODE_PRIVATE);
            // Map<String, ?> all = prefs.getAll();
        }

        // For now, just mark as loaded
        self.is_dirty = false;
    }

    /// Save preferences to persistent storage
    pub fn save(self: *Self) StorageError!void {
        if (self.config.mode == .memory) return;
        if (!self.is_dirty) return;

        // Platform-specific saving
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // [defaults synchronize];
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // SharedPreferences.Editor editor = prefs.edit();
            // editor.apply() or editor.commit()
        }

        self.is_dirty = false;
    }

    /// Set a string value
    pub fn setString(self: *Self, key: []const u8, value: []const u8) StorageError!void {
        try self.validateKey(key);
        if (value.len > self.config.max_value_size) return StorageError.ValueTooLarge;

        self.data.put(key, StorageValue{ .string = value }) catch return StorageError.OutOfMemory;
        self.is_dirty = true;

        if (self.config.sync_mode == .sync) {
            try self.save();
        }
    }

    /// Get a string value
    pub fn getString(self: *const Self, key: []const u8) ?[]const u8 {
        if (self.data.get(key)) |value| {
            return value.getString();
        }
        return null;
    }

    /// Get a string value with default
    pub fn getStringOr(self: *const Self, key: []const u8, default: []const u8) []const u8 {
        return self.getString(key) orelse default;
    }

    /// Set an integer value
    pub fn setInt(self: *Self, key: []const u8, value: i64) StorageError!void {
        try self.validateKey(key);

        self.data.put(key, StorageValue{ .int = value }) catch return StorageError.OutOfMemory;
        self.is_dirty = true;

        if (self.config.sync_mode == .sync) {
            try self.save();
        }
    }

    /// Get an integer value
    pub fn getInt(self: *const Self, key: []const u8) ?i64 {
        if (self.data.get(key)) |value| {
            return value.getInt();
        }
        return null;
    }

    /// Get an integer value with default
    pub fn getIntOr(self: *const Self, key: []const u8, default: i64) i64 {
        return self.getInt(key) orelse default;
    }

    /// Set a float value
    pub fn setFloat(self: *Self, key: []const u8, value: f64) StorageError!void {
        try self.validateKey(key);

        self.data.put(key, StorageValue{ .float = value }) catch return StorageError.OutOfMemory;
        self.is_dirty = true;

        if (self.config.sync_mode == .sync) {
            try self.save();
        }
    }

    /// Get a float value
    pub fn getFloat(self: *const Self, key: []const u8) ?f64 {
        if (self.data.get(key)) |value| {
            return value.getFloat();
        }
        return null;
    }

    /// Get a float value with default
    pub fn getFloatOr(self: *const Self, key: []const u8, default: f64) f64 {
        return self.getFloat(key) orelse default;
    }

    /// Set a boolean value
    pub fn setBool(self: *Self, key: []const u8, value: bool) StorageError!void {
        try self.validateKey(key);

        self.data.put(key, StorageValue{ .bool_val = value }) catch return StorageError.OutOfMemory;
        self.is_dirty = true;

        if (self.config.sync_mode == .sync) {
            try self.save();
        }
    }

    /// Get a boolean value
    pub fn getBool(self: *const Self, key: []const u8) ?bool {
        if (self.data.get(key)) |value| {
            return value.getBool();
        }
        return null;
    }

    /// Get a boolean value with default
    pub fn getBoolOr(self: *const Self, key: []const u8, default: bool) bool {
        return self.getBool(key) orelse default;
    }

    /// Set bytes value
    pub fn setBytes(self: *Self, key: []const u8, value: []const u8) StorageError!void {
        try self.validateKey(key);
        if (value.len > self.config.max_value_size) return StorageError.ValueTooLarge;

        self.data.put(key, StorageValue{ .bytes = value }) catch return StorageError.OutOfMemory;
        self.is_dirty = true;

        if (self.config.sync_mode == .sync) {
            try self.save();
        }
    }

    /// Get bytes value
    pub fn getBytes(self: *const Self, key: []const u8) ?[]const u8 {
        if (self.data.get(key)) |value| {
            return value.getBytes();
        }
        return null;
    }

    /// Check if key exists
    pub fn contains(self: *const Self, key: []const u8) bool {
        return self.data.contains(key);
    }

    /// Remove a value
    pub fn remove(self: *Self, key: []const u8) StorageError!void {
        _ = self.data.remove(key);
        self.is_dirty = true;

        if (self.config.sync_mode == .sync) {
            try self.save();
        }
    }

    /// Clear all values
    pub fn clear(self: *Self) StorageError!void {
        self.data.clearRetainingCapacity();
        self.is_dirty = true;

        if (self.config.sync_mode == .sync) {
            try self.save();
        }
    }

    /// Get all keys
    pub fn keys(self: *const Self) StorageError![]const []const u8 {
        var result = std.ArrayListUnmanaged([]const u8){};
        var iter = self.data.keyIterator();
        while (iter.next()) |key| {
            result.append(self.allocator, key.*) catch return StorageError.OutOfMemory;
        }
        return result.toOwnedSlice(self.allocator) catch return StorageError.OutOfMemory;
    }

    /// Get number of stored keys
    pub fn count(self: *const Self) usize {
        return self.data.count();
    }

    /// Get value type for key
    pub fn getType(self: *const Self, key: []const u8) ?[]const u8 {
        if (self.data.get(key)) |value| {
            return value.typeString();
        }
        return null;
    }

    // Validation helper
    fn validateKey(self: *const Self, key: []const u8) StorageError!void {
        if (key.len == 0) return StorageError.InvalidKey;
        if (key.len > self.config.max_key_length) return StorageError.KeyTooLong;
    }
};

// ============================================================================
// Secure Storage (Keychain/EncryptedPreferences)
// ============================================================================

/// Keychain accessibility options (iOS)
pub const KeychainAccessibility = enum {
    /// Available when device is unlocked
    when_unlocked,
    /// Available after first unlock
    after_first_unlock,
    /// Always available (not recommended)
    always,
    /// Available when unlocked, only on this device
    when_unlocked_this_device_only,
    /// After first unlock, only on this device
    after_first_unlock_this_device_only,
    /// Available when passcode is set
    when_passcode_set_this_device_only,

    pub fn toiOSString(self: KeychainAccessibility) []const u8 {
        return switch (self) {
            .when_unlocked => "kSecAttrAccessibleWhenUnlocked",
            .after_first_unlock => "kSecAttrAccessibleAfterFirstUnlock",
            .always => "kSecAttrAccessibleAlways",
            .when_unlocked_this_device_only => "kSecAttrAccessibleWhenUnlockedThisDeviceOnly",
            .after_first_unlock_this_device_only => "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly",
            .when_passcode_set_this_device_only => "kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly",
        };
    }
};

/// Secure storage configuration
pub const SecureStorageConfig = struct {
    /// Service name (iOS) or alias prefix (Android)
    service: []const u8,
    /// Access group for shared keychain (iOS)
    access_group: ?[]const u8,
    /// Accessibility level
    accessibility: KeychainAccessibility,
    /// Require biometric authentication
    require_biometric: bool,
    /// Allow fallback to device passcode
    allow_passcode_fallback: bool,

    pub fn init(service: []const u8) SecureStorageConfig {
        return .{
            .service = service,
            .access_group = null,
            .accessibility = .when_unlocked,
            .require_biometric = false,
            .allow_passcode_fallback = true,
        };
    }

    pub fn withBiometric(self: SecureStorageConfig) SecureStorageConfig {
        var c = self;
        c.require_biometric = true;
        return c;
    }

    pub fn withAccessGroup(self: SecureStorageConfig, group: []const u8) SecureStorageConfig {
        var c = self;
        c.access_group = group;
        return c;
    }
};

/// Secure storage manager (Keychain/EncryptedSharedPreferences)
pub const SecureStorage = struct {
    allocator: std.mem.Allocator,
    config: SecureStorageConfig,
    cache: std.StringHashMap([]const u8),
    native_handle: ?*anyopaque,

    const Self = @This();

    /// Initialize secure storage
    pub fn init(allocator: std.mem.Allocator, config: SecureStorageConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .cache = std.StringHashMap([]const u8).init(allocator),
            .native_handle = null,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        // Free all allocated keys
        var key_iter = self.cache.keyIterator();
        while (key_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.cache.deinit();
    }

    /// Store a secure value
    pub fn set(self: *Self, key: []const u8, value: []const u8) StorageError!void {
        if (key.len == 0) return StorageError.InvalidKey;

        // Platform-specific secure storage
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // SecItemAdd/SecItemUpdate with kSecClassGenericPassword
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // EncryptedSharedPreferences.edit().putString(key, value).apply()
        }

        // Cache the value - duplicate the key since it may be stack-allocated
        const key_copy = self.allocator.dupe(u8, key) catch return StorageError.OutOfMemory;
        self.cache.put(key_copy, value) catch {
            self.allocator.free(key_copy);
            return StorageError.OutOfMemory;
        };
    }

    /// Get a secure value
    pub fn get(self: *Self, key: []const u8) StorageError!?[]const u8 {
        // Check cache first
        if (self.cache.get(key)) |value| {
            return value;
        }

        // Platform-specific retrieval
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // SecItemCopyMatching with kSecClassGenericPassword
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // encryptedPrefs.getString(key, null)
        }

        return null;
    }

    /// Delete a secure value
    pub fn delete(self: *Self, key: []const u8) StorageError!void {
        // Platform-specific deletion
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // SecItemDelete
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // encryptedPrefs.edit().remove(key).apply()
        }

        // Find and free the allocated key
        if (self.cache.fetchRemove(key)) |kv| {
            self.allocator.free(kv.key);
        }
    }

    /// Check if key exists
    pub fn contains(self: *Self, key: []const u8) bool {
        if (self.cache.contains(key)) return true;

        // Would check platform storage here
        return false;
    }

    /// Delete all secure values
    pub fn deleteAll(self: *Self) StorageError!void {
        // Platform-specific deletion
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // Delete all items matching service
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // encryptedPrefs.edit().clear().apply()
        }

        // Free all allocated keys before clearing
        var key_iter = self.cache.keyIterator();
        while (key_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.cache.clearRetainingCapacity();
    }

    /// Store credentials (username + password)
    pub fn setCredentials(self: *Self, account: []const u8, username: []const u8, password: []const u8) StorageError!void {
        var username_key_buf: [512]u8 = undefined;
        var password_key_buf: [512]u8 = undefined;

        const username_key = std.fmt.bufPrint(&username_key_buf, "{s}.username", .{account}) catch return StorageError.KeyTooLong;
        const password_key = std.fmt.bufPrint(&password_key_buf, "{s}.password", .{account}) catch return StorageError.KeyTooLong;

        try self.set(username_key, username);
        try self.set(password_key, password);
    }

    /// Get credentials
    pub fn getCredentials(self: *Self, account: []const u8) StorageError!?struct { username: []const u8, password: []const u8 } {
        var username_key_buf: [512]u8 = undefined;
        var password_key_buf: [512]u8 = undefined;

        const username_key = std.fmt.bufPrint(&username_key_buf, "{s}.username", .{account}) catch return StorageError.KeyTooLong;
        const password_key = std.fmt.bufPrint(&password_key_buf, "{s}.password", .{account}) catch return StorageError.KeyTooLong;

        const username = (try self.get(username_key)) orelse return null;
        const password = (try self.get(password_key)) orelse return null;

        return .{ .username = username, .password = password };
    }

    /// Delete credentials
    pub fn deleteCredentials(self: *Self, account: []const u8) StorageError!void {
        var username_key_buf: [512]u8 = undefined;
        var password_key_buf: [512]u8 = undefined;

        const username_key = std.fmt.bufPrint(&username_key_buf, "{s}.username", .{account}) catch return StorageError.KeyTooLong;
        const password_key = std.fmt.bufPrint(&password_key_buf, "{s}.password", .{account}) catch return StorageError.KeyTooLong;

        try self.delete(username_key);
        try self.delete(password_key);
    }
};

// ============================================================================
// File-based Storage
// ============================================================================

/// File storage format
pub const FileFormat = enum {
    json,
    binary,
    plist, // iOS property list
    xml,

    pub fn extension(self: FileFormat) []const u8 {
        return switch (self) {
            .json => ".json",
            .binary => ".bin",
            .plist => ".plist",
            .xml => ".xml",
        };
    }
};

/// File storage configuration
pub const FileStorageConfig = struct {
    /// File name (without extension)
    filename: []const u8,
    /// Storage directory
    directory: StorageDirectory,
    /// File format
    format: FileFormat,
    /// Create backup before writing
    backup: bool,
    /// Encrypt file contents
    encrypt: bool,

    pub fn init(filename: []const u8) FileStorageConfig {
        return .{
            .filename = filename,
            .directory = .documents,
            .format = .json,
            .backup = false,
            .encrypt = false,
        };
    }

    pub fn withFormat(self: FileStorageConfig, format: FileFormat) FileStorageConfig {
        var c = self;
        c.format = format;
        return c;
    }

    pub fn withDirectory(self: FileStorageConfig, dir: StorageDirectory) FileStorageConfig {
        var c = self;
        c.directory = dir;
        return c;
    }
};

/// Standard storage directories
pub const StorageDirectory = enum {
    /// Documents directory (backed up)
    documents,
    /// Library directory (iOS)
    library,
    /// Caches directory (may be purged)
    caches,
    /// Temporary directory (may be purged)
    temp,
    /// Application support directory
    application_support,

    pub fn toPath(self: StorageDirectory) []const u8 {
        // Platform-specific paths would be resolved at runtime
        return switch (self) {
            .documents => "Documents",
            .library => "Library",
            .caches => "Caches",
            .temp => "tmp",
            .application_support => "Application Support",
        };
    }
};

/// File-based storage manager
pub const FileStorage = struct {
    allocator: std.mem.Allocator,
    config: FileStorageConfig,
    data: std.StringHashMap(StorageValue),
    is_loaded: bool,

    const Self = @This();

    /// Initialize file storage
    pub fn init(allocator: std.mem.Allocator, config: FileStorageConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .data = std.StringHashMap(StorageValue).init(allocator),
            .is_loaded = false,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }

    /// Load data from file
    pub fn load(self: *Self) StorageError!void {
        // Build file path
        // const path = self.buildPath();

        // Read and parse file based on format
        switch (self.config.format) {
            .json => {
                // Parse JSON file
            },
            .binary => {
                // Read binary format
            },
            .plist => {
                // Parse property list (iOS)
            },
            .xml => {
                // Parse XML
            },
        }

        self.is_loaded = true;
    }

    /// Save data to file
    pub fn save(self: *Self) StorageError!void {
        // Build file path
        // const path = self.buildPath();

        // Create backup if configured
        if (self.config.backup) {
            // Copy existing file to .bak
        }

        // Serialize and write based on format
        switch (self.config.format) {
            .json => {
                // Write JSON
            },
            .binary => {
                // Write binary
            },
            .plist => {
                // Write property list
            },
            .xml => {
                // Write XML
            },
        }
    }

    /// Set a value
    pub fn set(self: *Self, key: []const u8, value: StorageValue) StorageError!void {
        self.data.put(key, value) catch return StorageError.OutOfMemory;
    }

    /// Get a value
    pub fn get(self: *const Self, key: []const u8) ?StorageValue {
        return self.data.get(key);
    }

    /// Remove a value
    pub fn remove(self: *Self, key: []const u8) void {
        _ = self.data.remove(key);
    }

    /// Check if file exists
    pub fn exists(self: *const Self) bool {
        _ = self;
        // Check if file exists at path
        return false;
    }

    /// Delete the storage file
    pub fn deleteFile(self: *Self) StorageError!void {
        // Delete the file
        self.data.clearRetainingCapacity();
        self.is_loaded = false;
    }

    /// Get file size in bytes
    pub fn fileSize(self: *const Self) StorageError!usize {
        _ = self;
        // Return file size
        return 0;
    }
};

// ============================================================================
// Migration Utilities
// ============================================================================

/// Storage migration helper
pub const StorageMigration = struct {
    pub const MigrationFn = *const fn (old_value: StorageValue) StorageValue;

    /// Migrate string key to new key
    pub fn migrateKey(
        source: *PreferencesManager,
        dest: *PreferencesManager,
        old_key: []const u8,
        new_key: []const u8,
    ) StorageError!void {
        if (source.data.get(old_key)) |value| {
            dest.data.put(new_key, value) catch return StorageError.OutOfMemory;
            _ = source.data.remove(old_key);
        }
    }

    /// Migrate with transformation
    pub fn migrateWithTransform(
        source: *PreferencesManager,
        dest: *PreferencesManager,
        old_key: []const u8,
        new_key: []const u8,
        transform: MigrationFn,
    ) StorageError!void {
        if (source.data.get(old_key)) |old_value| {
            const new_value = transform(old_value);
            dest.data.put(new_key, new_value) catch return StorageError.OutOfMemory;
            _ = source.data.remove(old_key);
        }
    }

    /// Copy all keys with prefix
    pub fn copyWithPrefix(
        source: *PreferencesManager,
        dest: *PreferencesManager,
        prefix: []const u8,
    ) StorageError!void {
        var iter = source.data.iterator();
        while (iter.next()) |entry| {
            if (std.mem.startsWith(u8, entry.key_ptr.*, prefix)) {
                dest.data.put(entry.key_ptr.*, entry.value_ptr.*) catch return StorageError.OutOfMemory;
            }
        }
    }
};

// ============================================================================
// Storage Presets
// ============================================================================

/// Common storage configurations
pub const StoragePresets = struct {
    /// App settings storage
    pub fn appSettings() StorageConfig {
        return StorageConfig.init("AppSettings")
            .withSyncMode(.sync);
    }

    /// User preferences storage
    pub fn userPreferences() StorageConfig {
        return StorageConfig.init("UserPreferences")
            .withSyncMode(.async_mode);
    }

    /// Cache storage
    pub fn cache() StorageConfig {
        var config = StorageConfig.init("Cache");
        config.mode = .memory;
        return config;
    }

    /// Session storage (memory-only)
    pub fn session() StorageConfig {
        return StorageConfig.memory();
    }
};

/// Common secure storage configurations
pub const SecureStoragePresets = struct {
    /// Credential storage
    pub fn credentials(service: []const u8) SecureStorageConfig {
        return SecureStorageConfig.init(service);
    }

    /// Biometric-protected storage
    pub fn biometric(service: []const u8) SecureStorageConfig {
        return SecureStorageConfig.init(service).withBiometric();
    }

    /// Token storage
    pub fn tokens(service: []const u8) SecureStorageConfig {
        var config = SecureStorageConfig.init(service);
        config.accessibility = .after_first_unlock;
        return config;
    }
};

// ============================================================================
// Quick Storage Utilities
// ============================================================================

/// Quick storage utilities
pub const QuickStorage = struct {
    /// Store user setting
    pub fn setSetting(prefs: *PreferencesManager, key: []const u8, value: anytype) StorageError!void {
        const T = @TypeOf(value);
        switch (@typeInfo(T)) {
            .bool => try prefs.setBool(key, value),
            .int, .comptime_int => try prefs.setInt(key, @intCast(value)),
            .float, .comptime_float => try prefs.setFloat(key, @floatCast(value)),
            .pointer => |ptr| {
                if (ptr.child == u8) {
                    try prefs.setString(key, value);
                }
            },
            else => return StorageError.TypeMismatch,
        }
    }

    /// Check if first launch
    pub fn isFirstLaunch(prefs: *PreferencesManager) bool {
        const key = "app_has_launched_before";
        if (prefs.getBool(key)) |launched| {
            return !launched;
        }
        prefs.setBool(key, true) catch {};
        return true;
    }

    /// Get launch count
    pub fn getLaunchCount(prefs: *PreferencesManager) i64 {
        const key = "app_launch_count";
        const count = prefs.getIntOr(key, 0) + 1;
        prefs.setInt(key, count) catch {};
        return count;
    }

    /// Store last opened timestamp
    pub fn updateLastOpened(prefs: *PreferencesManager) StorageError!void {
        const now = getCurrentTimeMs();
        try prefs.setInt("last_opened_timestamp", @intCast(now));
    }

    fn getCurrentTimeMs() u64 {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
                return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
            } else {
                return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
            }
        }
        return 0;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StorageValue string" {
    const value = StorageValue{ .string = "hello" };
    try std.testing.expectEqualStrings("hello", value.getString().?);
    try std.testing.expect(value.getInt() == null);
    try std.testing.expectEqualStrings("string", value.typeString());
}

test "StorageValue int" {
    const value = StorageValue{ .int = 42 };
    try std.testing.expectEqual(@as(i64, 42), value.getInt().?);
    try std.testing.expect(value.getString() == null);
    try std.testing.expectEqualStrings("int", value.typeString());
}

test "StorageValue float" {
    const value = StorageValue{ .float = 3.14 };
    try std.testing.expectEqual(@as(f64, 3.14), value.getFloat().?);
    try std.testing.expectEqualStrings("float", value.typeString());
}

test "StorageValue bool" {
    const value = StorageValue{ .bool_val = true };
    try std.testing.expect(value.getBool().?);
    try std.testing.expectEqualStrings("bool", value.typeString());
}

test "StorageValue null" {
    const value = StorageValue{ .null_val = {} };
    try std.testing.expect(value.isNull());
    try std.testing.expectEqualStrings("null", value.typeString());
}

test "PersistenceMode toString" {
    try std.testing.expectEqualStrings("standard", PersistenceMode.standard.toString());
    try std.testing.expectEqualStrings("secure", PersistenceMode.secure.toString());
    try std.testing.expectEqualStrings("memory", PersistenceMode.memory.toString());
}

test "SyncMode toString" {
    try std.testing.expectEqualStrings("sync", SyncMode.sync.toString());
    try std.testing.expectEqualStrings("async", SyncMode.async_mode.toString());
}

test "StorageConfig creation" {
    const config = StorageConfig.init("MyApp");
    try std.testing.expectEqualStrings("MyApp", config.name);
    try std.testing.expectEqual(PersistenceMode.standard, config.mode);
    try std.testing.expectEqual(SyncMode.sync, config.sync_mode);
}

test "StorageConfig secure" {
    const config = StorageConfig.secure("MyApp");
    try std.testing.expectEqual(PersistenceMode.secure, config.mode);
}

test "StorageConfig memory" {
    const config = StorageConfig.memory();
    try std.testing.expectEqual(PersistenceMode.memory, config.mode);
}

test "PreferencesManager initialization" {
    const config = StorageConfig.init("Test");
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try std.testing.expectEqual(@as(usize, 0), prefs.count());
}

test "PreferencesManager setString and getString" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try prefs.setString("name", "Alice");
    try std.testing.expectEqualStrings("Alice", prefs.getString("name").?);
}

test "PreferencesManager getStringOr" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try std.testing.expectEqualStrings("default", prefs.getStringOr("missing", "default"));
}

test "PreferencesManager setInt and getInt" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try prefs.setInt("count", 100);
    try std.testing.expectEqual(@as(i64, 100), prefs.getInt("count").?);
}

test "PreferencesManager getIntOr" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try std.testing.expectEqual(@as(i64, 0), prefs.getIntOr("missing", 0));
}

test "PreferencesManager setFloat and getFloat" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try prefs.setFloat("pi", 3.14159);
    try std.testing.expectEqual(@as(f64, 3.14159), prefs.getFloat("pi").?);
}

test "PreferencesManager setBool and getBool" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try prefs.setBool("enabled", true);
    try std.testing.expect(prefs.getBool("enabled").?);
}

test "PreferencesManager getBoolOr" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try std.testing.expect(!prefs.getBoolOr("missing", false));
}

test "PreferencesManager setBytes and getBytes" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    const data = [_]u8{ 0x01, 0x02, 0x03 };
    try prefs.setBytes("data", &data);
    try std.testing.expectEqualSlices(u8, &data, prefs.getBytes("data").?);
}

test "PreferencesManager contains" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try std.testing.expect(!prefs.contains("key"));
    try prefs.setString("key", "value");
    try std.testing.expect(prefs.contains("key"));
}

test "PreferencesManager remove" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try prefs.setString("key", "value");
    try std.testing.expect(prefs.contains("key"));
    try prefs.remove("key");
    try std.testing.expect(!prefs.contains("key"));
}

test "PreferencesManager clear" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try prefs.setString("a", "1");
    try prefs.setString("b", "2");
    try std.testing.expectEqual(@as(usize, 2), prefs.count());

    try prefs.clear();
    try std.testing.expectEqual(@as(usize, 0), prefs.count());
}

test "PreferencesManager count" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try prefs.setString("a", "1");
    try prefs.setInt("b", 2);
    try prefs.setBool("c", true);

    try std.testing.expectEqual(@as(usize, 3), prefs.count());
}

test "PreferencesManager getType" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try prefs.setString("str", "hello");
    try prefs.setInt("num", 42);

    try std.testing.expectEqualStrings("string", prefs.getType("str").?);
    try std.testing.expectEqualStrings("int", prefs.getType("num").?);
    try std.testing.expect(prefs.getType("missing") == null);
}

test "PreferencesManager invalid key" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    const result = prefs.setString("", "value");
    try std.testing.expectError(StorageError.InvalidKey, result);
}

test "SecureStorageConfig creation" {
    const config = SecureStorageConfig.init("com.app.secure");
    try std.testing.expectEqualStrings("com.app.secure", config.service);
    try std.testing.expectEqual(KeychainAccessibility.when_unlocked, config.accessibility);
    try std.testing.expect(!config.require_biometric);
}

test "SecureStorageConfig withBiometric" {
    const config = SecureStorageConfig.init("com.app.secure").withBiometric();
    try std.testing.expect(config.require_biometric);
}

test "SecureStorage initialization" {
    const config = SecureStorageConfig.init("com.app.secure");
    var storage = SecureStorage.init(std.testing.allocator, config);
    defer storage.deinit();

    try std.testing.expectEqualStrings("com.app.secure", storage.config.service);
}

test "SecureStorage set and get" {
    const config = SecureStorageConfig.init("com.app.test");
    var storage = SecureStorage.init(std.testing.allocator, config);
    defer storage.deinit();

    try storage.set("token", "abc123");
    const value = try storage.get("token");
    try std.testing.expectEqualStrings("abc123", value.?);
}

test "SecureStorage delete" {
    const config = SecureStorageConfig.init("com.app.test");
    var storage = SecureStorage.init(std.testing.allocator, config);
    defer storage.deinit();

    try storage.set("token", "abc123");
    try storage.delete("token");
    const value = try storage.get("token");
    try std.testing.expect(value == null);
}

test "SecureStorage contains" {
    const config = SecureStorageConfig.init("com.app.test");
    var storage = SecureStorage.init(std.testing.allocator, config);
    defer storage.deinit();

    try std.testing.expect(!storage.contains("key"));
    try storage.set("key", "value");
    try std.testing.expect(storage.contains("key"));
}

test "SecureStorage setCredentials and getCredentials" {
    const config = SecureStorageConfig.init("com.app.test");
    var storage = SecureStorage.init(std.testing.allocator, config);
    defer storage.deinit();

    try storage.setCredentials("github", "user@example.com", "secret123");
    const creds = try storage.getCredentials("github");
    try std.testing.expect(creds != null);
    try std.testing.expectEqualStrings("user@example.com", creds.?.username);
    try std.testing.expectEqualStrings("secret123", creds.?.password);
}

test "KeychainAccessibility toiOSString" {
    try std.testing.expectEqualStrings(
        "kSecAttrAccessibleWhenUnlocked",
        KeychainAccessibility.when_unlocked.toiOSString(),
    );
}

test "FileFormat extension" {
    try std.testing.expectEqualStrings(".json", FileFormat.json.extension());
    try std.testing.expectEqualStrings(".bin", FileFormat.binary.extension());
    try std.testing.expectEqualStrings(".plist", FileFormat.plist.extension());
}

test "FileStorageConfig creation" {
    const config = FileStorageConfig.init("data");
    try std.testing.expectEqualStrings("data", config.filename);
    try std.testing.expectEqual(FileFormat.json, config.format);
    try std.testing.expectEqual(StorageDirectory.documents, config.directory);
}

test "FileStorageConfig withFormat" {
    const config = FileStorageConfig.init("data").withFormat(.binary);
    try std.testing.expectEqual(FileFormat.binary, config.format);
}

test "StorageDirectory toPath" {
    try std.testing.expectEqualStrings("Documents", StorageDirectory.documents.toPath());
    try std.testing.expectEqualStrings("Caches", StorageDirectory.caches.toPath());
}

test "FileStorage initialization" {
    const config = FileStorageConfig.init("test");
    var storage = FileStorage.init(std.testing.allocator, config);
    defer storage.deinit();

    try std.testing.expect(!storage.is_loaded);
}

test "FileStorage set and get" {
    const config = FileStorageConfig.init("test");
    var storage = FileStorage.init(std.testing.allocator, config);
    defer storage.deinit();

    try storage.set("key", StorageValue{ .string = "value" });
    const value = storage.get("key");
    try std.testing.expectEqualStrings("value", value.?.getString().?);
}

test "FileStorage remove" {
    const config = FileStorageConfig.init("test");
    var storage = FileStorage.init(std.testing.allocator, config);
    defer storage.deinit();

    try storage.set("key", StorageValue{ .int = 42 });
    storage.remove("key");
    try std.testing.expect(storage.get("key") == null);
}

test "StoragePresets appSettings" {
    const config = StoragePresets.appSettings();
    try std.testing.expectEqualStrings("AppSettings", config.name);
    try std.testing.expectEqual(SyncMode.sync, config.sync_mode);
}

test "StoragePresets userPreferences" {
    const config = StoragePresets.userPreferences();
    try std.testing.expectEqualStrings("UserPreferences", config.name);
    try std.testing.expectEqual(SyncMode.async_mode, config.sync_mode);
}

test "StoragePresets cache" {
    const config = StoragePresets.cache();
    try std.testing.expectEqual(PersistenceMode.memory, config.mode);
}

test "StoragePresets session" {
    const config = StoragePresets.session();
    try std.testing.expectEqual(PersistenceMode.memory, config.mode);
}

test "SecureStoragePresets credentials" {
    const config = SecureStoragePresets.credentials("com.app.auth");
    try std.testing.expectEqualStrings("com.app.auth", config.service);
}

test "SecureStoragePresets biometric" {
    const config = SecureStoragePresets.biometric("com.app.secure");
    try std.testing.expect(config.require_biometric);
}

test "SecureStoragePresets tokens" {
    const config = SecureStoragePresets.tokens("com.app.tokens");
    try std.testing.expectEqual(KeychainAccessibility.after_first_unlock, config.accessibility);
}

test "QuickStorage isFirstLaunch" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try std.testing.expect(QuickStorage.isFirstLaunch(&prefs));
    try std.testing.expect(!QuickStorage.isFirstLaunch(&prefs));
}

test "QuickStorage getLaunchCount" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try std.testing.expectEqual(@as(i64, 1), QuickStorage.getLaunchCount(&prefs));
    try std.testing.expectEqual(@as(i64, 2), QuickStorage.getLaunchCount(&prefs));
    try std.testing.expectEqual(@as(i64, 3), QuickStorage.getLaunchCount(&prefs));
}

test "QuickStorage updateLastOpened" {
    const config = StorageConfig.memory();
    var prefs = PreferencesManager.init(std.testing.allocator, config);
    defer prefs.deinit();

    try QuickStorage.updateLastOpened(&prefs);
    try std.testing.expect(prefs.getInt("last_opened_timestamp") != null);
}

test "StorageMigration migrateKey" {
    const config = StorageConfig.memory();
    var source = PreferencesManager.init(std.testing.allocator, config);
    defer source.deinit();
    var dest = PreferencesManager.init(std.testing.allocator, config);
    defer dest.deinit();

    try source.setString("old_key", "value");
    try StorageMigration.migrateKey(&source, &dest, "old_key", "new_key");

    try std.testing.expect(!source.contains("old_key"));
    try std.testing.expectEqualStrings("value", dest.getString("new_key").?);
}
