/// Components Library - Main Entry Point
/// Re-exports all component modules (38 components)

// Base components
pub const base = @import("components/base.zig");
pub const Component = base.Component;
pub const ComponentProps = base.ComponentProps;
pub const Style = base.Style;

// ============================================
// Core Form Components
// ============================================
pub const Button = @import("components/button.zig").Button;
pub const TextInput = @import("components/text_input.zig").TextInput;
pub const Checkbox = @import("components/checkbox.zig").Checkbox;
pub const radio = @import("components/radio.zig");
pub const RadioButton = radio.RadioButton;
pub const RadioGroup = radio.RadioGroup;
pub const Label = @import("components/label.zig").Label;
pub const Dropdown = @import("components/dropdown.zig").Dropdown;
pub const Slider = @import("components/slider.zig").Slider;
pub const Stepper = @import("components/stepper.zig").Stepper;

// ============================================
// Layout & Container Components
// ============================================
pub const Modal = @import("components/modal.zig").Modal;
pub const Tabs = @import("components/tabs.zig").Tabs;
pub const Accordion = @import("components/accordion.zig").Accordion;
pub const ListView = @import("components/list_view.zig").ListView;

// ============================================
// Data Display Components
// ============================================
pub const DataGrid = @import("components/data_grid.zig").DataGrid;
pub const TreeView = @import("components/tree_view.zig").TreeView;
pub const Chart = @import("components/chart.zig").Chart;
pub const ProgressBar = @import("components/progress_bar.zig").ProgressBar;

// ============================================
// Feedback Components
// ============================================
pub const Toast = @import("components/toast.zig").Toast;
pub const ToastManager = @import("components/toast.zig").ToastManager;
pub const Tooltip = @import("components/tooltip.zig").Tooltip;
pub const StatusBar = @import("components/status_bar.zig").StatusBar;

// ============================================
// Input Components
// ============================================
pub const Autocomplete = @import("components/autocomplete.zig").Autocomplete;
pub const ColorPicker = @import("components/color_picker.zig").ColorPicker;
pub const DatePicker = @import("components/date_picker.zig").DatePicker;
pub const TimePicker = @import("components/time_picker.zig").TimePicker;

// ============================================
// Media Components
// ============================================
pub const MediaPlayer = @import("components/media_player.zig").MediaPlayer;
pub const CodeEditor = @import("components/code_editor.zig").CodeEditor;

// ============================================
// Navigation & Menu Components
// ============================================
pub const Menu = @import("components/menu.zig").Menu;
pub const ContextMenu = @import("components/context_menu.zig").ContextMenu;
pub const Toolbar = @import("components/toolbar.zig").Toolbar;

// ============================================
// Native macOS/iOS Components
// ============================================
pub const NativeFileBrowser = @import("components/native_file_browser.zig").NativeFileBrowser;
pub const NativeSidebar = @import("components/native_sidebar.zig").NativeSidebar;
pub const NativeSplitView = @import("components/native_split_view.zig").NativeSplitView;
pub const QuickLook = @import("components/quick_look.zig").QuickLook;

// ============================================
// Interaction Components
// ============================================
pub const DragDrop = @import("components/drag_drop.zig").DragDrop;
pub const KeyboardHandler = @import("components/keyboard_handler.zig").KeyboardHandler;

test {
    @import("std").testing.refAllDecls(@This());
}
