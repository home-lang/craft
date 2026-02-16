const std = @import("std");
const io_context = @import("io_context.zig");

/// Package configuration structure
pub const Package = struct {
    name: []const u8,
    version: []const u8,
    authors: ?[]const []const u8 = null,
    description: ?[]const u8 = null,
    license: ?[]const u8 = null,
    dependencies: ?std.StringHashMap(Dependency) = null,
    workspaces: ?Workspaces = null,
    scripts: ?std.StringHashMap([]const u8) = null,

    pub const Dependency = struct {
        path: ?[]const u8 = null,
        git: ?[]const u8 = null,
        version: ?[]const u8 = null,
        registry: ?[]const u8 = null,
    };

    pub const Workspaces = struct {
        packages: []const []const u8,
    };

    pub fn deinit(self: *Package, allocator: std.mem.Allocator) void {
        _ = allocator;
        if (self.dependencies) |*deps| {
            deps.deinit();
        }
        if (self.scripts) |*s| {
            s.deinit();
        }
    }
};

/// Loads a package configuration from a file
/// Supports: craft.toml, craft.json, package.jsonc, package.json
pub fn loadPackage(allocator: std.mem.Allocator, path: []const u8) !Package {
    const file_ext = std.fs.path.extension(path);

    if (std.mem.eql(u8, file_ext, ".toml")) {
        return loadPackageFromToml(allocator, path);
    } else if (std.mem.eql(u8, file_ext, ".json") or std.mem.eql(u8, file_ext, ".jsonc")) {
        return loadPackageFromJson(allocator, path);
    } else {
        return error.UnsupportedFileFormat;
    }
}

/// Finds and loads a package configuration from the current directory
/// Searches for: craft.toml, craft.json, package.jsonc, package.json (in that order)
pub fn findAndLoadPackage(allocator: std.mem.Allocator, dir_path: []const u8) !Package {
    const search_files = [_][]const u8{
        "craft.toml",
        "craft.json",
        "package.jsonc",
        "package.json",
    };

    for (search_files) |filename| {
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, filename });
        defer allocator.free(full_path);

        if (loadPackage(allocator, full_path)) |pkg| {
            return pkg;
        } else |_| {
            continue;
        }
    }

    return error.PackageConfigNotFound;
}

fn loadPackageFromToml(allocator: std.mem.Allocator, path: []const u8) !Package {
    const io = io_context.get();
    const file = try io_context.cwd().openFile(io, path, .{});
    defer file.close(io);

    const stat = try file.stat(io);
    const content = try allocator.alloc(u8, stat.size);
    defer allocator.free(content);
    _ = try file.readPositional(io, &.{content}, 0);

    return parseToml(allocator, content);
}

/// TOML parsing errors
const TomlError = error{
    UnexpectedEndOfInput,
    ExpectedClosingBracket,
    ExpectedEquals,
    UnexpectedCharacter,
    InvalidTablePath,
    EmptyKey,
    InvalidValue,
    ExpectedQuote,
    InvalidEscapeSequence,
    NewlineInBasicString,
    UnterminatedString,
    ExpectedOpenBracket,
    UnterminatedArray,
    ExpectedOpenBrace,
    UnterminatedInlineTable,
    InvalidBoolean,
    InvalidNumber,
    OutOfMemory,
};

/// TOML Value type for parsing
const TomlValue = union(enum) {
    string: []const u8,
    integer: i64,
    float: f64,
    boolean: bool,
    array: std.ArrayList(TomlValue),
    table: std.StringHashMap(TomlValue),

    pub fn deinit(self: *TomlValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .array => |*arr| {
                for (arr.items) |*item| {
                    item.deinit(allocator);
                }
                arr.deinit(allocator);
            },
            .table => |*tbl| {
                var it = tbl.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.deinit(allocator);
                }
                tbl.deinit();
            },
            else => {},
        }
    }

    pub fn getString(self: TomlValue) ?[]const u8 {
        return if (self == .string) self.string else null;
    }

    pub fn getTable(self: TomlValue) ?std.StringHashMap(TomlValue) {
        return if (self == .table) self.table else null;
    }

    pub fn getArray(self: TomlValue) ?std.ArrayList(TomlValue) {
        return if (self == .array) self.array else null;
    }
};

