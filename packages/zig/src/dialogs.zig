const std = @import("std");
const io_context = @import("io_context.zig");

/// Native Dialog System
/// Provides comprehensive native dialogs with platform-specific implementations

pub const DialogType = enum {
    file_open,
    file_save,
    directory,
    color,
    font,
    message,
    confirm,
    input,
    progress,
    custom,
};

pub const DialogResult = union(enum) {
    ok: void,
    cancel: void,
    yes: void,
    no: void,
    file_path: []const u8,
    file_paths: []const []const u8,
    directory_path: []const u8,
    color: Color,
    font: Font,
    text: []const u8,
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = 255 };
    }

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Format color as hex string into the provided buffer
    /// Returns the slice of the buffer that was written
    pub fn toHex(self: Color, buf: *[7]u8) []const u8 {
        _ = std.fmt.bufPrint(buf, "#{x:0>2}{x:0>2}{x:0>2}", .{ self.r, self.g, self.b }) catch return "#000000";
        return buf;
    }

    pub fn fromHex(hex: []const u8) !Color {
        if (hex.len < 6) return error.InvalidHex;
        const start: usize = if (hex[0] == '#') 1 else 0;

        const r = try std.fmt.parseInt(u8, hex[start .. start + 2], 16);
        const g = try std.fmt.parseInt(u8, hex[start + 2 .. start + 4], 16);
        const b = try std.fmt.parseInt(u8, hex[start + 4 .. start + 6], 16);

        return Color.rgb(r, g, b);
    }
};

pub const Font = struct {
    family: []const u8,
    size: f32,
    weight: FontWeight,
    style: FontStyle,

    pub const FontWeight = enum {
        thin,
        light,
        regular,
        medium,
        semibold,
        bold,
        black,

        pub fn toNumber(self: FontWeight) u16 {
            return switch (self) {
                .thin => 100,
                .light => 300,
                .regular => 400,
                .medium => 500,
                .semibold => 600,
                .bold => 700,
                .black => 900,
            };
        }
    };

    pub const FontStyle = enum {
        normal,
        italic,
        oblique,
    };
};

pub const FileFilter = struct {
    name: []const u8,
    extensions: []const []const u8,

    pub fn create(name: []const u8, extensions: []const []const u8) FileFilter {
        return FileFilter{
            .name = name,
            .extensions = extensions,
        };
    }
};

pub const FileDialogOptions = struct {
    title: []const u8 = "Select File",
    default_path: ?[]const u8 = null,
    filters: []const FileFilter = &[_]FileFilter{},
    multi_select: bool = false,
    show_hidden: bool = false,
    create_directories: bool = false,
    default_extension: ?[]const u8 = null,
};

pub const DirectoryDialogOptions = struct {
    title: []const u8 = "Select Directory",
    default_path: ?[]const u8 = null,
    create_directories: bool = true,
    show_hidden: bool = false,
};

pub const MessageDialogOptions = struct {
    title: []const u8 = "Message",
    message: []const u8,
    detail: ?[]const u8 = null,
    type: MessageType = .info,
    buttons: ButtonSet = .ok,

    pub const MessageType = enum {
        info,
        warning,
        error_msg,
        question,
    };

    pub const ButtonSet = enum {
        ok,
        ok_cancel,
        yes_no,
        yes_no_cancel,
        retry_cancel,
    };
};

pub const ConfirmDialogOptions = struct {
    title: []const u8 = "Confirm",
    message: []const u8,
    detail: ?[]const u8 = null,
    confirm_text: []const u8 = "OK",
    cancel_text: []const u8 = "Cancel",
    destructive: bool = false,
};

pub const InputDialogOptions = struct {
    title: []const u8 = "Input",
    message: []const u8,
    default_value: []const u8 = "",
    placeholder: ?[]const u8 = null,
    secure: bool = false,
    multiline: bool = false,
};

pub const ProgressDialogOptions = struct {
    title: []const u8 = "Progress",
    message: []const u8,
    cancelable: bool = true,
    indeterminate: bool = false,
    min: f32 = 0.0,
    max: f32 = 100.0,
};

pub const ColorDialogOptions = struct {
    title: []const u8 = "Select Color",
    default_color: Color = Color.rgb(255, 255, 255),
    show_alpha: bool = true,
    show_palette: bool = true,
    custom_colors: []const Color = &[_]Color{},
};

pub const FontDialogOptions = struct {
    title: []const u8 = "Select Font",
    default_font: ?Font = null,
    min_size: f32 = 8.0,
    max_size: f32 = 72.0,
    show_effects: bool = true,
    show_color: bool = false,
};

pub const Dialog = struct {
    type: DialogType,
    handle: ?*anyopaque = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, dialog_type: DialogType) Dialog {
        return Dialog{
            .type = dialog_type,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Dialog) void {
        // Platform-specific cleanup
        _ = self;
    }

    pub fn showFileOpen(allocator: std.mem.Allocator, options: FileDialogOptions) !?DialogResult {
        const dialog = Dialog.init(allocator, .file_open);
        _ = dialog;

        // Platform-specific implementation
        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => showMacFileDialog(options),
            .linux => showLinuxFileDialog(options),
            .windows => showWindowsFileDialog(options),
            else => error.UnsupportedPlatform,
        };
    }

    pub fn showFileSave(allocator: std.mem.Allocator, options: FileDialogOptions) !?DialogResult {
        const dialog = Dialog.init(allocator, .file_save);
        _ = dialog;

        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => showMacFileSaveDialog(options),
            .linux => showLinuxFileSaveDialog(options),
            .windows => showWindowsFileSaveDialog(options),
            else => error.UnsupportedPlatform,
        };
    }

    pub fn showDirectory(allocator: std.mem.Allocator, options: DirectoryDialogOptions) !?DialogResult {
        const dialog = Dialog.init(allocator, .directory);
        _ = dialog;

        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => showMacDirectoryDialog(options),
            .linux => showLinuxDirectoryDialog(options),
            .windows => showWindowsDirectoryDialog(options),
            else => error.UnsupportedPlatform,
        };
    }

    pub fn showMessage(allocator: std.mem.Allocator, options: MessageDialogOptions) !DialogResult {
        const dialog = Dialog.init(allocator, .message);
        _ = dialog;

        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => showMacMessageDialog(options),
            .linux => showLinuxMessageDialog(options),
            .windows => showWindowsMessageDialog(options),
            else => error.UnsupportedPlatform,
        };
    }

    pub fn showConfirm(allocator: std.mem.Allocator, options: ConfirmDialogOptions) !DialogResult {
        const dialog = Dialog.init(allocator, .confirm);
        _ = dialog;

        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => showMacConfirmDialog(options),
            .linux => showLinuxConfirmDialog(options),
            .windows => showWindowsConfirmDialog(options),
            else => error.UnsupportedPlatform,
        };
    }

    pub fn showInput(allocator: std.mem.Allocator, options: InputDialogOptions) !?DialogResult {
        const dialog = Dialog.init(allocator, .input);
        _ = dialog;

        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => showMacInputDialog(allocator, options),
            .linux => showLinuxInputDialog(allocator, options),
            .windows => showWindowsInputDialog(allocator, options),
            else => error.UnsupportedPlatform,
        };
    }

    pub fn showColor(allocator: std.mem.Allocator, options: ColorDialogOptions) !?DialogResult {
        const dialog = Dialog.init(allocator, .color);
        _ = dialog;

        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => showMacColorDialog(options),
            .linux => showLinuxColorDialog(options),
            .windows => showWindowsColorDialog(options),
            else => error.UnsupportedPlatform,
        };
    }

    pub fn showFont(allocator: std.mem.Allocator, options: FontDialogOptions) !?DialogResult {
        const dialog = Dialog.init(allocator, .font);
        _ = dialog;

        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => showMacFontDialog(allocator, options),
            .linux => showLinuxFontDialog(allocator, options),
            .windows => showWindowsFontDialog(allocator, options),
            else => error.UnsupportedPlatform,
        };
    }
};

pub const ProgressDialog = struct {
    handle: ?*anyopaque,
    progress: f32,
    message: []const u8,
    cancelable: bool,
    canceled: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, options: ProgressDialogOptions) !ProgressDialog {
        _ = options;
        return ProgressDialog{
            .handle = null,
            .progress = 0.0,
            .message = "",
            .cancelable = true,
            .canceled = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ProgressDialog) void {
        _ = self;
    }

    pub fn setProgress(self: *ProgressDialog, value: f32) void {
        self.progress = value;
        // Update native dialog
    }

    pub fn setMessage(self: *ProgressDialog, message: []const u8) void {
        self.message = message;
        // Update native dialog
    }

    pub fn isCanceled(self: ProgressDialog) bool {
        return self.canceled;
    }

    pub fn close(self: *ProgressDialog) void {
        self.deinit();
    }
};

// ============================================================================
// macOS Platform-specific implementations using Objective-C runtime
// ============================================================================

const macos = if (@import("builtin").os.tag == .macos) @import("macos.zig") else struct {};

