const std = @import("std");

/// System Integration Module
/// Provides native system integrations: notifications, clipboard, file system

/// System Notifications
pub const Notification = struct {
    title: []const u8,
    body: []const u8,
    subtitle: ?[]const u8 = null,
    icon: ?[]const u8 = null,
    sound: ?NotificationSound = null,
    actions: []const NotificationAction = &[_]NotificationAction{},
    urgency: Urgency = .normal,
    timeout_ms: ?u64 = null,
    id: ?[]const u8 = null,

    pub const Urgency = enum {
        low,
        normal,
        critical,
    };

    pub const NotificationSound = enum {
        default,
        custom,
        none,
    };

    pub const NotificationAction = struct {
        id: []const u8,
        label: []const u8,
        callback: *const fn () void,
    };

    pub fn init(title: []const u8, body: []const u8) Notification {
        return Notification{
            .title = title,
            .body = body,
        };
    }

    pub fn show(self: Notification) !void {
        const builtin = @import("builtin");
        switch (builtin.target.os.tag) {
            .macos => try showMacOSNotification(self),
            .linux => try showLinuxNotification(self),
            .windows => try showWindowsNotification(self),
            else => return error.UnsupportedPlatform,
        }
    }

    fn showMacOSNotification(notification: Notification) !void {
        const objc = @import("objc_runtime.zig").objc;

        // Get UNUserNotificationCenter
        const UNUserNotificationCenterClass = objc.objc_getClass("UNUserNotificationCenter") orelse return error.ClassNotFound;
        const sel_currentNotificationCenter = objc.sel_registerName("currentNotificationCenter") orelse return error.SelectorNotFound;
        const center = objc.msgSendId(UNUserNotificationCenterClass, sel_currentNotificationCenter);

        // Create UNMutableNotificationContent
        const UNMutableNotificationContentClass = objc.objc_getClass("UNMutableNotificationContent") orelse return error.ClassNotFound;
        const content = try objc.allocInit(UNMutableNotificationContentClass);

        // Set title
        const allocator = std.heap.page_allocator;
        const ns_title = try objc.createNSString(notification.title, allocator);
        const sel_setTitle = objc.sel_registerName("setTitle:") orelse return error.SelectorNotFound;
        objc.msgSendVoid1(content, sel_setTitle, ns_title);

        // Set body
        const ns_body = try objc.createNSString(notification.body, allocator);
        const sel_setBody = objc.sel_registerName("setBody:") orelse return error.SelectorNotFound;
        objc.msgSendVoid1(content, sel_setBody, ns_body);

        // Set subtitle if present
        if (notification.subtitle) |subtitle| {
            const ns_subtitle = try objc.createNSString(subtitle, allocator);
            const sel_setSubtitle = objc.sel_registerName("setSubtitle:") orelse return error.SelectorNotFound;
            objc.msgSendVoid1(content, sel_setSubtitle, ns_subtitle);
        }

        // Set sound
        if (notification.sound) |sound| {
            switch (sound) {
                .default => {
                    const UNNotificationSoundClass = objc.objc_getClass("UNNotificationSound") orelse return error.ClassNotFound;
                    const sel_defaultSound = objc.sel_registerName("defaultSound") orelse return error.SelectorNotFound;
                    const default_sound = objc.msgSendId(UNNotificationSoundClass, sel_defaultSound);
                    const sel_setSound = objc.sel_registerName("setSound:") orelse return error.SelectorNotFound;
                    objc.msgSendVoid1(content, sel_setSound, default_sound);
                },
                .none, .custom => {},
            }
        }

        // Create UNNotificationRequest
        const UNNotificationRequestClass = objc.objc_getClass("UNNotificationRequest") orelse return error.ClassNotFound;
        const sel_requestWithIdentifier = objc.sel_registerName("requestWithIdentifier:content:trigger:") orelse return error.SelectorNotFound;

        // Generate identifier
        const identifier = if (notification.id) |id| try objc.createNSString(id, allocator) else try objc.createNSString("craft-notification", allocator);

        const Fn = *const fn (objc.Class, objc.SEL, objc.id, objc.id, ?*anyopaque) callconv(.C) objc.id;
        const func: Fn = @ptrCast(&@import("objc_runtime.zig").objc.objc_msgSend);
        const request = func(UNNotificationRequestClass, sel_requestWithIdentifier, identifier, content, null);

        // Add notification request to center
        const sel_addNotificationRequest = objc.sel_registerName("addNotificationRequest:withCompletionHandler:") orelse return error.SelectorNotFound;
        const Fn2 = *const fn (objc.id, objc.SEL, objc.id, ?*anyopaque) callconv(.C) void;
        const func2: Fn2 = @ptrCast(&@import("objc_runtime.zig").objc.objc_msgSend);
        func2(center, sel_addNotificationRequest, request, null);
    }

    fn showLinuxNotification(notification: Notification) !void {
        // Use libnotify via extern C bindings
        const linux = @import("linux.zig");
        try linux.showNotification(notification.title, notification.body);
    }

    fn showWindowsNotification(notification: Notification) !void {
        // Windows toast notifications would be implemented via WinRT
        const windows = @import("windows.zig");
        try windows.showNotification(notification.title, notification.body);
    }
};

