const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Local HTTP server bridge — designed for OAuth callback flows.
///
/// **Why this exists**: every app that signs in to Google/GitHub/Slack
/// needs to bind a local socket to receive the redirect. Browser apps
/// can't do this. Node ships an http server, but in a Craft window the
/// renderer is a webview without socket privileges. So we run a tiny
/// listener on the native side that emits incoming requests as
/// `craft:localServer:request` events.
///
/// **Scope**: this is intentionally not a general-purpose HTTP server.
/// We accept ONE connection at a time, read until end-of-headers,
/// emit the parsed request line + URL to JS, and respond with a small
/// HTML page (configurable). That's enough for OAuth and "click to
/// authorize" redirect flows; apps building real web servers should
/// use Bun's HTTP from the renderer or a separate process.
pub const LocalServerBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.stopServer() catch {};
    }

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "start")) try self.startServer(data)
        else if (std.mem.eql(u8, action, "stop")) try self.stopFromMessage()
        else if (std.mem.eql(u8, action, "respond")) try self.respondToRequest(data)
        else return BridgeError.UnknownAction;
    }

    fn startServer(self: *Self, data: []const u8) !void {
        const ParseShape = struct { port: u16 = 0, host: []const u8 = "127.0.0.1" };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();

        if (server_socket != -1) {
            // Already running. Be idempotent — return the bound port.
            var buf: [128]u8 = undefined;
            const json = try std.fmt.bufPrint(&buf,
                "{{\"port\":{d},\"started\":true,\"alreadyRunning\":true}}",
                .{bound_port});
            bridge_error.sendResultToJS(self.allocator, "start", json);
            return;
        }

        // Bind + listen via libc sockets. AF_INET, SOCK_STREAM, IPPROTO_TCP.
        const fd = socket(2, 1, 0); // AF_INET=2, SOCK_STREAM=1
        if (fd < 0) {
            bridge_error.sendResultToJS(self.allocator, "start", "{\"started\":false,\"reason\":\"socket() failed\"}");
            return;
        }

        // SO_REUSEADDR so a hot-reload doesn't get "address in use."
        var one: c_int = 1;
        _ = setsockopt(fd, 0xffff, 0x0004, &one, @sizeOf(c_int)); // SOL_SOCKET, SO_REUSEADDR

        var addr = sockaddr_in{
            .sin_len = @sizeOf(sockaddr_in),
            .sin_family = 2,
            .sin_port = htons(parsed.value.port),
            .sin_addr = inAddrLoopback(),
            .sin_zero = .{0} ** 8,
        };
        if (bind(fd, @ptrCast(&addr), @sizeOf(sockaddr_in)) < 0) {
            _ = close(fd);
            bridge_error.sendResultToJS(self.allocator, "start", "{\"started\":false,\"reason\":\"bind() failed — port in use?\"}");
            return;
        }
        if (listen(fd, 1) < 0) {
            _ = close(fd);
            bridge_error.sendResultToJS(self.allocator, "start", "{\"started\":false,\"reason\":\"listen() failed\"}");
            return;
        }

        // Read back the actual bound port (when caller passed 0).
        var actual_addr: sockaddr_in = undefined;
        var len: c_uint = @sizeOf(sockaddr_in);
        _ = getsockname(fd, @ptrCast(&actual_addr), &len);
        bound_port = ntohs(actual_addr.sin_port);
        server_socket = fd;

        // Spawn an accept-loop on a detached pthread. Each accepted
        // connection reads request headers, fires a JS event with the
        // parsed URL, and waits for a `respond` message before
        // closing. Apps that don't `respond` get a default 200 after
        // the response timeout.
        spawnAcceptThread();

        var buf: [128]u8 = undefined;
        const json = try std.fmt.bufPrint(&buf, "{{\"port\":{d},\"started\":true}}", .{bound_port});
        bridge_error.sendResultToJS(self.allocator, "start", json);
    }

    fn stopFromMessage(self: *Self) !void {
        try self.stopServer();
        bridge_error.sendResultToJS(self.allocator, "stop", "{\"ok\":true}");
    }

    fn stopServer(_: *Self) !void {
        if (server_socket != -1) {
            _ = close(server_socket);
            server_socket = -1;
        }
        // The accept thread sees -1 and exits on next iteration.
    }

    fn respondToRequest(self: *Self, data: []const u8) !void {
        // Apps respond to the in-flight request via this action. The
        // payload selects the HTTP status + body. A typical OAuth
        // success page is `{status:200, body:"Auth complete — return to the app."}`.
        const ParseShape = struct {
            status: u16 = 200,
            body: []const u8 = "OK",
            contentType: []const u8 = "text/html; charset=utf-8",
        };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();

        if (active_client_socket == -1) {
            bridge_error.sendResultToJS(self.allocator, "respond", "{\"ok\":false,\"reason\":\"no in-flight request\"}");
            return;
        }

        var header_buf: [512]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf,
            "HTTP/1.1 {d} OK\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n",
            .{ parsed.value.status, parsed.value.contentType, parsed.value.body.len });
        _ = send(active_client_socket, header.ptr, header.len, 0);
        _ = send(active_client_socket, parsed.value.body.ptr, parsed.value.body.len, 0);
        _ = close(active_client_socket);
        active_client_socket = -1;

        bridge_error.sendResultToJS(self.allocator, "respond", "{\"ok\":true}");
    }
};

