const std = @import("std");
const c = @cImport({
    @cInclude("gtk/gtk.h");
});

// ============================================
// GTK4 Type Definitions
// ============================================

pub const GtkWidget = c.GtkWidget;
pub const GtkWindow = c.GtkWindow;
pub const GtkApplication = c.GtkApplication;
pub const GtkBox = c.GtkBox;
pub const GtkButton = c.GtkButton;
pub const GtkLabel = c.GtkLabel;
pub const GtkEntry = c.GtkEntry;
pub const GtkTextView = c.GtkTextView;
pub const GtkScrolledWindow = c.GtkScrolledWindow;
pub const GtkListBox = c.GtkListBox;
pub const GtkStack = c.GtkStack;
pub const GtkHeaderBar = c.GtkHeaderBar;
pub const GtkPopover = c.GtkPopover;
pub const GtkMenuButton = c.GtkMenuButton;
pub const GtkSearchEntry = c.GtkSearchEntry;
pub const GtkPaned = c.GtkPaned;
pub const GtkNotebook = c.GtkNotebook;
pub const GtkProgressBar = c.GtkProgressBar;
pub const GtkSpinner = c.GtkSpinner;
pub const GtkSwitch = c.GtkSwitch;
pub const GtkCheckButton = c.GtkCheckButton;
pub const GtkDropDown = c.GtkDropDown;
pub const GtkColorButton = c.GtkColorButton;
pub const GtkFileDialog = c.GtkFileDialog;
pub const GtkAlertDialog = c.GtkAlertDialog;

pub const GApplication = c.GApplication;
pub const GObject = c.GObject;
pub const GError = c.GError;
pub const GFile = c.GFile;
pub const GListModel = c.GListModel;
pub const GdkDisplay = c.GdkDisplay;
pub const GdkSurface = c.GdkSurface;

// Orientation
pub const Orientation = enum(c_int) {
    horizontal = c.GTK_ORIENTATION_HORIZONTAL,
    vertical = c.GTK_ORIENTATION_VERTICAL,
};

// Align
pub const Align = enum(c_int) {
    fill = c.GTK_ALIGN_FILL,
    start = c.GTK_ALIGN_START,
    end = c.GTK_ALIGN_END,
    center = c.GTK_ALIGN_CENTER,
    baseline = c.GTK_ALIGN_BASELINE,
};

// Window position
pub const WindowPosition = enum(c_int) {
    none = c.GTK_WIN_POS_NONE,
    center = c.GTK_WIN_POS_CENTER,
    mouse = c.GTK_WIN_POS_MOUSE,
    center_always = c.GTK_WIN_POS_CENTER_ALWAYS,
    center_on_parent = c.GTK_WIN_POS_CENTER_ON_PARENT,
};

// ============================================
// GTK4 Application
// ============================================

pub const Application = struct {
    const Self = @This();

    app: *GtkApplication,
    main_window: ?*GtkWindow,
    allocator: std.mem.Allocator,
    on_activate: ?*const fn (*Self) void,
    user_data: ?*anyopaque,

    pub fn init(app_id: [*:0]const u8, allocator: std.mem.Allocator) !Self {
        const app = c.gtk_application_new(app_id, c.G_APPLICATION_DEFAULT_FLAGS) orelse return error.ApplicationCreationFailed;

        return Self{
            .app = app,
            .main_window = null,
            .allocator = allocator,
            .on_activate = null,
            .user_data = null,
        };
    }

    pub fn deinit(self: *Self) void {
        c.g_object_unref(@ptrCast(self.app));
    }

    pub fn run(self: *Self, argc: c_int, argv: [*c][*c]u8) c_int {
        // Connect activate signal
        _ = c.g_signal_connect_data(
            @ptrCast(self.app),
            "activate",
            @ptrCast(&activateCallback),
            self,
            null,
            c.G_CONNECT_DEFAULT,
        );

        return c.g_application_run(@ptrCast(self.app), argc, argv);
    }

    fn activateCallback(_: *GApplication, user_data: ?*anyopaque) callconv(.C) void {
        if (user_data) |data| {
            const self: *Self = @ptrCast(@alignCast(data));
            if (self.on_activate) |callback| {
                callback(self);
            }
        }
    }

    pub fn setOnActivate(self: *Self, callback: *const fn (*Self) void) void {
        self.on_activate = callback;
    }

    pub fn createWindow(self: *Self, title: [*:0]const u8, width: c_int, height: c_int) *GtkWindow {
        const window = c.gtk_application_window_new(self.app);
        c.gtk_window_set_title(@ptrCast(window), title);
        c.gtk_window_set_default_size(@ptrCast(window), width, height);
        self.main_window = @ptrCast(window);
        return @ptrCast(window);
    }
};

// ============================================
// GTK4 Window
// ============================================

