const std = @import("std");
const testing = std.testing;
const marketplace = @import("../src/marketplace.zig");

// PluginCategory tests
test "PluginCategory - all variants" {
    try testing.expectEqual(marketplace.PluginCategory.ui, .ui);
    try testing.expectEqual(marketplace.PluginCategory.data, .data);
    try testing.expectEqual(marketplace.PluginCategory.media, .media);
    try testing.expectEqual(marketplace.PluginCategory.networking, .networking);
    try testing.expectEqual(marketplace.PluginCategory.development, .development);
    try testing.expectEqual(marketplace.PluginCategory.productivity, .productivity);
    try testing.expectEqual(marketplace.PluginCategory.security, .security);
    try testing.expectEqual(marketplace.PluginCategory.utilities, .utilities);
    try testing.expectEqual(marketplace.PluginCategory.games, .games);
    try testing.expectEqual(marketplace.PluginCategory.other, .other);
}

// PluginInfo tests
test "PluginInfo - basic creation" {
    const info = marketplace.PluginInfo{
        .id = "test-plugin",
        .name = "Test Plugin",
        .version = "1.0.0",
        .author = "Test Author",
        .description = "A test plugin",
        .repository = "https://github.com/test/plugin",
        .homepage = null,
        .license = "MIT",
        .tags = &[_][]const u8{ "test", "demo" },
        .downloads = 100,
        .rating = 4.5,
        .verified = true,
        .created_at = 1234567890,
        .updated_at = 1234567900,
        .dependencies = &[_]marketplace.PluginInfo.Dependency{},
        .size = 1024,
        .checksum = "abc123",
    };

    try testing.expectEqualStrings("test-plugin", info.id);
    try testing.expectEqualStrings("Test Plugin", info.name);
    try testing.expectEqualStrings("1.0.0", info.version);
    try testing.expectEqualStrings("Test Author", info.author);
    try testing.expectEqual(@as(u64, 100), info.downloads);
    try testing.expectEqual(@as(f32, 4.5), info.rating);
    try testing.expect(info.verified);
}

test "PluginInfo - with homepage" {
    const info = marketplace.PluginInfo{
        .id = "plugin",
        .name = "Plugin",
        .version = "1.0.0",
        .author = "Author",
        .description = "Description",
        .repository = "https://github.com/test/plugin",
        .homepage = "https://example.com",
        .license = "MIT",
        .tags = &[_][]const u8{},
        .downloads = 0,
        .rating = 0.0,
        .verified = false,
        .created_at = 0,
        .updated_at = 0,
        .dependencies = &[_]marketplace.PluginInfo.Dependency{},
        .size = 0,
        .checksum = "",
    };

    try testing.expect(info.homepage != null);
    try testing.expectEqualStrings("https://example.com", info.homepage.?);
}

test "PluginInfo - with dependencies" {
    const deps = [_]marketplace.PluginInfo.Dependency{
        .{ .name = "dep1", .version = "1.0.0", .optional = false },
        .{ .name = "dep2", .version = "2.0.0", .optional = true },
    };

    const info = marketplace.PluginInfo{
        .id = "plugin",
        .name = "Plugin",
        .version = "1.0.0",
        .author = "Author",
        .description = "Description",
        .repository = "https://github.com/test/plugin",
        .homepage = null,
        .license = "MIT",
        .tags = &[_][]const u8{},
        .downloads = 0,
        .rating = 0.0,
        .verified = false,
        .created_at = 0,
        .updated_at = 0,
        .dependencies = &deps,
        .size = 0,
        .checksum = "",
    };

    try testing.expectEqual(@as(usize, 2), info.dependencies.len);
    try testing.expectEqualStrings("dep1", info.dependencies[0].name);
    try testing.expect(!info.dependencies[0].optional);
    try testing.expect(info.dependencies[1].optional);
}

// Dependency tests
test "Dependency - required dependency" {
    const dep = marketplace.PluginInfo.Dependency{
        .name = "required-dep",
        .version = "1.0.0",
        .optional = false,
    };

    try testing.expectEqualStrings("required-dep", dep.name);
    try testing.expectEqualStrings("1.0.0", dep.version);
    try testing.expect(!dep.optional);
}