pub const NotificationManager = struct {
    allocator: std.mem.Allocator,
    notifications: std.ArrayList(Notification),

    pub fn init(allocator: std.mem.Allocator) NotificationManager {
        return NotificationManager{
            .allocator = allocator,
            .notifications = .{},
        };
    }

    pub fn deinit(self: *NotificationManager) void {
        self.notifications.deinit(self.allocator);
    }

    pub fn send(self: *NotificationManager, notification: Notification) !void {
        try notification.show();
        try self.notifications.append(self.allocator, notification);
    }

    pub fn cancel(self: *NotificationManager, id: []const u8) void {
        _ = self;
        _ = id;
        // Platform-specific cancellation
    }

    pub fn cancelAll(self: *NotificationManager) void {
        _ = self;
        // Platform-specific cancel all
    }

    pub fn requestPermission(self: *NotificationManager) !bool {
        _ = self;
        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => requestMacOSPermission(),
            .linux => true, // Usually allowed by default
            .windows => true, // Usually allowed by default
            else => false,
        };
    }

    fn requestMacOSPermission() bool {
        // UNUserNotificationCenter requestAuthorization
        return true;
    }
};

/// Clipboard Management
pub const Clipboard = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Clipboard {
        return Clipboard{
            .allocator = allocator,
        };
    }

    pub fn getText(self: Clipboard) !?[]const u8 {
        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => try getMacOSClipboardText(self.allocator),
            .linux => try getLinuxClipboardText(self.allocator),
            .windows => try getWindowsClipboardText(self.allocator),
            else => null,
        };
    }

    pub fn setText(self: Clipboard, text: []const u8) !void {
        _ = self;
        const builtin = @import("builtin");
        switch (builtin.target.os.tag) {
            .macos => try setMacOSClipboardText(text),
            .linux => try setLinuxClipboardText(text),
            .windows => try setWindowsClipboardText(text),
            else => {},
        }
    }

    pub fn getImage(self: Clipboard) !?[]const u8 {
        _ = self;
        // Platform-specific image retrieval
        return null;
    }

    pub fn setImage(self: Clipboard, image_data: []const u8) !void {
        _ = self;
        _ = image_data;
        // Platform-specific image setting
    }

    pub fn getFiles(self: Clipboard) !?[]const []const u8 {
        _ = self;
        // Platform-specific file list retrieval
        return null;
    }

    pub fn setFiles(self: Clipboard, files: []const []const u8) !void {
        _ = self;
        _ = files;
        // Platform-specific file list setting
    }

    pub fn clear(self: Clipboard) !void {
        _ = self;
        const builtin = @import("builtin");
        switch (builtin.target.os.tag) {
            .macos => clearMacOSClipboard(),
            .linux => clearLinuxClipboard(),
            .windows => clearWindowsClipboard(),
            else => {},
        }
    }

    pub fn watch(self: Clipboard, callback: *const fn ([]const u8) void) !void {
        _ = self;
        _ = callback;
        // Watch for clipboard changes
    }

    fn getMacOSClipboardText(allocator: std.mem.Allocator) !?[]const u8 {
        const objc = @import("objc_runtime.zig").objc;

        // Get NSPasteboard generalPasteboard
        const NSPasteboardClass = objc.objc_getClass("NSPasteboard") orelse return error.ClassNotFound;
        const sel_generalPasteboard = objc.sel_registerName("generalPasteboard") orelse return error.SelectorNotFound;
        const pasteboard = objc.msgSendId(NSPasteboardClass, sel_generalPasteboard);

        // Get string for type NSPasteboardTypeString
        const NSPasteboardTypeString = objc.objc_getClass("NSPasteboardTypeString") orelse {
            // Fallback - create NSString for type
            const ns_type = try objc.createNSString("public.utf8-plain-text", allocator);
            const sel_stringForType = objc.sel_registerName("stringForType:") orelse return error.SelectorNotFound;
            const ns_string = objc.msgSendId1(pasteboard, sel_stringForType, ns_type);

            if (ns_string == null) return null;

            // Convert NSString to Zig string
            const utf8_ptr = objc.getNSStringUTF8(ns_string);
            if (utf8_ptr == null) return null;

            const len = std.mem.len(utf8_ptr.?);
            const result = try allocator.alloc(u8, len);
            @memcpy(result, utf8_ptr.?[0..len]);
            return result;
        };

        const sel_stringForType = objc.sel_registerName("stringForType:") orelse return error.SelectorNotFound;
        const ns_string = objc.msgSendId1(pasteboard, sel_stringForType, NSPasteboardTypeString);

        if (ns_string == null) return null;

        // Convert NSString to Zig string
        const utf8_ptr = objc.getNSStringUTF8(ns_string);
        if (utf8_ptr == null) return null;

        const len = std.mem.len(utf8_ptr.?);
        const result = try allocator.alloc(u8, len);
        @memcpy(result, utf8_ptr.?[0..len]);
        return result;
    }

    fn setMacOSClipboardText(text: []const u8) !void {
        const objc = @import("objc_runtime.zig").objc;

        // Get NSPasteboard generalPasteboard
        const NSPasteboardClass = objc.objc_getClass("NSPasteboard") orelse return error.ClassNotFound;
        const sel_generalPasteboard = objc.sel_registerName("generalPasteboard") orelse return error.SelectorNotFound;
        const pasteboard = objc.msgSendId(NSPasteboardClass, sel_generalPasteboard);

        // Clear contents
        const sel_clearContents = objc.sel_registerName("clearContents") orelse return error.SelectorNotFound;
        objc.msgSend(pasteboard, sel_clearContents);

        // Create NSString from text
        const allocator = std.heap.page_allocator;
        const ns_string = try objc.createNSString(text, allocator);

        // Create NSPasteboardTypeString type
        const ns_type = try objc.createNSString("public.utf8-plain-text", allocator);

        // Set string for type
        const sel_setString = objc.sel_registerName("setString:forType:") orelse return error.SelectorNotFound;
        const Fn = *const fn (objc.id, objc.SEL, objc.id, objc.id) callconv(.C) bool;
        const func: Fn = @ptrCast(&@import("objc_runtime.zig").objc.objc_msgSend);
        _ = func(pasteboard, sel_setString, ns_string, ns_type);
    }

    fn clearMacOSClipboard() void {
        const objc = @import("objc_runtime.zig").objc;

        // Get NSPasteboard generalPasteboard
        const NSPasteboardClass = objc.objc_getClass("NSPasteboard") orelse return;
        const sel_generalPasteboard = objc.sel_registerName("generalPasteboard") orelse return;
        const pasteboard = objc.msgSendId(NSPasteboardClass, sel_generalPasteboard);

        // Clear contents
        const sel_clearContents = objc.sel_registerName("clearContents") orelse return;
        objc.msgSend(pasteboard, sel_clearContents);
    }

    fn getLinuxClipboardText(allocator: std.mem.Allocator) !?[]const u8 {
        _ = allocator;
        // X11 or Wayland clipboard
        return null;
    }

    fn setLinuxClipboardText(text: []const u8) !void {
        _ = text;
        // X11 or Wayland clipboard
    }

    fn clearLinuxClipboard() void {
        // Clear X11/Wayland clipboard
    }

    fn getWindowsClipboardText(allocator: std.mem.Allocator) !?[]const u8 {
        _ = allocator;
        // GetClipboardData(CF_TEXT)
        return null;
    }

    fn setWindowsClipboardText(text: []const u8) !void {
        _ = text;
        // SetClipboardData
    }

    fn clearWindowsClipboard() void {
        // EmptyClipboard()
    }
};

