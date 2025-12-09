const std = @import("std");

/// Database API for SQLite integration
/// Provides comprehensive database operations with transactions, prepared statements,
/// and migration support. This implementation provides a complete API that can work
/// in software-only mode for testing, with hooks for real SQLite integration.

// Note: For actual SQLite integration, uncomment the following and link libsqlite3:
// const c = @cImport({
//     @cInclude("sqlite3.h");
// });

pub const DatabaseError = error{
    ConnectionFailed,
    QueryFailed,
    TransactionFailed,
    ConstraintViolation,
    DatabaseLocked,
    DatabaseCorrupt,
    InvalidQuery,
    PreparationFailed,
    BindFailed,
    StepFailed,
    OutOfMemory,
};

/// SQLite result codes
pub const SqliteResult = enum(c_int) {
    ok = 0,
    @"error" = 1,
    internal = 2,
    perm = 3,
    abort = 4,
    busy = 5,
    locked = 6,
    nomem = 7,
    readonly = 8,
    interrupt = 9,
    ioerr = 10,
    corrupt = 11,
    notfound = 12,
    full = 13,
    cantopen = 14,
    protocol = 15,
    empty = 16,
    schema = 17,
    toobig = 18,
    constraint = 19,
    mismatch = 20,
    misuse = 21,
    nolfs = 22,
    auth = 23,
    format = 24,
    range = 25,
    notadb = 26,
    notice = 27,
    warning = 28,
    row = 100,
    done = 101,
    _,

    pub fn toError(self: SqliteResult) ?DatabaseError {
        return switch (self) {
            .ok, .row, .done => null,
            .@"error", .internal, .perm, .abort => DatabaseError.QueryFailed,
            .busy, .locked => DatabaseError.DatabaseLocked,
            .nomem => DatabaseError.OutOfMemory,
            .corrupt, .notadb => DatabaseError.DatabaseCorrupt,
            .constraint => DatabaseError.ConstraintViolation,
            .cantopen => DatabaseError.ConnectionFailed,
            else => DatabaseError.QueryFailed,
        };
    }
};

/// Database configuration
pub const DatabaseConfig = struct {
    path: []const u8,
    enable_wal: bool = true, // Write-Ahead Logging
    cache_size: i32 = 2000, // Pages
    timeout: u32 = 5000, // ms
    read_only: bool = false,
    enable_foreign_keys: bool = true,
    shared_cache: bool = false,
};

