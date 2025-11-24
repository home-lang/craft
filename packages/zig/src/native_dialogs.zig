const std = @import("std");

/// Native dialog system for open/save dialogs, message boxes, and color pickers
/// Cross-platform dialog abstraction

pub const DialogError = error{
    DialogCancelled,
    InvalidPath,
    InvalidOptions,
};

/// Dialog result
pub const DialogResult = union(enum) {
    Ok: void,
    Cancel: void,
    Path: []const u8,
    Paths: []const []const u8,
    Color: Color,
    Custom: []const u8,
};

/// Color structure
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn toHex(self: Color, allocator: std.mem.Allocator) ![]u8 {
        return try std.fmt.allocPrint(allocator, "#{x:0>2}{x:0>2}{x:0>2}", .{ self.r, self.g, self.b });
    }

    pub fn fromHex(hex: []const u8) !Color {
        if (hex.len < 6) return DialogError.InvalidOptions;

        const start: usize = if (hex[0] == '#') 1 else 0;

        const r = try std.fmt.parseInt(u8, hex[start .. start + 2], 16);
        const g = try std.fmt.parseInt(u8, hex[start + 2 .. start + 4], 16);
        const b = try std.fmt.parseInt(u8, hex[start + 4 .. start + 6], 16);

        return Color{ .r = r, .g = g, .b = b };
    }
};

/// File filter for open/save dialogs
pub const FileFilter = struct {
    name: []const u8,
    extensions: []const []const u8,

    pub fn init(name: []const u8, extensions: []const []const u8) FileFilter {
        return FileFilter{
            .name = name,
            .extensions = extensions,
        };
    }
};

/// Open file dialog options
pub const OpenDialogOptions = struct {
    title: ?[]const u8 = null,
    default_path: ?[]const u8 = null,
    filters: ?[]const FileFilter = null,
    multi_select: bool = false,
    show_hidden: bool = false,
};

/// Save file dialog options
pub const SaveDialogOptions = struct {
    title: ?[]const u8 = null,
    default_path: ?[]const u8 = null,
    default_name: ?[]const u8 = null,
    filters: ?[]const FileFilter = null,
};

/// Message box options
pub const MessageBoxOptions = struct {
    title: []const u8,
    message: []const u8,
    type: MessageType = .Info,
    buttons: []const []const u8 = &[_][]const u8{"OK"},
    default_button: usize = 0,
};

/// Message box type
pub const MessageType = enum {
    Info,
    Warning,
    Error,
    Question,
};

/// Color picker options
pub const ColorPickerOptions = struct {
    title: ?[]const u8 = null,
    default_color: ?Color = null,
    show_alpha: bool = false,
};

