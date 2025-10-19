const std = @import("std");
const testing = std.testing;
const wasm = @import("../src/wasm.zig");

// WasmValue tests
test "WasmValue - i32 variant" {
    const value = wasm.WasmValue{ .i32 = 42 };
    try testing.expectEqual(@as(i32, 42), try value.asI32());
}

test "WasmValue - i64 variant" {
    const value = wasm.WasmValue{ .i64 = 1234567890 };
    try testing.expectEqual(@as(i64, 1234567890), try value.asI64());
}

test "WasmValue - f32 variant" {
    const value = wasm.WasmValue{ .f32 = 3.14 };
    try testing.expectEqual(@as(f32, 3.14), try value.asF32());
}

test "WasmValue - f64 variant" {
    const value = wasm.WasmValue{ .f64 = 2.718281828 };
    try testing.expectEqual(@as(f64, 2.718281828), try value.asF64());
}

test "WasmValue - type mismatch i32" {
    const value = wasm.WasmValue{ .f32 = 3.14 };
    try testing.expectError(error.TypeMismatch, value.asI32());
}

test "WasmValue - type mismatch i64" {
    const value = wasm.WasmValue{ .i32 = 42 };
    try testing.expectError(error.TypeMismatch, value.asI64());
}

test "WasmValue - type mismatch f32" {
    const value = wasm.WasmValue{ .i64 = 100 };
    try testing.expectError(error.TypeMismatch, value.asF32());
}

test "WasmValue - type mismatch f64" {
    const value = wasm.WasmValue{ .i32 = 42 };
    try testing.expectError(error.TypeMismatch, value.asF64());
}

// WasmType tests
test "WasmType - all types" {
    try testing.expectEqual(wasm.WasmType.i32, .i32);
    try testing.expectEqual(wasm.WasmType.i64, .i64);
    try testing.expectEqual(wasm.WasmType.f32, .f32);
    try testing.expectEqual(wasm.WasmType.f64, .f64);
    try testing.expectEqual(wasm.WasmType.funcref, .funcref);
    try testing.expectEqual(wasm.WasmType.externref, .externref);
}

// WasmModule tests
test "WasmModule - initialization" {
    const allocator = testing.allocator;
    const bytes = "\x00asm\x01\x00\x00\x00";

    var module = try wasm.WasmModule.init(allocator, "test-module", bytes);
    defer module.deinit();

    try testing.expectEqualStrings("test-module", module.name);
    try testing.expectEqual(@as(?*anyopaque, null), module.instance);
}

test "WasmModule - load valid magic" {
    const allocator = testing.allocator;
    const bytes = "\x00asm\x01\x00\x00\x00";

    var module = try wasm.WasmModule.init(allocator, "test", bytes);
    defer module.deinit();

    try module.load();
}

test "WasmModule - load invalid magic" {
    const allocator = testing.allocator;
    const bytes = "invalid!";

    var module = try wasm.WasmModule.init(allocator, "test", bytes);
    defer module.deinit();

    try testing.expectError(error.InvalidWasm, module.load());
}

test "WasmModule - load too short" {
    const allocator = testing.allocator;
    const bytes = "abc";

    var module = try wasm.WasmModule.init(allocator, "test", bytes);
    defer module.deinit();

    try testing.expectError(error.InvalidWasm, module.load());
}

// WasmRuntime tests
test "WasmRuntime - initialization" {
    const allocator = testing.allocator;
    var runtime = wasm.WasmRuntime.init(allocator);
    defer runtime.deinit();

    try testing.expectEqual(@as(usize, 0), runtime.modules.count());
}

// WasmParser tests
test "WasmParser - initialization" {
    const bytes = "\x00asm\x01\x00\x00\x00";
    const parser = wasm.WasmParser.init(bytes);

    try testing.expectEqual(@as(usize, 0), parser.position);
    try testing.expectEqual(@as(usize, 8), parser.bytes.len);
}

test "WasmParser - readByte" {
    const bytes = "\x00\x01\x02\x03";
    var parser = wasm.WasmParser.init(bytes);

    try testing.expectEqual(@as(u8, 0x00), try parser.readByte());
    try testing.expectEqual(@as(u8, 0x01), try parser.readByte());
    try testing.expectEqual(@as(u8, 0x02), try parser.readByte());
    try testing.expectEqual(@as(u8, 0x03), try parser.readByte());
}