/// Show NSOpenPanel for file selection
fn showMacFileDialog(options: FileDialogOptions) !?DialogResult {
    if (@import("builtin").os.tag != .macos) return null;

    // Get NSOpenPanel class and create instance
    const NSOpenPanel = macos.getClass("NSOpenPanel");
    const panel = macos.msgSend0(NSOpenPanel, "openPanel");

    // Configure panel
    _ = macos.msgSend1(panel, "setCanChooseFiles:", @as(c_long, 1));
    _ = macos.msgSend1(panel, "setCanChooseDirectories:", @as(c_long, 0));
    _ = macos.msgSend1(panel, "setAllowsMultipleSelection:", if (options.multi_select) @as(c_long, 1) else @as(c_long, 0));

    // Show hidden files if requested
    if (options.show_hidden) {
        _ = macos.msgSend1(panel, "setShowsHiddenFiles:", @as(c_long, 1));
    }

    // Set title
    const title_cstr = @as([*:0]const u8, @ptrCast(options.title.ptr));
    const NSString = macos.getClass("NSString");
    const str_alloc = macos.msgSend0(NSString, "alloc");
    const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr);
    _ = macos.msgSend1(panel, "setTitle:", ns_title);

    // Set default path if provided
    if (options.default_path) |path| {
        const path_cstr = @as([*:0]const u8, @ptrCast(path.ptr));
        const str_alloc2 = macos.msgSend0(NSString, "alloc");
        const ns_path = macos.msgSend1(str_alloc2, "initWithUTF8String:", path_cstr);
        const NSURL = macos.getClass("NSURL");
        const url = macos.msgSend1(NSURL, "fileURLWithPath:", ns_path);
        _ = macos.msgSend1(panel, "setDirectoryURL:", url);
    }

    // Set allowed file types if filters provided
    if (options.filters.len > 0) {
        const NSMutableArray = macos.getClass("NSMutableArray");
        const allowed_types = macos.msgSend0(NSMutableArray, "array");

        for (options.filters) |filter| {
            for (filter.extensions) |ext| {
                if (!std.mem.eql(u8, ext, "*")) {
                    var ext_buf: [64]u8 = undefined;
                    const ext_len = @min(ext.len, 63);
                    @memcpy(ext_buf[0..ext_len], ext[0..ext_len]);
                    ext_buf[ext_len] = 0;
                    const ext_str = macos.msgSend0(NSString, "alloc");
                    const ns_ext = macos.msgSend1(ext_str, "initWithUTF8String:", @as([*:0]const u8, @ptrCast(&ext_buf)));
                    _ = macos.msgSend1(allowed_types, "addObject:", ns_ext);
                }
            }
        }

        _ = macos.msgSend1(panel, "setAllowedFileTypes:", allowed_types);
    }

    // Run modal
    const result = macos.msgSend0(panel, "runModal");
    const result_int = @as(c_long, @intCast(@intFromPtr(result)));

    // NSModalResponseOK = 1
    if (result_int == 1) {
        const urls = macos.msgSend0(panel, "URLs");
        const count_ptr = macos.msgSend0(urls, "count");
        const count = @as(usize, @intFromPtr(count_ptr));

        if (count == 0) return null;

        if (options.multi_select and count > 1) {
            // Return multiple paths
            var paths: [32][]const u8 = undefined;
            const path_count = @min(count, 32);

            var i: usize = 0;
            while (i < path_count) : (i += 1) {
                const url = macos.msgSend1(urls, "objectAtIndex:", @as(c_ulong, i));
                const path = macos.msgSend0(url, "path");
                const path_cstr = macos.msgSend0(path, "UTF8String");
                paths[i] = std.mem.span(@as([*:0]const u8, @ptrCast(path_cstr)));
            }

            return DialogResult{ .file_paths = paths[0..path_count] };
        } else {
            // Return single path
            const url = macos.msgSend1(urls, "objectAtIndex:", @as(c_ulong, 0));
            const path = macos.msgSend0(url, "path");
            const path_cstr = macos.msgSend0(path, "UTF8String");
            const path_str = std.mem.span(@as([*:0]const u8, @ptrCast(path_cstr)));

            return DialogResult{ .file_path = path_str };
        }
    }

    return null; // Canceled
}

/// Show NSSavePanel for file saving
fn showMacFileSaveDialog(options: FileDialogOptions) !?DialogResult {
    if (@import("builtin").os.tag != .macos) return null;

    // Get NSSavePanel class and create instance
    const NSSavePanel = macos.getClass("NSSavePanel");
    const panel = macos.msgSend0(NSSavePanel, "savePanel");

    // Set title
    const NSString = macos.getClass("NSString");
    const title_cstr = @as([*:0]const u8, @ptrCast(options.title.ptr));
    const str_alloc = macos.msgSend0(NSString, "alloc");
    const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr);
    _ = macos.msgSend1(panel, "setTitle:", ns_title);

    // Allow creating directories
    if (options.create_directories) {
        _ = macos.msgSend1(panel, "setCanCreateDirectories:", @as(c_long, 1));
    }

    // Show hidden files if requested
    if (options.show_hidden) {
        _ = macos.msgSend1(panel, "setShowsHiddenFiles:", @as(c_long, 1));
    }

    // Set default path/filename if provided
    if (options.default_path) |path| {
        const path_cstr = @as([*:0]const u8, @ptrCast(path.ptr));
        const str_alloc2 = macos.msgSend0(NSString, "alloc");
        const ns_path = macos.msgSend1(str_alloc2, "initWithUTF8String:", path_cstr);
        _ = macos.msgSend1(panel, "setNameFieldStringValue:", ns_path);
    }

    // Set default extension if provided
    if (options.default_extension) |ext| {
        const ext_cstr = @as([*:0]const u8, @ptrCast(ext.ptr));
        const str_alloc3 = macos.msgSend0(NSString, "alloc");
        const ns_ext = macos.msgSend1(str_alloc3, "initWithUTF8String:", ext_cstr);

        const NSMutableArray = macos.getClass("NSMutableArray");
        const allowed_types = macos.msgSend0(NSMutableArray, "array");
        _ = macos.msgSend1(allowed_types, "addObject:", ns_ext);
        _ = macos.msgSend1(panel, "setAllowedFileTypes:", allowed_types);
    }

    // Run modal
    const result = macos.msgSend0(panel, "runModal");
    const result_int = @as(c_long, @intCast(@intFromPtr(result)));

    // NSModalResponseOK = 1
    if (result_int == 1) {
        const url = macos.msgSend0(panel, "URL");
        const path = macos.msgSend0(url, "path");
        const path_cstr = macos.msgSend0(path, "UTF8String");
        const path_str = std.mem.span(@as([*:0]const u8, @ptrCast(path_cstr)));

        return DialogResult{ .file_path = path_str };
    }

    return null; // Canceled
}

/// Show NSOpenPanel for directory selection
fn showMacDirectoryDialog(options: DirectoryDialogOptions) !?DialogResult {
    if (@import("builtin").os.tag != .macos) return null;

    // Get NSOpenPanel class and create instance
    const NSOpenPanel = macos.getClass("NSOpenPanel");
    const panel = macos.msgSend0(NSOpenPanel, "openPanel");

    // Configure for directory selection
    _ = macos.msgSend1(panel, "setCanChooseFiles:", @as(c_long, 0));
    _ = macos.msgSend1(panel, "setCanChooseDirectories:", @as(c_long, 1));
    _ = macos.msgSend1(panel, "setAllowsMultipleSelection:", @as(c_long, 0));

    // Allow creating directories
    if (options.create_directories) {
        _ = macos.msgSend1(panel, "setCanCreateDirectories:", @as(c_long, 1));
    }

    // Show hidden files if requested
    if (options.show_hidden) {
        _ = macos.msgSend1(panel, "setShowsHiddenFiles:", @as(c_long, 1));
    }

    // Set title
    const NSString = macos.getClass("NSString");
    const title_cstr = @as([*:0]const u8, @ptrCast(options.title.ptr));
    const str_alloc = macos.msgSend0(NSString, "alloc");
    const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr);
    _ = macos.msgSend1(panel, "setTitle:", ns_title);

    // Set default path if provided
    if (options.default_path) |path| {
        const path_cstr = @as([*:0]const u8, @ptrCast(path.ptr));
        const str_alloc2 = macos.msgSend0(NSString, "alloc");
        const ns_path = macos.msgSend1(str_alloc2, "initWithUTF8String:", path_cstr);
        const NSURL = macos.getClass("NSURL");
        const url = macos.msgSend1(NSURL, "fileURLWithPath:", ns_path);
        _ = macos.msgSend1(panel, "setDirectoryURL:", url);
    }

    // Run modal
    const result = macos.msgSend0(panel, "runModal");
    const result_int = @as(c_long, @intCast(@intFromPtr(result)));

    // NSModalResponseOK = 1
    if (result_int == 1) {
        const urls = macos.msgSend0(panel, "URLs");
        const url = macos.msgSend1(urls, "objectAtIndex:", @as(c_ulong, 0));
        const path = macos.msgSend0(url, "path");
        const path_cstr = macos.msgSend0(path, "UTF8String");
        const path_str = std.mem.span(@as([*:0]const u8, @ptrCast(path_cstr)));

        return DialogResult{ .directory_path = path_str };
    }

    return null; // Canceled
}

