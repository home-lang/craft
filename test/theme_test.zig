const std = @import("std");
const testing = std.testing;
const theme = @import("../src/theme.zig");

test "ThemeMode enum - all variants" {
    try testing.expectEqual(theme.ThemeMode.light, .light);
    try testing.expectEqual(theme.ThemeMode.dark, .dark);
    try testing.expectEqual(theme.ThemeMode.auto, .auto);
    try testing.expectEqual(theme.ThemeMode.custom, .custom);
}

test "ColorScheme - default light colors" {
    const colors = theme.defaultLightColors();

    try testing.expect(colors.primary.r == 33);
    try testing.expect(colors.primary.g == 150);
    try testing.expect(colors.primary.b == 243);

    try testing.expect(colors.background.r == 250);
    try testing.expect(colors.background.g == 250);
    try testing.expect(colors.background.b == 250);
}

test "ColorScheme - default dark colors" {
    const colors = theme.defaultDarkColors();

    try testing.expect(colors.primary.r == 144);
    try testing.expect(colors.primary.g == 202);
    try testing.expect(colors.primary.b == 249);

    try testing.expect(colors.background.r == 18);
    try testing.expect(colors.background.g == 18);
    try testing.expect(colors.background.b == 18);
}

test "Typography - default values" {
    const typo = theme.Typography{};

    try testing.expectEqualStrings("system-ui", typo.primary_font);
    try testing.expectEqualStrings("monospace", typo.monospace_font);
    try testing.expectEqual(@as(f32, 32.0), typo.h1_size);
    try testing.expectEqual(@as(f32, 14.0), typo.body_size);
    try testing.expectEqual(@as(f32, 12.0), typo.caption_size);
}

test "Typography - font weights" {
    const typo = theme.Typography{};

    try testing.expectEqual(@as(u16, 300), typo.light);
    try testing.expectEqual(@as(u16, 400), typo.regular);
    try testing.expectEqual(@as(u16, 500), typo.medium);
    try testing.expectEqual(@as(u16, 700), typo.bold);
}

test "Typography - line heights" {
    const typo = theme.Typography{};

    try testing.expectEqual(@as(f32, 1.2), typo.tight);
    try testing.expectEqual(@as(f32, 1.5), typo.normal);
    try testing.expectEqual(@as(f32, 1.8), typo.relaxed);
}

test "Spacing - default values" {
    const spacing = theme.Spacing{};

    try testing.expectEqual(@as(f32, 4.0), spacing.xs);
    try testing.expectEqual(@as(f32, 8.0), spacing.sm);
    try testing.expectEqual(@as(f32, 16.0), spacing.md);
    try testing.expectEqual(@as(f32, 24.0), spacing.lg);
    try testing.expectEqual(@as(f32, 32.0), spacing.xl);
    try testing.expectEqual(@as(f32, 48.0), spacing.xxl);
}

test "BorderRadius - default values" {
    const radius = theme.BorderRadius{};

    try testing.expectEqual(@as(f32, 0.0), radius.none);
    try testing.expectEqual(@as(f32, 4.0), radius.sm);
    try testing.expectEqual(@as(f32, 8.0), radius.md);
    try testing.expectEqual(@as(f32, 12.0), radius.lg);
    try testing.expectEqual(@as(f32, 16.0), radius.xl);
    try testing.expectEqual(@as(f32, 9999.0), radius.full);
}

test "Shadow - struct creation" {
    const shadow = theme.Shadow{
        .x = 2,
        .y = 4,
        .blur = 8,
        .spread = 0,
        .color = theme.defaultLightColors().shadow,
    };

    try testing.expectEqual(@as(i32, 2), shadow.x);
    try testing.expectEqual(@as(i32, 4), shadow.y);
    try testing.expectEqual(@as(u32, 8), shadow.blur);
}

test "Transitions - default values" {
    const transitions = theme.Transitions{};

    try testing.expectEqual(@as(u32, 150), transitions.fast);
    try testing.expectEqual(@as(u32, 300), transitions.normal);
    try testing.expectEqual(@as(u32, 500), transitions.slow);

    try testing.expectEqualStrings("linear", transitions.easing_linear);
    try testing.expectEqualStrings("ease", transitions.easing_ease);
    try testing.expectEqualStrings("ease-in", transitions.easing_ease_in);
    try testing.expectEqualStrings("ease-out", transitions.easing_ease_out);
    try testing.expectEqualStrings("ease-in-out", transitions.easing_ease_in_out);
}

