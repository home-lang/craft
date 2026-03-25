const std = @import("std");

/// Database API for SQLite integration
/// Provides comprehensive database operations with transactions, prepared statements,
/// and migration support. Uses real SQLite on all platforms — the vendored
/// amalgamation (vendor/sqlite/sqlite3.c) is compiled by Zig's C compiler,
/// so no system SQLite dependency is required.
const c = @cImport({
    @cInclude("sqlite3.h");
});

const builtin = @import("builtin");

// SQLITE_TRANSIENT tells SQLite to make its own copy of the bound data.
// The C definition is ((sqlite3_destructor_type)-1), i.e. a function pointer with value -1.
// Zig's @cImport can't translate this cast due to function pointer alignment checks.
// Instead, we call the C bind functions directly through thin asm stubs that pass the
// correct destructor value (-1), avoiding Zig's type system constraints.
extern fn sqlite3_bind_text_transient(stmt: ?*c.sqlite3_stmt, idx: c_int, text: [*c]const u8, len: c_int) c_int;
extern fn sqlite3_bind_blob_transient(stmt: ?*c.sqlite3_stmt, idx: c_int, blob: ?*const anyopaque, len: c_int) c_int;

comptime {
    // Asm stubs that tail-call sqlite3_bind_text/sqlite3_bind_blob with the 5th argument
    // (destructor) set to -1 (SQLITE_TRANSIENT). Platform-specific calling conventions:
    //   arm64: 5th arg in x4
    //   x86_64 SysV: 5th arg in r8 (Linux)
    //   x86_64 Win64: 5th arg on stack (Windows uses 4-register fastcall)
    if (builtin.cpu.arch == .aarch64) {
        asm (
            \\.globl _sqlite3_bind_text_transient
            \\_sqlite3_bind_text_transient:
            \\  mov x4, #-1
            \\  b _sqlite3_bind_text
        );
        asm (
            \\.globl _sqlite3_bind_blob_transient
            \\_sqlite3_bind_blob_transient:
            \\  mov x4, #-1
            \\  b _sqlite3_bind_blob
        );
    } else if (builtin.cpu.arch == .x86_64) {
        if (builtin.os.tag == .windows) {
            // Win64 ABI: first 4 args in rcx,rdx,r8,r9; 5th arg at [rsp+40]
            asm (
                \\.globl sqlite3_bind_text_transient
                \\sqlite3_bind_text_transient:
                \\  mov qword ptr [rsp+32], -1
                \\  jmp sqlite3_bind_text
            );
            asm (
                \\.globl sqlite3_bind_blob_transient
                \\sqlite3_bind_blob_transient:
                \\  mov qword ptr [rsp+32], -1
                \\  jmp sqlite3_bind_blob
            );
        } else {
            // SysV ABI (Linux/macOS): first 6 args in rdi,rsi,rdx,rcx,r8,r9
            asm (
                \\.globl sqlite3_bind_text_transient
                \\sqlite3_bind_text_transient:
                \\  mov r8, -1
                \\  jmp sqlite3_bind_text
            );
            asm (
                \\.globl sqlite3_bind_blob_transient
                \\sqlite3_bind_blob_transient:
                \\  mov r8, -1
                \\  jmp sqlite3_bind_blob
            );
        }
    }
}

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
        var it = self.columns.iterator();
        while (it.next()) |entry| {
            // Free duped column name
            self.allocator.free(entry.key_ptr.*);
            // Free duped text/blob values
            switch (entry.value_ptr.*) {
                .text => |t| self.allocator.free(t),
                .blob => |b| self.allocator.free(b),
                else => {},
            }
        }
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
    stmt_handle: ?*c.sqlite3_stmt = null,

    pub fn init(allocator: std.mem.Allocator, db: *Database, sql: []const u8) !Statement {
        const duped_sql = try allocator.dupe(u8, sql);
        errdefer allocator.free(duped_sql);

        // Prepare the SQLite statement
        var stmt_handle: ?*c.sqlite3_stmt = null;
        const rc = c.sqlite3_prepare_v2(
            db.db_handle,
            duped_sql.ptr,
            @intCast(duped_sql.len),
            &stmt_handle,
            null,
        );
        if (rc != c.SQLITE_OK) {
            return DatabaseError.PreparationFailed;
        }

        // Extract column names from the prepared statement
        var col_names = std.ArrayList([]const u8){};
        const col_count = c.sqlite3_column_count(stmt_handle);
        var col_idx: c_int = 0;
        while (col_idx < col_count) : (col_idx += 1) {
            const name_ptr = c.sqlite3_column_name(stmt_handle, col_idx);
            if (name_ptr) |name| {
                const name_slice = std.mem.span(name);
                const duped_name = try allocator.dupe(u8, name_slice);
                try col_names.append(allocator, duped_name);
            }
        }

        return Statement{
            .sql = duped_sql,
            .allocator = allocator,
            .db = db,
            .bound_params = .{},
            .column_names = col_names,
            .finalized = false,
            .stmt_handle = stmt_handle,
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
        if (self.stmt_handle) |handle| {
            const rc = c.sqlite3_bind_null(handle, @intCast(index));
            if (rc != c.SQLITE_OK) return DatabaseError.BindFailed;
        }
    }

    /// Bind an integer value
    pub fn bindInt(self: *Statement, index: usize, value: i64) !void {
        try self.ensureParamCapacity(index);
        self.bound_params.items[index - 1] = .{ .integer = value };
        if (self.stmt_handle) |handle| {
            const rc = c.sqlite3_bind_int64(handle, @intCast(index), value);
            if (rc != c.SQLITE_OK) return DatabaseError.BindFailed;
        }
    }

    /// Bind a float value
    pub fn bindFloat(self: *Statement, index: usize, value: f64) !void {
        try self.ensureParamCapacity(index);
        self.bound_params.items[index - 1] = .{ .real = value };
        if (self.stmt_handle) |handle| {
            const rc = c.sqlite3_bind_double(handle, @intCast(index), value);
            if (rc != c.SQLITE_OK) return DatabaseError.BindFailed;
        }
    }

    /// Bind a text value
    pub fn bindText(self: *Statement, index: usize, value: []const u8) !void {
        try self.ensureParamCapacity(index);
        self.bound_params.items[index - 1] = .{ .text = value };
        if (self.stmt_handle) |handle| {
            const rc = sqlite3_bind_text_transient(
                handle,
                @intCast(index),
                value.ptr,
                @intCast(value.len),
            );
            if (rc != c.SQLITE_OK) return DatabaseError.BindFailed;
        }
    }

    /// Bind a blob value
    pub fn bindBlob(self: *Statement, index: usize, value: []const u8) !void {
        try self.ensureParamCapacity(index);
        self.bound_params.items[index - 1] = .{ .blob = value };
        if (self.stmt_handle) |handle| {
            const rc = sqlite3_bind_blob_transient(
                handle,
                @intCast(index),
                value.ptr,
                @intCast(value.len),
            );
            if (rc != c.SQLITE_OK) return DatabaseError.BindFailed;
        }
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
        const handle = self.stmt_handle orelse return DatabaseError.InvalidQuery;
        const rc = c.sqlite3_step(handle);
        if (rc != c.SQLITE_DONE and rc != c.SQLITE_ROW) {
            const result: SqliteResult = @enumFromInt(rc);
            return result.toError() orelse DatabaseError.StepFailed;
        }
    }

    /// Execute query and return rows
    pub fn executeQuery(self: *Statement) ![]Row {
        var rows = std.ArrayList(Row){};
        errdefer {
            for (rows.items) |*row| {
                row.deinit();
            }
            rows.deinit(self.allocator);
        }

        const handle = self.stmt_handle orelse return DatabaseError.InvalidQuery;
        const col_count = c.sqlite3_column_count(handle);

        while (true) {
            const rc = c.sqlite3_step(handle);
            if (rc == c.SQLITE_DONE) break;
            if (rc != c.SQLITE_ROW) {
                const result: SqliteResult = @enumFromInt(rc);
                return result.toError() orelse DatabaseError.StepFailed;
            }

            var row = Row.init(self.allocator);
            errdefer row.deinit();

            var col_idx: c_int = 0;
            while (col_idx < col_count) : (col_idx += 1) {
                // Get column name
                const name_ptr = c.sqlite3_column_name(handle, col_idx);
                const col_name = if (name_ptr) |np|
                    try self.allocator.dupe(u8, std.mem.span(np))
                else
                    try self.allocator.dupe(u8, "");
                errdefer self.allocator.free(col_name);

                // Get column value based on type
                const col_type = c.sqlite3_column_type(handle, col_idx);
                const value: Row.Value = switch (col_type) {
                    c.SQLITE_NULL => .{ .null = {} },
                    c.SQLITE_INTEGER => .{ .integer = c.sqlite3_column_int64(handle, col_idx) },
                    c.SQLITE_FLOAT => .{ .real = c.sqlite3_column_double(handle, col_idx) },
                    c.SQLITE_TEXT => blk: {
                        const text_ptr = c.sqlite3_column_text(handle, col_idx);
                        const text_len: usize = @intCast(c.sqlite3_column_bytes(handle, col_idx));
                        if (text_ptr) |tp| {
                            const duped = try self.allocator.dupe(u8, tp[0..text_len]);
                            break :blk .{ .text = duped };
                        }
                        break :blk .{ .null = {} };
                    },
                    c.SQLITE_BLOB => blk: {
                        const blob_ptr = c.sqlite3_column_blob(handle, col_idx);
                        const blob_len: usize = @intCast(c.sqlite3_column_bytes(handle, col_idx));
                        if (blob_ptr) |bp| {
                            const src: [*]const u8 = @ptrCast(bp);
                            const duped = try self.allocator.dupe(u8, src[0..blob_len]);
                            break :blk .{ .blob = duped };
                        }
                        break :blk .{ .null = {} };
                    },
                    else => .{ .null = {} },
                };

                try row.columns.put(col_name, value);
            }

            try rows.append(self.allocator, row);
        }

        return try rows.toOwnedSlice(self.allocator);
    }

    /// Reset statement for reuse with new parameters
    pub fn reset(self: *Statement) void {
        self.bound_params.clearRetainingCapacity();
        if (self.stmt_handle) |handle| {
            _ = c.sqlite3_reset(handle);
            _ = c.sqlite3_clear_bindings(handle);
        }
    }

    /// Finalize and release the statement
    pub fn finalize(self: *Statement) void {
        if (self.stmt_handle) |handle| {
            _ = c.sqlite3_finalize(handle);
            self.stmt_handle = null;
        }
        self.finalized = true;
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
    db_handle: ?*c.sqlite3 = null,

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
            .db_handle = null,
        };

        try db.openConnection();
        return db;
    }

    fn openConnection(self: *Self) !void {
        // Build flags based on config
        var flags: c_int = 0;
        if (self.config.read_only) {
            flags = c.SQLITE_OPEN_READONLY;
        } else {
            flags = c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE;
        }
        if (self.config.shared_cache) {
            flags |= c.SQLITE_OPEN_SHAREDCACHE;
        }

        // Need a null-terminated string for sqlite3_open_v2
        const path_z = try self.allocator.alloc(u8, self.path.len + 1);
        defer self.allocator.free(path_z);
        @memcpy(path_z[0..self.path.len], self.path);
        path_z[self.path.len] = 0;

        const rc = c.sqlite3_open_v2(path_z.ptr, &self.db_handle, flags, null);
        if (rc != c.SQLITE_OK) {
            if (self.db_handle) |handle| {
                _ = c.sqlite3_close(handle);
                self.db_handle = null;
            }
            return DatabaseError.ConnectionFailed;
        }

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
        var sql_buf: [256]u8 = undefined;
        const sql = try std.fmt.bufPrint(&sql_buf, "PRAGMA {s} = {s}", .{ pragma, value });
        try self.executeRaw(sql);
    }

    fn executePragmaInt(self: *Self, pragma: []const u8, value: i32) !void {
        var sql_buf: [256]u8 = undefined;
        const sql = try std.fmt.bufPrint(&sql_buf, "PRAGMA {s} = {d}", .{ pragma, value });
        try self.executeRaw(sql);
    }

    pub fn deinit(self: *Self) void {
        // Finalize all prepared statements
        for (self.statements.items) |stmt| {
            stmt.deinit();
            self.allocator.destroy(stmt);
        }
        self.statements.deinit(self.allocator);

        if (self.db_handle) |handle| {
            _ = c.sqlite3_close_v2(handle);
            self.db_handle = null;
        }

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
        // Update change tracking from SQLite
        if (self.db_handle) |handle| {
            self.changes_count = @intCast(c.sqlite3_changes(handle));
            self.total_changes = @intCast(c.sqlite3_total_changes(handle));
            self.last_insert_rowid = c.sqlite3_last_insert_rowid(handle);
        }
    }

    /// Execute raw SQL without parameters
    pub fn executeRaw(self: *Self, sql: []const u8) !void {
        if (!self.open) return DatabaseError.ConnectionFailed;
        if (sql.len == 0) return DatabaseError.InvalidQuery;

        const handle = self.db_handle orelse return DatabaseError.ConnectionFailed;

        // Need a null-terminated string for sqlite3_exec
        const sql_z = try self.allocator.alloc(u8, sql.len + 1);
        defer self.allocator.free(sql_z);
        @memcpy(sql_z[0..sql.len], sql);
        sql_z[sql.len] = 0;

        var errmsg: [*c]u8 = null;
        const rc = c.sqlite3_exec(handle, sql_z.ptr, null, null, &errmsg);
        if (rc != c.SQLITE_OK) {
            if (errmsg) |msg| c.sqlite3_free(msg);
            const result: SqliteResult = @enumFromInt(rc);
            return result.toError() orelse DatabaseError.QueryFailed;
        }
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
                var mr = r.*;
                mr.deinit();
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
        errdefer self.rollback() catch |err| {
            std.log.warn("transaction rollback failed: {}", .{err});
        };

        try callback(self);
        try self.commit();
    }

    /// Get last insert row ID
    pub fn lastInsertRowId(self: *const Self) i64 {
        if (self.db_handle) |handle| {
            return c.sqlite3_last_insert_rowid(handle);
        }
        return self.last_insert_rowid;
    }

    /// Get number of changed rows from last statement
    pub fn changes(self: *const Self) i64 {
        if (self.db_handle) |handle| {
            return @intCast(c.sqlite3_changes(handle));
        }
        return self.changes_count;
    }

    /// Get total number of changed rows since connection opened
    pub fn totalChanges(self: *const Self) i64 {
        if (self.db_handle) |handle| {
            return @intCast(c.sqlite3_total_changes(handle));
        }
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
                var r = row.*;
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
                var r = row.*;
                r.deinit();
            }
            self.allocator.free(rows);
        }
        return rows.len > 0;
    }

    /// Get SQLite version
    pub fn getVersion(self: *Self) ![]const u8 {
        _ = self;
        return std.mem.span(c.sqlite3_libversion());
    }

    /// Get last error message
    pub fn getLastError(self: *Self) []const u8 {
        if (self.db_handle) |handle| {
            const msg = c.sqlite3_errmsg(handle);
            if (msg) |m| return std.mem.span(m);
        }
        return "";
    }

    /// Interrupt a long-running query
    pub fn interrupt(self: *Self) void {
        if (self.db_handle) |handle| {
            c.sqlite3_interrupt(handle);
        }
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
        const src_handle = self.db_handle orelse return DatabaseError.ConnectionFailed;

        // Open destination database
        const dest_z = try self.allocator.alloc(u8, dest_path.len + 1);
        defer self.allocator.free(dest_z);
        @memcpy(dest_z[0..dest_path.len], dest_path);
        dest_z[dest_path.len] = 0;

        var dest_handle: ?*c.sqlite3 = null;
        var rc = c.sqlite3_open(dest_z.ptr, &dest_handle);
        if (rc != c.SQLITE_OK) {
            if (dest_handle) |dh| _ = c.sqlite3_close(dh);
            return DatabaseError.ConnectionFailed;
        }
        defer _ = c.sqlite3_close(dest_handle);

        const bk = c.sqlite3_backup_init(dest_handle, "main", src_handle, "main");
        if (bk == null) return DatabaseError.QueryFailed;

        rc = c.sqlite3_backup_step(bk, -1);
        _ = c.sqlite3_backup_finish(bk);

        if (rc != c.SQLITE_DONE) {
            return DatabaseError.QueryFailed;
        }
    }

    /// Restore database from backup
    pub fn restore(self: *Self, source_path: []const u8) !void {
        const dest_handle = self.db_handle orelse return DatabaseError.ConnectionFailed;

        // Open source database
        const src_z = try self.allocator.alloc(u8, source_path.len + 1);
        defer self.allocator.free(src_z);
        @memcpy(src_z[0..source_path.len], source_path);
        src_z[source_path.len] = 0;

        var src_handle: ?*c.sqlite3 = null;
        var rc = c.sqlite3_open(src_z.ptr, &src_handle);
        if (rc != c.SQLITE_OK) {
            if (src_handle) |sh| _ = c.sqlite3_close(sh);
            return DatabaseError.ConnectionFailed;
        }
        defer _ = c.sqlite3_close(src_handle);

        const bk = c.sqlite3_backup_init(dest_handle, "main", src_handle, "main");
        if (bk == null) return DatabaseError.QueryFailed;

        rc = c.sqlite3_backup_step(bk, -1);
        _ = c.sqlite3_backup_finish(bk);

        if (rc != c.SQLITE_DONE) {
            return DatabaseError.QueryFailed;
        }
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
                errdefer self.db.rollback() catch |err| {
                    std.log.warn("migration rollback failed for version {d}: {}", .{ migration.version, err });
                };

                try self.db.executeRaw(migration.up);

                // Get current timestamp
                const now: i64 = std.time.timestamp();

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
                    errdefer self.db.rollback() catch |err| {
                        std.log.warn("migration rollback failed during downgrade of version {d}: {}", .{ migration.version, err });
                    };

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
                var r = row.*;
                r.deinit();
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

    // Create a table first so the statement can reference real columns
    try db.executeRaw("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)");

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

    try db.executeRaw("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, score REAL)");

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

    try db.executeRaw("CREATE TABLE users (id INTEGER PRIMARY KEY)");

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

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    // Create table and insert data, then query to get a real row
    try db.executeRaw("CREATE TABLE test (id INTEGER, name TEXT, score REAL)");
    try db.executeRaw("INSERT INTO test VALUES (42, 'Alice', 95.5)");

    const rows = try db.query("SELECT id, name, score FROM test", .{});
    defer {
        for (rows) |*row| {
            var r = row.*;
            r.deinit();
        }
        allocator.free(rows);
    }

    try std.testing.expect(rows.len == 1);
    try std.testing.expectEqual(@as(?i64, 42), rows[0].getInt("id"));
    try std.testing.expectEqualStrings("Alice", rows[0].getText("name").?);
    try std.testing.expectEqual(@as(?f64, 95.5), rows[0].getFloat("score"));

    // Non-existent column
    try std.testing.expect(rows[0].getInt("nonexistent") == null);
}

test "database changes tracking" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, .{
        .path = ":memory:",
    });
    defer db.deinit();

    try db.executeRaw("CREATE TABLE test (id INTEGER PRIMARY KEY)");

    try db.execute("INSERT INTO test VALUES (?)", .{@as(i64, 1)});
    try std.testing.expectEqual(@as(i64, 1), db.changes());
    try std.testing.expect(db.totalChanges() >= 1);
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