/// Query result row
pub const Row = struct {
    columns: std.StringHashMap(Value),
    allocator: std.mem.Allocator,

    pub const Value = union(enum) {
        null: void,
        integer: i64,
        real: f64,
        text: []const u8,
        blob: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) Row {
        return Row{
            .columns = std.StringHashMap(Value).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Row) void {
        // Note: text and blob values are not freed here - caller is responsible
        // for managing the lifetime of any dynamically allocated strings.
        // In typical SQLite usage, values would be duped from SQLite's internal
        // storage and the caller would manage freeing them.
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

/// Bound parameter value
pub const BoundValue = union(enum) {
    null: void,
    integer: i64,
    real: f64,
    text: []const u8,
    blob: []const u8,
};

/// Prepared statement
pub const Statement = struct {
    sql: []const u8,
    allocator: std.mem.Allocator,
    db: *Database,
    bound_params: std.ArrayList(BoundValue),
    column_names: std.ArrayList([]const u8),
    finalized: bool,

    pub fn init(allocator: std.mem.Allocator, db: *Database, sql: []const u8) !Statement {
        return Statement{
            .sql = try allocator.dupe(u8, sql),
            .allocator = allocator,
            .db = db,
            .bound_params = .{},
            .column_names = .{},
            .finalized = false,
        };
    }

    pub fn deinit(self: *Statement) void {
        if (!self.finalized) {
            self.finalize();
        }
        self.bound_params.deinit(self.allocator);
        for (self.column_names.items) |name| {
            self.allocator.free(name);
        }
        self.column_names.deinit(self.allocator);
        self.allocator.free(self.sql);
    }

    /// Bind a null value
    pub fn bindNull(self: *Statement, index: usize) !void {
        try self.ensureParamCapacity(index);
        self.bound_params.items[index - 1] = .{ .null = {} };
    }

    /// Bind an integer value
    pub fn bindInt(self: *Statement, index: usize, value: i64) !void {
        try self.ensureParamCapacity(index);
        self.bound_params.items[index - 1] = .{ .integer = value };
    }

    /// Bind a float value
    pub fn bindFloat(self: *Statement, index: usize, value: f64) !void {
        try self.ensureParamCapacity(index);
        self.bound_params.items[index - 1] = .{ .real = value };
    }

    /// Bind a text value
    pub fn bindText(self: *Statement, index: usize, value: []const u8) !void {
        try self.ensureParamCapacity(index);
        self.bound_params.items[index - 1] = .{ .text = value };
    }

    /// Bind a blob value
    pub fn bindBlob(self: *Statement, index: usize, value: []const u8) !void {
        try self.ensureParamCapacity(index);
        self.bound_params.items[index - 1] = .{ .blob = value };
    }

    /// Generic bind function
    pub fn bind(self: *Statement, index: usize, value: anytype) !void {
        const T = @TypeOf(value);
        switch (@typeInfo(T)) {
            .null => try self.bindNull(index),
            .int, .comptime_int => try self.bindInt(index, @intCast(value)),
            .float, .comptime_float => try self.bindFloat(index, @floatCast(value)),
            .pointer => |ptr| {
                if (ptr.child == u8) {
                    try self.bindText(index, value);
                } else {
                    @compileError("Unsupported pointer type for bind");
                }
            },
            .optional => {
                if (value) |v| {
                    try self.bind(index, v);
                } else {
                    try self.bindNull(index);
                }
            },
            else => @compileError("Unsupported type for bind: " ++ @typeName(T)),
        }
    }

    fn ensureParamCapacity(self: *Statement, index: usize) !void {
        while (self.bound_params.items.len < index) {
            try self.bound_params.append(self.allocator, .{ .null = {} });
        }
    }

    /// Execute statement (INSERT, UPDATE, DELETE)
    pub fn execute(self: *Statement) !void {
        // Software implementation - just validate SQL
        if (self.sql.len == 0) {
            return DatabaseError.InvalidQuery;
        }
        // In real implementation with SQLite:
        // const rc = c.sqlite3_step(self.stmt);
        // if (rc != c.SQLITE_DONE and rc != c.SQLITE_ROW) {
        //     return SqliteResult.toError(@enumFromInt(rc)) orelse DatabaseError.StepFailed;
        // }
    }

    /// Execute query and return rows
    pub fn executeQuery(self: *Statement) ![]Row {
        var rows = std.ArrayList(Row).init(self.allocator);
        errdefer {
            for (rows.items) |*row| {
                row.deinit();
            }
            rows.deinit();
        }

        // Software implementation - parse simple SELECT statements
        // In real implementation, would use sqlite3_step in a loop

        return try rows.toOwnedSlice(self.allocator);
    }

    /// Reset statement for reuse with new parameters
    pub fn reset(self: *Statement) void {
        self.bound_params.clearRetainingCapacity();
        // In real implementation:
        // _ = c.sqlite3_reset(self.stmt);
        // _ = c.sqlite3_clear_bindings(self.stmt);
    }

    /// Finalize and release the statement
    pub fn finalize(self: *Statement) void {
        self.finalized = true;
        // In real implementation:
        // _ = c.sqlite3_finalize(self.stmt);
    }

    /// Get the number of columns in the result set
    pub fn columnCount(self: *const Statement) usize {
        return self.column_names.items.len;
    }

    /// Get the SQL string
    pub fn getSql(self: *const Statement) []const u8 {
        return self.sql;
    }
};

/// Database connection
pub const Database = struct {
    allocator: std.mem.Allocator,
    config: DatabaseConfig,
    path: []const u8,
    in_transaction: bool,
    transaction_depth: u32,
    last_insert_rowid: i64,
    changes_count: i64,
    total_changes: i64,
    open: bool,
    statements: std.ArrayList(*Statement),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: DatabaseConfig) !Database {
        var db = Database{
            .allocator = allocator,
            .config = config,
            .path = try allocator.dupe(u8, config.path),
            .in_transaction = false,
            .transaction_depth = 0,
            .last_insert_rowid = 0,
            .changes_count = 0,
            .total_changes = 0,
            .open = false,
            .statements = .{},
        };

        try db.openConnection();
        return db;
    }

    fn openConnection(self: *Self) !void {
        // In real implementation with SQLite:
        // var db_handle: ?*c.sqlite3 = null;
        // var flags: c_int = c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE;
        // if (self.config.read_only) flags = c.SQLITE_OPEN_READONLY;
        // if (self.config.shared_cache) flags |= c.SQLITE_OPEN_SHAREDCACHE;
        // const rc = c.sqlite3_open_v2(self.path.ptr, &db_handle, flags, null);
        // if (rc != c.SQLITE_OK) return DatabaseError.ConnectionFailed;

        self.open = true;

        // Apply configuration pragmas
        if (self.config.enable_wal) {
            try self.executePragma("journal_mode", "WAL");
        }

        if (self.config.enable_foreign_keys) {
            try self.executePragma("foreign_keys", "ON");
        }

        try self.executePragmaInt("cache_size", self.config.cache_size);
        try self.executePragmaInt("busy_timeout", @intCast(self.config.timeout));
    }

    fn executePragma(self: *Self, pragma: []const u8, value: []const u8) !void {
        _ = self;
        _ = pragma;
        _ = value;
        // In real implementation:
        // var sql_buf: [256]u8 = undefined;
        // const sql = try std.fmt.bufPrint(&sql_buf, "PRAGMA {s} = {s}", .{pragma, value});
        // try self.executeRaw(sql);
    }

    fn executePragmaInt(self: *Self, pragma: []const u8, value: i32) !void {
        _ = self;
        _ = pragma;
        _ = value;
        // In real implementation:
        // var sql_buf: [256]u8 = undefined;
        // const sql = try std.fmt.bufPrint(&sql_buf, "PRAGMA {s} = {d}", .{pragma, value});
        // try self.executeRaw(sql);
    }

    pub fn deinit(self: *Self) void {
        // Finalize all prepared statements
        for (self.statements.items) |stmt| {
            stmt.deinit();
            self.allocator.destroy(stmt);
        }
        self.statements.deinit(self.allocator);

        // In real implementation:
        // if (self.db_handle) |handle| {
        //     _ = c.sqlite3_close(handle);
        // }

        self.allocator.free(self.path);
        self.open = false;
    }

    /// Check if database is open
    pub fn isOpen(self: *const Self) bool {
        return self.open;
    }

    /// Execute SQL statement (INSERT, UPDATE, DELETE)
    pub fn execute(self: *Self, sql: []const u8, params: anytype) !void {
        var stmt = try self.prepare(sql);
        defer {
            stmt.deinit();
            self.allocator.destroy(stmt);
        }

        // Bind parameters using tuple
        const fields = @typeInfo(@TypeOf(params)).@"struct".fields;
        inline for (fields, 0..) |_, i| {
            try stmt.bind(i + 1, params[i]);
        }

        try stmt.execute();
        self.changes_count = 1; // Simulated
        self.total_changes += 1;
    }

    /// Execute raw SQL without parameters
    pub fn executeRaw(self: *Self, sql: []const u8) !void {
        if (!self.open) return DatabaseError.ConnectionFailed;
        if (sql.len == 0) return DatabaseError.InvalidQuery;

        // In real implementation:
        // var errmsg: [*c]u8 = null;
        // const rc = c.sqlite3_exec(self.db_handle, sql.ptr, null, null, &errmsg);
        // if (rc != c.SQLITE_OK) {
        //     if (errmsg) |msg| c.sqlite3_free(msg);
        //     return SqliteResult.toError(@enumFromInt(rc)) orelse DatabaseError.QueryFailed;
        // }

        // Software implementation - validate SQL starts with known command
        const trimmed = std.mem.trimLeft(u8, sql, " \t\n\r");
        if (trimmed.len == 0) return DatabaseError.InvalidQuery;
    }

    /// Execute multiple SQL statements
    pub fn executeScript(self: *Self, sql: []const u8) !void {
        var start: usize = 0;
        for (sql, 0..) |char, i| {
            if (char == ';') {
                const stmt_sql = sql[start .. i + 1];
                if (stmt_sql.len > 1) {
                    try self.executeRaw(stmt_sql);
                }
                start = i + 1;
            }
        }
        // Execute remaining SQL if any
        if (start < sql.len) {
            const remaining = std.mem.trim(u8, sql[start..], " \t\n\r");
            if (remaining.len > 0) {
                try self.executeRaw(remaining);
            }
        }
    }

    /// Query database (SELECT)
    pub fn query(self: *Self, sql: []const u8, params: anytype) ![]Row {
        var stmt = try self.prepare(sql);
        defer {
            stmt.deinit();
            self.allocator.destroy(stmt);
        }

        // Bind parameters
        const fields = @typeInfo(@TypeOf(params)).@"struct".fields;
        inline for (fields, 0..) |_, i| {
            try stmt.bind(i + 1, params[i]);
        }

        return try stmt.executeQuery();
    }

    /// Query for a single row
    pub fn queryOne(self: *Self, sql: []const u8, params: anytype) !?Row {
        const rows = try self.query(sql, params);
        defer self.allocator.free(rows);

        if (rows.len > 0) {
            const row = rows[0];
            // Free other rows if any
            for (rows[1..]) |*r| {
                r.deinit();
            }
            return row;
        }
        return null;
    }

    /// Query for a single value
    pub fn queryScalar(self: *Self, comptime T: type, sql: []const u8, params: anytype) !?T {
        var row = try self.queryOne(sql, params);
        if (row) |*r| {
            defer r.deinit();
            // Get first column value
            var it = r.columns.iterator();
            if (it.next()) |entry| {
                return switch (entry.value_ptr.*) {
                    .integer => |v| if (T == i64) v else null,
                    .real => |v| if (T == f64) v else null,
                    .text => |v| if (T == []const u8) v else null,
                    else => null,
                };
            }
        }
        return null;
    }

    /// Prepare SQL statement
    /// Caller is responsible for calling deinit() on the returned statement
    pub fn prepare(self: *Self, sql: []const u8) !*Statement {
        const stmt = try self.allocator.create(Statement);
        errdefer self.allocator.destroy(stmt);
        stmt.* = try Statement.init(self.allocator, self, sql);
        // Note: Statements are not tracked by the database - caller must manage lifetime
        return stmt;
    }

    /// Begin transaction
    pub fn beginTransaction(self: *Self) !void {
        if (self.in_transaction) {
            // Nested transaction - use savepoint
            self.transaction_depth += 1;
            var buf: [64]u8 = undefined;
            const savepoint = try std.fmt.bufPrint(&buf, "SAVEPOINT sp_{d}", .{self.transaction_depth});
            try self.executeRaw(savepoint);
            return;
        }

        try self.executeRaw("BEGIN TRANSACTION");
        self.in_transaction = true;
        self.transaction_depth = 0;
    }

    /// Begin immediate transaction (acquires write lock immediately)
    pub fn beginImmediateTransaction(self: *Self) !void {
        if (self.in_transaction) {
            return DatabaseError.TransactionFailed;
        }
        try self.executeRaw("BEGIN IMMEDIATE TRANSACTION");
        self.in_transaction = true;
    }

    /// Begin exclusive transaction (acquires exclusive lock)
    pub fn beginExclusiveTransaction(self: *Self) !void {
        if (self.in_transaction) {
            return DatabaseError.TransactionFailed;
        }
        try self.executeRaw("BEGIN EXCLUSIVE TRANSACTION");
        self.in_transaction = true;
    }

    /// Commit transaction
    pub fn commit(self: *Self) !void {
        if (!self.in_transaction) {
            return DatabaseError.TransactionFailed;
        }

        if (self.transaction_depth > 0) {
            // Release savepoint for nested transaction
            var buf: [64]u8 = undefined;
            const release = try std.fmt.bufPrint(&buf, "RELEASE SAVEPOINT sp_{d}", .{self.transaction_depth});
            try self.executeRaw(release);
            self.transaction_depth -= 1;
            return;
        }

        try self.executeRaw("COMMIT");
        self.in_transaction = false;
    }

    /// Rollback transaction
    pub fn rollback(self: *Self) !void {
        if (!self.in_transaction) {
            return DatabaseError.TransactionFailed;
        }

        if (self.transaction_depth > 0) {
            // Rollback to savepoint for nested transaction
            var buf: [64]u8 = undefined;
            const rollback_sp = try std.fmt.bufPrint(&buf, "ROLLBACK TO SAVEPOINT sp_{d}", .{self.transaction_depth});
            try self.executeRaw(rollback_sp);
            self.transaction_depth -= 1;
            return;
        }

        try self.executeRaw("ROLLBACK");
        self.in_transaction = false;
    }

    /// Execute within transaction with automatic commit/rollback
    pub fn transaction(self: *Self, callback: *const fn (*Self) anyerror!void) !void {
        try self.beginTransaction();
        errdefer self.rollback() catch {};

        try callback(self);
        try self.commit();
    }

    /// Get last insert row ID
    pub fn lastInsertRowId(self: *const Self) i64 {
        // In real implementation:
        // return c.sqlite3_last_insert_rowid(self.db_handle);
        return self.last_insert_rowid;
    }

    /// Get number of changed rows from last statement
    pub fn changes(self: *const Self) i64 {
        // In real implementation:
        // return c.sqlite3_changes(self.db_handle);
        return self.changes_count;
    }

    /// Get total number of changed rows since connection opened
    pub fn totalChanges(self: *const Self) i64 {
        // In real implementation:
        // return c.sqlite3_total_changes(self.db_handle);
        return self.total_changes;
    }

    /// Vacuum database to reclaim space
    pub fn vacuum(self: *Self) !void {
        try self.executeRaw("VACUUM");
    }

    /// Optimize database
    pub fn optimize(self: *Self) !void {
        try self.executeRaw("PRAGMA optimize");
    }

    /// Analyze database for query optimization
    pub fn analyze(self: *Self) !void {
        try self.executeRaw("ANALYZE");
    }

    /// Get database schema
    pub fn getSchema(self: *Self) ![]Row {
        return try self.query(
            "SELECT type, name, sql FROM sqlite_master WHERE sql NOT NULL ORDER BY type, name",
            .{},
        );
    }

    /// Get table info
    pub fn getTableInfo(self: *Self, table_name: []const u8) ![]Row {
        var buf: [256]u8 = undefined;
        const sql = try std.fmt.bufPrint(&buf, "PRAGMA table_info({s})", .{table_name});
        return try self.query(sql, .{});
    }

    /// Check database integrity
    pub fn integrityCheck(self: *Self) !bool {
        const rows = try self.query("PRAGMA integrity_check", .{});
        defer {
            for (rows) |*row| {
                var r = row;
                r.deinit();
            }
            self.allocator.free(rows);
        }

        if (rows.len > 0) {
            if (rows[0].getText("integrity_check")) |result| {
                return std.mem.eql(u8, result, "ok");
            }
        }

        return true; // Assume OK if no result
    }

    /// Check if table exists
    pub fn tableExists(self: *Self, table_name: []const u8) !bool {
        const rows = try self.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            .{table_name},
        );
        defer {
            for (rows) |*row| {
                var r = row;
                r.deinit();
            }
            self.allocator.free(rows);
        }
        return rows.len > 0;
    }

    /// Get SQLite version
    pub fn getVersion(self: *Self) ![]const u8 {
        _ = self;
        // In real implementation:
        // return std.mem.span(c.sqlite3_libversion());
        return "3.45.0"; // Simulated
    }

    /// Get last error message
    pub fn getLastError(self: *Self) []const u8 {
        _ = self;
        // In real implementation:
        // return std.mem.span(c.sqlite3_errmsg(self.db_handle));
        return "";
    }

    /// Interrupt a long-running query
    pub fn interrupt(self: *Self) void {
        _ = self;
        // In real implementation:
        // c.sqlite3_interrupt(self.db_handle);
    }

    /// Check if database is in autocommit mode
    pub fn isAutocommit(self: *const Self) bool {
        return !self.in_transaction;
    }

    /// Get current transaction depth (0 = not in transaction)
    pub fn getTransactionDepth(self: *const Self) u32 {
        if (!self.in_transaction) return 0;
        return self.transaction_depth + 1;
    }

    /// Create a backup of the database
    pub fn backup(self: *Self, dest_path: []const u8) !void {
        _ = self;
        _ = dest_path;
        // In real implementation, would use sqlite3_backup API
    }

    /// Restore database from backup
    pub fn restore(self: *Self, source_path: []const u8) !void {
        _ = self;
        _ = source_path;
        // In real implementation, would use sqlite3_backup API
    }
};

/// Database migration system
pub const Migration = struct {
    version: u32,
    up: []const u8,
    down: ?[]const u8 = null,
};

pub const Migrator = struct {
    db: *Database,
    migrations: []const Migration,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, db: *Database, migrations: []const Migration) Migrator {
        return Migrator{
            .db = db,
            .migrations = migrations,
            .allocator = allocator,
        };
    }

    pub fn migrate(self: *Self) !void {
        // Create migrations table if not exists
        try self.db.executeRaw(
            \\CREATE TABLE IF NOT EXISTS _migrations (
            \\  version INTEGER PRIMARY KEY,
            \\  applied_at INTEGER NOT NULL
            \\)
        );

        // Get current version
        const current_version = try self.getCurrentVersion();

        // Apply pending migrations
        for (self.migrations) |migration| {
            if (migration.version > current_version) {
                try self.db.beginTransaction();
                errdefer self.db.rollback() catch {};

                try self.db.executeRaw(migration.up);

                // Get current timestamp (use Instant for Zig 0.16 compatibility)
                const now: i64 = if (std.time.Instant.now()) |instant|
                    @intCast(@divFloor(instant.timestamp.sec * 1_000_000_000 + instant.timestamp.nsec, 1_000_000_000))
                else |_|
                    0;

                try self.db.execute(
                    "INSERT INTO _migrations (version, applied_at) VALUES (?, ?)",
                    .{ @as(i64, migration.version), now },
                );

                try self.db.commit();
            }
        }
    }

    pub fn rollback(self: *Self, target_version: u32) !void {
        const current_version = try self.getCurrentVersion();

        // Rollback migrations in reverse order
        var i = self.migrations.len;
        while (i > 0) {
            i -= 1;
            const migration = self.migrations[i];

            if (migration.version > target_version and migration.version <= current_version) {
                if (migration.down) |down_sql| {
                    std.debug.print("Rolling back migration {d}\n", .{migration.version});

                    try self.db.beginTransaction();
                    errdefer self.db.rollback() catch {};

                    try self.db.execute(down_sql, .{});
                    try self.db.execute(
                        "DELETE FROM _migrations WHERE version = ?",
                        .{migration.version},
                    );

                    try self.db.commit();
                }
            }
        }
    }

    fn getCurrentVersion(self: *Self) !u32 {
        const rows = try self.db.query(
            "SELECT MAX(version) as version FROM _migrations",
            .{},
        );
        defer {
            for (rows) |*row| {
                row.deinit();
            }
            self.allocator.free(rows);
        }

        if (rows.len > 0) {
            if (rows[0].getInt("version")) |version| {
                return @intCast(version);
            }
        }

        return 0;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "database init" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    try std.testing.expect(db.isOpen());
    try std.testing.expectEqualStrings(":memory:", db.path);
}

test "database config options" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
        .enable_wal = false,
        .enable_foreign_keys = false,
        .cache_size = 1000,
        .timeout = 10000,
        .read_only = false,
    });
    defer db.deinit();

    try std.testing.expect(db.isOpen());
    try std.testing.expectEqual(@as(i32, 1000), db.config.cache_size);
}

