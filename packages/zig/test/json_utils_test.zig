const std = @import("std");
const testing = std.testing;
const json_utils = @import("../src/json_utils.zig");

test "getString - basic" {
    const data = "{\"title\":\"Hello World\",\"body\":\"Test message\"}";

    const title = json_utils.getString(data, "title");
    try testing.expect(title != null);
    try testing.expectEqualStrings("Hello World", title.?);

    const body = json_utils.getString(data, "body");
    try testing.expect(body != null);
    try testing.expectEqualStrings("Test message", body.?);
}

test "getString - missing key" {
    const data = "{\"title\":\"Hello\"}";

    const missing = json_utils.getString(data, "nonexistent");
    try testing.expect(missing == null);
}

test "getString - empty value" {
    const data = "{\"title\":\"\"}";

    const title = json_utils.getString(data, "title");
    try testing.expect(title != null);
    try testing.expectEqualStrings("", title.?);
}

test "getInt - positive" {
    const data = "{\"count\":42,\"value\":100}";

    const count = json_utils.getInt(i32, data, "count");
    try testing.expect(count != null);
    try testing.expectEqual(@as(i32, 42), count.?);

    const value = json_utils.getInt(i64, data, "value");
    try testing.expect(value != null);
    try testing.expectEqual(@as(i64, 100), value.?);
}

test "getInt - negative" {
    const data = "{\"offset\":-50}";

    const offset = json_utils.getInt(i32, data, "offset");
    try testing.expect(offset != null);
    try testing.expectEqual(@as(i32, -50), offset.?);
}

test "getInt - missing key" {
    const data = "{\"count\":42}";

    const missing = json_utils.getInt(i32, data, "nonexistent");
    try testing.expect(missing == null);
}

test "getFloat - basic" {
    const data = "{\"ratio\":3.14159,\"scale\":1.5}";

    const ratio = json_utils.getFloat(f64, data, "ratio");
    try testing.expect(ratio != null);
    try testing.expect(@abs(ratio.? - 3.14159) < 0.00001);

    const scale = json_utils.getFloat(f32, data, "scale");
    try testing.expect(scale != null);
    try testing.expect(@abs(scale.? - 1.5) < 0.001);
}

test "getFloat - negative" {
    const data = "{\"temperature\":-20.5}";

    const temp = json_utils.getFloat(f64, data, "temperature");
    try testing.expect(temp != null);
    try testing.expect(@abs(temp.? - -20.5) < 0.001);
}

test "getBool - true" {
    const data = "{\"enabled\":true,\"visible\":true}";

    const enabled = json_utils.getBool(data, "enabled");
    try testing.expect(enabled != null);
    try testing.expect(enabled.? == true);
}

test "getBool - false" {
    const data = "{\"disabled\":false}";

    const disabled = json_utils.getBool(data, "disabled");
    try testing.expect(disabled != null);
    try testing.expect(disabled.? == false);
}

test "getBool - missing key" {
    const data = "{\"enabled\":true}";

    const missing = json_utils.getBool(data, "nonexistent");
    try testing.expect(missing == null);
}

test "hasKey - exists" {
    const data = "{\"name\":\"test\",\"value\":123}";

    try testing.expect(json_utils.hasKey(data, "name"));
    try testing.expect(json_utils.hasKey(data, "value"));
}

test "hasKey - not exists" {
    const data = "{\"name\":\"test\"}";

    try testing.expect(!json_utils.hasKey(data, "missing"));
}

test "escapeJson - no escape needed" {
    const allocator = testing.allocator;

    const escaped = try json_utils.escapeJson(allocator, "Hello World");
    defer allocator.free(escaped);

    try testing.expectEqualStrings("Hello World", escaped);
}

test "escapeJson - quotes" {
    const allocator = testing.allocator;

    const escaped = try json_utils.escapeJson(allocator, "Hello \"World\"");
    defer allocator.free(escaped);

    try testing.expectEqualStrings("Hello \\\"World\\\"", escaped);
}

test "escapeJson - newlines" {
    const allocator = testing.allocator;

    const escaped = try json_utils.escapeJson(allocator, "Line1\nLine2");
    defer allocator.free(escaped);

    try testing.expectEqualStrings("Line1\\nLine2", escaped);
}

test "escapeJson - backslash" {
    const allocator = testing.allocator;

    const escaped = try json_utils.escapeJson(allocator, "path\\to\\file");
    defer allocator.free(escaped);

    try testing.expectEqualStrings("path\\\\to\\\\file", escaped);
}

test "escapeJson - tabs and carriage return" {
    const allocator = testing.allocator;

    const escaped = try json_utils.escapeJson(allocator, "col1\tcol2\r\n");
    defer allocator.free(escaped);

    try testing.expectEqualStrings("col1\\tcol2\\r\\n", escaped);
}

test "JsonBuilder - single string field" {
    const allocator = testing.allocator;

    var builder = json_utils.JsonBuilder(4).init(allocator);
    defer builder.deinit();

    try builder.addString("name", "test");
    const json = try builder.finish();
    defer allocator.free(json);

    try testing.expectEqualStrings("{\"name\":\"test\"}", json);
}

test "JsonBuilder - multiple fields" {
    const allocator = testing.allocator;

    var builder = json_utils.JsonBuilder(4).init(allocator);
    defer builder.deinit();

    try builder.addString("name", "test");
    try builder.addBool("enabled", true);
    try builder.addInt("count", @as(i32, 42));
    const json = try builder.finish();
    defer allocator.free(json);

    try testing.expect(std.mem.indexOf(u8, json, "\"name\":\"test\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"enabled\":true") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"count\":42") != null);
}

test "JsonBuilder - escaped string value" {
    const allocator = testing.allocator;

    var builder = json_utils.JsonBuilder(4).init(allocator);
    defer builder.deinit();

    try builder.addString("message", "Hello \"World\"\nNew line");
    const json = try builder.finish();
    defer allocator.free(json);

    try testing.expect(std.mem.indexOf(u8, json, "\\\"World\\\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\\n") != null);
}

test "complex nested JSON parsing" {
    const data =
        \\{"user":{"name":"John","age":30},"settings":{"theme":"dark","notifications":true}}
    ;

    // Can find top-level keys
    try testing.expect(json_utils.hasKey(data, "user"));
    try testing.expect(json_utils.hasKey(data, "settings"));

    // Can find nested keys (note: simple parser finds first occurrence)
    const name = json_utils.getString(data, "name");
    try testing.expect(name != null);
    try testing.expectEqualStrings("John", name.?);

    const theme = json_utils.getString(data, "theme");
    try testing.expect(theme != null);
    try testing.expectEqualStrings("dark", theme.?);
}