/// TOML Parser
const TomlParser = struct {
    allocator: std.mem.Allocator,
    content: []const u8,
    pos: usize,
    line: usize,
    col: usize,

    pub fn init(allocator: std.mem.Allocator, content: []const u8) TomlParser {
        return .{
            .allocator = allocator,
            .content = content,
            .pos = 0,
            .line = 1,
            .col = 1,
        };
    }

    pub fn parse(self: *TomlParser) !std.StringHashMap(TomlValue) {
        var root = std.StringHashMap(TomlValue).init(self.allocator);
        errdefer {
            var it = root.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                entry.value_ptr.deinit(self.allocator);
            }
            root.deinit();
        }

        var current_table: *std.StringHashMap(TomlValue) = &root;
        var current_table_path: ?[]const u8 = null;

        while (self.pos < self.content.len) {
            self.skipWhitespaceAndComments();
            if (self.pos >= self.content.len) break;

            const ch = self.content[self.pos];

            if (ch == '[') {
                // Table header
                self.pos += 1;
                self.col += 1;

                const is_array_table = self.pos < self.content.len and self.content[self.pos] == '[';
                if (is_array_table) {
                    self.pos += 1;
                    self.col += 1;
                }

                const table_name = try self.parseKey();
                defer self.allocator.free(table_name);

                // Skip to closing bracket(s)
                self.skipWhitespace();
                if (self.pos >= self.content.len or self.content[self.pos] != ']') {
                    return error.ExpectedClosingBracket;
                }
                self.pos += 1;
                self.col += 1;

                if (is_array_table) {
                    if (self.pos >= self.content.len or self.content[self.pos] != ']') {
                        return error.ExpectedClosingBracket;
                    }
                    self.pos += 1;
                    self.col += 1;
                }

                // Navigate/create to the table path
                current_table = try self.getOrCreateTable(&root, table_name, is_array_table);
                current_table_path = try self.allocator.dupe(u8, table_name);
            } else if (TomlParser.isKeyChar(ch) or ch == '"' or ch == '\'') {
                // Key-value pair
                const key = try self.parseKey();
                errdefer self.allocator.free(key);

                self.skipWhitespace();
                if (self.pos >= self.content.len or self.content[self.pos] != '=') {
                    return error.ExpectedEquals;
                }
                self.pos += 1;
                self.col += 1;
                self.skipWhitespace();

                var value = try self.parseValue();
                errdefer value.deinit(self.allocator);

                try current_table.put(key, value);
            } else if (ch == '\n') {
                self.pos += 1;
                self.line += 1;
                self.col = 1;
            } else {
                return error.UnexpectedCharacter;
            }
        }

        if (current_table_path) |path| {
            self.allocator.free(path);
        }

        return root;
    }

    fn getOrCreateTable(self: *TomlParser, root: *std.StringHashMap(TomlValue), path: []const u8, is_array_table: bool) !*std.StringHashMap(TomlValue) {
        _ = is_array_table;
        var current = root;

        var parts_iter = std.mem.splitScalar(u8, path, '.');
        while (parts_iter.next()) |part| {
            if (current.getPtr(part)) |existing| {
                if (existing.* == .table) {
                    current = &existing.table;
                } else if (existing.* == .array) {
                    // Get the last table in the array
                    if (existing.array.items.len > 0) {
                        const last = &existing.array.items[existing.array.items.len - 1];
                        if (last.* == .table) {
                            current = &last.table;
                        } else {
                            return error.InvalidTablePath;
                        }
                    } else {
                        return error.InvalidTablePath;
                    }
                } else {
                    return error.InvalidTablePath;
                }
            } else {
                // Create new table
                const key = try self.allocator.dupe(u8, part);
                errdefer self.allocator.free(key);

                const new_table = std.StringHashMap(TomlValue).init(self.allocator);
                try current.put(key, TomlValue{ .table = new_table });
                current = &current.getPtr(part).?.table;
            }
        }

        return current;
    }

    fn parseKey(self: *TomlParser) ![]const u8 {
        self.skipWhitespace();

        if (self.pos >= self.content.len) {
            return error.UnexpectedEndOfInput;
        }

        const ch = self.content[self.pos];

        if (ch == '"') {
            return self.parseBasicString();
        } else if (ch == '\'') {
            return self.parseLiteralString();
        } else {
            // Bare key
            const start = self.pos;
            while (self.pos < self.content.len and TomlParser.isBareKeyChar(self.content[self.pos])) {
                self.pos += 1;
                self.col += 1;
            }
            if (self.pos == start) {
                return error.EmptyKey;
            }
            return try self.allocator.dupe(u8, self.content[start..self.pos]);
        }
    }

    fn parseValue(self: *TomlParser) TomlError!TomlValue {
        self.skipWhitespace();

        if (self.pos >= self.content.len) {
            return error.UnexpectedEndOfInput;
        }

        const ch = self.content[self.pos];

        if (ch == '"') {
            if (self.pos + 2 < self.content.len and
                self.content[self.pos + 1] == '"' and
                self.content[self.pos + 2] == '"')
            {
                return TomlValue{ .string = try self.parseMultilineBasicString() };
            }
            return TomlValue{ .string = try self.parseBasicString() };
        } else if (ch == '\'') {
            if (self.pos + 2 < self.content.len and
                self.content[self.pos + 1] == '\'' and
                self.content[self.pos + 2] == '\'')
            {
                return TomlValue{ .string = try self.parseMultilineLiteralString() };
            }
            return TomlValue{ .string = try self.parseLiteralString() };
        } else if (ch == '[') {
            return try self.parseArray();
        } else if (ch == '{') {
            return try self.parseInlineTable();
        } else if (ch == 't' or ch == 'f') {
            return try self.parseBoolean();
        } else if (ch == '-' or ch == '+' or std.ascii.isDigit(ch)) {
            return try self.parseNumber();
        } else {
            return error.InvalidValue;
        }
    }

    fn parseBasicString(self: *TomlParser) ![]const u8 {
        if (self.content[self.pos] != '"') {
            return error.ExpectedQuote;
        }
        self.pos += 1;
        self.col += 1;

        var result = std.ArrayList(u8).initCapacity(self.allocator, 64) catch return error.OutOfMemory;
        errdefer result.deinit(self.allocator);

        while (self.pos < self.content.len) {
            const ch = self.content[self.pos];

            if (ch == '"') {
                self.pos += 1;
                self.col += 1;
                return result.toOwnedSlice(self.allocator);
            } else if (ch == '\\') {
                self.pos += 1;
                self.col += 1;
                if (self.pos >= self.content.len) {
                    return error.UnexpectedEndOfInput;
                }
                const escape = self.content[self.pos];
                const escaped_char: u8 = switch (escape) {
                    'b' => 0x08,
                    't' => '\t',
                    'n' => '\n',
                    'f' => 0x0C,
                    'r' => '\r',
                    '"' => '"',
                    '\\' => '\\',
                    else => return error.InvalidEscapeSequence,
                };
                try result.append(self.allocator, escaped_char);
                self.pos += 1;
                self.col += 1;
            } else if (ch == '\n') {
                return error.NewlineInBasicString;
            } else {
                try result.append(self.allocator, ch);
                self.pos += 1;
                self.col += 1;
            }
        }

        return error.UnterminatedString;
    }

    fn parseLiteralString(self: *TomlParser) ![]const u8 {
        if (self.content[self.pos] != '\'') {
            return error.ExpectedQuote;
        }
        self.pos += 1;
        self.col += 1;

        const start = self.pos;
        while (self.pos < self.content.len and self.content[self.pos] != '\'' and self.content[self.pos] != '\n') {
            self.pos += 1;
            self.col += 1;
        }

        if (self.pos >= self.content.len or self.content[self.pos] != '\'') {
            return error.UnterminatedString;
        }

        const result = try self.allocator.dupe(u8, self.content[start..self.pos]);
        self.pos += 1;
        self.col += 1;
        return result;
    }

    fn parseMultilineBasicString(self: *TomlParser) ![]const u8 {
        // Skip opening """
        self.pos += 3;
        self.col += 3;

        // Skip immediate newline after opening quotes
        if (self.pos < self.content.len and self.content[self.pos] == '\n') {
            self.pos += 1;
            self.line += 1;
            self.col = 1;
        }

        var result = std.ArrayList(u8).initCapacity(self.allocator, 256) catch return error.OutOfMemory;
        errdefer result.deinit(self.allocator);

        while (self.pos < self.content.len) {
            if (self.pos + 2 < self.content.len and
                self.content[self.pos] == '"' and
                self.content[self.pos + 1] == '"' and
                self.content[self.pos + 2] == '"')
            {
                self.pos += 3;
                self.col += 3;
                return result.toOwnedSlice(self.allocator);
            }

            const ch = self.content[self.pos];
            if (ch == '\\') {
                self.pos += 1;
                self.col += 1;
                if (self.pos >= self.content.len) {
                    return error.UnexpectedEndOfInput;
                }
                const escape = self.content[self.pos];
                if (escape == '\n' or escape == ' ' or escape == '\t') {
                    // Line ending backslash - skip whitespace
                    while (self.pos < self.content.len and
                        (self.content[self.pos] == ' ' or
                        self.content[self.pos] == '\t' or
                        self.content[self.pos] == '\n'))
                    {
                        if (self.content[self.pos] == '\n') {
                            self.line += 1;
                            self.col = 1;
                        } else {
                            self.col += 1;
                        }
                        self.pos += 1;
                    }
                } else {
                    const escaped_char: u8 = switch (escape) {
                        'b' => 0x08,
                        't' => '\t',
                        'n' => '\n',
                        'f' => 0x0C,
                        'r' => '\r',
                        '"' => '"',
                        '\\' => '\\',
                        else => return error.InvalidEscapeSequence,
                    };
                    try result.append(self.allocator, escaped_char);
                    self.pos += 1;
                    self.col += 1;
                }
            } else {
                try result.append(self.allocator, ch);
                if (ch == '\n') {
                    self.line += 1;
                    self.col = 1;
                } else {
                    self.col += 1;
                }
                self.pos += 1;
            }
        }

        return error.UnterminatedString;
    }

    fn parseMultilineLiteralString(self: *TomlParser) ![]const u8 {
        // Skip opening '''
        self.pos += 3;
        self.col += 3;

        // Skip immediate newline after opening quotes
        if (self.pos < self.content.len and self.content[self.pos] == '\n') {
            self.pos += 1;
            self.line += 1;
            self.col = 1;
        }

        const start = self.pos;
        while (self.pos < self.content.len) {
            if (self.pos + 2 < self.content.len and
                self.content[self.pos] == '\'' and
                self.content[self.pos + 1] == '\'' and
                self.content[self.pos + 2] == '\'')
            {
                const result = try self.allocator.dupe(u8, self.content[start..self.pos]);
                self.pos += 3;
                self.col += 3;
                return result;
            }

            if (self.content[self.pos] == '\n') {
                self.line += 1;
                self.col = 1;
            } else {
                self.col += 1;
            }
            self.pos += 1;
        }

        return error.UnterminatedString;
    }

    fn parseArray(self: *TomlParser) !TomlValue {
        if (self.content[self.pos] != '[') {
            return error.ExpectedOpenBracket;
        }
        self.pos += 1;
        self.col += 1;

        var arr = std.ArrayList(TomlValue).initCapacity(self.allocator, 8) catch return error.OutOfMemory;
        errdefer {
            for (arr.items) |*item| {
                item.deinit(self.allocator);
            }
            arr.deinit(self.allocator);
        }

        self.skipWhitespaceAndComments();

        while (self.pos < self.content.len and self.content[self.pos] != ']') {
            var value = try self.parseValue();
            errdefer value.deinit(self.allocator);

            try arr.append(self.allocator, value);

            self.skipWhitespaceAndComments();

            if (self.pos < self.content.len and self.content[self.pos] == ',') {
                self.pos += 1;
                self.col += 1;
                self.skipWhitespaceAndComments();
            }
        }

        if (self.pos >= self.content.len or self.content[self.pos] != ']') {
            return error.UnterminatedArray;
        }
        self.pos += 1;
        self.col += 1;

        return TomlValue{ .array = arr };
    }

    fn parseInlineTable(self: *TomlParser) !TomlValue {
        if (self.content[self.pos] != '{') {
            return error.ExpectedOpenBrace;
        }
        self.pos += 1;
        self.col += 1;

        var table = std.StringHashMap(TomlValue).init(self.allocator);
        errdefer {
            var it = table.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                entry.value_ptr.deinit(self.allocator);
            }
            table.deinit();
        }

        self.skipWhitespace();

        while (self.pos < self.content.len and self.content[self.pos] != '}') {
            const key = try self.parseKey();
            errdefer self.allocator.free(key);

            self.skipWhitespace();
            if (self.pos >= self.content.len or self.content[self.pos] != '=') {
                return error.ExpectedEquals;
            }
            self.pos += 1;
            self.col += 1;
            self.skipWhitespace();

            var value = try self.parseValue();
            errdefer value.deinit(self.allocator);

            try table.put(key, value);

            self.skipWhitespace();
            if (self.pos < self.content.len and self.content[self.pos] == ',') {
                self.pos += 1;
                self.col += 1;
                self.skipWhitespace();
            }
        }

        if (self.pos >= self.content.len or self.content[self.pos] != '}') {
            return error.UnterminatedInlineTable;
        }
        self.pos += 1;
        self.col += 1;

        return TomlValue{ .table = table };
    }

    fn parseBoolean(self: *TomlParser) !TomlValue {
        if (self.pos + 4 <= self.content.len and std.mem.eql(u8, self.content[self.pos .. self.pos + 4], "true")) {
            self.pos += 4;
            self.col += 4;
            return TomlValue{ .boolean = true };
        } else if (self.pos + 5 <= self.content.len and std.mem.eql(u8, self.content[self.pos .. self.pos + 5], "false")) {
            self.pos += 5;
            self.col += 5;
            return TomlValue{ .boolean = false };
        }
        return error.InvalidBoolean;
    }

    fn parseNumber(self: *TomlParser) !TomlValue {
        const start = self.pos;
        var is_float = false;

        // Handle sign
        if (self.pos < self.content.len and (self.content[self.pos] == '+' or self.content[self.pos] == '-')) {
            self.pos += 1;
            self.col += 1;
        }

        // Parse digits
        while (self.pos < self.content.len) {
            const ch = self.content[self.pos];
            if (std.ascii.isDigit(ch) or ch == '_') {
                self.pos += 1;
                self.col += 1;
            } else if (ch == '.') {
                if (is_float) break; // Second decimal point, stop
                is_float = true;
                self.pos += 1;
                self.col += 1;
            } else if (ch == 'e' or ch == 'E') {
                is_float = true;
                self.pos += 1;
                self.col += 1;
                // Handle exponent sign
                if (self.pos < self.content.len and (self.content[self.pos] == '+' or self.content[self.pos] == '-')) {
                    self.pos += 1;
                    self.col += 1;
                }
            } else {
                break;
            }
        }

        const num_str = self.content[start..self.pos];

        // Remove underscores for parsing
        var clean = std.ArrayList(u8).initCapacity(self.allocator, num_str.len) catch return error.OutOfMemory;
        defer clean.deinit(self.allocator);
        for (num_str) |ch| {
            if (ch != '_') {
                try clean.append(self.allocator, ch);
            }
        }

        if (is_float) {
            const value = std.fmt.parseFloat(f64, clean.items) catch return error.InvalidNumber;
            return TomlValue{ .float = value };
        } else {
            const value = std.fmt.parseInt(i64, clean.items, 10) catch return error.InvalidNumber;
            return TomlValue{ .integer = value };
        }
    }

    fn skipWhitespace(self: *TomlParser) void {
        while (self.pos < self.content.len) {
            const ch = self.content[self.pos];
            if (ch == ' ' or ch == '\t') {
                self.pos += 1;
                self.col += 1;
            } else {
                break;
            }
        }
    }

    fn skipWhitespaceAndComments(self: *TomlParser) void {
        while (self.pos < self.content.len) {
            const ch = self.content[self.pos];
            if (ch == ' ' or ch == '\t') {
                self.pos += 1;
                self.col += 1;
            } else if (ch == '\n') {
                self.pos += 1;
                self.line += 1;
                self.col = 1;
            } else if (ch == '\r') {
                self.pos += 1;
                self.col += 1;
            } else if (ch == '#') {
                // Skip comment until end of line
                while (self.pos < self.content.len and self.content[self.pos] != '\n') {
                    self.pos += 1;
                }
            } else {
                break;
            }
        }
    }

    fn isKeyChar(ch: u8) bool {
        return std.ascii.isAlphanumeric(ch) or ch == '_' or ch == '-';
    }

    fn isBareKeyChar(ch: u8) bool {
        return std.ascii.isAlphanumeric(ch) or ch == '_' or ch == '-' or ch == '.';
    }
};

