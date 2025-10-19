const std = @import("std");

/// Native Components Library
/// Provides native UI components with platform-specific implementations

pub const Component = struct {
    id: []const u8,
    handle: ?*anyopaque,
    props: ComponentProps,
    children: std.ArrayList(*Component),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, props: ComponentProps) !Component {
        return Component{
            .id = id,
            .handle = null,
            .props = props,
            .children = std.ArrayList(*Component).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Component) void {
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit();
    }

    pub fn appendChild(self: *Component, child: *Component) !void {
        try self.children.append(child);
    }

    pub fn removeChild(self: *Component, child: *Component) void {
        for (self.children.items, 0..) |c, i| {
            if (c == child) {
                _ = self.children.swapRemove(i);
                break;
            }
        }
    }
};

pub const ComponentProps = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u32 = 100,
    height: u32 = 30,
    enabled: bool = true,
    visible: bool = true,
    style: Style = .{},
};

pub const Style = struct {
    background_color: ?[4]u8 = null,
    foreground_color: ?[4]u8 = null,
    border_color: ?[4]u8 = null,
    border_width: u32 = 0,
    border_radius: u32 = 0,
    font_size: u32 = 14,
    font_weight: FontWeight = .regular,
    padding: Padding = .{},
    margin: Margin = .{},

    pub const FontWeight = enum {
        light,
        regular,
        medium,
        bold,
    };

    pub const Padding = struct {
        top: u32 = 0,
        right: u32 = 0,
        bottom: u32 = 0,
        left: u32 = 0,
    };

    pub const Margin = struct {
        top: u32 = 0,
        right: u32 = 0,
        bottom: u32 = 0,
        left: u32 = 0,
    };
};

/// Button Component
pub const Button = struct {
    component: Component,
    text: []const u8,
    on_click: ?*const fn () void,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, props: ComponentProps) !*Button {
        const button = try allocator.create(Button);
        button.* = Button{
            .component = try Component.init(allocator, "button", props),
            .text = text,
            .on_click = null,
        };
        return button;
    }

    pub fn deinit(self: *Button) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn onClick(self: *Button, callback: *const fn () void) void {
        self.on_click = callback;
    }

    pub fn click(self: *Button) void {
        if (self.on_click) |callback| {
            callback();
        }
    }

    pub fn setText(self: *Button, text: []const u8) void {
        self.text = text;
    }
};

/// Text Input Component
pub const TextInput = struct {
    component: Component,
    value: []const u8,
    placeholder: ?[]const u8,
    max_length: ?usize,
    password: bool,
    on_change: ?*const fn ([]const u8) void,

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*TextInput {
        const input = try allocator.create(TextInput);
        input.* = TextInput{
            .component = try Component.init(allocator, "text_input", props),
            .value = "",
            .placeholder = null,
            .max_length = null,
            .password = false,
            .on_change = null,
        };
        return input;
    }

    pub fn deinit(self: *TextInput) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setValue(self: *TextInput, value: []const u8) void {
        self.value = value;
        if (self.on_change) |callback| {
            callback(value);
        }
    }

    pub fn onChange(self: *TextInput, callback: *const fn ([]const u8) void) void {
        self.on_change = callback;
    }
};

/// Label Component
pub const Label = struct {
    component: Component,
    text: []const u8,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, props: ComponentProps) !*Label {
        const label = try allocator.create(Label);
        label.* = Label{
            .component = try Component.init(allocator, "label", props),
            .text = text,
        };
        return label;
    }

    pub fn deinit(self: *Label) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setText(self: *Label, text: []const u8) void {
        self.text = text;
    }
};