test "Theme - init with light mode" {
    var t = theme.Theme.init(testing.allocator, "light", .light);
    defer t.deinit();

    try testing.expectEqualStrings("light", t.name);
    try testing.expectEqual(theme.ThemeMode.light, t.mode);
}

test "Theme - init with dark mode" {
    var t = theme.Theme.init(testing.allocator, "dark", .dark);
    defer t.deinit();

    try testing.expectEqualStrings("dark", t.name);
    try testing.expectEqual(theme.ThemeMode.dark, t.mode);
}

test "Theme - setCustomProperty" {
    var t = theme.Theme.init(testing.allocator, "test", .light);
    defer t.deinit();

    try t.setCustomProperty("my-color", "#ff0000");
    const value = t.getCustomProperty("my-color");

    try testing.expect(value != null);
    try testing.expectEqualStrings("#ff0000", value.?);
}

test "Theme - getCustomProperty non-existent" {
    const t = theme.Theme.init(testing.allocator, "test", .light);
    defer {
        var mut_t = t;
        mut_t.deinit();
    }

    const value = t.getCustomProperty("non-existent");
    try testing.expect(value == null);
}

test "Theme - toCSS generation" {
    var t = theme.Theme.init(testing.allocator, "test", .light);
    defer t.deinit();

    const css = try t.toCSS(testing.allocator);
    defer testing.allocator.free(css);

    try testing.expect(css.len > 0);
    try testing.expect(std.mem.indexOf(u8, css, ":root {") != null);
    try testing.expect(std.mem.indexOf(u8, css, "--color-primary:") != null);
}

test "Theme - toCSS with custom properties" {
    var t = theme.Theme.init(testing.allocator, "test", .light);
    defer t.deinit();

    try t.setCustomProperty("custom-prop", "value");

    const css = try t.toCSS(testing.allocator);
    defer testing.allocator.free(css);

    try testing.expect(std.mem.indexOf(u8, css, "--custom-prop: value") != null);
}

test "ThemeManager - init and deinit" {
    var manager = try theme.ThemeManager.init(testing.allocator);
    defer manager.deinit();

    try testing.expect(manager.themes.count() >= 2); // light and dark
}

test "ThemeManager - default themes exist" {
    var manager = try theme.ThemeManager.init(testing.allocator);
    defer manager.deinit();

    try testing.expect(manager.themes.contains("light"));
    try testing.expect(manager.themes.contains("dark"));
}

test "ThemeManager - setTheme to light" {
    var manager = try theme.ThemeManager.init(testing.allocator);
    defer manager.deinit();

    try manager.setTheme("light");
    try testing.expectEqual(theme.ThemeMode.light, manager.current_theme.mode);
}

test "ThemeManager - setTheme to dark" {
    var manager = try theme.ThemeManager.init(testing.allocator);
    defer manager.deinit();

    try manager.setTheme("dark");
    try testing.expectEqual(theme.ThemeMode.dark, manager.current_theme.mode);
}

test "ThemeManager - setTheme non-existent" {
    var manager = try theme.ThemeManager.init(testing.allocator);
    defer manager.deinit();

    const result = manager.setTheme("non-existent");
    try testing.expectError(error.ThemeNotFound, result);
}

test "ThemeManager - registerTheme" {
    var manager = try theme.ThemeManager.init(testing.allocator);
    defer manager.deinit();

    var custom = theme.Theme.init(testing.allocator, "custom", .custom);
    try manager.registerTheme(custom);

    try testing.expect(manager.themes.contains("custom"));
}

test "ThemeManager - getCurrentTheme" {
    var manager = try theme.ThemeManager.init(testing.allocator);
    defer manager.deinit();

    const current = manager.getCurrentTheme();
    try testing.expect(current.* == manager.current_theme.*);
}

test "ThemeManager - onThemeChange callback" {
    var manager = try theme.ThemeManager.init(testing.allocator);
    defer manager.deinit();

    const TestCallback = struct {
        fn callback(_: *theme.Theme) void {}
    };

    try manager.onThemeChange(TestCallback.callback);
    try testing.expectEqual(@as(usize, 1), manager.watchers.items.len);
}

test "ThemeManager - detectSystemTheme" {
    var manager = try theme.ThemeManager.init(testing.allocator);
    defer manager.deinit();

    const system_mode = manager.detectSystemTheme();
    try testing.expect(system_mode == .light or system_mode == .dark);
}

test "ThemeManager - enableAutoTheme" {
    var manager = try theme.ThemeManager.init(testing.allocator);
    defer manager.deinit();

    try manager.enableAutoTheme();
    // Should set theme based on system preference
}