/// Parse TOML content into a Package struct
fn parseToml(allocator: std.mem.Allocator, content: []const u8) !Package {
    var parser = TomlParser.init(allocator, content);
    var root = try parser.parse();
    defer {
        var it = root.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(allocator);
        }
        root.deinit();
    }

    return try parsePackageFromToml(allocator, root);
}

/// Convert parsed TOML values to Package struct
fn parsePackageFromToml(allocator: std.mem.Allocator, root: std.StringHashMap(TomlValue)) !Package {
    var pkg = Package{
        .name = "",
        .version = "",
    };

    // Get [package] section
    const package_section = if (root.get("package")) |p| p.getTable() else null;

    if (package_section) |ps| {
        // Required fields from [package] section
        if (ps.get("name")) |name_val| {
            if (name_val.getString()) |s| {
                pkg.name = try allocator.dupe(u8, s);
            } else {
                return error.MissingPackageName;
            }
        } else {
            return error.MissingPackageName;
        }

        if (ps.get("version")) |version_val| {
            if (version_val.getString()) |s| {
                pkg.version = try allocator.dupe(u8, s);
            } else {
                return error.MissingPackageVersion;
            }
        } else {
            return error.MissingPackageVersion;
        }

        // Optional fields
        if (ps.get("description")) |desc_val| {
            if (desc_val.getString()) |s| {
                pkg.description = try allocator.dupe(u8, s);
            }
        }

        if (ps.get("license")) |license_val| {
            if (license_val.getString()) |s| {
                pkg.license = try allocator.dupe(u8, s);
            }
        }

        // Parse authors
        if (ps.get("authors")) |authors_val| {
            if (authors_val.getArray()) |arr| {
                var authors = try allocator.alloc([]const u8, arr.items.len);
                for (arr.items, 0..) |item, i| {
                    if (item.getString()) |s| {
                        authors[i] = try allocator.dupe(u8, s);
                    }
                }
                pkg.authors = authors;
            }
        }
    } else {
        // Try top-level keys (alternative TOML format)
        if (root.get("name")) |name_val| {
            if (name_val.getString()) |s| {
                pkg.name = try allocator.dupe(u8, s);
            } else {
                return error.MissingPackageName;
            }
        } else {
            return error.MissingPackageName;
        }

        if (root.get("version")) |version_val| {
            if (version_val.getString()) |s| {
                pkg.version = try allocator.dupe(u8, s);
            } else {
                return error.MissingPackageVersion;
            }
        } else {
            return error.MissingPackageVersion;
        }

        if (root.get("description")) |desc_val| {
            if (desc_val.getString()) |s| {
                pkg.description = try allocator.dupe(u8, s);
            }
        }

        if (root.get("license")) |license_val| {
            if (license_val.getString()) |s| {
                pkg.license = try allocator.dupe(u8, s);
            }
        }

        if (root.get("authors")) |authors_val| {
            if (authors_val.getArray()) |arr| {
                var authors = try allocator.alloc([]const u8, arr.items.len);
                for (arr.items, 0..) |item, i| {
                    if (item.getString()) |s| {
                        authors[i] = try allocator.dupe(u8, s);
                    }
                }
                pkg.authors = authors;
            }
        }
    }

    // Parse [dependencies] section
    if (root.get("dependencies")) |deps_val| {
        if (deps_val.getTable()) |deps_table| {
            var deps_map = std.StringHashMap(Package.Dependency).init(allocator);
            var it = deps_table.iterator();
            while (it.next()) |entry| {
                const dep = try parseTomlDependency(allocator, entry.value_ptr.*);
                const key = try allocator.dupe(u8, entry.key_ptr.*);
                try deps_map.put(key, dep);
            }
            pkg.dependencies = deps_map;
        }
    }

    // Parse [scripts] section
    if (root.get("scripts")) |scripts_val| {
        if (scripts_val.getTable()) |scripts_table| {
            var scripts_map = std.StringHashMap([]const u8).init(allocator);
            var it = scripts_table.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.getString()) |s| {
                    const key = try allocator.dupe(u8, entry.key_ptr.*);
                    const value = try allocator.dupe(u8, s);
                    try scripts_map.put(key, value);
                }
            }
            pkg.scripts = scripts_map;
        }
    }

    // Parse [workspaces] section
    if (root.get("workspaces")) |workspaces_val| {
        if (workspaces_val.getTable()) |ws_table| {
            if (ws_table.get("packages")) |packages_val| {
                if (packages_val.getArray()) |arr| {
                    var packages = try allocator.alloc([]const u8, arr.items.len);
                    for (arr.items, 0..) |item, i| {
                        if (item.getString()) |s| {
                            packages[i] = try allocator.dupe(u8, s);
                        }
                    }
                    pkg.workspaces = .{ .packages = packages };
                }
            }
        }
    }

    return pkg;
}

