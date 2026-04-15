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
        errdefer allocator.destroy(autocomplete);
        const component = try Component.init(allocator, "autocomplete", props);
        autocomplete.* = Autocomplete{
            .component = component,
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
        const allocator = self.component.allocator;
        // Free owned suggestion storage (label, value, description, icon).
        for (self.suggestions.items) |s| {
            allocator.free(s.label);
            allocator.free(s.value);
            if (s.description) |d| allocator.free(d);
            if (s.icon) |i| allocator.free(i);
        }
        // Free the current input buffer (see `setInput`).
        if (self.input_value.len > 0) allocator.free(self.input_value);
        self.suggestions.deinit(allocator);
        self.filtered_suggestions.deinit(allocator);
        self.component.deinit();
        allocator.destroy(self);
    }

    pub fn addSuggestion(self: *Autocomplete, label: []const u8, value: []const u8) !void {
        // Dupe label/value so the component owns its storage. Previously
        // these were borrowed, so any caller that passed a transient buffer
        // ended up with a dangling suggestion.
        const allocator = self.component.allocator;
        const label_dup = try allocator.dupe(u8, label);
        errdefer allocator.free(label_dup);
        const value_dup = try allocator.dupe(u8, value);
        errdefer allocator.free(value_dup);

        try self.suggestions.append(allocator, .{
            .label = label_dup,
            .value = value_dup,
        });
    }

    pub fn addSuggestionWithDetails(
        self: *Autocomplete,
        label: []const u8,
        value: []const u8,
        description: ?[]const u8,
        icon: ?[]const u8,
    ) !void {
        const allocator = self.component.allocator;
        const label_dup = try allocator.dupe(u8, label);
        errdefer allocator.free(label_dup);
        const value_dup = try allocator.dupe(u8, value);
        errdefer allocator.free(value_dup);
        const desc_dup = if (description) |d| try allocator.dupe(u8, d) else null;
        errdefer if (desc_dup) |d| allocator.free(d);
        const icon_dup = if (icon) |i| try allocator.dupe(u8, i) else null;
        errdefer if (icon_dup) |i| allocator.free(i);

        try self.suggestions.append(allocator, .{
            .label = label_dup,
            .value = value_dup,
            .description = desc_dup,
            .icon = icon_dup,
        });
    }

    pub fn clearSuggestions(self: *Autocomplete) void {
        const allocator = self.component.allocator;
        for (self.suggestions.items) |s| {
            allocator.free(s.label);
            allocator.free(s.value);
            if (s.description) |d| allocator.free(d);
            if (s.icon) |i| allocator.free(i);
        }
        self.suggestions.clearRetainingCapacity();
        self.filtered_suggestions.clearRetainingCapacity();
    }

    pub fn setInput(self: *Autocomplete, value: []const u8) !void {
        if (self.disabled) return;

        const allocator = self.component.allocator;
        const new_input = try allocator.dupe(u8, value);
        if (self.input_value.len > 0) allocator.free(self.input_value);
        self.input_value = new_input;

        if (self.on_input) |callback| {
            callback(self.input_value);
        }

        // Filter suggestions
        try self.filterSuggestions();

        // Open dropdown if we have results and meet min_chars
        if (self.input_value.len >= self.min_chars and self.filtered_suggestions.items.len > 0) {
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

        // Lower the needle ONCE instead of per-suggestion. The old
        // implementation allocated a fresh lowered copy of the needle AND
        // of every suggestion label on every call, turning a keystroke
        // into O(N) allocator churn.
        const allocator = self.component.allocator;
        const needle_buf: ?[]u8 = if (self.case_sensitive)
            null
        else
            std.ascii.allocLowerString(allocator, self.input_value) catch null;
        defer if (needle_buf) |nb| allocator.free(nb);
        const needle: []const u8 = if (needle_buf) |nb| nb else self.input_value;

        for (self.suggestions.items, 0..) |suggestion, i| {
            if (self.matchesWith(suggestion.label, needle)) {
                try self.filtered_suggestions.append(allocator, i);

                if (self.filtered_suggestions.items.len >= self.max_suggestions) {
                    break;
                }
            }
        }
    }

    /// Match `text` against the pre-lowered (if applicable) `needle`.
    fn matchesWith(self: *const Autocomplete, text: []const u8, needle: []const u8) bool {
        const allocator = self.component.allocator;
        const haystack_buf: ?[]u8 = if (self.case_sensitive)
            null
        else
            std.ascii.allocLowerString(allocator, text) catch return false;
        defer if (haystack_buf) |hb| allocator.free(hb);
        const haystack: []const u8 = if (haystack_buf) |hb| hb else text;

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

    pub fn selectSuggestion(self: *Autocomplete, index: usize) !void {
        if (index >= self.filtered_suggestions.items.len) return;

        const suggestion_idx = self.filtered_suggestions.items[index];
        const suggestion = &self.suggestions.items[suggestion_idx];

        self.selected_index = index;

        // Replace `input_value` with a duped copy of the suggestion's value
        // so we continue to own the buffer. Previously this was a direct
        // slice assignment, which made `input_value` alias the suggestion
        // and later caused a double-free in `deinit` / `setInput`.
        const allocator = self.component.allocator;
        const new_input = try allocator.dupe(u8, suggestion.value);
        if (self.input_value.len > 0) allocator.free(self.input_value);
        self.input_value = new_input;

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
