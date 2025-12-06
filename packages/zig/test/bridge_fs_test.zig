const std = @import("std");
const testing = std.testing;
const bridge_fs = @import("../src/bridge_fs.zig");
const bridge_error = @import("../src/bridge_error.zig");

test "FSBridge - init" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    try testing.expectEqual(allocator, fs.allocator);
}

test "FSBridge - handleMessage unknown action" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    // Unknown action should not crash - it reports error to JS
    try fs.handleMessage("unknownAction", "{}");
}

test "FSBridge - handleMessage exists missing path" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    // Missing path should be handled gracefully
    try fs.handleMessage("exists", "{}");
    try fs.handleMessage("exists", "{\"callbackId\":\"cb1\"}");
}

test "FSBridge - handleMessage readFile missing path" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    // Missing path should be handled gracefully
    try fs.handleMessage("readFile", "{}");
    try fs.handleMessage("readFile", "{\"callbackId\":\"cb1\"}");
}

test "FSBridge - handleMessage writeFile missing data" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    // Missing path should be handled gracefully
    try fs.handleMessage("writeFile", "{}");
    try fs.handleMessage("writeFile", "{\"path\":\"/tmp/test.txt\"}");
}

test "FSBridge - handleMessage appendFile" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    // Should handle missing data gracefully
    try fs.handleMessage("appendFile", "{}");
}

test "FSBridge - handleMessage deleteFile" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    try fs.handleMessage("deleteFile", "{}");
    try fs.handleMessage("deleteFile", "{\"path\":\"/nonexistent/file.txt\"}");
}

test "FSBridge - handleMessage stat" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    try fs.handleMessage("stat", "{}");
    try fs.handleMessage("stat", "{\"path\":\"/nonexistent/file.txt\"}");
}

test "FSBridge - handleMessage readDir" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    try fs.handleMessage("readDir", "{}");
    try fs.handleMessage("readDir", "{\"path\":\"/nonexistent/dir\"}");
}

test "FSBridge - handleMessage mkdir" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    try fs.handleMessage("mkdir", "{}");
    try fs.handleMessage("mkdir", "{\"path\":\"/tmp/test\"}");
    try fs.handleMessage("mkdir", "{\"path\":\"/tmp/test\",\"recursive\":true}");
    try fs.handleMessage("mkdir", "{\"path\":\"/tmp/test\",\"recursive\":false}");
}

test "FSBridge - handleMessage rmdir" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    try fs.handleMessage("rmdir", "{}");
    try fs.handleMessage("rmdir", "{\"path\":\"/nonexistent/dir\"}");
}

test "FSBridge - handleMessage copy" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    try fs.handleMessage("copy", "{}");
    try fs.handleMessage("copy", "{\"src\":\"/tmp/source.txt\"}");
    try fs.handleMessage("copy", "{\"dest\":\"/tmp/dest.txt\"}");
    try fs.handleMessage("copy", "{\"src\":\"/nonexistent/source.txt\",\"dest\":\"/tmp/dest.txt\"}");
}

test "FSBridge - handleMessage move" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    try fs.handleMessage("move", "{}");
    try fs.handleMessage("move", "{\"src\":\"/tmp/source.txt\"}");
    try fs.handleMessage("move", "{\"dest\":\"/tmp/dest.txt\"}");
    try fs.handleMessage("move", "{\"src\":\"/nonexistent/source.txt\",\"dest\":\"/tmp/dest.txt\"}");
}

test "FSBridge - handleMessage watch" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    try fs.handleMessage("watch", "{}");
    try fs.handleMessage("watch", "{\"id\":\"w1\"}");
    try fs.handleMessage("watch", "{\"path\":\"/tmp\"}");
    try fs.handleMessage("watch", "{\"id\":\"w1\",\"path\":\"/tmp\"}");
    try fs.handleMessage("watch", "{\"id\":\"w1\",\"path\":\"/tmp\",\"recursive\":true}");
}

test "FSBridge - handleMessage unwatch" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    // Add a watcher first
    try fs.handleMessage("watch", "{\"id\":\"w1\",\"path\":\"/tmp\",\"callbackId\":\"cb1\"}");

    // Now remove it
    try fs.handleMessage("unwatch", "{\"id\":\"w1\"}");

    // Unwatch non-existent should not crash
    try fs.handleMessage("unwatch", "{\"id\":\"w2\"}");
    try fs.handleMessage("unwatch", "{}");
}