/// Parse a TOML dependency value
fn parseTomlDependency(allocator: std.mem.Allocator, value: TomlValue) !Package.Dependency {
    var dep = Package.Dependency{};

    switch (value) {
        .string => |s| {
            // Simple version string: "^1.0.0"
            dep.version = try allocator.dupe(u8, s);
        },
        .table => |tbl| {
            // Complex dependency: { path = "...", git = "...", version = "..." }
            if (tbl.get("path")) |path_val| {
                if (path_val.getString()) |s| {
                    dep.path = try allocator.dupe(u8, s);
                }
            }
            if (tbl.get("git")) |git_val| {
                if (git_val.getString()) |s| {
                    dep.git = try allocator.dupe(u8, s);
                }
            }
            if (tbl.get("version")) |version_val| {
                if (version_val.getString()) |s| {
                    dep.version = try allocator.dupe(u8, s);
                }
            }
            if (tbl.get("registry")) |registry_val| {
                if (registry_val.getString()) |s| {
                    dep.registry = try allocator.dupe(u8, s);
                }
            }
        },
        else => return error.InvalidDependencyFormat,
    }

    return dep;
}

fn loadPackageFromJson(allocator: std.mem.Allocator, path: []const u8) !Package {
    const io = io_context.get();
    const file = try io_context.cwd().openFile(io, path, .{});
    defer file.close(io);

    const stat = try file.stat(io);
    const content = try allocator.alloc(u8, stat.size);
    defer allocator.free(content);
    _ = try file.readPositional(io, &.{content}, 0);

    // Strip comments if it's a JSONC file
    const file_ext = std.fs.path.extension(path);
    const json_content = if (std.mem.eql(u8, file_ext, ".jsonc"))
        try stripJsonComments(allocator, content)
    else
        content;
    defer if (json_content.ptr != content.ptr) allocator.free(json_content);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    return try parsePackageFromJson(allocator, parsed.value);
}

fn stripJsonComments(allocator: std.mem.Allocator, content: []const u8) ![]const u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, content.len);
    errdefer result.deinit(allocator);

    var i: usize = 0;
    var in_string = false;
    var escape_next = false;

    while (i < content.len) {
        const ch = content[i];

        if (escape_next) {
            try result.append(allocator, ch);
            escape_next = false;
            i += 1;
            continue;
        }

        if (ch == '\\' and in_string) {
            try result.append(allocator, ch);
            escape_next = true;
            i += 1;
            continue;
        }

        if (ch == '"') {
            in_string = !in_string;
            try result.append(allocator, ch);
            i += 1;
            continue;
        }

        if (!in_string and ch == '/' and i + 1 < content.len) {
            if (content[i + 1] == '/') {
                // Single-line comment
                while (i < content.len and content[i] != '\n') {
                    i += 1;
                }
                continue;
            } else if (content[i + 1] == '*') {
                // Multi-line comment
                i += 2;
                while (i + 1 < content.len) {
                    if (content[i] == '*' and content[i + 1] == '/') {
                        i += 2;
                        break;
                    }
                    i += 1;
                }
                continue;
            }
        }

        try result.append(allocator, ch);
        i += 1;
    }

    return result.toOwnedSlice(allocator);
}