test "Dependency - optional dependency" {
    const dep = marketplace.PluginInfo.Dependency{
        .name = "optional-dep",
        .version = "2.0.0",
        .optional = true,
    };

    try testing.expectEqualStrings("optional-dep", dep.name);
    try testing.expect(dep.optional);
}

test "Dependency - default optional value" {
    const dep = marketplace.PluginInfo.Dependency{
        .name = "dep",
        .version = "1.0.0",
    };

    try testing.expect(!dep.optional); // Default is false
}

// SearchFilter tests
test "SearchFilter - default values" {
    const filter = marketplace.SearchFilter{};

    try testing.expectEqual(@as(?[]const u8, null), filter.query);
    try testing.expectEqual(@as(?marketplace.PluginCategory, null), filter.category);
    try testing.expect(!filter.verified_only);
    try testing.expectEqual(@as(?f32, null), filter.min_rating);
    try testing.expectEqual(@as(usize, 0), filter.tags.len);
    try testing.expectEqual(marketplace.SearchFilter.SortBy.downloads, filter.sort_by);
    try testing.expectEqual(marketplace.SearchFilter.Order.descending, filter.order);
}

test "SearchFilter - with query" {
    const filter = marketplace.SearchFilter{
        .query = "test",
    };

    try testing.expect(filter.query != null);
    try testing.expectEqualStrings("test", filter.query.?);
}

test "SearchFilter - with category" {
    const filter = marketplace.SearchFilter{
        .category = .ui,
    };

    try testing.expect(filter.category != null);
    try testing.expectEqual(marketplace.PluginCategory.ui, filter.category.?);
}

test "SearchFilter - verified only" {
    const filter = marketplace.SearchFilter{
        .verified_only = true,
    };

    try testing.expect(filter.verified_only);
}

test "SearchFilter - with min rating" {
    const filter = marketplace.SearchFilter{
        .min_rating = 4.0,
    };

    try testing.expect(filter.min_rating != null);
    try testing.expectEqual(@as(f32, 4.0), filter.min_rating.?);
}

test "SearchFilter - with tags" {
    const tags = [_][]const u8{ "tag1", "tag2" };
    const filter = marketplace.SearchFilter{
        .tags = &tags,
    };

    try testing.expectEqual(@as(usize, 2), filter.tags.len);
}

test "SearchFilter - SortBy variants" {
    try testing.expectEqual(marketplace.SearchFilter.SortBy.downloads, .downloads);
    try testing.expectEqual(marketplace.SearchFilter.SortBy.rating, .rating);
    try testing.expectEqual(marketplace.SearchFilter.SortBy.created_at, .created_at);
    try testing.expectEqual(marketplace.SearchFilter.SortBy.updated_at, .updated_at);
    try testing.expectEqual(marketplace.SearchFilter.SortBy.name, .name);
}

test "SearchFilter - Order variants" {
    try testing.expectEqual(marketplace.SearchFilter.Order.ascending, .ascending);
    try testing.expectEqual(marketplace.SearchFilter.Order.descending, .descending);
}

// InstallOptions tests
test "InstallOptions - default values" {
    const options = marketplace.InstallOptions{};

    try testing.expectEqual(@as(?[]const u8, null), options.version);
    try testing.expect(!options.force);
    try testing.expect(!options.skip_dependencies);
    try testing.expectEqual(@as(?[]const u8, null), options.registry_url);
}

test "InstallOptions - with version" {
    const options = marketplace.InstallOptions{
        .version = "2.0.0",
    };

    try testing.expect(options.version != null);
    try testing.expectEqualStrings("2.0.0", options.version.?);
}

test "InstallOptions - force install" {
    const options = marketplace.InstallOptions{
        .force = true,
    };

    try testing.expect(options.force);
}

test "InstallOptions - skip dependencies" {
    const options = marketplace.InstallOptions{
        .skip_dependencies = true,
    };

    try testing.expect(options.skip_dependencies);
}

test "InstallOptions - with registry URL" {
    const options = marketplace.InstallOptions{
        .registry_url = "https://custom.registry.com",
    };

    try testing.expect(options.registry_url != null);
    try testing.expectEqualStrings("https://custom.registry.com", options.registry_url.?);
}