test "FSBridge - handleMessage getHomeDir" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    try fs.handleMessage("getHomeDir", "");
}

test "FSBridge - handleMessage getTempDir" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    try fs.handleMessage("getTempDir", "");
}

test "FSBridge - handleMessage getAppDataDir" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    try fs.handleMessage("getAppDataDir", "");
}

test "FSBridge - watch and unwatch lifecycle" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    // Add multiple watchers
    try fs.handleMessage("watch", "{\"id\":\"w1\",\"path\":\"/tmp/a\",\"callbackId\":\"cb1\"}");
    try fs.handleMessage("watch", "{\"id\":\"w2\",\"path\":\"/tmp/b\",\"callbackId\":\"cb2\"}");
    try fs.handleMessage("watch", "{\"id\":\"w3\",\"path\":\"/tmp/c\",\"callbackId\":\"cb3\",\"recursive\":true}");

    // Remove one
    try fs.handleMessage("unwatch", "{\"id\":\"w2\"}");

    // Remove another
    try fs.handleMessage("unwatch", "{\"id\":\"w1\"}");

    // deinit should clean up remaining watchers
}

test "FSBridge - deinit with watchers" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);

    // Add watchers
    try fs.handleMessage("watch", "{\"id\":\"w1\",\"path\":\"/tmp/a\",\"callbackId\":\"cb1\"}");
    try fs.handleMessage("watch", "{\"id\":\"w2\",\"path\":\"/tmp/b\",\"callbackId\":\"cb2\"}");

    // Should clean up all watchers
    fs.deinit();
}

test "FSBridge - global bridge functions" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    // Test that global functions exist and work
    _ = bridge_fs.getGlobalFSBridge();
    bridge_fs.setGlobalFSBridge(&fs);

    const global = bridge_fs.getGlobalFSBridge();
    try testing.expect(global != null);
}

test "FSBridge - multiple sequential calls" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    // Should handle multiple calls without issues
    try fs.handleMessage("getHomeDir", "");
    try fs.handleMessage("getTempDir", "");
    try fs.handleMessage("getAppDataDir", "");
    try fs.handleMessage("exists", "{\"path\":\"/tmp\",\"callbackId\":\"cb1\"}");
    try fs.handleMessage("watch", "{\"id\":\"w1\",\"path\":\"/tmp\",\"callbackId\":\"cb2\"}");
    try fs.handleMessage("unwatch", "{\"id\":\"w1\"}");
}

test "FSBridge - callback ID extraction" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    // Test various callback ID formats
    try fs.handleMessage("exists", "{\"path\":\"/tmp\",\"callbackId\":\"simple\"}");
    try fs.handleMessage("stat", "{\"path\":\"/tmp\",\"callbackId\":\"with-dashes\"}");
    try fs.handleMessage("readDir", "{\"path\":\"/tmp\",\"callbackId\":\"with_underscores\"}");
    try fs.handleMessage("readFile", "{\"path\":\"/tmp/test.txt\",\"callbackId\":\"123456\"}");
}

test "FSBridge - path extraction" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    // Test various path formats
    try fs.handleMessage("exists", "{\"path\":\"/simple/path\",\"callbackId\":\"cb1\"}");
    try fs.handleMessage("exists", "{\"path\":\"/path/with spaces/file.txt\",\"callbackId\":\"cb2\"}");
    try fs.handleMessage("exists", "{\"path\":\"/path-with-dashes/file\",\"callbackId\":\"cb3\"}");
    try fs.handleMessage("exists", "{\"path\":\"/path_with_underscores/file\",\"callbackId\":\"cb4\"}");
}

test "FSBridge - malformed JSON" {
    const allocator = testing.allocator;
    var fs = bridge_fs.FSBridge.init(allocator);
    defer fs.deinit();

    // Should handle malformed JSON gracefully
    try fs.handleMessage("exists", "not json");
    try fs.handleMessage("readFile", "{invalid}");
    try fs.handleMessage("writeFile", "");
    try fs.handleMessage("mkdir", "{{}}");
}

test "FSBridge - repeated init and deinit" {
    const allocator = testing.allocator;

    // Should be able to create and destroy multiple instances
    var fs1 = bridge_fs.FSBridge.init(allocator);
    fs1.deinit();

    var fs2 = bridge_fs.FSBridge.init(allocator);
    fs2.deinit();

    var fs3 = bridge_fs.FSBridge.init(allocator);
    defer fs3.deinit();

    try fs3.handleMessage("getHomeDir", "");
}
