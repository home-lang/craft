const std = @import("std");
const wasm = @import("wasm.zig");

/// Plugin Marketplace System
/// Allows discovering, installing, and managing plugins from remote registries

pub const PluginInfo = struct {
    id: []const u8,
    name: []const u8,
    version: []const u8,
    author: []const u8,
    description: []const u8,
    repository: []const u8,
    homepage: ?[]const u8,
    license: []const u8,
    tags: []const []const u8,
    downloads: u64,
    rating: f32,
    verified: bool,
    created_at: i64,
    updated_at: i64,
    dependencies: []const Dependency,
    size: u64,
    checksum: []const u8,

    pub const Dependency = struct {
        name: []const u8,
        version: []const u8,
        optional: bool = false,
    };
};

pub const PluginCategory = enum {
    ui,
    data,
    media,
    networking,
    development,
    productivity,
    security,
    utilities,
    games,
    other,
};

pub const SearchFilter = struct {
    query: ?[]const u8 = null,
    category: ?PluginCategory = null,
    verified_only: bool = false,
    min_rating: ?f32 = null,
    tags: []const []const u8 = &[_][]const u8{},
    sort_by: SortBy = .downloads,
    order: Order = .descending,

    pub const SortBy = enum {
        downloads,
        rating,
        created_at,
        updated_at,
        name,
    };

    pub const Order = enum {
        ascending,
        descending,
    };
};

pub const InstallOptions = struct {
    version: ?[]const u8 = null, // null = latest
    force: bool = false,
    skip_dependencies: bool = false,
    registry_url: ?[]const u8 = null,
};

pub const Registry = struct {
    url: []const u8,
    name: []const u8,
    verified: bool,
    plugins_cache: std.StringHashMap(PluginInfo),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, url: []const u8, verified: bool) Registry {
        return Registry{
            .url = url,
            .name = name,
            .verified = verified,
            .plugins_cache = std.StringHashMap(PluginInfo).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Registry) void {
        self.plugins_cache.deinit();
    }

    pub fn fetchPlugins(self: *Registry) ![]PluginInfo {
        _ = self;
        // Would make HTTP request to registry API
        // For now, return empty list
        return &[_]PluginInfo{};
    }

    pub fn getPlugin(self: *Registry, id: []const u8) !?PluginInfo {
        if (self.plugins_cache.get(id)) |info| {
            return info;
        }

        // Fetch from remote
        _ = try self.fetchPlugins();
        return self.plugins_cache.get(id);
    }
};