// =============================================================================
// libc socket bindings + accept loop
// =============================================================================

const sockaddr_in = extern struct {
    sin_len: u8,
    sin_family: u8,
    sin_port: u16,
    sin_addr: u32,
    sin_zero: [8]u8,
};

extern "c" fn socket(domain: c_int, type_: c_int, protocol: c_int) c_int;
extern "c" fn bind(fd: c_int, addr: *const anyopaque, addrlen: c_uint) c_int;
extern "c" fn listen(fd: c_int, backlog: c_int) c_int;
extern "c" fn accept(fd: c_int, addr: ?*anyopaque, addrlen: ?*c_uint) c_int;
extern "c" fn setsockopt(fd: c_int, level: c_int, name: c_int, value: *const anyopaque, len: c_uint) c_int;
extern "c" fn getsockname(fd: c_int, addr: *anyopaque, addrlen: *c_uint) c_int;
extern "c" fn close(fd: c_int) c_int;
extern "c" fn read(fd: c_int, buf: [*]u8, len: usize) isize;
extern "c" fn send(fd: c_int, buf: [*]const u8, len: usize, flags: c_int) isize;
extern "c" fn pthread_create(thread: *?*anyopaque, attr: ?*anyopaque, start: *const fn (?*anyopaque) callconv(.c) ?*anyopaque, arg: ?*anyopaque) c_int;
extern "c" fn pthread_detach(thread: ?*anyopaque) c_int;

// `std.Thread.sleep` was removed in zig 0.17. Fall back to libc usleep
// (microsecond precision is plenty for our 50 ms accept-loop tick).
extern "c" fn usleep(microseconds: c_uint) c_int;

fn htons(p: u16) u16 {
    return std.mem.nativeToBig(u16, p);
}
fn ntohs(p: u16) u16 {
    return std.mem.bigToNative(u16, p);
}
fn inAddrLoopback() u32 {
    // 127.0.0.1 in network byte order.
    return std.mem.nativeToBig(u32, 0x7F000001);
}

var server_socket: c_int = -1;
var bound_port: u16 = 0;
var active_client_socket: c_int = -1;

fn spawnAcceptThread() void {
    var thread: ?*anyopaque = null;
    if (pthread_create(&thread, null, acceptLoop, null) == 0) {
        _ = pthread_detach(thread);
    }
}