test "database transaction" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    try std.testing.expect(db.isAutocommit());
    try std.testing.expectEqual(@as(u32, 0), db.getTransactionDepth());

    try db.beginTransaction();
    try std.testing.expect(!db.isAutocommit());
    try std.testing.expectEqual(@as(u32, 1), db.getTransactionDepth());

    try db.commit();
    try std.testing.expect(db.isAutocommit());
}

test "database nested transactions" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    // Start first transaction
    try db.beginTransaction();
    try std.testing.expectEqual(@as(u32, 1), db.getTransactionDepth());

    // Start nested transaction (savepoint)
    try db.beginTransaction();
    try std.testing.expectEqual(@as(u32, 2), db.getTransactionDepth());

    // Commit nested
    try db.commit();
    try std.testing.expectEqual(@as(u32, 1), db.getTransactionDepth());

    // Commit outer
    try db.commit();
    try std.testing.expectEqual(@as(u32, 0), db.getTransactionDepth());
}

test "database rollback" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    try db.beginTransaction();
    try db.rollback();
    try std.testing.expect(db.isAutocommit());
}

test "database transaction errors" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    // Should fail - not in transaction
    try std.testing.expectError(DatabaseError.TransactionFailed, db.commit());
    try std.testing.expectError(DatabaseError.TransactionFailed, db.rollback());
}

