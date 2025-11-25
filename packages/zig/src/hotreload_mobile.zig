const std = @import("std");
const hotreload = @import("hotreload.zig");

/// Mobile Hot Reload
/// WebSocket-based hot reload for iOS and Android

pub const MobileHotReloadServer = struct {
    allocator: std.mem.Allocator,
    port: u16,
    running: bool = false,
    clients: std.ArrayList(Client),

    const Client = struct {
        socket: std.net.Stream,
        platform: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator, port: u16) MobileHotReloadServer {
        return .{
            .allocator = allocator,
            .port = port,
            .clients = std.ArrayList(Client).init(allocator),
        };
    }

    pub fn deinit(self: *MobileHotReloadServer) void {
        for (self.clients.items) |client| {
            client.socket.close();
        }
        self.clients.deinit();
    }

    pub fn start(self: *MobileHotReloadServer) !void {
        const address = try std.net.Address.parseIp("0.0.0.0", self.port);
        var server = try address.listen(.{
            .reuse_address = true,
        });
        defer server.deinit();

        self.running = true;
        std.debug.print("Mobile hot reload server listening on port {d}\n", .{self.port});

        while (self.running) {
            const connection = try server.accept();
            try self.handleClient(connection);
        }
    }

    fn handleClient(self: *MobileHotReloadServer, connection: std.net.Server.Connection) !void {
        // Simple WebSocket handshake
        var buffer: [4096]u8 = undefined;
        const bytes_read = try connection.stream.read(&buffer);

        if (bytes_read == 0) return;

        // Check if it's a WebSocket upgrade request
        const request = buffer[0..bytes_read];
        if (std.mem.indexOf(u8, request, "Upgrade: websocket") == null) {
            connection.stream.close();
            return;
        }

        // Send WebSocket handshake response
        const response =
            \\HTTP/1.1 101 Switching Protocols
            \\Upgrade: websocket
            \\Connection: Upgrade
            \\Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
            \\
            \\
        ;
        try connection.stream.writeAll(response);

        // Add client to list
        try self.clients.append(.{
            .socket = connection.stream,
            .platform = "unknown",
        });

        std.debug.print("Mobile client connected. Total clients: {d}\n", .{self.clients.items.len});
    }

    pub fn broadcastReload(self: *MobileHotReloadServer, file_path: []const u8) !void {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "{{\"type\":\"reload\",\"file\":\"{s}\"}}",
            .{file_path},
        );
        defer self.allocator.free(message);

        // WebSocket frame for text message
        var frame = std.ArrayList(u8).init(self.allocator);
        defer frame.deinit();

        try frame.append(0x81); // FIN + text frame
        if (message.len < 126) {
            try frame.append(@as(u8, @intCast(message.len)));
        } else if (message.len < 65536) {
            try frame.append(126);
            try frame.append(@as(u8, @intCast((message.len >> 8) & 0xFF)));
            try frame.append(@as(u8, @intCast(message.len & 0xFF)));
        }
        try frame.appendSlice(message);

        var i: usize = 0;
        while (i < self.clients.items.len) {
            const client = self.clients.items[i];
            client.socket.writeAll(frame.items) catch {
                // Remove disconnected client
                _ = self.clients.swapRemove(i);
                client.socket.close();
                continue;
            };
            i += 1;
        }

        std.debug.print("Broadcast reload to {d} clients\n", .{self.clients.items.len});
    }

    pub fn stop(self: *MobileHotReloadServer) void {
        self.running = false;
    }
};

