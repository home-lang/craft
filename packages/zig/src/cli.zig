const std = @import("std");

pub const WindowOptions = struct {
    url: ?[]const u8 = null,
    html: ?[]const u8 = null,
    title: []const u8 = "Craft App",
    width: u32 = 1200,
    height: u32 = 800,
    x: ?i32 = null,
    y: ?i32 = null,
    frameless: bool = false,
    transparent: bool = false,
    always_on_top: bool = false,
    resizable: bool = true,
    fullscreen: bool = false,
    dev_tools: bool = true,
    dark_mode: ?bool = null,
    hot_reload: bool = false,
    system_tray: bool = false,
    hide_dock_icon: bool = false,
    menubar_only: bool = false,
    titlebar_hidden: bool = false,
    native_sidebar: bool = false,
    sidebar_width: u32 = 220,
    sidebar_config: ?[]const u8 = null,
    benchmark: bool = false,
};

pub const CliError = error{
    InvalidArgument,
    MissingValue,
    InvalidNumber,
};

/// Enable debug logging via --debug flag
var debug_mode: bool = false;

/// Debug print helper - only prints when debug mode is enabled
fn debugPrint(comptime fmt: []const u8, args: anytype) void {
    if (debug_mode) {
        std.debug.print(fmt, args);
    }
}

pub fn parseArgs(allocator: std.mem.Allocator, args: []const [:0]const u8) !WindowOptions {
    // First pass: check for --debug flag
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--debug")) {
            debug_mode = true;
            break;
        }
    }

    debugPrint("\n[CLI DEBUG] Total arguments received: {d}\n", .{args.len});
    for (args, 0..) |arg, idx| {
        debugPrint("[CLI DEBUG] arg[{d}] = '{s}'\n", .{ idx, arg });
    }
    debugPrint("\n", .{});

    var options = WindowOptions{};
    var i: usize = 1; // Skip program name

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            printVersion();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "--url") or std.mem.eql(u8, arg, "-u")) {
            i += 1;
            if (i >= args.len) return CliError.MissingValue;
            options.url = try allocator.dupe(u8, args[i]);
        } else if (std.mem.eql(u8, arg, "--html")) {
            i += 1;
            if (i >= args.len) return CliError.MissingValue;
            options.html = try allocator.dupe(u8, args[i]);
        } else if (std.mem.eql(u8, arg, "--title") or std.mem.eql(u8, arg, "-t")) {
            i += 1;
            if (i >= args.len) return CliError.MissingValue;
            options.title = try allocator.dupe(u8, args[i]);
        } else if (std.mem.eql(u8, arg, "--width") or std.mem.eql(u8, arg, "-w")) {
            i += 1;
            if (i >= args.len) return CliError.MissingValue;
            options.width = std.fmt.parseInt(u32, args[i], 10) catch return CliError.InvalidNumber;
        } else if (std.mem.eql(u8, arg, "--height")) {
            i += 1;
            if (i >= args.len) return CliError.MissingValue;
            options.height = std.fmt.parseInt(u32, args[i], 10) catch return CliError.InvalidNumber;
        } else if (std.mem.eql(u8, arg, "--x") or std.mem.eql(u8, arg, "-x")) {
            i += 1;
            if (i >= args.len) return CliError.MissingValue;
            options.x = std.fmt.parseInt(i32, args[i], 10) catch return CliError.InvalidNumber;
        } else if (std.mem.eql(u8, arg, "--y") or std.mem.eql(u8, arg, "-y")) {
            i += 1;
            if (i >= args.len) return CliError.MissingValue;
            options.y = std.fmt.parseInt(i32, args[i], 10) catch return CliError.InvalidNumber;
        } else if (std.mem.eql(u8, arg, "--frameless")) {
            options.frameless = true;
        } else if (std.mem.eql(u8, arg, "--transparent")) {
            options.transparent = true;
        } else if (std.mem.eql(u8, arg, "--always-on-top")) {
            options.always_on_top = true;
        } else if (std.mem.eql(u8, arg, "--fullscreen") or std.mem.eql(u8, arg, "-f")) {
            options.fullscreen = true;
        } else if (std.mem.eql(u8, arg, "--no-resize")) {
            options.resizable = false;
        } else if (std.mem.eql(u8, arg, "--titlebar-hidden")) {
            debugPrint("[CLI DEBUG] Found --titlebar-hidden flag, setting to true\n", .{});
            options.titlebar_hidden = true;
        } else if (std.mem.eql(u8, arg, "--debug")) {
            // Already handled in first pass
        } else if (std.mem.eql(u8, arg, "--no-devtools")) {
            options.dev_tools = false;
        } else if (std.mem.eql(u8, arg, "--dark")) {
            options.dark_mode = true;
        } else if (std.mem.eql(u8, arg, "--light")) {
            options.dark_mode = false;
        } else if (std.mem.eql(u8, arg, "--hot-reload")) {
            options.hot_reload = true;
        } else if (std.mem.eql(u8, arg, "--system-tray")) {
            options.system_tray = true;
        } else if (std.mem.eql(u8, arg, "--hide-dock-icon")) {
            options.hide_dock_icon = true;
        } else if (std.mem.eql(u8, arg, "--menubar-only")) {
            options.menubar_only = true;
            options.system_tray = true; // Menubar-only implies system tray
            options.hide_dock_icon = true; // And hiding dock icon
        } else if (std.mem.eql(u8, arg, "--native-sidebar")) {
            options.native_sidebar = true;
        } else if (std.mem.eql(u8, arg, "--sidebar-width")) {
            i += 1;
            if (i >= args.len) return CliError.MissingValue;
            options.sidebar_width = std.fmt.parseInt(u32, args[i], 10) catch return CliError.InvalidNumber;
        } else if (std.mem.eql(u8, arg, "--benchmark")) {
            options.benchmark = true;
        } else if (std.mem.eql(u8, arg, "--sidebar-config")) {
            i += 1;
            if (i >= args.len) return CliError.MissingValue;
            options.sidebar_config = try allocator.dupe(u8, args[i]);
        } else if (!std.mem.startsWith(u8, arg, "--")) {
            // Treat as positional URL argument
            if (options.url == null) {
                options.url = try allocator.dupe(u8, arg);
            }
        }
    }

    debugPrint("[CLI DEBUG] Final options: titlebar_hidden={}, frameless={}, transparent={}\n", .{
        options.titlebar_hidden,
        options.frameless,
        options.transparent,
    });

    return options;
}

