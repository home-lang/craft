const std = @import("std");
const testing = std.testing;
const shortcuts = @import("../src/shortcuts.zig");

test "Key enum - letters" {
    try testing.expectEqual(shortcuts.Key.a, .a);
    try testing.expectEqual(shortcuts.Key.z, .z);
    try testing.expectEqual(shortcuts.Key.m, .m);
}

test "Key enum - numbers" {
    try testing.expectEqual(shortcuts.Key.@"0", .@"0");
    try testing.expectEqual(shortcuts.Key.@"5", .@"5");
    try testing.expectEqual(shortcuts.Key.@"9", .@"9");
}

test "Key enum - function keys" {
    try testing.expectEqual(shortcuts.Key.f1, .f1);
    try testing.expectEqual(shortcuts.Key.f12, .f12);
    try testing.expectEqual(shortcuts.Key.f20, .f20);
}

test "Key enum - navigation" {
    try testing.expectEqual(shortcuts.Key.left, .left);
    try testing.expectEqual(shortcuts.Key.right, .right);
    try testing.expectEqual(shortcuts.Key.up, .up);
    try testing.expectEqual(shortcuts.Key.down, .down);
    try testing.expectEqual(shortcuts.Key.home, .home);
    try testing.expectEqual(shortcuts.Key.end, .end);
}

test "Key enum - editing" {
    try testing.expectEqual(shortcuts.Key.backspace, .backspace);
    try testing.expectEqual(shortcuts.Key.delete, .delete);
    try testing.expectEqual(shortcuts.Key.enter, .enter);
    try testing.expectEqual(shortcuts.Key.tab, .tab);
    try testing.expectEqual(shortcuts.Key.escape, .escape);
}

test "Key enum - media keys" {
    try testing.expectEqual(shortcuts.Key.volume_up, .volume_up);
    try testing.expectEqual(shortcuts.Key.volume_down, .volume_down);
    try testing.expectEqual(shortcuts.Key.media_play, .media_play);
}

test "Modifiers - none" {
    const mods = shortcuts.Modifiers.none();

    try testing.expect(!mods.ctrl);
    try testing.expect(!mods.alt);
    try testing.expect(!mods.shift);
    try testing.expect(!mods.meta);
}

test "Modifiers - ctrl" {
    const mods = shortcuts.Modifiers.withCtrl();

    try testing.expect(mods.ctrl);
    try testing.expect(!mods.alt);
    try testing.expect(!mods.shift);
    try testing.expect(!mods.meta);
}

test "Modifiers - alt" {
    const mods = shortcuts.Modifiers.withAlt();

    try testing.expect(!mods.ctrl);
    try testing.expect(mods.alt);
    try testing.expect(!mods.shift);
    try testing.expect(!mods.meta);
}

test "Modifiers - shift" {
    const mods = shortcuts.Modifiers.withShift();

    try testing.expect(!mods.ctrl);
    try testing.expect(!mods.alt);
    try testing.expect(mods.shift);
    try testing.expect(!mods.meta);
}

test "Modifiers - meta" {
    const mods = shortcuts.Modifiers.withMeta();

    try testing.expect(!mods.ctrl);
    try testing.expect(!mods.alt);
    try testing.expect(!mods.shift);
    try testing.expect(mods.meta);
}

test "Modifiers - equals same" {
    const mods1 = shortcuts.Modifiers.withCtrl();
    const mods2 = shortcuts.Modifiers.withCtrl();

    try testing.expect(mods1.equals(mods2));
}

test "Modifiers - equals different" {
    const mods1 = shortcuts.Modifiers.withCtrl();
    const mods2 = shortcuts.Modifiers.withAlt();

    try testing.expect(!mods1.equals(mods2));
}

test "Modifiers - combined" {
    const mods = shortcuts.Modifiers{
        .ctrl = true,
        .shift = true,
    };

    try testing.expect(mods.ctrl);
    try testing.expect(mods.shift);
    try testing.expect(!mods.alt);
    try testing.expect(!mods.meta);
}

test "ShortcutManager - init and deinit" {
    var manager = shortcuts.ShortcutManager.init(testing.allocator);
    defer manager.deinit();

    try testing.expectEqual(@as(usize, 0), manager.shortcuts.items.len);
}

test "ShortcutManager - register shortcut" {
    var manager = shortcuts.ShortcutManager.init(testing.allocator);
    defer manager.deinit();

    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.Shortcut{
        .key = .s,
        .modifiers = shortcuts.Modifiers.withCtrl(),
        .action = TestAction.action,
    };

    try manager.register(shortcut);
    try testing.expectEqual(@as(usize, 1), manager.shortcuts.items.len);
}

