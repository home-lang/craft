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

// Advanced Components
pub const Chart = @import("components/chart.zig").Chart;
pub const MediaPlayer = @import("components/media_player.zig").MediaPlayer;
pub const CodeEditor = @import("components/code_editor.zig").CodeEditor;

test {
    @import("std").testing.refAllDecls(@This());
}
