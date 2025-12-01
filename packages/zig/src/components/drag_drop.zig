const std = @import("std");
const macos = @import("../macos.zig");

/// Drag and Drop support for native UI components
/// Implements NSDraggingSource and NSDraggingDestination protocols

/// Use NSPoint as CGPoint (they're the same on macOS)
pub const CGPoint = macos.NSPoint;

/// Pasteboard type for internal drag operations
pub const CraftDragType = "com.craft.drag.item";

/// Drag operation masks
pub const DragOperation = struct {
    pub const None: c_ulong = 0;
    pub const Copy: c_ulong = 1;
    pub const Link: c_ulong = 2;
    pub const Generic: c_ulong = 4;
    pub const Private: c_ulong = 8;
    pub const Move: c_ulong = 16;
    pub const Delete: c_ulong = 32;
    pub const Every: c_ulong = 0xFFFFFFFF;
};

/// Drag session info stored during drag operations
pub const DragSession = struct {
    source_id: []const u8,
    item_ids: std.ArrayList([]const u8),
    operation: c_ulong,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, source_id: []const u8) !*DragSession {
        const session = try allocator.create(DragSession);
        session.* = .{
            .source_id = try allocator.dupe(u8, source_id),
            .item_ids = std.ArrayList([]const u8).init(allocator),
            .operation = DragOperation.None,
            .allocator = allocator,
        };
        return session;
    }

    pub fn deinit(self: *DragSession) void {
        self.allocator.free(self.source_id);
        for (self.item_ids.items) |id| {
            self.allocator.free(id);
        }
        self.item_ids.deinit();
        self.allocator.destroy(self);
    }

    pub fn addItem(self: *DragSession, item_id: []const u8) !void {
        const id_copy = try self.allocator.dupe(u8, item_id);
        try self.item_ids.append(id_copy);
    }
};

/// Dragging source delegate for table/outline views
pub const DraggingSourceDelegate = struct {
    objc_class: macos.objc.Class,
    instance: macos.objc.id,
    callback_data: *CallbackData,
    allocator: std.mem.Allocator,

    pub const CallbackData = struct {
        on_drag_begin: ?*const fn (item_ids: []const []const u8) void = null,
        on_drag_end: ?*const fn (operation: c_ulong) void = null,
        current_session: ?*DragSession = null,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) CallbackData {
            return .{ .allocator = allocator };
        }
    };

    pub fn init(allocator: std.mem.Allocator) !*DraggingSourceDelegate {
        const callback_data = try allocator.create(CallbackData);
        callback_data.* = CallbackData.init(allocator);

        const NSObject = macos.getClass("NSObject");
        const class_name = "CraftDraggingSourceDelegate";

        var objc_class = macos.objc.objc_getClass(class_name);
        if (objc_class == null) {
            objc_class = macos.objc.objc_allocateClassPair(NSObject, class_name, 0);

            // draggingSession:sourceOperationMaskForDraggingContext:
            const sourceOperationMask = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, c_long) callconv(.c) c_ulong,
                @ptrCast(@constCast(&draggingSessionSourceOperationMask)),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("draggingSession:sourceOperationMaskForDraggingContext:"),
                @ptrCast(@constCast(sourceOperationMask)),
                "Q@:@q",
            );

            // draggingSession:willBeginAtPoint:
            const willBegin = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, CGPoint) callconv(.c) void,
                @ptrCast(@constCast(&draggingSessionWillBegin)),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("draggingSession:willBeginAtPoint:"),
                @ptrCast(@constCast(willBegin)),
                "v@:@{CGPoint=dd}",
            );

            // draggingSession:endedAtPoint:operation:
            const ended = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, CGPoint, c_ulong) callconv(.c) void,
                @ptrCast(@constCast(&draggingSessionEnded)),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("draggingSession:endedAtPoint:operation:"),
                @ptrCast(@constCast(ended)),
                "v@:@{CGPoint=dd}Q",
            );

            macos.objc.objc_registerClassPair(objc_class);
        }

        const instance = macos.msgSend0(macos.msgSend0(objc_class.?, "alloc"), "init");

        // Store callback data
        const data_ptr_value = @intFromPtr(callback_data);
        const NSValue = macos.getClass("NSValue");
        const data_value = macos.msgSend1(
            NSValue,
            "valueWithPointer:",
            @as(?*anyopaque, @ptrFromInt(data_ptr_value)),
        );
        macos.objc.objc_setAssociatedObject(
            instance,
            @ptrFromInt(0xDRAG),
            data_value,
            macos.objc.OBJC_ASSOCIATION_RETAIN,
        );

        const delegate = try allocator.create(DraggingSourceDelegate);
        delegate.* = .{
            .objc_class = objc_class.?,
            .instance = instance,
            .callback_data = callback_data,
            .allocator = allocator,
        };
        return delegate;
    }

    pub fn deinit(self: *DraggingSourceDelegate) void {
        if (self.callback_data.current_session) |session| {
            session.deinit();
        }
        if (self.instance != @as(macos.objc.id, null)) {
            _ = macos.msgSend0(self.instance, "release");
        }
        self.allocator.destroy(self.callback_data);
        self.allocator.destroy(self);
    }

    pub fn getInstance(self: *DraggingSourceDelegate) macos.objc.id {
        return self.instance;
    }

    pub fn setOnDragBeginCallback(self: *DraggingSourceDelegate, callback: *const fn ([]const []const u8) void) void {
        self.callback_data.on_drag_begin = callback;
    }

    pub fn setOnDragEndCallback(self: *DraggingSourceDelegate, callback: *const fn (c_ulong) void) void {
        self.callback_data.on_drag_end = callback;
    }
};

