const std = @import("std");
const craft = @import("../../src/main.zig");

/// File Dialogs Example
///
/// Demonstrates how to use native file dialogs in Craft:
/// - Open file dialog
/// - Save file dialog
/// - Select folder dialog
/// - Message dialogs
/// - Input dialogs

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Craft File Dialogs Demo ===\n\n", .{});

    // Demo 1: Open File Dialog
    try demoOpenFile(allocator);

    // Demo 2: Save File Dialog
    try demoSaveFile(allocator);

    // Demo 3: Select Folder Dialog
    try demoSelectFolder(allocator);

    // Demo 4: Message Dialog
    try demoMessageDialog(allocator);

    // Demo 5: Confirm Dialog
    try demoConfirmDialog(allocator);

    std.debug.print("\n=== Demo Complete ===\n", .{});
}

fn demoOpenFile(allocator: std.mem.Allocator) !void {
    std.debug.print("1. Opening file dialog...\n", .{});

    // Open file with filters
    const filters = [_]craft.FileFilter{
        craft.FileFilter.create("Text Files", &[_][]const u8{ "txt", "md", "json" }),
        craft.FileFilter.create("All Files", &[_][]const u8{"*"}),
    };

    const result = try craft.Dialog.showFileOpen(allocator, .{
        .title = "Open File",
        .filters = &filters,
        .multi_select = false,
    });

    if (result) |r| {
        switch (r) {
            .file_path => |path| std.debug.print("   Selected: {s}\n", .{path}),
            .file_paths => |paths| {
                std.debug.print("   Selected {d} files:\n", .{paths.len});
                for (paths) |p| {
                    std.debug.print("   - {s}\n", .{p});
                }
            },
            else => {},
        }
    } else {
        std.debug.print("   Canceled\n", .{});
    }
}

fn demoSaveFile(allocator: std.mem.Allocator) !void {
    std.debug.print("\n2. Opening save dialog...\n", .{});

    const result = try craft.Dialog.showFileSave(allocator, .{
        .title = "Save File",
        .default_path = "untitled.txt",
        .default_extension = "txt",
        .create_directories = true,
    });

    if (result) |r| {
        switch (r) {
            .file_path => |path| std.debug.print("   Save to: {s}\n", .{path}),
            else => {},
        }
    } else {
        std.debug.print("   Canceled\n", .{});
    }
}

fn demoSelectFolder(allocator: std.mem.Allocator) !void {
    std.debug.print("\n3. Opening folder dialog...\n", .{});

    const result = try craft.Dialog.showDirectory(allocator, .{
        .title = "Select Project Folder",
        .create_directories = true,
    });

    if (result) |r| {
        switch (r) {
            .directory_path => |path| std.debug.print("   Selected folder: {s}\n", .{path}),
            else => {},
        }
    } else {
        std.debug.print("   Canceled\n", .{});
    }
}

fn demoMessageDialog(allocator: std.mem.Allocator) !void {
    std.debug.print("\n4. Showing message dialog...\n", .{});

    const result = try craft.Dialog.showMessage(allocator, .{
        .title = "Welcome",
        .message = "Welcome to Craft File Dialogs!",
        .type = .info,
        .buttons = .ok,
    });

    switch (result) {
        .ok => std.debug.print("   User clicked OK\n", .{}),
        else => {},
    }
}

fn demoConfirmDialog(allocator: std.mem.Allocator) !void {
    std.debug.print("\n5. Showing confirm dialog...\n", .{});

    const result = try craft.Dialog.showConfirm(allocator, .{
        .title = "Confirm Action",
        .message = "Are you sure you want to continue?",
        .confirm_text = "Continue",
        .cancel_text = "Cancel",
        .destructive = false,
    });

    switch (result) {
        .ok => std.debug.print("   User confirmed\n", .{}),
        .cancel => std.debug.print("   User canceled\n", .{}),
        else => {},
    }
}

// Convenience functions using CommonDialogs
fn demoCommonDialogs(allocator: std.mem.Allocator) !void {
    // Open image file
    if (try craft.CommonDialogs.openImage(allocator)) |result| {
        switch (result) {
            .file_path => |path| std.debug.print("Image: {s}\n", .{path}),
            else => {},
        }
    }

    // Save file
    if (try craft.CommonDialogs.saveAs(allocator, "document.txt")) |result| {
        switch (result) {
            .file_path => |path| std.debug.print("Save to: {s}\n", .{path}),
            else => {},
        }
    }

    // Show error
    _ = try craft.CommonDialogs.showError(allocator, "An error occurred!");

    // Show info
    _ = try craft.CommonDialogs.showInfo(allocator, "Operation completed successfully.");
}
