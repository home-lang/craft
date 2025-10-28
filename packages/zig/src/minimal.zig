const std = @import("std");
const builtin = @import("builtin");
const craft = @import("craft");
const cli = @import("cli.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse CLI arguments
    const options = cli.parseArgs(allocator) catch |err| {
        switch (err) {
            cli.CliError.InvalidArgument => std.debug.print("Error: Invalid argument\n", .{}),
            cli.CliError.MissingValue => std.debug.print("Error: Missing value for argument\n", .{}),
            cli.CliError.InvalidNumber => std.debug.print("Error: Invalid number format\n", .{}),
            else => std.debug.print("Error: {}\n", .{err}),
        }
        std.process.exit(1);
    };

    // Special handling for system tray apps - use direct approach like minimal test
    if (options.system_tray) {
        try runWithSystemTray(allocator, options);
        return;
    }

    var app = craft.App.init(allocator);
    defer app.deinit();

    // Initialize platform FIRST (must be called before creating windows or system tray)
    // This calls finishLaunching on macOS which is required for menubar items
    app.initPlatform();

    // Determine what to load
    if (options.url) |url| {
        // Load URL directly (no iframe!)
        std.debug.print("\n⚡ Loading URL in native window: {s}\n", .{url});
        std.debug.print("   Title: {s}\n", .{options.title});
        std.debug.print("   Size: {d}x{d}\n", .{ options.width, options.height });
        if (options.frameless) std.debug.print("   Style: Frameless\n", .{});
        if (options.transparent) std.debug.print("   Style: Transparent\n", .{});
        if (options.always_on_top) std.debug.print("   Style: Always on top\n", .{});
        if (options.dark_mode) |is_dark| std.debug.print("   Theme: {s}\n", .{if (is_dark) "Dark" else "Light"});
        if (options.hot_reload) std.debug.print("   Hot Reload: Enabled\n", .{});
        if (options.system_tray) std.debug.print("   System Tray: Enabled\n", .{});
        if (options.hide_dock_icon) std.debug.print("   Dock Icon: Hidden (menubar-only mode)\n", .{});
        if (options.dev_tools) std.debug.print("   DevTools: Enabled (Right-click > Inspect Element)\n", .{});
        std.debug.print("\n", .{});

        _ = try app.createWindowWithURL(
            options.title,
            options.width,
            options.height,
            url,
            .{
                .frameless = options.frameless,
                .transparent = options.transparent,
                .always_on_top = options.always_on_top,
                .resizable = options.resizable,
                .fullscreen = options.fullscreen,
                .x = options.x,
                .y = options.y,
                .dark_mode = options.dark_mode,
                .enable_hot_reload = options.hot_reload,
                .hide_dock_icon = options.hide_dock_icon,
            },
        );
    } else if (options.html) |html| {
        // Load HTML content
        std.debug.print("\n⚡ Loading HTML content in native window\n", .{});
        std.debug.print("   Title: {s}\n", .{options.title});
        std.debug.print("   Size: {d}x{d}\n\n", .{ options.width, options.height });

        _ = try app.createWindowWithHTML(
            options.title,
            options.width,
            options.height,
            html,
            .{
                .frameless = options.frameless,
                .transparent = options.transparent,
                .resizable = options.resizable,
                .always_on_top = options.always_on_top,
                .fullscreen = options.fullscreen,
                .x = options.x,
                .y = options.y,
                .dark_mode = options.dark_mode,
                .enable_hot_reload = options.hot_reload,
                .hide_dock_icon = options.hide_dock_icon,
            },
        );
    } else {
        // Show default demo app
        std.debug.print("\n⚡ Launching Craft demo app\n", .{});
        std.debug.print("   Run with --help to see available options\n\n", .{});

        const demo_html =
            \\<!DOCTYPE html>
            \\<html>
            \\<head>
            \\    <meta charset="UTF-8">
            \\    <title>Craft Demo</title>
            \\    <style>
            \\        * {
            \\            margin: 0;
            \\            padding: 0;
            \\            box-sizing: border-box;
            \\        }
            \\        body {
            \\            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            \\            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            \\            height: 100vh;
            \\            display: flex;
            \\            justify-content: center;
            \\            align-items: center;
            \\            color: white;
            \\        }
            \\        .container {
            \\            text-align: center;
            \\            padding: 3rem;
            \\            background: rgba(255, 255, 255, 0.1);
            \\            border-radius: 20px;
            \\            backdrop-filter: blur(10px);
            \\            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            \\        }
            \\        h1 {
            \\            font-size: 4rem;
            \\            margin-bottom: 1rem;
            \\            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
            \\        }
            \\        p {
            \\            font-size: 1.5rem;
            \\            opacity: 0.9;
            \\        }
            \\        .emoji {
            \\            font-size: 6rem;
            \\            margin-bottom: 1rem;
            \\            animation: bounce 2s infinite;
            \\        }
            \\        @keyframes bounce {
            \\            0%, 100% { transform: translateY(0); }
            \\            50% { transform: translateY(-20px); }
            \\        }
            \\        code {
            \\            background: rgba(0, 0, 0, 0.3);
            \\            padding: 0.2rem 0.5rem;
            \\            border-radius: 4px;
            \\            font-family: monospace;
            \\        }
            \\    </style>
            \\</head>
            \\<body>
            \\    <div class="container">
            \\        <div class="emoji">⚡</div>
            \\        <h1>Craft</h1>
            \\        <p>Desktop apps with web languages</p>
            \\        <p style="margin-top: 2rem; font-size: 1rem; opacity: 0.7;">
            \\            Try: <code>craft --help</code>
            \\        </p>
            \\    </div>
            \\</body>
            \\</html>
        ;

        _ = try app.createWindow("Craft - Demo", 600, 400, demo_html);
    }

    // Create system tray if requested
    if (options.system_tray) {
        const sys_tray = try app.createSystemTray(options.title);

        // Set tooltip with additional info
        const tooltip = try std.fmt.allocPrint(
            allocator,
            "{s} - Craft Application",
            .{options.title},
        );
        defer allocator.free(tooltip);
        try sys_tray.setTooltip(tooltip);

        std.debug.print("   System Tray: Created successfully\n", .{});
    }

    try app.run();
}

