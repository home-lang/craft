const std = @import("std");
const macos = @import("../macos.zig");
const objc = macos.objc;
const compat_mutex = @import("../compat_mutex.zig");

/// Associated object keys for Zig-to-ObjC connections
pub const AssociatedObjectKeys = struct {
    pub const ZigPointer = "com.craft.zigPointer";
    pub const DeallocCallback = "com.craft.deallocCallback";
    pub const EventHandler = "com.craft.eventHandler";
    pub const DataSource = "com.craft.dataSource";
    pub const Delegate = "com.craft.delegate";
};

/// Association policy for associated objects
pub const AssociationPolicy = enum(usize) {
    assign = 0,
    retain_nonatomic = 1,
    copy_nonatomic = 3,
    retain = 0x301,
    copy = 0x303,
};

/// Set an associated object on an ObjC object
pub fn setAssociatedObject(
    object: objc.id,
    key: [*:0]const u8,
    value: ?objc.id,
    policy: AssociationPolicy,
) void {
    const objc_setAssociatedObject = @extern(*const fn (objc.id, [*:0]const u8, ?objc.id, usize) callconv(.c) void, .{
        .name = "objc_setAssociatedObject",
    });
    objc_setAssociatedObject(object, key, value, @intFromEnum(policy));
}

/// Get an associated object from an ObjC object
pub fn getAssociatedObject(object: objc.id, key: [*:0]const u8) ?objc.id {
    const objc_getAssociatedObject = @extern(*const fn (objc.id, [*:0]const u8) callconv(.c) ?objc.id, .{
        .name = "objc_getAssociatedObject",
    });
    return objc_getAssociatedObject(object, key);
}

/// Remove all associated objects from an ObjC object
pub fn removeAssociatedObjects(object: objc.id) void {
    const objc_removeAssociatedObjects = @extern(*const fn (objc.id) callconv(.c) void, .{
        .name = "objc_removeAssociatedObjects",
    });
    objc_removeAssociatedObjects(object);
}

/// Dealloc callback type
pub const DeallocCallback = *const fn (object: objc.id, context: ?*anyopaque) void;

/// Allocation tracker for debugging memory leaks
pub const AllocationTracker = struct {
    const Self = @This();

    allocations: std.AutoHashMap(usize, AllocationInfo),
    mutex: compat_mutex.Mutex,
    total_allocated: usize,
    total_freed: usize,
    peak_allocated: usize,
    allocation_count: usize,

    pub const AllocationInfo = struct {
        size: usize,
        timestamp: i64,
        stack_trace: ?[]const usize,
        type_name: ?[]const u8,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocations = std.AutoHashMap(usize, AllocationInfo).init(allocator),
            .mutex = .{},
            .total_allocated = 0,
            .total_freed = 0,
            .peak_allocated = 0,
            .allocation_count = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocations.deinit();
    }

    pub fn trackAllocation(self: *Self, ptr: usize, size: usize, type_name: ?[]const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.allocations.put(ptr, .{
            .size = size,
            .timestamp = std.time.milliTimestamp(),
            .stack_trace = null,
            .type_name = type_name,
        }) catch {};

        self.total_allocated += size;
        self.allocation_count += 1;
        if (self.total_allocated - self.total_freed > self.peak_allocated) {
            self.peak_allocated = self.total_allocated - self.total_freed;
        }
    }

    pub fn trackDeallocation(self: *Self, ptr: usize) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.allocations.get(ptr)) |info| {
            self.total_freed += info.size;
            _ = self.allocations.remove(ptr);
        }
    }

    pub fn getLeaks(self: *Self, allocator: std.mem.Allocator) ![]AllocationInfo {
        self.mutex.lock();
        defer self.mutex.unlock();

        var leaks = std.ArrayList(AllocationInfo).init(allocator);
        var iter = self.allocations.valueIterator();
        while (iter.next()) |info| {
            try leaks.append(info.*);
        }
        return leaks.toOwnedSlice();
    }

    pub fn getStats(self: *Self) struct { total_allocated: usize, total_freed: usize, peak: usize, current: usize, count: usize } {
        self.mutex.lock();
        defer self.mutex.unlock();

        return .{
            .total_allocated = self.total_allocated,
            .total_freed = self.total_freed,
            .peak = self.peak_allocated,
            .current = self.total_allocated - self.total_freed,
            .count = self.allocation_count,
        };
    }

    pub fn printLeakReport(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.allocations.count() == 0) {
            std.debug.print("No memory leaks detected.\n", .{});
            return;
        }

        std.debug.print("\n=== Memory Leak Report ===\n", .{});
        std.debug.print("Total leaks: {d}\n", .{self.allocations.count()});

        var total_leaked: usize = 0;
        var iter = self.allocations.iterator();
        while (iter.next()) |entry| {
            const info = entry.value_ptr.*;
            total_leaked += info.size;
            std.debug.print("  Leak at 0x{x}: {d} bytes", .{ entry.key_ptr.*, info.size });
            if (info.type_name) |name| {
                std.debug.print(" (type: {s})", .{name});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("Total leaked: {d} bytes\n", .{total_leaked});
    }
};