fn getDraggingCallbackData(instance: macos.objc.id) ?*DraggingSourceDelegate.CallbackData {
    const associated = macos.objc.objc_getAssociatedObject(instance, @ptrFromInt(0xDRAG));
    if (associated == @as(macos.objc.id, null)) return null;

    const ptr = macos.msgSend0(associated, "pointerValue");
    if (@intFromPtr(ptr) == 0) return null;

    return @ptrCast(@alignCast(ptr));
}

/// NSDraggingSource method: sourceOperationMaskForDraggingContext
export fn draggingSessionSourceOperationMask(
    _: macos.objc.id,
    _: macos.objc.SEL,
    _: macos.objc.id, // session
    context: c_long,
) callconv(.c) c_ulong {
    // context: 0 = withinApplication, 1 = outsideApplication
    if (context == 0) {
        // Within app: allow move, copy
        return DragOperation.Move | DragOperation.Copy;
    } else {
        // Outside app: allow copy only
        return DragOperation.Copy;
    }
}

/// NSDraggingSource method: willBeginAtPoint
export fn draggingSessionWillBegin(
    self: macos.objc.id,
    _: macos.objc.SEL,
    _: macos.objc.id, // session
    _: CGPoint, // point
) callconv(.c) void {
    const callback_data = getDraggingCallbackData(self) orelse return;

    if (callback_data.on_drag_begin) |callback| {
        if (callback_data.current_session) |session| {
            callback(session.item_ids.items);
        }
    }

    std.debug.print("[DragDrop] Drag session began\n", .{});
}

/// NSDraggingSource method: endedAtPoint:operation
export fn draggingSessionEnded(
    self: macos.objc.id,
    _: macos.objc.SEL,
    _: macos.objc.id, // session
    _: CGPoint, // point
    operation: c_ulong,
) callconv(.c) void {
    const callback_data = getDraggingCallbackData(self) orelse return;

    if (callback_data.on_drag_end) |callback| {
        callback(operation);
    }

    // Clean up session
    if (callback_data.current_session) |session| {
        session.deinit();
        callback_data.current_session = null;
    }

    std.debug.print("[DragDrop] Drag session ended with operation: {d}\n", .{operation});
}

