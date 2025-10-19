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
            .children = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Component) void {
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit(self.allocator);
    }

    pub fn appendChild(self: *Component, child: *Component) !void {
        try self.children.append(self.allocator, child);
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
            .items = .{},
            .selected_index = null,
            .on_select = null,
        };
        return list;
    }

    pub fn deinit(self: *ListView) void {
        self.items.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addItem(self: *ListView, item: []const u8) !void {
        try self.items.append(self.component.allocator, item);
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
            .rows = .{},
            .selected_row = null,
            .on_select = null,
        };
        return table;
    }

    pub fn deinit(self: *Table) void {
        self.rows.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addRow(self: *Table, row: Row) !void {
        try self.rows.append(self.component.allocator, row);
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
            .tabs = .{},
            .selected_tab = 0,
            .on_change = null,
        };
        return tabs;
    }

    pub fn deinit(self: *TabView) void {
        self.tabs.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addTab(self: *TabView, tab: Tab) !void {
        try self.tabs.append(self.component.allocator, tab);
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
            .items = .{},
        };
        return toolbar;
    }

    pub fn deinit(self: *Toolbar) void {
        self.items.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addButton(self: *Toolbar, button: ToolbarButton) !void {
        try self.items.append(self.component.allocator, .{ .button = button });
    }

    pub fn addSeparator(self: *Toolbar) !void {
        try self.items.append(self.component.allocator, .separator);
    }

    pub fn addSpacer(self: *Toolbar) !void {
        try self.items.append(self.component.allocator, .spacer);
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

/// Color Picker Component
pub const ColorPicker = struct {
    component: Component,
    color: [4]u8,
    on_change: ?*const fn ([4]u8) void,

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*ColorPicker {
        const picker = try allocator.create(ColorPicker);
        picker.* = ColorPicker{
            .component = try Component.init(allocator, "color_picker", props),
            .color = [_]u8{ 255, 255, 255, 255 },
            .on_change = null,
        };
        return picker;
    }

    pub fn deinit(self: *ColorPicker) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setColor(self: *ColorPicker, color: [4]u8) void {
        self.color = color;
        if (self.on_change) |callback| {
            callback(color);
        }
    }

    pub fn onChange(self: *ColorPicker, callback: *const fn ([4]u8) void) void {
        self.on_change = callback;
    }
};

/// Date Picker Component
pub const DatePicker = struct {
    component: Component,
    year: u32,
    month: u8,
    day: u8,
    on_change: ?*const fn (u32, u8, u8) void,

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*DatePicker {
        const picker = try allocator.create(DatePicker);
        picker.* = DatePicker{
            .component = try Component.init(allocator, "date_picker", props),
            .year = 2025,
            .month = 1,
            .day = 1,
            .on_change = null,
        };
        return picker;
    }

    pub fn deinit(self: *DatePicker) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setDate(self: *DatePicker, year: u32, month: u8, day: u8) void {
        self.year = year;
        self.month = month;
        self.day = day;
        if (self.on_change) |callback| {
            callback(year, month, day);
        }
    }

    pub fn onChange(self: *DatePicker, callback: *const fn (u32, u8, u8) void) void {
        self.on_change = callback;
    }
};

/// Time Picker Component
pub const TimePicker = struct {
    component: Component,
    hour: u8,
    minute: u8,
    second: u8,
    format_24h: bool,
    on_change: ?*const fn (u8, u8, u8) void,

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*TimePicker {
        const picker = try allocator.create(TimePicker);
        picker.* = TimePicker{
            .component = try Component.init(allocator, "time_picker", props),
            .hour = 12,
            .minute = 0,
            .second = 0,
            .format_24h = true,
            .on_change = null,
        };
        return picker;
    }

    pub fn deinit(self: *TimePicker) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setTime(self: *TimePicker, hour: u8, minute: u8, second: u8) void {
        self.hour = hour;
        self.minute = minute;
        self.second = second;
        if (self.on_change) |callback| {
            callback(hour, minute, second);
        }
    }

    pub fn onChange(self: *TimePicker, callback: *const fn (u8, u8, u8) void) void {
        self.on_change = callback;
    }
};

/// Spinner/Loading Component
pub const Spinner = struct {
    component: Component,
    spinning: bool,
    speed: f32,

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*Spinner {
        const spinner = try allocator.create(Spinner);
        spinner.* = Spinner{
            .component = try Component.init(allocator, "spinner", props),
            .spinning = true,
            .speed = 1.0,
        };
        return spinner;
    }

    pub fn deinit(self: *Spinner) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn start(self: *Spinner) void {
        self.spinning = true;
    }

    pub fn stop(self: *Spinner) void {
        self.spinning = false;
    }

    pub fn setSpeed(self: *Spinner, speed: f32) void {
        self.speed = speed;
    }
};

/// Tree View Component
pub const TreeView = struct {
    component: Component,
    root: ?*TreeNode,
    selected_node: ?*TreeNode,
    on_select: ?*const fn (*TreeNode) void,

    pub const TreeNode = struct {
        label: []const u8,
        children: std.ArrayList(*TreeNode),
        expanded: bool,
        data: ?*anyopaque,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, label: []const u8) !*TreeNode {
            const node = try allocator.create(TreeNode);
            node.* = TreeNode{
                .label = label,
                .children = std.ArrayList(*TreeNode).init(allocator),
                .expanded = false,
                .data = null,
                .allocator = allocator,
            };
            return node;
        }

        pub fn deinit(self: *TreeNode) void {
            for (self.children.items) |child| {
                child.deinit();
            }
            self.children.deinit();
            self.allocator.destroy(self);
        }

        pub fn addChild(self: *TreeNode, child: *TreeNode) !void {
            try self.children.append(child);
        }

        pub fn expand(self: *TreeNode) void {
            self.expanded = true;
        }

        pub fn collapse(self: *TreeNode) void {
            self.expanded = false;
        }

        pub fn toggle(self: *TreeNode) void {
            self.expanded = !self.expanded;
        }
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*TreeView {
        const tree = try allocator.create(TreeView);
        tree.* = TreeView{
            .component = try Component.init(allocator, "tree", props),
            .root = null,
            .selected_node = null,
            .on_select = null,
        };
        return tree;
    }

    pub fn deinit(self: *TreeView) void {
        if (self.root) |root| {
            root.deinit();
        }
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setRoot(self: *TreeView, root: *TreeNode) void {
        self.root = root;
    }

    pub fn selectNode(self: *TreeView, node: *TreeNode) void {
        self.selected_node = node;
        if (self.on_select) |callback| {
            callback(node);
        }
    }

    pub fn onSelect(self: *TreeView, callback: *const fn (*TreeNode) void) void {
        self.on_select = callback;
    }
};

/// Accordion Component
pub const Accordion = struct {
    component: Component,
    sections: std.ArrayList(AccordionSection),

    pub const AccordionSection = struct {
        title: []const u8,
        content: *Component,
        expanded: bool,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*Accordion {
        const accordion = try allocator.create(Accordion);
        accordion.* = Accordion{
            .component = try Component.init(allocator, "accordion", props),
            .sections = std.ArrayList(AccordionSection).init(allocator),
        };
        return accordion;
    }

    pub fn deinit(self: *Accordion) void {
        self.sections.deinit();
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addSection(self: *Accordion, section: AccordionSection) !void {
        try self.sections.append(section);
    }

    pub fn expandSection(self: *Accordion, index: usize) void {
        if (index < self.sections.items.len) {
            self.sections.items[index].expanded = true;
        }
    }

    pub fn collapseSection(self: *Accordion, index: usize) void {
        if (index < self.sections.items.len) {
            self.sections.items[index].expanded = false;
        }
    }

    pub fn toggleSection(self: *Accordion, index: usize) void {
        if (index < self.sections.items.len) {
            self.sections.items[index].expanded = !self.sections.items[index].expanded;
        }
    }
};

/// Card Component
pub const Card = struct {
    component: Component,
    title: ?[]const u8,
    content: *Component,
    footer: ?*Component,
    elevated: bool,

    pub fn init(allocator: std.mem.Allocator, content: *Component, props: ComponentProps) !*Card {
        const card = try allocator.create(Card);
        card.* = Card{
            .component = try Component.init(allocator, "card", props),
            .title = null,
            .content = content,
            .footer = null,
            .elevated = true,
        };
        return card;
    }

    pub fn deinit(self: *Card) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setTitle(self: *Card, title: []const u8) void {
        self.title = title;
    }

    pub fn setFooter(self: *Card, footer: *Component) void {
        self.footer = footer;
    }
};

/// Badge Component
pub const Badge = struct {
    component: Component,
    text: []const u8,
    color: BadgeColor,

    pub const BadgeColor = enum {
        primary,
        secondary,
        success,
        warning,
        error_color,
        info,
    };

    pub fn init(allocator: std.mem.Allocator, text: []const u8, props: ComponentProps) !*Badge {
        const badge = try allocator.create(Badge);
        badge.* = Badge{
            .component = try Component.init(allocator, "badge", props),
            .text = text,
            .color = .primary,
        };
        return badge;
    }

    pub fn deinit(self: *Badge) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setText(self: *Badge, text: []const u8) void {
        self.text = text;
    }

    pub fn setColor(self: *Badge, color: BadgeColor) void {
        self.color = color;
    }
};

/// Chip Component
pub const Chip = struct {
    component: Component,
    text: []const u8,
    icon: ?[]const u8,
    closable: bool,
    on_close: ?*const fn () void,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, props: ComponentProps) !*Chip {
        const chip = try allocator.create(Chip);
        chip.* = Chip{
            .component = try Component.init(allocator, "chip", props),
            .text = text,
            .icon = null,
            .closable = false,
            .on_close = null,
        };
        return chip;
    }

    pub fn deinit(self: *Chip) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn close(self: *Chip) void {
        if (self.on_close) |callback| {
            callback();
        }
    }

    pub fn onClose(self: *Chip, callback: *const fn () void) void {
        self.on_close = callback;
    }
};

/// Avatar Component
pub const Avatar = struct {
    component: Component,
    image_path: ?[]const u8,
    initials: ?[]const u8,
    size: AvatarSize,

    pub const AvatarSize = enum {
        small,
        medium,
        large,
        xlarge,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*Avatar {
        const avatar = try allocator.create(Avatar);
        avatar.* = Avatar{
            .component = try Component.init(allocator, "avatar", props),
            .image_path = null,
            .initials = null,
            .size = .medium,
        };
        return avatar;
    }

    pub fn deinit(self: *Avatar) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setImage(self: *Avatar, image_path: []const u8) void {
        self.image_path = image_path;
    }

    pub fn setInitials(self: *Avatar, initials: []const u8) void {
        self.initials = initials;
    }

    pub fn setSize(self: *Avatar, size: AvatarSize) void {
        self.size = size;
    }
};

/// Stepper Component
pub const Stepper = struct {
    component: Component,
    steps: std.ArrayList(Step),
    current_step: usize,
    on_step_change: ?*const fn (usize) void,

    pub const Step = struct {
        label: []const u8,
        completed: bool,
        is_error: bool,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*Stepper {
        const stepper = try allocator.create(Stepper);
        stepper.* = Stepper{
            .component = try Component.init(allocator, "stepper", props),
            .steps = std.ArrayList(Step).init(allocator),
            .current_step = 0,
            .on_step_change = null,
        };
        return stepper;
    }

    pub fn deinit(self: *Stepper) void {
        self.steps.deinit();
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addStep(self: *Stepper, step: Step) !void {
        try self.steps.append(step);
    }

    pub fn next(self: *Stepper) void {
        if (self.current_step < self.steps.items.len - 1) {
            self.current_step += 1;
            if (self.on_step_change) |callback| {
                callback(self.current_step);
            }
        }
    }

    pub fn previous(self: *Stepper) void {
        if (self.current_step > 0) {
            self.current_step -= 1;
            if (self.on_step_change) |callback| {
                callback(self.current_step);
            }
        }
    }

    pub fn goToStep(self: *Stepper, step: usize) void {
        if (step < self.steps.items.len) {
            self.current_step = step;
            if (self.on_step_change) |callback| {
                callback(self.current_step);
            }
        }
    }

    pub fn onStepChange(self: *Stepper, callback: *const fn (usize) void) void {
        self.on_step_change = callback;
    }
};

/// Rating Component
pub const Rating = struct {
    component: Component,
    value: f32,
    max: u8,
    readonly: bool,
    on_change: ?*const fn (f32) void,

    pub fn init(allocator: std.mem.Allocator, max: u8, props: ComponentProps) !*Rating {
        const rating = try allocator.create(Rating);
        rating.* = Rating{
            .component = try Component.init(allocator, "rating", props),
            .value = 0,
            .max = max,
            .readonly = false,
            .on_change = null,
        };
        return rating;
    }

    pub fn deinit(self: *Rating) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setValue(self: *Rating, value: f32) void {
        self.value = std.math.clamp(value, 0, @floatFromInt(self.max));
        if (self.on_change) |callback| {
            callback(self.value);
        }
    }

    pub fn onChange(self: *Rating, callback: *const fn (f32) void) void {
        self.on_change = callback;
    }
};
