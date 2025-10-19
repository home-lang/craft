const std = @import("std");
const testing = std.testing;
const dialogs = @import("../src/dialogs.zig");

test "Color - rgb creation" {
    const color = dialogs.Color.rgb(255, 128, 64);

    try testing.expectEqual(@as(u8, 255), color.r);
    try testing.expectEqual(@as(u8, 128), color.g);
    try testing.expectEqual(@as(u8, 64), color.b);
    try testing.expectEqual(@as(u8, 255), color.a);
}

test "Color - rgba creation" {
    const color = dialogs.Color.rgba(100, 150, 200, 128);

    try testing.expectEqual(@as(u8, 100), color.r);
    try testing.expectEqual(@as(u8, 150), color.g);
    try testing.expectEqual(@as(u8, 200), color.b);
    try testing.expectEqual(@as(u8, 128), color.a);
}

test "Font - creation" {
    const font = dialogs.Font{
        .family = "Arial",
        .size = 16.0,
        .weight = .bold,
        .style = .italic,
    };

    try testing.expectEqualStrings("Arial", font.family);
    try testing.expectEqual(@as(f32, 16.0), font.size);
    try testing.expectEqual(dialogs.FontWeight.bold, font.weight);
    try testing.expectEqual(dialogs.FontStyle.italic, font.style);
}

test "FileFilter - creation" {
    const filter = dialogs.FileFilter{
        .name = "Images",
        .extensions = &[_][]const u8{ "png", "jpg", "gif" },
    };

    try testing.expectEqualStrings("Images", filter.name);
    try testing.expectEqual(@as(usize, 3), filter.extensions.len);
    try testing.expectEqualStrings("png", filter.extensions[0]);
    try testing.expectEqualStrings("jpg", filter.extensions[1]);
    try testing.expectEqualStrings("gif", filter.extensions[2]);
}

test "Dialog - default values" {
    const dialog = dialogs.Dialog{
        .title = "Test Dialog",
        .message = "Test Message",
    };

    try testing.expectEqualStrings("Test Dialog", dialog.title);
    try testing.expectEqualStrings("Test Message", dialog.message);
    try testing.expectEqual(dialogs.DialogType.info, dialog.dialog_type);
    try testing.expect(dialog.buttons.len > 0);
}

test "Dialog - custom values" {
    const buttons = [_][]const u8{ "Yes", "No", "Cancel" };
    const dialog = dialogs.Dialog{
        .title = "Confirm",
        .message = "Are you sure?",
        .dialog_type = .warning,
        .buttons = &buttons,
        .default_button = 0,
        .cancel_button = 2,
    };

    try testing.expectEqualStrings("Confirm", dialog.title);
    try testing.expectEqualStrings("Are you sure?", dialog.message);
    try testing.expectEqual(dialogs.DialogType.warning, dialog.dialog_type);
    try testing.expectEqual(@as(usize, 3), dialog.buttons.len);
    try testing.expectEqual(@as(u32, 0), dialog.default_button.?);
    try testing.expectEqual(@as(u32, 2), dialog.cancel_button.?);
}

test "DialogType - enum values" {
    try testing.expectEqual(dialogs.DialogType.info, .info);
    try testing.expectEqual(dialogs.DialogType.warning, .warning);
    try testing.expectEqual(dialogs.DialogType.error_dlg, .error_dlg);
    try testing.expectEqual(dialogs.DialogType.question, .question);
}

test "ProgressDialog - creation" {
    const progress = dialogs.ProgressDialog{
        .title = "Loading",
        .message = "Please wait...",
        .progress = 0.5,
        .indeterminate = false,
        .cancelable = true,
    };

    try testing.expectEqualStrings("Loading", progress.title);
    try testing.expectEqualStrings("Please wait...", progress.message);
    try testing.expectEqual(@as(f32, 0.5), progress.progress);
    try testing.expect(!progress.indeterminate);
    try testing.expect(progress.cancelable);
}