/// File System Dialogs
pub const FileDialog = struct {
    title: []const u8,
    default_path: ?[]const u8 = null,
    filters: []const FileFilter = &[_]FileFilter{},
    multi_select: bool = false,
    create_directories: bool = false,
    show_hidden: bool = false,

    pub const FileFilter = struct {
        name: []const u8,
        extensions: []const []const u8,
    };

    pub fn openFile(options: FileDialog) !?[]const u8 {
        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => openMacOSFileDialog(options),
            .linux => openLinuxFileDialog(options),
            .windows => openWindowsFileDialog(options),
            else => null,
        };
    }

    pub fn openFiles(options: FileDialog) !?[]const []const u8 {
        var opts = options;
        opts.multi_select = true;
        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => openMacOSFilesDialog(opts),
            .linux => openLinuxFilesDialog(opts),
            .windows => openWindowsFilesDialog(opts),
            else => null,
        };
    }

    pub fn saveFile(options: FileDialog) !?[]const u8 {
        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => saveMacOSFileDialog(options),
            .linux => saveLinuxFileDialog(options),
            .windows => saveWindowsFileDialog(options),
            else => null,
        };
    }

    pub fn selectDirectory(options: FileDialog) !?[]const u8 {
        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => selectMacOSDirectoryDialog(options),
            .linux => selectLinuxDirectoryDialog(options),
            .windows => selectWindowsDirectoryDialog(options),
            else => null,
        };
    }

    fn openMacOSFileDialog(options: FileDialog) !?[]const u8 {
        const objc = @import("objc_runtime.zig").objc;

        // Create NSOpenPanel
        const NSOpenPanelClass = objc.objc_getClass("NSOpenPanel") orelse return error.ClassNotFound;
        const sel_openPanel = objc.sel_registerName("openPanel") orelse return error.SelectorNotFound;
        const panel = objc.msgSendId(NSOpenPanelClass, sel_openPanel);

        // Configure panel
        const sel_setCanChooseFiles = objc.sel_registerName("setCanChooseFiles:") orelse return error.SelectorNotFound;
        objc.msgSendVoid1(panel, sel_setCanChooseFiles, @as(bool, true));

        const sel_setCanChooseDirectories = objc.sel_registerName("setCanChooseDirectories:") orelse return error.SelectorNotFound;
        objc.msgSendVoid1(panel, sel_setCanChooseDirectories, @as(bool, false));

        const sel_setAllowsMultipleSelection = objc.sel_registerName("setAllowsMultipleSelection:") orelse return error.SelectorNotFound;
        objc.msgSendVoid1(panel, sel_setAllowsMultipleSelection, @as(bool, false));

        // Set title
        const allocator = std.heap.page_allocator;
        const ns_title = try objc.createNSString(options.title, allocator);
        const sel_setTitle = objc.sel_registerName("setTitle:") orelse return error.SelectorNotFound;
        objc.msgSendVoid1(panel, sel_setTitle, ns_title);

        // Show hidden files if requested
        if (options.show_hidden) {
            const sel_setShowsHiddenFiles = objc.sel_registerName("setShowsHiddenFiles:") orelse return error.SelectorNotFound;
            objc.msgSendVoid1(panel, sel_setShowsHiddenFiles, @as(bool, true));
        }

        // Run modal
        const sel_runModal = objc.sel_registerName("runModal") orelse return error.SelectorNotFound;
        const Fn = *const fn (objc.id, objc.SEL) callconv(.C) i64;
        const func: Fn = @ptrCast(&@import("objc_runtime.zig").objc.objc_msgSend);
        const result = func(panel, sel_runModal);

        // NSModalResponseOK = 1
        if (result != 1) return null;

        // Get URL
        const sel_URL = objc.sel_registerName("URL") orelse return error.SelectorNotFound;
        const url = objc.msgSendId(panel, sel_URL);
        if (url == null) return null;

        // Get path from URL
        const sel_path = objc.sel_registerName("path") orelse return error.SelectorNotFound;
        const ns_path = objc.msgSendId(url, sel_path);
        if (ns_path == null) return null;

        // Convert to Zig string
        const utf8_ptr = objc.getNSStringUTF8(ns_path);
        if (utf8_ptr == null) return null;

        const len = std.mem.len(utf8_ptr.?);
        const path = try allocator.alloc(u8, len);
        @memcpy(path, utf8_ptr.?[0..len]);
        return path;
    }

    fn openMacOSFilesDialog(options: FileDialog) !?[]const []const u8 {
        const objc = @import("objc_runtime.zig").objc;

        // Create NSOpenPanel
        const NSOpenPanelClass = objc.objc_getClass("NSOpenPanel") orelse return error.ClassNotFound;
        const sel_openPanel = objc.sel_registerName("openPanel") orelse return error.SelectorNotFound;
        const panel = objc.msgSendId(NSOpenPanelClass, sel_openPanel);

        // Configure panel for multiple selection
        const sel_setCanChooseFiles = objc.sel_registerName("setCanChooseFiles:") orelse return error.SelectorNotFound;
        objc.msgSendVoid1(panel, sel_setCanChooseFiles, @as(bool, true));

        const sel_setAllowsMultipleSelection = objc.sel_registerName("setAllowsMultipleSelection:") orelse return error.SelectorNotFound;
        objc.msgSendVoid1(panel, sel_setAllowsMultipleSelection, @as(bool, true));

        // Set title
        const allocator = std.heap.page_allocator;
        const ns_title = try objc.createNSString(options.title, allocator);
        const sel_setTitle = objc.sel_registerName("setTitle:") orelse return error.SelectorNotFound;
        objc.msgSendVoid1(panel, sel_setTitle, ns_title);

        // Run modal
        const sel_runModal = objc.sel_registerName("runModal") orelse return error.SelectorNotFound;
        const Fn = *const fn (objc.id, objc.SEL) callconv(.C) i64;
        const func: Fn = @ptrCast(&@import("objc_runtime.zig").objc.objc_msgSend);
        const result = func(panel, sel_runModal);

        if (result != 1) return null;

        // Get URLs
        const sel_URLs = objc.sel_registerName("URLs") orelse return error.SelectorNotFound;
        const urls = objc.msgSendId(panel, sel_URLs);
        if (urls == null) return null;

        // Get count
        const sel_count = objc.sel_registerName("count") orelse return error.SelectorNotFound;
        const FnCount = *const fn (objc.id, objc.SEL) callconv(.C) u64;
        const count_func: FnCount = @ptrCast(&@import("objc_runtime.zig").objc.objc_msgSend);
        const count = count_func(urls, sel_count);

        if (count == 0) return null;

        // Allocate result array
        var paths = try allocator.alloc([]const u8, count);
        const sel_objectAtIndex = objc.sel_registerName("objectAtIndex:") orelse return error.SelectorNotFound;
        const sel_path = objc.sel_registerName("path") orelse return error.SelectorNotFound;

        var i: u64 = 0;
        while (i < count) : (i += 1) {
            const FnObj = *const fn (objc.id, objc.SEL, u64) callconv(.C) objc.id;
            const obj_func: FnObj = @ptrCast(&@import("objc_runtime.zig").objc.objc_msgSend);
            const url = obj_func(urls, sel_objectAtIndex, i);

            const ns_path = objc.msgSendId(url, sel_path);
            const utf8_ptr = objc.getNSStringUTF8(ns_path) orelse continue;

            const len = std.mem.len(utf8_ptr);
            const path = try allocator.alloc(u8, len);
            @memcpy(path, utf8_ptr[0..len]);
            paths[i] = path;
        }

        return paths;
    }

    fn saveMacOSFileDialog(options: FileDialog) !?[]const u8 {
        const objc = @import("objc_runtime.zig").objc;

        // Create NSSavePanel
        const NSSavePanelClass = objc.objc_getClass("NSSavePanel") orelse return error.ClassNotFound;
        const sel_savePanel = objc.sel_registerName("savePanel") orelse return error.SelectorNotFound;
        const panel = objc.msgSendId(NSSavePanelClass, sel_savePanel);

        // Set title
        const allocator = std.heap.page_allocator;
        const ns_title = try objc.createNSString(options.title, allocator);
        const sel_setTitle = objc.sel_registerName("setTitle:") orelse return error.SelectorNotFound;
        objc.msgSendVoid1(panel, sel_setTitle, ns_title);

        // Allow creating directories
        if (options.create_directories) {
            const sel_setCanCreateDirectories = objc.sel_registerName("setCanCreateDirectories:") orelse return error.SelectorNotFound;
            objc.msgSendVoid1(panel, sel_setCanCreateDirectories, @as(bool, true));
        }

        // Run modal
        const sel_runModal = objc.sel_registerName("runModal") orelse return error.SelectorNotFound;
        const Fn = *const fn (objc.id, objc.SEL) callconv(.C) i64;
        const func: Fn = @ptrCast(&@import("objc_runtime.zig").objc.objc_msgSend);
        const result = func(panel, sel_runModal);

        if (result != 1) return null;

        // Get URL
        const sel_URL = objc.sel_registerName("URL") orelse return error.SelectorNotFound;
        const url = objc.msgSendId(panel, sel_URL);
        if (url == null) return null;

        // Get path
        const sel_path = objc.sel_registerName("path") orelse return error.SelectorNotFound;
        const ns_path = objc.msgSendId(url, sel_path);
        if (ns_path == null) return null;

        const utf8_ptr = objc.getNSStringUTF8(ns_path) orelse return null;
        const len = std.mem.len(utf8_ptr);
        const path = try allocator.alloc(u8, len);
        @memcpy(path, utf8_ptr[0..len]);
        return path;
    }

    fn selectMacOSDirectoryDialog(options: FileDialog) !?[]const u8 {
        const objc = @import("objc_runtime.zig").objc;

        // Create NSOpenPanel
        const NSOpenPanelClass = objc.objc_getClass("NSOpenPanel") orelse return error.ClassNotFound;
        const sel_openPanel = objc.sel_registerName("openPanel") orelse return error.SelectorNotFound;
        const panel = objc.msgSendId(NSOpenPanelClass, sel_openPanel);

        // Configure for directory selection
        const sel_setCanChooseFiles = objc.sel_registerName("setCanChooseFiles:") orelse return error.SelectorNotFound;
        objc.msgSendVoid1(panel, sel_setCanChooseFiles, @as(bool, false));

        const sel_setCanChooseDirectories = objc.sel_registerName("setCanChooseDirectories:") orelse return error.SelectorNotFound;
        objc.msgSendVoid1(panel, sel_setCanChooseDirectories, @as(bool, true));

        // Set title
        const allocator = std.heap.page_allocator;
        const ns_title = try objc.createNSString(options.title, allocator);
        const sel_setTitle = objc.sel_registerName("setTitle:") orelse return error.SelectorNotFound;
        objc.msgSendVoid1(panel, sel_setTitle, ns_title);

        // Allow creating directories
        if (options.create_directories) {
            const sel_setCanCreateDirectories = objc.sel_registerName("setCanCreateDirectories:") orelse return error.SelectorNotFound;
            objc.msgSendVoid1(panel, sel_setCanCreateDirectories, @as(bool, true));
        }

        // Run modal
        const sel_runModal = objc.sel_registerName("runModal") orelse return error.SelectorNotFound;
        const Fn = *const fn (objc.id, objc.SEL) callconv(.C) i64;
        const func: Fn = @ptrCast(&@import("objc_runtime.zig").objc.objc_msgSend);
        const result = func(panel, sel_runModal);

        if (result != 1) return null;

        // Get URL
        const sel_URL = objc.sel_registerName("URL") orelse return error.SelectorNotFound;
        const url = objc.msgSendId(panel, sel_URL);
        if (url == null) return null;

        // Get path
        const sel_path = objc.sel_registerName("path") orelse return error.SelectorNotFound;
        const ns_path = objc.msgSendId(url, sel_path);
        if (ns_path == null) return null;

        const utf8_ptr = objc.getNSStringUTF8(ns_path) orelse return null;
        const len = std.mem.len(utf8_ptr);
        const path = try allocator.alloc(u8, len);
        @memcpy(path, utf8_ptr[0..len]);
        return path;
    }

    fn openLinuxFileDialog(options: FileDialog) !?[]const u8 {
        _ = options;
        // GtkFileChooserDialog
        return null;
    }

    fn openLinuxFilesDialog(options: FileDialog) !?[]const []const u8 {
        _ = options;
        // GtkFileChooserDialog with select_multiple
        return null;
    }

    fn saveLinuxFileDialog(options: FileDialog) !?[]const u8 {
        _ = options;
        // GtkFileChooserDialog with SAVE action
        return null;
    }

    fn selectLinuxDirectoryDialog(options: FileDialog) !?[]const u8 {
        _ = options;
        // GtkFileChooserDialog with SELECT_FOLDER action
        return null;
    }

    fn openWindowsFileDialog(options: FileDialog) !?[]const u8 {
        _ = options;
        // IFileOpenDialog
        return null;
    }

    fn openWindowsFilesDialog(options: FileDialog) !?[]const []const u8 {
        _ = options;
        // IFileOpenDialog with FOS_ALLOWMULTISELECT
        return null;
    }

    fn saveWindowsFileDialog(options: FileDialog) !?[]const u8 {
        _ = options;
        // IFileSaveDialog
        return null;
    }

    fn selectWindowsDirectoryDialog(options: FileDialog) !?[]const u8 {
        _ = options;
        // IFileOpenDialog with FOS_PICKFOLDERS
        return null;
    }
};

