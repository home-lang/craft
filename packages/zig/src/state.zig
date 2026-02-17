const std = @import("std");
const io_context = @import("io_context.zig");
const compat_mutex = @import("compat_mutex.zig");

/// State Management System
/// Provides reactive state management with observers and middleware
pub const StateError = error{
    InvalidState,
    MutationDuringComputation,
    CircularDependency,
};

pub const State = struct {
    data: std.StringHashMap(StateValue),
    observers: std.StringHashMap(std.ArrayList(Observer)),
    computed: std.StringHashMap(ComputedValue),
    middleware: std.ArrayList(Middleware),
    history: StateHistory,
    is_computing: bool,
    mutex: compat_mutex.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) State {
        return State{
            .data = std.StringHashMap(StateValue).init(allocator),
            .observers = std.StringHashMap(std.ArrayList(Observer)).init(allocator),
            .computed = std.StringHashMap(ComputedValue).init(allocator),
            .middleware = std.ArrayList(Middleware).init(allocator),
            .history = StateHistory.init(allocator),
            .is_computing = false,
            .mutex = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *State) void {
        var observer_iter = self.observers.valueIterator();
        while (observer_iter.next()) |observers| {
            observers.deinit();
        }
        self.observers.deinit();
        self.data.deinit();
        self.computed.deinit();
        self.middleware.deinit();
        self.history.deinit();
    }

    pub fn set(self: *State, key: []const u8, value: StateValue) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.is_computing) return StateError.MutationDuringComputation;

        const old_value = self.data.get(key);

        // Run middleware
        for (self.middleware.items) |middleware| {
            if (!middleware.fn_ptr(key, value, old_value)) {
                return; // Middleware blocked the change
            }
        }

        // Update state
        try self.data.put(key, value);

        // Save to history
        try self.history.push(key, old_value, value);

        // Notify observers
        if (self.observers.get(key)) |observers| {
            for (observers.items) |observer| {
                observer.fn_ptr(value, old_value);
            }
        }

        // Invalidate computed values that depend on this key
        try self.invalidateComputed(key);
    }

    pub fn get(self: *State, key: []const u8) ?StateValue {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.data.get(key);
    }

    pub fn observe(self: *State, key: []const u8, observer: Observer) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.observers.getPtr(key)) |observers| {
            try observers.append(observer);
        } else {
            var observers = std.ArrayList(Observer).init(self.allocator);
            try observers.append(observer);
            try self.observers.put(key, observers);
        }
    }

    pub fn unobserve(self: *State, key: []const u8, observer: Observer) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.observers.getPtr(key)) |observers| {
            for (observers.items, 0..) |obs, i| {
                if (obs.id == observer.id) {
                    _ = observers.swapRemove(i);
                    break;
                }
            }
        }
    }

    pub fn addComputed(self: *State, key: []const u8, computed: ComputedValue) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.computed.put(key, computed);
    }

    pub fn getComputed(self: *State, key: []const u8) !?StateValue {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.computed.getPtr(key)) |computed| {
            if (!computed.is_valid) {
                self.is_computing = true;
                defer self.is_computing = false;

                computed.value = try computed.fn_ptr(self);
                computed.is_valid = true;
            }
            return computed.value;
        }
        return null;
    }

    pub fn addMiddleware(self: *State, middleware: Middleware) !void {
        try self.middleware.append(middleware);
    }

    pub fn undo(self: *State) !void {
        if (try self.history.undo()) |change| {
            try self.data.put(change.key, change.old_value orelse StateValue{ .null_value = {} });
            if (self.observers.get(change.key)) |observers| {
                for (observers.items) |observer| {
                    observer.fn_ptr(change.old_value orelse StateValue{ .null_value = {} }, change.new_value);
                }
            }
        }
    }

    pub fn redo(self: *State) !void {
        if (try self.history.redo()) |change| {
            try self.data.put(change.key, change.new_value);
            if (self.observers.get(change.key)) |observers| {
                for (observers.items) |observer| {
                    observer.fn_ptr(change.new_value, change.old_value);
                }
            }
        }
    }

    fn invalidateComputed(self: *State, key: []const u8) !void {
        var iter = self.computed.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.dependencies.items) |dep| {
                if (std.mem.eql(u8, dep, key)) {
                    entry.value_ptr.is_valid = false;
                    break;
                }
            }
        }
    }
};

