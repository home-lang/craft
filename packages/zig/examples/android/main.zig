const std = @import("std");
const craft = @import("craft");

/// Android Example
///
/// Demonstrates how to build Android apps with Craft:
/// - CraftActivity for Android lifecycle
/// - JavaScript bridge for web-native communication
/// - Native Android features (toast, vibration, etc.)

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Craft Android Demo ===\n\n", .{});

    // Demo 1: Create CraftActivity
    std.debug.print("1. Creating CraftActivity...\n", .{});

    var app = craft.CraftActivity.init(allocator, .{
        .name = "My Craft App",
        .package_name = "com.example.craftapp",
        .initial_content = .{ .html = app_html },
        .theme = .system,
        .orientation = .portrait,
        .enable_javascript = true,
        .enable_dom_storage = true,
        .enable_inspector = true, // Enable WebView inspector in debug
    });
    defer app.deinit();

    std.debug.print("   Activity created: {s}\n", .{app.config.name});
    std.debug.print("   Package: {s}\n", .{app.config.package_name});

    // Demo 2: Set lifecycle callbacks
    std.debug.print("\n2. Setting lifecycle callbacks...\n", .{});

    app.onCreate(onAppCreate);
    app.onResume(onAppResume);
    app.onPause(onAppPause);
    app.onDestroy(onAppDestroy);
    app.onBackPressed(onBackPressed);

    std.debug.print("   Callbacks registered!\n", .{});

    // Demo 3: Register custom JavaScript handlers
    std.debug.print("\n3. Registering custom JS handlers...\n", .{});

    try app.run();

    if (app.getBridge()) |bridge| {
        try bridge.registerHandler("customAction", handleCustomAction);
        try bridge.registerHandler("getUserData", handleGetUserData);
        std.debug.print("   Custom handlers registered!\n", .{});
    }

    // Demo 4: Show available native features
    std.debug.print("\n4. Available Android features:\n", .{});
    std.debug.print("   - showToast: Show toast messages\n", .{});
    std.debug.print("   - vibrate: Device vibration\n", .{});
    std.debug.print("   - setClipboard/getClipboard: Clipboard access\n", .{});
    std.debug.print("   - share: Native share dialog\n", .{});
    std.debug.print("   - openURL: Open URLs in browser\n", .{});
    std.debug.print("   - showAlert: Native alert dialogs\n", .{});

    // Demo 5: Device info
    std.debug.print("\n5. Device info:\n", .{});
    const device = craft.AndroidFeatures.getDeviceInfo();
    std.debug.print("   Manufacturer: {s}\n", .{device.manufacturer});
    std.debug.print("   Model: {s}\n", .{device.model});
    std.debug.print("   OS Version: {s}\n", .{device.os_version});
    std.debug.print("   SDK Version: {d}\n", .{device.sdk_version});

    std.debug.print("\n=== Demo Complete ===\n", .{});
    std.debug.print("Build APK with: zig build android-apk\n\n", .{});
}

// Lifecycle callbacks
fn onAppCreate() void {
    std.debug.print("   [LIFECYCLE] onCreate called\n", .{});
}

fn onAppResume() void {
    std.debug.print("   [LIFECYCLE] onResume called\n", .{});
}

fn onAppPause() void {
    std.debug.print("   [LIFECYCLE] onPause called\n", .{});
}

fn onAppDestroy() void {
    std.debug.print("   [LIFECYCLE] onDestroy called\n", .{});
}

fn onBackPressed() bool {
    std.debug.print("   [LIFECYCLE] onBackPressed - consuming event\n", .{});
    return true; // Consume the back button event
}

// Custom JavaScript handlers
fn handleCustomAction(params: []const u8, bridge: *craft.AndroidJSBridge, callback_id: []const u8) void {
    std.debug.print("   [JS] customAction called with: {s}\n", .{params});
    bridge.sendResponse(callback_id, "{ \"status\": \"ok\" }") catch {};
}

fn handleGetUserData(_: []const u8, bridge: *craft.AndroidJSBridge, callback_id: []const u8) void {
    std.debug.print("   [JS] getUserData called\n", .{});
    const response =
        \\{ "user": { "name": "John Doe", "email": "john@example.com" } }
    ;
    bridge.sendResponse(callback_id, response) catch {};
}