/// Dialog manager
pub const DialogManager = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) DialogManager {
        return DialogManager{
            .allocator = allocator,
        };
    }

    /// Show open file dialog
    pub fn showOpenDialog(self: *Self, options: OpenDialogOptions) !DialogResult {
        std.debug.print("Opening file dialog...\n", .{});

        if (options.title) |title| {
            std.debug.print("  Title: {s}\n", .{title});
        }

        if (options.default_path) |path| {
            std.debug.print("  Default path: {s}\n", .{path});
        }

        std.debug.print("  Multi-select: {}\n", .{options.multi_select});

        // Platform-specific implementation would go here
        // For now, return a mock result
        if (options.multi_select) {
            const paths = try self.allocator.alloc([]const u8, 2);
            paths[0] = try self.allocator.dupe(u8, "/mock/file1.txt");
            paths[1] = try self.allocator.dupe(u8, "/mock/file2.txt");
            return DialogResult{ .Paths = paths };
        } else {
            const path = try self.allocator.dupe(u8, "/mock/file.txt");
            return DialogResult{ .Path = path };
        }
    }

    /// Show save file dialog
    pub fn showSaveDialog(self: *Self, options: SaveDialogOptions) !DialogResult {
        std.debug.print("Opening save dialog...\n", .{});

        if (options.title) |title| {
            std.debug.print("  Title: {s}\n", .{title});
        }

        if (options.default_name) |name| {
            std.debug.print("  Default name: {s}\n", .{name});
        }

        // Platform-specific implementation
        const path = try self.allocator.dupe(u8, "/mock/saved-file.txt");
        return DialogResult{ .Path = path };
    }

    /// Show message box
    pub fn showMessageBox(self: *Self, options: MessageBoxOptions) !usize {
        std.debug.print("Showing message box...\n", .{});
        std.debug.print("  Title: {s}\n", .{options.title});
        std.debug.print("  Message: {s}\n", .{options.message});
        std.debug.print("  Type: {s}\n", .{@tagName(options.type)});

        _ = self;

        // Platform-specific implementation
        // Return button index (0-based)
        return options.default_button;
    }

    /// Show confirmation dialog
    pub fn showConfirmation(self: *Self, title: []const u8, message: []const u8) !bool {
        const result = try self.showMessageBox(.{
            .title = title,
            .message = message,
            .type = .Question,
            .buttons = &[_][]const u8{ "Yes", "No" },
            .default_button = 0,
        });

        return result == 0; // Yes = true, No = false
    }

    /// Show error dialog
    pub fn showError(self: *Self, title: []const u8, message: []const u8) !void {
        _ = try self.showMessageBox(.{
            .title = title,
            .message = message,
            .type = .Error,
            .buttons = &[_][]const u8{"OK"},
        });
    }

    /// Show warning dialog
    pub fn showWarning(self: *Self, title: []const u8, message: []const u8) !void {
        _ = try self.showMessageBox(.{
            .title = title,
            .message = message,
            .type = .Warning,
            .buttons = &[_][]const u8{"OK"},
        });
    }

    /// Show info dialog
    pub fn showInfo(self: *Self, title: []const u8, message: []const u8) !void {
        _ = try self.showMessageBox(.{
            .title = title,
            .message = message,
            .type = .Info,
            .buttons = &[_][]const u8{"OK"},
        });
    }

    /// Show color picker dialog
    pub fn showColorPicker(self: *Self, options: ColorPickerOptions) !DialogResult {
        std.debug.print("Opening color picker...\n", .{});

        if (options.title) |title| {
            std.debug.print("  Title: {s}\n", .{title});
        }

        if (options.default_color) |color| {
            std.debug.print("  Default color: #{x:0>2}{x:0>2}{x:0>2}\n", .{ color.r, color.g, color.b });
        }

        std.debug.print("  Show alpha: {}\n", .{options.show_alpha});

        _ = self;

        // Platform-specific implementation
        const color = Color{ .r = 255, .g = 0, .g = 0, .a = 255 }; // Red
        return DialogResult{ .Color = color };
    }

    /// Show folder picker dialog
    pub fn showFolderDialog(self: *Self, title: ?[]const u8, default_path: ?[]const u8) !DialogResult {
        std.debug.print("Opening folder dialog...\n", .{});

        if (title) |t| {
            std.debug.print("  Title: {s}\n", .{t});
        }

        if (default_path) |path| {
            std.debug.print("  Default path: {s}\n", .{path});
        }

        // Platform-specific implementation
        const path = try self.allocator.dupe(u8, "/mock/folder");
        return DialogResult{ .Path = path };
    }

    /// Free dialog result
    pub fn freeResult(self: *Self, result: DialogResult) void {
        switch (result) {
            .Path => |path| self.allocator.free(path),
            .Paths => |paths| {
                for (paths) |path| {
                    self.allocator.free(path);
                }
                self.allocator.free(paths);
            },
            .Custom => |data| self.allocator.free(data),
            else => {},
        }
    }
};

// Tests
test "color from hex" {
    const color = try Color.fromHex("#FF0000");
    try std.testing.expectEqual(255, color.r);
    try std.testing.expectEqual(0, color.g);
    try std.testing.expectEqual(0, color.b);
}

test "color to hex" {
    const allocator = std.testing.allocator;
    const color = Color{ .r = 255, .g = 128, .b = 64 };

    const hex = try color.toHex(allocator);
    defer allocator.free(hex);

    try std.testing.expectEqualStrings("#ff8040", hex);
}

test "show open dialog" {
    const allocator = std.testing.allocator;
    var dm = DialogManager.init(allocator);

    const result = try dm.showOpenDialog(.{
        .title = "Select a file",
        .multi_select = false,
    });

    defer dm.freeResult(result);

    try std.testing.expect(result == .Path);
}

test "show confirmation" {
    const allocator = std.testing.allocator;
    var dm = DialogManager.init(allocator);

    const confirmed = try dm.showConfirmation("Test", "Are you sure?");
    try std.testing.expect(confirmed == true); // Mock always returns true
}

test "file filter" {
    const extensions = [_][]const u8{ ".txt", ".md" };
    const filter = FileFilter.init("Text Files", &extensions);

    try std.testing.expectEqualStrings("Text Files", filter.name);
    try std.testing.expectEqual(2, filter.extensions.len);
}
