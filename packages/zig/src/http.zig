const std = @import("std");

/// HTTP Client API with progress tracking
/// Provides fetch, download, and upload functionality

pub const HttpError = error{
    ConnectionFailed,
    RequestFailed,
    InvalidURL,
    Timeout,
    InvalidResponse,
    TooManyRedirects,
    NetworkError,
};

/// HTTP method
pub const Method = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,

    pub fn toString(self: Method) []const u8 {
        return switch (self) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .PATCH => "PATCH",
            .HEAD => "HEAD",
            .OPTIONS => "OPTIONS",
        };
    }
};

/// HTTP request configuration
pub const RequestConfig = struct {
    method: Method = .GET,
    headers: ?std.StringHashMap([]const u8) = null,
    body: ?[]const u8 = null,
    timeout: u32 = 30000, // ms
    follow_redirects: bool = true,
    max_redirects: u8 = 10,
};

/// HTTP response
pub const Response = struct {
    status: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Response) void {
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
        self.allocator.free(self.body);
    }

    pub fn json(self: *const Response, comptime T: type) !T {
        return try std.json.parseFromSlice(T, self.allocator, self.body, .{});
    }

    pub fn text(self: *const Response) []const u8 {
        return self.body;
    }
};

/// Progress callback
pub const ProgressCallback = *const fn (loaded: u64, total: u64) void;

/// Download configuration
pub const DownloadConfig = struct {
    output_path: []const u8,
    headers: ?std.StringHashMap([]const u8) = null,
    on_progress: ?ProgressCallback = null,
    timeout: u32 = 0, // 0 = no timeout
    resume: bool = false, // Resume partial download
};

/// Upload configuration
pub const UploadConfig = struct {
    method: Method = .POST,
    headers: ?std.StringHashMap([]const u8) = null,
    on_progress: ?ProgressCallback = null,
    timeout: u32 = 0, // 0 = no timeout
};