pub const StateValue = union(enum) {
    int: i64,
    float: f64,
    bool: bool,
    string: []const u8,
    null_value: void,

    pub fn eql(self: StateValue, other: ?StateValue) bool {
        const other_val = other orelse return false;
        return switch (self) {
            .int => |v| if (other_val == .int) v == other_val.int else false,
            .float => |v| if (other_val == .float) v == other_val.float else false,
            .bool => |v| if (other_val == .bool) v == other_val.bool else false,
            .string => |v| if (other_val == .string) std.mem.eql(u8, v, other_val.string) else false,
            .null_value => other_val == .null_value,
        };
    }
};

pub const Observer = struct {
    id: usize,
    fn_ptr: *const fn (StateValue, ?StateValue) void,
};

pub const ComputedValue = struct {
    fn_ptr: *const fn (*State) anyerror!StateValue,
    dependencies: std.ArrayList([]const u8),
    value: StateValue,
    is_valid: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, fn_ptr: *const fn (*State) anyerror!StateValue, dependencies: []const []const u8) !ComputedValue {
        var deps = std.ArrayList([]const u8).init(allocator);
        for (dependencies) |dep| {
            try deps.append(dep);
        }

        return ComputedValue{
            .fn_ptr = fn_ptr,
            .dependencies = deps,
            .value = StateValue{ .null_value = {} },
            .is_valid = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ComputedValue) void {
        self.dependencies.deinit();
    }
};

pub const Middleware = struct {
    fn_ptr: *const fn ([]const u8, StateValue, ?StateValue) bool,
};

pub const StateHistory = struct {
    changes: std.ArrayList(StateChange),
    current_index: isize,
    max_size: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) StateHistory {
        return StateHistory{
            .changes = std.ArrayList(StateChange).init(allocator),
            .current_index = -1,
            .max_size = 100,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StateHistory) void {
        self.changes.deinit();
    }

    pub fn push(self: *StateHistory, key: []const u8, old_value: ?StateValue, new_value: StateValue) !void {
        // Remove any changes after current index (redo stack)
        while (self.changes.items.len > 0 and @as(isize, @intCast(self.changes.items.len)) - 1 > self.current_index) {
            _ = self.changes.pop();
        }

        // Add new change
        try self.changes.append(StateChange{
            .key = key,
            .old_value = old_value,
            .new_value = new_value,
            .timestamp = std.time.milliTimestamp(),
        });

        self.current_index = @intCast(self.changes.items.len - 1);

        // Limit history size
        while (self.changes.items.len > self.max_size) {
            _ = self.changes.orderedRemove(0);
            self.current_index -= 1;
        }
    }

    pub fn undo(self: *StateHistory) !?StateChange {
        if (self.current_index < 0) return null;

        const change = self.changes.items[@intCast(self.current_index)];
        self.current_index -= 1;
        return change;
    }

    pub fn redo(self: *StateHistory) !?StateChange {
        if (self.current_index >= @as(isize, @intCast(self.changes.items.len)) - 1) return null;

        self.current_index += 1;
        return self.changes.items[@intCast(self.current_index)];
    }

    pub fn canUndo(self: StateHistory) bool {
        return self.current_index >= 0;
    }

    pub fn canRedo(self: StateHistory) bool {
        return self.current_index < @as(isize, @intCast(self.changes.items.len)) - 1;
    }

    pub fn clear(self: *StateHistory) void {
        self.changes.clearRetainingCapacity();
        self.current_index = -1;
    }
};

pub const StateChange = struct {
    key: []const u8,
    old_value: ?StateValue,
    new_value: StateValue,
    timestamp: i64,
};

