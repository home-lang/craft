//! Craft - Cross-platform Native Application Framework
//!
//! This module provides the main entry point for the Craft framework,
//! organizing all functionality into logical namespaces.

const std = @import("std");

// ============================================
// Core
// ============================================

/// Application lifecycle and configuration
pub const app = struct {
    pub const Config = @import("config.zig").Config;
    pub const Log = @import("log.zig");
    pub const Lifecycle = @import("app_lifecycle.zig");
    pub const Memory = @import("memory.zig");
    pub const Profiler = @import("profiler.zig");
};

/// Command-line interface utilities
pub const cli = @import("cli.zig");

// ============================================
// Platform Abstraction
// ============================================

/// Platform-specific implementations
pub const platform = struct {
    pub const macos = @import("macos.zig");

    pub const current = switch (@import("builtin").os.tag) {
        .macos, .ios => macos,
        else => @compileError("Unsupported platform"),
    };
};

// ============================================
// UI Components
// ============================================

/// Native UI components
pub const ui = struct {
    pub const Component = @import("components/component.zig").Component;
    pub const ComponentProps = @import("components/base.zig").ComponentProps;

    // Basic components
    pub const Button = @import("components/button.zig").Button;
    pub const Label = @import("components/label.zig").Label;
    pub const TextInput = @import("components/text_input.zig").TextInput;

    // Input components
    pub const Checkbox = @import("components/checkbox.zig").Checkbox;
    pub const RadioButton = @import("components/radio_button.zig").RadioButton;
    pub const Switch = @import("components/switch.zig").Switch;
    pub const Slider = @import("components/slider.zig").Slider;
    pub const Dropdown = @import("components/dropdown.zig").Dropdown;

    // Container components
    pub const ListView = @import("components/list_view.zig").ListView;
    pub const TabView = @import("components/tab_view.zig").TabView;
    pub const Toolbar = @import("components/toolbar.zig").Toolbar;
    pub const StatusBar = @import("components/status_bar.zig").StatusBar;

    // Specialized components
    pub const ProgressBar = @import("components/progress_bar.zig").ProgressBar;
    pub const ColorPicker = @import("components/color_picker.zig").ColorPicker;
};

// ============================================
// Native Features
// ============================================

/// Audio playback and system sounds
pub const audio = @import("audio.zig");

/// Camera capture and barcode scanning
pub const camera = @import("camera.zig");

/// Native dialog boxes
pub const dialogs = @import("dialogs.zig");

/// Notification system
pub const notifications = @import("notifications.zig");

/// Internationalization
pub const i18n = @import("i18n.zig");

/// Bluetooth connectivity
pub const bluetooth = @import("bluetooth.zig");

/// Biometric authentication
pub const biometrics = @import("biometrics.zig");

/// System permissions
pub const permissions = @import("permissions.zig");

/// Geolocation services
pub const geolocation = @import("geolocation.zig");

/// Data storage
pub const storage = @import("storage.zig");

// ============================================
// System Integration
// ============================================

/// System tray
pub const tray = @import("tray.zig");

/// Window management
pub const window = @import("window.zig");

/// Menu management
pub const menu = @import("menu.zig");

/// Keyboard shortcuts
pub const shortcuts = @import("shortcuts.zig");

/// System information
pub const system = @import("system.zig");

/// Network utilities
pub const network = @import("network.zig");

// ============================================
// Bridge (JS/TS Integration)
// ============================================

/// Bridge for JavaScript/TypeScript integration
pub const bridge = struct {
    pub const Core = @import("bridge.zig");
    pub const Types = @import("bridge_types.zig");
    pub const Async = @import("bridge_async.zig");
    pub const API = @import("bridge_api.zig");

    // Feature bridges
    pub const Window = @import("bridge_window.zig");
    pub const Dialog = @import("bridge_dialog.zig");
    pub const Clipboard = @import("bridge_clipboard.zig");
    pub const Notification = @import("bridge_notification.zig");
    pub const Menu = @import("bridge_menu.zig");
    pub const Tray = @import("bridge_tray.zig");
    pub const Shell = @import("bridge_shell.zig");
    pub const FileSystem = @import("bridge_fs.zig");
    pub const Network = @import("bridge_network.zig");
    pub const System = @import("bridge_system.zig");
    pub const Power = @import("bridge_power.zig");
    pub const Bluetooth = @import("bridge_bluetooth.zig");
    pub const Shortcuts = @import("bridge_shortcuts.zig");
    pub const App = @import("bridge_app.zig");
    pub const Updater = @import("bridge_updater.zig");
    pub const TouchBar = @import("bridge_touchbar.zig");
};

// ============================================
// APIs (High-level interfaces)
// ============================================

/// High-level APIs
pub const api = struct {
    pub const Core = @import("api.zig");
    pub const HTTP = @import("api_http.zig");
    pub const FileSystem = @import("api_filesystem.zig");
    pub const Database = @import("api_database.zig");
    pub const Process = @import("api_process.zig");
    pub const Crypto = @import("api_crypto.zig");
};

// ============================================
// Plugin System
// ============================================

/// Plugin architecture
pub const plugin = struct {
    pub const Plugin = @import("plugin.zig").Plugin;
    pub const PluginManager = @import("plugin.zig").PluginManager;
    pub const PluginLoader = @import("plugin.zig").PluginLoader;
    pub const PluginManifest = @import("plugin.zig").PluginManifest;
    pub const PluginEvent = @import("plugin.zig").PluginEvent;
    pub const Security = @import("plugin_security.zig");
    pub const Wasm = @import("wasm.zig");
};

// ============================================
// Crypto
// ============================================

/// Cryptographic utilities
pub const crypto = @import("crypto.zig");

// ============================================
// Testing & Development
// ============================================

/// Development utilities
pub const dev = struct {
    pub const HotReload = @import("hot_reload.zig");
    pub const DevTools = @import("dev_mode.zig");
    pub const Benchmark = @import("benchmark.zig");
};

// ============================================
// Version Info
// ============================================

pub const version = "0.1.0";
pub const version_major = 0;
pub const version_minor = 1;
pub const version_patch = 0;

// ============================================
// Tests
// ============================================

test {
    // Run tests from imported modules
    @import("std").testing.refAllDecls(@This());
}