/// System Information
pub const SystemInfo = struct {
    pub fn getOSName() []const u8 {
        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => "macOS",
            .linux => "Linux",
            .windows => "Windows",
            .ios => "iOS",
            else => "Unknown",
        };
    }

    pub fn getOSVersion(allocator: std.mem.Allocator) ![]const u8 {
        _ = allocator;
        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => getMacOSVersion(),
            .linux => getLinuxVersion(),
            .windows => getWindowsVersion(),
            else => "Unknown",
        };
    }

    pub fn getHostname(allocator: std.mem.Allocator) ![]const u8 {
        _ = allocator;
        // gethostname() or platform equivalent
        return "localhost";
    }

    pub fn getUsername(allocator: std.mem.Allocator) ![]const u8 {
        _ = allocator;
        // getenv("USER") or platform equivalent
        return "user";
    }

    pub fn getHomeDirectory(allocator: std.mem.Allocator) ![]const u8 {
        _ = allocator;
        // getenv("HOME") or platform equivalent
        return "/home/user";
    }

    pub fn getTempDirectory(allocator: std.mem.Allocator) ![]const u8 {
        _ = allocator;
        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos, .linux => "/tmp",
            .windows => "C:\\Windows\\Temp",
            else => "/tmp",
        };
    }

    pub fn getCPUCount() u32 {
        // Get number of logical CPUs
        return 8;
    }

    pub fn getTotalMemory() u64 {
        // Get total system memory in bytes
        return 16 * 1024 * 1024 * 1024;
    }

    pub fn getFreeMemory() u64 {
        // Get free system memory in bytes
        return 8 * 1024 * 1024 * 1024;
    }

    pub fn getUptime() u64 {
        // Get system uptime in seconds
        return 86400;
    }

    fn getMacOSVersion() []const u8 {
        // NSProcessInfo.processInfo.operatingSystemVersionString
        return "14.0";
    }

    fn getLinuxVersion() []const u8 {
        // uname -r or /proc/version
        return "6.0.0";
    }

    fn getWindowsVersion() []const u8 {
        // GetVersionEx or RtlGetVersion
        return "11";
    }
};