test "ShortcutManager - register multiple shortcuts" {
    var manager = shortcuts.ShortcutManager.init(testing.allocator);
    defer manager.deinit();

    const TestAction = struct {
        fn action() void {}
    };

    try manager.register(.{
        .key = .s,
        .modifiers = shortcuts.Modifiers.withCtrl(),
        .action = TestAction.action,
    });

    try manager.register(.{
        .key = .o,
        .modifiers = shortcuts.Modifiers.withCtrl(),
        .action = TestAction.action,
    });

    try testing.expectEqual(@as(usize, 2), manager.shortcuts.items.len);
}

test "ShortcutManager - unregister shortcut" {
    var manager = shortcuts.ShortcutManager.init(testing.allocator);
    defer manager.deinit();

    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.Shortcut{
        .key = .s,
        .modifiers = shortcuts.Modifiers.withCtrl(),
        .action = TestAction.action,
    };

    try manager.register(shortcut);
    manager.unregister(.s, shortcuts.Modifiers.withCtrl());

    try testing.expectEqual(@as(usize, 0), manager.shortcuts.items.len);
}

test "ShortcutManager - handleKeyPress triggers action" {
    var manager = shortcuts.ShortcutManager.init(testing.allocator);
    defer manager.deinit();

    var was_called = false;
    const TestAction = struct {
        var called: *bool = undefined;
        fn action() void {
            called.* = true;
        }
    };
    TestAction.called = &was_called;

    try manager.register(.{
        .key = .s,
        .modifiers = shortcuts.Modifiers.withCtrl(),
        .action = TestAction.action,
    });

    const handled = manager.handleKeyPress(.s, shortcuts.Modifiers.withCtrl());

    try testing.expect(handled);
    try testing.expect(was_called);
}

test "ShortcutManager - handleKeyPress no match" {
    var manager = shortcuts.ShortcutManager.init(testing.allocator);
    defer manager.deinit();

    const TestAction = struct {
        fn action() void {}
    };

    try manager.register(.{
        .key = .s,
        .modifiers = shortcuts.Modifiers.withCtrl(),
        .action = TestAction.action,
    });

    const handled = manager.handleKeyPress(.o, shortcuts.Modifiers.withCtrl());

    try testing.expect(!handled);
}

test "ShortcutManager - setEnabled" {
    var manager = shortcuts.ShortcutManager.init(testing.allocator);
    defer manager.deinit();

    const TestAction = struct {
        fn action() void {}
    };

    try manager.register(.{
        .key = .s,
        .modifiers = shortcuts.Modifiers.withCtrl(),
        .action = TestAction.action,
    });

    manager.setEnabled(.s, shortcuts.Modifiers.withCtrl(), false);

    try testing.expect(!manager.shortcuts.items[0].enabled);
}

test "ShortcutManager - disabled shortcut not triggered" {
    var manager = shortcuts.ShortcutManager.init(testing.allocator);
    defer manager.deinit();

    var was_called = false;
    const TestAction = struct {
        var called: *bool = undefined;
        fn action() void {
            called.* = true;
        }
    };
    TestAction.called = &was_called;

    try manager.register(.{
        .key = .s,
        .modifiers = shortcuts.Modifiers.withCtrl(),
        .action = TestAction.action,
    });

    manager.setEnabled(.s, shortcuts.Modifiers.withCtrl(), false);
    const handled = manager.handleKeyPress(.s, shortcuts.Modifiers.withCtrl());

    try testing.expect(!handled);
    try testing.expect(!was_called);
}

test "ShortcutManager - getAll" {
    var manager = shortcuts.ShortcutManager.init(testing.allocator);
    defer manager.deinit();

    const TestAction = struct {
        fn action() void {}
    };

    try manager.register(.{
        .key = .s,
        .modifiers = shortcuts.Modifiers.withCtrl(),
        .action = TestAction.action,
    });

    const all = manager.getAll();
    try testing.expectEqual(@as(usize, 1), all.len);
}

test "ShortcutManager - clear" {
    var manager = shortcuts.ShortcutManager.init(testing.allocator);
    defer manager.deinit();

    const TestAction = struct {
        fn action() void {}
    };

    try manager.register(.{
        .key = .s,
        .modifiers = shortcuts.Modifiers.withCtrl(),
        .action = TestAction.action,
    });

    manager.clear();
    try testing.expectEqual(@as(usize, 0), manager.shortcuts.items.len);
}

