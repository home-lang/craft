const std = @import("std");

/// Type-safe bridge protocol with auto-generated TypeScript types
/// Ensures type safety across Zig-JavaScript boundary
pub const TypeInfo = struct {
    name: []const u8,
    kind: TypeKind,
    fields: ?[]const FieldInfo = null,
};

pub const TypeKind = enum {
    Void,
    Bool,
    Int,
    Float,
    String,
    Array,
    Object,
    Optional,
    Union,
};

pub const FieldInfo = struct {
    name: []const u8,
    type_info: TypeInfo,
    optional: bool = false,
};

/// Generate TypeScript type definition from Zig type
pub fn generateTypeScript(comptime T: type, allocator: std.mem.Allocator) ![]u8 {
    var buffer: std.ArrayList(u8) = .{};
    const writer = buffer.writer(allocator);

    try writeTypeScriptType(T, writer);

    return try buffer.toOwnedSlice(allocator);
}

fn writeTypeScriptType(comptime T: type, writer: anytype) !void {
    const type_info = @typeInfo(T);

    switch (type_info) {
        .Void => try writer.writeAll("void"),
        .Bool => try writer.writeAll("boolean"),
        .Int => try writer.writeAll("number"),
        .Float => try writer.writeAll("number"),
        .Pointer => |ptr| {
            if (ptr.size == .Slice and ptr.child == u8) {
                try writer.writeAll("string");
            } else {
                try writer.writeAll("Array<");
                try writeTypeScriptType(ptr.child, writer);
                try writer.writeAll(">");
            }
        },
        .Optional => |opt| {
            try writeTypeScriptType(opt.child, writer);
            try writer.writeAll(" | null");
        },
        .Struct => |st| {
            try writer.writeAll("{\n");
            inline for (st.fields) |field| {
                try writer.print("  {s}: ", .{field.name});
                try writeTypeScriptType(field.type, writer);
                try writer.writeAll(";\n");
            }
            try writer.writeAll("}");
        },
        .Union => try writer.writeAll("any"), // Unions become any for simplicity
        .Enum => try writer.writeAll("string"),
        else => try writer.writeAll("unknown"),
    }
}

/// Bridge method definition
pub const BridgeMethod = struct {
    name: []const u8,
    params: []const ParamInfo,
    return_type: TypeInfo,
};

pub const ParamInfo = struct {
    name: []const u8,
    type_info: TypeInfo,
};

/// Auto-generate bridge bindings
pub fn generateBridgeBindings(methods: []const BridgeMethod, allocator: std.mem.Allocator) ![]u8 {
    var buffer: std.ArrayList(u8) = .{};
    const writer = buffer.writer(allocator);

    try writer.writeAll("// Auto-generated TypeScript bridge bindings\n");
    try writer.writeAll("// DO NOT EDIT - Generated from Zig types\n\n");
    try writer.writeAll("export interface CraftBridge {\n");

    for (methods) |method| {
        try writer.print("  {s}(", .{method.name});

        for (method.params, 0..) |param, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.print("{s}: ", .{param.name});
            try writeTypeInfoAsTS(param.type_info, writer);
        }

        try writer.writeAll("): Promise<");
        try writeTypeInfoAsTS(method.return_type, writer);
        try writer.writeAll(">;\n");
    }

    try writer.writeAll("}\n");

    return try buffer.toOwnedSlice(allocator);
}

fn writeTypeInfoAsTS(type_info: TypeInfo, writer: anytype) !void {
    switch (type_info.kind) {
        .Void => try writer.writeAll("void"),
        .Bool => try writer.writeAll("boolean"),
        .Int, .Float => try writer.writeAll("number"),
        .String => try writer.writeAll("string"),
        .Array => try writer.writeAll("Array<any>"),
        .Object => {
            try writer.writeAll("{\n");
            if (type_info.fields) |fields| {
                for (fields) |field| {
                    try writer.print("    {s}: ", .{field.name});
                    try writeTypeInfoAsTS(field.type_info, writer);
                    try writer.writeAll(";\n");
                }
            }
            try writer.writeAll("  }");
        },
        .Optional => try writer.writeAll("any | null"),
        .Union => try writer.writeAll("any"),
    }
}

// Example usage
pub const ExampleDeviceInfo = struct {
    model: []const u8,
    os_version: []const u8,
    platform: []const u8,
    screen_width: u32,
    screen_height: u32,
};

// Tests
test "generate TypeScript for simple struct" {
    const allocator = std.testing.allocator;

    const ts_type = try generateTypeScript(ExampleDeviceInfo, allocator);
    defer allocator.free(ts_type);

    try std.testing.expect(ts_type.len > 0);
}

test "generate bridge bindings" {
    const allocator = std.testing.allocator;

    const methods = [_]BridgeMethod{
        .{
            .name = "getDeviceInfo",
            .params = &[_]ParamInfo{},
            .return_type = .{
                .name = "DeviceInfo",
                .kind = .Object,
                .fields = &[_]FieldInfo{
                    .{ .name = "model", .type_info = .{ .name = "string", .kind = .String } },
                    .{ .name = "platform", .type_info = .{ .name = "string", .kind = .String } },
                },
            },
        },
    };

    const bindings = try generateBridgeBindings(&methods, allocator);
    defer allocator.free(bindings);

    try std.testing.expect(bindings.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, bindings, "getDeviceInfo") != null);
}