// Example HTML for the app
const app_html =
    \\<!DOCTYPE html>
    \\<html>
    \\<head>
    \\    <meta charset="UTF-8">
    \\    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    \\    <title>Craft Android App</title>
    \\    <style>
    \\        * { box-sizing: border-box; margin: 0; padding: 0; }
    \\        body {
    \\            font-family: 'Roboto', sans-serif;
    \\            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    \\            min-height: 100vh;
    \\            padding: 20px;
    \\            color: white;
    \\        }
    \\        .container {
    \\            max-width: 400px;
    \\            margin: 0 auto;
    \\        }
    \\        h1 {
    \\            font-size: 1.8rem;
    \\            margin-bottom: 20px;
    \\            text-align: center;
    \\        }
    \\        .card {
    \\            background: rgba(255, 255, 255, 0.15);
    \\            border-radius: 16px;
    \\            padding: 20px;
    \\            margin-bottom: 16px;
    \\            backdrop-filter: blur(10px);
    \\        }
    \\        .card h2 {
    \\            font-size: 1.1rem;
    \\            margin-bottom: 12px;
    \\            opacity: 0.9;
    \\        }
    \\        button {
    \\            width: 100%;
    \\            padding: 14px;
    \\            border: none;
    \\            border-radius: 8px;
    \\            font-size: 1rem;
    \\            cursor: pointer;
    \\            margin-bottom: 10px;
    \\            background: rgba(255, 255, 255, 0.9);
    \\            color: #333;
    \\            font-weight: 500;
    \\            transition: transform 0.1s;
    \\        }
    \\        button:active {
    \\            transform: scale(0.98);
    \\        }
    \\        #output {
    \\            background: rgba(0, 0, 0, 0.2);
    \\            padding: 12px;
    \\            border-radius: 8px;
    \\            font-family: monospace;
    \\            font-size: 0.85rem;
    \\            min-height: 60px;
    \\            word-wrap: break-word;
    \\        }
    \\    </style>
    \\</head>
    \\<body>
    \\    <div class="container">
    \\        <h1>Craft Android</h1>
    \\
    \\        <div class="card">
    \\            <h2>Native Features</h2>
    \\            <button onclick="showToast()">Show Toast</button>
    \\            <button onclick="vibrate()">Vibrate</button>
    \\            <button onclick="shareContent()">Share</button>
    \\            <button onclick="getPlatform()">Get Platform Info</button>
    \\        </div>
    \\
    \\        <div class="card">
    \\            <h2>Custom Actions</h2>
    \\            <button onclick="customAction()">Custom Action</button>
    \\            <button onclick="getUserData()">Get User Data</button>
    \\        </div>
    \\
    \\        <div class="card">
    \\            <h2>Output</h2>
    \\            <div id="output">Ready...</div>
    \\        </div>
    \\    </div>
    \\
    \\    <script>
    \\        function log(msg) {
    \\            document.getElementById('output').textContent = msg;
    \\        }
    \\
    \\        async function invoke(method, params = {}) {
    \\            return new Promise((resolve) => {
    \\                const callbackId = 'cb_' + Date.now();
    \\                window['__craftCallback_' + callbackId] = (result) => {
    \\                    delete window['__craftCallback_' + callbackId];
    \\                    resolve(result);
    \\                };
    \\                if (window.CraftBridge) {
    \\                    CraftBridge.postMessage(JSON.stringify({
    \\                        method: method,
    \\                        params: params,
    \\                        callbackId: callbackId
    \\                    }));
    \\                } else {
    \\                    log('CraftBridge not available (demo mode)');
    \\                    resolve({ demo: true });
    \\                }
    \\            });
    \\        }
    \\
    \\        async function showToast() {
    \\            const result = await invoke('showToast', { message: 'Hello from Craft!' });
    \\            log('Toast: ' + JSON.stringify(result));
    \\        }
    \\
    \\        async function vibrate() {
    \\            const result = await invoke('vibrate', { duration: 100 });
    \\            log('Vibrate: ' + JSON.stringify(result));
    \\        }
    \\
    \\        async function shareContent() {
    \\            const result = await invoke('share', { text: 'Check out Craft!' });
    \\            log('Share: ' + JSON.stringify(result));
    \\        }
    \\
    \\        async function getPlatform() {
    \\            const result = await invoke('getPlatform');
    \\            log('Platform: ' + JSON.stringify(result));
    \\        }
    \\
    \\        async function customAction() {
    \\            const result = await invoke('customAction', { action: 'test' });
    \\            log('Custom: ' + JSON.stringify(result));
    \\        }
    \\
    \\        async function getUserData() {
    \\            const result = await invoke('getUserData');
    \\            log('User: ' + JSON.stringify(result));
    \\        }
    \\
    \\        // Listen for native events
    \\        window.addEventListener('craft:ready', () => {
    \\            log('Craft native bridge ready!');
    \\        });
    \\    </script>
    \\</body>
    \\</html>
;

// Example: Using quick start
pub fn simpleApp() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // One-liner to start an Android app
    try craft.android.quickStart(allocator,
        \\<!DOCTYPE html>
        \\<html>
        \\<body><h1>Hello, Android!</h1></body>
        \\</html>
    );
}