/// Dynamic class with dealloc implementation
pub const DynamicClassBuilder = struct {
    const Self = @This();

    class: objc.Class,
    dealloc_impl: ?*const fn (objc.id, objc.SEL) callconv(.c) void,
    original_dealloc: ?objc.IMP,

    /// Create a new dynamic class with automatic dealloc handling
    pub fn create(name: [*:0]const u8, superclass: objc.Class) !Self {
        const objc_allocateClassPair = @extern(*const fn (objc.Class, [*:0]const u8, usize) callconv(.c) ?objc.Class, .{
            .name = "objc_allocateClassPair",
        });

        const new_class = objc_allocateClassPair(superclass, name, 0) orelse return error.ClassCreationFailed;

        return Self{
            .class = new_class,
            .dealloc_impl = null,
            .original_dealloc = null,
        };
    }

    /// Add a method to the class
    pub fn addMethod(
        self: *Self,
        selector: objc.SEL,
        implementation: objc.IMP,
        types: [*:0]const u8,
    ) !void {
        const class_addMethod = @extern(*const fn (objc.Class, objc.SEL, objc.IMP, [*:0]const u8) callconv(.c) bool, .{
            .name = "class_addMethod",
        });

        if (!class_addMethod(self.class, selector, implementation, types)) {
            return error.MethodAddFailed;
        }
    }

    /// Set the dealloc implementation
    pub fn setDealloc(self: *Self, dealloc: *const fn (objc.id, objc.SEL) callconv(.c) void) void {
        self.dealloc_impl = dealloc;
    }

    /// Register the class
    pub fn register(self: *Self) void {
        // Add dealloc if specified
        if (self.dealloc_impl) |dealloc| {
            const sel_dealloc = objc.sel_registerName("dealloc");
            self.addMethod(sel_dealloc, @ptrCast(dealloc), "v@:") catch {};
        }

        const objc_registerClassPair = @extern(*const fn (objc.Class) callconv(.c) void, .{
            .name = "objc_registerClassPair",
        });
        objc_registerClassPair(self.class);
    }

    /// Dispose of the class
    pub fn dispose(self: *Self) void {
        const objc_disposeClassPair = @extern(*const fn (objc.Class) callconv(.c) void, .{
            .name = "objc_disposeClassPair",
        });
        objc_disposeClassPair(self.class);
    }
};

/// Reference-counted bridge object wrapper
pub fn BridgeObject(comptime T: type) type {
    return struct {
        const Self = @This();

        data: T,
        ref_count: std.atomic.Value(u32),
        destructor: ?*const fn (*T) void,
        allocator: std.mem.Allocator,

        pub fn create(allocator: std.mem.Allocator, data: T, destructor: ?*const fn (*T) void) !*Self {
            const self = try allocator.create(Self);
            self.* = .{
                .data = data,
                .ref_count = std.atomic.Value(u32).init(1),
                .destructor = destructor,
                .allocator = allocator,
            };
            return self;
        }

        pub fn retain(self: *Self) *Self {
            _ = self.ref_count.fetchAdd(1, .seq_cst);
            return self;
        }

        pub fn release(self: *Self) void {
            const prev = self.ref_count.fetchSub(1, .seq_cst);
            if (prev == 1) {
                if (self.destructor) |dtor| {
                    dtor(&self.data);
                }
                self.allocator.destroy(self);
            }
        }

        pub fn getRefCount(self: *Self) u32 {
            return self.ref_count.load(.seq_cst);
        }
    };
}