/// Dragging destination delegate for drop targets
pub const DraggingDestinationDelegate = struct {
    objc_class: macos.objc.Class,
    instance: macos.objc.id,
    callback_data: *DestinationCallbackData,
    allocator: std.mem.Allocator,

    pub const DestinationCallbackData = struct {
        on_drag_enter: ?*const fn () c_ulong = null,
        on_drag_updated: ?*const fn (point: CGPoint) c_ulong = null,
        on_drop: ?*const fn (item_ids: []const []const u8, point: CGPoint) bool = null,
        on_drag_exit: ?*const fn () void = null,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) DestinationCallbackData {
            return .{ .allocator = allocator };
        }
    };

    pub fn init(allocator: std.mem.Allocator) !*DraggingDestinationDelegate {
        const callback_data = try allocator.create(DestinationCallbackData);
        callback_data.* = DestinationCallbackData.init(allocator);

        const NSObject = macos.getClass("NSObject");
        const class_name = "CraftDraggingDestinationDelegate";

        var objc_class = macos.objc.objc_getClass(class_name);
        if (objc_class == null) {
            objc_class = macos.objc.objc_allocateClassPair(NSObject, class_name, 0);

            // draggingEntered:
            const entered = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id) callconv(.c) c_ulong,
                @ptrCast(@constCast(&draggingEntered)),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("draggingEntered:"),
                @ptrCast(@constCast(entered)),
                "Q@:@",
            );

            // draggingUpdated:
            const updated = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id) callconv(.c) c_ulong,
                @ptrCast(@constCast(&draggingUpdated)),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("draggingUpdated:"),
                @ptrCast(@constCast(updated)),
                "Q@:@",
            );

            // draggingExited:
            const exited = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id) callconv(.c) void,
                @ptrCast(@constCast(&draggingExited)),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("draggingExited:"),
                @ptrCast(@constCast(exited)),
                "v@:@",
            );

            // performDragOperation:
            const perform = @as(
                *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id) callconv(.c) c_int,
                @ptrCast(@constCast(&performDragOperation)),
            );
            _ = macos.objc.class_addMethod(
                objc_class,
                macos.sel("performDragOperation:"),
                @ptrCast(@constCast(perform)),
                "c@:@",
            );

            macos.objc.objc_registerClassPair(objc_class);
        }

        const instance = macos.msgSend0(macos.msgSend0(objc_class.?, "alloc"), "init");

        // Store callback data
        const data_ptr_value = @intFromPtr(callback_data);
        const NSValue = macos.getClass("NSValue");
        const data_value = macos.msgSend1(
            NSValue,
            "valueWithPointer:",
            @as(?*anyopaque, @ptrFromInt(data_ptr_value)),
        );
        macos.objc.objc_setAssociatedObject(
            instance,
            @ptrFromInt(0xDROP),
            data_value,
            macos.objc.OBJC_ASSOCIATION_RETAIN,
        );

        const delegate = try allocator.create(DraggingDestinationDelegate);
        delegate.* = .{
            .objc_class = objc_class.?,
            .instance = instance,
            .callback_data = callback_data,
            .allocator = allocator,
        };
        return delegate;
    }

    pub fn deinit(self: *DraggingDestinationDelegate) void {
        if (self.instance != @as(macos.objc.id, null)) {
            _ = macos.msgSend0(self.instance, "release");
        }
        self.allocator.destroy(self.callback_data);
        self.allocator.destroy(self);
    }

    pub fn getInstance(self: *DraggingDestinationDelegate) macos.objc.id {
        return self.instance;
    }

    pub fn setOnDropCallback(self: *DraggingDestinationDelegate, callback: *const fn ([]const []const u8, CGPoint) bool) void {
        self.callback_data.on_drop = callback;
    }
};

fn getDestinationCallbackData(instance: macos.objc.id) ?*DraggingDestinationDelegate.DestinationCallbackData {
    const associated = macos.objc.objc_getAssociatedObject(instance, @ptrFromInt(0xDROP));
    if (associated == @as(macos.objc.id, null)) return null;

    const ptr = macos.msgSend0(associated, "pointerValue");
    if (@intFromPtr(ptr) == 0) return null;

    return @ptrCast(@alignCast(ptr));
}