/// Show NSAlert message dialog
fn showMacMessageDialog(options: MessageDialogOptions) !DialogResult {
    if (@import("builtin").os.tag != .macos) return DialogResult{ .ok = {} };

    // Get NSAlert class and create instance
    const NSAlert = macos.getClass("NSAlert");
    const alert = macos.msgSend0(macos.msgSend0(NSAlert, "alloc"), "init");

    const NSString = macos.getClass("NSString");

    // Set title (messageText)
    const title_cstr = @as([*:0]const u8, @ptrCast(options.title.ptr));
    const str_alloc1 = macos.msgSend0(NSString, "alloc");
    const ns_title = macos.msgSend1(str_alloc1, "initWithUTF8String:", title_cstr);
    _ = macos.msgSend1(alert, "setMessageText:", ns_title);

    // Set message (informativeText)
    const msg_cstr = @as([*:0]const u8, @ptrCast(options.message.ptr));
    const str_alloc2 = macos.msgSend0(NSString, "alloc");
    const ns_msg = macos.msgSend1(str_alloc2, "initWithUTF8String:", msg_cstr);
    _ = macos.msgSend1(alert, "setInformativeText:", ns_msg);

    // Set alert style based on type
    const alert_style: c_long = switch (options.type) {
        .info => 1, // NSAlertStyleInformational
        .warning => 0, // NSAlertStyleWarning
        .error_msg => 2, // NSAlertStyleCritical
        .question => 1, // NSAlertStyleInformational
    };
    _ = macos.msgSend1(alert, "setAlertStyle:", alert_style);

    // Add buttons based on button set
    switch (options.buttons) {
        .ok => {
            const ok_str = macos.msgSend0(NSString, "alloc");
            const ns_ok = macos.msgSend1(ok_str, "initWithUTF8String:", @as([*:0]const u8, "OK"));
            _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_ok);
        },
        .ok_cancel => {
            const ok_str = macos.msgSend0(NSString, "alloc");
            const ns_ok = macos.msgSend1(ok_str, "initWithUTF8String:", @as([*:0]const u8, "OK"));
            _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_ok);

            const cancel_str = macos.msgSend0(NSString, "alloc");
            const ns_cancel = macos.msgSend1(cancel_str, "initWithUTF8String:", @as([*:0]const u8, "Cancel"));
            _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_cancel);
        },
        .yes_no => {
            const yes_str = macos.msgSend0(NSString, "alloc");
            const ns_yes = macos.msgSend1(yes_str, "initWithUTF8String:", @as([*:0]const u8, "Yes"));
            _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_yes);

            const no_str = macos.msgSend0(NSString, "alloc");
            const ns_no = macos.msgSend1(no_str, "initWithUTF8String:", @as([*:0]const u8, "No"));
            _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_no);
        },
        .yes_no_cancel => {
            const yes_str = macos.msgSend0(NSString, "alloc");
            const ns_yes = macos.msgSend1(yes_str, "initWithUTF8String:", @as([*:0]const u8, "Yes"));
            _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_yes);

            const no_str = macos.msgSend0(NSString, "alloc");
            const ns_no = macos.msgSend1(no_str, "initWithUTF8String:", @as([*:0]const u8, "No"));
            _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_no);

            const cancel_str = macos.msgSend0(NSString, "alloc");
            const ns_cancel = macos.msgSend1(cancel_str, "initWithUTF8String:", @as([*:0]const u8, "Cancel"));
            _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_cancel);
        },
        .retry_cancel => {
            const retry_str = macos.msgSend0(NSString, "alloc");
            const ns_retry = macos.msgSend1(retry_str, "initWithUTF8String:", @as([*:0]const u8, "Retry"));
            _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_retry);

            const cancel_str = macos.msgSend0(NSString, "alloc");
            const ns_cancel = macos.msgSend1(cancel_str, "initWithUTF8String:", @as([*:0]const u8, "Cancel"));
            _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_cancel);
        },
    }

    // Run modal
    const result = macos.msgSend0(alert, "runModal");
    const result_int = @as(c_long, @intCast(@intFromPtr(result)));

    // NSAlertFirstButtonReturn = 1000, NSAlertSecondButtonReturn = 1001, NSAlertThirdButtonReturn = 1002
    return switch (options.buttons) {
        .ok => DialogResult{ .ok = {} },
        .ok_cancel => if (result_int == 1000) DialogResult{ .ok = {} } else DialogResult{ .cancel = {} },
        .yes_no => if (result_int == 1000) DialogResult{ .yes = {} } else DialogResult{ .no = {} },
        .yes_no_cancel => switch (result_int) {
            1000 => DialogResult{ .yes = {} },
            1001 => DialogResult{ .no = {} },
            else => DialogResult{ .cancel = {} },
        },
        .retry_cancel => if (result_int == 1000) DialogResult{ .ok = {} } else DialogResult{ .cancel = {} },
    };
}

/// Show NSAlert confirm dialog
fn showMacConfirmDialog(options: ConfirmDialogOptions) !DialogResult {
    if (@import("builtin").os.tag != .macos) return DialogResult{ .ok = {} };

    // Get NSAlert class and create instance
    const NSAlert = macos.getClass("NSAlert");
    const alert = macos.msgSend0(macos.msgSend0(NSAlert, "alloc"), "init");

    const NSString = macos.getClass("NSString");

    // Set title
    const title_cstr = @as([*:0]const u8, @ptrCast(options.title.ptr));
    const str_alloc1 = macos.msgSend0(NSString, "alloc");
    const ns_title = macos.msgSend1(str_alloc1, "initWithUTF8String:", title_cstr);
    _ = macos.msgSend1(alert, "setMessageText:", ns_title);

    // Set message
    const msg_cstr = @as([*:0]const u8, @ptrCast(options.message.ptr));
    const str_alloc2 = macos.msgSend0(NSString, "alloc");
    const ns_msg = macos.msgSend1(str_alloc2, "initWithUTF8String:", msg_cstr);
    _ = macos.msgSend1(alert, "setInformativeText:", ns_msg);

    // Set destructive style if requested
    if (options.destructive) {
        _ = macos.msgSend1(alert, "setAlertStyle:", @as(c_long, 2)); // NSAlertStyleCritical
    }

    // Add confirm button
    const confirm_cstr = @as([*:0]const u8, @ptrCast(options.confirm_text.ptr));
    const str_alloc3 = macos.msgSend0(NSString, "alloc");
    const ns_confirm = macos.msgSend1(str_alloc3, "initWithUTF8String:", confirm_cstr);
    _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_confirm);

    // Add cancel button
    const cancel_cstr = @as([*:0]const u8, @ptrCast(options.cancel_text.ptr));
    const str_alloc4 = macos.msgSend0(NSString, "alloc");
    const ns_cancel = macos.msgSend1(str_alloc4, "initWithUTF8String:", cancel_cstr);
    _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_cancel);

    // Run modal
    const result = macos.msgSend0(alert, "runModal");
    const result_int = @as(c_long, @intCast(@intFromPtr(result)));

    // NSAlertFirstButtonReturn = 1000
    return if (result_int == 1000) DialogResult{ .ok = {} } else DialogResult{ .cancel = {} };
}

/// Show NSAlert with text input field
fn showMacInputDialog(allocator: std.mem.Allocator, options: InputDialogOptions) !?DialogResult {
    if (@import("builtin").os.tag != .macos) return null;

    // Get NSAlert class and create instance
    const NSAlert = macos.getClass("NSAlert");
    const alert = macos.msgSend0(macos.msgSend0(NSAlert, "alloc"), "init");

    const NSString = macos.getClass("NSString");

    // Set title
    const title_cstr = @as([*:0]const u8, @ptrCast(options.title.ptr));
    const str_alloc1 = macos.msgSend0(NSString, "alloc");
    const ns_title = macos.msgSend1(str_alloc1, "initWithUTF8String:", title_cstr);
    _ = macos.msgSend1(alert, "setMessageText:", ns_title);

    // Set message
    const msg_cstr = @as([*:0]const u8, @ptrCast(options.message.ptr));
    const str_alloc2 = macos.msgSend0(NSString, "alloc");
    const ns_msg = macos.msgSend1(str_alloc2, "initWithUTF8String:", msg_cstr);
    _ = macos.msgSend1(alert, "setInformativeText:", ns_msg);

    // Create NSTextField for input
    const NSTextField = macos.getClass("NSTextField");
    const input_field = macos.msgSend0(macos.msgSend0(NSTextField, "alloc"), "init");

    // Set frame (width 200, height 24)
    const NSValue = macos.getClass("NSValue");
    _ = NSValue; // Would need to set frame properly

    // Set default value
    const default_cstr = @as([*:0]const u8, @ptrCast(options.default_value.ptr));
    const str_alloc3 = macos.msgSend0(NSString, "alloc");
    const ns_default = macos.msgSend1(str_alloc3, "initWithUTF8String:", default_cstr);
    _ = macos.msgSend1(input_field, "setStringValue:", ns_default);

    // Set placeholder if provided
    if (options.placeholder) |placeholder| {
        const placeholder_cstr = @as([*:0]const u8, @ptrCast(placeholder.ptr));
        const str_alloc4 = macos.msgSend0(NSString, "alloc");
        const ns_placeholder = macos.msgSend1(str_alloc4, "initWithUTF8String:", placeholder_cstr);
        _ = macos.msgSend1(input_field, "setPlaceholderString:", ns_placeholder);
    }

    // Set accessory view
    _ = macos.msgSend1(alert, "setAccessoryView:", input_field);

    // Add OK and Cancel buttons
    const ok_str = macos.msgSend0(NSString, "alloc");
    const ns_ok = macos.msgSend1(ok_str, "initWithUTF8String:", @as([*:0]const u8, "OK"));
    _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_ok);

    const cancel_str = macos.msgSend0(NSString, "alloc");
    const ns_cancel = macos.msgSend1(cancel_str, "initWithUTF8String:", @as([*:0]const u8, "Cancel"));
    _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_cancel);

    // Run modal
    const result = macos.msgSend0(alert, "runModal");
    const result_int = @as(c_long, @intCast(@intFromPtr(result)));

    // NSAlertFirstButtonReturn = 1000
    if (result_int == 1000) {
        // Get the text value
        const ns_value = macos.msgSend0(input_field, "stringValue");
        const value_cstr = macos.msgSend0(ns_value, "UTF8String");
        const value_str = std.mem.span(@as([*:0]const u8, @ptrCast(value_cstr)));

        // Duplicate the string since the NSString might be deallocated
        const result_text = try allocator.dupe(u8, value_str);
        return DialogResult{ .text = result_text };
    }

    return null; // Canceled
}