/// HTTP Client
pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    user_agent: []const u8 = "Craft-HTTP/1.0",

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) HttpClient {
        return HttpClient{
            .allocator = allocator,
        };
    }

    /// Fetch a URL
    pub fn fetch(self: *Self, url: []const u8, config: RequestConfig) !Response {
        // Parse URL
        const uri = try std.Uri.parse(url);

        // Validate scheme
        if (!std.mem.eql(u8, uri.scheme, "http") and !std.mem.eql(u8, uri.scheme, "https")) {
            return HttpError.InvalidURL;
        }

        // In real implementation, would use std.http.Client
        std.debug.print("HTTP {s} {s}\n", .{ config.method.toString(), url });

        // Create client
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        // Prepare request
        const server_header_buffer: []u8 = try self.allocator.alloc(u8, 16 * 1024);
        defer self.allocator.free(server_header_buffer);

        var req = try client.open(.GET, uri, .{
            .server_header_buffer = server_header_buffer,
        });
        defer req.deinit();

        // Add headers
        try req.headers.append("User-Agent", self.user_agent);
        if (config.headers) |headers| {
            var it = headers.iterator();
            while (it.next()) |entry| {
                try req.headers.append(entry.key_ptr.*, entry.value_ptr.*);
            }
        }

        // Send request
        try req.send();

        // Wait for response
        try req.wait();

        // Read body
        const body = try req.reader().readAllAlloc(self.allocator, 100 * 1024 * 1024); // 100MB max

        // Parse response headers
        var response_headers = std.StringHashMap([]const u8).init(self.allocator);
        var header_it = req.response.headers.iterator();
        while (header_it.next()) |header| {
            const key = try self.allocator.dupe(u8, header.name);
            const value = try self.allocator.dupe(u8, header.value);
            try response_headers.put(key, value);
        }

        return Response{
            .status = @intFromEnum(req.response.status),
            .headers = response_headers,
            .body = body,
            .allocator = self.allocator,
        };
    }

    /// Download file with progress tracking
    pub fn download(self: *Self, url: []const u8, config: DownloadConfig) !void {
        std.debug.print("Downloading {s} -> {s}\n", .{ url, config.output_path });

        // Parse URL
        const uri = try std.Uri.parse(url);

        // Create HTTP client
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const server_header_buffer: []u8 = try self.allocator.alloc(u8, 16 * 1024);
        defer self.allocator.free(server_header_buffer);

        var req = try client.open(.GET, uri, .{
            .server_header_buffer = server_header_buffer,
        });
        defer req.deinit();

        // Add headers
        try req.headers.append("User-Agent", self.user_agent);
        if (config.headers) |headers| {
            var it = headers.iterator();
            while (it.next()) |entry| {
                try req.headers.append(entry.key_ptr.*, entry.value_ptr.*);
            }
        }

        // Resume support
        if (config.resume) {
            // Check if partial file exists and add Range header
            const file = std.fs.cwd().openFile(config.output_path, .{}) catch null;
            if (file) |f| {
                const size = try f.getEndPos();
                f.close();
                const range_header = try std.fmt.allocPrint(self.allocator, "bytes={d}-", .{size});
                defer self.allocator.free(range_header);
                try req.headers.append("Range", range_header);
            }
        }

        try req.send();
        try req.wait();

        // Get content length
        const content_length = blk: {
            var it = req.response.headers.iterator();
            while (it.next()) |header| {
                if (std.ascii.eqlIgnoreCase(header.name, "content-length")) {
                    break :blk try std.fmt.parseInt(u64, header.value, 10);
                }
            }
            break :blk 0;
        };

        // Open output file
        const file = try std.fs.cwd().createFile(config.output_path, .{});
        defer file.close();

        // Download with progress
        var buffer: [8192]u8 = undefined;
        var total_read: u64 = 0;

        while (true) {
            const bytes_read = try req.reader().read(&buffer);
            if (bytes_read == 0) break;

            _ = try file.write(buffer[0..bytes_read]);
            total_read += bytes_read;

            // Call progress callback
            if (config.on_progress) |callback| {
                callback(total_read, content_length);
            }
        }
    }

    /// Upload file with progress tracking
    pub fn upload(self: *Self, url: []const u8, file_path: []const u8, config: UploadConfig) !Response {
        std.debug.print("Uploading {s} -> {s}\n", .{ file_path, url });

        // Read file
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const file_content = try file.readToEndAlloc(self.allocator, file_size);
        defer self.allocator.free(file_content);

        // Parse URL
        const uri = try std.Uri.parse(url);

        // Create client
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const server_header_buffer: []u8 = try self.allocator.alloc(u8, 16 * 1024);
        defer self.allocator.free(server_header_buffer);

        var req = try client.open(.POST, uri, .{
            .server_header_buffer = server_header_buffer,
        });
        defer req.deinit();

        // Set content length
        const content_length_str = try std.fmt.allocPrint(self.allocator, "{d}", .{file_size});
        defer self.allocator.free(content_length_str);

        try req.headers.append("User-Agent", self.user_agent);
        try req.headers.append("Content-Length", content_length_str);

        if (config.headers) |headers| {
            var it = headers.iterator();
            while (it.next()) |entry| {
                try req.headers.append(entry.key_ptr.*, entry.value_ptr.*);
            }
        }

        try req.send();

        // Upload with progress
        var total_sent: u64 = 0;
        const chunk_size: usize = 8192;
        var offset: usize = 0;

        while (offset < file_content.len) {
            const end = @min(offset + chunk_size, file_content.len);
            const chunk = file_content[offset..end];

            _ = try req.writer().write(chunk);
            total_sent += chunk.len;
            offset = end;

            // Call progress callback
            if (config.on_progress) |callback| {
                callback(total_sent, file_size);
            }
        }

        try req.finish();
        try req.wait();

        // Read response
        const body = try req.reader().readAllAlloc(self.allocator, 10 * 1024 * 1024);

        // Parse headers
        var response_headers = std.StringHashMap([]const u8).init(self.allocator);
        var header_it = req.response.headers.iterator();
        while (header_it.next()) |header| {
            const key = try self.allocator.dupe(u8, header.name);
            const value = try self.allocator.dupe(u8, header.value);
            try response_headers.put(key, value);
        }

        return Response{
            .status = @intFromEnum(req.response.status),
            .headers = response_headers,
            .body = body,
            .allocator = self.allocator,
        };
    }
};

// Tests
test "http client init" {
    const allocator = std.testing.allocator;
    const client = HttpClient.init(allocator);
    _ = client;
}

test "http method to string" {
    try std.testing.expectEqualStrings("GET", Method.GET.toString());
    try std.testing.expectEqualStrings("POST", Method.POST.toString());
}