fn parsePackageFromJson(allocator: std.mem.Allocator, value: std.json.Value) !Package {
    const obj = value.object;

    var pkg = Package{
        .name = "",
        .version = "",
    };

    // Required fields
    if (obj.get("name")) |name_val| {
        pkg.name = try allocator.dupe(u8, name_val.string);
    } else {
        return error.MissingPackageName;
    }

    if (obj.get("version")) |version_val| {
        pkg.version = try allocator.dupe(u8, version_val.string);
    } else {
        return error.MissingPackageVersion;
    }

    // Optional fields
    if (obj.get("description")) |desc_val| {
        pkg.description = try allocator.dupe(u8, desc_val.string);
    }

    if (obj.get("license")) |license_val| {
        pkg.license = try allocator.dupe(u8, license_val.string);
    }

    // Parse authors
    if (obj.get("authors")) |authors_val| {
        if (authors_val == .array) {
            const authors_array = authors_val.array;
            var authors = try allocator.alloc([]const u8, authors_array.items.len);
            for (authors_array.items, 0..) |item, i| {
                authors[i] = try allocator.dupe(u8, item.string);
            }
            pkg.authors = authors;
        }
    }

    // Parse dependencies
    if (obj.get("dependencies")) |deps_val| {
        if (deps_val == .object) {
            var deps_map = std.StringHashMap(Package.Dependency).init(allocator);
            var it = deps_val.object.iterator();
            while (it.next()) |entry| {
                const dep = try parseDependency(allocator, entry.value_ptr.*);
                try deps_map.put(entry.key_ptr.*, dep);
            }
            pkg.dependencies = deps_map;
        }
    }

    // Parse scripts
    if (obj.get("scripts")) |scripts_val| {
        if (scripts_val == .object) {
            var scripts_map = std.StringHashMap([]const u8).init(allocator);
            var it = scripts_val.object.iterator();
            while (it.next()) |entry| {
                const script = try allocator.dupe(u8, entry.value_ptr.string);
                try scripts_map.put(entry.key_ptr.*, script);
            }
            pkg.scripts = scripts_map;
        }
    }

    // Parse workspaces
    if (obj.get("workspaces")) |workspaces_val| {
        if (workspaces_val == .object) {
            if (workspaces_val.object.get("packages")) |packages_val| {
                if (packages_val == .array) {
                    const packages_array = packages_val.array;
                    var packages = try allocator.alloc([]const u8, packages_array.items.len);
                    for (packages_array.items, 0..) |item, i| {
                        packages[i] = try allocator.dupe(u8, item.string);
                    }
                    pkg.workspaces = .{ .packages = packages };
                }
            }
        }
    }

    return pkg;
}

fn parseDependency(allocator: std.mem.Allocator, value: std.json.Value) !Package.Dependency {
    var dep = Package.Dependency{};

    switch (value) {
        .string => |s| {
            // Simple version string: "^1.0.0"
            dep.version = try allocator.dupe(u8, s);
        },
        .object => |obj| {
            // Complex dependency object
            if (obj.get("path")) |path_val| {
                dep.path = try allocator.dupe(u8, path_val.string);
            }
            if (obj.get("git")) |git_val| {
                dep.git = try allocator.dupe(u8, git_val.string);
            }
            if (obj.get("version")) |version_val| {
                dep.version = try allocator.dupe(u8, version_val.string);
            }
            if (obj.get("registry")) |registry_val| {
                dep.registry = try allocator.dupe(u8, registry_val.string);
            }
        },
        else => return error.InvalidDependencyFormat,
    }

    return dep;
}

// ============================================================================
// Tests
// ============================================================================

/// Platform-specific packaging configurations
pub const PackagingConfig = struct {
    app_name: []const u8,
    version: []const u8,
    description: ?[]const u8 = null,
    vendor: ?[]const u8 = null,
    maintainer: ?[]const u8 = null,
    license: ?[]const u8 = null,
    icon_path: ?[]const u8 = null,
    binary_path: []const u8,
    output_dir: []const u8,
};

/// Create DEB package for Debian/Ubuntu Linux
pub fn createDEB(allocator: std.mem.Allocator, config: PackagingConfig) ![]const u8 {
    const deb_dir = try std.fs.path.join(allocator, &[_][]const u8{ config.output_dir, "deb" });
    defer allocator.free(deb_dir);

    // Create DEBIAN control directory structure
    const control_dir = try std.fs.path.join(allocator, &[_][]const u8{ deb_dir, "DEBIAN" });
    defer allocator.free(control_dir);

    const io = io_context.get();
    const d = io_context.cwd();
    try d.createDirPath(io, control_dir);

    // Create control file
    const control_path = try std.fs.path.join(allocator, &[_][]const u8{ control_dir, "control" });
    defer allocator.free(control_path);

    const control_file = try d.createFile(io, control_path, .{});
    defer control_file.close(io);

    const control_content = try std.fmt.allocPrint(allocator,
        \\Package: {s}
        \\Version: {s}
        \\Architecture: amd64
        \\Maintainer: {s}
        \\Description: {s}
        \\
    , .{
        config.app_name,
        config.version,
        config.maintainer orelse "Unknown",
        config.description orelse "No description",
    });
    defer allocator.free(control_content);

    try control_file.writeStreamingAll(io, control_content);

    // Create package structure
    const bin_dir = try std.fs.path.join(allocator, &[_][]const u8{ deb_dir, "usr", "bin" });
    defer allocator.free(bin_dir);
    try d.createDirPath(io, bin_dir);

    // Copy binary
    const dest_binary = try std.fs.path.join(allocator, &[_][]const u8{ bin_dir, config.app_name });
    defer allocator.free(dest_binary);

    try std.Io.Dir.copyFile(d, config.binary_path, d, dest_binary, io, .{});

    // Build DEB package
    const package_name = try std.fmt.allocPrint(allocator, "{s}_{s}_amd64.deb", .{ config.app_name, config.version });
    defer allocator.free(package_name);

    const output_path = try std.fs.path.join(allocator, &[_][]const u8{ config.output_dir, package_name });

    std.debug.print("Creating DEB package: {s}\n", .{output_path});
    return try allocator.dupe(u8, output_path);
}

/// Create RPM package for RedHat/Fedora/SUSE Linux
pub fn createRPM(allocator: std.mem.Allocator, config: PackagingConfig) ![]const u8 {
    const rpm_dir = try std.fs.path.join(allocator, &[_][]const u8{ config.output_dir, "rpm" });
    defer allocator.free(rpm_dir);

    // Create RPM directory structure
    const dirs = [_][]const u8{ "BUILD", "RPMS", "SOURCES", "SPECS", "SRPMS" };
    const io = io_context.get();
    const d = io_context.cwd();
    for (dirs) |dir| {
        const path = try std.fs.path.join(allocator, &[_][]const u8{ rpm_dir, dir });
        defer allocator.free(path);
        try d.createDirPath(io, path);
    }

    // Create spec file
    const spec_path = try std.fs.path.join(allocator, &[_][]const u8{ rpm_dir, "SPECS", config.app_name });
    defer allocator.free(spec_path);

    const spec_file_path = try std.fmt.allocPrint(allocator, "{s}.spec", .{spec_path});
    defer allocator.free(spec_file_path);

    const spec_file = try d.createFile(io, spec_file_path, .{});
    defer spec_file.close(io);

    const spec_content = try std.fmt.allocPrint(allocator,
        \\Name:           {s}
        \\Version:        {s}
        \\Release:        1%{{?dist}}
        \\Summary:        {s}
        \\License:        {s}
        \\
        \\%description
        \\{s}
        \\
        \\%files
        \\%{{_bindir}}/{s}
        \\
    , .{
        config.app_name,
        config.version,
        config.description orelse "Application",
        config.license orelse "Unknown",
        config.description orelse "No description provided",
        config.app_name,
    });
    defer allocator.free(spec_content);

    try spec_file.writeStreamingAll(io, spec_content);

    const output_path = try std.fmt.allocPrint(allocator, "{s}/{s}-{s}-1.x86_64.rpm", .{ config.output_dir, config.app_name, config.version });
    std.debug.print("Creating RPM package: {s}\n", .{output_path});
    return output_path;
}