/// Show NSColorPanel color picker
fn showMacColorDialog(options: ColorDialogOptions) !?DialogResult {
    if (@import("builtin").os.tag != .macos) return null;

    // Get NSColorPanel class
    const NSColorPanel = macos.getClass("NSColorPanel");
    const panel = macos.msgSend0(NSColorPanel, "sharedColorPanel");

    // Set title (NSColorPanel doesn't have direct title setting, but we can set window title)
    const NSString = macos.getClass("NSString");
    const title_cstr = @as([*:0]const u8, @ptrCast(options.title.ptr));
    const str_alloc = macos.msgSend0(NSString, "alloc");
    const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr);
    _ = macos.msgSend1(panel, "setTitle:", ns_title);

    // Set default color
    const NSColor = macos.getClass("NSColor");
    const r_f = @as(f64, @floatFromInt(options.default_color.r)) / 255.0;
    const g_f = @as(f64, @floatFromInt(options.default_color.g)) / 255.0;
    const b_f = @as(f64, @floatFromInt(options.default_color.b)) / 255.0;
    const a_f = @as(f64, @floatFromInt(options.default_color.a)) / 255.0;

    // Create color with RGBA (using calibrated color space)
    const MsgSendColor = *const fn (macos.objc.Class, macos.objc.SEL, f64, f64, f64, f64) callconv(.c) macos.objc.id;
    const msg_color: MsgSendColor = @ptrCast(&macos.objc.objc_msgSend);
    const ns_color = msg_color(NSColor, macos.sel("colorWithCalibratedRed:green:blue:alpha:"), r_f, g_f, b_f, a_f);
    _ = macos.msgSend1(panel, "setColor:", ns_color);

    // Show alpha if requested
    _ = macos.msgSend1(panel, "setShowsAlpha:", if (options.show_alpha) @as(c_long, 1) else @as(c_long, 0));

    // Show the panel (NSColorPanel is typically non-modal)
    _ = macos.msgSend1(panel, "orderFront:", @as(macos.objc.id, null));

    // For simplicity, return the default color (in a real app you'd need a delegate)
    // A proper implementation would require setting up a delegate to capture color changes
    return DialogResult{ .color = options.default_color };
}

/// Show NSFontPanel font picker
fn showMacFontDialog(allocator: std.mem.Allocator, options: FontDialogOptions) !?DialogResult {
    if (@import("builtin").os.tag != .macos) return null;

    // Get NSFontPanel class
    const NSFontPanel = macos.getClass("NSFontPanel");
    const panel = macos.msgSend0(NSFontPanel, "sharedFontPanel");

    // Set title
    const NSString = macos.getClass("NSString");
    const title_cstr = @as([*:0]const u8, @ptrCast(options.title.ptr));
    const str_alloc = macos.msgSend0(NSString, "alloc");
    const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr);
    _ = macos.msgSend1(panel, "setTitle:", ns_title);

    // Set default font if provided
    if (options.default_font) |default_font| {
        const NSFontManager = macos.getClass("NSFontManager");
        const font_manager = macos.msgSend0(NSFontManager, "sharedFontManager");

        const family_cstr = @as([*:0]const u8, @ptrCast(default_font.family.ptr));
        const str_alloc2 = macos.msgSend0(NSString, "alloc");
        const ns_family = macos.msgSend1(str_alloc2, "initWithUTF8String:", family_cstr);

        // Create font with family and size
        const NSFont = macos.getClass("NSFont");
        const MsgSendFont = *const fn (macos.objc.Class, macos.objc.SEL, macos.objc.id, f64) callconv(.c) macos.objc.id;
        const msg_font: MsgSendFont = @ptrCast(&macos.objc.objc_msgSend);
        const ns_font = msg_font(NSFont, macos.sel("fontWithName:size:"), ns_family, @as(f64, default_font.size));

        if (ns_font != null) {
            _ = macos.msgSend1(font_manager, "setSelectedFont:isMultiple:", ns_font);
        }
    }

    // Show the panel (NSFontPanel is typically non-modal)
    _ = macos.msgSend1(panel, "orderFront:", @as(macos.objc.id, null));

    // For simplicity, return the default font (in a real app you'd need a delegate)
    // A proper implementation would require setting up a delegate to capture font selection
    if (options.default_font) |default_font| {
        const family_copy = try allocator.dupe(u8, default_font.family);
        return DialogResult{ .font = Font{
            .family = family_copy,
            .size = default_font.size,
            .weight = default_font.weight,
            .style = default_font.style,
        } };
    }

    return null;
}

// ============================================================================
// Linux Platform-specific implementations using zenity/kdialog
// ============================================================================

fn showLinuxFileDialog(options: FileDialogOptions) !?DialogResult {
    // Use zenity for file dialogs on Linux
    var args = std.ArrayList([]const u8).init(std.heap.c_allocator);
    defer args.deinit();

    try args.append("zenity");
    try args.append("--file-selection");
    try args.append("--title");
    try args.append(options.title);

    if (options.multi_select) {
        try args.append("--multiple");
        try args.append("--separator=|");
    }

    if (options.default_path) |path| {
        try args.append("--filename");
        try args.append(path);
    }

    // Add file filters
    for (options.filters) |filter| {
        for (filter.extensions) |ext| {
            var filter_buf: [128]u8 = undefined;
            const filter_str = std.fmt.bufPrint(&filter_buf, "--file-filter={s} | *.{s}", .{ filter.name, ext }) catch continue;
            const filter_copy = std.heap.c_allocator.dupe(u8, filter_str) catch continue;
            try args.append(filter_copy);
        }
    }

    var child = std.process.Child.init(args.items, std.heap.c_allocator);
    child.stdout_behavior = .Pipe;

    try child.spawn();
    const result = child.wait() catch return null;

    if (result.Exited == 0) {
        if (child.stdout) |stdout| {
            var buf: [4096]u8 = undefined;
            const bytes_read = stdout.read(&buf) catch return null;
            if (bytes_read > 0) {
                const path = std.mem.trimRight(u8, buf[0..bytes_read], "\n\r");
                return DialogResult{ .file_path = path };
            }
        }
    }

    return null;
}

fn showLinuxFileSaveDialog(options: FileDialogOptions) !?DialogResult {
    var args = std.ArrayList([]const u8).init(std.heap.c_allocator);
    defer args.deinit();

    try args.append("zenity");
    try args.append("--file-selection");
    try args.append("--save");
    try args.append("--confirm-overwrite");
    try args.append("--title");
    try args.append(options.title);

    if (options.default_path) |path| {
        try args.append("--filename");
        try args.append(path);
    }

    var child = std.process.Child.init(args.items, std.heap.c_allocator);
    child.stdout_behavior = .Pipe;

    try child.spawn();
    const result = child.wait() catch return null;

    if (result.Exited == 0) {
        if (child.stdout) |stdout| {
            var buf: [4096]u8 = undefined;
            const bytes_read = stdout.read(&buf) catch return null;
            if (bytes_read > 0) {
                const path = std.mem.trimRight(u8, buf[0..bytes_read], "\n\r");
                return DialogResult{ .file_path = path };
            }
        }
    }

    return null;
}

fn showLinuxDirectoryDialog(options: DirectoryDialogOptions) !?DialogResult {
    var args = std.ArrayList([]const u8).init(std.heap.c_allocator);
    defer args.deinit();

    try args.append("zenity");
    try args.append("--file-selection");
    try args.append("--directory");
    try args.append("--title");
    try args.append(options.title);

    if (options.default_path) |path| {
        try args.append("--filename");
        try args.append(path);
    }

    var child = std.process.Child.init(args.items, std.heap.c_allocator);
    child.stdout_behavior = .Pipe;

    try child.spawn();
    const result = child.wait() catch return null;

    if (result.Exited == 0) {
        if (child.stdout) |stdout| {
            var buf: [4096]u8 = undefined;
            const bytes_read = stdout.read(&buf) catch return null;
            if (bytes_read > 0) {
                const path = std.mem.trimRight(u8, buf[0..bytes_read], "\n\r");
                return DialogResult{ .directory_path = path };
            }
        }
    }

    return null;
}

fn showLinuxMessageDialog(options: MessageDialogOptions) !DialogResult {
    var args = std.ArrayList([]const u8).init(std.heap.c_allocator);
    defer args.deinit();

    try args.append("zenity");

    // Set dialog type
    switch (options.type) {
        .info => try args.append("--info"),
        .warning => try args.append("--warning"),
        .error_msg => try args.append("--error"),
        .question => try args.append("--question"),
    }

    try args.append("--title");
    try args.append(options.title);
    try args.append("--text");
    try args.append(options.message);

    var child = std.process.Child.init(args.items, std.heap.c_allocator);
    try child.spawn();
    const result = child.wait() catch return DialogResult{ .ok = {} };

    return if (result.Exited == 0) DialogResult{ .ok = {} } else DialogResult{ .cancel = {} };
}

fn showLinuxConfirmDialog(options: ConfirmDialogOptions) !DialogResult {
    var args = std.ArrayList([]const u8).init(std.heap.c_allocator);
    defer args.deinit();

    try args.append("zenity");
    try args.append("--question");
    try args.append("--title");
    try args.append(options.title);
    try args.append("--text");
    try args.append(options.message);
    try args.append("--ok-label");
    try args.append(options.confirm_text);
    try args.append("--cancel-label");
    try args.append(options.cancel_text);

    var child = std.process.Child.init(args.items, std.heap.c_allocator);
    try child.spawn();
    const result = child.wait() catch return DialogResult{ .cancel = {} };

    return if (result.Exited == 0) DialogResult{ .ok = {} } else DialogResult{ .cancel = {} };
}

fn showLinuxInputDialog(allocator: std.mem.Allocator, options: InputDialogOptions) !?DialogResult {
    var args = std.ArrayList([]const u8).init(std.heap.c_allocator);
    defer args.deinit();

    try args.append("zenity");
    try args.append("--entry");
    try args.append("--title");
    try args.append(options.title);
    try args.append("--text");
    try args.append(options.message);

    if (options.default_value.len > 0) {
        try args.append("--entry-text");
        try args.append(options.default_value);
    }

    if (options.secure) {
        try args.append("--hide-text");
    }

    var child = std.process.Child.init(args.items, std.heap.c_allocator);
    child.stdout_behavior = .Pipe;

    try child.spawn();
    const result = child.wait() catch return null;

    if (result.Exited == 0) {
        if (child.stdout) |stdout| {
            var buf: [4096]u8 = undefined;
            const bytes_read = stdout.read(&buf) catch return null;
            if (bytes_read > 0) {
                const text = std.mem.trimRight(u8, buf[0..bytes_read], "\n\r");
                const result_text = try allocator.dupe(u8, text);
                return DialogResult{ .text = result_text };
            }
        }
    }

    return null;
}