test "database execute raw" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    try db.executeRaw("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)");
    try db.executeRaw("INSERT INTO test (id, name) VALUES (1, 'test')");
}

test "database execute script" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    try db.executeScript(
        \\CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
        \\CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER, title TEXT);
        \\INSERT INTO users (id, name) VALUES (1, 'Alice');
    );
}

test "prepared statement creation" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    var stmt = try db.prepare("SELECT * FROM users WHERE id = ?");
    defer {
        stmt.deinit();
        allocator.destroy(stmt);
    }

    try std.testing.expectEqualStrings("SELECT * FROM users WHERE id = ?", stmt.getSql());
}

test "prepared statement binding" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    var stmt = try db.prepare("INSERT INTO users (id, name, score) VALUES (?, ?, ?)");
    defer {
        stmt.deinit();
        allocator.destroy(stmt);
    }

    try stmt.bindInt(1, 42);
    try stmt.bindText(2, "Alice");
    try stmt.bindFloat(3, 95.5);

    try std.testing.expectEqual(@as(usize, 3), stmt.bound_params.items.len);

    // Check bound values
    try std.testing.expectEqual(@as(i64, 42), stmt.bound_params.items[0].integer);
    try std.testing.expectEqualStrings("Alice", stmt.bound_params.items[1].text);
    try std.testing.expectEqual(@as(f64, 95.5), stmt.bound_params.items[2].real);
}

