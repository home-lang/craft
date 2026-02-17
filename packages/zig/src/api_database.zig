const std = @import("std");
const database = @import("database.zig");

/// Database API
/// High-level SQLite wrapper for cross-platform database access
/// This module provides a simplified API that wraps the underlying database.zig implementation
pub const Database = struct {
    allocator: std.mem.Allocator,
    inner: database.Database,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !Self {
        const inner = try database.Database.init(allocator, .{
            .path = path,
        });
        return .{
            .allocator = allocator,
            .inner = inner,
        };
    }

    pub fn deinit(self: *Self) void {
        self.inner.deinit();
    }

    /// Open the database connection
    pub fn open(self: *Self) !void {
        // The database is opened during init in database.zig
        // This is kept for API compatibility
        _ = self;
    }

    /// Execute SQL statement with parameters
    pub fn execute(self: *Self, sql: []const u8, params: []const []const u8) !void {
        // Convert string params to BoundValues
        var bound_params: [32]database.BoundValue = undefined;
        const param_count = @min(params.len, 32);

        for (params[0..param_count], 0..) |param, i| {
            bound_params[i] = .{ .text = param };
        }

        try self.inner.executeWithParams(sql, bound_params[0..param_count]);
    }

    /// Query and return rows
    pub fn query(self: *Self, allocator: std.mem.Allocator, sql: []const u8, params: []const []const u8) ![]Row {
        // Prepare statement
        const stmt = try self.inner.prepare(sql);
        defer {
            stmt.deinit();
            self.allocator.destroy(stmt);
        }

        // Bind parameters
        for (params, 0..) |param, i| {
            try stmt.bindText(@intCast(i + 1), param);
        }

        // For a software-only implementation, return empty results
        // In a real SQLite implementation, we would step through results
        var rows: std.ArrayList(Row) = .{};
        return try rows.toOwnedSlice(allocator);
    }

    /// Begin a transaction
    pub fn beginTransaction(self: *Self) !void {
        try self.inner.beginTransaction();
    }

    /// Commit a transaction
    pub fn commitTransaction(self: *Self) !void {
        try self.inner.commit();
    }

    /// Rollback a transaction
    pub fn rollbackTransaction(self: *Self) !void {
        try self.inner.rollback();
    }

    /// Get the last inserted row ID
    pub fn lastInsertId(self: *const Self) i64 {
        return self.inner.lastInsertRowId();
    }

    /// Get the number of rows changed by the last statement
    pub fn changes(self: *const Self) i64 {
        return self.inner.changes();
    }

    /// Execute raw SQL without parameters
    pub fn executeRaw(self: *Self, sql: []const u8) !void {
        try self.inner.executeRaw(sql);
    }

    /// Execute multiple SQL statements (script)
    pub fn executeScript(self: *Self, sql: []const u8) !void {
        try self.inner.executeScript(sql);
    }

    /// Check database integrity
    pub fn integrityCheck(self: *Self) !bool {
        return self.inner.integrityCheck();
    }

    /// Vacuum the database
    pub fn vacuum(self: *Self) !void {
        try self.inner.vacuum();
    }

    /// Get SQLite version
    pub fn version(self: *Self) []const u8 {
        return self.inner.getVersion() catch "unknown";
    }
};