pub const Store = struct {
    state: State,
    actions: std.StringHashMap(Action),
    getters: std.StringHashMap(Getter),
    modules: std.StringHashMap(*Store),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Store {
        return Store{
            .state = State.init(allocator),
            .actions = std.StringHashMap(Action).init(allocator),
            .getters = std.StringHashMap(Getter).init(allocator),
            .modules = std.StringHashMap(*Store).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Store) void {
        self.state.deinit();
        self.actions.deinit();
        self.getters.deinit();

        var module_iter = self.modules.valueIterator();
        while (module_iter.next()) |module| {
            module.*.deinit();
            self.allocator.destroy(module.*);
        }
        self.modules.deinit();
    }

    pub fn registerAction(self: *Store, name: []const u8, action: Action) !void {
        try self.actions.put(name, action);
    }

    pub fn dispatch(self: *Store, action_name: []const u8, payload: ?StateValue) !void {
        if (self.actions.get(action_name)) |action| {
            try action.fn_ptr(&self.state, payload);
        }
    }

    pub fn registerGetter(self: *Store, name: []const u8, getter: Getter) !void {
        try self.getters.put(name, getter);
    }

    pub fn get(self: *Store, getter_name: []const u8) !?StateValue {
        if (self.getters.get(getter_name)) |getter| {
            return try getter.fn_ptr(&self.state);
        }
        return null;
    }

    pub fn registerModule(self: *Store, name: []const u8, module: *Store) !void {
        try self.modules.put(name, module);
    }

    pub fn getModule(self: *Store, name: []const u8) ?*Store {
        return self.modules.get(name);
    }

    pub fn commit(self: *Store, mutation_name: []const u8, payload: ?StateValue) !void {
        _ = mutation_name;
        _ = payload;
        // Implement mutations (synchronous state changes)
        _ = self;
    }
};

pub const Action = struct {
    fn_ptr: *const fn (*State, ?StateValue) anyerror!void,
};

pub const Getter = struct {
    fn_ptr: *const fn (*State) anyerror!StateValue,
};

pub const ReactiveRef = struct {
    state: *State,
    key: []const u8,

    pub fn init(state: *State, key: []const u8) ReactiveRef {
        return ReactiveRef{
            .state = state,
            .key = key,
        };
    }

    pub fn get(self: ReactiveRef) ?StateValue {
        return self.state.get(self.key);
    }

    pub fn set(self: ReactiveRef, value: StateValue) !void {
        try self.state.set(self.key, value);
    }

    pub fn observe(self: ReactiveRef, observer: Observer) !void {
        try self.state.observe(self.key, observer);
    }
};

pub const ComputedRef = struct {
    state: *State,
    key: []const u8,

    pub fn init(state: *State, key: []const u8, fn_ptr: *const fn (*State) anyerror!StateValue, dependencies: []const []const u8) !ComputedRef {
        const computed = try ComputedValue.init(state.allocator, fn_ptr, dependencies);
        try state.addComputed(key, computed);

        return ComputedRef{
            .state = state,
            .key = key,
        };
    }

    pub fn get(self: ComputedRef) !?StateValue {
        return try self.state.getComputed(self.key);
    }
};

pub const WatchCallback = *const fn (StateValue, ?StateValue) void;

pub fn watch(state: *State, key: []const u8, callback: WatchCallback) !void {
    const observer = Observer{
        .id = @intFromPtr(callback),
        .fn_ptr = callback,
    };
    try state.observe(key, observer);
}

pub const Persistence = struct {
    state: *State,
    storage_key: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(state: *State, storage_key: []const u8, allocator: std.mem.Allocator) Persistence {
        return Persistence{
            .state = state,
            .storage_key = storage_key,
            .allocator = allocator,
        };
    }

    pub fn save(self: Persistence) !void {
        _ = self;
        // Would serialize state and save to localStorage/file
    }

    pub fn load(self: Persistence) !void {
        _ = self;
        // Would load and deserialize state from localStorage/file
    }

    pub fn clear(self: Persistence) !void {
        _ = self;
        // Would clear persisted state
    }
};

pub const DevTools = struct {
    state: *State,
    enabled: bool,

    pub fn init(state: *State) DevTools {
        return DevTools{
            .state = state,
            .enabled = true,
        };
    }

    pub fn log(self: DevTools, message: []const u8) void {
        if (self.enabled) {
            std.debug.print("[State DevTools] {s}\n", .{message});
        }
    }

    pub fn logStateChange(self: DevTools, key: []const u8, old_value: ?StateValue, new_value: StateValue) void {
        if (self.enabled) {
            std.debug.print("[State] {s}: ", .{key});
            if (old_value) |old| {
                self.printValue(old);
            } else {
                std.debug.print("undefined", .{});
            }
            std.debug.print(" -> ", .{});
            self.printValue(new_value);
            std.debug.print("\n", .{});
        }
    }

    fn printValue(self: DevTools, value: StateValue) void {
        _ = self;
        switch (value) {
            .int => |v| std.debug.print("{d}", .{v}),
            .float => |v| std.debug.print("{d}", .{v}),
            .bool => |v| std.debug.print("{}", .{v}),
            .string => |v| std.debug.print("\"{s}\"", .{v}),
            .null_value => std.debug.print("null", .{}),
        }
    }

    pub fn getHistory(self: DevTools) []StateChange {
        return self.state.history.changes.items;
    }
};

/// Advanced State Selectors with Memoization
pub const Selector = struct {
    fn_ptr: *const fn (*State) anyerror!StateValue,
    dependencies: []const []const u8,
    last_value: ?StateValue,
    last_dep_values: std.ArrayList(StateValue),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, fn_ptr: *const fn (*State) anyerror!StateValue, dependencies: []const []const u8) !Selector {
        return Selector{
            .fn_ptr = fn_ptr,
            .dependencies = dependencies,
            .last_value = null,
            .last_dep_values = std.ArrayList(StateValue).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Selector) void {
        self.last_dep_values.deinit();
    }

    pub fn select(self: *Selector, state: *State) !StateValue {
        // Check if dependencies changed
        var deps_changed = false;
        var current_dep_values = std.ArrayList(StateValue).init(self.allocator);
        defer current_dep_values.deinit();

        for (self.dependencies) |dep| {
            if (state.get(dep)) |value| {
                try current_dep_values.append(value);
            }
        }

        if (self.last_dep_values.items.len != current_dep_values.items.len) {
            deps_changed = true;
        } else {
            for (self.last_dep_values.items, 0..) |old_val, i| {
                if (!old_val.eql(current_dep_values.items[i])) {
                    deps_changed = true;
                    break;
                }
            }
        }

        // Recompute if dependencies changed
        if (deps_changed or self.last_value == null) {
            const new_value = try self.fn_ptr(state);
            self.last_value = new_value;

            self.last_dep_values.clearRetainingCapacity();
            for (current_dep_values.items) |val| {
                try self.last_dep_values.append(val);
            }

            return new_value;
        }

        return self.last_value.?;
    }
};

/// State Snapshot System for Time-Travel Debugging
pub const StateSnapshot = struct {
    data: std.StringHashMap(StateValue),
    timestamp: i64,
    label: ?[]const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, label: ?[]const u8) StateSnapshot {
        return StateSnapshot{
            .data = std.StringHashMap(StateValue).init(allocator),
            .timestamp = std.time.milliTimestamp(),
            .label = label,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StateSnapshot) void {
        self.data.deinit();
    }

    pub fn capture(self: *StateSnapshot, state: *State) !void {
        var iter = state.data.iterator();
        while (iter.next()) |entry| {
            try self.data.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    pub fn restore(self: *StateSnapshot, state: *State) !void {
        state.data.clearRetainingCapacity();
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            try state.data.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }
};

/// Snapshot Manager for Multiple Snapshots
pub const SnapshotManager = struct {
    snapshots: std.ArrayList(StateSnapshot),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SnapshotManager {
        return SnapshotManager{
            .snapshots = std.ArrayList(StateSnapshot).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SnapshotManager) void {
        for (self.snapshots.items) |*snapshot| {
            snapshot.deinit();
        }
        self.snapshots.deinit();
    }

    pub fn createSnapshot(self: *SnapshotManager, state: *State, label: ?[]const u8) !void {
        var snapshot = StateSnapshot.init(self.allocator, label);
        try snapshot.capture(state);
        try self.snapshots.append(snapshot);
    }

    pub fn restoreSnapshot(self: *SnapshotManager, state: *State, index: usize) !void {
        if (index >= self.snapshots.items.len) return error.InvalidSnapshotIndex;
        try self.snapshots.items[index].restore(state);
    }

    pub fn listSnapshots(self: *SnapshotManager) []StateSnapshot {
        return self.snapshots.items;
    }

    pub fn clearSnapshots(self: *SnapshotManager) void {
        for (self.snapshots.items) |*snapshot| {
            snapshot.deinit();
        }
        self.snapshots.clearRetainingCapacity();
    }
};

/// Batch Update Transaction System
pub const Transaction = struct {
    pending_changes: std.StringHashMap(StateValue),
    state: *State,
    allocator: std.mem.Allocator,
    is_active: bool,

    pub fn init(state: *State, allocator: std.mem.Allocator) Transaction {
        return Transaction{
            .pending_changes = std.StringHashMap(StateValue).init(allocator),
            .state = state,
            .allocator = allocator,
            .is_active = false,
        };
    }

    pub fn deinit(self: *Transaction) void {
        self.pending_changes.deinit();
    }

    pub fn begin(self: *Transaction) void {
        self.is_active = true;
        self.pending_changes.clearRetainingCapacity();
    }

    pub fn set(self: *Transaction, key: []const u8, value: StateValue) !void {
        if (!self.is_active) return error.TransactionNotActive;
        try self.pending_changes.put(key, value);
    }

    pub fn commit(self: *Transaction) !void {
        if (!self.is_active) return error.TransactionNotActive;

        var iter = self.pending_changes.iterator();
        while (iter.next()) |entry| {
            try self.state.set(entry.key_ptr.*, entry.value_ptr.*);
        }

        self.is_active = false;
        self.pending_changes.clearRetainingCapacity();
    }

    pub fn rollback(self: *Transaction) void {
        self.is_active = false;
        self.pending_changes.clearRetainingCapacity();
    }
};

/// Async State Actions with Promises
pub const AsyncAction = struct {
    fn_ptr: *const fn (*State, ?StateValue) anyerror!void,
    pending: bool,
    error_handler: ?*const fn (anyerror) void,

    pub fn init(fn_ptr: *const fn (*State, ?StateValue) anyerror!void) AsyncAction {
        return AsyncAction{
            .fn_ptr = fn_ptr,
            .pending = false,
            .error_handler = null,
        };
    }

    pub fn execute(self: *AsyncAction, state: *State, payload: ?StateValue) !void {
        if (self.pending) return error.ActionAlreadyPending;

        self.pending = true;
        defer self.pending = false;

        self.fn_ptr(state, payload) catch |err| {
            if (self.error_handler) |handler| {
                handler(err);
            }
            return err;
        };
    }

    pub fn onError(self: *AsyncAction, handler: *const fn (anyerror) void) void {
        self.error_handler = handler;
    }
};

/// State Hydration/Dehydration for Persistence
pub const StateSerializer = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) StateSerializer {
        return StateSerializer{
            .allocator = allocator,
        };
    }

    pub fn serialize(self: StateSerializer, state: *State) ![]const u8 {
        _ = self;
        _ = state;
        // Would implement JSON/binary serialization
        return "";
    }

    pub fn deserialize(self: StateSerializer, data: []const u8, state: *State) !void {
        _ = self;
        _ = data;
        _ = state;
        // Would implement JSON/binary deserialization
    }

    pub fn serializeToFile(self: StateSerializer, state: *State, file_path: []const u8) !void {
        const serialized = try self.serialize(state);
        const io = io_context.get();
        const file = try io_context.cwd().createFile(io, file_path, .{});
        defer file.close(io);
        try file.writeStreamingAll(io, serialized);
    }

    pub fn deserializeFromFile(self: StateSerializer, state: *State, file_path: []const u8) !void {
        const io = io_context.get();
        const file = try io_context.cwd().openFile(io, file_path, .{});
        defer file.close(io);

        const file_stat = try file.stat(io);
        const buffer = try self.allocator.alloc(u8, file_stat.size);
        defer self.allocator.free(buffer);

        _ = try file.readPositional(io, &.{buffer}, 0);
        try self.deserialize(buffer, state);
    }
};

/// Computed State with Dependency Tracking
pub const DependencyTracker = struct {
    dependencies: std.StringHashMap(std.ArrayList([]const u8)),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) DependencyTracker {
        return DependencyTracker{
            .dependencies = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DependencyTracker) void {
        var iter = self.dependencies.valueIterator();
        while (iter.next()) |deps| {
            deps.deinit();
        }
        self.dependencies.deinit();
    }

    pub fn addDependency(self: *DependencyTracker, computed_key: []const u8, dependency: []const u8) !void {
        if (self.dependencies.getPtr(computed_key)) |deps| {
            try deps.append(dependency);
        } else {
            var deps = std.ArrayList([]const u8).init(self.allocator);
            try deps.append(dependency);
            try self.dependencies.put(computed_key, deps);
        }
    }

    pub fn getDependents(self: *DependencyTracker, key: []const u8) ![][]const u8 {
        var dependents = std.ArrayList([]const u8).init(self.allocator);
        defer dependents.deinit();

        var iter = self.dependencies.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.items) |dep| {
                if (std.mem.eql(u8, dep, key)) {
                    try dependents.append(entry.key_ptr.*);
                    break;
                }
            }
        }

        return dependents.toOwnedSlice();
    }
};