test "ProgressDialog - indeterminate" {
    const progress = dialogs.ProgressDialog{
        .title = "Processing",
        .message = "Working...",
        .indeterminate = true,
    };

    try testing.expect(progress.indeterminate);
}

test "Toast - default values" {
    const toast = dialogs.Toast{
        .message = "Success!",
    };

    try testing.expectEqualStrings("Success!", toast.message);
    try testing.expectEqual(dialogs.ToastType.info, toast.toast_type);
    try testing.expectEqual(@as(u32, 3000), toast.duration_ms);
    try testing.expectEqual(dialogs.ToastPosition.bottom_right, toast.position);
}

test "Toast - custom values" {
    const toast = dialogs.Toast{
        .message = "Error occurred",
        .toast_type = .error_toast,
        .duration_ms = 5000,
        .position = .top_center,
    };

    try testing.expectEqualStrings("Error occurred", toast.message);
    try testing.expectEqual(dialogs.ToastType.error_toast, toast.toast_type);
    try testing.expectEqual(@as(u32, 5000), toast.duration_ms);
    try testing.expectEqual(dialogs.ToastPosition.top_center, toast.position);
}

test "ToastType - enum values" {
    try testing.expectEqual(dialogs.ToastType.info, .info);
    try testing.expectEqual(dialogs.ToastType.success, .success);
    try testing.expectEqual(dialogs.ToastType.warning, .warning);
    try testing.expectEqual(dialogs.ToastType.error_toast, .error_toast);
}

test "ToastPosition - enum values" {
    try testing.expectEqual(dialogs.ToastPosition.top_left, .top_left);
    try testing.expectEqual(dialogs.ToastPosition.top_center, .top_center);
    try testing.expectEqual(dialogs.ToastPosition.top_right, .top_right);
    try testing.expectEqual(dialogs.ToastPosition.bottom_left, .bottom_left);
    try testing.expectEqual(dialogs.ToastPosition.bottom_center, .bottom_center);
    try testing.expectEqual(dialogs.ToastPosition.bottom_right, .bottom_right);
}

test "ToastManager - init and deinit" {
    var manager = dialogs.ToastManager.init(testing.allocator);
    defer manager.deinit();

    try testing.expectEqual(@as(usize, 0), manager.active_toasts.items.len);
}

test "ToastManager - add toast" {
    var manager = dialogs.ToastManager.init(testing.allocator);
    defer manager.deinit();

    const toast = dialogs.Toast{
        .message = "Test toast",
    };

    try manager.add(toast);

    try testing.expectEqual(@as(usize, 1), manager.active_toasts.items.len);
}

test "ToastManager - clear toasts" {
    var manager = dialogs.ToastManager.init(testing.allocator);
    defer manager.deinit();

    try manager.add(dialogs.Toast{ .message = "Toast 1" });
    try manager.add(dialogs.Toast{ .message = "Toast 2" });

    try testing.expectEqual(@as(usize, 2), manager.active_toasts.items.len);

    manager.clear();

    try testing.expectEqual(@as(usize, 0), manager.active_toasts.items.len);
}

test "ContextMenu - creation" {
    const items = [_]dialogs.MenuItem{
        .{ .label = "Copy", .action = "copy" },
        .{ .label = "Paste", .action = "paste" },
    };

    const menu = dialogs.ContextMenu{
        .items = &items,
    };

    try testing.expectEqual(@as(usize, 2), menu.items.len);
    try testing.expectEqualStrings("Copy", menu.items[0].label);
    try testing.expectEqualStrings("copy", menu.items[0].action);
}

test "MenuItem - with separator" {
    const item = dialogs.MenuItem{
        .label = "",
        .action = "",
        .separator = true,
    };

    try testing.expect(item.separator);
}

test "MenuItem - disabled" {
    const item = dialogs.MenuItem{
        .label = "Disabled Item",
        .action = "disabled",
        .enabled = false,
    };

    try testing.expect(!item.enabled);
}

