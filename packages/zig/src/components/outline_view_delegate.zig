const std = @import("std");
const macos = @import("../macos.zig");

/// NSOutlineViewDelegate implementation in Zig
/// Handles cell views, selection, and user interactions
pub const OutlineViewDelegate = struct {
    objc_class: macos.objc.Class,
    instance: macos.objc.id,
    callback_data: *CallbackData,
    allocator: std.mem.Allocator,

    pub const CallbackData = struct {
        on_select: ?*const fn (item_id: []const u8) void = null,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) CallbackData {
            return .{ .allocator = allocator };
        }
    };

    pub fn init(allocator: std.mem.Allocator) !OutlineViewDelegate {
        const callback_data = try allocator.create(CallbackData);
        callback_data.* = CallbackData.init(allocator);

        const NSObject = macos.getClass("NSObject");
        const class_name = "CraftOutlineViewDelegate";

        var objc_class = macos.objc.objc_getClass(class_name);
        if (objc_class == null) {
            objc_class = macos.objc.objc_allocateClassPair(NSObject, class_name, 0);

            // Add outlineView:viewForTableColumn:item: for view-based rendering
            const viewForTableColumn = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, macos.objc.id, macos.objc.id) callconv(.c) macos.objc.id,
                @ptrCast(&outlineViewViewForTableColumnItem),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("outlineView:viewForTableColumn:item:"),
                @ptrCast(viewForTableColumn),
                "@@:@@@",
            );

            // Add outlineView:shouldSelectItem:
            const shouldSelectItem = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, macos.objc.id) callconv(.c) c_int,
                @ptrCast(&outlineViewShouldSelectItem),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("outlineView:shouldSelectItem:"),
                @ptrCast(shouldSelectItem),
                "c@:@@",
            );

            // Add outlineViewSelectionDidChange:
            const selectionDidChange = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id) callconv(.c) void,
                @ptrCast(&outlineViewSelectionDidChange),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("outlineViewSelectionDidChange:"),
                @ptrCast(selectionDidChange),
                "v@:@",
            );

            // Add outlineView:heightOfRowByItem:
            const heightOfRowByItem = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, macos.objc.id) callconv(.c) f64,
                @ptrCast(&outlineViewHeightOfRowByItem),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("outlineView:heightOfRowByItem:"),
                @ptrCast(heightOfRowByItem),
                "d@:@@",
            );

            macos.objc.objc_registerClassPair(objc_class);
        }

        const instance = macos.msgSend0(macos.msgSend0(objc_class.?, "alloc"), "init");

        // Store callback data pointer
        const data_ptr_value = @intFromPtr(callback_data);
        const NSValue = macos.getClass("NSValue");
        const data_value = macos.msgSend1(
            NSValue,
            "valueWithPointer:",
            @as(?*anyopaque, @ptrFromInt(data_ptr_value)),
        );
        macos.objc.objc_setAssociatedObject(
            instance,
            @ptrFromInt(0x9ABC), // unique key
            data_value,
            macos.objc.OBJC_ASSOCIATION_RETAIN,
        );

        return .{
            .objc_class = objc_class.?,
            .instance = instance,
            .callback_data = callback_data,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *OutlineViewDelegate) void {
        self.allocator.destroy(self.callback_data);
    }

    pub fn getInstance(self: *OutlineViewDelegate) macos.objc.id {
        return self.instance;
    }

    pub fn setOnSelectCallback(self: *OutlineViewDelegate, callback: *const fn (item_id: []const u8) void) void {
        self.callback_data.on_select = callback;
    }
};

fn getCallbackData(instance: macos.objc.id) ?*OutlineViewDelegate.CallbackData {
    const associated = macos.objc.objc_getAssociatedObject(instance, @ptrFromInt(0x9ABC));
    if (associated == @as(macos.objc.id, null)) return null;

    const ptr = macos.msgSend0(associated, "pointerValue");
    if (@intFromPtr(ptr) == 0) return null;

    return @ptrCast(@alignCast(ptr));
}