fn acceptLoop(_: ?*anyopaque) callconv(.c) ?*anyopaque {
    while (server_socket != -1) {
        const client = accept(server_socket, null, null);
        if (client < 0) continue;

        // Read until end-of-headers OR buffer full. OAuth callbacks
        // are tiny — the URL is in the request line — so 4 KiB is
        // generous. Apps doing more elaborate flows would need a
        // streaming read instead.
        var buf: [4096]u8 = undefined;
        const n = read(client, &buf, buf.len);
        if (n <= 0) {
            _ = close(client);
            continue;
        }

        // Parse the request line: METHOD PATH HTTP/x.y\r\n
        const text = buf[0..@intCast(n)];
        const eol = std.mem.indexOf(u8, text, "\r\n") orelse {
            _ = close(client);
            continue;
        };
        const line = text[0..eol];
        const method_end = std.mem.indexOf(u8, line, " ") orelse {
            _ = close(client);
            continue;
        };
        const path_start = method_end + 1;
        const path_end = std.mem.indexOfPos(u8, line, path_start, " ") orelse {
            _ = close(client);
            continue;
        };
        const method = line[0..method_end];
        const path = line[path_start..path_end];

        active_client_socket = client;
        emitRequestEvent(method, path);

        // 5-second timeout: if no respond() comes through, send a
        // default response so we don't keep the socket open forever.
        // This is "good enough" for OAuth callbacks where apps
        // typically respond within milliseconds.
        var waited: u32 = 0;
        const tick_ms: u32 = 50;
        const max_ms: u32 = 5000;
        while (active_client_socket != -1 and waited < max_ms) : (waited += tick_ms) {
            _ = usleep(tick_ms * 1000);
        }
        if (active_client_socket != -1) {
            const default_body = "OK";
            var hdr: [128]u8 = undefined;
            const hdr_text = std.fmt.bufPrint(&hdr,
                "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n",
                .{default_body.len}) catch "HTTP/1.1 200 OK\r\n\r\n";
            _ = send(active_client_socket, hdr_text.ptr, hdr_text.len, 0);
            _ = send(active_client_socket, default_body.ptr, default_body.len, 0);
            _ = close(active_client_socket);
            active_client_socket = -1;
        }
    }
    return null;
}

fn emitRequestEvent(method: []const u8, path: []const u8) void {
    if (builtin.os.tag != .macos) return;
    const macos = @import("macos.zig");
    const webview = macos.getGlobalWebView() orelse return;

    var script: std.ArrayListUnmanaged(u8) = .empty;
    defer script.deinit(std.heap.c_allocator);
    script.appendSlice(std.heap.c_allocator,
        "if (window.dispatchEvent) window.dispatchEvent(new CustomEvent('craft:localServer:request', { detail: { method: '") catch return;
    appendEscaped(&script, method);
    script.appendSlice(std.heap.c_allocator, "', url: '") catch return;
    appendEscaped(&script, path);
    script.appendSlice(std.heap.c_allocator, "' } }));") catch return;
    script.append(std.heap.c_allocator, 0) catch return;

    const NSString = macos.getClass("NSString");
    const js = macos.msgSend1(NSString, "stringWithUTF8String:", @as([*:0]const u8, @ptrCast(script.items.ptr)));
    _ = macos.msgSend2(webview, "evaluateJavaScript:completionHandler:", js, @as(?*anyopaque, null));
}

fn appendEscaped(buf: *std.ArrayListUnmanaged(u8), s: []const u8) void {
    const allocator = std.heap.c_allocator;
    for (s) |b| {
        switch (b) {
            '"' => buf.appendSlice(allocator, "\\\"") catch return,
            '\\' => buf.appendSlice(allocator, "\\\\") catch return,
            '\'' => buf.appendSlice(allocator, "\\'") catch return,
            '\n' => buf.appendSlice(allocator, "\\n") catch return,
            '\r' => buf.appendSlice(allocator, "\\r") catch return,
            else => buf.append(allocator, b) catch return,
        }
    }
}