test "WasmParser - readByte EOF" {
    const bytes = "a";
    var parser = wasm.WasmParser.init(bytes);

    _ = try parser.readByte();
    try testing.expectError(error.UnexpectedEOF, parser.readByte());
}

test "WasmParser - readU32" {
    const bytes = "\x05";
    var parser = wasm.WasmParser.init(bytes);

    const value = try parser.readU32();
    try testing.expectEqual(@as(u32, 5), value);
}

test "WasmParser - readBytes" {
    const bytes = "hello world";
    var parser = wasm.WasmParser.init(bytes);

    const slice = try parser.readBytes(5);
    try testing.expectEqualStrings("hello", slice);
}

test "WasmParser - readBytes EOF" {
    const bytes = "abc";
    var parser = wasm.WasmParser.init(bytes);

    try testing.expectError(error.UnexpectedEOF, parser.readBytes(10));
}

test "WasmParser - checkMagic valid" {
    const bytes = "\x00asm\x01\x00\x00\x00";
    var parser = wasm.WasmParser.init(bytes);

    try parser.checkMagic();
}

test "WasmParser - checkMagic invalid" {
    const bytes = "invalid!";
    var parser = wasm.WasmParser.init(bytes);

    try testing.expectError(error.InvalidMagic, parser.checkMagic());
}

// PluginAPI tests
test "PluginAPI - getCurrentTime" {
    const time1 = wasm.PluginAPI.getCurrentTime();
    const time2 = wasm.PluginAPI.getCurrentTime();

    try testing.expect(time2 >= time1);
}

// PluginManager tests
test "PluginManager - initialization" {
    const allocator = testing.allocator;
    var manager = wasm.PluginManager.init(allocator);
    defer manager.deinit();

    try testing.expectEqual(@as(usize, 0), manager.plugins.count());
}

// PluginSandbox tests
test "PluginSandbox - initialization" {
    const allocator = testing.allocator;
    var sandbox = wasm.PluginSandbox.init(allocator, 1024 * 1024, 1000);
    defer sandbox.deinit();

    try testing.expectEqual(@as(usize, 1024 * 1024), sandbox.memory_limit);
    try testing.expectEqual(@as(u64, 1000), sandbox.cpu_time_limit);
}

test "PluginSandbox - allowAPI" {
    const allocator = testing.allocator;
    var sandbox = wasm.PluginSandbox.init(allocator, 1024, 1000);
    defer sandbox.deinit();

    try sandbox.allowAPI("console.log");
    try testing.expect(sandbox.isAPIAllowed("console.log"));
}

test "PluginSandbox - isAPIAllowed default false" {
    const allocator = testing.allocator;
    var sandbox = wasm.PluginSandbox.init(allocator, 1024, 1000);
    defer sandbox.deinit();

    try testing.expect(!sandbox.isAPIAllowed("unknown.api"));
}

test "PluginSandbox - checkMemoryLimit under" {
    const allocator = testing.allocator;
    const sandbox = wasm.PluginSandbox.init(allocator, 1024, 1000);

    try testing.expect(sandbox.checkMemoryLimit(512));
}

test "PluginSandbox - checkMemoryLimit at" {
    const allocator = testing.allocator;
    const sandbox = wasm.PluginSandbox.init(allocator, 1024, 1000);

    try testing.expect(sandbox.checkMemoryLimit(1024));
}

test "PluginSandbox - checkMemoryLimit over" {
    const allocator = testing.allocator;
    const sandbox = wasm.PluginSandbox.init(allocator, 1024, 1000);

    try testing.expect(!sandbox.checkMemoryLimit(2048));
}

test "PluginSandbox - multiple APIs" {
    const allocator = testing.allocator;
    var sandbox = wasm.PluginSandbox.init(allocator, 1024, 1000);
    defer sandbox.deinit();

    try sandbox.allowAPI("api1");
    try sandbox.allowAPI("api2");
    try sandbox.allowAPI("api3");

    try testing.expect(sandbox.isAPIAllowed("api1"));
    try testing.expect(sandbox.isAPIAllowed("api2"));
    try testing.expect(sandbox.isAPIAllowed("api3"));
    try testing.expect(!sandbox.isAPIAllowed("api4"));
}
