const std = @import("std");
const macos = @import("macos.zig");
const NativeSidebar = @import("components/native_sidebar.zig").NativeSidebar;
const NativeFileBrowser = @import("components/native_file_browser.zig").NativeFileBrowser;
const NativeSplitView = @import("components/native_split_view.zig").NativeSplitView;

/// Bridge handler for native UI components
/// Routes messages from JavaScript to native AppKit components
pub const NativeUIBridge = struct {
    allocator: std.mem.Allocator,
    window: ?macos.objc.id,
    sidebars: std.StringHashMap(*NativeSidebar),
    file_browsers: std.StringHashMap(*NativeFileBrowser),
    split_views: std.StringHashMap(*NativeSplitView),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) NativeUIBridge {
        return .{
            .allocator = allocator,
            .window = null,
            .sidebars = std.StringHashMap(*NativeSidebar).init(allocator),
            .file_browsers = std.StringHashMap(*NativeFileBrowser).init(allocator),
            .split_views = std.StringHashMap(*NativeSplitView).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        // Clean up all sidebars
        var sidebar_iter = self.sidebars.iterator();
        while (sidebar_iter.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.sidebars.deinit();

        // Clean up all file browsers
        var browser_iter = self.file_browsers.iterator();
        while (browser_iter.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.file_browsers.deinit();

        // Clean up all split views
        var split_iter = self.split_views.iterator();
        while (split_iter.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.split_views.deinit();
    }

    pub fn setWindow(self: *Self, window: macos.objc.id) void {
        self.window = window;
    }

    /// Handle incoming messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        std.debug.print("[NativeUI] Action: {s}, Data: {s}\n", .{ action, data });

        if (std.mem.eql(u8, action, "createSidebar")) {
            try self.createSidebar(data);
        } else if (std.mem.eql(u8, action, "addSidebarSection")) {
            try self.addSidebarSection(data);
        } else if (std.mem.eql(u8, action, "setSelectedItem")) {
            try self.setSelectedItem(data);
        } else if (std.mem.eql(u8, action, "createFileBrowser")) {
            try self.createFileBrowser(data);
        } else if (std.mem.eql(u8, action, "addFile")) {
            try self.addFile(data);
        } else if (std.mem.eql(u8, action, "addFiles")) {
            try self.addFiles(data);
        } else if (std.mem.eql(u8, action, "clearFiles")) {
            try self.clearFiles(data);
        } else if (std.mem.eql(u8, action, "createSplitView")) {
            try self.createSplitView(data);
        } else if (std.mem.eql(u8, action, "destroyComponent")) {
            try self.destroyComponent(data);
        } else {
            std.debug.print("[NativeUI] Unknown action: {s}\n", .{action});
        }
    }

    /// Create a new sidebar component
    fn createSidebar(self: *Self, data: []const u8) !void {
        std.debug.print("[NativeUI] Parsing JSON: {s}\n", .{data});

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, data, .{}) catch |err| {
            std.debug.print("[NativeUI] JSON parse error: {any}\n", .{err});
            return err;
        };
        defer parsed.deinit();

        const root = parsed.value.object;
        const id = root.get("id").?.string;

        std.debug.print("[NativeUI] Creating sidebar: {s}\n", .{id});

        // Create sidebar
        const sidebar = try NativeSidebar.init(self.allocator);
        errdefer sidebar.deinit();

        // Store in registry
        const id_copy = try self.allocator.dupe(u8, id);
        try self.sidebars.put(id_copy, sidebar);

        // Add to window if we have window reference
        if (self.window) |window| {
            const NSRect = extern struct {
                origin: extern struct { x: f64, y: f64 },
                size: extern struct { width: f64, height: f64 },
            };

            // Get current content view (which is the webview)
            const webview = macos.msgSend0(window, "contentView");
            std.debug.print("[NativeUI-DEBUG] Webview ptr: {*}\n", .{webview});

            // Get window frame to get correct dimensions
            const frame_result = macos.msgSend0(window, "frame");
            const frame: *const NSRect = @ptrCast(@alignCast(frame_result));
            const window_width = frame.size.width;
            const window_height = frame.size.height;

            std.debug.print("[NativeUI-DEBUG] Window dimensions from frame: {d}x{d}\n", .{ window_width, window_height });

            const sidebar_width: f64 = 240;

            // Create a container view to hold both sidebar and webview
            const NSView = macos.getClass("NSView");
            const container = macos.msgSend0(macos.msgSend0(NSView, "alloc"), "init");
            std.debug.print("[NativeUI-DEBUG] Container ptr: {*}\n", .{container});

            // Set container frame to match current content view
            const container_frame = NSRect{
                .origin = .{ .x = 0, .y = 0 },
                .size = .{ .width = window_width, .height = window_height },
            };
            _ = macos.msgSend1(container, "setFrame:", container_frame);
            std.debug.print("[NativeUI-DEBUG] Container frame set: ({d},{d}) {d}x{d}\n", .{ container_frame.origin.x, container_frame.origin.y, container_frame.size.width, container_frame.size.height });

            _ = macos.msgSend1(container, "setAutoresizingMask:", @as(c_ulong, 18)); // Width + Height resizable

            // Adjust webview frame to make room for sidebar
            const webview_frame = NSRect{
                .origin = .{ .x = sidebar_width, .y = 0 },
                .size = .{ .width = window_width - sidebar_width, .height = window_height },
            };
            _ = macos.msgSend1(webview, "setFrame:", webview_frame);
            std.debug.print("[NativeUI-DEBUG] Webview frame set: ({d},{d}) {d}x{d}\n", .{ webview_frame.origin.x, webview_frame.origin.y, webview_frame.size.width, webview_frame.size.height });

            _ = macos.msgSend1(webview, "setAutoresizingMask:", @as(c_ulong, 18)); // Width + Height resizable

            // Position sidebar on the left side
            const sidebar_view = sidebar.getView();
            std.debug.print("[NativeUI-DEBUG] Sidebar view ptr: {*}\n", .{sidebar_view});

            sidebar.setFrame(0, 0, sidebar_width, window_height);
            std.debug.print("[NativeUI-DEBUG] Sidebar frame set: (0,0) {d}x{d}\n", .{ sidebar_width, window_height });

            sidebar.setAutoresizingMask(18); // Height resizable

            // Set a visible background color on sidebar for debugging
            const NSColor = macos.getClass("NSColor");
            const redColor = macos.msgSend4(NSColor, "colorWithRed:green:blue:alpha:", @as(f64, 1.0), @as(f64, 0.0), @as(f64, 0.0), @as(f64, 0.5)); // Semi-transparent red
            _ = macos.msgSend1(sidebar_view, "setBackgroundColor:", redColor);
            std.debug.print("[NativeUI-DEBUG] Sidebar background color set to red\n", .{});

            // Add both views to container
            _ = macos.msgSend1(container, "addSubview:", webview);
            std.debug.print("[NativeUI-DEBUG] Webview added to container\n", .{});

            _ = macos.msgSend1(container, "addSubview:", sidebar_view);
            std.debug.print("[NativeUI-DEBUG] Sidebar added to container\n", .{});

            // Verify subviews were added
            const subviews = macos.msgSend0(container, "subviews");
            const subview_count = macos.msgSend0(subviews, "count");
            std.debug.print("[NativeUI-DEBUG] Container has {*} subviews\n", .{subview_count});

            // Replace content view with container
            _ = macos.msgSend1(window, "setContentView:", container);
            std.debug.print("[NativeUI-DEBUG] Container set as content view\n", .{});

            // Verify content view was changed
            const new_content_view = macos.msgSend0(window, "contentView");
            std.debug.print("[NativeUI-DEBUG] New content view ptr: {*}\n", .{new_content_view});

            std.debug.print("[NativeUI] ✓ Sidebar added (240x{d}), webview adjusted ({d}x{d})\n", .{ window_height, window_width - sidebar_width, window_height });
        }
    }

    /// Add a section to an existing sidebar
    fn addSidebarSection(self: *Self, data: []const u8) !void {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, data, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const sidebar_id = root.get("sidebarId").?.string;
        const section_data = root.get("section").?.object;

        // Get sidebar from registry
        const sidebar = self.sidebars.get(sidebar_id) orelse return error.SidebarNotFound;

        const section_id = section_data.get("id").?.string;
        const header = if (section_data.get("header")) |h| h.string else null;
        const items_json = section_data.get("items").?.array;

        // Build items array
        var items: std.ArrayList(NativeSidebar.SidebarItem) = .{};
        defer items.deinit(self.allocator);

        for (items_json.items) |item_json| {
            const item_obj = item_json.object;
            try items.append(self.allocator, .{
                .id = item_obj.get("id").?.string,
                .label = item_obj.get("label").?.string,
                .icon = if (item_obj.get("icon")) |icon| icon.string else null,
                .badge = if (item_obj.get("badge")) |badge| badge.string else null,
            });
        }

        // Add section to sidebar
        try sidebar.addSection(.{
            .id = section_id,
            .header = header,
            .items = items.items,
        });

        std.debug.print("[NativeUI] ✓ Added section '{s}' to sidebar '{s}'\n", .{ section_id, sidebar_id });
    }

    /// Set selected item in sidebar
    fn setSelectedItem(self: *Self, data: []const u8) !void {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, data, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const sidebar_id = root.get("sidebarId").?.string;
        const item_id = root.get("itemId").?.string;

        const sidebar = self.sidebars.get(sidebar_id) orelse return error.SidebarNotFound;
        sidebar.setSelectedItem(item_id);

        std.debug.print("[NativeUI] ✓ Selected item '{s}' in sidebar '{s}'\n", .{ item_id, sidebar_id });
    }

    /// Create a new file browser component
    fn createFileBrowser(self: *Self, data: []const u8) !void {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, data, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const id = root.get("id").?.string;

        std.debug.print("[NativeUI] Creating file browser: {s}\n", .{id});

        // Create file browser
        const browser = try NativeFileBrowser.init(self.allocator);
        errdefer browser.deinit();

        // Store in registry
        const id_copy = try self.allocator.dupe(u8, id);
        try self.file_browsers.put(id_copy, browser);

        // Add to window if we have window reference
        if (self.window) |window| {
            const content_view = macos.msgSend0(window, "contentView");
            const browser_view = browser.getView();

            // Get window frame
            const frame = macos.msgSend0(window, "frame");
            const frame_ptr: [*]const f64 = @ptrCast(@alignCast(&frame));
            const window_width = frame_ptr[2];
            const window_height = frame_ptr[3];

            browser.setFrame(240, 0, window_width - 240, window_height);
            browser.setAutoresizingMask(18); // Width + Height resizable

            _ = macos.msgSend1(content_view, "addSubview:", browser_view);
            std.debug.print("[NativeUI] ✓ File browser added to window\n", .{});
        }
    }

    /// Add a single file to file browser
    fn addFile(self: *Self, data: []const u8) !void {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, data, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const browser_id = root.get("browserId").?.string;
        const file_data = root.get("file").?.object;

        const browser = self.file_browsers.get(browser_id) orelse return error.BrowserNotFound;

        const file = NativeFileBrowser.FileItem{
            .id = file_data.get("id").?.string,
            .name = file_data.get("name").?.string,
            .icon = if (file_data.get("icon")) |icon| icon.string else null,
            .date_modified = if (file_data.get("dateModified")) |date| date.string else null,
            .size = if (file_data.get("size")) |size| size.string else null,
            .kind = if (file_data.get("kind")) |kind| kind.string else null,
        };

        try browser.addFile(file);
        std.debug.print("[NativeUI] ✓ Added file '{s}' to browser '{s}'\n", .{ file.name, browser_id });
    }

    /// Add multiple files to file browser
    fn addFiles(self: *Self, data: []const u8) !void {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, data, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const browser_id = root.get("browserId").?.string;
        const files_json = root.get("files").?.array;

        const browser = self.file_browsers.get(browser_id) orelse return error.BrowserNotFound;

        var files: std.ArrayList(NativeFileBrowser.FileItem) = .{};
        defer files.deinit(self.allocator);

        for (files_json.items) |file_json| {
            const file_obj = file_json.object;
            try files.append(self.allocator, .{
                .id = file_obj.get("id").?.string,
                .name = file_obj.get("name").?.string,
                .icon = if (file_obj.get("icon")) |icon| icon.string else null,
                .date_modified = if (file_obj.get("dateModified")) |date| date.string else null,
                .size = if (file_obj.get("size")) |size| size.string else null,
                .kind = if (file_obj.get("kind")) |kind| kind.string else null,
            });
        }

        try browser.addFiles(files.items);
        std.debug.print("[NativeUI] ✓ Added {d} files to browser '{s}'\n", .{ files.items.len, browser_id });
    }

    /// Clear all files from file browser
    fn clearFiles(self: *Self, data: []const u8) !void {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, data, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const browser_id = root.get("browserId").?.string;

        const browser = self.file_browsers.get(browser_id) orelse return error.BrowserNotFound;
        browser.clearFiles();

        std.debug.print("[NativeUI] ✓ Cleared files from browser '{s}'\n", .{browser_id});
    }

    /// Create a split view combining sidebar and file browser
    fn createSplitView(self: *Self, data: []const u8) !void {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, data, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const id = root.get("id").?.string;
        const sidebar_id = root.get("sidebarId").?.string;
        const browser_id = root.get("browserId").?.string;

        std.debug.print("[NativeUI] Creating split view: {s}\n", .{id});

        // Get sidebar and browser
        const sidebar = self.sidebars.get(sidebar_id) orelse return error.SidebarNotFound;
        const browser = self.file_browsers.get(browser_id) orelse return error.BrowserNotFound;

        // Create split view
        const split_view = try NativeSplitView.init(self.allocator, .{});
        errdefer split_view.deinit();

        // Add components to split view
        split_view.setSidebar(sidebar);
        split_view.setFileBrowser(browser);

        // Store in registry
        const id_copy = try self.allocator.dupe(u8, id);
        try self.split_views.put(id_copy, split_view);

        // Add to window if we have window reference
        if (self.window) |window| {
            const content_view = macos.msgSend0(window, "contentView");
            const split_view_obj = split_view.getView();

            // Get window frame
            const frame = macos.msgSend0(window, "frame");
            const frame_ptr: [*]const f64 = @ptrCast(@alignCast(&frame));
            const window_width = frame_ptr[2];
            const window_height = frame_ptr[3];

            split_view.setFrame(0, 0, window_width, window_height);
            split_view.setAutoresizingMask(18); // Width + Height resizable

            _ = macos.msgSend1(content_view, "addSubview:", split_view_obj);
            std.debug.print("[NativeUI] ✓ Split view added to window\n", .{});
        }
    }

    /// Destroy a component
    fn destroyComponent(self: *Self, data: []const u8) !void {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, data, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const id = root.get("id").?.string;
        const component_type = root.get("type").?.string;

        if (std.mem.eql(u8, component_type, "sidebar")) {
            if (self.sidebars.fetchRemove(id)) |entry| {
                self.allocator.free(entry.key);
                entry.value.deinit();
                std.debug.print("[NativeUI] ✓ Destroyed sidebar '{s}'\n", .{id});
            }
        } else if (std.mem.eql(u8, component_type, "fileBrowser")) {
            if (self.file_browsers.fetchRemove(id)) |entry| {
                self.allocator.free(entry.key);
                entry.value.deinit();
                std.debug.print("[NativeUI] ✓ Destroyed file browser '{s}'\n", .{id});
            }
        } else if (std.mem.eql(u8, component_type, "splitView")) {
            if (self.split_views.fetchRemove(id)) |entry| {
                self.allocator.free(entry.key);
                entry.value.deinit();
                std.debug.print("[NativeUI] ✓ Destroyed split view '{s}'\n", .{id});
            }
        }
    }
};