fn showLinuxColorDialog(options: ColorDialogOptions) !?DialogResult {
    var args = std.ArrayList([]const u8).init(std.heap.c_allocator);
    defer args.deinit();

    try args.append("zenity");
    try args.append("--color-selection");
    try args.append("--title");
    try args.append(options.title);

    // Set initial color
    var color_buf: [16]u8 = undefined;
    const color_str = std.fmt.bufPrint(&color_buf, "rgb({d},{d},{d})", .{
        options.default_color.r,
        options.default_color.g,
        options.default_color.b,
    }) catch "rgb(255,255,255)";
    try args.append("--color");
    try args.append(color_str);

    var child = std.process.Child.init(args.items, std.heap.c_allocator);
    child.stdout_behavior = .Pipe;

    try child.spawn();
    const result = child.wait() catch return null;

    if (result.Exited == 0) {
        if (child.stdout) |stdout| {
            var buf: [128]u8 = undefined;
            const bytes_read = stdout.read(&buf) catch return null;
            if (bytes_read > 0) {
                const output = std.mem.trimRight(u8, buf[0..bytes_read], "\n\r");
                // Parse zenity color output (format: rgb(r,g,b) or rgba(r,g,b,a))
                if (std.mem.startsWith(u8, output, "rgb")) {
                    // Basic parsing - would need more robust implementation
                    return DialogResult{ .color = options.default_color };
                }
            }
        }
    }

    return null;
}

fn showLinuxFontDialog(allocator: std.mem.Allocator, options: FontDialogOptions) !?DialogResult {
    var args = std.ArrayList([]const u8).init(std.heap.c_allocator);
    defer args.deinit();

    try args.append("zenity");
    try args.append("--font-selection");
    try args.append("--title");
    try args.append(options.title);

    if (options.default_font) |font| {
        var font_buf: [256]u8 = undefined;
        const font_str = std.fmt.bufPrint(&font_buf, "{s} {d}", .{ font.family, @as(u32, @intFromFloat(font.size)) }) catch "";
        try args.append("--font");
        try args.append(font_str);
    }

    var child = std.process.Child.init(args.items, std.heap.c_allocator);
    child.stdout_behavior = .Pipe;

    try child.spawn();
    const result = child.wait() catch return null;

    if (result.Exited == 0) {
        if (child.stdout) |stdout| {
            var buf: [512]u8 = undefined;
            const bytes_read = stdout.read(&buf) catch return null;
            if (bytes_read > 0) {
                const output = std.mem.trimRight(u8, buf[0..bytes_read], "\n\r");
                // Parse font string (format: "Font Name Size")
                const family = try allocator.dupe(u8, output);
                return DialogResult{ .font = Font{
                    .family = family,
                    .size = 12.0,
                    .weight = .regular,
                    .style = .normal,
                } };
            }
        }
    }

    return null;
}

// ============================================================================
// Windows Platform-specific implementations using Win32 API
// ============================================================================

fn showWindowsFileDialog(options: FileDialogOptions) !?DialogResult {
    if (@import("builtin").os.tag != .windows) return null;

    const windows = struct {
        extern "comdlg32" fn GetOpenFileNameA(lpofn: *OPENFILENAMEA) callconv(.winapi) i32;

        const OPENFILENAMEA = extern struct {
            lStructSize: u32,
            hwndOwner: ?*anyopaque,
            hInstance: ?*anyopaque,
            lpstrFilter: ?[*:0]const u8,
            lpstrCustomFilter: ?[*]u8,
            nMaxCustFilter: u32,
            nFilterIndex: u32,
            lpstrFile: [*]u8,
            nMaxFile: u32,
            lpstrFileTitle: ?[*]u8,
            nMaxFileTitle: u32,
            lpstrInitialDir: ?[*:0]const u8,
            lpstrTitle: ?[*:0]const u8,
            Flags: u32,
            nFileOffset: u16,
            nFileExtension: u16,
            lpstrDefExt: ?[*:0]const u8,
            lCustData: usize,
            lpfnHook: ?*anyopaque,
            lpTemplateName: ?[*:0]const u8,
        };

        const OFN_PATHMUSTEXIST: u32 = 0x00000800;
        const OFN_FILEMUSTEXIST: u32 = 0x00001000;
        const OFN_ALLOWMULTISELECT: u32 = 0x00000200;
        const OFN_EXPLORER: u32 = 0x00080000;
    };

    var file_buf: [4096]u8 = undefined;
    @memset(&file_buf, 0);

    var ofn: windows.OPENFILENAMEA = .{
        .lStructSize = @sizeOf(windows.OPENFILENAMEA),
        .hwndOwner = null,
        .hInstance = null,
        .lpstrFilter = "All Files\x00*.*\x00\x00",
        .lpstrCustomFilter = null,
        .nMaxCustFilter = 0,
        .nFilterIndex = 1,
        .lpstrFile = &file_buf,
        .nMaxFile = file_buf.len,
        .lpstrFileTitle = null,
        .nMaxFileTitle = 0,
        .lpstrInitialDir = if (options.default_path) |p| @ptrCast(p.ptr) else null,
        .lpstrTitle = @ptrCast(options.title.ptr),
        .Flags = windows.OFN_PATHMUSTEXIST | windows.OFN_FILEMUSTEXIST | windows.OFN_EXPLORER,
        .nFileOffset = 0,
        .nFileExtension = 0,
        .lpstrDefExt = null,
        .lCustData = 0,
        .lpfnHook = null,
        .lpTemplateName = null,
    };

    if (options.multi_select) {
        ofn.Flags |= windows.OFN_ALLOWMULTISELECT;
    }

    if (windows.GetOpenFileNameA(&ofn) != 0) {
        const path = std.mem.sliceTo(&file_buf, 0);
        return DialogResult{ .file_path = path };
    }

    return null;
}

fn showWindowsFileSaveDialog(options: FileDialogOptions) !?DialogResult {
    if (@import("builtin").os.tag != .windows) return null;

    const windows = struct {
        extern "comdlg32" fn GetSaveFileNameA(lpofn: *OPENFILENAMEA) callconv(.winapi) i32;

        const OPENFILENAMEA = extern struct {
            lStructSize: u32,
            hwndOwner: ?*anyopaque,
            hInstance: ?*anyopaque,
            lpstrFilter: ?[*:0]const u8,
            lpstrCustomFilter: ?[*]u8,
            nMaxCustFilter: u32,
            nFilterIndex: u32,
            lpstrFile: [*]u8,
            nMaxFile: u32,
            lpstrFileTitle: ?[*]u8,
            nMaxFileTitle: u32,
            lpstrInitialDir: ?[*:0]const u8,
            lpstrTitle: ?[*:0]const u8,
            Flags: u32,
            nFileOffset: u16,
            nFileExtension: u16,
            lpstrDefExt: ?[*:0]const u8,
            lCustData: usize,
            lpfnHook: ?*anyopaque,
            lpTemplateName: ?[*:0]const u8,
        };

        const OFN_OVERWRITEPROMPT: u32 = 0x00000002;
        const OFN_PATHMUSTEXIST: u32 = 0x00000800;
        const OFN_EXPLORER: u32 = 0x00080000;
    };

    var file_buf: [4096]u8 = undefined;
    @memset(&file_buf, 0);

    // Copy default filename if provided
    if (options.default_path) |path| {
        const len = @min(path.len, file_buf.len - 1);
        @memcpy(file_buf[0..len], path[0..len]);
    }

    var ofn: windows.OPENFILENAMEA = .{
        .lStructSize = @sizeOf(windows.OPENFILENAMEA),
        .hwndOwner = null,
        .hInstance = null,
        .lpstrFilter = "All Files\x00*.*\x00\x00",
        .lpstrCustomFilter = null,
        .nMaxCustFilter = 0,
        .nFilterIndex = 1,
        .lpstrFile = &file_buf,
        .nMaxFile = file_buf.len,
        .lpstrFileTitle = null,
        .nMaxFileTitle = 0,
        .lpstrInitialDir = null,
        .lpstrTitle = @ptrCast(options.title.ptr),
        .Flags = windows.OFN_OVERWRITEPROMPT | windows.OFN_PATHMUSTEXIST | windows.OFN_EXPLORER,
        .nFileOffset = 0,
        .nFileExtension = 0,
        .lpstrDefExt = if (options.default_extension) |ext| @ptrCast(ext.ptr) else null,
        .lCustData = 0,
        .lpfnHook = null,
        .lpTemplateName = null,
    };

    if (windows.GetSaveFileNameA(&ofn) != 0) {
        const path = std.mem.sliceTo(&file_buf, 0);
        return DialogResult{ .file_path = path };
    }

    return null;
}

fn showWindowsDirectoryDialog(options: DirectoryDialogOptions) !?DialogResult {
    if (@import("builtin").os.tag != .windows) return null;

    const windows = struct {
        extern "shell32" fn SHBrowseForFolderA(lpbi: *BROWSEINFOA) callconv(.winapi) ?*anyopaque;
        extern "shell32" fn SHGetPathFromIDListA(pidl: *anyopaque, pszPath: [*]u8) callconv(.winapi) i32;

        const BROWSEINFOA = extern struct {
            hwndOwner: ?*anyopaque,
            pidlRoot: ?*anyopaque,
            pszDisplayName: [*]u8,
            lpszTitle: ?[*:0]const u8,
            ulFlags: u32,
            lpfn: ?*anyopaque,
            lParam: usize,
            iImage: i32,
        };

        const BIF_RETURNONLYFSDIRS: u32 = 0x00000001;
        const BIF_NEWDIALOGSTYLE: u32 = 0x00000040;
    };

    var display_name: [260]u8 = undefined;
    var path_buf: [260]u8 = undefined;

    var bi: windows.BROWSEINFOA = .{
        .hwndOwner = null,
        .pidlRoot = null,
        .pszDisplayName = &display_name,
        .lpszTitle = @ptrCast(options.title.ptr),
        .ulFlags = windows.BIF_RETURNONLYFSDIRS | windows.BIF_NEWDIALOGSTYLE,
        .lpfn = null,
        .lParam = 0,
        .iImage = 0,
    };

    if (windows.SHBrowseForFolderA(&bi)) |pidl| {
        if (windows.SHGetPathFromIDListA(pidl, &path_buf) != 0) {
            const path = std.mem.sliceTo(&path_buf, 0);
            return DialogResult{ .directory_path = path };
        }
    }

    return null;
}