/// Checkbox Component
pub const Checkbox = struct {
    component: Component,
    checked: bool,
    label: ?[]const u8,
    on_change: ?*const fn (bool) void,

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*Checkbox {
        const checkbox = try allocator.create(Checkbox);
        checkbox.* = Checkbox{
            .component = try Component.init(allocator, "checkbox", props),
            .checked = false,
            .label = null,
            .on_change = null,
        };
        return checkbox;
    }

    pub fn deinit(self: *Checkbox) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setChecked(self: *Checkbox, checked: bool) void {
        self.checked = checked;
        if (self.on_change) |callback| {
            callback(checked);
        }
    }

    pub fn toggle(self: *Checkbox) void {
        self.setChecked(!self.checked);
    }

    pub fn onChange(self: *Checkbox, callback: *const fn (bool) void) void {
        self.on_change = callback;
    }
};

/// Radio Button Component
pub const RadioButton = struct {
    component: Component,
    group: []const u8,
    value: []const u8,
    selected: bool,
    label: ?[]const u8,
    on_select: ?*const fn ([]const u8) void,

    pub fn init(allocator: std.mem.Allocator, group: []const u8, value: []const u8, props: ComponentProps) !*RadioButton {
        const radio = try allocator.create(RadioButton);
        radio.* = RadioButton{
            .component = try Component.init(allocator, "radio", props),
            .group = group,
            .value = value,
            .selected = false,
            .label = null,
            .on_select = null,
        };
        return radio;
    }

    pub fn deinit(self: *RadioButton) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn select(self: *RadioButton) void {
        self.selected = true;
        if (self.on_select) |callback| {
            callback(self.value);
        }
    }

    pub fn onSelect(self: *RadioButton, callback: *const fn ([]const u8) void) void {
        self.on_select = callback;
    }
};

/// Slider Component
pub const Slider = struct {
    component: Component,
    value: f32,
    min: f32,
    max: f32,
    step: f32,
    on_change: ?*const fn (f32) void,

    pub fn init(allocator: std.mem.Allocator, min: f32, max: f32, props: ComponentProps) !*Slider {
        const slider = try allocator.create(Slider);
        slider.* = Slider{
            .component = try Component.init(allocator, "slider", props),
            .value = min,
            .min = min,
            .max = max,
            .step = 1.0,
            .on_change = null,
        };
        return slider;
    }

    pub fn deinit(self: *Slider) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setValue(self: *Slider, value: f32) void {
        self.value = std.math.clamp(value, self.min, self.max);
        if (self.on_change) |callback| {
            callback(self.value);
        }
    }

    pub fn onChange(self: *Slider, callback: *const fn (f32) void) void {
        self.on_change = callback;
    }
};

/// Progress Bar Component
pub const ProgressBar = struct {
    component: Component,
    value: f32,
    min: f32,
    max: f32,
    indeterminate: bool,

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*ProgressBar {
        const progress = try allocator.create(ProgressBar);
        progress.* = ProgressBar{
            .component = try Component.init(allocator, "progress", props),
            .value = 0,
            .min = 0,
            .max = 100,
            .indeterminate = false,
        };
        return progress;
    }

    pub fn deinit(self: *ProgressBar) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setValue(self: *ProgressBar, value: f32) void {
        self.value = std.math.clamp(value, self.min, self.max);
    }

    pub fn getProgress(self: *ProgressBar) f32 {
        return (self.value - self.min) / (self.max - self.min);
    }
};

