const std = @import("std");

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

fn showLinuxFileDialog(options: FileDialogOptions) !?DialogResult {
    _ = options;
    // Would use GtkFileChooserDialog
    return null;
}

fn showLinuxFileSaveDialog(options: FileDialogOptions) !?DialogResult {
    _ = options;
    // Would use GtkFileChooserDialog with save action
    return null;
}

fn showLinuxDirectoryDialog(options: DirectoryDialogOptions) !?DialogResult {
    _ = options;
    // Would use GtkFileChooserDialog with select folder action
    return null;
}

fn showLinuxMessageDialog(options: MessageDialogOptions) !DialogResult {
    _ = options;
    // Would use GtkMessageDialog
    return DialogResult{ .ok = {} };
}

fn showLinuxConfirmDialog(options: ConfirmDialogOptions) !DialogResult {
    _ = options;
    // Would use GtkMessageDialog with yes/no buttons
    return DialogResult{ .ok = {} };
}

fn showLinuxInputDialog(allocator: std.mem.Allocator, options: InputDialogOptions) !?DialogResult {
    _ = allocator;
    _ = options;
    // Would use GtkDialog with GtkEntry
    return null;
}

fn showLinuxColorDialog(options: ColorDialogOptions) !?DialogResult {
    _ = options;
    // Would use GtkColorChooserDialog
    return null;
}

fn showLinuxFontDialog(allocator: std.mem.Allocator, options: FontDialogOptions) !?DialogResult {
    _ = allocator;
    _ = options;
    // Would use GtkFontChooserDialog
    return null;
}

fn showWindowsFileDialog(options: FileDialogOptions) !?DialogResult {
    _ = options;
    // Would use IFileOpenDialog COM interface
    return null;
}

fn showWindowsFileSaveDialog(options: FileDialogOptions) !?DialogResult {
    _ = options;
    // Would use IFileSaveDialog COM interface
    return null;
}

fn showWindowsDirectoryDialog(options: DirectoryDialogOptions) !?DialogResult {
    _ = options;
    // Would use IFileOpenDialog with FOS_PICKFOLDERS
    return null;
}

fn showWindowsMessageDialog(options: MessageDialogOptions) !DialogResult {
    _ = options;
    // Would use MessageBox or TaskDialog
    return DialogResult{ .ok = {} };
}

fn showWindowsConfirmDialog(options: ConfirmDialogOptions) !DialogResult {
    _ = options;
    // Would use MessageBox or TaskDialog
    return DialogResult{ .ok = {} };
}

fn showWindowsInputDialog(allocator: std.mem.Allocator, options: InputDialogOptions) !?DialogResult {
    _ = allocator;
    _ = options;
    // Would use custom dialog with edit control
    return null;
}

fn showWindowsColorDialog(options: ColorDialogOptions) !?DialogResult {
    _ = options;
    // Would use ChooseColor
    return null;
}

fn showWindowsFontDialog(allocator: std.mem.Allocator, options: FontDialogOptions) !?DialogResult {
    _ = allocator;
    _ = options;
    // Would use ChooseFont
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
    shown_at: ?std.time.Instant,
    closed: bool,

    pub fn init(id: usize, options: ToastOptions) Toast {
        return Toast{
            .id = id,
            .options = options,
            .shown_at = std.time.Instant.now() catch null,
            .closed = false,
        };
    }

    pub fn close(self: *Toast) void {
        self.closed = true;
    }

    pub fn isExpired(self: Toast) bool {
        const shown = self.shown_at orelse return false;
        const now = std.time.Instant.now() catch return false;
        const elapsed_ns = now.since(shown);
        const elapsed_ms = elapsed_ns / std.time.ns_per_ms;
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
