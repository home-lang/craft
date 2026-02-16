const std = @import("std");
const io_context = @import("io_context.zig");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Marketplace bridge for package discovery, installation, and updates
/// Integrates with Pantry (the Craft ecosystem package manager)
pub const MarketplaceBridge = struct {
    allocator: std.mem.Allocator,
    pantry_path: ?[]const u8 = null,
    cache_dir: ?[]const u8 = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        var self = Self{
            .allocator = allocator,
        };

        // Try to find pantry binary
        self.detectPantryInstallation();

        return self;
    }

    fn detectPantryInstallation(self: *Self) void {
        // Check common locations for pantry
        const locations = [_][]const u8{
            "/usr/local/bin/pantry",
            "/opt/homebrew/bin/pantry",
            "~/.local/bin/pantry",
            "~/.bun/bin/pantry",
        };

        const io = io_context.get();
        for (locations) |loc| {
            if (io_context.cwd().access(io, loc, .{})) |_| {
                self.pantry_path = loc;
                break;
            } else |_| {}
        }

        // Also try to find via PATH by running 'which pantry'
        if (self.pantry_path == null) {
            var child = std.process.Child.init(&.{ "which", "pantry" }, self.allocator);
            child.stdout_behavior = .Pipe;
            child.stderr_behavior = .Ignore;

            child.spawn() catch return;
            const result = child.wait() catch return;

            if (result.Exited == 0) {
                if (child.stdout) |stdout| {
                    const output = stdout.reader().readAllAlloc(self.allocator, 1024) catch return;
                    const trimmed = std.mem.trim(u8, output, "\n\r ");
                    if (trimmed.len > 0) {
                        self.pantry_path = self.allocator.dupe(u8, trimmed) catch null;
                    }
                    self.allocator.free(output);
                }
            }
        }

        if (self.pantry_path != null) {
            std.debug.print("[MarketplaceBridge] Found pantry at: {s}\n", .{self.pantry_path.?});
        } else {
            std.debug.print("[MarketplaceBridge] Pantry not found, marketplace features limited\n", .{});
        }
    }

    /// Handle marketplace-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        self.handleMessageInternal(action, data) catch |err| {
            self.reportError(action, err);
        };
    }

    fn handleMessageInternal(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "search")) {
            try self.search(data);
        } else if (std.mem.eql(u8, action, "install")) {
            try self.install(data);
        } else if (std.mem.eql(u8, action, "uninstall")) {
            try self.uninstall(data);
        } else if (std.mem.eql(u8, action, "update")) {
            try self.update(data);
        } else if (std.mem.eql(u8, action, "list")) {
            try self.list(data);
        } else if (std.mem.eql(u8, action, "info")) {
            try self.info(data);
        } else if (std.mem.eql(u8, action, "isAvailable")) {
            try self.isAvailable(data);
        } else if (std.mem.eql(u8, action, "getVersion")) {
            try self.getVersion(data);
        } else if (std.mem.eql(u8, action, "login")) {
            try self.login(data);
        } else if (std.mem.eql(u8, action, "logout")) {
            try self.logout(data);
        } else if (std.mem.eql(u8, action, "publish")) {
            try self.publish(data);
        } else {
            return BridgeError.UnknownAction;
        }
    }

    fn reportError(self: *Self, action: []const u8, err: anyerror) void {
        const bridge_err: BridgeError = switch (err) {
            BridgeError.MissingData => BridgeError.MissingData,
            BridgeError.InvalidJSON => BridgeError.InvalidJSON,
            else => BridgeError.NativeCallFailed,
        };
        bridge_error.sendErrorToJS(self.allocator, action, bridge_err);
    }

    /// Check if Pantry marketplace is available
    /// JSON: {"callbackId": "cb1"}
    fn isAvailable(self: *Self, data: []const u8) !void {
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        const available = self.pantry_path != null;

        self.sendResult(callback_id, "isAvailable", if (available) "true" else "false");
    }

    /// Get Pantry version
    /// JSON: {"callbackId": "cb1"}
    fn getVersion(self: *Self, data: []const u8) !void {
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (self.pantry_path == null) {
            self.sendResult(callback_id, "getVersion", "\"not installed\"");
            return;
        }

        // Run pantry --version
        var child = std.process.Child.init(&.{ self.pantry_path.?, "--version" }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Ignore;

        child.spawn() catch {
            self.sendResult(callback_id, "getVersion", "\"error\"");
            return;
        };
        _ = child.wait() catch {
            self.sendResult(callback_id, "getVersion", "\"error\"");
            return;
        };

        if (child.stdout) |stdout| {
            const output = stdout.reader().readAllAlloc(self.allocator, 1024) catch {
                self.sendResult(callback_id, "getVersion", "\"error\"");
                return;
            };
            defer self.allocator.free(output);

            const trimmed = std.mem.trim(u8, output, "\n\r ");

            var buf: [256]u8 = undefined;
            const result = std.fmt.bufPrint(&buf, "\"{s}\"", .{trimmed}) catch return;
            self.sendResult(callback_id, "getVersion", result);
        }
    }

    /// Search packages in the marketplace
    /// JSON: {"query": "ui-components", "callbackId": "cb1"}
    fn search(self: *Self, data: []const u8) !void {
        var query: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"query\":\"")) |idx| {
            const start = idx + 9;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                query = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[MarketplaceBridge] search: {s}\n", .{query});

        if (self.pantry_path == null) {
            self.sendError(callback_id, "search", "Pantry not installed");
            return;
        }

        // Run pantry search <query>
        var child = std.process.Child.init(&.{ self.pantry_path.?, "search", query }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch {
            self.sendError(callback_id, "search", "Failed to run pantry");
            return;
        };
        _ = child.wait() catch {
            self.sendError(callback_id, "search", "Pantry search failed");
            return;
        };

        if (child.stdout) |stdout| {
            const output = stdout.reader().readAllAlloc(self.allocator, 64 * 1024) catch {
                self.sendError(callback_id, "search", "Failed to read output");
                return;
            };
            defer self.allocator.free(output);

            // Parse and send results as JSON
            // For now, send raw output - in production, would parse into structured JSON
            self.sendResultEscaped(callback_id, "search", output);
        }
    }

    /// Install a package
    /// JSON: {"name": "package-name", "version": "1.0.0", "callbackId": "cb1"}
    fn install(self: *Self, data: []const u8) !void {
        var name: []const u8 = "";
        var version: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"name\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                name = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"version\":\"")) |idx| {
            const start = idx + 11;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                version = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (name.len == 0) {
            self.sendError(callback_id, "install", "Package name required");
            return;
        }

        std.debug.print("[MarketplaceBridge] install: {s}@{s}\n", .{ name, version });

        if (self.pantry_path == null) {
            self.sendError(callback_id, "install", "Pantry not installed");
            return;
        }

        // Build package spec (name@version or just name)
        var spec_buf: [256]u8 = undefined;
        const spec = if (version.len > 0)
            std.fmt.bufPrint(&spec_buf, "{s}@{s}", .{ name, version }) catch name
        else
            name;

        // Run pantry install <spec>
        var child = std.process.Child.init(&.{ self.pantry_path.?, "install", spec }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch {
            self.sendError(callback_id, "install", "Failed to run pantry");
            return;
        };

        const result = child.wait() catch {
            self.sendError(callback_id, "install", "Installation failed");
            return;
        };

        if (result.Exited == 0) {
            self.sendResult(callback_id, "install", "{\"success\":true}");
        } else {
            if (child.stderr) |stderr| {
                const err_output = stderr.reader().readAllAlloc(self.allocator, 4096) catch "Unknown error";
                defer if (@TypeOf(err_output) != @TypeOf("Unknown error")) self.allocator.free(err_output);
                self.sendResultEscaped(callback_id, "install", err_output);
            } else {
                self.sendError(callback_id, "install", "Installation failed");
            }
        }
    }

    /// Uninstall a package
    /// JSON: {"name": "package-name", "callbackId": "cb1"}
    fn uninstall(self: *Self, data: []const u8) !void {
        var name: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"name\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                name = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (name.len == 0) {
            self.sendError(callback_id, "uninstall", "Package name required");
            return;
        }

        std.debug.print("[MarketplaceBridge] uninstall: {s}\n", .{name});

        if (self.pantry_path == null) {
            self.sendError(callback_id, "uninstall", "Pantry not installed");
            return;
        }

        var child = std.process.Child.init(&.{ self.pantry_path.?, "remove", name }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch {
            self.sendError(callback_id, "uninstall", "Failed to run pantry");
            return;
        };

        const result = child.wait() catch {
            self.sendError(callback_id, "uninstall", "Uninstallation failed");
            return;
        };

        if (result.Exited == 0) {
            self.sendResult(callback_id, "uninstall", "{\"success\":true}");
        } else {
            self.sendError(callback_id, "uninstall", "Uninstallation failed");
        }
    }

    /// Update packages
    /// JSON: {"name": "package-name", "callbackId": "cb1"} or {"callbackId": "cb1"} for all
    fn update(self: *Self, data: []const u8) !void {
        var name: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"name\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                name = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[MarketplaceBridge] update: {s}\n", .{if (name.len > 0) name else "all"});

        if (self.pantry_path == null) {
            self.sendError(callback_id, "update", "Pantry not installed");
            return;
        }

        // Run pantry update [name]
        const args = if (name.len > 0)
            &[_][]const u8{ self.pantry_path.?, "update", name }
        else
            &[_][]const u8{ self.pantry_path.?, "update" };

        var child = std.process.Child.init(args, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch {
            self.sendError(callback_id, "update", "Failed to run pantry");
            return;
        };

        const result = child.wait() catch {
            self.sendError(callback_id, "update", "Update failed");
            return;
        };

        if (result.Exited == 0) {
            self.sendResult(callback_id, "update", "{\"success\":true}");
        } else {
            self.sendError(callback_id, "update", "Update failed");
        }
    }

    /// List installed packages
    /// JSON: {"callbackId": "cb1"}
    fn list(self: *Self, data: []const u8) !void {
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[MarketplaceBridge] list\n", .{});

        if (self.pantry_path == null) {
            self.sendError(callback_id, "list", "Pantry not installed");
            return;
        }

        var child = std.process.Child.init(&.{ self.pantry_path.?, "list" }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Ignore;

        child.spawn() catch {
            self.sendError(callback_id, "list", "Failed to run pantry");
            return;
        };
        _ = child.wait() catch {
            self.sendError(callback_id, "list", "List failed");
            return;
        };

        if (child.stdout) |stdout| {
            const output = stdout.reader().readAllAlloc(self.allocator, 64 * 1024) catch {
                self.sendError(callback_id, "list", "Failed to read output");
                return;
            };
            defer self.allocator.free(output);

            self.sendResultEscaped(callback_id, "list", output);
        }
    }

    /// Get package info
    /// JSON: {"name": "package-name", "callbackId": "cb1"}
    fn info(self: *Self, data: []const u8) !void {
        var name: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"name\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                name = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (name.len == 0) {
            self.sendError(callback_id, "info", "Package name required");
            return;
        }

        std.debug.print("[MarketplaceBridge] info: {s}\n", .{name});

        if (self.pantry_path == null) {
            self.sendError(callback_id, "info", "Pantry not installed");
            return;
        }

        var child = std.process.Child.init(&.{ self.pantry_path.?, "info", name }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Ignore;

        child.spawn() catch {
            self.sendError(callback_id, "info", "Failed to run pantry");
            return;
        };
        _ = child.wait() catch {
            self.sendError(callback_id, "info", "Info failed");
            return;
        };

        if (child.stdout) |stdout| {
            const output = stdout.reader().readAllAlloc(self.allocator, 64 * 1024) catch {
                self.sendError(callback_id, "info", "Failed to read output");
                return;
            };
            defer self.allocator.free(output);

            self.sendResultEscaped(callback_id, "info", output);
        }
    }

    /// Login to marketplace
    /// JSON: {"callbackId": "cb1"}
    fn login(self: *Self, data: []const u8) !void {
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[MarketplaceBridge] login\n", .{});

        if (self.pantry_path == null) {
            self.sendError(callback_id, "login", "Pantry not installed");
            return;
        }

        // Run pantry login - this may open a browser for OAuth
        var child = std.process.Child.init(&.{ self.pantry_path.?, "login" }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch {
            self.sendError(callback_id, "login", "Failed to run pantry");
            return;
        };

        const result = child.wait() catch {
            self.sendError(callback_id, "login", "Login failed");
            return;
        };

        if (result.Exited == 0) {
            self.sendResult(callback_id, "login", "{\"success\":true}");
        } else {
            self.sendError(callback_id, "login", "Login failed");
        }
    }

    /// Logout from marketplace
    /// JSON: {"callbackId": "cb1"}
    fn logout(self: *Self, data: []const u8) !void {
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[MarketplaceBridge] logout\n", .{});

        if (self.pantry_path == null) {
            self.sendError(callback_id, "logout", "Pantry not installed");
            return;
        }

        var child = std.process.Child.init(&.{ self.pantry_path.?, "logout" }, self.allocator);
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;

        child.spawn() catch {
            self.sendError(callback_id, "logout", "Failed to run pantry");
            return;
        };

        const result = child.wait() catch {
            self.sendError(callback_id, "logout", "Logout failed");
            return;
        };

        if (result.Exited == 0) {
            self.sendResult(callback_id, "logout", "{\"success\":true}");
        } else {
            self.sendError(callback_id, "logout", "Logout failed");
        }
    }

    /// Publish a package to marketplace
    /// JSON: {"path": "/path/to/package", "callbackId": "cb1"}
    fn publish(self: *Self, data: []const u8) !void {
        var path: []const u8 = ".";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"path\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                path = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[MarketplaceBridge] publish: {s}\n", .{path});

        if (self.pantry_path == null) {
            self.sendError(callback_id, "publish", "Pantry not installed");
            return;
        }

        var child = std.process.Child.init(&.{ self.pantry_path.?, "publish", path }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch {
            self.sendError(callback_id, "publish", "Failed to run pantry");
            return;
        };

        const result = child.wait() catch {
            self.sendError(callback_id, "publish", "Publish failed");
            return;
        };

        if (result.Exited == 0) {
            self.sendResult(callback_id, "publish", "{\"success\":true}");
        } else {
            if (child.stderr) |stderr| {
                const err_output = stderr.reader().readAllAlloc(self.allocator, 4096) catch "Unknown error";
                defer if (@TypeOf(err_output) != @TypeOf("Unknown error")) self.allocator.free(err_output);
                self.sendResultEscaped(callback_id, "publish", err_output);
            } else {
                self.sendError(callback_id, "publish", "Publish failed");
            }
        }
    }

    // Helper functions for sending results to JavaScript

    fn sendResult(_: *Self, callback_id: []const u8, action: []const u8, result: []const u8) void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        var buf: [8192]u8 = undefined;
        const js = std.fmt.bufPrint(&buf, "if(window.__craftMarketplaceCallback)window.__craftMarketplaceCallback('{s}','{s}',{s});", .{ callback_id, action, result }) catch return;

        macos.tryEvalJS(js) catch {};
    }

    fn sendResultEscaped(self: *Self, callback_id: []const u8, action: []const u8, content: []const u8) void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        // Escape for JavaScript string
        var buf: [65536]u8 = undefined;
        var pos: usize = 0;

        const prefix = std.fmt.bufPrint(buf[pos..], "if(window.__craftMarketplaceCallback)window.__craftMarketplaceCallback('{s}','{s}','", .{ callback_id, action }) catch return;
        pos += prefix.len;

        for (content) |c| {
            if (pos >= buf.len - 10) break;
            switch (c) {
                '\n' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = 'n';
                    pos += 1;
                },
                '\r' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = 'r';
                    pos += 1;
                },
                '\t' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = 't';
                    pos += 1;
                },
                '\\' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = '\\';
                    pos += 1;
                },
                '\'' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = '\'';
                    pos += 1;
                },
                else => {
                    buf[pos] = c;
                    pos += 1;
                },
            }
        }

        _ = self;
        const suffix = "');";
        @memcpy(buf[pos .. pos + suffix.len], suffix);
        pos += suffix.len;

        macos.tryEvalJS(buf[0..pos]) catch {};
    }

    fn sendError(_: *Self, callback_id: []const u8, action: []const u8, message: []const u8) void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        var buf: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&buf, "if(window.__craftMarketplaceError)window.__craftMarketplaceError('{s}','{s}','{s}');", .{ callback_id, action, message }) catch return;

        macos.tryEvalJS(js) catch {};
    }

    pub fn deinit(self: *Self) void {
        if (self.pantry_path) |path| {
            // Only free if we allocated it (from 'which' command)
            // Static strings don't need freeing
            _ = path;
        }
    }
};

/// Global marketplace bridge instance
var global_marketplace_bridge: ?*MarketplaceBridge = null;

pub fn getGlobalMarketplaceBridge() ?*MarketplaceBridge {
    return global_marketplace_bridge;
}

pub fn setGlobalMarketplaceBridge(bridge: *MarketplaceBridge) void {
    global_marketplace_bridge = bridge;
}
