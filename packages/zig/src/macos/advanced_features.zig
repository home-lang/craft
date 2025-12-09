const std = @import("std");
const objc = @import("../objc.zig");
const memory = @import("memory_management.zig");

// ============================================
// Drag and Drop Support
// ============================================

/// Drag operation type
pub const DragOperation = enum(u64) {
    none = 0,
    copy = 1,
    link = 2,
    generic = 4,
    private = 8,
    move = 16,
    delete = 32,
    every = std.math.maxInt(u64),
};

/// Dragging source handler
pub const DraggingSourceHandler = struct {
    const Self = @This();

    view: objc.id,
    delegate_class: ?objc.Class,
    delegate_instance: ?objc.id,

    allowed_operations: DragOperation,
    dragging_items: std.ArrayList(DraggingItem),
    allocator: std.mem.Allocator,

    on_drag_begin: ?*const fn (Self, objc.id) void,
    on_drag_moved: ?*const fn (Self, f64, f64) void,
    on_drag_ended: ?*const fn (Self, DragOperation) void,

    pub const DraggingItem = struct {
        pasteboard_type: [*:0]const u8,
        data: []const u8,
        image: ?objc.id,
    };

    pub fn init(view: objc.id, allocator: std.mem.Allocator) !Self {
        return Self{
            .view = view,
            .delegate_class = null,
            .delegate_instance = null,
            .allowed_operations = .copy,
            .dragging_items = std.ArrayList(DraggingItem).init(allocator),
            .allocator = allocator,
            .on_drag_begin = null,
            .on_drag_moved = null,
            .on_drag_ended = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.dragging_items.deinit();
        if (self.delegate_instance) |delegate| {
            const release_sel = objc.sel_registerName("release");
            _ = objc.objc_msgSend(delegate, release_sel);
        }
    }

    pub fn addItem(self: *Self, item: DraggingItem) !void {
        try self.dragging_items.append(item);
    }

    pub fn beginDragging(self: *Self, event: objc.id) void {
        const NSPasteboard = objc.objc_getClass("NSPasteboard") orelse return;
        const NSDraggingItem = objc.objc_getClass("NSDraggingItem") orelse return;

        // Get dragging pasteboard
        const pasteboard_sel = objc.sel_registerName("pasteboardWithName:");
        const drag_pboard_name = createNSString("NSDragPboard") orelse return;
        defer releaseObject(drag_pboard_name);

        const pasteboard = objc.objc_msgSend(NSPasteboard, pasteboard_sel, drag_pboard_name);
        if (pasteboard == null) return;

        // Clear pasteboard
        const clear_sel = objc.sel_registerName("clearContents");
        _ = objc.objc_msgSend(pasteboard, clear_sel);

        // Create dragging items array
        const NSMutableArray = objc.objc_getClass("NSMutableArray") orelse return;
        const array = objc.objc_msgSend(objc.objc_msgSend(NSMutableArray, objc.sel_registerName("alloc")), objc.sel_registerName("init"));
        if (array == null) return;
        defer releaseObject(array);

        // Add items to array
        for (self.dragging_items.items) |item| {
            const pasteboard_item = objc.objc_msgSend(
                objc.objc_msgSend(NSDraggingItem, objc.sel_registerName("alloc")),
                objc.sel_registerName("initWithPasteboardWriter:"),
                createPasteboardItem(item),
            );
            if (pasteboard_item != null) {
                _ = objc.objc_msgSend(array, objc.sel_registerName("addObject:"), pasteboard_item);
            }
        }

        // Begin dragging session
        const begin_sel = objc.sel_registerName("beginDraggingSessionWithItems:event:source:");
        _ = objc.objc_msgSend(self.view, begin_sel, array, event, self.delegate_instance);

        if (self.on_drag_begin) |callback| {
            callback(self.*, event);
        }
    }

    fn createPasteboardItem(item: DraggingItem) ?objc.id {
        const NSPasteboardItem = objc.objc_getClass("NSPasteboardItem") orelse return null;

        const pb_item = objc.objc_msgSend(
            objc.objc_msgSend(NSPasteboardItem, objc.sel_registerName("alloc")),
            objc.sel_registerName("init"),
        );
        if (pb_item == null) return null;

        // Set data for type
        const type_str = createNSString(item.pasteboard_type) orelse return null;
        defer releaseObject(type_str);

        const data = createNSData(item.data) orelse return null;
        defer releaseObject(data);

        const set_sel = objc.sel_registerName("setData:forType:");
        _ = objc.objc_msgSend(pb_item, set_sel, data, type_str);

        return pb_item;
    }
};

/// Dragging destination handler
pub const DraggingDestinationHandler = struct {
    const Self = @This();

    view: objc.id,
    registered_types: std.ArrayList([*:0]const u8),
    allocator: std.mem.Allocator,

    on_drag_entered: ?*const fn (Self, objc.id) DragOperation,
    on_drag_updated: ?*const fn (Self, objc.id) DragOperation,
    on_drag_exited: ?*const fn (Self) void,
    on_perform_drag: ?*const fn (Self, objc.id) bool,

    pub fn init(view: objc.id, allocator: std.mem.Allocator) Self {
        return Self{
            .view = view,
            .registered_types = std.ArrayList([*:0]const u8).init(allocator),
            .allocator = allocator,
            .on_drag_entered = null,
            .on_drag_updated = null,
            .on_drag_exited = null,
            .on_perform_drag = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.registered_types.deinit();
    }

    pub fn registerForDraggedTypes(self: *Self, types: []const [*:0]const u8) !void {
        for (types) |t| {
            try self.registered_types.append(t);
        }

        // Register with the view
        const NSMutableArray = objc.objc_getClass("NSMutableArray") orelse return;
        const array = objc.objc_msgSend(
            objc.objc_msgSend(NSMutableArray, objc.sel_registerName("alloc")),
            objc.sel_registerName("init"),
        );
        if (array == null) return;
        defer releaseObject(array);

        for (types) |t| {
            const str = createNSString(t) orelse continue;
            _ = objc.objc_msgSend(array, objc.sel_registerName("addObject:"), str);
            releaseObject(str);
        }

        const register_sel = objc.sel_registerName("registerForDraggedTypes:");
        _ = objc.objc_msgSend(self.view, register_sel, array);
    }

    pub fn unregisterDraggedTypes(self: *Self) void {
        const unregister_sel = objc.sel_registerName("unregisterDraggedTypes");
        _ = objc.objc_msgSend(self.view, unregister_sel);
        self.registered_types.clearRetainingCapacity();
    }
};

// ============================================
// Context Menus (NSMenu)
// ============================================

/// Menu item configuration
pub const MenuItemConfig = struct {
    title: [*:0]const u8,
    action: ?objc.SEL = null,
    key_equivalent: [*:0]const u8 = "",
    tag: i64 = 0,
    enabled: bool = true,
    state: MenuItemState = .off,
    submenu: ?*const Menu = null,
    is_separator: bool = false,
    image: ?objc.id = null,
};

pub const MenuItemState = enum(i64) {
    off = 0,
    on = 1,
    mixed = -1,
};

/// Menu builder
pub const Menu = struct {
    const Self = @This();

    title: [*:0]const u8,
    items: std.ArrayList(MenuItemConfig),
    ns_menu: ?objc.id,
    allocator: std.mem.Allocator,

    pub fn init(title: [*:0]const u8, allocator: std.mem.Allocator) Self {
        return Self{
            .title = title,
            .items = std.ArrayList(MenuItemConfig).init(allocator),
            .ns_menu = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.items.deinit();
        if (self.ns_menu) |menu| {
            releaseObject(menu);
        }
    }

    pub fn addItem(self: *Self, config: MenuItemConfig) !void {
        try self.items.append(config);
    }

    pub fn addSeparator(self: *Self) !void {
        try self.items.append(.{
            .title = "",
            .is_separator = true,
        });
    }

    pub fn build(self: *Self) ?objc.id {
        const NSMenu = objc.objc_getClass("NSMenu") orelse return null;
        const NSMenuItem = objc.objc_getClass("NSMenuItem") orelse return null;

        // Create menu
        const title_str = createNSString(self.title) orelse return null;
        defer releaseObject(title_str);

        const menu = objc.objc_msgSend(
            objc.objc_msgSend(NSMenu, objc.sel_registerName("alloc")),
            objc.sel_registerName("initWithTitle:"),
            title_str,
        );
        if (menu == null) return null;

        // Add items
        for (self.items.items) |item_config| {
            const menu_item: objc.id = if (item_config.is_separator)
                objc.objc_msgSend(NSMenuItem, objc.sel_registerName("separatorItem"))
            else blk: {
                const item_title = createNSString(item_config.title) orelse continue;
                defer releaseObject(item_title);

                const key_equiv = createNSString(item_config.key_equivalent) orelse continue;
                defer releaseObject(key_equiv);

                const mi = objc.objc_msgSend(
                    objc.objc_msgSend(NSMenuItem, objc.sel_registerName("alloc")),
                    objc.sel_registerName("initWithTitle:action:keyEquivalent:"),
                    item_title,
                    item_config.action,
                    key_equiv,
                );

                if (mi != null) {
                    // Set properties
                    _ = objc.objc_msgSend(mi, objc.sel_registerName("setTag:"), item_config.tag);
                    _ = objc.objc_msgSend(mi, objc.sel_registerName("setEnabled:"), @as(i8, if (item_config.enabled) 1 else 0));
                    _ = objc.objc_msgSend(mi, objc.sel_registerName("setState:"), @intFromEnum(item_config.state));

                    if (item_config.image) |img| {
                        _ = objc.objc_msgSend(mi, objc.sel_registerName("setImage:"), img);
                    }

                    // Handle submenu
                    if (item_config.submenu) |submenu| {
                        var sub = @constCast(submenu);
                        if (sub.build()) |sub_menu| {
                            _ = objc.objc_msgSend(mi, objc.sel_registerName("setSubmenu:"), sub_menu);
                        }
                    }
                }

                break :blk mi;
            };

            if (menu_item != null) {
                _ = objc.objc_msgSend(menu, objc.sel_registerName("addItem:"), menu_item);
            }
        }

        self.ns_menu = menu;
        return menu;
    }

    /// Show as context menu at location
    pub fn showAtLocation(self: *Self, view: objc.id, x: f64, y: f64) void {
        const menu = self.ns_menu orelse self.build() orelse return;

        // Create NSPoint
        const NSEvent = objc.objc_getClass("NSEvent") orelse return;

        // Pop up menu
        const popup_sel = objc.sel_registerName("popUpContextMenu:withEvent:forView:");
        const NSMenu = objc.objc_getClass("NSMenu") orelse return;

        // Get current event or create one
        const NSApp = objc.objc_getClass("NSApplication") orelse return;
        const shared_sel = objc.sel_registerName("sharedApplication");
        const app = objc.objc_msgSend(NSApp, shared_sel);

        const event_sel = objc.sel_registerName("currentEvent");
        const event = objc.objc_msgSend(app, event_sel);

        _ = objc.objc_msgSend(NSMenu, popup_sel, menu, event, view);

        _ = x;
        _ = y;
        _ = NSEvent;
    }
};

// ============================================
// Quick Look Support (QLPreviewPanel)
// ============================================

/// Quick Look preview item
pub const QuickLookItem = struct {
    url: [*:0]const u8,
    title: ?[*:0]const u8 = null,
};

/// Quick Look controller
pub const QuickLookController = struct {
    const Self = @This();

    items: std.ArrayList(QuickLookItem),
    current_index: usize,
    delegate_class: ?objc.Class,
    delegate_instance: ?objc.id,
    data_source_class: ?objc.Class,
    data_source_instance: ?objc.id,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Self {
        var self = Self{
            .items = std.ArrayList(QuickLookItem).init(allocator),
            .current_index = 0,
            .delegate_class = null,
            .delegate_instance = null,
            .data_source_class = null,
            .data_source_instance = null,
            .allocator = allocator,
        };

        try self.setupDelegateClass();
        try self.setupDataSourceClass();

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.items.deinit();
        if (self.delegate_instance) |delegate| {
            releaseObject(delegate);
        }
        if (self.data_source_instance) |ds| {
            releaseObject(ds);
        }
    }

    fn setupDelegateClass(self: *Self) !void {
        const NSObject = objc.objc_getClass("NSObject") orelse return error.ClassNotFound;

        var builder = try memory.DynamicClassBuilder.create("CraftQLPreviewPanelDelegate", NSObject);

        // Add QLPreviewPanelDelegate methods
        try builder.addMethod(
            objc.sel_registerName("previewPanel:handleEvent:"),
            @ptrCast(&handleEvent),
            "c@:@@",
        );

        builder.register();
        self.delegate_class = builder.class;

        // Create instance
        self.delegate_instance = objc.objc_msgSend(
            objc.objc_msgSend(builder.class, objc.sel_registerName("alloc")),
            objc.sel_registerName("init"),
        );
    }

    fn setupDataSourceClass(self: *Self) !void {
        const NSObject = objc.objc_getClass("NSObject") orelse return error.ClassNotFound;

        var builder = try memory.DynamicClassBuilder.create("CraftQLPreviewPanelDataSource", NSObject);

        // Add QLPreviewPanelDataSource methods
        try builder.addMethod(
            objc.sel_registerName("numberOfPreviewItemsInPreviewPanel:"),
            @ptrCast(&numberOfItems),
            "q@:@",
        );

        try builder.addMethod(
            objc.sel_registerName("previewPanel:previewItemAtIndex:"),
            @ptrCast(&previewItemAtIndex),
            "@@:@q",
        );

        builder.register();
        self.data_source_class = builder.class;

        // Create instance and store self pointer
        self.data_source_instance = objc.objc_msgSend(
            objc.objc_msgSend(builder.class, objc.sel_registerName("alloc")),
            objc.sel_registerName("init"),
        );

        // Store self reference
        if (self.data_source_instance) |instance| {
            memory.setAssociatedObject(
                instance,
                memory.AssociatedObjectKeys.ZigPointer,
                @ptrCast(@alignCast(self)),
                .retain_nonatomic,
            );
        }
    }

    fn handleEvent(_: objc.id, _: objc.SEL, _: objc.id, _: objc.id) callconv(.c) i8 {
        return 0; // Not handled
    }

    fn numberOfItems(instance: objc.id, _: objc.SEL, _: objc.id) callconv(.c) i64 {
        const self_ptr = memory.getAssociatedObject(instance, memory.AssociatedObjectKeys.ZigPointer);
        if (self_ptr) |ptr| {
            const self: *Self = @ptrCast(@alignCast(ptr));
            return @intCast(self.items.items.len);
        }
        return 0;
    }

    fn previewItemAtIndex(instance: objc.id, _: objc.SEL, _: objc.id, index: i64) callconv(.c) ?objc.id {
        const self_ptr = memory.getAssociatedObject(instance, memory.AssociatedObjectKeys.ZigPointer);
        if (self_ptr) |ptr| {
            const self: *Self = @ptrCast(@alignCast(ptr));
            const idx: usize = @intCast(index);
            if (idx < self.items.items.len) {
                return self.createPreviewItem(self.items.items[idx]);
            }
        }
        return null;
    }

    fn createPreviewItem(self: *Self, item: QuickLookItem) ?objc.id {
        _ = self;
        const NSURL = objc.objc_getClass("NSURL") orelse return null;

        const path_str = createNSString(item.url) orelse return null;
        defer releaseObject(path_str);

        const url = objc.objc_msgSend(NSURL, objc.sel_registerName("fileURLWithPath:"), path_str);
        return url;
    }

    pub fn addItem(self: *Self, item: QuickLookItem) !void {
        try self.items.append(item);
    }

    pub fn clearItems(self: *Self) void {
        self.items.clearRetainingCapacity();
    }

    pub fn show(self: *Self) void {
        const QLPreviewPanel = objc.objc_getClass("QLPreviewPanel") orelse return;

        // Get shared panel
        const shared_sel = objc.sel_registerName("sharedPreviewPanel");
        const panel = objc.objc_msgSend(QLPreviewPanel, shared_sel);
        if (panel == null) return;

        // Set data source and delegate
        if (self.data_source_instance) |ds| {
            _ = objc.objc_msgSend(panel, objc.sel_registerName("setDataSource:"), ds);
        }
        if (self.delegate_instance) |delegate| {
            _ = objc.objc_msgSend(panel, objc.sel_registerName("setDelegate:"), delegate);
        }

        // Set current index
        _ = objc.objc_msgSend(panel, objc.sel_registerName("setCurrentPreviewItemIndex:"), @as(i64, @intCast(self.current_index)));

        // Show panel
        _ = objc.objc_msgSend(panel, objc.sel_registerName("makeKeyAndOrderFront:"), @as(?objc.id, null));
    }

    pub fn hide(self: *Self) void {
        _ = self;
        const QLPreviewPanel = objc.objc_getClass("QLPreviewPanel") orelse return;

        const shared_sel = objc.sel_registerName("sharedPreviewPanel");
        const panel = objc.objc_msgSend(QLPreviewPanel, shared_sel);
        if (panel == null) return;

        _ = objc.objc_msgSend(panel, objc.sel_registerName("orderOut:"), @as(?objc.id, null));
    }

    pub fn refresh(self: *Self) void {
        _ = self;
        const QLPreviewPanel = objc.objc_getClass("QLPreviewPanel") orelse return;

        const shared_sel = objc.sel_registerName("sharedPreviewPanel");
        const panel = objc.objc_msgSend(QLPreviewPanel, shared_sel);
        if (panel == null) return;

        _ = objc.objc_msgSend(panel, objc.sel_registerName("reloadData"));
    }

    pub fn setCurrentIndex(self: *Self, index: usize) void {
        self.current_index = index;

        const QLPreviewPanel = objc.objc_getClass("QLPreviewPanel") orelse return;
        const shared_sel = objc.sel_registerName("sharedPreviewPanel");
        const panel = objc.objc_msgSend(QLPreviewPanel, shared_sel);
        if (panel == null) return;

        _ = objc.objc_msgSend(panel, objc.sel_registerName("setCurrentPreviewItemIndex:"), @as(i64, @intCast(index)));
    }
};

// ============================================
// Helper Functions
// ============================================

fn createNSString(str: [*:0]const u8) ?objc.id {
    const NSString = objc.objc_getClass("NSString") orelse return null;
    const sel = objc.sel_registerName("stringWithUTF8String:");
    return objc.objc_msgSend(NSString, sel, str);
}

fn createNSData(data: []const u8) ?objc.id {
    const NSData = objc.objc_getClass("NSData") orelse return null;
    const sel = objc.sel_registerName("dataWithBytes:length:");
    return objc.objc_msgSend(NSData, sel, data.ptr, data.len);
}

fn releaseObject(obj: objc.id) void {
    const sel = objc.sel_registerName("release");
    _ = objc.objc_msgSend(obj, sel);
}

// Tests
test "Menu creation" {
    var menu = Menu.init("Test Menu", std.testing.allocator);
    defer menu.deinit();

    try menu.addItem(.{ .title = "Item 1", .key_equivalent = "a" });
    try menu.addSeparator();
    try menu.addItem(.{ .title = "Item 2", .enabled = false });

    try std.testing.expectEqual(@as(usize, 3), menu.items.items.len);
}

test "QuickLookController item management" {
    // Note: Full test requires macOS runtime
    // This tests basic item management
    var items = std.ArrayList(QuickLookItem).init(std.testing.allocator);
    defer items.deinit();

    try items.append(.{ .url = "/path/to/file.pdf" });
    try items.append(.{ .url = "/path/to/image.png", .title = "Image" });

    try std.testing.expectEqual(@as(usize, 2), items.items.len);
}