fn printHelp() void {
    std.debug.print(
        \\
        \\⚡ Craft - Build desktop apps with web languages
        \\
        \\Usage: craft [OPTIONS] [URL]
        \\
        \\Window Content:
        \\  -u, --url <URL>          Load URL in the window
        \\      --html <HTML>        Load HTML content directly
        \\
        \\Window Appearance:
        \\  -t, --title <TITLE>      Window title (default: "Craft App")
        \\  -w, --width <WIDTH>      Window width (default: 1200)
        \\      --height <HEIGHT>    Window height (default: 800)
        \\  -x, --x <X>              Window x position (default: centered)
        \\  -y, --y <Y>              Window y position (default: centered)
        \\
        \\Window Style:
        \\      --frameless          Create frameless window
        \\      --transparent        Make window transparent
        \\      --always-on-top      Keep window always on top
        \\  -f, --fullscreen         Start in fullscreen mode
        \\      --no-resize          Disable window resizing
        \\
        \\Theme:
        \\      --dark               Force dark mode
        \\      --light              Force light mode
        \\
        \\Features:
        \\      --hot-reload         Enable hot reload support
        \\      --system-tray        Show system tray icon
        \\      --hide-dock-icon     Hide dock icon (menubar-only mode, macOS)
        \\      --menubar-only       Menubar-only mode (no window, system tray only)
        \\      --no-devtools        Disable WebKit DevTools
        \\      --titlebar-hidden    Hide window titlebar
        \\      --native-sidebar     Use native macOS sidebar (Finder-style)
        \\      --sidebar-width <W>  Sidebar width in pixels (default: 220)
        \\
        \\Debugging:
        \\      --debug              Enable debug output
        \\      --benchmark          Benchmark mode: create window, print "ready", exit
        \\
        \\Information:
        \\  -h, --help               Show this help message
        \\  -v, --version            Show version information
        \\
        \\Examples:
        \\  craft http://localhost:3000
        \\  craft --url http://example.com --width 800 --height 600
        \\  craft --url http://localhost:3000 --title "My App" --frameless
        \\  craft --html "<h1>Hello, World!</h1>" --width 400 --height 300
        \\  craft http://localhost:3000 --x 100 --y 100 --fullscreen
        \\  craft http://localhost:3000 --transparent --always-on-top
        \\  craft http://localhost:3000 --dark --hot-reload
        \\  craft http://localhost:3000 --system-tray --light
        \\  craft http://localhost:3000 --native-sidebar --sidebar-width 250
        \\
        \\For more information, visit: https://github.com/stacksjs/craft
        \\
        \\
    , .{});
}

fn printVersion() void {
    const target = @import("builtin").target;
    const platform_name = switch (target.os.tag) {
        .macos => "macOS",
        .linux => "Linux",
        .windows => "Windows",
        else => "Unknown",
    };

    std.debug.print(
        \\craft version 1.3.0
        \\Built with Zig 0.16.0
        \\Platform: {s}
        \\Features: 79
        \\
        \\
    , .{platform_name});
}