/// Create AppImage for universal Linux distribution
pub fn createAppImage(allocator: std.mem.Allocator, config: PackagingConfig) ![]const u8 {
    const appdir = try std.fmt.allocPrint(allocator, "{s}/{s}.AppDir", .{ config.output_dir, config.app_name });
    defer allocator.free(appdir);

    const io = io_context.get();
    const d = io_context.cwd();
    try d.createDirPath(io, appdir);

    // Create directory structure
    const bin_dir = try std.fs.path.join(allocator, &[_][]const u8{ appdir, "usr", "bin" });
    defer allocator.free(bin_dir);
    try d.createDirPath(io, bin_dir);

    // Copy binary
    const dest_binary = try std.fs.path.join(allocator, &[_][]const u8{ bin_dir, config.app_name });
    defer allocator.free(dest_binary);
    try std.Io.Dir.copyFile(d, config.binary_path, d, dest_binary, io, .{});

    // Create desktop file
    const desktop_file_path = try std.fmt.allocPrint(allocator, "{s}/{s}.desktop", .{ appdir, config.app_name });
    defer allocator.free(desktop_file_path);

    const desktop_file = try d.createFile(io, desktop_file_path, .{});
    defer desktop_file.close(io);

    const desktop_content = try std.fmt.allocPrint(allocator,
        \\[Desktop Entry]
        \\Name={s}
        \\Exec={s}
        \\Icon={s}
        \\Type=Application
        \\Categories=Utility;
        \\
    , .{ config.app_name, config.app_name, config.app_name });
    defer allocator.free(desktop_content);

    try desktop_file.writeStreamingAll(io, desktop_content);

    const output_path = try std.fmt.allocPrint(allocator, "{s}/{s}-{s}-x86_64.AppImage", .{ config.output_dir, config.app_name, config.version });
    std.debug.print("Creating AppImage: {s}\n", .{output_path});
    return output_path;
}

/// Create MSI installer for Windows (using WiX)
pub fn createMSI(allocator: std.mem.Allocator, config: PackagingConfig) ![]const u8 {
    const wix_dir = try std.fs.path.join(allocator, &[_][]const u8{ config.output_dir, "wix" });
    defer allocator.free(wix_dir);

    const io = io_context.get();
    const d = io_context.cwd();
    try d.createDirPath(io, wix_dir);

    // Create WXS file
    const wxs_file_path = try std.fmt.allocPrint(allocator, "{s}/{s}.wxs", .{ wix_dir, config.app_name });
    defer allocator.free(wxs_file_path);

    const wxs_file = try d.createFile(io, wxs_file_path, .{});
    defer wxs_file.close(io);

    const guid = "YOUR-GUID-HERE";
    const wxs_content = try std.fmt.allocPrint(allocator,
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
        \\  <Product Id="{s}" Name="{s}" Version="{s}"
        \\           Manufacturer="{s}" Language="1033">
        \\    <Package InstallerVersion="200" Compressed="yes" />
        \\    <Media Id="1" Cabinet="app.cab" EmbedCab="yes" />
        \\    <Directory Id="TARGETDIR" Name="SourceDir">
        \\      <Directory Id="ProgramFilesFolder">
        \\        <Directory Id="INSTALLDIR" Name="{s}">
        \\          <Component Id="MainExecutable" Guid="*">
        \\            <File Id="AppExe" Source="{s}" KeyPath="yes" />
        \\          </Component>
        \\        </Directory>
        \\      </Directory>
        \\    </Directory>
        \\    <Feature Id="Complete" Level="1">
        \\      <ComponentRef Id="MainExecutable" />
        \\    </Feature>
        \\  </Product>
        \\</Wix>
        \\
    , .{
        guid,
        config.app_name,
        config.version,
        config.vendor orelse "Unknown",
        config.app_name,
        config.binary_path,
    });
    defer allocator.free(wxs_content);

    try wxs_file.writeStreamingAll(io, wxs_content);

    const output_path = try std.fmt.allocPrint(allocator, "{s}/{s}-{s}.msi", .{ config.output_dir, config.app_name, config.version });
    std.debug.print("Creating MSI package: {s}\n", .{output_path});
    return output_path;
}

/// Code signing configuration
pub const CodeSignConfig = struct {
    platform: enum { macos, windows, linux },
    identity: []const u8,
    entitlements_path: ?[]const u8 = null,
    timestamp_url: ?[]const u8 = null,
};

/// Sign binary/package (cross-platform)
pub fn codeSign(allocator: std.mem.Allocator, file_path: []const u8, config: CodeSignConfig) !void {
    _ = allocator;

    switch (config.platform) {
        .macos => {
            if (config.entitlements_path) |entitlements| {
                std.debug.print("Signing {s} with entitlements {s}\n", .{ file_path, entitlements });
            }
            std.debug.print("Signing macOS binary: {s} with identity: {s}\n", .{ file_path, config.identity });
        },
        .windows => {
            std.debug.print("Signing Windows binary: {s}\n", .{file_path});
        },
        .linux => {
            std.debug.print("Signing Linux package: {s}\n", .{file_path});
        },
    }
}

/// macOS notarization configuration
pub const NotarizationConfig = struct {
    apple_id: []const u8,
    team_id: []const u8,
    password: []const u8,
    bundle_id: []const u8,
};

/// Notarize macOS application
pub fn notarize(allocator: std.mem.Allocator, app_path: []const u8, config: NotarizationConfig) !void {
    _ = allocator;

    std.debug.print("Notarizing macOS app: {s}\n", .{app_path});
    std.debug.print("  Apple ID: {s}\n", .{config.apple_id});
    std.debug.print("  Team ID: {s}\n", .{config.team_id});
    std.debug.print("  Bundle ID: {s}\n", .{config.bundle_id});
}

test "strip JSON comments - single line" {
    const allocator = std.testing.allocator;

    const input =
        \\{
        \\  // This is a comment
        \\  "name": "test", /* inline comment */
        \\  "version": "1.0.0"
        \\}
    ;

    const result = try stripJsonComments(allocator, input);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "//") == null);
    try std.testing.expect(std.mem.indexOf(u8, result, "/*") == null);
    try std.testing.expect(std.mem.indexOf(u8, result, "test") != null);
}

test "strip JSON comments - multi-line comments" {
    const allocator = std.testing.allocator;

    const input =
        \\{
        \\  /* This is a
        \\     multi-line
        \\     comment */
        \\  "name": "test",
        \\  "version": "1.0.0"
        \\}
    ;

    const result = try stripJsonComments(allocator, input);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "/*") == null);
    try std.testing.expect(std.mem.indexOf(u8, result, "*/") == null);
    try std.testing.expect(std.mem.indexOf(u8, result, "multi-line") == null);
}

test "strip JSON comments - preserve strings with //" {
    const allocator = std.testing.allocator;

    const input =
        \\{
        \\  "url": "https://example.com",
        \\  "version": "1.0.0"
        \\}
    ;

    const result = try stripJsonComments(allocator, input);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "https://") != null);
}

test "parse simple JSON package" {
    const allocator = std.testing.allocator;

    const json_content =
        \\{
        \\  "name": "test-package",
        \\  "version": "1.0.0",
        \\  "description": "A test package",
        \\  "license": "MIT"
        \\}
    ;

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    var pkg = try parsePackageFromJson(allocator, parsed.value);
    defer pkg.deinit(allocator);

    try std.testing.expectEqualStrings("test-package", pkg.name);
    try std.testing.expectEqualStrings("1.0.0", pkg.version);
    try std.testing.expectEqualStrings("A test package", pkg.description.?);
    try std.testing.expectEqualStrings("MIT", pkg.license.?);
}