test "Presets - materialLight" {
    const t = theme.Presets.materialLight(testing.allocator);
    defer {
        var mut_t = t;
        mut_t.deinit();
    }

    try testing.expectEqualStrings("material-light", t.name);
    try testing.expectEqual(theme.ThemeMode.light, t.mode);
}

test "Presets - materialDark" {
    const t = theme.Presets.materialDark(testing.allocator);
    defer {
        var mut_t = t;
        mut_t.deinit();
    }

    try testing.expectEqualStrings("material-dark", t.name);
    try testing.expectEqual(theme.ThemeMode.dark, t.mode);
}

test "Presets - nord" {
    const t = theme.Presets.nord(testing.allocator);
    defer {
        var mut_t = t;
        mut_t.deinit();
    }

    try testing.expectEqualStrings("nord", t.name);
    try testing.expectEqual(theme.ThemeMode.dark, t.mode);
    try testing.expect(t.colors.primary.r == 136);
}

test "Presets - dracula" {
    const t = theme.Presets.dracula(testing.allocator);
    defer {
        var mut_t = t;
        mut_t.deinit();
    }

    try testing.expectEqualStrings("dracula", t.name);
    try testing.expectEqual(theme.ThemeMode.dark, t.mode);
    try testing.expect(t.colors.primary.r == 189);
}

test "Presets - gruvbox" {
    const t = theme.Presets.gruvbox(testing.allocator);
    defer {
        var mut_t = t;
        mut_t.deinit();
    }

    try testing.expectEqualStrings("gruvbox", t.name);
    try testing.expectEqual(theme.ThemeMode.dark, t.mode);
    try testing.expect(t.colors.primary.r == 251);
}

test "ColorScheme - all status colors" {
    const colors = theme.defaultLightColors();

    try testing.expect(colors.success.r == 76);
    try testing.expect(colors.warning.r == 255);
    try testing.expect(colors.info.r == 33);
}

test "ColorScheme - all interactive states" {
    const colors = theme.defaultLightColors();

    try testing.expect(colors.hover.a < 255);
    try testing.expect(colors.pressed.a < 255);
    try testing.expect(colors.focused.a < 255);
    try testing.expect(colors.selected.a < 255);
}

test "Shadows - all shadow sizes" {
    const shadows = theme.Shadows{};

    try testing.expectEqual(@as(i32, 0), shadows.none.x);
    try testing.expectEqual(@as(i32, 0), shadows.sm.x);
    try testing.expectEqual(@as(u32, 2), shadows.sm.blur);
    try testing.expectEqual(@as(u32, 4), shadows.md.blur);
    try testing.expectEqual(@as(u32, 8), shadows.lg.blur);
    try testing.expectEqual(@as(u32, 16), shadows.xl.blur);
}

test "Theme - color to hex conversion" {
    var t = theme.Theme.init(testing.allocator, "test", .light);
    defer t.deinit();

    const css = try t.toCSS(testing.allocator);
    defer testing.allocator.free(css);

    // Check that hex colors are formatted correctly
    try testing.expect(std.mem.indexOf(u8, css, "#") != null);
}

test "Typography - all heading sizes" {
    const typo = theme.Typography{};

    try testing.expectEqual(@as(f32, 32.0), typo.h1_size);
    try testing.expectEqual(@as(f32, 28.0), typo.h2_size);
    try testing.expectEqual(@as(f32, 24.0), typo.h3_size);
    try testing.expectEqual(@as(f32, 20.0), typo.h4_size);
    try testing.expectEqual(@as(f32, 18.0), typo.h5_size);
    try testing.expectEqual(@as(f32, 16.0), typo.h6_size);
}

test "Theme - custom mode initialization" {
    var t = theme.Theme.init(testing.allocator, "custom", .custom);
    defer t.deinit();

    try testing.expectEqual(theme.ThemeMode.custom, t.mode);
}

test "Theme - auto mode initialization" {
    var t = theme.Theme.init(testing.allocator, "auto", .auto);
    defer t.deinit();

    try testing.expectEqual(theme.ThemeMode.auto, t.mode);
}

test "ThemeManager - multiple custom properties" {
    var t = theme.Theme.init(testing.allocator, "test", .light);
    defer t.deinit();

    try t.setCustomProperty("prop1", "value1");
    try t.setCustomProperty("prop2", "value2");
    try t.setCustomProperty("prop3", "value3");

    try testing.expectEqualStrings("value1", t.getCustomProperty("prop1").?);
    try testing.expectEqualStrings("value2", t.getCustomProperty("prop2").?);
    try testing.expectEqualStrings("value3", t.getCustomProperty("prop3").?);
}