/// NSDraggingDestination method: draggingEntered
export fn draggingEntered(
    self: macos.objc.id,
    _: macos.objc.SEL,
    _: macos.objc.id, // draggingInfo
) callconv(.c) c_ulong {
    const callback_data = getDestinationCallbackData(self) orelse return DragOperation.None;

    if (callback_data.on_drag_enter) |callback| {
        return callback();
    }

    // Default: accept copy and move
    return DragOperation.Copy | DragOperation.Move;
}

/// NSDraggingDestination method: draggingUpdated
export fn draggingUpdated(
    self: macos.objc.id,
    _: macos.objc.SEL,
    draggingInfo: macos.objc.id,
) callconv(.c) c_ulong {
    const callback_data = getDestinationCallbackData(self) orelse return DragOperation.None;

    // Get drag location - draggingLocation returns NSPoint directly
    // For now, use a default point since extracting struct returns is complex
    const location = CGPoint{ .x = 0, .y = 0 };
    _ = draggingInfo;

    if (callback_data.on_drag_updated) |callback| {
        return callback(location);
    }

    return DragOperation.Copy | DragOperation.Move;
}

/// NSDraggingDestination method: draggingExited
export fn draggingExited(
    self: macos.objc.id,
    _: macos.objc.SEL,
    _: macos.objc.id, // draggingInfo
) callconv(.c) void {
    const callback_data = getDestinationCallbackData(self) orelse return;

    if (callback_data.on_drag_exit) |callback| {
        callback();
    }
}

/// NSDraggingDestination method: performDragOperation
export fn performDragOperation(
    self: macos.objc.id,
    _: macos.objc.SEL,
    draggingInfo: macos.objc.id,
) callconv(.c) c_int {
    const callback_data = getDestinationCallbackData(self) orelse return 0;
    _ = draggingInfo;

    // Use default point for now
    const location = CGPoint{ .x = 0, .y = 0 };

    if (callback_data.on_drop) |callback| {
        // TODO: Extract item IDs from pasteboard
        const empty_items: []const []const u8 = &.{};
        const success = callback(empty_items, location);
        return if (success) 1 else 0;
    }

    return 1; // Accept drop by default
}

/// Register a view for drag operations
pub fn registerForDraggedTypes(view: macos.objc.id) void {
    const NSArray = macos.getClass("NSArray");
    const types = macos.msgSend1(
        NSArray,
        "arrayWithObject:",
        macos.createNSString(CraftDragType),
    );
    _ = macos.msgSend1(view, "registerForDraggedTypes:", types);

    std.debug.print("[DragDrop] Registered view for dragged types\n", .{});
}

/// Create a dragging item for pasteboard
pub fn createDraggingItem(item_id: []const u8, frame: macos.NSRect) macos.objc.id {
    const NSDraggingItem = macos.getClass("NSDraggingItem");
    const NSString = macos.getClass("NSString");

    // Create pasteboard item
    const nsString = macos.createNSString(item_id);

    // Create dragging item
    const item = macos.msgSend1(
        macos.msgSend0(NSDraggingItem, "alloc"),
        "initWithPasteboardWriter:",
        nsString,
    );

    // Set dragging frame
    _ = macos.msgSend2(item, "setDraggingFrame:contents:", frame, @as(macos.objc.id, null));

    return item;
}

/// Start a drag session from a view
pub fn beginDraggingSession(
    view: macos.objc.id,
    items: []const macos.objc.id,
    event: macos.objc.id,
    source: macos.objc.id,
) macos.objc.id {
    const NSArray = macos.getClass("NSArray");

    // Create array of dragging items
    const items_array = macos.msgSend2(
        NSArray,
        "arrayWithObjects:count:",
        @as([*]const macos.objc.id, items.ptr),
        @as(c_ulong, items.len),
    );

    // Begin session
    const session = macos.msgSend3(
        view,
        "beginDraggingSessionWithItems:event:source:",
        items_array,
        event,
        source,
    );

    std.debug.print("[DragDrop] Started dragging session\n", .{});
    return session;
}
