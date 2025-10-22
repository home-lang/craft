const std = @import("std");

/// Package configuration structure
pub const Package = struct {
    name: []const u8,
    version: []const u8,
    authors: ?[]const []const u8 = null,
    description: ?[]const u8 = null,
    license: ?[]const u8 = null,
    dependencies: ?std.StringHashMap(Dependency) = null,
    workspaces: ?Workspaces = null,
    scripts: ?std.StringHashMap([]const u8) = null,

    pub const Dependency = struct {
        path: ?[]const u8 = null,
        git: ?[]const u8 = null,
        version: ?[]const u8 = null,
        registry: ?[]const u8 = null,
    };

    pub const Workspaces = struct {
        packages: []const []const u8,
    };

    pub fn deinit(self: *Package, allocator: std.mem.Allocator) void {
        if (self.dependencies) |*deps| {
            deps.deinit();
        }
        if (self.scripts) |*s| {
            s.deinit();
        }
    }
};

/// Loads a package configuration from a file
/// Supports: zyte.toml, zyte.json, package.jsonc, package.json
pub fn loadPackage(allocator: std.mem.Allocator, path: []const u8) !Package {
    const file_ext = std.fs.path.extension(path);

    if (std.mem.eql(u8, file_ext, ".toml")) {
        return loadPackageFromToml(allocator, path);
    } else if (std.mem.eql(u8, file_ext, ".json") or std.mem.eql(u8, file_ext, ".jsonc")) {
        return loadPackageFromJson(allocator, path);
    } else {
        return error.UnsupportedFileFormat;
    }
}

/// Finds and loads a package configuration from the current directory
/// Searches for: zyte.toml, zyte.json, package.jsonc, package.json (in that order)
pub fn findAndLoadPackage(allocator: std.mem.Allocator, dir_path: []const u8) !Package {
    const search_files = [_][]const u8{
        "zyte.toml",
        "zyte.json",
        "package.jsonc",
        "package.json",
    };

    for (search_files) |filename| {
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, filename });
        defer allocator.free(full_path);

        if (loadPackage(allocator, full_path)) |pkg| {
            return pkg;
        } else |_| {
            continue;
        }
    }

    return error.PackageConfigNotFound;
}

fn loadPackageFromToml(allocator: std.mem.Allocator, path: []const u8) !Package {
    // For now, return a basic implementation
    // Full TOML parsing would require a TOML library
    _ = allocator;
    _ = path;
    return error.NotImplementedYet;
}

fn loadPackageFromJson(allocator: std.mem.Allocator, path: []const u8) !Package {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10MB max
    defer allocator.free(content);

    // Strip comments if it's a JSONC file
    const file_ext = std.fs.path.extension(path);
    const json_content = if (std.mem.eql(u8, file_ext, ".jsonc"))
        try stripJsonComments(allocator, content)
    else
        content;
    defer if (json_content.ptr != content.ptr) allocator.free(json_content);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    return try parsePackageFromJson(allocator, parsed.value);
}

fn stripJsonComments(allocator: std.mem.Allocator, content: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    var i: usize = 0;
    var in_string = false;
    var escape_next = false;

    while (i < content.len) {
        const ch = content[i];

        if (escape_next) {
            try result.append(ch);
            escape_next = false;
            i += 1;
            continue;
        }

        if (ch == '\\' and in_string) {
            try result.append(ch);
            escape_next = true;
            i += 1;
            continue;
        }

        if (ch == '"') {
            in_string = !in_string;
            try result.append(ch);
            i += 1;
            continue;
        }

        if (!in_string and ch == '/' and i + 1 < content.len) {
            if (content[i + 1] == '/') {
                // Single-line comment
                while (i < content.len and content[i] != '\n') {
                    i += 1;
                }
                continue;
            } else if (content[i + 1] == '*') {
                // Multi-line comment
                i += 2;
                while (i + 1 < content.len) {
                    if (content[i] == '*' and content[i + 1] == '/') {
                        i += 2;
                        break;
                    }
                    i += 1;
                }
                continue;
            }
        }

        try result.append(ch);
        i += 1;
    }

    return result.toOwnedSlice();
}

