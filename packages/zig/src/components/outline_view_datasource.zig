const std = @import("std");
const macos = @import("../macos.zig");

/// NSOutlineViewDataSource implementation in Zig
/// This creates a dynamic Objective-C class at runtime that implements the data source protocol
pub const OutlineViewDataSource = struct {
    objc_class: macos.objc.Class,
    instance: macos.objc.id,
    data: *DataStore,
    allocator: std.mem.Allocator,

    /// Data structure that holds the outline view hierarchy
    pub const DataStore = struct {
        sections: std.ArrayList(Section),
        allocator: std.mem.Allocator,

        pub const Section = struct {
            id: []const u8,
            header: ?[]const u8,
            items: std.ArrayList(Item),
            is_expanded: bool = true,

            pub const Item = struct {
                id: []const u8,
                label: []const u8,
                icon: ?[]const u8 = null,
                badge: ?[]const u8 = null,
            };
        };

        pub fn init(allocator: std.mem.Allocator) DataStore {
            return .{
                .sections = .{},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *DataStore) void {
            self.sections.deinit(self.allocator);
        }
    };

    /// Create a new data source with dynamic Objective-C class
    pub fn init(allocator: std.mem.Allocator) !OutlineViewDataSource {
        // Allocate data store
        const data = try allocator.create(DataStore);
        data.* = DataStore.init(allocator);

        // Create dynamic Objective-C class
        const NSObject = macos.getClass("NSObject");
        const class_name = "CraftOutlineViewDataSource";

        // Check if class already exists
        var objc_class = macos.objc.objc_getClass(class_name);
        if (objc_class == null) {
            // Allocate new class
            objc_class = macos.objc.objc_allocateClassPair(NSObject, class_name, 0);

            // Add required NSOutlineViewDataSource methods
            const outlineView_numberOfChildrenOfItem = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, macos.objc.id) callconv(.c) c_long,
                @ptrCast(&outlineViewNumberOfChildrenOfItem),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("outlineView:numberOfChildrenOfItem:"),
                @ptrCast(outlineView_numberOfChildrenOfItem),
                "l@:@@", // returns long, takes self, _cmd, outlineView, item
            );

            const outlineView_child_ofItem = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, c_long, macos.objc.id) callconv(.c) macos.objc.id,
                @ptrCast(&outlineViewChildOfItem),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("outlineView:child:ofItem:"),
                @ptrCast(outlineView_child_ofItem),
                "@@:@l@", // returns id, takes self, _cmd, outlineView, index, item
            );

            const outlineView_isItemExpandable = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, macos.objc.id) callconv(.c) c_int,
                @ptrCast(&outlineViewIsItemExpandable),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("outlineView:isItemExpandable:"),
                @ptrCast(outlineView_isItemExpandable),
                "c@:@@", // returns BOOL (char), takes self, _cmd, outlineView, item
            );

            const outlineView_objectValueForTableColumn_byItem = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, macos.objc.id, macos.objc.id) callconv(.c) macos.objc.id,
                @ptrCast(&outlineViewObjectValueForTableColumnByItem),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("outlineView:objectValueForTableColumn:byItem:"),
                @ptrCast(outlineView_objectValueForTableColumn_byItem),
                "@@:@@@", // returns id, takes self, _cmd, outlineView, column, item
            );

            // Register the class
            macos.objc.objc_registerClassPair(objc_class);
        }

        // Create instance
        const instance = macos.msgSend0(macos.msgSend0(objc_class.?, "alloc"), "init");

        // Store data pointer in associated object
        const data_ptr_value = @intFromPtr(data);
        const NSValue = macos.getClass("NSValue");
        const data_value = macos.msgSend1(
            NSValue,
            "valueWithPointer:",
            @as(?*anyopaque, @ptrFromInt(data_ptr_value)),
        );
        macos.objc.objc_setAssociatedObject(
            instance,
            @ptrFromInt(0x1234), // unique key
            data_value,
            macos.objc.OBJC_ASSOCIATION_RETAIN,
        );

        return .{
            .objc_class = objc_class.?,
            .instance = instance,
            .data = data,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *OutlineViewDataSource) void {
        self.data.deinit();
        self.allocator.destroy(self.data);
    }

    /// Get the Objective-C instance to set as data source
    pub fn getInstance(self: *OutlineViewDataSource) macos.objc.id {
        return self.instance;
    }
};