/// Autorelease pool wrapper for Zig
pub const AutoreleasePool = struct {
    pool: objc.id,

    pub fn init() AutoreleasePool {
        const NSAutoreleasePool = objc.objc_getClass("NSAutoreleasePool");
        const alloc_sel = objc.sel_registerName("alloc");
        const init_sel = objc.sel_registerName("init");

        const allocated = objc.objc_msgSend(NSAutoreleasePool, alloc_sel);
        const pool = objc.objc_msgSend(allocated, init_sel);

        return .{ .pool = pool };
    }

    pub fn deinit(self: *AutoreleasePool) void {
        const drain_sel = objc.sel_registerName("drain");
        _ = objc.objc_msgSend(self.pool, drain_sel);
    }

    pub fn drain(self: *AutoreleasePool) void {
        const drain_sel = objc.sel_registerName("drain");
        _ = objc.objc_msgSend(self.pool, drain_sel);

        // Recreate pool
        const NSAutoreleasePool = objc.objc_getClass("NSAutoreleasePool");
        const alloc_sel = objc.sel_registerName("alloc");
        const init_sel = objc.sel_registerName("init");

        const allocated = objc.objc_msgSend(NSAutoreleasePool, alloc_sel);
        self.pool = objc.objc_msgSend(allocated, init_sel);
    }
};

/// Weak reference wrapper
pub fn WeakRef(comptime T: type) type {
    return struct {
        const Self = @This();

        ptr: ?*T,
        objc_weak: ?objc.id,

        pub fn init(strong: ?*T) Self {
            return .{
                .ptr = strong,
                .objc_weak = null,
            };
        }

        pub fn initObjC(object: objc.id) Self {
            // Use objc_storeWeak for proper weak reference
            var weak: ?objc.id = null;
            const objc_storeWeak = @extern(*const fn (*?objc.id, ?objc.id) callconv(.c) ?objc.id, .{
                .name = "objc_storeWeak",
            });
            _ = objc_storeWeak(&weak, object);

            return .{
                .ptr = null,
                .objc_weak = weak,
            };
        }

        pub fn get(self: *Self) ?*T {
            return self.ptr;
        }

        pub fn getObjC(self: *Self) ?objc.id {
            if (self.objc_weak) |*weak| {
                const objc_loadWeak = @extern(*const fn (*?objc.id) callconv(.c) ?objc.id, .{
                    .name = "objc_loadWeak",
                });
                return objc_loadWeak(weak);
            }
            return null;
        }

        pub fn clear(self: *Self) void {
            self.ptr = null;
            if (self.objc_weak) |*weak| {
                const objc_storeWeak = @extern(*const fn (*?objc.id, ?objc.id) callconv(.c) ?objc.id, .{
                    .name = "objc_storeWeak",
                });
                _ = objc_storeWeak(weak, null);
            }
        }
    };
}

// Global allocation tracker instance
var global_tracker: ?AllocationTracker = null;

pub fn getGlobalTracker() *AllocationTracker {
    if (global_tracker == null) {
        global_tracker = AllocationTracker.init(std.heap.page_allocator);
    }
    return &global_tracker.?;
}

pub fn deinitGlobalTracker() void {
    if (global_tracker) |*tracker| {
        tracker.printLeakReport();
        tracker.deinit();
        global_tracker = null;
    }
}

// Tests
test "AllocationTracker basic operations" {
    var tracker = AllocationTracker.init(std.testing.allocator);
    defer tracker.deinit();

    tracker.trackAllocation(0x1000, 100, "TestType");
    tracker.trackAllocation(0x2000, 200, null);

    const stats = tracker.getStats();
    try std.testing.expectEqual(@as(usize, 300), stats.total_allocated);
    try std.testing.expectEqual(@as(usize, 2), stats.count);

    tracker.trackDeallocation(0x1000);
    const stats2 = tracker.getStats();
    try std.testing.expectEqual(@as(usize, 100), stats2.total_freed);
}

test "BridgeObject reference counting" {
    const TestData = struct { value: i32 };

    var destroyed = false;
    const obj = try BridgeObject(TestData).create(std.testing.allocator, .{ .value = 42 }, struct {
        fn dtor(data: *TestData) void {
            _ = data;
            // Would set destroyed = true but can't capture
        }
    }.dtor);

    try std.testing.expectEqual(@as(u32, 1), obj.getRefCount());

    const retained = obj.retain();
    try std.testing.expectEqual(@as(u32, 2), retained.getRefCount());

    obj.release();
    try std.testing.expectEqual(@as(u32, 1), retained.getRefCount());

    retained.release();
    // Object should be destroyed now

    _ = destroyed;
}