pub const Window = struct {
    const Self = @This();

    widget: *GtkWindow,

    pub fn init(app: *Application) Self {
        const window = c.gtk_application_window_new(app.app);
        return Self{ .widget = @ptrCast(window) };
    }

    pub fn initPopup() Self {
        const window = c.gtk_window_new();
        return Self{ .widget = @ptrCast(window) };
    }

    pub fn setTitle(self: *Self, title: [*:0]const u8) void {
        c.gtk_window_set_title(self.widget, title);
    }

    pub fn setDefaultSize(self: *Self, width: c_int, height: c_int) void {
        c.gtk_window_set_default_size(self.widget, width, height);
    }

    pub fn setChild(self: *Self, child: *GtkWidget) void {
        c.gtk_window_set_child(self.widget, child);
    }

    pub fn setDecorated(self: *Self, decorated: bool) void {
        c.gtk_window_set_decorated(self.widget, if (decorated) 1 else 0);
    }

    pub fn setResizable(self: *Self, resizable: bool) void {
        c.gtk_window_set_resizable(self.widget, if (resizable) 1 else 0);
    }

    pub fn setModal(self: *Self, modal: bool) void {
        c.gtk_window_set_modal(self.widget, if (modal) 1 else 0);
    }

    pub fn setTransientFor(self: *Self, parent: *GtkWindow) void {
        c.gtk_window_set_transient_for(self.widget, parent);
    }

    pub fn present(self: *Self) void {
        c.gtk_window_present(self.widget);
    }

    pub fn close(self: *Self) void {
        c.gtk_window_close(self.widget);
    }

    pub fn destroy(self: *Self) void {
        c.gtk_window_destroy(self.widget);
    }

    pub fn fullscreen(self: *Self) void {
        c.gtk_window_fullscreen(self.widget);
    }

    pub fn unfullscreen(self: *Self) void {
        c.gtk_window_unfullscreen(self.widget);
    }

    pub fn maximize(self: *Self) void {
        c.gtk_window_maximize(self.widget);
    }

    pub fn unmaximize(self: *Self) void {
        c.gtk_window_unmaximize(self.widget);
    }

    pub fn minimize(self: *Self) void {
        c.gtk_window_minimize(self.widget);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 Box (Layout Container)
// ============================================

pub const Box = struct {
    const Self = @This();

    widget: *GtkBox,

    pub fn init(orientation: Orientation, spacing: c_int) Self {
        const box = c.gtk_box_new(@intFromEnum(orientation), spacing);
        return Self{ .widget = @ptrCast(box) };
    }

    pub fn append(self: *Self, child: *GtkWidget) void {
        c.gtk_box_append(self.widget, child);
    }

    pub fn prepend(self: *Self, child: *GtkWidget) void {
        c.gtk_box_prepend(self.widget, child);
    }

    pub fn remove(self: *Self, child: *GtkWidget) void {
        c.gtk_box_remove(self.widget, child);
    }

    pub fn setHomogeneous(self: *Self, homogeneous: bool) void {
        c.gtk_box_set_homogeneous(self.widget, if (homogeneous) 1 else 0);
    }

    pub fn setSpacing(self: *Self, spacing: c_int) void {
        c.gtk_box_set_spacing(self.widget, spacing);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 Button
// ============================================

pub const Button = struct {
    const Self = @This();

    widget: *GtkButton,
    on_clicked: ?*const fn (*Self, ?*anyopaque) void,
    user_data: ?*anyopaque,

    pub fn init() Self {
        const button = c.gtk_button_new();
        return Self{
            .widget = @ptrCast(button),
            .on_clicked = null,
            .user_data = null,
        };
    }

    pub fn initWithLabel(label: [*:0]const u8) Self {
        const button = c.gtk_button_new_with_label(label);
        return Self{
            .widget = @ptrCast(button),
            .on_clicked = null,
            .user_data = null,
        };
    }

    pub fn initWithIconName(icon_name: [*:0]const u8) Self {
        const button = c.gtk_button_new_from_icon_name(icon_name);
        return Self{
            .widget = @ptrCast(button),
            .on_clicked = null,
            .user_data = null,
        };
    }

    pub fn setLabel(self: *Self, label: [*:0]const u8) void {
        c.gtk_button_set_label(self.widget, label);
    }

    pub fn setIconName(self: *Self, icon_name: [*:0]const u8) void {
        c.gtk_button_set_icon_name(self.widget, icon_name);
    }

    pub fn setOnClicked(self: *Self, callback: *const fn (*Self, ?*anyopaque) void, user_data: ?*anyopaque) void {
        self.on_clicked = callback;
        self.user_data = user_data;

        _ = c.g_signal_connect_data(
            @ptrCast(self.widget),
            "clicked",
            @ptrCast(&clickedCallback),
            self,
            null,
            c.G_CONNECT_DEFAULT,
        );
    }

    fn clickedCallback(_: *GtkButton, user_data: ?*anyopaque) callconv(.C) void {
        if (user_data) |data| {
            const self: *Self = @ptrCast(@alignCast(data));
            if (self.on_clicked) |callback| {
                callback(self, self.user_data);
            }
        }
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 Label
// ============================================

pub const Label = struct {
    const Self = @This();

    widget: *GtkLabel,

    pub fn init(text: [*:0]const u8) Self {
        const label = c.gtk_label_new(text);
        return Self{ .widget = @ptrCast(label) };
    }

    pub fn setText(self: *Self, text: [*:0]const u8) void {
        c.gtk_label_set_text(self.widget, text);
    }

    pub fn setMarkup(self: *Self, markup: [*:0]const u8) void {
        c.gtk_label_set_markup(self.widget, markup);
    }

    pub fn setSelectable(self: *Self, selectable: bool) void {
        c.gtk_label_set_selectable(self.widget, if (selectable) 1 else 0);
    }

    pub fn setWrap(self: *Self, wrap: bool) void {
        c.gtk_label_set_wrap(self.widget, if (wrap) 1 else 0);
    }

    pub fn setXAlign(self: *Self, xalign: f32) void {
        c.gtk_label_set_xalign(self.widget, xalign);
    }

    pub fn setYAlign(self: *Self, yalign: f32) void {
        c.gtk_label_set_yalign(self.widget, yalign);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 Entry (Text Input)
// ============================================

pub const Entry = struct {
    const Self = @This();

    widget: *GtkEntry,
    on_changed: ?*const fn (*Self, ?*anyopaque) void,
    on_activate: ?*const fn (*Self, ?*anyopaque) void,
    user_data: ?*anyopaque,

    pub fn init() Self {
        const entry = c.gtk_entry_new();
        return Self{
            .widget = @ptrCast(entry),
            .on_changed = null,
            .on_activate = null,
            .user_data = null,
        };
    }

    pub fn getText(self: *Self) [*:0]const u8 {
        const buffer = c.gtk_entry_get_buffer(self.widget);
        return c.gtk_entry_buffer_get_text(buffer);
    }

    pub fn setText(self: *Self, text: [*:0]const u8) void {
        const buffer = c.gtk_entry_get_buffer(self.widget);
        c.gtk_entry_buffer_set_text(buffer, text, -1);
    }

    pub fn setPlaceholder(self: *Self, placeholder: [*:0]const u8) void {
        c.gtk_entry_set_placeholder_text(self.widget, placeholder);
    }

    pub fn setVisibility(self: *Self, visible: bool) void {
        c.gtk_entry_set_visibility(self.widget, if (visible) 1 else 0);
    }

    pub fn setMaxLength(self: *Self, max: c_int) void {
        c.gtk_entry_set_max_length(self.widget, max);
    }

    pub fn setOnChanged(self: *Self, callback: *const fn (*Self, ?*anyopaque) void, user_data: ?*anyopaque) void {
        self.on_changed = callback;
        self.user_data = user_data;

        _ = c.g_signal_connect_data(
            @ptrCast(self.widget),
            "changed",
            @ptrCast(&changedCallback),
            self,
            null,
            c.G_CONNECT_DEFAULT,
        );
    }

    fn changedCallback(_: *GtkEntry, user_data: ?*anyopaque) callconv(.C) void {
        if (user_data) |data| {
            const self: *Self = @ptrCast(@alignCast(data));
            if (self.on_changed) |callback| {
                callback(self, self.user_data);
            }
        }
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 ScrolledWindow
// ============================================

pub const ScrolledWindow = struct {
    const Self = @This();

    widget: *GtkScrolledWindow,

    pub fn init() Self {
        const sw = c.gtk_scrolled_window_new();
        return Self{ .widget = @ptrCast(sw) };
    }

    pub fn setChild(self: *Self, child: *GtkWidget) void {
        c.gtk_scrolled_window_set_child(self.widget, child);
    }

    pub fn setMinContentWidth(self: *Self, width: c_int) void {
        c.gtk_scrolled_window_set_min_content_width(self.widget, width);
    }

    pub fn setMinContentHeight(self: *Self, height: c_int) void {
        c.gtk_scrolled_window_set_min_content_height(self.widget, height);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 HeaderBar
// ============================================

pub const HeaderBar = struct {
    const Self = @This();

    widget: *GtkHeaderBar,

    pub fn init() Self {
        const hb = c.gtk_header_bar_new();
        return Self{ .widget = @ptrCast(hb) };
    }

    pub fn setTitle(self: *Self, title: *GtkWidget) void {
        c.gtk_header_bar_set_title_widget(self.widget, title);
    }

    pub fn packStart(self: *Self, child: *GtkWidget) void {
        c.gtk_header_bar_pack_start(self.widget, child);
    }

    pub fn packEnd(self: *Self, child: *GtkWidget) void {
        c.gtk_header_bar_pack_end(self.widget, child);
    }

    pub fn setShowTitleButtons(self: *Self, show: bool) void {
        c.gtk_header_bar_set_show_title_buttons(self.widget, if (show) 1 else 0);
    }

    pub fn setDecorationLayout(self: *Self, layout: [*:0]const u8) void {
        c.gtk_header_bar_set_decoration_layout(self.widget, layout);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 Stack
// ============================================

pub const Stack = struct {
    const Self = @This();

    widget: *GtkStack,

    pub fn init() Self {
        const stack = c.gtk_stack_new();
        return Self{ .widget = @ptrCast(stack) };
    }

    pub fn addNamed(self: *Self, child: *GtkWidget, name: [*:0]const u8) void {
        _ = c.gtk_stack_add_named(self.widget, child, name);
    }

    pub fn addTitled(self: *Self, child: *GtkWidget, name: [*:0]const u8, title: [*:0]const u8) void {
        _ = c.gtk_stack_add_titled(self.widget, child, name, title);
    }

    pub fn setVisibleChild(self: *Self, child: *GtkWidget) void {
        c.gtk_stack_set_visible_child(self.widget, child);
    }

    pub fn setVisibleChildName(self: *Self, name: [*:0]const u8) void {
        c.gtk_stack_set_visible_child_name(self.widget, name);
    }

    pub fn setTransitionType(self: *Self, transition: c.GtkStackTransitionType) void {
        c.gtk_stack_set_transition_type(self.widget, transition);
    }

    pub fn setTransitionDuration(self: *Self, duration: c_uint) void {
        c.gtk_stack_set_transition_duration(self.widget, duration);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 Paned (Split View)
// ============================================

pub const Paned = struct {
    const Self = @This();

    widget: *GtkPaned,

    pub fn init(orientation: Orientation) Self {
        const paned = c.gtk_paned_new(@intFromEnum(orientation));
        return Self{ .widget = @ptrCast(paned) };
    }

    pub fn setStartChild(self: *Self, child: *GtkWidget) void {
        c.gtk_paned_set_start_child(self.widget, child);
    }

    pub fn setEndChild(self: *Self, child: *GtkWidget) void {
        c.gtk_paned_set_end_child(self.widget, child);
    }

    pub fn setPosition(self: *Self, position: c_int) void {
        c.gtk_paned_set_position(self.widget, position);
    }

    pub fn setShrinkStartChild(self: *Self, shrink: bool) void {
        c.gtk_paned_set_shrink_start_child(self.widget, if (shrink) 1 else 0);
    }

    pub fn setShrinkEndChild(self: *Self, shrink: bool) void {
        c.gtk_paned_set_shrink_end_child(self.widget, if (shrink) 1 else 0);
    }

    pub fn setResizeStartChild(self: *Self, resize: bool) void {
        c.gtk_paned_set_resize_start_child(self.widget, if (resize) 1 else 0);
    }

    pub fn setResizeEndChild(self: *Self, resize: bool) void {
        c.gtk_paned_set_resize_end_child(self.widget, if (resize) 1 else 0);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 FileDialog
// ============================================

pub const FileDialog = struct {
    const Self = @This();

    dialog: *GtkFileDialog,

    pub fn init() Self {
        const dialog = c.gtk_file_dialog_new();
        return Self{ .dialog = dialog };
    }

    pub fn setTitle(self: *Self, title: [*:0]const u8) void {
        c.gtk_file_dialog_set_title(self.dialog, title);
    }

    pub fn setModal(self: *Self, modal: bool) void {
        c.gtk_file_dialog_set_modal(self.dialog, if (modal) 1 else 0);
    }

    pub fn openFile(self: *Self, parent: ?*GtkWindow, callback: c.GAsyncReadyCallback, user_data: ?*anyopaque) void {
        c.gtk_file_dialog_open(self.dialog, parent, null, callback, user_data);
    }

    pub fn saveFile(self: *Self, parent: ?*GtkWindow, callback: c.GAsyncReadyCallback, user_data: ?*anyopaque) void {
        c.gtk_file_dialog_save(self.dialog, parent, null, callback, user_data);
    }

    pub fn selectFolder(self: *Self, parent: ?*GtkWindow, callback: c.GAsyncReadyCallback, user_data: ?*anyopaque) void {
        c.gtk_file_dialog_select_folder(self.dialog, parent, null, callback, user_data);
    }
};

// ============================================
// Helper Functions
// ============================================

/// Initialize GTK4
pub fn init() bool {
    return c.gtk_init_check() != 0;
}

/// Main loop
pub fn mainLoop() void {
    while (c.g_main_context_iteration(null, 1) != 0) {}
}

/// Quit main loop
pub fn quit() void {
    c.g_main_loop_quit(null);
}

/// Set widget CSS class
pub fn addCssClass(widget: *GtkWidget, class_name: [*:0]const u8) void {
    c.gtk_widget_add_css_class(widget, class_name);
}

/// Remove widget CSS class
pub fn removeCssClass(widget: *GtkWidget, class_name: [*:0]const u8) void {
    c.gtk_widget_remove_css_class(widget, class_name);
}

/// Load CSS from string
pub fn loadCss(css: [*:0]const u8) void {
    const provider = c.gtk_css_provider_new();
    c.gtk_css_provider_load_from_string(provider, css);

    const display = c.gdk_display_get_default();
    c.gtk_style_context_add_provider_for_display(
        display,
        @ptrCast(provider),
        c.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION,
    );
}

/// Set widget margin
pub fn setMargins(widget: *GtkWidget, top: c_int, bottom: c_int, start: c_int, end: c_int) void {
    c.gtk_widget_set_margin_top(widget, top);
    c.gtk_widget_set_margin_bottom(widget, bottom);
    c.gtk_widget_set_margin_start(widget, start);
    c.gtk_widget_set_margin_end(widget, end);
}

/// Set widget expand
pub fn setExpand(widget: *GtkWidget, hexpand: bool, vexpand: bool) void {
    c.gtk_widget_set_hexpand(widget, if (hexpand) 1 else 0);
    c.gtk_widget_set_vexpand(widget, if (vexpand) 1 else 0);
}

/// Set widget alignment
pub fn setAlign(widget: *GtkWidget, halign: Align, valign: Align) void {
    c.gtk_widget_set_halign(widget, @intFromEnum(halign));
    c.gtk_widget_set_valign(widget, @intFromEnum(valign));
}

/// Show widget
pub fn show(widget: *GtkWidget) void {
    c.gtk_widget_set_visible(widget, 1);
}

/// Hide widget
pub fn hide(widget: *GtkWidget) void {
    c.gtk_widget_set_visible(widget, 0);
}

/// Set widget sensitive
pub fn setSensitive(widget: *GtkWidget, sensitive: bool) void {
    c.gtk_widget_set_sensitive(widget, if (sensitive) 1 else 0);
}

/// Set widget tooltip
pub fn setTooltip(widget: *GtkWidget, tooltip: [*:0]const u8) void {
    c.gtk_widget_set_tooltip_text(widget, tooltip);
}

// ============================================
// GTK4 ListBox
// ============================================

pub const ListBox = struct {
    const Self = @This();

    widget: *GtkListBox,
    on_row_selected: ?*const fn (*Self, ?*c.GtkListBoxRow, ?*anyopaque) void,
    user_data: ?*anyopaque,

    pub fn init() Self {
        const list = c.gtk_list_box_new();
        return Self{
            .widget = @ptrCast(list),
            .on_row_selected = null,
            .user_data = null,
        };
    }

    pub fn append(self: *Self, child: *GtkWidget) void {
        c.gtk_list_box_append(self.widget, child);
    }

    pub fn prepend(self: *Self, child: *GtkWidget) void {
        c.gtk_list_box_prepend(self.widget, child);
    }

    pub fn remove(self: *Self, child: *GtkWidget) void {
        c.gtk_list_box_remove(self.widget, child);
    }

    pub fn selectRow(self: *Self, row: ?*c.GtkListBoxRow) void {
        c.gtk_list_box_select_row(self.widget, row);
    }

    pub fn setSelectionMode(self: *Self, mode: c.GtkSelectionMode) void {
        c.gtk_list_box_set_selection_mode(self.widget, mode);
    }

    pub fn setShowSeparators(self: *Self, show: bool) void {
        c.gtk_list_box_set_show_separators(self.widget, if (show) 1 else 0);
    }

    pub fn setOnRowSelected(self: *Self, callback: *const fn (*Self, ?*c.GtkListBoxRow, ?*anyopaque) void, user_data: ?*anyopaque) void {
        self.on_row_selected = callback;
        self.user_data = user_data;

        _ = c.g_signal_connect_data(
            @ptrCast(self.widget),
            "row-selected",
            @ptrCast(&rowSelectedCallback),
            self,
            null,
            c.G_CONNECT_DEFAULT,
        );
    }

    fn rowSelectedCallback(_: *GtkListBox, row: ?*c.GtkListBoxRow, user_data: ?*anyopaque) callconv(.C) void {
        if (user_data) |data| {
            const self: *Self = @ptrCast(@alignCast(data));
            if (self.on_row_selected) |callback| {
                callback(self, row, self.user_data);
            }
        }
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 TextView (Multiline Text)
// ============================================

pub const TextView = struct {
    const Self = @This();

    widget: *GtkTextView,

    pub fn init() Self {
        const tv = c.gtk_text_view_new();
        return Self{ .widget = @ptrCast(tv) };
    }

    pub fn getBuffer(self: *Self) *c.GtkTextBuffer {
        return c.gtk_text_view_get_buffer(self.widget);
    }

    pub fn getText(self: *Self) ?[*:0]const u8 {
        const buffer = self.getBuffer();
        var start: c.GtkTextIter = undefined;
        var end: c.GtkTextIter = undefined;
        c.gtk_text_buffer_get_start_iter(buffer, &start);
        c.gtk_text_buffer_get_end_iter(buffer, &end);
        return c.gtk_text_buffer_get_text(buffer, &start, &end, 0);
    }

    pub fn setText(self: *Self, text: [*:0]const u8) void {
        const buffer = self.getBuffer();
        c.gtk_text_buffer_set_text(buffer, text, -1);
    }

    pub fn setEditable(self: *Self, editable: bool) void {
        c.gtk_text_view_set_editable(self.widget, if (editable) 1 else 0);
    }

    pub fn setWrapMode(self: *Self, mode: c.GtkWrapMode) void {
        c.gtk_text_view_set_wrap_mode(self.widget, mode);
    }

    pub fn setMonospace(self: *Self, monospace: bool) void {
        c.gtk_text_view_set_monospace(self.widget, if (monospace) 1 else 0);
    }

    pub fn setCursorVisible(self: *Self, visible: bool) void {
        c.gtk_text_view_set_cursor_visible(self.widget, if (visible) 1 else 0);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 Switch
// ============================================

pub const Switch = struct {
    const Self = @This();

    widget: *GtkSwitch,
    on_state_set: ?*const fn (*Self, bool, ?*anyopaque) bool,
    user_data: ?*anyopaque,

    pub fn init() Self {
        const sw = c.gtk_switch_new();
        return Self{
            .widget = @ptrCast(sw),
            .on_state_set = null,
            .user_data = null,
        };
    }

    pub fn getActive(self: *Self) bool {
        return c.gtk_switch_get_active(self.widget) != 0;
    }

    pub fn setActive(self: *Self, active: bool) void {
        c.gtk_switch_set_active(self.widget, if (active) 1 else 0);
    }

    pub fn setState(self: *Self, state: bool) void {
        c.gtk_switch_set_state(self.widget, if (state) 1 else 0);
    }

    pub fn setOnStateSet(self: *Self, callback: *const fn (*Self, bool, ?*anyopaque) bool, user_data: ?*anyopaque) void {
        self.on_state_set = callback;
        self.user_data = user_data;

        _ = c.g_signal_connect_data(
            @ptrCast(self.widget),
            "state-set",
            @ptrCast(&stateSetCallback),
            self,
            null,
            c.G_CONNECT_DEFAULT,
        );
    }

    fn stateSetCallback(_: *GtkSwitch, state: c.gboolean, user_data: ?*anyopaque) callconv(.C) c.gboolean {
        if (user_data) |data| {
            const self: *Self = @ptrCast(@alignCast(data));
            if (self.on_state_set) |callback| {
                return if (callback(self, state != 0, self.user_data)) 1 else 0;
            }
        }
        return 0;
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 CheckButton
// ============================================

pub const CheckButton = struct {
    const Self = @This();

    widget: *GtkCheckButton,
    on_toggled: ?*const fn (*Self, ?*anyopaque) void,
    user_data: ?*anyopaque,

    pub fn init() Self {
        const cb = c.gtk_check_button_new();
        return Self{
            .widget = @ptrCast(cb),
            .on_toggled = null,
            .user_data = null,
        };
    }

    pub fn initWithLabel(label: [*:0]const u8) Self {
        const cb = c.gtk_check_button_new_with_label(label);
        return Self{
            .widget = @ptrCast(cb),
            .on_toggled = null,
            .user_data = null,
        };
    }

    pub fn getActive(self: *Self) bool {
        return c.gtk_check_button_get_active(self.widget) != 0;
    }

    pub fn setActive(self: *Self, active: bool) void {
        c.gtk_check_button_set_active(self.widget, if (active) 1 else 0);
    }

    pub fn setLabel(self: *Self, label: [*:0]const u8) void {
        c.gtk_check_button_set_label(self.widget, label);
    }

    pub fn setInconsistent(self: *Self, inconsistent: bool) void {
        c.gtk_check_button_set_inconsistent(self.widget, if (inconsistent) 1 else 0);
    }

    pub fn setOnToggled(self: *Self, callback: *const fn (*Self, ?*anyopaque) void, user_data: ?*anyopaque) void {
        self.on_toggled = callback;
        self.user_data = user_data;

        _ = c.g_signal_connect_data(
            @ptrCast(self.widget),
            "toggled",
            @ptrCast(&toggledCallback),
            self,
            null,
            c.G_CONNECT_DEFAULT,
        );
    }

    fn toggledCallback(_: *GtkCheckButton, user_data: ?*anyopaque) callconv(.C) void {
        if (user_data) |data| {
            const self: *Self = @ptrCast(@alignCast(data));
            if (self.on_toggled) |callback| {
                callback(self, self.user_data);
            }
        }
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 ProgressBar
// ============================================

pub const ProgressBar = struct {
    const Self = @This();

    widget: *GtkProgressBar,

    pub fn init() Self {
        const pb = c.gtk_progress_bar_new();
        return Self{ .widget = @ptrCast(pb) };
    }

    pub fn setFraction(self: *Self, fraction: f64) void {
        c.gtk_progress_bar_set_fraction(self.widget, fraction);
    }

    pub fn getFraction(self: *Self) f64 {
        return c.gtk_progress_bar_get_fraction(self.widget);
    }

    pub fn pulse(self: *Self) void {
        c.gtk_progress_bar_pulse(self.widget);
    }

    pub fn setPulseStep(self: *Self, step: f64) void {
        c.gtk_progress_bar_set_pulse_step(self.widget, step);
    }

    pub fn setText(self: *Self, text: [*:0]const u8) void {
        c.gtk_progress_bar_set_text(self.widget, text);
    }

    pub fn setShowText(self: *Self, show: bool) void {
        c.gtk_progress_bar_set_show_text(self.widget, if (show) 1 else 0);
    }

    pub fn setInverted(self: *Self, inverted: bool) void {
        c.gtk_progress_bar_set_inverted(self.widget, if (inverted) 1 else 0);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 Spinner
// ============================================

pub const Spinner = struct {
    const Self = @This();

    widget: *GtkSpinner,

    pub fn init() Self {
        const spinner = c.gtk_spinner_new();
        return Self{ .widget = @ptrCast(spinner) };
    }

    pub fn start(self: *Self) void {
        c.gtk_spinner_start(self.widget);
    }

    pub fn stop(self: *Self) void {
        c.gtk_spinner_stop(self.widget);
    }

    pub fn setSpinning(self: *Self, spinning: bool) void {
        c.gtk_spinner_set_spinning(self.widget, if (spinning) 1 else 0);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 Notebook (Tabbed Interface)
// ============================================

pub const Notebook = struct {
    const Self = @This();

    widget: *GtkNotebook,

    pub fn init() Self {
        const nb = c.gtk_notebook_new();
        return Self{ .widget = @ptrCast(nb) };
    }

    pub fn appendPage(self: *Self, child: *GtkWidget, tab_label: ?*GtkWidget) c_int {
        return c.gtk_notebook_append_page(self.widget, child, tab_label);
    }

    pub fn prependPage(self: *Self, child: *GtkWidget, tab_label: ?*GtkWidget) c_int {
        return c.gtk_notebook_prepend_page(self.widget, child, tab_label);
    }

    pub fn insertPage(self: *Self, child: *GtkWidget, tab_label: ?*GtkWidget, position: c_int) c_int {
        return c.gtk_notebook_insert_page(self.widget, child, tab_label, position);
    }

    pub fn removePage(self: *Self, page_num: c_int) void {
        c.gtk_notebook_remove_page(self.widget, page_num);
    }

    pub fn getCurrentPage(self: *Self) c_int {
        return c.gtk_notebook_get_current_page(self.widget);
    }

    pub fn setCurrentPage(self: *Self, page_num: c_int) void {
        c.gtk_notebook_set_current_page(self.widget, page_num);
    }

    pub fn setTabPos(self: *Self, pos: c.GtkPositionType) void {
        c.gtk_notebook_set_tab_pos(self.widget, pos);
    }

    pub fn setShowTabs(self: *Self, show: bool) void {
        c.gtk_notebook_set_show_tabs(self.widget, if (show) 1 else 0);
    }

    pub fn setShowBorder(self: *Self, show: bool) void {
        c.gtk_notebook_set_show_border(self.widget, if (show) 1 else 0);
    }

    pub fn setScrollable(self: *Self, scrollable: bool) void {
        c.gtk_notebook_set_scrollable(self.widget, if (scrollable) 1 else 0);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 Popover
// ============================================

pub const Popover = struct {
    const Self = @This();

    widget: *GtkPopover,

    pub fn init() Self {
        const pop = c.gtk_popover_new();
        return Self{ .widget = @ptrCast(pop) };
    }

    pub fn setChild(self: *Self, child: *GtkWidget) void {
        c.gtk_popover_set_child(self.widget, child);
    }

    pub fn setPosition(self: *Self, position: c.GtkPositionType) void {
        c.gtk_popover_set_position(self.widget, position);
    }

    pub fn setAutohide(self: *Self, autohide: bool) void {
        c.gtk_popover_set_autohide(self.widget, if (autohide) 1 else 0);
    }

    pub fn popup(self: *Self) void {
        c.gtk_popover_popup(self.widget);
    }

    pub fn popdown(self: *Self) void {
        c.gtk_popover_popdown(self.widget);
    }

    pub fn present(self: *Self) void {
        c.gtk_popover_present(self.widget);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 MenuButton
// ============================================

pub const MenuButton = struct {
    const Self = @This();

    widget: *GtkMenuButton,

    pub fn init() Self {
        const mb = c.gtk_menu_button_new();
        return Self{ .widget = @ptrCast(mb) };
    }

    pub fn setPopover(self: *Self, popover: *GtkPopover) void {
        c.gtk_menu_button_set_popover(self.widget, @ptrCast(popover));
    }

    pub fn setMenuModel(self: *Self, model: *c.GMenuModel) void {
        c.gtk_menu_button_set_menu_model(self.widget, model);
    }

    pub fn setIconName(self: *Self, icon_name: [*:0]const u8) void {
        c.gtk_menu_button_set_icon_name(self.widget, icon_name);
    }

    pub fn setLabel(self: *Self, label: [*:0]const u8) void {
        c.gtk_menu_button_set_label(self.widget, label);
    }

    pub fn setDirection(self: *Self, direction: c.GtkArrowType) void {
        c.gtk_menu_button_set_direction(self.widget, direction);
    }

    pub fn setPrimary(self: *Self, primary: bool) void {
        c.gtk_menu_button_set_primary(self.widget, if (primary) 1 else 0);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 SearchEntry
// ============================================

pub const SearchEntry = struct {
    const Self = @This();

    widget: *GtkSearchEntry,
    on_search_changed: ?*const fn (*Self, ?*anyopaque) void,
    on_activate: ?*const fn (*Self, ?*anyopaque) void,
    user_data: ?*anyopaque,

    pub fn init() Self {
        const se = c.gtk_search_entry_new();
        return Self{
            .widget = @ptrCast(se),
            .on_search_changed = null,
            .on_activate = null,
            .user_data = null,
        };
    }

    pub fn getText(self: *Self) [*:0]const u8 {
        return c.gtk_editable_get_text(@ptrCast(self.widget));
    }

    pub fn setText(self: *Self, text: [*:0]const u8) void {
        c.gtk_editable_set_text(@ptrCast(self.widget), text);
    }

    pub fn setPlaceholder(self: *Self, placeholder: [*:0]const u8) void {
        c.gtk_entry_set_placeholder_text(@ptrCast(self.widget), placeholder);
    }

    pub fn setOnSearchChanged(self: *Self, callback: *const fn (*Self, ?*anyopaque) void, user_data: ?*anyopaque) void {
        self.on_search_changed = callback;
        self.user_data = user_data;

        _ = c.g_signal_connect_data(
            @ptrCast(self.widget),
            "search-changed",
            @ptrCast(&searchChangedCallback),
            self,
            null,
            c.G_CONNECT_DEFAULT,
        );
    }

    fn searchChangedCallback(_: *GtkSearchEntry, user_data: ?*anyopaque) callconv(.C) void {
        if (user_data) |data| {
            const self: *Self = @ptrCast(@alignCast(data));
            if (self.on_search_changed) |callback| {
                callback(self, self.user_data);
            }
        }
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 Image
// ============================================

pub const Image = struct {
    const Self = @This();

    widget: *c.GtkImage,

    pub fn init() Self {
        const img = c.gtk_image_new();
        return Self{ .widget = @ptrCast(img) };
    }

    pub fn initFromFile(filename: [*:0]const u8) Self {
        const img = c.gtk_image_new_from_file(filename);
        return Self{ .widget = @ptrCast(img) };
    }

    pub fn initFromIconName(icon_name: [*:0]const u8) Self {
        const img = c.gtk_image_new_from_icon_name(icon_name);
        return Self{ .widget = @ptrCast(img) };
    }

    pub fn setFromFile(self: *Self, filename: [*:0]const u8) void {
        c.gtk_image_set_from_file(self.widget, filename);
    }

    pub fn setFromIconName(self: *Self, icon_name: [*:0]const u8) void {
        c.gtk_image_set_from_icon_name(self.widget, icon_name);
    }

    pub fn setPixelSize(self: *Self, size: c_int) void {
        c.gtk_image_set_pixel_size(self.widget, size);
    }

    pub fn clear(self: *Self) void {
        c.gtk_image_clear(self.widget);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 Scale (Slider)
// ============================================

pub const Scale = struct {
    const Self = @This();

    widget: *c.GtkScale,
    on_value_changed: ?*const fn (*Self, f64, ?*anyopaque) void,
    user_data: ?*anyopaque,

    pub fn init(orientation: Orientation, min: f64, max: f64, step: f64) Self {
        const scale = c.gtk_scale_new_with_range(@intFromEnum(orientation), min, max, step);
        return Self{
            .widget = @ptrCast(scale),
            .on_value_changed = null,
            .user_data = null,
        };
    }

    pub fn getValue(self: *Self) f64 {
        return c.gtk_range_get_value(@ptrCast(self.widget));
    }

    pub fn setValue(self: *Self, value: f64) void {
        c.gtk_range_set_value(@ptrCast(self.widget), value);
    }

    pub fn setDrawValue(self: *Self, draw: bool) void {
        c.gtk_scale_set_draw_value(self.widget, if (draw) 1 else 0);
    }

    pub fn setDigits(self: *Self, digits: c_int) void {
        c.gtk_scale_set_digits(self.widget, digits);
    }

    pub fn addMark(self: *Self, value: f64, position: c.GtkPositionType, markup: ?[*:0]const u8) void {
        c.gtk_scale_add_mark(self.widget, value, position, markup);
    }

    pub fn clearMarks(self: *Self) void {
        c.gtk_scale_clear_marks(self.widget);
    }

    pub fn setOnValueChanged(self: *Self, callback: *const fn (*Self, f64, ?*anyopaque) void, user_data: ?*anyopaque) void {
        self.on_value_changed = callback;
        self.user_data = user_data;

        _ = c.g_signal_connect_data(
            @ptrCast(self.widget),
            "value-changed",
            @ptrCast(&valueChangedCallback),
            self,
            null,
            c.G_CONNECT_DEFAULT,
        );
    }

    fn valueChangedCallback(range: *c.GtkRange, user_data: ?*anyopaque) callconv(.C) void {
        if (user_data) |data| {
            const self: *Self = @ptrCast(@alignCast(data));
            if (self.on_value_changed) |callback| {
                callback(self, c.gtk_range_get_value(range), self.user_data);
            }
        }
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 Grid
// ============================================

pub const Grid = struct {
    const Self = @This();

    widget: *c.GtkGrid,

    pub fn init() Self {
        const grid = c.gtk_grid_new();
        return Self{ .widget = @ptrCast(grid) };
    }

    pub fn attach(self: *Self, child: *GtkWidget, column: c_int, row: c_int, width: c_int, height: c_int) void {
        c.gtk_grid_attach(self.widget, child, column, row, width, height);
    }

    pub fn attachNextTo(self: *Self, child: *GtkWidget, sibling: ?*GtkWidget, side: c.GtkPositionType, width: c_int, height: c_int) void {
        c.gtk_grid_attach_next_to(self.widget, child, sibling, side, width, height);
    }

    pub fn remove(self: *Self, child: *GtkWidget) void {
        c.gtk_grid_remove(self.widget, child);
    }

    pub fn setRowSpacing(self: *Self, spacing: c_uint) void {
        c.gtk_grid_set_row_spacing(self.widget, spacing);
    }

    pub fn setColumnSpacing(self: *Self, spacing: c_uint) void {
        c.gtk_grid_set_column_spacing(self.widget, spacing);
    }

    pub fn setRowHomogeneous(self: *Self, homogeneous: bool) void {
        c.gtk_grid_set_row_homogeneous(self.widget, if (homogeneous) 1 else 0);
    }

    pub fn setColumnHomogeneous(self: *Self, homogeneous: bool) void {
        c.gtk_grid_set_column_homogeneous(self.widget, if (homogeneous) 1 else 0);
    }

    pub fn asWidget(self: *Self) *GtkWidget {
        return @ptrCast(self.widget);
    }
};

// ============================================
// GTK4 AlertDialog
// ============================================

pub const AlertDialog = struct {
    const Self = @This();

    dialog: *GtkAlertDialog,

    pub fn init(message: [*:0]const u8) Self {
        const dialog = c.gtk_alert_dialog_new("%s", message);
        return Self{ .dialog = dialog };
    }

    pub fn setMessage(self: *Self, message: [*:0]const u8) void {
        c.gtk_alert_dialog_set_message(self.dialog, message);
    }

    pub fn setDetail(self: *Self, detail: [*:0]const u8) void {
        c.gtk_alert_dialog_set_detail(self.dialog, detail);
    }

    pub fn setButtons(self: *Self, buttons: [*c]const [*:0]const u8) void {
        c.gtk_alert_dialog_set_buttons(self.dialog, buttons);
    }

    pub fn setCancelButton(self: *Self, button: c_int) void {
        c.gtk_alert_dialog_set_cancel_button(self.dialog, button);
    }

    pub fn setDefaultButton(self: *Self, button: c_int) void {
        c.gtk_alert_dialog_set_default_button(self.dialog, button);
    }

    pub fn setModal(self: *Self, modal: bool) void {
        c.gtk_alert_dialog_set_modal(self.dialog, if (modal) 1 else 0);
    }

    pub fn show(self: *Self, parent: ?*GtkWindow) void {
        c.gtk_alert_dialog_show(self.dialog, parent);
    }

    pub fn choose(self: *Self, parent: ?*GtkWindow, callback: c.GAsyncReadyCallback, user_data: ?*anyopaque) void {
        c.gtk_alert_dialog_choose(self.dialog, parent, null, callback, user_data);
    }
};

// ============================================
// GTK4 ColorDialog
// ============================================

pub const ColorDialog = struct {
    const Self = @This();

    dialog: *c.GtkColorDialog,

    pub fn init() Self {
        const dialog = c.gtk_color_dialog_new();
        return Self{ .dialog = dialog };
    }

    pub fn setTitle(self: *Self, title: [*:0]const u8) void {
        c.gtk_color_dialog_set_title(self.dialog, title);
    }

    pub fn setModal(self: *Self, modal: bool) void {
        c.gtk_color_dialog_set_modal(self.dialog, if (modal) 1 else 0);
    }

    pub fn setWithAlpha(self: *Self, with_alpha: bool) void {
        c.gtk_color_dialog_set_with_alpha(self.dialog, if (with_alpha) 1 else 0);
    }

    pub fn chooseRgba(self: *Self, parent: ?*GtkWindow, initial: ?*const c.GdkRGBA, callback: c.GAsyncReadyCallback, user_data: ?*anyopaque) void {
        c.gtk_color_dialog_choose_rgba(self.dialog, parent, initial, null, callback, user_data);
    }
};

// ============================================
// Drag and Drop Support
// ============================================

pub const DragSource = struct {
    const Self = @This();

    source: *c.GtkDragSource,

    pub fn init() Self {
        const source = c.gtk_drag_source_new();
        return Self{ .source = source };
    }

    pub fn setContent(self: *Self, content: *c.GdkContentProvider) void {
        c.gtk_drag_source_set_content(self.source, content);
    }

    pub fn setActions(self: *Self, actions: c.GdkDragAction) void {
        c.gtk_drag_source_set_actions(self.source, actions);
    }

    pub fn attach(self: *Self, widget: *GtkWidget) void {
        c.gtk_widget_add_controller(widget, @ptrCast(self.source));
    }
};

pub const DropTarget = struct {
    const Self = @This();

    target: *c.GtkDropTarget,

    pub fn init(gtype: c.GType, actions: c.GdkDragAction) Self {
        const target = c.gtk_drop_target_new(gtype, actions);
        return Self{ .target = target };
    }

    pub fn setPreload(self: *Self, preload: bool) void {
        c.gtk_drop_target_set_preload(self.target, if (preload) 1 else 0);
    }

    pub fn attach(self: *Self, widget: *GtkWidget) void {
        c.gtk_widget_add_controller(widget, @ptrCast(self.target));
    }
};

// ============================================
// Gesture Controllers
// ============================================

pub const GestureClick = struct {
    const Self = @This();

    gesture: *c.GtkGestureClick,
    on_pressed: ?*const fn (c_int, f64, f64, ?*anyopaque) void,
    on_released: ?*const fn (c_int, f64, f64, ?*anyopaque) void,
    user_data: ?*anyopaque,

    pub fn init() Self {
        const gesture = c.gtk_gesture_click_new();
        return Self{
            .gesture = gesture,
            .on_pressed = null,
            .on_released = null,
            .user_data = null,
        };
    }

    pub fn setButton(self: *Self, button: c_uint) void {
        c.gtk_gesture_single_set_button(@ptrCast(self.gesture), button);
    }

    pub fn attach(self: *Self, widget: *GtkWidget) void {
        c.gtk_widget_add_controller(widget, @ptrCast(self.gesture));
    }

    pub fn setOnPressed(self: *Self, callback: *const fn (c_int, f64, f64, ?*anyopaque) void, user_data: ?*anyopaque) void {
        self.on_pressed = callback;
        self.user_data = user_data;

        _ = c.g_signal_connect_data(
            @ptrCast(self.gesture),
            "pressed",
            @ptrCast(&pressedCallback),
            self,
            null,
            c.G_CONNECT_DEFAULT,
        );
    }

    fn pressedCallback(_: *c.GtkGestureClick, n_press: c_int, x: f64, y: f64, user_data: ?*anyopaque) callconv(.C) void {
        if (user_data) |data| {
            const self: *Self = @ptrCast(@alignCast(data));
            if (self.on_pressed) |callback| {
                callback(n_press, x, y, self.user_data);
            }
        }
    }
};

pub const GestureDrag = struct {
    const Self = @This();

    gesture: *c.GtkGestureDrag,

    pub fn init() Self {
        const gesture = c.gtk_gesture_drag_new();
        return Self{ .gesture = gesture };
    }

    pub fn attach(self: *Self, widget: *GtkWidget) void {
        c.gtk_widget_add_controller(widget, @ptrCast(self.gesture));
    }
};

pub const GestureZoom = struct {
    const Self = @This();

    gesture: *c.GtkGestureZoom,

    pub fn init() Self {
        const gesture = c.gtk_gesture_zoom_new();
        return Self{ .gesture = gesture };
    }

    pub fn attach(self: *Self, widget: *GtkWidget) void {
        c.gtk_widget_add_controller(widget, @ptrCast(self.gesture));
    }

    pub fn getScaleDelta(self: *Self) f64 {
        return c.gtk_gesture_zoom_get_scale_delta(self.gesture);
    }
};

// ============================================
// Event Controllers
// ============================================

pub const EventControllerKey = struct {
    const Self = @This();

    controller: *c.GtkEventControllerKey,
    on_key_pressed: ?*const fn (c_uint, c_uint, c.GdkModifierType, ?*anyopaque) bool,
    user_data: ?*anyopaque,

    pub fn init() Self {
        const controller = c.gtk_event_controller_key_new();
        return Self{
            .controller = controller,
            .on_key_pressed = null,
            .user_data = null,
        };
    }

    pub fn attach(self: *Self, widget: *GtkWidget) void {
        c.gtk_widget_add_controller(widget, @ptrCast(self.controller));
    }

    pub fn setOnKeyPressed(self: *Self, callback: *const fn (c_uint, c_uint, c.GdkModifierType, ?*anyopaque) bool, user_data: ?*anyopaque) void {
        self.on_key_pressed = callback;
        self.user_data = user_data;

        _ = c.g_signal_connect_data(
            @ptrCast(self.controller),
            "key-pressed",
            @ptrCast(&keyPressedCallback),
            self,
            null,
            c.G_CONNECT_DEFAULT,
        );
    }

    fn keyPressedCallback(_: *c.GtkEventControllerKey, keyval: c_uint, keycode: c_uint, state: c.GdkModifierType, user_data: ?*anyopaque) callconv(.C) c.gboolean {
        if (user_data) |data| {
            const self: *Self = @ptrCast(@alignCast(data));
            if (self.on_key_pressed) |callback| {
                return if (callback(keyval, keycode, state, self.user_data)) 1 else 0;
            }
        }
        return 0;
    }
};

pub const EventControllerMotion = struct {
    const Self = @This();

    controller: *c.GtkEventControllerMotion,

    pub fn init() Self {
        const controller = c.gtk_event_controller_motion_new();
        return Self{ .controller = controller };
    }

    pub fn attach(self: *Self, widget: *GtkWidget) void {
        c.gtk_widget_add_controller(widget, @ptrCast(self.controller));
    }
};

pub const EventControllerScroll = struct {
    const Self = @This();

    controller: *c.GtkEventControllerScroll,

    pub fn init(flags: c.GtkEventControllerScrollFlags) Self {
        const controller = c.gtk_event_controller_scroll_new(flags);
        return Self{ .controller = controller };
    }

    pub fn attach(self: *Self, widget: *GtkWidget) void {
        c.gtk_widget_add_controller(widget, @ptrCast(self.controller));
    }
};

// ============================================
// Clipboard Support
// ============================================

pub const Clipboard = struct {
    pub fn getDefault() *c.GdkClipboard {
        const display = c.gdk_display_get_default();
        return c.gdk_display_get_clipboard(display);
    }

    pub fn setText(text: [*:0]const u8) void {
        const clipboard = getDefault();
        c.gdk_clipboard_set_text(clipboard, text);
    }

    pub fn readTextAsync(callback: c.GAsyncReadyCallback, user_data: ?*anyopaque) void {
        const clipboard = getDefault();
        c.gdk_clipboard_read_text_async(clipboard, null, callback, user_data);
    }
};

// ============================================
// Shortcut Controller
// ============================================

pub const ShortcutController = struct {
    const Self = @This();

    controller: *c.GtkShortcutController,

    pub fn init() Self {
        const controller = c.gtk_shortcut_controller_new();
        return Self{ .controller = controller };
    }

    pub fn setScope(self: *Self, scope: c.GtkShortcutScope) void {
        c.gtk_shortcut_controller_set_scope(self.controller, scope);
    }

    pub fn addShortcut(self: *Self, shortcut: *c.GtkShortcut) void {
        c.gtk_shortcut_controller_add_shortcut(self.controller, shortcut);
    }

    pub fn attach(self: *Self, widget: *GtkWidget) void {
        c.gtk_widget_add_controller(widget, @ptrCast(self.controller));
    }
};

/// Create a keyboard shortcut
pub fn createShortcut(accelerator: [*:0]const u8, action_name: [*:0]const u8) *c.GtkShortcut {
    const trigger = c.gtk_shortcut_trigger_parse_string(accelerator);
    const action = c.gtk_named_action_new(action_name);
    return c.gtk_shortcut_new(@ptrCast(trigger), @ptrCast(action));
}

// ============================================
// Toast/Notification (via libadwaita or GNotification)
// ============================================

pub const Notification = struct {
    notification: *c.GNotification,

    pub fn init(title: [*:0]const u8) Notification {
        const notif = c.g_notification_new(title);
        return .{ .notification = notif };
    }

    pub fn setBody(self: *Notification, body: [*:0]const u8) void {
        c.g_notification_set_body(self.notification, body);
    }

    pub fn setPriority(self: *Notification, priority: c.GNotificationPriority) void {
        c.g_notification_set_priority(self.notification, priority);
    }

    pub fn setIcon(self: *Notification, icon: *c.GIcon) void {
        c.g_notification_set_icon(self.notification, icon);
    }

    pub fn addButton(self: *Notification, label: [*:0]const u8, action: [*:0]const u8) void {
        c.g_notification_add_button(self.notification, label, action);
    }

    pub fn send(self: *Notification, app: *GApplication, id: ?[*:0]const u8) void {
        c.g_application_send_notification(app, id, self.notification);
    }

    pub fn withdraw(app: *GApplication, id: [*:0]const u8) void {
        c.g_application_withdraw_notification(app, id);
    }

    pub fn deinit(self: *Notification) void {
        c.g_object_unref(@ptrCast(self.notification));
    }
};

// ============================================
// GSettings Integration
// ============================================

pub const Settings = struct {
    const Self = @This();

    settings: *c.GSettings,

    pub fn init(schema_id: [*:0]const u8) ?Self {
        const settings = c.g_settings_new(schema_id) orelse return null;
        return Self{ .settings = settings };
    }

    pub fn deinit(self: *Self) void {
        c.g_object_unref(@ptrCast(self.settings));
    }

    pub fn getString(self: *Self, key: [*:0]const u8) ?[*:0]u8 {
        return c.g_settings_get_string(self.settings, key);
    }

    pub fn setString(self: *Self, key: [*:0]const u8, value: [*:0]const u8) bool {
        return c.g_settings_set_string(self.settings, key, value) != 0;
    }

    pub fn getBoolean(self: *Self, key: [*:0]const u8) bool {
        return c.g_settings_get_boolean(self.settings, key) != 0;
    }

    pub fn setBoolean(self: *Self, key: [*:0]const u8, value: bool) bool {
        return c.g_settings_set_boolean(self.settings, key, if (value) 1 else 0) != 0;
    }

    pub fn getInt(self: *Self, key: [*:0]const u8) c_int {
        return c.g_settings_get_int(self.settings, key);
    }

    pub fn setInt(self: *Self, key: [*:0]const u8, value: c_int) bool {
        return c.g_settings_set_int(self.settings, key, value) != 0;
    }

    pub fn getDouble(self: *Self, key: [*:0]const u8) f64 {
        return c.g_settings_get_double(self.settings, key);
    }

    pub fn setDouble(self: *Self, key: [*:0]const u8, value: f64) bool {
        return c.g_settings_set_double(self.settings, key, value) != 0;
    }

    pub fn reset(self: *Self, key: [*:0]const u8) void {
        c.g_settings_reset(self.settings, key);
    }

    pub fn bind(self: *Self, key: [*:0]const u8, object: *GObject, property: [*:0]const u8, flags: c.GSettingsBindFlags) void {
        c.g_settings_bind(self.settings, key, object, property, flags);
    }
};

// ============================================
// Action Support
// ============================================

pub const SimpleAction = struct {
    const Self = @This();

    action: *c.GSimpleAction,
    on_activate: ?*const fn (*c.GVariant, ?*anyopaque) void,
    user_data: ?*anyopaque,

    pub fn init(name: [*:0]const u8) Self {
        const action = c.g_simple_action_new(name, null);
        return Self{
            .action = action,
            .on_activate = null,
            .user_data = null,
        };
    }

    pub fn initStateful(name: [*:0]const u8, state: *c.GVariant) Self {
        const action = c.g_simple_action_new_stateful(name, null, state);
        return Self{
            .action = action,
            .on_activate = null,
            .user_data = null,
        };
    }

    pub fn setEnabled(self: *Self, enabled: bool) void {
        c.g_simple_action_set_enabled(self.action, if (enabled) 1 else 0);
    }

    pub fn setState(self: *Self, state: *c.GVariant) void {
        c.g_simple_action_set_state(self.action, state);
    }

    pub fn setOnActivate(self: *Self, callback: *const fn (*c.GVariant, ?*anyopaque) void, user_data: ?*anyopaque) void {
        self.on_activate = callback;
        self.user_data = user_data;

        _ = c.g_signal_connect_data(
            @ptrCast(self.action),
            "activate",
            @ptrCast(&activateCallback),
            self,
            null,
            c.G_CONNECT_DEFAULT,
        );
    }

    fn activateCallback(_: *c.GSimpleAction, parameter: ?*c.GVariant, user_data: ?*anyopaque) callconv(.C) void {
        if (user_data) |data| {
            const self: *Self = @ptrCast(@alignCast(data));
            if (self.on_activate) |callback| {
                callback(parameter orelse undefined, self.user_data);
            }
        }
    }

    const undefined: *c.GVariant = undefined;
};

pub const ActionMap = struct {
    pub fn addAction(map: *c.GActionMap, action: *c.GAction) void {
        c.g_action_map_add_action(map, action);
    }

    pub fn removeAction(map: *c.GActionMap, name: [*:0]const u8) void {
        c.g_action_map_remove_action(map, name);
    }

    pub fn lookupAction(map: *c.GActionMap, name: [*:0]const u8) ?*c.GAction {
        return c.g_action_map_lookup_action(map, name);
    }
};

// ============================================
// Tests
// ============================================

test "Box creation" {
    // Note: These tests would need GTK to be initialized
    // Just verify compilation
    _ = Box.init;
    _ = Button.init;
    _ = Label.init;
}

test "Helper functions exist" {
    _ = addCssClass;
    _ = removeCssClass;
    _ = loadCss;
    _ = setMargins;
    _ = setExpand;
    _ = setAlign;
}