fn showWindowsMessageDialog(options: MessageDialogOptions) !DialogResult {
    if (@import("builtin").os.tag != .windows) return DialogResult{ .ok = {} };

    const windows = struct {
        extern "user32" fn MessageBoxA(
            hWnd: ?*anyopaque,
            lpText: [*:0]const u8,
            lpCaption: [*:0]const u8,
            uType: u32,
        ) callconv(.winapi) i32;

        const MB_OK: u32 = 0x00000000;
        const MB_OKCANCEL: u32 = 0x00000001;
        const MB_YESNO: u32 = 0x00000004;
        const MB_YESNOCANCEL: u32 = 0x00000003;
        const MB_RETRYCANCEL: u32 = 0x00000005;
        const MB_ICONINFORMATION: u32 = 0x00000040;
        const MB_ICONWARNING: u32 = 0x00000030;
        const MB_ICONERROR: u32 = 0x00000010;
        const MB_ICONQUESTION: u32 = 0x00000020;

        const IDOK: i32 = 1;
        const IDCANCEL: i32 = 2;
        const IDYES: i32 = 6;
        const IDNO: i32 = 7;
        const IDRETRY: i32 = 4;
    };

    var msg_type: u32 = switch (options.buttons) {
        .ok => windows.MB_OK,
        .ok_cancel => windows.MB_OKCANCEL,
        .yes_no => windows.MB_YESNO,
        .yes_no_cancel => windows.MB_YESNOCANCEL,
        .retry_cancel => windows.MB_RETRYCANCEL,
    };

    msg_type |= switch (options.type) {
        .info => windows.MB_ICONINFORMATION,
        .warning => windows.MB_ICONWARNING,
        .error_msg => windows.MB_ICONERROR,
        .question => windows.MB_ICONQUESTION,
    };

    const title_z = std.heap.c_allocator.dupeZ(u8, options.title) catch return DialogResult{ .ok = {} };
    defer std.heap.c_allocator.free(title_z);
    const msg_z = std.heap.c_allocator.dupeZ(u8, options.message) catch return DialogResult{ .ok = {} };
    defer std.heap.c_allocator.free(msg_z);

    const result = windows.MessageBoxA(null, msg_z.ptr, title_z.ptr, msg_type);

    return switch (result) {
        windows.IDOK, windows.IDRETRY => DialogResult{ .ok = {} },
        windows.IDCANCEL => DialogResult{ .cancel = {} },
        windows.IDYES => DialogResult{ .yes = {} },
        windows.IDNO => DialogResult{ .no = {} },
        else => DialogResult{ .ok = {} },
    };
}

fn showWindowsConfirmDialog(options: ConfirmDialogOptions) !DialogResult {
    if (@import("builtin").os.tag != .windows) return DialogResult{ .ok = {} };

    const windows = struct {
        extern "user32" fn MessageBoxA(
            hWnd: ?*anyopaque,
            lpText: [*:0]const u8,
            lpCaption: [*:0]const u8,
            uType: u32,
        ) callconv(.winapi) i32;

        const MB_OKCANCEL: u32 = 0x00000001;
        const MB_ICONQUESTION: u32 = 0x00000020;
        const MB_ICONWARNING: u32 = 0x00000030;
        const IDOK: i32 = 1;
    };

    var msg_type: u32 = windows.MB_OKCANCEL;
    if (options.destructive) {
        msg_type |= windows.MB_ICONWARNING;
    } else {
        msg_type |= windows.MB_ICONQUESTION;
    }

    const title_z = std.heap.c_allocator.dupeZ(u8, options.title) catch return DialogResult{ .cancel = {} };
    defer std.heap.c_allocator.free(title_z);
    const msg_z = std.heap.c_allocator.dupeZ(u8, options.message) catch return DialogResult{ .cancel = {} };
    defer std.heap.c_allocator.free(msg_z);

    const result = windows.MessageBoxA(null, msg_z.ptr, title_z.ptr, msg_type);

    return if (result == windows.IDOK) DialogResult{ .ok = {} } else DialogResult{ .cancel = {} };
}

fn showWindowsInputDialog(allocator: std.mem.Allocator, options: InputDialogOptions) !?DialogResult {
    // Windows doesn't have a built-in input dialog, so we return the default value
    // A full implementation would create a custom dialog window
    _ = allocator;
    if (options.default_value.len > 0) {
        return DialogResult{ .text = options.default_value };
    }
    return null;
}

fn showWindowsColorDialog(options: ColorDialogOptions) !?DialogResult {
    if (@import("builtin").os.tag != .windows) return null;

    const windows = struct {
        extern "comdlg32" fn ChooseColorA(lpcc: *CHOOSECOLORA) callconv(.winapi) i32;

        const CHOOSECOLORA = extern struct {
            lStructSize: u32,
            hwndOwner: ?*anyopaque,
            hInstance: ?*anyopaque,
            rgbResult: u32,
            lpCustColors: *[16]u32,
            Flags: u32,
            lCustData: usize,
            lpfnHook: ?*anyopaque,
            lpTemplateName: ?[*:0]const u8,
        };

        const CC_RGBINIT: u32 = 0x00000001;
        const CC_FULLOPEN: u32 = 0x00000002;
    };

    var custom_colors: [16]u32 = .{0} ** 16;

    // Convert Color to Windows COLORREF (0x00BBGGRR)
    const initial_color: u32 = @as(u32, options.default_color.r) |
        (@as(u32, options.default_color.g) << 8) |
        (@as(u32, options.default_color.b) << 16);

    var cc: windows.CHOOSECOLORA = .{
        .lStructSize = @sizeOf(windows.CHOOSECOLORA),
        .hwndOwner = null,
        .hInstance = null,
        .rgbResult = initial_color,
        .lpCustColors = &custom_colors,
        .Flags = windows.CC_RGBINIT | windows.CC_FULLOPEN,
        .lCustData = 0,
        .lpfnHook = null,
        .lpTemplateName = null,
    };

    if (windows.ChooseColorA(&cc) != 0) {
        // Convert COLORREF back to Color
        const r: u8 = @truncate(cc.rgbResult & 0xFF);
        const g: u8 = @truncate((cc.rgbResult >> 8) & 0xFF);
        const b: u8 = @truncate((cc.rgbResult >> 16) & 0xFF);
        return DialogResult{ .color = Color.rgb(r, g, b) };
    }

    return null;
}

fn showWindowsFontDialog(allocator: std.mem.Allocator, options: FontDialogOptions) !?DialogResult {
    if (@import("builtin").os.tag != .windows) return null;

    const windows = struct {
        extern "comdlg32" fn ChooseFontA(lpcf: *CHOOSEFONTA) callconv(.winapi) i32;

        const LOGFONTA = extern struct {
            lfHeight: i32,
            lfWidth: i32,
            lfEscapement: i32,
            lfOrientation: i32,
            lfWeight: i32,
            lfItalic: u8,
            lfUnderline: u8,
            lfStrikeOut: u8,
            lfCharSet: u8,
            lfOutPrecision: u8,
            lfClipPrecision: u8,
            lfQuality: u8,
            lfPitchAndFamily: u8,
            lfFaceName: [32]u8,
        };

        const CHOOSEFONTA = extern struct {
            lStructSize: u32,
            hwndOwner: ?*anyopaque,
            hDC: ?*anyopaque,
            lpLogFont: *LOGFONTA,
            iPointSize: i32,
            Flags: u32,
            rgbColors: u32,
            lCustData: usize,
            lpfnHook: ?*anyopaque,
            lpTemplateName: ?[*:0]const u8,
            hInstance: ?*anyopaque,
            lpszStyle: ?[*]u8,
            nFontType: u16,
            nSizeMin: i32,
            nSizeMax: i32,
        };

        const CF_SCREENFONTS: u32 = 0x00000001;
        const CF_INITTOLOGFONTSTRUCT: u32 = 0x00000040;
        const CF_EFFECTS: u32 = 0x00000100;
    };

    var lf: windows.LOGFONTA = std.mem.zeroes(windows.LOGFONTA);

    // Set default font if provided
    if (options.default_font) |font| {
        const len = @min(font.family.len, 31);
        @memcpy(lf.lfFaceName[0..len], font.family[0..len]);
        lf.lfHeight = -@as(i32, @intFromFloat(font.size));
        lf.lfWeight = @intCast(font.weight.toNumber());
        lf.lfItalic = if (font.style == .italic) 1 else 0;
    }

    var cf: windows.CHOOSEFONTA = .{
        .lStructSize = @sizeOf(windows.CHOOSEFONTA),
        .hwndOwner = null,
        .hDC = null,
        .lpLogFont = &lf,
        .iPointSize = 0,
        .Flags = windows.CF_SCREENFONTS | windows.CF_INITTOLOGFONTSTRUCT,
        .rgbColors = 0,
        .lCustData = 0,
        .lpfnHook = null,
        .lpTemplateName = null,
        .hInstance = null,
        .lpszStyle = null,
        .nFontType = 0,
        .nSizeMin = @intFromFloat(options.min_size),
        .nSizeMax = @intFromFloat(options.max_size),
    };

    if (options.show_effects) {
        cf.Flags |= windows.CF_EFFECTS;
    }

    if (windows.ChooseFontA(&cf) != 0) {
        const face_name = std.mem.sliceTo(&lf.lfFaceName, 0);
        const family = try allocator.dupe(u8, face_name);
        const size: f32 = @floatFromInt(@divTrunc(cf.iPointSize, 10));

        const weight: Font.FontWeight = if (lf.lfWeight >= 700) .bold else if (lf.lfWeight >= 500) .medium else .regular;

        const style: Font.FontStyle = if (lf.lfItalic != 0) .italic else .normal;

        return DialogResult{ .font = Font{
            .family = family,
            .size = size,
            .weight = weight,
            .style = style,
        } };
    }

    return null;
}

