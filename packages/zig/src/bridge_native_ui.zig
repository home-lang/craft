const std = @import("std");
const macos = @import("macos.zig");
const NativeSidebar = @import("components/native_sidebar.zig").NativeSidebar;
const NativeFileBrowser = @import("components/native_file_browser.zig").NativeFileBrowser;
const NativeSplitView = @import("components/native_split_view.zig").NativeSplitView;
const NativeSplitViewController = @import("components/native_split_view_controller.zig").NativeSplitViewController;
const context_menu = @import("components/context_menu.zig");
const quick_look = @import("components/quick_look.zig");
const TestHelpers = @import("test_helpers.zig").TestHelpers;

/// Bridge handler for native UI components
/// Routes messages from JavaScript to native AppKit components
pub const NativeUIBridge = struct {
    allocator: std.mem.Allocator,
    window: ?macos.objc.id,
    sidebars: std.StringHashMap(*NativeSidebar),
    file_browsers: std.StringHashMap(*NativeFileBrowser),
    split_views: std.StringHashMap(*NativeSplitView),
    split_view_controller: ?*NativeSplitViewController,
    original_webview: ?macos.objc.id,
    last_reload_time: i64,
    is_destroyed: bool,
    active_context_menu_delegate: ?*context_menu.ContextMenuDelegate,
    quick_look_controller: ?*quick_look.QuickLookController,

    const Self = @This();
    const RELOAD_DEBOUNCE_MS: i64 = 16; // ~60fps

    pub fn init(allocator: std.mem.Allocator) NativeUIBridge {
        return .{
            .allocator = allocator,
            .window = null,
            .sidebars = std.StringHashMap(*NativeSidebar).init(allocator),
            .file_browsers = std.StringHashMap(*NativeFileBrowser).init(allocator),
            .split_views = std.StringHashMap(*NativeSplitView).init(allocator),
            .split_view_controller = null,
            .original_webview = null,
            .last_reload_time = 0,
            .is_destroyed = false,
            .active_context_menu_delegate = null,
            .quick_look_controller = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.is_destroyed = true;

        // Clean up Quick Look controller
        if (self.quick_look_controller) |controller| {
            controller.deinit();
            self.quick_look_controller = null;
        }

        // Clean up active context menu delegate
        if (self.active_context_menu_delegate) |delegate| {
            delegate.deinit();
            self.active_context_menu_delegate = null;
        }

        // Clean up split view controller
        if (self.split_view_controller) |svc| {
            svc.deinit();
            self.split_view_controller = null;
        }

        // Clean up all sidebars
        var sidebar_iter = self.sidebars.iterator();
        while (sidebar_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit();
        }
        self.sidebars.deinit();

        // Clean up all file browsers
        var browser_iter = self.file_browsers.iterator();
        while (browser_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit();
        }
        self.file_browsers.deinit();

        // Clean up all split views
        var split_iter = self.split_views.iterator();
        while (split_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit();
        }
        self.split_views.deinit();

        self.window = null;
        self.original_webview = null;

        std.debug.print("[NativeUI] Bridge destroyed and all components cleaned up\n", .{});
    }

    /// Called when window is about to close - cleanup all resources
    pub fn handleWindowClose(self: *Self) void {
        std.debug.print("[NativeUI] Window closing - cleaning up resources\n", .{});
        self.deinit();
    }

    pub fn setWindow(self: *Self, window: macos.objc.id) void {
        self.window = window;
    }

    /// Handle incoming messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        // Edge case: Bridge is destroyed
        if (self.is_destroyed) {
            std.debug.print("[NativeUI] WARNING: Message received after bridge destroyed. Ignoring.\n", .{});
            return;
        }

        // Edge case: Empty action
        if (action.len == 0) {
            std.debug.print("[NativeUI] WARNING: Empty action received. Ignoring.\n", .{});
            return;
        }

        std.debug.print("[NativeUI] Action: {s}, Data length: {d}\n", .{ action, data.len });

        if (std.mem.eql(u8, action, "createSidebar")) {
            self.createSidebar(data) catch |err| {
                std.debug.print("[NativeUI] ERROR creating sidebar: {any}\n", .{err});
            };
        } else if (std.mem.eql(u8, action, "addSidebarSection")) {
            self.addSidebarSection(data) catch |err| {
                std.debug.print("[NativeUI] ERROR adding sidebar section: {any}\n", .{err});
            };
        } else if (std.mem.eql(u8, action, "setSelectedItem")) {
            self.setSelectedItem(data) catch |err| {
                std.debug.print("[NativeUI] ERROR setting selected item: {any}\n", .{err});
            };
        } else if (std.mem.eql(u8, action, "createFileBrowser")) {
            self.createFileBrowser(data) catch |err| {
                std.debug.print("[NativeUI] ERROR creating file browser: {any}\n", .{err});
            };
        } else if (std.mem.eql(u8, action, "addFile")) {
            self.addFile(data) catch |err| {
                std.debug.print("[NativeUI] ERROR adding file: {any}\n", .{err});
            };
        } else if (std.mem.eql(u8, action, "addFiles")) {
            self.addFiles(data) catch |err| {
                std.debug.print("[NativeUI] ERROR adding files: {any}\n", .{err});
            };
        } else if (std.mem.eql(u8, action, "clearFiles")) {
            self.clearFiles(data) catch |err| {
                std.debug.print("[NativeUI] ERROR clearing files: {any}\n", .{err});
            };
        } else if (std.mem.eql(u8, action, "createSplitView")) {
            self.createSplitView(data) catch |err| {
                std.debug.print("[NativeUI] ERROR creating split view: {any}\n", .{err});
            };
        } else if (std.mem.eql(u8, action, "destroyComponent")) {
            self.destroyComponent(data) catch |err| {
                std.debug.print("[NativeUI] ERROR destroying component: {any}\n", .{err});
            };
        } else if (std.mem.eql(u8, action, "showContextMenu")) {
            self.showContextMenu(data) catch |err| {
                std.debug.print("[NativeUI] ERROR showing context menu: {any}\n", .{err});
            };
        } else if (std.mem.eql(u8, action, "showQuickLook")) {
            self.showQuickLook(data) catch |err| {
                std.debug.print("[NativeUI] ERROR showing Quick Look: {any}\n", .{err});
            };
        } else if (std.mem.eql(u8, action, "closeQuickLook")) {
            self.closeQuickLook();
        } else if (std.mem.eql(u8, action, "toggleQuickLook")) {
            self.toggleQuickLook(data) catch |err| {
                std.debug.print("[NativeUI] ERROR toggling Quick Look: {any}\n", .{err});
            };
        } else {
            std.debug.print("[NativeUI] Unknown action: {s}\n", .{action});
        }
    }

    /// Check if enough time has passed for a reload (debounce)
    fn shouldDebounceReload(self: *Self) bool {
        const now = std.time.milliTimestamp();
        if (now - self.last_reload_time < RELOAD_DEBOUNCE_MS) {
            return true;
        }
        self.last_reload_time = now;
        return false;
    }

    /// Create a new sidebar component using NSSplitViewController with native Liquid Glass
    fn createSidebar(self: *Self, data: []const u8) !void {
        // Edge case: Empty data
        if (data.len == 0) {
            std.debug.print("[NativeUI] ERROR: Empty data for createSidebar\n", .{});
            return error.EmptyData;
        }

        // Edge case: Missing window reference
        if (self.window == null) {
            std.debug.print("[NativeUI] WARNING: No window reference set. Sidebar will be created but not displayed.\n", .{});
        }

        std.debug.print("[NativeUI] Parsing JSON: {s}\n", .{data});

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, data, .{}) catch |err| {
            std.debug.print("[NativeUI] JSON parse error: {any}\n", .{err});
            return error.MalformedJSON;
        };
        defer parsed.deinit();

        const root = parsed.value.object;
        const id = root.get("id") orelse {
            std.debug.print("[NativeUI] ERROR: Missing 'id' field in createSidebar data\n", .{});
            return error.MissingRequiredField;
        };
        const id_str = id.string;

        // Check if a sidebar already exists
        if (self.sidebars.count() > 0) {
            std.debug.print("[NativeUI] WARNING: Sidebar already exists. Only one sidebar is supported. Ignoring request for: {s}\n", .{id_str});
            return;
        }

        std.debug.print("[LiquidGlass] Creating sidebar with NSSplitViewController: {s}\n", .{id_str});

        // Create sidebar
        const sidebar = try NativeSidebar.init(self.allocator);
        errdefer sidebar.deinit();

        // Store in registry
        const id_copy = try self.allocator.dupe(u8, id_str);
        try self.sidebars.put(id_copy, sidebar);

        // Add to window if we have window reference
        if (self.window) |window| {
            // Save the original webview (current content view)
            self.original_webview = macos.msgSend0(window, "contentView");
            std.debug.print("[LiquidGlass] Saved original webview: {*}\n", .{self.original_webview.?});

            // Create NSSplitViewController
            const split_vc = try NativeSplitViewController.init(self.allocator);
            self.split_view_controller = split_vc;

            // CRITICAL: Add sidebar FIRST (AppKit applies Liquid Glass automatically)
            try split_vc.setSidebar(sidebar.getView());
            std.debug.print("[LiquidGlass] ✓ Sidebar added with native Liquid Glass material\n", .{});

            // CRITICAL: Add content SECOND (extends full-width under sidebar)
            try split_vc.setContent(self.original_webview.?);
            std.debug.print("[LiquidGlass] ✓ Content extends under floating sidebar\n", .{});

            // Set split view controller as window's content view controller
            _ = macos.msgSend1(window, "setContentViewController:", split_vc.getSplitViewController());
            std.debug.print("[LiquidGlass] ✓ Set NSSplitViewController as window content view controller\n", .{});

            // CRITICAL: Reposition traffic lights to float over the sidebar (macOS Tahoe style)
            // The traffic lights should be 13px from the top of the window
            // With full-size content view, position them at 13px from top
            const traffic_light_y: f64 = 787.0; // 800 (window height) - 13

            const closeButton = macos.msgSend1(window, "standardWindowButton:", @as(c_ulong, 0));
            if (closeButton != null) {
                _ = macos.msgSend2(closeButton, "setFrameOrigin:", @as(f64, 13.0), traffic_light_y);
            }

            const miniButton = macos.msgSend1(window, "standardWindowButton:", @as(c_ulong, 1));
            if (miniButton != null) {
                _ = macos.msgSend2(miniButton, "setFrameOrigin:", @as(f64, 33.0), traffic_light_y);
            }

            const zoomButton = macos.msgSend1(window, "standardWindowButton:", @as(c_ulong, 2));
            if (zoomButton != null) {
                _ = macos.msgSend2(zoomButton, "setFrameOrigin:", @as(f64, 53.0), traffic_light_y);
            }

            std.debug.print("[LiquidGlass] ✓ Repositioned traffic lights over sidebar at y={d}\n", .{traffic_light_y});
            std.debug.print("[LiquidGlass] ✓ Native Liquid Glass sidebar created successfully\n", .{});
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

    /// Show a context menu at a specific position
    /// Expected JSON format:
    /// {
    ///   "targetId": "item-id",
    ///   "targetType": "sidebar" | "file",
    ///   "x": 100,
    ///   "y": 200,
    ///   "items": [
    ///     { "id": "open", "title": "Open", "icon": "arrow.up.forward.square", "shortcut": "cmd+o" },
    ///     { "id": "separator", "title": "", "type": "separator" },
    ///     { "id": "delete", "title": "Move to Trash", "icon": "trash" }
    ///   ]
    /// }
    fn showContextMenu(self: *Self, data: []const u8) !void {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, data, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const target_id = root.get("targetId").?.string;
        const target_type = root.get("targetType").?.string;

        // Get position
        const x = switch (root.get("x").?) {
            .integer => |i| @as(f64, @floatFromInt(i)),
            .float => |f| f,
            else => 0.0,
        };
        const y = switch (root.get("y").?) {
            .integer => |i| @as(f64, @floatFromInt(i)),
            .float => |f| f,
            else => 0.0,
        };

        // Clean up previous delegate if it exists
        if (self.active_context_menu_delegate) |prev_delegate| {
            prev_delegate.deinit();
            self.active_context_menu_delegate = null;
        }

        // Create new delegate
        const delegate = try context_menu.ContextMenuDelegate.init(self.allocator, target_id, target_type);
        self.active_context_menu_delegate = delegate;

        // Parse menu items
        const items_json = root.get("items").?.array;
        var items: std.ArrayList(context_menu.MenuItem) = .{};
        defer items.deinit(self.allocator);

        for (items_json.items) |item_json| {
            const item_obj = item_json.object;
            const item_type_str = if (item_obj.get("type")) |t| t.string else "standard";

            const item_type: context_menu.MenuItemType = if (std.mem.eql(u8, item_type_str, "separator"))
                .separator
            else if (std.mem.eql(u8, item_type_str, "submenu"))
                .submenu
            else
                .standard;

            try items.append(self.allocator, .{
                .id = item_obj.get("id").?.string,
                .title = item_obj.get("title").?.string,
                .icon = if (item_obj.get("icon")) |icon| icon.string else null,
                .shortcut = if (item_obj.get("shortcut")) |shortcut| shortcut.string else null,
                .enabled = if (item_obj.get("enabled")) |enabled| enabled.bool else true,
                .item_type = item_type,
                .submenu_items = null, // TODO: Support nested submenus
            });
        }

        // Create the menu
        const menu = try context_menu.createMenu(self.allocator, "", items.items, delegate);

        // Get the view to show the menu in
        var view: macos.objc.id = null;
        if (std.mem.eql(u8, target_type, "sidebar")) {
            // Use the sidebar's view
            var sidebar_iter = self.sidebars.valueIterator();
            if (sidebar_iter.next()) |sidebar| {
                view = sidebar.*.getView();
            }
        } else if (std.mem.eql(u8, target_type, "file")) {
            // Use the file browser's view
            var browser_iter = self.file_browsers.valueIterator();
            if (browser_iter.next()) |browser| {
                view = browser.*.getView();
            }
        }

        // Fallback to window's content view
        if (view == null) {
            if (self.window) |window| {
                view = macos.msgSend0(window, "contentView");
            }
        }

        if (view == null) {
            std.debug.print("[NativeUI] ERROR: No view available for context menu\n", .{});
            return error.NoViewAvailable;
        }

        // Show the menu
        context_menu.showContextMenu(menu, view, .{ .x = x, .y = y });
        std.debug.print("[NativeUI] ✓ Showed context menu for {s} '{s}' at ({d}, {d})\n", .{ target_type, target_id, x, y });
    }

    /// Show Quick Look panel for files
    /// Expected JSON format:
    /// {
    ///   "files": [
    ///     { "id": "file-1", "path": "/path/to/file.pdf", "title": "Document.pdf" },
    ///     { "id": "file-2", "path": "/path/to/image.png" }
    ///   ],
    ///   "currentIndex": 0  // Optional, defaults to 0
    /// }
    fn showQuickLook(self: *Self, data: []const u8) !void {
        // Check if Quick Look is available
        if (!quick_look.isQuickLookAvailable()) {
            std.debug.print("[NativeUI] ERROR: Quick Look is not available on this system\n", .{});
            return error.QuickLookNotAvailable;
        }

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, data, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const files_json = root.get("files").?.array;

        // Create or reuse Quick Look controller
        if (self.quick_look_controller == null) {
            self.quick_look_controller = try quick_look.QuickLookController.init(self.allocator);
        }

        const controller = self.quick_look_controller.?;

        // Clear existing items and add new ones
        controller.callback_data.clearItems();

        for (files_json.items) |file_json| {
            const file_obj = file_json.object;
            const file_id = file_obj.get("id").?.string;
            const file_path = file_obj.get("path").?.string;
            const file_title = if (file_obj.get("title")) |t| t.string else null;

            try controller.addPreviewItem(.{
                .id = file_id,
                .path = file_path,
                .title = file_title,
            });
        }

        // Set current index if provided
        if (root.get("currentIndex")) |idx| {
            const index: usize = switch (idx) {
                .integer => |i| @intCast(i),
                else => 0,
            };
            controller.setCurrentPreviewIndex(index);
        }

        // Show the panel
        controller.showPanel();
        std.debug.print("[NativeUI] ✓ Showed Quick Look with {d} files\n", .{files_json.items.len});
    }

    /// Close Quick Look panel
    fn closeQuickLook(self: *Self) void {
        if (self.quick_look_controller) |controller| {
            controller.closePanel();
            std.debug.print("[NativeUI] ✓ Closed Quick Look panel\n", .{});
        }
    }

    /// Toggle Quick Look panel (show/hide)
    /// Expected JSON format: same as showQuickLook
    fn toggleQuickLook(self: *Self, data: []const u8) !void {
        // Check if Quick Look is available
        if (!quick_look.isQuickLookAvailable()) {
            std.debug.print("[NativeUI] ERROR: Quick Look is not available on this system\n", .{});
            return error.QuickLookNotAvailable;
        }

        // If controller exists and panel is visible, close it
        if (self.quick_look_controller) |controller| {
            const QLPreviewPanel = macos.getClass("QLPreviewPanel");
            if (QLPreviewPanel != null) {
                const panel = macos.msgSend0(QLPreviewPanel, "sharedPreviewPanel");
                const isVisible = @as(
                    *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) bool,
                    @ptrCast(&macos.objc.objc_msgSend),
                );

                if (isVisible(panel, macos.sel("isVisible"))) {
                    controller.closePanel();
                    std.debug.print("[NativeUI] ✓ Toggled Quick Look OFF\n", .{});
                    return;
                }
            }
        }

        // Otherwise, show the panel with provided data
        try self.showQuickLook(data);
        std.debug.print("[NativeUI] ✓ Toggled Quick Look ON\n", .{});
    }
};
