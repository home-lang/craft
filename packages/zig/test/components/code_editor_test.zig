const std = @import("std");
const components = @import("components");
const CodeEditor = components.CodeEditor;
const ComponentProps = components.ComponentProps;

var last_content: []const u8 = "";
var saved_content: []const u8 = "";

fn handleChange(content: []const u8) void {
    last_content = content;
}

fn handleSave(content: []const u8) void {
    saved_content = content;
}

test "code editor creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const editor = try CodeEditor.init(allocator, "zig", props);
    defer editor.deinit();

    try std.testing.expectEqualStrings("zig", editor.language);
    try std.testing.expect(editor.theme == .dark);
    try std.testing.expect(editor.line_numbers);
    try std.testing.expect(editor.syntax_highlighting);
    try std.testing.expect(editor.auto_complete);
}

test "code editor set content" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const editor = try CodeEditor.init(allocator, "zig", props);
    defer editor.deinit();

    last_content = "";
    editor.onChange(&handleChange);

    const code = "const std = @import(\"std\");";
    editor.setContent(code);

    try std.testing.expectEqualStrings(code, editor.content);
    try std.testing.expectEqualStrings(code, last_content);
}

test "code editor themes" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const editor = try CodeEditor.init(allocator, "javascript", props);
    defer editor.deinit();

    editor.setTheme(.monokai);
    try std.testing.expect(editor.theme == .monokai);

    editor.setTheme(.github);
    try std.testing.expect(editor.theme == .github);
}

test "code editor settings" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const editor = try CodeEditor.init(allocator, "python", props);
    defer editor.deinit();

    editor.setLineNumbers(false);
    try std.testing.expect(!editor.line_numbers);

    editor.setSyntaxHighlighting(false);
    try std.testing.expect(!editor.syntax_highlighting);

    editor.setAutoComplete(false);
    try std.testing.expect(!editor.auto_complete);

    editor.setTabSize(2);
    try std.testing.expect(editor.tab_size == 2);

    editor.setWordWrap(true);
    try std.testing.expect(editor.word_wrap);
}

test "code editor readonly" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const editor = try CodeEditor.init(allocator, "rust", props);
    defer editor.deinit();

    editor.setReadonly(true);
    editor.setContent("test");

    // Should not change content when readonly
    try std.testing.expectEqualStrings("", editor.content);
}

test "code editor save" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const editor = try CodeEditor.init(allocator, "go", props);
    defer editor.deinit();

    saved_content = "";
    editor.onSave(&handleSave);

    const code = "package main";
    editor.setContent(code);
    editor.save();

    try std.testing.expectEqualStrings(code, saved_content);
}

test "code editor line count" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const editor = try CodeEditor.init(allocator, "zig", props);
    defer editor.deinit();

    const code = "line 1\nline 2\nline 3";
    editor.setContent(code);

    const line_count = editor.getLineCount();
    try std.testing.expect(line_count == 3);
}

test "code editor clear" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const editor = try CodeEditor.init(allocator, "c", props);
    defer editor.deinit();

    editor.setContent("some code");
    try std.testing.expect(editor.content.len > 0);

    editor.clear();
    try std.testing.expectEqualStrings("", editor.content);
}

test "code editor tab size clamping" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const editor = try CodeEditor.init(allocator, "ruby", props);
    defer editor.deinit();

    editor.setTabSize(10);
    try std.testing.expect(editor.tab_size == 8); // Clamped to max

    editor.setTabSize(0);
    try std.testing.expect(editor.tab_size == 1); // Clamped to min
}