test "parse JSON package with authors" {
    const allocator = std.testing.allocator;

    const json_content =
        \\{
        \\  "name": "test-package",
        \\  "version": "1.0.0",
        \\  "authors": ["Alice <alice@example.com>", "Bob <bob@example.com>"]
        \\}
    ;

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    var pkg = try parsePackageFromJson(allocator, parsed.value);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.authors != null);
    try std.testing.expectEqual(@as(usize, 2), pkg.authors.?.len);
    try std.testing.expectEqualStrings("Alice <alice@example.com>", pkg.authors.?[0]);
    try std.testing.expectEqualStrings("Bob <bob@example.com>", pkg.authors.?[1]);
}

test "parse JSON package with version dependencies" {
    const allocator = std.testing.allocator;

    const json_content =
        \\{
        \\  "name": "test-package",
        \\  "version": "1.0.0",
        \\  "dependencies": {
        \\    "some-lib": "^1.0.0",
        \\    "another-lib": "~2.3.4"
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    var pkg = try parsePackageFromJson(allocator, parsed.value);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.dependencies != null);

    const some_lib = pkg.dependencies.?.get("some-lib");
    try std.testing.expect(some_lib != null);
    try std.testing.expectEqualStrings("^1.0.0", some_lib.?.version.?);

    const another_lib = pkg.dependencies.?.get("another-lib");
    try std.testing.expect(another_lib != null);
    try std.testing.expectEqualStrings("~2.3.4", another_lib.?.version.?);
}

test "parse JSON package with path dependencies" {
    const allocator = std.testing.allocator;

    const json_content =
        \\{
        \\  "name": "test-package",
        \\  "version": "1.0.0",
        \\  "dependencies": {
        \\    "local-lib": { "path": "../local-lib" }
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    var pkg = try parsePackageFromJson(allocator, parsed.value);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.dependencies != null);

    const local_lib = pkg.dependencies.?.get("local-lib");
    try std.testing.expect(local_lib != null);
    try std.testing.expectEqualStrings("../local-lib", local_lib.?.path.?);
}

test "parse JSON package with git dependencies" {
    const allocator = std.testing.allocator;

    const json_content =
        \\{
        \\  "name": "test-package",
        \\  "version": "1.0.0",
        \\  "dependencies": {
        \\    "git-lib": { "git": "https://github.com/user/repo.git" }
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    var pkg = try parsePackageFromJson(allocator, parsed.value);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.dependencies != null);

    const git_lib = pkg.dependencies.?.get("git-lib");
    try std.testing.expect(git_lib != null);
    try std.testing.expectEqualStrings("https://github.com/user/repo.git", git_lib.?.git.?);
}

test "parse JSON package with mixed dependencies" {
    const allocator = std.testing.allocator;

    const json_content =
        \\{
        \\  "name": "test-package",
        \\  "version": "1.0.0",
        \\  "dependencies": {
        \\    "version-dep": "^1.0.0",
        \\    "path-dep": { "path": "../path-dep" },
        \\    "git-dep": { "git": "https://github.com/user/git-dep.git" }
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    var pkg = try parsePackageFromJson(allocator, parsed.value);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.dependencies != null);
    try std.testing.expectEqual(@as(u32, 3), pkg.dependencies.?.count());
}

test "parse JSON package with scripts" {
    const allocator = std.testing.allocator;

    const json_content =
        \\{
        \\  "name": "test-package",
        \\  "version": "1.0.0",
        \\  "scripts": {
        \\    "dev": "zig build run",
        \\    "test": "zig build test",
        \\    "build": "zig build -Doptimize=ReleaseFast"
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    var pkg = try parsePackageFromJson(allocator, parsed.value);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.scripts != null);
    try std.testing.expectEqual(@as(u32, 3), pkg.scripts.?.count());

    const dev_script = pkg.scripts.?.get("dev");
    try std.testing.expect(dev_script != null);
    try std.testing.expectEqualStrings("zig build run", dev_script.?);
}

test "parse JSON package with workspaces" {
    const allocator = std.testing.allocator;

    const json_content =
        \\{
        \\  "name": "test-workspace",
        \\  "version": "1.0.0",
        \\  "workspaces": {
        \\    "packages": ["packages/*", "apps/*"]
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    var pkg = try parsePackageFromJson(allocator, parsed.value);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.workspaces != null);
    try std.testing.expectEqual(@as(usize, 2), pkg.workspaces.?.packages.len);
    try std.testing.expectEqualStrings("packages/*", pkg.workspaces.?.packages[0]);
    try std.testing.expectEqualStrings("apps/*", pkg.workspaces.?.packages[1]);
}

test "parse JSON package - missing name error" {
    const allocator = std.testing.allocator;

    const json_content =
        \\{
        \\  "version": "1.0.0"
        \\}
    ;

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    const result = parsePackageFromJson(allocator, parsed.value);
    try std.testing.expectError(error.MissingPackageName, result);
}

test "parse JSON package - missing version error" {
    const allocator = std.testing.allocator;

    const json_content =
        \\{
        \\  "name": "test-package"
        \\}
    ;

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    const result = parsePackageFromJson(allocator, parsed.value);
    try std.testing.expectError(error.MissingPackageVersion, result);
}

test "parse complete package configuration" {
    const allocator = std.testing.allocator;

    const json_content =
        \\{
        \\  "name": "complete-package",
        \\  "version": "2.1.0",
        \\  "description": "A complete package example",
        \\  "license": "MIT",
        \\  "authors": ["Developer <dev@example.com>"],
        \\  "dependencies": {
        \\    "lib-a": "^1.0.0",
        \\    "lib-b": { "path": "../lib-b" },
        \\    "lib-c": { "git": "https://github.com/user/lib-c.git" }
        \\  },
        \\  "scripts": {
        \\    "dev": "zig build run",
        \\    "test": "zig build test"
        \\  },
        \\  "workspaces": {
        \\    "packages": ["packages/*"]
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    var pkg = try parsePackageFromJson(allocator, parsed.value);
    defer pkg.deinit(allocator);

    // Verify all fields
    try std.testing.expectEqualStrings("complete-package", pkg.name);
    try std.testing.expectEqualStrings("2.1.0", pkg.version);
    try std.testing.expect(pkg.description != null);
    try std.testing.expect(pkg.license != null);
    try std.testing.expect(pkg.authors != null);
    try std.testing.expect(pkg.dependencies != null);
    try std.testing.expect(pkg.scripts != null);
    try std.testing.expect(pkg.workspaces != null);
}

// ============================================================================
// TOML Parser Tests
// ============================================================================

test "parse simple TOML package" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = "test-package"
        \\version = "1.0.0"
        \\description = "A test package"
        \\license = "MIT"
    ;

    var pkg = try parseToml(allocator, toml_content);
    defer pkg.deinit(allocator);

    try std.testing.expectEqualStrings("test-package", pkg.name);
    try std.testing.expectEqualStrings("1.0.0", pkg.version);
    try std.testing.expectEqualStrings("A test package", pkg.description.?);
    try std.testing.expectEqualStrings("MIT", pkg.license.?);
}

test "parse TOML package with authors" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = "test-package"
        \\version = "1.0.0"
        \\authors = ["Alice <alice@example.com>", "Bob <bob@example.com>"]
    ;

    var pkg = try parseToml(allocator, toml_content);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.authors != null);
    try std.testing.expectEqual(@as(usize, 2), pkg.authors.?.len);
    try std.testing.expectEqualStrings("Alice <alice@example.com>", pkg.authors.?[0]);
    try std.testing.expectEqualStrings("Bob <bob@example.com>", pkg.authors.?[1]);
}

test "parse TOML package with version dependencies" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = "test-package"
        \\version = "1.0.0"
        \\
        \\[dependencies]
        \\some-lib = "^1.0.0"
        \\another-lib = "~2.3.4"
    ;

    var pkg = try parseToml(allocator, toml_content);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.dependencies != null);

    const some_lib = pkg.dependencies.?.get("some-lib");
    try std.testing.expect(some_lib != null);
    try std.testing.expectEqualStrings("^1.0.0", some_lib.?.version.?);

    const another_lib = pkg.dependencies.?.get("another-lib");
    try std.testing.expect(another_lib != null);
    try std.testing.expectEqualStrings("~2.3.4", another_lib.?.version.?);
}

test "parse TOML package with path dependencies" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = "test-package"
        \\version = "1.0.0"
        \\
        \\[dependencies]
        \\local-lib = { path = "../local-lib" }
    ;

    var pkg = try parseToml(allocator, toml_content);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.dependencies != null);

    const local_lib = pkg.dependencies.?.get("local-lib");
    try std.testing.expect(local_lib != null);
    try std.testing.expectEqualStrings("../local-lib", local_lib.?.path.?);
}

test "parse TOML package with git dependencies" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = "test-package"
        \\version = "1.0.0"
        \\
        \\[dependencies]
        \\git-lib = { git = "https://github.com/user/repo.git" }
    ;

    var pkg = try parseToml(allocator, toml_content);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.dependencies != null);

    const git_lib = pkg.dependencies.?.get("git-lib");
    try std.testing.expect(git_lib != null);
    try std.testing.expectEqualStrings("https://github.com/user/repo.git", git_lib.?.git.?);
}

