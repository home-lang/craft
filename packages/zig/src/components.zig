/// Components Library - Main Entry Point
/// Re-exports all component modules

// Base components
pub const base = @import("components/base.zig");
pub const Component = base.Component;
pub const ComponentProps = base.ComponentProps;
pub const Style = base.Style;

// UI Components
pub const Button = @import("components/button.zig").Button;
pub const TextInput = @import("components/text_input.zig").TextInput;
pub const Tabs = @import("components/tabs.zig").Tabs;
pub const Modal = @import("components/modal.zig").Modal;
pub const ProgressBar = @import("components/progress_bar.zig").ProgressBar;
pub const Dropdown = @import("components/dropdown.zig").Dropdown;
pub const Toast = @import("components/toast.zig").Toast;
pub const ToastManager = @import("components/toast.zig").ToastManager;
pub const TreeView = @import("components/tree_view.zig").TreeView;
pub const DatePicker = @import("components/date_picker.zig").DatePicker;
pub const DataGrid = @import("components/data_grid.zig").DataGrid;
pub const Tooltip = @import("components/tooltip.zig").Tooltip;
pub const Slider = @import("components/slider.zig").Slider;
pub const Autocomplete = @import("components/autocomplete.zig").Autocomplete;
pub const ColorPicker = @import("components/color_picker.zig").ColorPicker;

// Advanced Components
pub const Chart = @import("components/chart.zig").Chart;
pub const MediaPlayer = @import("components/media_player.zig").MediaPlayer;
pub const CodeEditor = @import("components/code_editor.zig").CodeEditor;

test {
    @import("std").testing.refAllDecls(@This());
}