/// Run with system tray using a modified App flow
/// Key difference: we create the system tray BEFORE calling initPlatform
fn runWithSystemTray(allocator: std.mem.Allocator, options: cli.WindowOptions) !void {
    std.debug.print("\n⚡ Creating system tray application\n", .{});
    std.debug.print("   Title: {s}\n", .{options.title});

    if (options.menubar_only) {
        std.debug.print("   Mode: Menubar-only (no window)\n", .{});
    } else if (options.url) |url| {
        std.debug.print("   URL: {s}\n", .{url});
        std.debug.print("   Size: {d}x{d}\n", .{ options.width, options.height });
    }

    if (options.hide_dock_icon) {
        std.debug.print("   Style: Menubar-only (no Dock icon)\n", .{});
    }
    std.debug.print("\n", .{});

    var app = craft.App.init(allocator);
    defer app.deinit();

    // Initialize platform for TRAY apps - uses Accessory policy AND calls finishLaunching
    // This MUST happen BEFORE creating the status bar item (proven by working test)
    app.initPlatformForTray();

    // Create system tray AFTER finishLaunching (this is the key!)
    const sys_tray = try app.createSystemTray(options.title);

    // Setup bridge handlers with tray handle
    // This will be done automatically when the window is created

    // Create window AFTER system tray (UNLESS menubar-only mode is enabled)
    if (!options.menubar_only) {
        if (options.url) |url| {
            _ = try app.createWindowWithURL(
                options.title,
                options.width,
                options.height,
                url,
                .{
                    .frameless = options.frameless,
                    .transparent = options.transparent,
                    .always_on_top = options.always_on_top,
                    .resizable = options.resizable,
                    .fullscreen = options.fullscreen,
                    .x = options.x,
                    .y = options.y,
                    .dark_mode = options.dark_mode,
                    .enable_hot_reload = options.hot_reload,
                    .hide_dock_icon = options.hide_dock_icon,
                },
            );
        } else if (options.html) |html| {
            _ = try app.createWindowWithHTML(
                options.title,
                options.width,
                options.height,
                html,
                .{
                    .frameless = options.frameless,
                    .transparent = options.transparent,
                    .resizable = options.resizable,
                    .always_on_top = options.always_on_top,
                    .fullscreen = options.fullscreen,
                    .x = options.x,
                    .y = options.y,
                    .dark_mode = options.dark_mode,
                    .enable_hot_reload = options.hot_reload,
                    .hide_dock_icon = options.hide_dock_icon,
                },
            );
        }
    }

    // Set tooltip with additional info
    const tooltip = try std.fmt.allocPrint(
        allocator,
        "{s} - Craft Application",
        .{options.title},
    );
    defer allocator.free(tooltip);
    try sys_tray.setTooltip(tooltip);

    std.debug.print("✅ System tray icon created\n", .{});
    std.debug.print("   Look for \"{s}\" in your menubar\n\n", .{options.title});

    // Show windows AFTER system tray is created but BEFORE running the event loop
    // Using orderFront (in showWindows) prevents app activation which would hide the tray
    // IMPORTANT: We must show windows even in menubar-only mode to trigger WebView loading
    // Without this, the WebView won't load its HTML/JavaScript content
    app.showWindows();

    try app.run();
}