pub const Marketplace = struct {
    registries: std.ArrayList(Registry),
    installed_plugins: std.StringHashMap(InstalledPlugin),
    cache_dir: []const u8,
    download_dir: []const u8,
    allocator: std.mem.Allocator,

    pub const InstalledPlugin = struct {
        info: PluginInfo,
        install_path: []const u8,
        installed_at: i64,
        enabled: bool,
    };

    pub fn init(allocator: std.mem.Allocator, cache_dir: []const u8, download_dir: []const u8) Marketplace {
        return Marketplace{
            .registries = std.ArrayList(Registry).init(allocator),
            .installed_plugins = std.StringHashMap(InstalledPlugin).init(allocator),
            .cache_dir = cache_dir,
            .download_dir = download_dir,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Marketplace) void {
        for (self.registries.items) |*registry| {
            registry.deinit();
        }
        self.registries.deinit();
        self.installed_plugins.deinit();
    }

    pub fn addRegistry(self: *Marketplace, registry: Registry) !void {
        try self.registries.append(registry);
    }

    pub fn removeRegistry(self: *Marketplace, name: []const u8) void {
        var i: usize = 0;
        while (i < self.registries.items.len) {
            if (std.mem.eql(u8, self.registries.items[i].name, name)) {
                var removed = self.registries.swapRemove(i);
                removed.deinit();
                return;
            }
            i += 1;
        }
    }

    pub fn search(self: *Marketplace, filter: SearchFilter) ![]PluginInfo {
        var results = std.ArrayList(PluginInfo).init(self.allocator);
        defer results.deinit();

        // Search all registries
        for (self.registries.items) |*registry| {
            const plugins = try registry.fetchPlugins();

            for (plugins) |plugin| {
                // Apply filters
                if (filter.query) |query| {
                    if (!contains(plugin.name, query) and !contains(plugin.description, query)) {
                        continue;
                    }
                }

                if (filter.verified_only and !plugin.verified) {
                    continue;
                }

                if (filter.min_rating) |min_rating| {
                    if (plugin.rating < min_rating) {
                        continue;
                    }
                }

                if (filter.tags.len > 0) {
                    var has_tag = false;
                    for (filter.tags) |tag| {
                        for (plugin.tags) |plugin_tag| {
                            if (std.mem.eql(u8, tag, plugin_tag)) {
                                has_tag = true;
                                break;
                            }
                        }
                    }
                    if (!has_tag) continue;
                }

                try results.append(plugin);
            }
        }

        // Sort results
        const items = try results.toOwnedSlice();
        sortPlugins(items, filter.sort_by, filter.order);
        return items;
    }

    pub fn install(self: *Marketplace, plugin_id: []const u8, options: InstallOptions) !void {
        // Check if already installed
        if (self.installed_plugins.contains(plugin_id) and !options.force) {
            return error.PluginAlreadyInstalled;
        }

        // Find plugin in registries
        var plugin_info: ?PluginInfo = null;
        for (self.registries.items) |*registry| {
            if (try registry.getPlugin(plugin_id)) |info| {
                plugin_info = info;
                break;
            }
        }

        if (plugin_info == null) {
            return error.PluginNotFound;
        }

        const info = plugin_info.?;

        // Install dependencies first
        if (!options.skip_dependencies) {
            for (info.dependencies) |dep| {
                if (!dep.optional) {
                    try self.install(dep.name, .{
                        .version = dep.version,
                        .registry_url = options.registry_url,
                    });
                }
            }
        }

        // Download plugin
        const download_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}-{s}.wasm",
            .{ self.download_dir, info.id, info.version },
        );
        defer self.allocator.free(download_path);

        // Would download from repository URL
        // For now, simulate successful download

        // Verify checksum
        // Would verify downloaded file matches checksum

        // Install plugin
        const install_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}",
            .{ self.cache_dir, info.id },
        );

        const installed = InstalledPlugin{
            .info = info,
            .install_path = install_path,
            .installed_at = std.time.milliTimestamp(),
            .enabled = true,
        };

        try self.installed_plugins.put(plugin_id, installed);
    }

    pub fn uninstall(self: *Marketplace, plugin_id: []const u8) !void {
        if (self.installed_plugins.fetchRemove(plugin_id)) |kv| {
            // Delete plugin files
            std.fs.cwd().deleteTree(kv.value.install_path) catch {};
            self.allocator.free(kv.value.install_path);
        } else {
            return error.PluginNotInstalled;
        }
    }

    pub fn update(self: *Marketplace, plugin_id: []const u8) !void {
        const installed = self.installed_plugins.get(plugin_id) orelse return error.PluginNotInstalled;

        // Check for updates
        var latest_version: ?[]const u8 = null;
        for (self.registries.items) |*registry| {
            if (try registry.getPlugin(plugin_id)) |info| {
                if (compareVersions(info.version, installed.info.version) > 0) {
                    latest_version = info.version;
                }
            }
        }

        if (latest_version) |version| {
            // Uninstall old version
            try self.uninstall(plugin_id);

            // Install new version
            try self.install(plugin_id, .{ .version = version });
        }
    }

    pub fn updateAll(self: *Marketplace) !void {
        var iter = self.installed_plugins.keyIterator();
        while (iter.next()) |key| {
            try self.update(key.*);
        }
    }

    pub fn getInstalled(self: *Marketplace, plugin_id: []const u8) ?InstalledPlugin {
        return self.installed_plugins.get(plugin_id);
    }

    pub fn listInstalled(self: *Marketplace) []InstalledPlugin {
        var list = std.ArrayList(InstalledPlugin).init(self.allocator);
        defer list.deinit();

        var iter = self.installed_plugins.valueIterator();
        while (iter.next()) |plugin| {
            list.append(plugin.*) catch continue;
        }

        return list.toOwnedSlice() catch &[_]InstalledPlugin{};
    }

    pub fn enable(self: *Marketplace, plugin_id: []const u8) !void {
        if (self.installed_plugins.getPtr(plugin_id)) |plugin| {
            plugin.enabled = true;
        } else {
            return error.PluginNotInstalled;
        }
    }

    pub fn disable(self: *Marketplace, plugin_id: []const u8) !void {
        if (self.installed_plugins.getPtr(plugin_id)) |plugin| {
            plugin.enabled = false;
        } else {
            return error.PluginNotInstalled;
        }
    }

    pub fn checkForUpdates(self: *Marketplace) ![]PluginUpdate {
        var updates = std.ArrayList(PluginUpdate).init(self.allocator);
        defer updates.deinit();

        var iter = self.installed_plugins.iterator();
        while (iter.next()) |entry| {
            for (self.registries.items) |*registry| {
                if (try registry.getPlugin(entry.key_ptr.*)) |info| {
                    if (compareVersions(info.version, entry.value_ptr.info.version) > 0) {
                        try updates.append(.{
                            .plugin_id = entry.key_ptr.*,
                            .current_version = entry.value_ptr.info.version,
                            .latest_version = info.version,
                            .info = info,
                        });
                    }
                }
            }
        }

        return updates.toOwnedSlice();
    }

    fn contains(haystack: []const u8, needle: []const u8) bool {
        if (needle.len > haystack.len) return false;

        var i: usize = 0;
        while (i <= haystack.len - needle.len) : (i += 1) {
            if (std.mem.eql(u8, haystack[i .. i + needle.len], needle)) {
                return true;
            }
        }
        return false;
    }

    fn sortPlugins(items: []PluginInfo, sort_by: SearchFilter.SortBy, order: SearchFilter.Order) void {
        _ = sort_by;
        _ = order;
        // Would implement sorting based on sort_by and order
        _ = items;
    }

    fn compareVersions(v1: []const u8, v2: []const u8) i32 {
        // Simplified version comparison
        // Would implement proper semver comparison
        if (std.mem.eql(u8, v1, v2)) return 0;
        return if (v1.len > v2.len) 1 else -1;
    }
};