// Registry tests
test "Registry - initialization" {
    const allocator = testing.allocator;
    var registry = marketplace.Registry.init(allocator, "test-registry", "https://test.com", true);
    defer registry.deinit();

    try testing.expectEqualStrings("test-registry", registry.name);
    try testing.expectEqualStrings("https://test.com", registry.url);
    try testing.expect(registry.verified);
}

test "Registry - unverified registry" {
    const allocator = testing.allocator;
    var registry = marketplace.Registry.init(allocator, "unverified", "https://example.com", false);
    defer registry.deinit();

    try testing.expect(!registry.verified);
}

test "Registry - fetch plugins returns empty" {
    const allocator = testing.allocator;
    var registry = marketplace.Registry.init(allocator, "test", "https://test.com", true);
    defer registry.deinit();

    const plugins = try registry.fetchPlugins();
    try testing.expectEqual(@as(usize, 0), plugins.len);
}

test "Registry - get plugin not in cache" {
    const allocator = testing.allocator;
    var registry = marketplace.Registry.init(allocator, "test", "https://test.com", true);
    defer registry.deinit();

    const result = try registry.getPlugin("non-existent");
    try testing.expectEqual(@as(?marketplace.PluginInfo, null), result);
}

// Marketplace tests
test "Marketplace - initialization" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    try testing.expectEqualStrings("/cache", mp.cache_dir);
    try testing.expectEqualStrings("/downloads", mp.download_dir);
    try testing.expectEqual(@as(usize, 0), mp.registries.items.len);
}

test "Marketplace - add registry" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    const registry = marketplace.Registry.init(allocator, "test", "https://test.com", true);
    try mp.addRegistry(registry);

    try testing.expectEqual(@as(usize, 1), mp.registries.items.len);
}

test "Marketplace - add multiple registries" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    const registry1 = marketplace.Registry.init(allocator, "registry1", "https://test1.com", true);
    const registry2 = marketplace.Registry.init(allocator, "registry2", "https://test2.com", false);

    try mp.addRegistry(registry1);
    try mp.addRegistry(registry2);

    try testing.expectEqual(@as(usize, 2), mp.registries.items.len);
}

test "Marketplace - remove registry" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    const registry1 = marketplace.Registry.init(allocator, "registry1", "https://test1.com", true);
    const registry2 = marketplace.Registry.init(allocator, "registry2", "https://test2.com", false);

    try mp.addRegistry(registry1);
    try mp.addRegistry(registry2);

    mp.removeRegistry("registry1");

    try testing.expectEqual(@as(usize, 1), mp.registries.items.len);
    try testing.expectEqualStrings("registry2", mp.registries.items[0].name);
}

test "Marketplace - remove non-existent registry" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    const registry = marketplace.Registry.init(allocator, "test", "https://test.com", true);
    try mp.addRegistry(registry);

    mp.removeRegistry("non-existent");

    try testing.expectEqual(@as(usize, 1), mp.registries.items.len);
}

test "Marketplace - search returns empty" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    const filter = marketplace.SearchFilter{};
    const results = try mp.search(filter);
    defer allocator.free(results);

    try testing.expectEqual(@as(usize, 0), results.len);
}

test "Marketplace - install non-existent plugin" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    const result = mp.install("non-existent", .{});
    try testing.expectError(error.PluginNotFound, result);
}

test "Marketplace - getInstalled returns null for non-existent" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    const result = mp.getInstalled("non-existent");
    try testing.expectEqual(@as(?marketplace.Marketplace.InstalledPlugin, null), result);
}

test "Marketplace - listInstalled returns empty" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    const list = mp.listInstalled();
    defer allocator.free(list);

    try testing.expectEqual(@as(usize, 0), list.len);
}

test "Marketplace - enable non-existent plugin" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    const result = mp.enable("non-existent");
    try testing.expectError(error.PluginNotInstalled, result);
}

test "Marketplace - disable non-existent plugin" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    const result = mp.disable("non-existent");
    try testing.expectError(error.PluginNotInstalled, result);
}

test "Marketplace - uninstall non-existent plugin" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    const result = mp.uninstall("non-existent");
    try testing.expectError(error.PluginNotInstalled, result);
}

test "Marketplace - update non-existent plugin" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    const result = mp.update("non-existent");
    try testing.expectError(error.PluginNotInstalled, result);
}

test "Marketplace - updateAll with no plugins" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    try mp.updateAll();
}