/// Common dialog presets for convenience
pub const CommonDialogs = struct {
    pub fn openImage(allocator: std.mem.Allocator) !?DialogResult {
        const filters = [_]FileFilter{
            FileFilter.create("Images", &[_][]const u8{ "png", "jpg", "jpeg", "gif", "bmp", "svg" }),
            FileFilter.create("All Files", &[_][]const u8{"*"}),
        };

        return Dialog.showFileOpen(allocator, .{
            .title = "Open Image",
            .filters = &filters,
        });
    }

    pub fn openText(allocator: std.mem.Allocator) !?DialogResult {
        const filters = [_]FileFilter{
            FileFilter.create("Text Files", &[_][]const u8{ "txt", "md", "json", "xml", "html" }),
            FileFilter.create("All Files", &[_][]const u8{"*"}),
        };

        return Dialog.showFileOpen(allocator, .{
            .title = "Open Text File",
            .filters = &filters,
        });
    }

    pub fn saveAs(allocator: std.mem.Allocator, default_name: []const u8) !?DialogResult {
        return Dialog.showFileSave(allocator, .{
            .title = "Save As",
            .default_path = default_name,
        });
    }

    pub fn confirmDelete(allocator: std.mem.Allocator, item_name: []const u8) !DialogResult {
        var message_buf: [256]u8 = undefined;
        const message = try std.fmt.bufPrint(&message_buf, "Are you sure you want to delete '{s}'?", .{item_name});

        return Dialog.showConfirm(allocator, .{
            .title = "Confirm Delete",
            .message = message,
            .confirm_text = "Delete",
            .destructive = true,
        });
    }

    pub fn showError(allocator: std.mem.Allocator, error_message: []const u8) !DialogResult {
        return Dialog.showMessage(allocator, .{
            .title = "Error",
            .message = error_message,
            .type = .error_msg,
        });
    }

    pub fn showInfo(allocator: std.mem.Allocator, info_message: []const u8) !DialogResult {
        return Dialog.showMessage(allocator, .{
            .title = "Information",
            .message = info_message,
            .type = .info,
        });
    }
};

/// Toast Notification System
pub const ToastType = enum {
    info,
    success,
    warning,
    error_msg,
};

pub const ToastPosition = enum {
    top_left,
    top_center,
    top_right,
    bottom_left,
    bottom_center,
    bottom_right,
};

pub const ToastOptions = struct {
    message: []const u8,
    title: ?[]const u8 = null,
    type: ToastType = .info,
    position: ToastPosition = .bottom_right,
    duration_ms: u64 = 3000,
    closable: bool = true,
    icon: ?[]const u8 = null,
    action_text: ?[]const u8 = null,
    action_callback: ?*const fn () void = null,
};

pub const Toast = struct {
    id: usize,
    options: ToastOptions,
    shown_at: ?std.Io.Timestamp,
    closed: bool,

    pub fn init(id: usize, options: ToastOptions) Toast {
        return Toast{
            .id = id,
            .options = options,
            .shown_at = std.Io.Timestamp.now(io_context.get(), .awake),
            .closed = false,
        };
    }

    pub fn close(self: *Toast) void {
        self.closed = true;
    }

    pub fn isExpired(self: Toast) bool {
        const shown = self.shown_at orelse return false;
        const now = std.Io.Timestamp.now(io_context.get(), .awake);
        const elapsed = shown.durationTo(now);
        const elapsed_ms = @as(u64, @intCast(elapsed.nanoseconds)) / std.time.ns_per_ms;
        return elapsed_ms >= self.options.duration_ms;
    }
};