fn parsePackageFromJson(allocator: std.mem.Allocator, value: std.json.Value) !Package {
    const obj = value.object;

    var pkg = Package{
        .name = "",
        .version = "",
    };

    // Required fields
    if (obj.get("name")) |name_val| {
        pkg.name = try allocator.dupe(u8, name_val.string);
    } else {
        return error.MissingPackageName;
    }

    if (obj.get("version")) |version_val| {
        pkg.version = try allocator.dupe(u8, version_val.string);
    } else {
        return error.MissingPackageVersion;
    }

    // Optional fields
    if (obj.get("description")) |desc_val| {
        pkg.description = try allocator.dupe(u8, desc_val.string);
    }

    if (obj.get("license")) |license_val| {
        pkg.license = try allocator.dupe(u8, license_val.string);
    }

    // Parse authors
    if (obj.get("authors")) |authors_val| {
        if (authors_val == .array) {
            const authors_array = authors_val.array;
            var authors = try allocator.alloc([]const u8, authors_array.items.len);
            for (authors_array.items, 0..) |item, i| {
                authors[i] = try allocator.dupe(u8, item.string);
            }
            pkg.authors = authors;
        }
    }

    // Parse dependencies
    if (obj.get("dependencies")) |deps_val| {
        if (deps_val == .object) {
            var deps_map = std.StringHashMap(Package.Dependency).init(allocator);
            var it = deps_val.object.iterator();
            while (it.next()) |entry| {
                const dep = try parseDependency(allocator, entry.value_ptr.*);
                try deps_map.put(entry.key_ptr.*, dep);
            }
            pkg.dependencies = deps_map;
        }
    }

    // Parse scripts
    if (obj.get("scripts")) |scripts_val| {
        if (scripts_val == .object) {
            var scripts_map = std.StringHashMap([]const u8).init(allocator);
            var it = scripts_val.object.iterator();
            while (it.next()) |entry| {
                const script = try allocator.dupe(u8, entry.value_ptr.string);
                try scripts_map.put(entry.key_ptr.*, script);
            }
            pkg.scripts = scripts_map;
        }
    }

    // Parse workspaces
    if (obj.get("workspaces")) |workspaces_val| {
        if (workspaces_val == .object) {
            if (workspaces_val.object.get("packages")) |packages_val| {
                if (packages_val == .array) {
                    const packages_array = packages_val.array;
                    var packages = try allocator.alloc([]const u8, packages_array.items.len);
                    for (packages_array.items, 0..) |item, i| {
                        packages[i] = try allocator.dupe(u8, item.string);
                    }
                    pkg.workspaces = .{ .packages = packages };
                }
            }
        }
    }

    return pkg;
}

fn parseDependency(allocator: std.mem.Allocator, value: std.json.Value) !Package.Dependency {
    var dep = Package.Dependency{};

    switch (value) {
        .string => |s| {
            // Simple version string: "^1.0.0"
            dep.version = try allocator.dupe(u8, s);
        },
        .object => |obj| {
            // Complex dependency object
            if (obj.get("path")) |path_val| {
                dep.path = try allocator.dupe(u8, path_val.string);
            }
            if (obj.get("git")) |git_val| {
                dep.git = try allocator.dupe(u8, git_val.string);
            }
            if (obj.get("version")) |version_val| {
                dep.version = try allocator.dupe(u8, version_val.string);
            }
            if (obj.get("registry")) |registry_val| {
                dep.registry = try allocator.dupe(u8, registry_val.string);
            }
        },
        else => return error.InvalidDependencyFormat,
    }

    return dep;
}

test "strip JSON comments" {
    const allocator = std.testing.allocator;

    const input =
        \\{
        \\  // This is a comment
        \\  "name": "test", /* inline comment */
        \\  "version": "1.0.0"
        \\}
    ;

    const result = try stripJsonComments(allocator, input);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "//") == null);
    try std.testing.expect(std.mem.indexOf(u8, result, "/*") == null);
}