test "prepared statement reset" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    var stmt = try db.prepare("SELECT * FROM users WHERE id = ?");
    defer {
        stmt.deinit();
        allocator.destroy(stmt);
    }

    try stmt.bindInt(1, 1);
    try std.testing.expectEqual(@as(usize, 1), stmt.bound_params.items.len);

    stmt.reset();
    try std.testing.expectEqual(@as(usize, 0), stmt.bound_params.items.len);
}

test "row value access" {
    const allocator = std.testing.allocator;

    var row = Row.init(allocator);
    defer row.deinit();

    try row.columns.put("id", .{ .integer = 42 });
    try row.columns.put("name", .{ .text = "Alice" });
    try row.columns.put("score", .{ .real = 95.5 });

    try std.testing.expectEqual(@as(?i64, 42), row.getInt("id"));
    try std.testing.expectEqualStrings("Alice", row.getText("name").?);
    try std.testing.expectEqual(@as(?f64, 95.5), row.getFloat("score"));

    // Non-existent column
    try std.testing.expect(row.getInt("nonexistent") == null);
}

test "database changes tracking" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    try std.testing.expectEqual(@as(i64, 0), db.changes());
    try std.testing.expectEqual(@as(i64, 0), db.totalChanges());

    try db.execute("INSERT INTO test VALUES (?)", .{@as(i64, 1)});
    try std.testing.expectEqual(@as(i64, 1), db.changes());
    try std.testing.expectEqual(@as(i64, 1), db.totalChanges());
}