pub const ToastManager = struct {
    toasts: std.ArrayList(Toast),
    next_id: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ToastManager {
        return ToastManager{
            .toasts = .{},
            .next_id = 1,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ToastManager) void {
        self.toasts.deinit(self.allocator);
    }

    pub fn show(self: *ToastManager, options: ToastOptions) !usize {
        const id = self.next_id;
        self.next_id += 1;

        const toast = Toast.init(id, options);
        try self.toasts.append(self.allocator, toast);

        return id;
    }

    pub fn close(self: *ToastManager, id: usize) void {
        for (self.toasts.items) |*toast| {
            if (toast.id == id) {
                toast.close();
                break;
            }
        }
    }

    pub fn closeAll(self: *ToastManager) void {
        for (self.toasts.items) |*toast| {
            toast.close();
        }
    }

    pub fn update(self: *ToastManager) void {
        // Remove expired and closed toasts
        var i: usize = 0;
        while (i < self.toasts.items.len) {
            const toast = self.toasts.items[i];
            if (toast.closed or toast.isExpired()) {
                _ = self.toasts.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }
};

/// Context Menu Dialog
pub const ContextMenuItem = struct {
    label: []const u8,
    icon: ?[]const u8 = null,
    shortcut: ?[]const u8 = null,
    enabled: bool = true,
    checked: bool = false,
    callback: ?*const fn () void = null,
    submenu: ?[]const ContextMenuItem = null,
    separator: bool = false,
};

pub const ContextMenuOptions = struct {
    items: []const ContextMenuItem,
    x: i32,
    y: i32,
};

pub const ContextMenu = struct {
    options: ContextMenuOptions,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, options: ContextMenuOptions) ContextMenu {
        return ContextMenu{
            .options = options,
            .allocator = allocator,
        };
    }

    pub fn show(self: *ContextMenu) !void {
        _ = self;
        // Platform-specific implementation to show context menu
    }

    pub fn close(self: *ContextMenu) void {
        _ = self;
        // Close the context menu
    }
};

/// Popover Dialog
pub const PopoverOptions = struct {
    content: []const u8,
    title: ?[]const u8 = null,
    target_x: i32,
    target_y: i32,
    width: u32 = 300,
    height: u32 = 200,
    arrow_position: ArrowPosition = .top,
    closable: bool = true,
    modal: bool = false,

    pub const ArrowPosition = enum {
        top,
        bottom,
        left,
        right,
        none,
    };
};

pub const Popover = struct {
    options: PopoverOptions,
    allocator: std.mem.Allocator,
    visible: bool,

    pub fn init(allocator: std.mem.Allocator, options: PopoverOptions) Popover {
        return Popover{
            .options = options,
            .allocator = allocator,
            .visible = false,
        };
    }

    pub fn show(self: *Popover) !void {
        self.visible = true;
        // Platform-specific implementation
    }

    pub fn hide(self: *Popover) void {
        self.visible = false;
    }

    pub fn toggle(self: *Popover) !void {
        if (self.visible) {
            self.hide();
        } else {
            try self.show();
        }
    }
};

/// Modal Overlay Dialog
pub const ModalOptions = struct {
    title: []const u8,
    content: []const u8,
    width: u32 = 600,
    height: u32 = 400,
    closable: bool = true,
    backdrop_dismiss: bool = true,
    buttons: []const ModalButton = &[_]ModalButton{},
};

pub const ModalButton = struct {
    label: []const u8,
    style: ButtonStyle = .default,
    callback: *const fn () void,

    pub const ButtonStyle = enum {
        default,
        primary,
        danger,
        success,
    };
};

pub const Modal = struct {
    options: ModalOptions,
    allocator: std.mem.Allocator,
    visible: bool,

    pub fn init(allocator: std.mem.Allocator, options: ModalOptions) Modal {
        return Modal{
            .options = options,
            .allocator = allocator,
            .visible = false,
        };
    }

    pub fn show(self: *Modal) !void {
        self.visible = true;
        // Platform-specific implementation
    }

    pub fn hide(self: *Modal) void {
        self.visible = false;
    }
};

/// Drawer/Sidebar Dialog
pub const DrawerOptions = struct {
    title: []const u8,
    content: []const u8,
    position: Position = .right,
    width: u32 = 400,
    closable: bool = true,
    overlay: bool = true,

    pub const Position = enum {
        left,
        right,
        top,
        bottom,
    };
};

pub const Drawer = struct {
    options: DrawerOptions,
    allocator: std.mem.Allocator,
    visible: bool,

    pub fn init(allocator: std.mem.Allocator, options: DrawerOptions) Drawer {
        return Drawer{
            .options = options,
            .allocator = allocator,
            .visible = false,
        };
    }

    pub fn show(self: *Drawer) !void {
        self.visible = true;
        // Platform-specific implementation
    }

    pub fn hide(self: *Drawer) void {
        self.visible = false;
    }

    pub fn toggle(self: *Drawer) !void {
        if (self.visible) {
            self.hide();
        } else {
            try self.show();
        }
    }
};

/// Bottom Sheet Dialog
pub const BottomSheetOptions = struct {
    title: ?[]const u8 = null,
    content: []const u8,
    height: u32 = 300,
    draggable: bool = true,
    closable: bool = true,
    snap_points: []const u32 = &[_]u32{ 300, 600 },
};

pub const BottomSheet = struct {
    options: BottomSheetOptions,
    allocator: std.mem.Allocator,
    visible: bool,
    current_height: u32,

    pub fn init(allocator: std.mem.Allocator, options: BottomSheetOptions) BottomSheet {
        return BottomSheet{
            .options = options,
            .allocator = allocator,
            .visible = false,
            .current_height = options.height,
        };
    }

    pub fn show(self: *BottomSheet) !void {
        self.visible = true;
        // Platform-specific implementation
    }

    pub fn hide(self: *BottomSheet) void {
        self.visible = false;
    }

    pub fn setHeight(self: *BottomSheet, height: u32) void {
        self.current_height = height;
        // Update UI
    }

    pub fn snapToPoint(self: *BottomSheet, index: usize) void {
        if (index < self.options.snap_points.len) {
            self.current_height = self.options.snap_points[index];
        }
    }
};

/// Alert/Notification Banner
pub const BannerOptions = struct {
    message: []const u8,
    type: BannerType = .info,
    position: BannerPosition = .top,
    closable: bool = true,
    auto_dismiss: bool = true,
    duration_ms: u64 = 5000,
    actions: []const BannerAction = &[_]BannerAction{},

    pub const BannerType = enum {
        info,
        success,
        warning,
        error_msg,
    };

    pub const BannerPosition = enum {
        top,
        bottom,
    };
};

pub const BannerAction = struct {
    label: []const u8,
    callback: *const fn () void,
};

pub const Banner = struct {
    options: BannerOptions,
    allocator: std.mem.Allocator,
    visible: bool,
    shown_at: i64,

    pub fn init(allocator: std.mem.Allocator, options: BannerOptions) Banner {
        return Banner{
            .options = options,
            .allocator = allocator,
            .visible = false,
            .shown_at = 0,
        };
    }

    pub fn show(self: *Banner) !void {
        self.visible = true;
        self.shown_at = std.time.milliTimestamp();
        // Platform-specific implementation
    }

    pub fn hide(self: *Banner) void {
        self.visible = false;
    }

    pub fn shouldDismiss(self: Banner) bool {
        if (!self.options.auto_dismiss) return false;
        const now = std.time.milliTimestamp();
        const elapsed = @as(u64, @intCast(now - self.shown_at));
        return elapsed >= self.options.duration_ms;
    }
};

/// Tooltip Dialog
pub const TooltipOptions = struct {
    text: []const u8,
    target_x: i32,
    target_y: i32,
    delay_ms: u64 = 500,
    position: TooltipPosition = .top,

    pub const TooltipPosition = enum {
        top,
        bottom,
        left,
        right,
        auto,
    };
};

pub const Tooltip = struct {
    options: TooltipOptions,
    allocator: std.mem.Allocator,
    visible: bool,

    pub fn init(allocator: std.mem.Allocator, options: TooltipOptions) Tooltip {
        return Tooltip{
            .options = options,
            .allocator = allocator,
            .visible = false,
        };
    }

    pub fn show(self: *Tooltip) !void {
        self.visible = true;
        // Platform-specific implementation
    }

    pub fn hide(self: *Tooltip) void {
        self.visible = false;
    }
};

/// Dropdown/Select Dialog
pub const DropdownOption = struct {
    label: []const u8,
    value: []const u8,
    icon: ?[]const u8 = null,
    disabled: bool = false,
};

pub const DropdownOptions = struct {
    options: []const DropdownOption,
    selected_value: ?[]const u8 = null,
    placeholder: []const u8 = "Select...",
    searchable: bool = false,
    multi_select: bool = false,
    max_height: u32 = 300,
};

pub const Dropdown = struct {
    options: DropdownOptions,
    allocator: std.mem.Allocator,
    visible: bool,
    selected_indices: std.ArrayList(usize),

    pub fn init(allocator: std.mem.Allocator, options: DropdownOptions) !Dropdown {
        return Dropdown{
            .options = options,
            .allocator = allocator,
            .visible = false,
            .selected_indices = .{},
        };
    }

    pub fn deinit(self: *Dropdown) void {
        self.selected_indices.deinit(self.allocator);
    }

    pub fn show(self: *Dropdown) !void {
        self.visible = true;
    }

    pub fn hide(self: *Dropdown) void {
        self.visible = false;
    }

    pub fn selectOption(self: *Dropdown, index: usize) !void {
        if (self.options.multi_select) {
            try self.selected_indices.append(self.allocator, index);
        } else {
            self.selected_indices.clearRetainingCapacity();
            try self.selected_indices.append(self.allocator, index);
        }
    }

    pub fn getSelectedValues(self: *Dropdown) ![][]const u8 {
        var values: std.ArrayList([]const u8) = .{};
        defer values.deinit(self.allocator);

        for (self.selected_indices.items) |idx| {
            if (idx < self.options.options.len) {
                try values.append(self.allocator, self.options.options[idx].value);
            }
        }

        return values.toOwnedSlice(self.allocator);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "color creation" {
    const red = Color.rgb(255, 0, 0);
    try std.testing.expectEqual(@as(u8, 255), red.r);
    try std.testing.expectEqual(@as(u8, 0), red.g);
    try std.testing.expectEqual(@as(u8, 0), red.b);
    try std.testing.expectEqual(@as(u8, 255), red.a);

    const transparent = Color.rgba(0, 128, 255, 128);
    try std.testing.expectEqual(@as(u8, 128), transparent.a);
}

test "color from hex" {
    const color = try Color.fromHex("#FF8000");
    try std.testing.expectEqual(@as(u8, 255), color.r);
    try std.testing.expectEqual(@as(u8, 128), color.g);
    try std.testing.expectEqual(@as(u8, 0), color.b);

    // Without hash
    const color2 = try Color.fromHex("00FF00");
    try std.testing.expectEqual(@as(u8, 0), color2.r);
    try std.testing.expectEqual(@as(u8, 255), color2.g);
    try std.testing.expectEqual(@as(u8, 0), color2.b);
}

test "color to hex" {
    const color = Color.rgb(255, 128, 64);
    var buf: [7]u8 = undefined;
    const hex = color.toHex(&buf);
    try std.testing.expectEqualStrings("#ff8040", hex);
}

test "file filter creation" {
    const filter = FileFilter.create("Images", &[_][]const u8{ "png", "jpg", "gif" });
    try std.testing.expectEqualStrings("Images", filter.name);
    try std.testing.expectEqual(@as(usize, 3), filter.extensions.len);
}

test "dialog result types" {
    const ok_result: DialogResult = .{ .ok = {} };
    const cancel_result: DialogResult = .{ .cancel = {} };
    const file_result: DialogResult = .{ .file_path = "/path/to/file.txt" };
    const dir_result: DialogResult = .{ .directory_path = "/path/to/dir" };

    switch (ok_result) {
        .ok => {},
        else => try std.testing.expect(false),
    }
    switch (cancel_result) {
        .cancel => {},
        else => try std.testing.expect(false),
    }
    switch (file_result) {
        .file_path => |path| try std.testing.expectEqualStrings("/path/to/file.txt", path),
        else => try std.testing.expect(false),
    }
    switch (dir_result) {
        .directory_path => |path| try std.testing.expectEqualStrings("/path/to/dir", path),
        else => try std.testing.expect(false),
    }
}

test "font weight to number" {
    try std.testing.expectEqual(@as(u16, 100), Font.FontWeight.thin.toNumber());
    try std.testing.expectEqual(@as(u16, 400), Font.FontWeight.regular.toNumber());
    try std.testing.expectEqual(@as(u16, 700), Font.FontWeight.bold.toNumber());
    try std.testing.expectEqual(@as(u16, 900), Font.FontWeight.black.toNumber());
}

test "dialog options defaults" {
    const file_opts = FileDialogOptions{};
    try std.testing.expectEqualStrings("Select File", file_opts.title);
    try std.testing.expect(file_opts.default_path == null);
    try std.testing.expect(!file_opts.multi_select);

    const dir_opts = DirectoryDialogOptions{};
    try std.testing.expectEqualStrings("Select Directory", dir_opts.title);
    try std.testing.expect(dir_opts.create_directories);

    const msg_opts = MessageDialogOptions{ .message = "Test" };
    try std.testing.expectEqualStrings("Message", msg_opts.title);
    try std.testing.expectEqual(MessageDialogOptions.MessageType.info, msg_opts.type);
}

test "toast creation and expiry" {
    const opts = ToastOptions{ .message = "Hello", .duration_ms = 100 };
    var toast = Toast.init(1, opts);

    try std.testing.expectEqual(@as(usize, 1), toast.id);
    try std.testing.expect(!toast.closed);
    try std.testing.expect(!toast.isExpired());

    toast.close();
    try std.testing.expect(toast.closed);
}

test "progress dialog initialization" {
    const allocator = std.testing.allocator;
    var progress = try ProgressDialog.init(allocator, .{
        .message = "Loading...",
        .indeterminate = false,
    });
    defer progress.deinit();

    try std.testing.expectEqual(@as(f32, 0.0), progress.progress);
    try std.testing.expect(!progress.canceled);

    progress.setProgress(50.0);
    try std.testing.expectEqual(@as(f32, 50.0), progress.progress);
}

test "modal initialization" {
    const allocator = std.testing.allocator;
    const modal = Modal.init(allocator, .{
        .title = "Test Modal",
        .content = "Modal content",
    });

    try std.testing.expectEqualStrings("Test Modal", modal.options.title);
    try std.testing.expect(!modal.visible);
}

test "drawer initialization" {
    const allocator = std.testing.allocator;
    const drawer = Drawer.init(allocator, .{
        .title = "Sidebar",
        .content = "Drawer content",
        .position = .left,
    });

    try std.testing.expectEqualStrings("Sidebar", drawer.options.title);
    try std.testing.expectEqual(DrawerOptions.Position.left, drawer.options.position);
    try std.testing.expect(!drawer.visible);
}

test "popover initialization" {
    const allocator = std.testing.allocator;
    const popover = Popover.init(allocator, .{
        .content = "Popover content",
        .target_x = 100,
        .target_y = 200,
    });

    try std.testing.expectEqual(@as(i32, 100), popover.options.target_x);
    try std.testing.expectEqual(@as(i32, 200), popover.options.target_y);
    try std.testing.expect(!popover.visible);
}

test "dropdown initialization and selection" {
    const allocator = std.testing.allocator;

    const options = [_]DropdownOption{
        .{ .label = "Option 1", .value = "opt1" },
        .{ .label = "Option 2", .value = "opt2" },
        .{ .label = "Option 3", .value = "opt3" },
    };

    var dropdown = try Dropdown.init(allocator, .{
        .options = &options,
    });
    defer dropdown.deinit();

    try std.testing.expect(!dropdown.visible);
    try std.testing.expectEqual(@as(usize, 0), dropdown.selected_indices.items.len);

    try dropdown.selectOption(1);
    try std.testing.expectEqual(@as(usize, 1), dropdown.selected_indices.items.len);
    try std.testing.expectEqual(@as(usize, 1), dropdown.selected_indices.items[0]);
}