/// Power Management
pub const PowerManagement = struct {
    pub const BatteryState = enum {
        unknown,
        unplugged,
        charging,
        full,
    };

    pub const BatteryInfo = struct {
        state: BatteryState,
        level: f32, // 0.0 to 1.0
        time_remaining: ?u64, // seconds
    };

    pub fn getBatteryInfo() !BatteryInfo {
        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => getMacOSBatteryInfo(),
            .linux => getLinuxBatteryInfo(),
            .windows => getWindowsBatteryInfo(),
            else => BatteryInfo{
                .state = .unknown,
                .level = 0.0,
                .time_remaining = null,
            },
        };
    }

    pub fn preventSleep() !void {
        const builtin = @import("builtin");
        switch (builtin.target.os.tag) {
            .macos => preventMacOSSleep(),
            .linux => preventLinuxSleep(),
            .windows => preventWindowsSleep(),
            else => {},
        }
    }

    pub fn allowSleep() void {
        const builtin = @import("builtin");
        switch (builtin.target.os.tag) {
            .macos => allowMacOSSleep(),
            .linux => allowLinuxSleep(),
            .windows => allowWindowsSleep(),
            else => {},
        }
    }

    fn getMacOSBatteryInfo() BatteryInfo {
        // IOKit power sources
        return BatteryInfo{
            .state = .unknown,
            .level = 0.5,
            .time_remaining = null,
        };
    }

    fn getLinuxBatteryInfo() BatteryInfo {
        // /sys/class/power_supply/BAT0/
        return BatteryInfo{
            .state = .unknown,
            .level = 0.5,
            .time_remaining = null,
        };
    }

    fn getWindowsBatteryInfo() BatteryInfo {
        // GetSystemPowerStatus
        return BatteryInfo{
            .state = .unknown,
            .level = 0.5,
            .time_remaining = null,
        };
    }

    fn preventMacOSSleep() void {
        // IOPMAssertionCreateWithName
    }

    fn allowMacOSSleep() void {
        // IOPMAssertionRelease
    }

    fn preventLinuxSleep() void {
        // systemd-inhibit
    }

    fn allowLinuxSleep() void {
        // Release systemd inhibitor
    }

    fn preventWindowsSleep() void {
        // SetThreadExecutionState
    }

    fn allowWindowsSleep() void {
        // SetThreadExecutionState(ES_CONTINUOUS)
    }
};

