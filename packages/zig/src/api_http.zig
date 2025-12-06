const std = @import("std");

/// HTTP Client API
/// Provides HTTP/HTTPS request functionality
pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    timeout_ms: u64 = 30000, // 30 seconds default

    pub fn init(allocator: std.mem.Allocator) HttpClient {
        return .{ .allocator = allocator };
    }

    pub fn fetch(self: *HttpClient, request: Request) !Response {
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        // Parse URI
        const uri = try std.Uri.parse(request.url);

        // Create request
        var headers = std.http.Headers{ .allocator = self.allocator };
        defer headers.deinit();

        // Add custom headers
        if (request.headers) |req_headers| {
            var it = req_headers.iterator();
            while (it.next()) |entry| {
                try headers.append(entry.key_ptr.*, entry.value_ptr.*);
            }
        }

        // Make request
        var req = try client.open(request.method, uri, headers, .{});
        defer req.deinit();

        // Send body if present
        if (request.body) |body| {
            req.transfer_encoding = .{ .content_length = body.len };
            try req.send(.{});
            try req.writeAll(body);
        } else {
            try req.send(.{});
        }

        try req.finish();
        try req.wait();

        // Read response
        const body_reader = req.reader();
        const body = try body_reader.readAllAlloc(self.allocator, 10 * 1024 * 1024); // 10MB max

        // Extract response headers into a StringHashMap
        var response_headers = std.StringHashMap([]const u8).init(self.allocator);
        var header_it = req.response.headers.iterator();
        var have_headers = false;
        while (header_it.next()) |header| {
            const key = try self.allocator.dupe(u8, header.name);
            const value = try self.allocator.dupe(u8, header.value);
            try response_headers.put(key, value);
            have_headers = true;
        }

        return Response{
            .status = @intFromEnum(req.response.status),
            .headers = if (have_headers) response_headers else blk: {
                response_headers.deinit();
                break :blk null;
            },
            .body = body,
        };
    }

    pub fn download(self: *HttpClient, url: []const u8, dest_path: []const u8, progress_callback: ?*const fn (u64, u64) void) !void {
        const response = try self.fetch(.{
            .url = url,
            .method = .GET,
        });
        defer self.allocator.free(response.body);

        const file = try std.fs.cwd().createFile(dest_path, .{});
        defer file.close();

        try file.writeAll(response.body);

        if (progress_callback) |callback| {
            callback(response.body.len, response.body.len);
        }
    }

    pub fn upload(self: *HttpClient, url: []const u8, file_path: []const u8, progress_callback: ?*const fn (u64, u64) void) !Response {
        // Read file
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const stat = try file.stat();
        const file_contents = try file.readToEndAlloc(self.allocator, stat.size);
        defer self.allocator.free(file_contents);

        if (progress_callback) |callback| {
            callback(file_contents.len, file_contents.len);
        }

        // Upload as POST body
        return try self.fetch(.{
            .url = url,
            .method = .POST,
            .body = file_contents,
        });
    }
};

pub const Request = struct {
    url: []const u8,
    method: std.http.Method = .GET,
    headers: ?std.StringHashMap([]const u8) = null,
    body: ?[]const u8 = null,
    timeout_ms: ?u64 = null,
};

pub const Response = struct {
    status: u32,
    headers: ?std.StringHashMap([]const u8),
    body: []const u8,
};

// Tests
test "HttpClient init" {
    const allocator = std.testing.allocator;
    const client = HttpClient.init(allocator);
    _ = client;
}