/// State Effects System
pub const Effect = struct {
    fn_ptr: *const fn (*State) anyerror!void,
    dependencies: []const []const u8,
    cleanup_fn: ?*const fn () void,

    pub fn init(fn_ptr: *const fn (*State) anyerror!void, dependencies: []const []const u8) Effect {
        return Effect{
            .fn_ptr = fn_ptr,
            .dependencies = dependencies,
            .cleanup_fn = null,
        };
    }

    pub fn run(self: *Effect, state: *State) !void {
        try self.fn_ptr(state);
    }

    pub fn cleanup(self: *Effect) void {
        if (self.cleanup_fn) |cleanup| {
            cleanup();
        }
    }

    pub fn onCleanup(self: *Effect, cleanup_fn: *const fn () void) void {
        self.cleanup_fn = cleanup_fn;
    }
};

/// Effect Manager for Running Effects on State Changes
pub const EffectManager = struct {
    effects: std.ArrayList(Effect),
    state: *State,
    allocator: std.mem.Allocator,

    pub fn init(state: *State, allocator: std.mem.Allocator) EffectManager {
        return EffectManager{
            .effects = std.ArrayList(Effect).init(allocator),
            .state = state,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EffectManager) void {
        for (self.effects.items) |*effect| {
            effect.cleanup();
        }
        self.effects.deinit();
    }

    pub fn registerEffect(self: *EffectManager, effect: Effect) !void {
        try self.effects.append(effect);

        // Set up observers for dependencies
        for (effect.dependencies) |dep| {
            const observer = Observer{
                .id = @intFromPtr(effect.fn_ptr),
                .fn_ptr = struct {
                    fn callback(_: StateValue, _: ?StateValue) void {
                        // Would trigger effect re-run
                    }
                }.callback,
            };
            try self.state.observe(dep, observer);
        }
    }

    pub fn runEffects(self: *EffectManager) !void {
        for (self.effects.items) |*effect| {
            try effect.run(self.state);
        }
    }
};