test "Popover - creation" {
    const popover = dialogs.Popover{
        .content = "<div>Test</div>",
        .anchor_x = 100,
        .anchor_y = 200,
        .width = 300,
        .height = 150,
    };

    try testing.expectEqualStrings("<div>Test</div>", popover.content);
    try testing.expectEqual(@as(i32, 100), popover.anchor_x);
    try testing.expectEqual(@as(i32, 200), popover.anchor_y);
    try testing.expectEqual(@as(u32, 300), popover.width);
    try testing.expectEqual(@as(u32, 150), popover.height);
}

test "Modal - creation" {
    const modal = dialogs.Modal{
        .title = "Modal Title",
        .content = "Modal Content",
        .width = 600,
        .height = 400,
        .backdrop = true,
        .closable = true,
    };

    try testing.expectEqualStrings("Modal Title", modal.title);
    try testing.expectEqualStrings("Modal Content", modal.content);
    try testing.expectEqual(@as(u32, 600), modal.width);
    try testing.expectEqual(@as(u32, 400), modal.height);
    try testing.expect(modal.backdrop);
    try testing.expect(modal.closable);
}

test "Drawer - creation" {
    const drawer = dialogs.Drawer{
        .content = "Drawer Content",
        .position = .left,
        .width = 300,
    };

    try testing.expectEqualStrings("Drawer Content", drawer.content);
    try testing.expectEqual(dialogs.DrawerPosition.left, drawer.position);
    try testing.expectEqual(@as(u32, 300), drawer.width);
}

test "DrawerPosition - enum values" {
    try testing.expectEqual(dialogs.DrawerPosition.left, .left);
    try testing.expectEqual(dialogs.DrawerPosition.right, .right);
    try testing.expectEqual(dialogs.DrawerPosition.top, .top);
    try testing.expectEqual(dialogs.DrawerPosition.bottom, .bottom);
}

test "BottomSheet - creation" {
    const sheet = dialogs.BottomSheet{
        .content = "Sheet Content",
        .height = 400,
        .draggable = true,
        .backdrop = true,
    };

    try testing.expectEqualStrings("Sheet Content", sheet.content);
    try testing.expectEqual(@as(u32, 400), sheet.height);
    try testing.expect(sheet.draggable);
    try testing.expect(sheet.backdrop);
}

test "Banner - creation" {
    const banner = dialogs.Banner{
        .message = "Important Notice",
        .banner_type = .warning,
        .dismissable = true,
        .action_label = "Learn More",
    };

    try testing.expectEqualStrings("Important Notice", banner.message);
    try testing.expectEqual(dialogs.BannerType.warning, banner.banner_type);
    try testing.expect(banner.dismissable);
    try testing.expectEqualStrings("Learn More", banner.action_label.?);
}

test "BannerType - enum values" {
    try testing.expectEqual(dialogs.BannerType.info, .info);
    try testing.expectEqual(dialogs.BannerType.success, .success);
    try testing.expectEqual(dialogs.BannerType.warning, .warning);
    try testing.expectEqual(dialogs.BannerType.error_banner, .error_banner);
}

test "Tooltip - creation" {
    const tooltip = dialogs.Tooltip{
        .text = "Helpful tip",
        .position = .top,
    };

    try testing.expectEqualStrings("Helpful tip", tooltip.text);
    try testing.expectEqual(dialogs.TooltipPosition.top, tooltip.position);
}

test "TooltipPosition - enum values" {
    try testing.expectEqual(dialogs.TooltipPosition.top, .top);
    try testing.expectEqual(dialogs.TooltipPosition.bottom, .bottom);
    try testing.expectEqual(dialogs.TooltipPosition.left, .left);
    try testing.expectEqual(dialogs.TooltipPosition.right, .right);
}

test "Dropdown - creation" {
    const options = [_][]const u8{ "Option 1", "Option 2", "Option 3" };
    const dropdown = dialogs.Dropdown{
        .options = &options,
        .selected_index = 0,
        .placeholder = "Select option",
    };

    try testing.expectEqual(@as(usize, 3), dropdown.options.len);
    try testing.expectEqual(@as(usize, 0), dropdown.selected_index);
    try testing.expectEqualStrings("Select option", dropdown.placeholder.?);
}