/// Screen Information
pub const Screen = struct {
    width: u32,
    height: u32,
    scale_factor: f32,
    x: i32,
    y: i32,
    is_primary: bool,

    pub fn getAllScreens(allocator: std.mem.Allocator) ![]Screen {
        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => getMacOSScreens(allocator),
            .linux => getLinuxScreens(allocator),
            .windows => getWindowsScreens(allocator),
            else => &[_]Screen{},
        };
    }

    pub fn getPrimaryScreen() !Screen {
        return Screen{
            .width = 1920,
            .height = 1080,
            .scale_factor = 1.0,
            .x = 0,
            .y = 0,
            .is_primary = true,
        };
    }

    fn getMacOSScreens(allocator: std.mem.Allocator) ![]Screen {
        _ = allocator;
        // NSScreen.screens
        return &[_]Screen{};
    }

    fn getLinuxScreens(allocator: std.mem.Allocator) ![]Screen {
        _ = allocator;
        // X11 or Wayland screen info
        return &[_]Screen{};
    }

    fn getWindowsScreens(allocator: std.mem.Allocator) ![]Screen {
        _ = allocator;
        // EnumDisplayMonitors
        return &[_]Screen{};
    }
};

/// URL Handling
pub const URLHandler = struct {
    pub fn openURL(url: []const u8) !void {
        const builtin = @import("builtin");
        switch (builtin.target.os.tag) {
            .macos => try openMacOSURL(url),
            .linux => try openLinuxURL(url),
            .windows => try openWindowsURL(url),
            else => return error.UnsupportedPlatform,
        }
    }

    pub fn registerURLScheme(scheme: []const u8, handler: *const fn ([]const u8) void) !void {
        _ = handler;
        const builtin = @import("builtin");
        switch (builtin.target.os.tag) {
            .macos => registerMacOSURLScheme(scheme),
            .linux => registerLinuxURLScheme(scheme),
            .windows => registerWindowsURLScheme(scheme),
            else => {},
        }
    }

    fn openMacOSURL(url: []const u8) !void {
        _ = url;
        // NSWorkspace.shared.open(URL)
    }

    fn openLinuxURL(url: []const u8) !void {
        _ = url;
        // xdg-open
    }

    fn openWindowsURL(url: []const u8) !void {
        _ = url;
        // ShellExecute
    }

    fn registerMacOSURLScheme(scheme: []const u8) void {
        _ = scheme;
        // CFBundleURLTypes in Info.plist
    }

    fn registerLinuxURLScheme(scheme: []const u8) void {
        _ = scheme;
        // .desktop file with x-scheme-handler
    }

    fn registerWindowsURLScheme(scheme: []const u8) void {
        _ = scheme;
        // Registry: HKEY_CLASSES_ROOT
    }
};