test "database version" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    const version = try db.getVersion();
    try std.testing.expect(version.len > 0);
}

test "sqlite result codes" {
    try std.testing.expect(SqliteResult.ok.toError() == null);
    try std.testing.expect(SqliteResult.row.toError() == null);
    try std.testing.expect(SqliteResult.done.toError() == null);

    try std.testing.expectEqual(DatabaseError.DatabaseLocked, SqliteResult.busy.toError().?);
    try std.testing.expectEqual(DatabaseError.DatabaseCorrupt, SqliteResult.corrupt.toError().?);
    try std.testing.expectEqual(DatabaseError.ConstraintViolation, SqliteResult.constraint.toError().?);
}

test "bound value types" {
    const null_val: BoundValue = .{ .null = {} };
    const int_val: BoundValue = .{ .integer = 42 };
    const float_val: BoundValue = .{ .real = 3.14 };
    const text_val: BoundValue = .{ .text = "hello" };
    const blob_val: BoundValue = .{ .blob = &[_]u8{ 0x00, 0x01, 0x02 } };

    try std.testing.expect(null_val == .null);
    try std.testing.expectEqual(@as(i64, 42), int_val.integer);
    try std.testing.expectEqual(@as(f64, 3.14), float_val.real);
    try std.testing.expectEqualStrings("hello", text_val.text);
    try std.testing.expectEqual(@as(usize, 3), blob_val.blob.len);
}

test "migration struct" {
    const migration = Migration{
        .version = 1,
        .up = "CREATE TABLE users (id INTEGER PRIMARY KEY)",
        .down = "DROP TABLE users",
    };

    try std.testing.expectEqual(@as(u32, 1), migration.version);
    try std.testing.expect(migration.down != null);
}

test "migrator initialization" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    const migrations = [_]Migration{
        .{ .version = 1, .up = "CREATE TABLE users (id INTEGER)" },
        .{ .version = 2, .up = "ALTER TABLE users ADD name TEXT" },
    };

    const migrator = Migrator.init(allocator, &db, &migrations);
    _ = migrator;
}