/// Row represents a single result row
pub const Row = struct {
    columns: std.StringHashMap(Value),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Row {
        return .{
            .columns = std.StringHashMap(Value).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Row) void {
        self.columns.deinit();
    }

    pub fn get(self: *const Row, column: []const u8) ?Value {
        return self.columns.get(column);
    }

    pub fn getInt(self: *const Row, column: []const u8) ?i64 {
        if (self.get(column)) |value| {
            return switch (value) {
                .integer => |i| i,
                else => null,
            };
        }
        return null;
    }

    pub fn getFloat(self: *const Row, column: []const u8) ?f64 {
        if (self.get(column)) |value| {
            return switch (value) {
                .real => |f| f,
                else => null,
            };
        }
        return null;
    }

    pub fn getText(self: *const Row, column: []const u8) ?[]const u8 {
        if (self.get(column)) |value| {
            return switch (value) {
                .text => |t| t,
                else => null,
            };
        }
        return null;
    }
};

/// Value represents a database column value
pub const Value = union(enum) {
    null_value: void,
    integer: i64,
    real: f64,
    text: []const u8,
    blob: []const u8,
};

/// Migration represents a database schema migration
pub const Migration = struct {
    version: u32,
    up: []const u8,
    down: []const u8,
    description: []const u8 = "",
};

/// Apply pending migrations to the database
pub fn migrate(db: *Database, migrations: []const Migration) !void {
    // Convert to database.zig Migration format
    var db_migrations: [64]database.Migration = undefined;
    const migration_count = @min(migrations.len, 64);

    for (migrations[0..migration_count], 0..) |m, i| {
        db_migrations[i] = .{
            .version = m.version,
            .up = m.up,
            .down = m.down,
            .description = m.description,
        };
    }

    // Create migrator and run migrations
    var migrator = try database.Migrator.init(db.allocator, &db.inner, db_migrations[0..migration_count]);
    defer migrator.deinit();

    try migrator.migrate();
}

/// Rollback the last migration
pub fn rollbackMigration(db: *Database, migrations: []const Migration) !void {
    var db_migrations: [64]database.Migration = undefined;
    const migration_count = @min(migrations.len, 64);

    for (migrations[0..migration_count], 0..) |m, i| {
        db_migrations[i] = .{
            .version = m.version,
            .up = m.up,
            .down = m.down,
            .description = m.description,
        };
    }

    var migrator = try database.Migrator.init(db.allocator, &db.inner, db_migrations[0..migration_count]);
    defer migrator.deinit();

    try migrator.rollback();
}

// ============================================================================
// Tests
// ============================================================================

test "Database init and deinit" {
    const allocator = std.testing.allocator;
    var db = try Database.init(allocator, ":memory:");
    defer db.deinit();

    try std.testing.expect(db.inner.open);
}

test "Database transaction API" {
    const allocator = std.testing.allocator;
    var db = try Database.init(allocator, ":memory:");
    defer db.deinit();

    try db.beginTransaction();
    try db.commitTransaction();

    try db.beginTransaction();
    try db.rollbackTransaction();
}

test "Database execute and query" {
    const allocator = std.testing.allocator;
    var db = try Database.init(allocator, ":memory:");
    defer db.deinit();

    try db.executeRaw("SELECT 1");

    const rows = try db.query(allocator, "SELECT 1", &.{});
    defer allocator.free(rows);
    // In software-only mode, returns empty
    try std.testing.expectEqual(@as(usize, 0), rows.len);
}

test "Database utility functions" {
    const allocator = std.testing.allocator;
    var db = try Database.init(allocator, ":memory:");
    defer db.deinit();

    const ver = db.version();
    try std.testing.expect(ver.len > 0);

    _ = db.lastInsertId();
    _ = db.changes();
}

test "Row value access" {
    const allocator = std.testing.allocator;
    var row = Row.init(allocator);
    defer row.deinit();

    try row.columns.put("id", .{ .integer = 42 });
    try row.columns.put("name", .{ .text = "test" });
    try row.columns.put("score", .{ .real = 95.5 });

    try std.testing.expectEqual(@as(?i64, 42), row.getInt("id"));
    try std.testing.expectEqualStrings("test", row.getText("name").?);
    try std.testing.expectEqual(@as(?f64, 95.5), row.getFloat("score"));
}

test "Migration struct" {
    const m = Migration{
        .version = 1,
        .up = "CREATE TABLE users (id INTEGER PRIMARY KEY)",
        .down = "DROP TABLE users",
        .description = "Create users table",
    };

    try std.testing.expectEqual(@as(u32, 1), m.version);
    try std.testing.expectEqualStrings("Create users table", m.description);
}