test "Marketplace - checkForUpdates returns empty" {
    const allocator = testing.allocator;
    var mp = marketplace.Marketplace.init(allocator, "/cache", "/downloads");
    defer mp.deinit();

    const updates = try mp.checkForUpdates();
    defer allocator.free(updates);

    try testing.expectEqual(@as(usize, 0), updates.len);
}

// InstalledPlugin tests
test "InstalledPlugin - creation" {
    const info = marketplace.PluginInfo{
        .id = "plugin",
        .name = "Plugin",
        .version = "1.0.0",
        .author = "Author",
        .description = "Description",
        .repository = "https://github.com/test/plugin",
        .homepage = null,
        .license = "MIT",
        .tags = &[_][]const u8{},
        .downloads = 0,
        .rating = 0.0,
        .verified = false,
        .created_at = 0,
        .updated_at = 0,
        .dependencies = &[_]marketplace.PluginInfo.Dependency{},
        .size = 0,
        .checksum = "",
    };

    const installed = marketplace.Marketplace.InstalledPlugin{
        .info = info,
        .install_path = "/path/to/plugin",
        .installed_at = 1234567890,
        .enabled = true,
    };

    try testing.expectEqualStrings("plugin", installed.info.id);
    try testing.expectEqualStrings("/path/to/plugin", installed.install_path);
    try testing.expectEqual(@as(i64, 1234567890), installed.installed_at);
    try testing.expect(installed.enabled);
}

test "InstalledPlugin - disabled" {
    const info = marketplace.PluginInfo{
        .id = "plugin",
        .name = "Plugin",
        .version = "1.0.0",
        .author = "Author",
        .description = "Description",
        .repository = "https://github.com/test/plugin",
        .homepage = null,
        .license = "MIT",
        .tags = &[_][]const u8{},
        .downloads = 0,
        .rating = 0.0,
        .verified = false,
        .created_at = 0,
        .updated_at = 0,
        .dependencies = &[_]marketplace.PluginInfo.Dependency{},
        .size = 0,
        .checksum = "",
    };

    const installed = marketplace.Marketplace.InstalledPlugin{
        .info = info,
        .install_path = "/path/to/plugin",
        .installed_at = 1234567890,
        .enabled = false,
    };

    try testing.expect(!installed.enabled);
}

// PluginUpdate tests
test "PluginUpdate - creation" {
    const info = marketplace.PluginInfo{
        .id = "plugin",
        .name = "Plugin",
        .version = "2.0.0",
        .author = "Author",
        .description = "Description",
        .repository = "https://github.com/test/plugin",
        .homepage = null,
        .license = "MIT",
        .tags = &[_][]const u8{},
        .downloads = 0,
        .rating = 0.0,
        .verified = false,
        .created_at = 0,
        .updated_at = 0,
        .dependencies = &[_]marketplace.PluginInfo.Dependency{},
        .size = 0,
        .checksum = "",
    };

    const update = marketplace.PluginUpdate{
        .plugin_id = "plugin",
        .current_version = "1.0.0",
        .latest_version = "2.0.0",
        .info = info,
    };

    try testing.expectEqualStrings("plugin", update.plugin_id);
    try testing.expectEqualStrings("1.0.0", update.current_version);
    try testing.expectEqualStrings("2.0.0", update.latest_version);
    try testing.expectEqualStrings("2.0.0", update.info.version);
}

// OfficialRegistry tests
test "OfficialRegistry - constants" {
    try testing.expectEqualStrings("https://plugins.zyte.dev", marketplace.OfficialRegistry.URL);
    try testing.expectEqualStrings("official", marketplace.OfficialRegistry.NAME);
}

test "OfficialRegistry - create" {
    const allocator = testing.allocator;
    var registry = marketplace.OfficialRegistry.create(allocator);
    defer registry.deinit();

    try testing.expectEqualStrings("official", registry.name);
    try testing.expectEqualStrings("https://plugins.zyte.dev", registry.url);
    try testing.expect(registry.verified);
}

// CommunityRegistry tests
test "CommunityRegistry - constants" {
    try testing.expectEqualStrings("https://community.zyte.dev", marketplace.CommunityRegistry.URL);
    try testing.expectEqualStrings("community", marketplace.CommunityRegistry.NAME);
}