/// Helper to get data store from Objective-C instance
fn getDataStore(instance: macos.objc.id) ?*OutlineViewDataSource.DataStore {
    const associated = macos.objc.objc_getAssociatedObject(instance, @ptrFromInt(0x1234));
    if (associated == @as(macos.objc.id, null)) return null;

    const ptr = macos.msgSend0(associated, "pointerValue");
    if (@intFromPtr(ptr) == 0) return null;

    return @ptrCast(@alignCast(ptr));
}

/// NSOutlineViewDataSource method: numberOfChildrenOfItem
export fn outlineViewNumberOfChildrenOfItem(
    self: macos.objc.id,
    _: macos.objc.SEL,
    _: macos.objc.id, // outlineView
    item: macos.objc.id,
) callconv(.c) c_long {
    const data = getDataStore(self) orelse return 0;

    // If item is nil, return number of root items (sections)
    if (item == @as(macos.objc.id, null)) {
        return @intCast(data.sections.items.len);
    }

    // Otherwise, item is a section, return number of items in that section
    // We identify sections by their pointer address
    const item_ptr = @intFromPtr(item);
    for (data.sections.items) |*section| {
        const section_ptr = @intFromPtr(@as(*const anyopaque, @ptrCast(section)));
        if (item_ptr == section_ptr) {
            return @intCast(section.items.items.len);
        }
    }

    return 0;
}

/// NSOutlineViewDataSource method: child:ofItem
export fn outlineViewChildOfItem(
    self: macos.objc.id,
    _: macos.objc.SEL,
    _: macos.objc.id, // outlineView
    index: c_long,
    item: macos.objc.id,
) callconv(.c) macos.objc.id {
    const data = getDataStore(self) orelse return null;

    const idx: usize = @intCast(index);

    // If item is nil, return root item (section) at index
    if (item == @as(macos.objc.id, null)) {
        if (idx >= data.sections.items.len) return null;
        const section = &data.sections.items[idx];
        // Return section pointer as item identifier
        const section_ptr = @intFromPtr(@as(*const anyopaque, @ptrCast(section)));
        return @ptrFromInt(section_ptr);
    }

    // Otherwise, return child item at index within section
    const item_ptr = @intFromPtr(item);
    for (data.sections.items) |*section| {
        const section_ptr = @intFromPtr(@as(*const anyopaque, @ptrCast(section)));
        if (item_ptr == section_ptr) {
            if (idx >= section.items.items.len) return null;
            const child = &section.items.items[idx];
            const child_ptr = @intFromPtr(@as(*const anyopaque, @ptrCast(child)));
            return @ptrFromInt(child_ptr);
        }
    }

    return null;
}

/// NSOutlineViewDataSource method: isItemExpandable
export fn outlineViewIsItemExpandable(
    self: macos.objc.id,
    _: macos.objc.SEL,
    _: macos.objc.id, // outlineView
    item: macos.objc.id,
) callconv(.c) c_int {
    const data = getDataStore(self) orelse return 0;

    // Root items (nil) are not expandable
    if (item == @as(macos.objc.id, null)) return 0;

    // Check if item is a section (sections are expandable)
    const item_ptr = @intFromPtr(item);
    for (data.sections.items) |*section| {
        const section_ptr = @intFromPtr(@as(*const anyopaque, @ptrCast(section)));
        if (item_ptr == section_ptr) {
            return if (section.items.items.len > 0) 1 else 0;
        }
    }

    // Items are not expandable
    return 0;
}

/// NSOutlineViewDataSource method: objectValueForTableColumn:byItem
export fn outlineViewObjectValueForTableColumnByItem(
    self: macos.objc.id,
    _: macos.objc.SEL,
    _: macos.objc.id, // outlineView
    _: macos.objc.id, // tableColumn
    item: macos.objc.id,
) callconv(.c) macos.objc.id {
    const data = getDataStore(self) orelse return null;

    if (item == @as(macos.objc.id, null)) return null;

    const item_ptr = @intFromPtr(item);

    // Check if it's a section header
    for (data.sections.items) |*section| {
        const section_ptr = @intFromPtr(@as(*const anyopaque, @ptrCast(section)));
        if (item_ptr == section_ptr) {
            // Return section header text
            if (section.header) |header| {
                return macos.createNSString(header);
            }
            return macos.createNSString(section.id);
        }

        // Check if it's an item within this section
        for (section.items.items) |*child| {
            const child_ptr = @intFromPtr(@as(*const anyopaque, @ptrCast(child)));
            if (item_ptr == child_ptr) {
                // Return item label
                return macos.createNSString(child.label);
            }
        }
    }

    return null;
}