test "CommonShortcuts - save" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.CommonShortcuts.save(TestAction.action);

    try testing.expectEqual(shortcuts.Key.s, shortcut.key);
    try testing.expectEqualStrings("Save", shortcut.description.?);
}

test "CommonShortcuts - open" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.CommonShortcuts.open(TestAction.action);

    try testing.expectEqual(shortcuts.Key.o, shortcut.key);
    try testing.expectEqualStrings("Open", shortcut.description.?);
}

test "CommonShortcuts - copy" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.CommonShortcuts.copy(TestAction.action);

    try testing.expectEqual(shortcuts.Key.c, shortcut.key);
    try testing.expectEqualStrings("Copy", shortcut.description.?);
}

test "CommonShortcuts - paste" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.CommonShortcuts.paste(TestAction.action);

    try testing.expectEqual(shortcuts.Key.v, shortcut.key);
}

test "CommonShortcuts - cut" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.CommonShortcuts.cut(TestAction.action);

    try testing.expectEqual(shortcuts.Key.x, shortcut.key);
}

test "CommonShortcuts - undo" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.CommonShortcuts.undo(TestAction.action);

    try testing.expectEqual(shortcuts.Key.z, shortcut.key);
}

test "CommonShortcuts - redo" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.CommonShortcuts.redo(TestAction.action);

    try testing.expectEqual(shortcuts.Key.z, shortcut.key);
    try testing.expect(shortcut.modifiers.shift);
}

test "CommonShortcuts - selectAll" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.CommonShortcuts.selectAll(TestAction.action);

    try testing.expectEqual(shortcuts.Key.a, shortcut.key);
}

test "CommonShortcuts - find" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.CommonShortcuts.find(TestAction.action);

    try testing.expectEqual(shortcuts.Key.f, shortcut.key);
}

test "CommonShortcuts - fullscreen" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.CommonShortcuts.fullscreen(TestAction.action);

    try testing.expectEqual(shortcuts.Key.f11, shortcut.key);
}

test "CommonShortcuts - devTools" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.CommonShortcuts.devTools(TestAction.action);

    try testing.expectEqual(shortcuts.Key.f12, shortcut.key);
}

test "ShortcutRecorder - init" {
    var recorder = shortcuts.ShortcutRecorder.init();

    try testing.expect(!recorder.recording);
    try testing.expect(recorder.current_key == null);
}

test "ShortcutRecorder - startRecording" {
    var recorder = shortcuts.ShortcutRecorder.init();

    const TestCallback = struct {
        fn callback(_: shortcuts.Key, _: shortcuts.Modifiers) void {}
    };

    recorder.startRecording(TestCallback.callback);

    try testing.expect(recorder.recording);
}

test "ShortcutRecorder - stopRecording" {
    var recorder = shortcuts.ShortcutRecorder.init();

    const TestCallback = struct {
        fn callback(_: shortcuts.Key, _: shortcuts.Modifiers) void {}
    };

    recorder.startRecording(TestCallback.callback);
    recorder.stopRecording();

    try testing.expect(!recorder.recording);
}

test "ShortcutRecorder - handleKeyPress while recording" {
    var recorder = shortcuts.ShortcutRecorder.init();

    var captured_key: ?shortcuts.Key = null;
    const TestCallback = struct {
        var key_ptr: *?shortcuts.Key = undefined;
        fn callback(key: shortcuts.Key, _: shortcuts.Modifiers) void {
            key_ptr.* = key;
        }
    };
    TestCallback.key_ptr = &captured_key;

    recorder.startRecording(TestCallback.callback);
    recorder.handleKeyPress(.s, shortcuts.Modifiers.withCtrl());

    try testing.expect(captured_key == .s);
    try testing.expect(!recorder.recording); // Should stop after capture
}

test "Shortcut - with description" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.Shortcut{
        .key = .s,
        .modifiers = shortcuts.Modifiers.withCtrl(),
        .action = TestAction.action,
        .description = "Save file",
    };

    try testing.expectEqualStrings("Save file", shortcut.description.?);
}

test "Shortcut - global flag" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.Shortcut{
        .key = .s,
        .modifiers = shortcuts.Modifiers.withCtrl(),
        .action = TestAction.action,
        .global = true,
    };

    try testing.expect(shortcut.global);
}

test "Shortcut - enabled by default" {
    const TestAction = struct {
        fn action() void {}
    };

    const shortcut = shortcuts.Shortcut{
        .key = .s,
        .modifiers = shortcuts.Modifiers.withCtrl(),
        .action = TestAction.action,
    };

    try testing.expect(shortcut.enabled);
}