/// List View Component
pub const ListView = struct {
    component: Component,
    items: std.ArrayList([]const u8),
    selected_index: ?usize,
    on_select: ?*const fn (usize) void,

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*ListView {
        const list = try allocator.create(ListView);
        list.* = ListView{
            .component = try Component.init(allocator, "list", props),
            .items = std.ArrayList([]const u8).init(allocator),
            .selected_index = null,
            .on_select = null,
        };
        return list;
    }

    pub fn deinit(self: *ListView) void {
        self.items.deinit();
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addItem(self: *ListView, item: []const u8) !void {
        try self.items.append(item);
    }

    pub fn removeItem(self: *ListView, index: usize) void {
        if (index < self.items.items.len) {
            _ = self.items.swapRemove(index);
        }
    }

    pub fn selectItem(self: *ListView, index: usize) void {
        if (index < self.items.items.len) {
            self.selected_index = index;
            if (self.on_select) |callback| {
                callback(index);
            }
        }
    }

    pub fn onSelect(self: *ListView, callback: *const fn (usize) void) void {
        self.on_select = callback;
    }
};

/// Table Component
pub const Table = struct {
    component: Component,
    columns: []Column,
    rows: std.ArrayList(Row),
    selected_row: ?usize,
    on_select: ?*const fn (usize) void,

    pub const Column = struct {
        title: []const u8,
        width: u32,
    };

    pub const Row = struct {
        data: []const []const u8,
    };

    pub fn init(allocator: std.mem.Allocator, columns: []Column, props: ComponentProps) !*Table {
        const table = try allocator.create(Table);
        table.* = Table{
            .component = try Component.init(allocator, "table", props),
            .columns = columns,
            .rows = std.ArrayList(Row).init(allocator),
            .selected_row = null,
            .on_select = null,
        };
        return table;
    }

    pub fn deinit(self: *Table) void {
        self.rows.deinit();
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addRow(self: *Table, row: Row) !void {
        try self.rows.append(row);
    }

    pub fn removeRow(self: *Table, index: usize) void {
        if (index < self.rows.items.len) {
            _ = self.rows.swapRemove(index);
        }
    }

    pub fn selectRow(self: *Table, index: usize) void {
        if (index < self.rows.items.len) {
            self.selected_row = index;
            if (self.on_select) |callback| {
                callback(index);
            }
        }
    }

    pub fn onSelect(self: *Table, callback: *const fn (usize) void) void {
        self.on_select = callback;
    }
};

/// Tab View Component
pub const TabView = struct {
    component: Component,
    tabs: std.ArrayList(Tab),
    selected_tab: usize,
    on_change: ?*const fn (usize) void,

    pub const Tab = struct {
        title: []const u8,
        content: *Component,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*TabView {
        const tabs = try allocator.create(TabView);
        tabs.* = TabView{
            .component = try Component.init(allocator, "tabs", props),
            .tabs = std.ArrayList(Tab).init(allocator),
            .selected_tab = 0,
            .on_change = null,
        };
        return tabs;
    }

    pub fn deinit(self: *TabView) void {
        self.tabs.deinit();
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addTab(self: *TabView, tab: Tab) !void {
        try self.tabs.append(tab);
    }

    pub fn selectTab(self: *TabView, index: usize) void {
        if (index < self.tabs.items.len) {
            self.selected_tab = index;
            if (self.on_change) |callback| {
                callback(index);
            }
        }
    }

    pub fn onChange(self: *TabView, callback: *const fn (usize) void) void {
        self.on_change = callback;
    }
};

/// Menu Component
pub const Menu = struct {
    component: Component,
    items: std.ArrayList(MenuItem),

    pub const MenuItem = struct {
        title: []const u8,
        shortcut: ?[]const u8 = null,
        enabled: bool = true,
        checked: bool = false,
        separator: bool = false,
        submenu: ?*Menu = null,
        on_select: ?*const fn () void = null,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*Menu {
        const menu = try allocator.create(Menu);
        menu.* = Menu{
            .component = try Component.init(allocator, "menu", props),
            .items = std.ArrayList(MenuItem).init(allocator),
        };
        return menu;
    }

    pub fn deinit(self: *Menu) void {
        for (self.items.items) |item| {
            if (item.submenu) |submenu| {
                submenu.deinit();
            }
        }
        self.items.deinit();
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addItem(self: *Menu, item: MenuItem) !void {
        try self.items.append(item);
    }

    pub fn show(self: *Menu, x: i32, y: i32) void {
        _ = self;
        _ = x;
        _ = y;
        // Show menu at position
    }
};

/// Toolbar Component
pub const Toolbar = struct {
    component: Component,
    items: std.ArrayList(ToolbarItem),

    pub const ToolbarItem = union(enum) {
        button: ToolbarButton,
        separator: void,
        spacer: void,
    };

    pub const ToolbarButton = struct {
        icon: ?[]const u8,
        label: ?[]const u8,
        on_click: *const fn () void,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*Toolbar {
        const toolbar = try allocator.create(Toolbar);
        toolbar.* = Toolbar{
            .component = try Component.init(allocator, "toolbar", props),
            .items = std.ArrayList(ToolbarItem).init(allocator),
        };
        return toolbar;
    }

    pub fn deinit(self: *Toolbar) void {
        self.items.deinit();
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addButton(self: *Toolbar, button: ToolbarButton) !void {
        try self.items.append(.{ .button = button });
    }

    pub fn addSeparator(self: *Toolbar) !void {
        try self.items.append(.separator);
    }

    pub fn addSpacer(self: *Toolbar) !void {
        try self.items.append(.spacer);
    }
};

/// Status Bar Component
pub const StatusBar = struct {
    component: Component,
    text: []const u8,
    sections: std.ArrayList(StatusSection),

    pub const StatusSection = struct {
        text: []const u8,
        width: ?u32 = null,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*StatusBar {
        const status = try allocator.create(StatusBar);
        status.* = StatusBar{
            .component = try Component.init(allocator, "statusbar", props),
            .text = "",
            .sections = std.ArrayList(StatusSection).init(allocator),
        };
        return status;
    }

    pub fn deinit(self: *StatusBar) void {
        self.sections.deinit();
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setText(self: *StatusBar, text: []const u8) void {
        self.text = text;
    }

    pub fn addSection(self: *StatusBar, section: StatusSection) !void {
        try self.sections.append(section);
    }
};

/// Image View Component
pub const ImageView = struct {
    component: Component,
    image_path: []const u8,
    scale_mode: ScaleMode,

    pub const ScaleMode = enum {
        fit,
        fill,
        stretch,
        center,
    };

    pub fn init(allocator: std.mem.Allocator, image_path: []const u8, props: ComponentProps) !*ImageView {
        const image = try allocator.create(ImageView);
        image.* = ImageView{
            .component = try Component.init(allocator, "image", props),
            .image_path = image_path,
            .scale_mode = .fit,
        };
        return image;
    }

    pub fn deinit(self: *ImageView) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setImage(self: *ImageView, image_path: []const u8) void {
        self.image_path = image_path;
    }

    pub fn setScaleMode(self: *ImageView, mode: ScaleMode) void {
        self.scale_mode = mode;
    }
};

/// Scroll View Component
pub const ScrollView = struct {
    component: Component,
    content: *Component,
    scroll_x: i32,
    scroll_y: i32,
    show_scrollbars: bool,

    pub fn init(allocator: std.mem.Allocator, content: *Component, props: ComponentProps) !*ScrollView {
        const scroll = try allocator.create(ScrollView);
        scroll.* = ScrollView{
            .component = try Component.init(allocator, "scroll", props),
            .content = content,
            .scroll_x = 0,
            .scroll_y = 0,
            .show_scrollbars = true,
        };
        return scroll;
    }

    pub fn deinit(self: *ScrollView) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn scrollTo(self: *ScrollView, x: i32, y: i32) void {
        self.scroll_x = x;
        self.scroll_y = y;
    }

    pub fn scrollBy(self: *ScrollView, dx: i32, dy: i32) void {
        self.scroll_x += dx;
        self.scroll_y += dy;
    }
};

/// Split View Component
pub const SplitView = struct {
    component: Component,
    left: *Component,
    right: *Component,
    split_position: f32,
    orientation: Orientation,

    pub const Orientation = enum {
        horizontal,
        vertical,
    };

    pub fn init(allocator: std.mem.Allocator, left: *Component, right: *Component, orientation: Orientation, props: ComponentProps) !*SplitView {
        const split = try allocator.create(SplitView);
        split.* = SplitView{
            .component = try Component.init(allocator, "split", props),
            .left = left,
            .right = right,
            .split_position = 0.5,
            .orientation = orientation,
        };
        return split;
    }

    pub fn deinit(self: *SplitView) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setSplitPosition(self: *SplitView, position: f32) void {
        self.split_position = std.math.clamp(position, 0.0, 1.0);
    }
};