/// Mobile Hot Reload Manager
/// Integrates file watching with WebSocket broadcast
pub const MobileHotReloadManager = struct {
    allocator: std.mem.Allocator,
    server: MobileHotReloadServer,
    watcher: hotreload.FileWatcher,
    running: bool = false,

    pub fn init(allocator: std.mem.Allocator, config: hotreload.HotReloadConfig, port: u16) !MobileHotReloadManager {
        const server = MobileHotReloadServer.init(allocator, port);
        const watcher = try hotreload.FileWatcher.init(allocator, config);

        return .{
            .allocator = allocator,
            .server = server,
            .watcher = watcher,
        };
    }

    pub fn deinit(self: *MobileHotReloadManager) void {
        self.server.deinit();
        self.watcher.deinit();
    }

    pub fn start(self: *MobileHotReloadManager) !void {
        self.running = true;

        // Start server in separate thread
        const server_thread = try std.Thread.spawn(.{}, serverLoop, .{&self.server});
        defer server_thread.join();

        // Watch for file changes
        while (self.running) {
            if (try self.watcher.check()) {
                try self.server.broadcastReload("*");
            }
            std.time.sleep(100 * std.time.ns_per_ms);
        }
    }

    fn serverLoop(server: *MobileHotReloadServer) !void {
        try server.start();
    }

    pub fn stop(self: *MobileHotReloadManager) void {
        self.running = false;
        self.server.stop();
    }
};

/// Generate mobile hot reload client script
pub fn generateClientScript(allocator: std.mem.Allocator, server_url: []const u8) ![]u8 {
    const script = try std.fmt.allocPrint(
        allocator,
        \\(function() {{
        \\  const HOTRELOAD_URL = '{s}';
        \\  let ws = null;
        \\  let reconnectAttempts = 0;
        \\  const MAX_RECONNECT_ATTEMPTS = 10;
        \\
        \\  function connect() {{
        \\    if (ws && ws.readyState === WebSocket.OPEN) {{
        \\      return;
        \\    }}
        \\
        \\    console.log('[HotReload] Connecting to ' + HOTRELOAD_URL);
        \\    ws = new WebSocket(HOTRELOAD_URL);
        \\
        \\    ws.onopen = function() {{
        \\      console.log('[HotReload] Connected');
        \\      reconnectAttempts = 0;
        \\    }};
        \\
        \\    ws.onmessage = function(event) {{
        \\      try {{
        \\        const data = JSON.parse(event.data);
        \\        console.log('[HotReload] Received:', data);
        \\
        \\        if (data.type === 'reload') {{
        \\          console.log('[HotReload] Reloading...');
        \\          window.location.reload();
        \\        }}
        \\      }} catch (e) {{
        \\        console.error('[HotReload] Error parsing message:', e);
        \\      }}
        \\    }};
        \\
        \\    ws.onerror = function(error) {{
        \\      console.error('[HotReload] Error:', error);
        \\    }};
        \\
        \\    ws.onclose = function() {{
        \\      console.log('[HotReload] Disconnected');
        \\      ws = null;
        \\
        \\      if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {{
        \\        const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 10000);
        \\        console.log('[HotReload] Reconnecting in ' + delay + 'ms...');
        \\        setTimeout(connect, delay);
        \\        reconnectAttempts++;
        \\      }} else {{
        \\        console.error('[HotReload] Max reconnect attempts reached');
        \\      }}
        \\    }};
        \\  }}
        \\
        \\  // Start connection
        \\  connect();
        \\
        \\  // Expose API
        \\  window.craftHotReload = {{
        \\    reconnect: connect,
        \\    disconnect: function() {{
        \\      if (ws) {{
        \\        ws.close();
        \\        ws = null;
        \\      }}
        \\    }}
        \\  }};
        \\
        \\  console.log('[HotReload] Client initialized');
        \\}})();
        \\
    ,
        .{server_url},
    );

    return script;
}

// Tests
test "Mobile hot reload server init" {
    const allocator = std.testing.allocator;
    var server = MobileHotReloadServer.init(allocator, 8765);
    defer server.deinit();

    try std.testing.expect(server.port == 8765);
    try std.testing.expect(server.clients.items.len == 0);
}

test "Generate client script" {
    const allocator = std.testing.allocator;
    const script = try generateClientScript(allocator, "ws://localhost:8765");
    defer allocator.free(script);

    try std.testing.expect(std.mem.indexOf(u8, script, "WebSocket") != null);
    try std.testing.expect(std.mem.indexOf(u8, script, "localhost:8765") != null);
}
