const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Autocomplete Component - Search with suggestions
pub const Autocomplete = struct {
    component: Component,
    input_value: []const u8,
    suggestions: std.ArrayList(Suggestion),
    filtered_suggestions: std.ArrayList(usize),
    selected_index: ?usize,
    open: bool,
    disabled: bool,
    case_sensitive: bool,
    min_chars: usize,
    max_suggestions: usize,
    placeholder: ?[]const u8,
    match_mode: MatchMode,
    on_select: ?*const fn (*const Suggestion) void,
    on_input: ?*const fn ([]const u8) void,
    on_open: ?*const fn () void,
    on_close: ?*const fn () void,

    pub const Suggestion = struct {
        label: []const u8,
        value: []const u8,
        description: ?[]const u8 = null,
        icon: ?[]const u8 = null,
        data: ?*anyopaque = null,
    };

    pub const MatchMode = enum {
        starts_with,
        contains,
        fuzzy,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*Autocomplete {
        const autocomplete = try allocator.create(Autocomplete);
        autocomplete.* = Autocomplete{
            .component = try Component.init(allocator, "autocomplete", props),
            .input_value = "",
            .suggestions = .{},
            .filtered_suggestions = .{},
            .selected_index = null,
            .open = false,
            .disabled = false,
            .case_sensitive = false,
            .min_chars = 1,
            .max_suggestions = 10,
            .placeholder = null,
            .match_mode = .contains,
            .on_select = null,
            .on_input = null,
            .on_open = null,
            .on_close = null,
        };
        return autocomplete;
    }

    pub fn deinit(self: *Autocomplete) void {
        self.suggestions.deinit(self.component.allocator);
        self.filtered_suggestions.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addSuggestion(self: *Autocomplete, label: []const u8, value: []const u8) !void {
        try self.suggestions.append(self.component.allocator, .{
            .label = label,
            .value = value,
        });
    }

    pub fn addSuggestionWithDetails(
        self: *Autocomplete,
        label: []const u8,
        value: []const u8,
        description: ?[]const u8,
        icon: ?[]const u8,
    ) !void {
        try self.suggestions.append(self.component.allocator, .{
            .label = label,
            .value = value,
            .description = description,
            .icon = icon,
        });
    }

    pub fn clearSuggestions(self: *Autocomplete) void {
        self.suggestions.clearRetainingCapacity();
        self.filtered_suggestions.clearRetainingCapacity();
    }

    pub fn setInput(self: *Autocomplete, value: []const u8) !void {
        if (self.disabled) return;

        self.input_value = value;

        if (self.on_input) |callback| {
            callback(value);
        }

        // Filter suggestions
        try self.filterSuggestions();

        // Open dropdown if we have results and meet min_chars
        if (value.len >= self.min_chars and self.filtered_suggestions.items.len > 0) {
            self.openDropdown();
        } else {
            self.closeDropdown();
        }
    }

    fn filterSuggestions(self: *Autocomplete) !void {
        self.filtered_suggestions.clearRetainingCapacity();

        if (self.input_value.len < self.min_chars) {
            return;
        }

        for (self.suggestions.items, 0..) |suggestion, i| {
            if (self.matches(suggestion.label)) {
                try self.filtered_suggestions.append(self.component.allocator, i);

                if (self.filtered_suggestions.items.len >= self.max_suggestions) {
                    break;
                }
            }
        }
    }

    fn matches(self: *const Autocomplete, text: []const u8) bool {
        const needle = if (self.case_sensitive) self.input_value else std.ascii.allocLowerString(self.component.allocator, self.input_value) catch return false;
        defer if (!self.case_sensitive) self.component.allocator.free(needle);

        const haystack = if (self.case_sensitive) text else std.ascii.allocLowerString(self.component.allocator, text) catch return false;
        defer if (!self.case_sensitive) self.component.allocator.free(haystack);

        return switch (self.match_mode) {
            .starts_with => std.mem.startsWith(u8, haystack, needle),
            .contains => std.mem.indexOf(u8, haystack, needle) != null,
            .fuzzy => self.fuzzyMatch(haystack, needle),
        };
    }

    fn fuzzyMatch(self: *const Autocomplete, haystack: []const u8, needle: []const u8) bool {
        _ = self;
        var h_idx: usize = 0;
        var n_idx: usize = 0;

        while (n_idx < needle.len and h_idx < haystack.len) {
            if (needle[n_idx] == haystack[h_idx]) {
                n_idx += 1;
            }
            h_idx += 1;
        }

        return n_idx == needle.len;
    }

    pub fn selectSuggestion(self: *Autocomplete, index: usize) void {
        if (index >= self.filtered_suggestions.items.len) return;

        const suggestion_idx = self.filtered_suggestions.items[index];
        const suggestion = &self.suggestions.items[suggestion_idx];

        self.selected_index = index;
        self.input_value = suggestion.value;

        if (self.on_select) |callback| {
            callback(suggestion);
        }

        self.closeDropdown();
    }

    pub fn selectNext(self: *Autocomplete) void {
        if (self.filtered_suggestions.items.len == 0) return;

        if (self.selected_index) |idx| {
            if (idx + 1 < self.filtered_suggestions.items.len) {
                self.selected_index = idx + 1;
            }
        } else {
            self.selected_index = 0;
        }
    }

    pub fn selectPrevious(self: *Autocomplete) void {
        if (self.filtered_suggestions.items.len == 0) return;

        if (self.selected_index) |idx| {
            if (idx > 0) {
                self.selected_index = idx - 1;
            }
        } else {
            self.selected_index = self.filtered_suggestions.items.len - 1;
        }
    }

    pub fn openDropdown(self: *Autocomplete) void {
        if (!self.open and self.filtered_suggestions.items.len > 0) {
            self.open = true;
            if (self.on_open) |callback| {
                callback();
            }
        }
    }

    pub fn closeDropdown(self: *Autocomplete) void {
        if (self.open) {
            self.open = false;
            self.selected_index = null;
            if (self.on_close) |callback| {
                callback();
            }
        }
    }

    pub fn setDisabled(self: *Autocomplete, disabled: bool) void {
        self.disabled = disabled;
        if (disabled) {
            self.closeDropdown();
        }
    }

    pub fn setCaseSensitive(self: *Autocomplete, case_sensitive: bool) void {
        self.case_sensitive = case_sensitive;
    }

    pub fn setMinChars(self: *Autocomplete, min_chars: usize) void {
        self.min_chars = min_chars;
    }

    pub fn setMaxSuggestions(self: *Autocomplete, max: usize) void {
        self.max_suggestions = max;
    }

    pub fn setMatchMode(self: *Autocomplete, mode: MatchMode) void {
        self.match_mode = mode;
    }

    pub fn setPlaceholder(self: *Autocomplete, placeholder: []const u8) void {
        self.placeholder = placeholder;
    }

    pub fn getFilteredCount(self: *const Autocomplete) usize {
        return self.filtered_suggestions.items.len;
    }

    pub fn clear(self: *Autocomplete) void {
        self.input_value = "";
        self.filtered_suggestions.clearRetainingCapacity();
        self.closeDropdown();
    }

    pub fn onSelect(self: *Autocomplete, callback: *const fn (*const Suggestion) void) void {
        self.on_select = callback;
    }

    pub fn onInput(self: *Autocomplete, callback: *const fn ([]const u8) void) void {
        self.on_input = callback;
    }

    pub fn onOpen(self: *Autocomplete, callback: *const fn () void) void {
        self.on_open = callback;
    }

    pub fn onClose(self: *Autocomplete, callback: *const fn () void) void {
        self.on_close = callback;
    }
};