test "CommunityRegistry - create" {
    const allocator = testing.allocator;
    var registry = marketplace.CommunityRegistry.create(allocator);
    defer registry.deinit();

    try testing.expectEqualStrings("community", registry.name);
    try testing.expectEqualStrings("https://community.zyte.dev", registry.url);
    try testing.expect(!registry.verified);
}

// Rating tests
test "Rating - valid rating creation" {
    const rating = try marketplace.Rating.init("user123", "plugin456", 5, "Great plugin!");

    try testing.expectEqualStrings("user123", rating.user_id);
    try testing.expectEqualStrings("plugin456", rating.plugin_id);
    try testing.expectEqual(@as(u8, 5), rating.rating);
    try testing.expect(rating.review != null);
    try testing.expectEqualStrings("Great plugin!", rating.review.?);
    try testing.expect(rating.created_at > 0);
}

test "Rating - minimum rating" {
    const rating = try marketplace.Rating.init("user", "plugin", 1, null);
    try testing.expectEqual(@as(u8, 1), rating.rating);
}

test "Rating - maximum rating" {
    const rating = try marketplace.Rating.init("user", "plugin", 5, null);
    try testing.expectEqual(@as(u8, 5), rating.rating);
}

test "Rating - invalid rating too low" {
    const result = marketplace.Rating.init("user", "plugin", 0, null);
    try testing.expectError(error.InvalidRating, result);
}

test "Rating - invalid rating too high" {
    const result = marketplace.Rating.init("user", "plugin", 6, null);
    try testing.expectError(error.InvalidRating, result);
}

test "Rating - without review" {
    const rating = try marketplace.Rating.init("user", "plugin", 4, null);
    try testing.expectEqual(@as(?[]const u8, null), rating.review);
}

test "Rating - with review" {
    const rating = try marketplace.Rating.init("user", "plugin", 3, "Good but needs work");
    try testing.expect(rating.review != null);
    try testing.expectEqualStrings("Good but needs work", rating.review.?);
}

// PluginStats tests
test "PluginStats - creation" {
    const stats = marketplace.PluginStats{
        .plugin_id = "plugin",
        .total_downloads = 1000,
        .weekly_downloads = 50,
        .monthly_downloads = 200,
        .average_rating = 4.5,
        .total_ratings = 100,
        .last_updated = 1234567890,
    };

    try testing.expectEqualStrings("plugin", stats.plugin_id);
    try testing.expectEqual(@as(u64, 1000), stats.total_downloads);
    try testing.expectEqual(@as(u64, 50), stats.weekly_downloads);
    try testing.expectEqual(@as(u64, 200), stats.monthly_downloads);
    try testing.expectEqual(@as(f32, 4.5), stats.average_rating);
    try testing.expectEqual(@as(u64, 100), stats.total_ratings);
}

test "PluginStats - calculateAverageRating with no ratings" {
    const ratings = [_]marketplace.Rating{};
    const avg = marketplace.PluginStats.calculateAverageRating(&ratings);
    try testing.expectEqual(@as(f32, 0.0), avg);
}

test "PluginStats - calculateAverageRating with single rating" {
    const ratings = [_]marketplace.Rating{
        try marketplace.Rating.init("user", "plugin", 5, null),
    };
    const avg = marketplace.PluginStats.calculateAverageRating(&ratings);
    try testing.expectEqual(@as(f32, 5.0), avg);
}

test "PluginStats - calculateAverageRating with multiple ratings" {
    const ratings = [_]marketplace.Rating{
        try marketplace.Rating.init("user1", "plugin", 5, null),
        try marketplace.Rating.init("user2", "plugin", 4, null),
        try marketplace.Rating.init("user3", "plugin", 3, null),
    };
    const avg = marketplace.PluginStats.calculateAverageRating(&ratings);
    try testing.expectEqual(@as(f32, 4.0), avg);
}

test "PluginStats - calculateAverageRating rounds correctly" {
    const ratings = [_]marketplace.Rating{
        try marketplace.Rating.init("user1", "plugin", 5, null),
        try marketplace.Rating.init("user2", "plugin", 4, null),
    };
    const avg = marketplace.PluginStats.calculateAverageRating(&ratings);
    try testing.expectEqual(@as(f32, 4.5), avg);
}