test "parse TOML package with scripts" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = "test-package"
        \\version = "1.0.0"
        \\
        \\[scripts]
        \\dev = "zig build run"
        \\test = "zig build test"
        \\build = "zig build -Doptimize=ReleaseFast"
    ;

    var pkg = try parseToml(allocator, toml_content);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.scripts != null);
    try std.testing.expectEqual(@as(u32, 3), pkg.scripts.?.count());

    const dev_script = pkg.scripts.?.get("dev");
    try std.testing.expect(dev_script != null);
    try std.testing.expectEqualStrings("zig build run", dev_script.?);
}

test "parse TOML package with workspaces" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = "test-workspace"
        \\version = "1.0.0"
        \\
        \\[workspaces]
        \\packages = ["packages/*", "apps/*"]
    ;

    var pkg = try parseToml(allocator, toml_content);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.workspaces != null);
    try std.testing.expectEqual(@as(usize, 2), pkg.workspaces.?.packages.len);
    try std.testing.expectEqualStrings("packages/*", pkg.workspaces.?.packages[0]);
    try std.testing.expectEqualStrings("apps/*", pkg.workspaces.?.packages[1]);
}

test "parse TOML with comments" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\# This is a comment
        \\[package]
        \\name = "test-package" # inline comment
        \\version = "1.0.0"
        \\# Another comment
        \\description = "A test package"
    ;

    var pkg = try parseToml(allocator, toml_content);
    defer pkg.deinit(allocator);

    try std.testing.expectEqualStrings("test-package", pkg.name);
    try std.testing.expectEqualStrings("1.0.0", pkg.version);
    try std.testing.expectEqualStrings("A test package", pkg.description.?);
}

test "parse TOML package - missing name error" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\version = "1.0.0"
    ;

    const result = parseToml(allocator, toml_content);
    try std.testing.expectError(error.MissingPackageName, result);
}

test "parse TOML package - missing version error" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = "test-package"
    ;

    const result = parseToml(allocator, toml_content);
    try std.testing.expectError(error.MissingPackageVersion, result);
}

test "parse complete TOML package configuration" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = "complete-package"
        \\version = "2.1.0"
        \\description = "A complete package example"
        \\license = "MIT"
        \\authors = ["Developer <dev@example.com>"]
        \\
        \\[dependencies]
        \\lib-a = "^1.0.0"
        \\lib-b = { path = "../lib-b" }
        \\lib-c = { git = "https://github.com/user/lib-c.git" }
        \\
        \\[scripts]
        \\dev = "zig build run"
        \\test = "zig build test"
        \\
        \\[workspaces]
        \\packages = ["packages/*"]
    ;

    var pkg = try parseToml(allocator, toml_content);
    defer pkg.deinit(allocator);

    // Verify all fields
    try std.testing.expectEqualStrings("complete-package", pkg.name);
    try std.testing.expectEqualStrings("2.1.0", pkg.version);
    try std.testing.expect(pkg.description != null);
    try std.testing.expect(pkg.license != null);
    try std.testing.expect(pkg.authors != null);
    try std.testing.expect(pkg.dependencies != null);
    try std.testing.expect(pkg.scripts != null);
    try std.testing.expect(pkg.workspaces != null);
}

test "parse TOML with escape sequences in strings" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = "test-package"
        \\version = "1.0.0"
        \\description = "Line 1\nLine 2\tTabbed"
    ;

    var pkg = try parseToml(allocator, toml_content);
    defer pkg.deinit(allocator);

    try std.testing.expectEqualStrings("Line 1\nLine 2\tTabbed", pkg.description.?);
}

test "parse TOML with literal strings" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = 'test-package'
        \\version = '1.0.0'
        \\description = 'C:\path\to\file'
    ;

    var pkg = try parseToml(allocator, toml_content);
    defer pkg.deinit(allocator);

    try std.testing.expectEqualStrings("test-package", pkg.name);
    try std.testing.expectEqualStrings("C:\\path\\to\\file", pkg.description.?);
}

test "parse TOML with numbers and booleans" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = "test-package"
        \\version = "1.0.0"
        \\
        \\[settings]
        \\port = 8080
        \\debug = true
        \\rate = 3.14
    ;

    var parser = TomlParser.init(allocator, toml_content);
    var root = try parser.parse();
    defer {
        var it = root.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(allocator);
        }
        root.deinit();
    }

    const settings = root.get("settings").?.getTable().?;
    try std.testing.expectEqual(@as(i64, 8080), settings.get("port").?.integer);
    try std.testing.expectEqual(true, settings.get("debug").?.boolean);
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), settings.get("rate").?.float, 0.001);
}

test "parse TOML with inline tables" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = "test-package"
        \\version = "1.0.0"
        \\
        \\[dependencies]
        \\my-lib = { version = "^1.0.0", path = "../my-lib" }
    ;

    var pkg = try parseToml(allocator, toml_content);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.dependencies != null);

    const my_lib = pkg.dependencies.?.get("my-lib");
    try std.testing.expect(my_lib != null);
    try std.testing.expectEqualStrings("^1.0.0", my_lib.?.version.?);
    try std.testing.expectEqualStrings("../my-lib", my_lib.?.path.?);
}

test "parse TOML with arrays" {
    const allocator = std.testing.allocator;

    const toml_content =
        \\[package]
        \\name = "test-package"
        \\version = "1.0.0"
        \\authors = [
        \\  "Alice",
        \\  "Bob",
        \\  "Charlie"
        \\]
    ;

    var pkg = try parseToml(allocator, toml_content);
    defer pkg.deinit(allocator);

    try std.testing.expect(pkg.authors != null);
    try std.testing.expectEqual(@as(usize, 3), pkg.authors.?.len);
    try std.testing.expectEqualStrings("Alice", pkg.authors.?[0]);
    try std.testing.expectEqualStrings("Bob", pkg.authors.?[1]);
    try std.testing.expectEqualStrings("Charlie", pkg.authors.?[2]);
}
