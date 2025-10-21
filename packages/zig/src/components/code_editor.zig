const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Code Editor Component
pub const CodeEditor = struct {
    component: Component,
    content: []const u8,
    language: []const u8,
    theme: EditorTheme,
    line_numbers: bool,
    syntax_highlighting: bool,
    auto_complete: bool,
    tab_size: u8,
    word_wrap: bool,
    readonly: bool,
    on_change: ?*const fn ([]const u8) void,
    on_save: ?*const fn ([]const u8) void,

    pub const EditorTheme = enum {
        light,
        dark,
        monokai,
        solarized_light,
        solarized_dark,
        github,
        dracula,
    };

    pub fn init(allocator: std.mem.Allocator, language: []const u8, props: ComponentProps) !*CodeEditor {
        const editor = try allocator.create(CodeEditor);
        editor.* = CodeEditor{
            .component = try Component.init(allocator, "code_editor", props),
            .content = "",
            .language = language,
            .theme = .dark,
            .line_numbers = true,
            .syntax_highlighting = true,
            .auto_complete = true,
            .tab_size = 4,
            .word_wrap = false,
            .readonly = false,
            .on_change = null,
            .on_save = null,
        };
        return editor;
    }

    pub fn deinit(self: *CodeEditor) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setContent(self: *CodeEditor, content: []const u8) void {
        if (self.readonly) return;
        self.content = content;
        if (self.on_change) |callback| {
            callback(content);
        }
    }

    pub fn appendContent(self: *CodeEditor, text: []const u8, allocator: std.mem.Allocator) !void {
        if (self.readonly) return;
        const new_content = try std.fmt.allocPrint(allocator, "{s}{s}", .{ self.content, text });
        self.content = new_content;
        if (self.on_change) |callback| {
            callback(self.content);
        }
    }

    pub fn setTheme(self: *CodeEditor, theme: EditorTheme) void {
        self.theme = theme;
    }

    pub fn setLanguage(self: *CodeEditor, language: []const u8) void {
        self.language = language;
    }

    pub fn setLineNumbers(self: *CodeEditor, enabled: bool) void {
        self.line_numbers = enabled;
    }

    pub fn setSyntaxHighlighting(self: *CodeEditor, enabled: bool) void {
        self.syntax_highlighting = enabled;
    }

    pub fn setAutoComplete(self: *CodeEditor, enabled: bool) void {
        self.auto_complete = enabled;
    }

    pub fn setTabSize(self: *CodeEditor, size: u8) void {
        self.tab_size = std.math.clamp(size, 1, 8);
    }

    pub fn setWordWrap(self: *CodeEditor, enabled: bool) void {
        self.word_wrap = enabled;
    }

    pub fn setReadonly(self: *CodeEditor, readonly: bool) void {
        self.readonly = readonly;
    }

    pub fn save(self: *CodeEditor) void {
        if (self.on_save) |callback| {
            callback(self.content);
        }
    }

    pub fn onChange(self: *CodeEditor, callback: *const fn ([]const u8) void) void {
        self.on_change = callback;
    }

    pub fn onSave(self: *CodeEditor, callback: *const fn ([]const u8) void) void {
        self.on_save = callback;
    }

    pub fn getLineCount(self: *const CodeEditor) usize {
        if (self.content.len == 0) return 0;
        var count: usize = 1;
        for (self.content) |ch| {
            if (ch == '\n') count += 1;
        }
        return count;
    }

    pub fn clear(self: *CodeEditor) void {
        self.setContent("");
    }
};