pub const PluginUpdate = struct {
    plugin_id: []const u8,
    current_version: []const u8,
    latest_version: []const u8,
    info: PluginInfo,
};

/// Official Zyte Plugin Registry
pub const OfficialRegistry = struct {
    pub const URL = "https://plugins.zyte.dev";
    pub const NAME = "official";

    pub fn create(allocator: std.mem.Allocator) Registry {
        return Registry.init(allocator, NAME, URL, true);
    }
};

/// Community Plugin Registry
pub const CommunityRegistry = struct {
    pub const URL = "https://community.zyte.dev";
    pub const NAME = "community";

    pub fn create(allocator: std.mem.Allocator) Registry {
        return Registry.init(allocator, NAME, URL, false);
    }
};

/// Plugin Rating System
pub const Rating = struct {
    user_id: []const u8,
    plugin_id: []const u8,
    rating: u8, // 1-5
    review: ?[]const u8,
    created_at: i64,

    pub fn init(user_id: []const u8, plugin_id: []const u8, rating: u8, review: ?[]const u8) !Rating {
        if (rating < 1 or rating > 5) {
            return error.InvalidRating;
        }

        return Rating{
            .user_id = user_id,
            .plugin_id = plugin_id,
            .rating = rating,
            .review = review,
            .created_at = std.time.milliTimestamp(),
        };
    }
};

/// Plugin Statistics
pub const PluginStats = struct {
    plugin_id: []const u8,
    total_downloads: u64,
    weekly_downloads: u64,
    monthly_downloads: u64,
    average_rating: f32,
    total_ratings: u64,
    last_updated: i64,

    pub fn calculateAverageRating(ratings: []const Rating) f32 {
        if (ratings.len == 0) return 0.0;

        var sum: u64 = 0;
        for (ratings) |rating| {
            sum += rating.rating;
        }

        return @as(f32, @floatFromInt(sum)) / @as(f32, @floatFromInt(ratings.len));
    }
};