/// Create a simple text field view
/// We use NSTextField directly instead of NSTableCellView to avoid AutoLayout issues
fn createSimpleTextField(text: []const u8) macos.objc.id {
    const NSTextField = macos.getClass("NSTextField");

    // Create label-style text field (non-editable, non-selectable)
    const nsString = macos.createNSString(text);
    const textField = macos.msgSend1(NSTextField, "labelWithString:", nsString);

    // Set font
    const NSFont = macos.getClass("NSFont");
    const font = macos.msgSend1(NSFont, "systemFontOfSize:", @as(f64, 13.0));
    _ = macos.msgSend1(textField, "setFont:", font);

    // Disable autoresizing to prevent AutoLayout conflicts
    _ = macos.msgSend1(textField, "setTranslatesAutoresizingMaskIntoConstraints:", @as(c_int, 1));

    return textField;
}

/// NSOutlineViewDelegate method: viewForTableColumn:item
export fn outlineViewViewForTableColumnItem(
    _: macos.objc.id, // self
    _: macos.objc.SEL,
    outlineView: macos.objc.id,
    _: macos.objc.id, // tableColumn
    item: macos.objc.id,
) callconv(.c) macos.objc.id {
    if (item == @as(macos.objc.id, null)) return null;

    // Get the text value from the data source
    const dataSource = macos.msgSend0(outlineView, "dataSource");
    if (dataSource == @as(macos.objc.id, null)) return null;

    const objectValue = macos.msgSend3(
        dataSource,
        "outlineView:objectValueForTableColumn:byItem:",
        outlineView,
        @as(macos.objc.id, null),
        item,
    );

    if (objectValue == @as(macos.objc.id, null)) return null;

    // Convert NSString to C string
    const cstr = macos.msgSend0(objectValue, "UTF8String");
    if (@intFromPtr(cstr) == 0) return null;

    const text: [*:0]const u8 = @ptrCast(cstr);
    const text_slice = std.mem.span(text);

    // Create simple text field view
    return createSimpleTextField(text_slice);
}

/// NSOutlineViewDelegate method: shouldSelectItem
export fn outlineViewShouldSelectItem(
    _: macos.objc.id, // self
    _: macos.objc.SEL,
    _: macos.objc.id, // outlineView
    _: macos.objc.id, // item
) callconv(.c) c_int {
    // Allow all items to be selected
    return 1;
}

/// NSOutlineViewDelegate method: selectionDidChange
export fn outlineViewSelectionDidChange(
    self: macos.objc.id,
    _: macos.objc.SEL,
    notification: macos.objc.id,
) callconv(.c) void {
    const callback_data = getCallbackData(self) orelse return;

    // Get the outline view from notification
    const outlineView = macos.msgSend0(notification, "object");
    if (outlineView == @as(macos.objc.id, null)) return;

    // Get selected row
    const selectedRow = macos.msgSend0(outlineView, "selectedRow");
    const row: c_long = @intCast(@intFromPtr(selectedRow));

    if (row < 0) return;

    // Get the item at the selected row
    const item = macos.msgSend1(outlineView, "itemAtRow:", row);
    if (item == @as(macos.objc.id, null)) return;

    // Get item label from data source
    const dataSource = macos.msgSend0(outlineView, "dataSource");
    if (dataSource == @as(macos.objc.id, null)) return;

    const objectValue = macos.msgSend3(
        dataSource,
        "outlineView:objectValueForTableColumn:byItem:",
        outlineView,
        @as(macos.objc.id, null),
        item,
    );

    if (objectValue == @as(macos.objc.id, null)) return;

    // Convert to C string
    const cstr = macos.msgSend0(objectValue, "UTF8String");
    if (@intFromPtr(cstr) == 0) return;

    const item_id: [*:0]const u8 = @ptrCast(cstr);
    const item_id_slice = std.mem.span(item_id);

    // Call the callback if set
    if (callback_data.on_select) |callback| {
        callback(item_id_slice);
    }
}

/// NSOutlineViewDelegate method: heightOfRowByItem
export fn outlineViewHeightOfRowByItem(
    _: macos.objc.id, // self
    _: macos.objc.SEL,
    outlineView: macos.objc.id,
    item: macos.objc.id,
) callconv(.c) f64 {
    // Check if item is a group/header (parent) or regular item (child)
    const isExpandable = macos.msgSend1(outlineView, "isExpandable:", item);
    const expandable: c_int = @intCast(@intFromPtr(isExpandable));

    // Headers are shorter (20px), items are taller (24px)
    return if (expandable != 0) 20.0 else 24.0;
}
