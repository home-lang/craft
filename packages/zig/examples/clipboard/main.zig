const std = @import("std");
const craft = @import("../../src/main.zig");

/// Clipboard Example
///
/// Demonstrates how to use clipboard operations in Craft:
/// - Write text to clipboard
/// - Read text from clipboard
/// - Write/read HTML
/// - Check clipboard contents
/// - Clear clipboard

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Craft Clipboard Demo ===\n\n", .{});

    var clipboard = craft.ClipboardBridge.init(allocator);
    defer clipboard.deinit();

    // Demo 1: Write text to clipboard
    std.debug.print("1. Writing text to clipboard...\n", .{});
    try clipboard.handleMessageWithData("writeText", "{\"text\":\"Hello from Craft!\"}");
    std.debug.print("   Done!\n", .{});

    std.time.sleep(1 * std.time.ns_per_s);

    // Demo 2: Check if clipboard has text
    std.debug.print("\n2. Checking if clipboard has text...\n", .{});
    try clipboard.handleMessageWithData("hasText", null);

    std.time.sleep(1 * std.time.ns_per_s);

    // Demo 3: Read text from clipboard
    std.debug.print("\n3. Reading text from clipboard...\n", .{});
    try clipboard.handleMessageWithData("readText", null);

    std.time.sleep(1 * std.time.ns_per_s);

    // Demo 4: Write HTML to clipboard
    std.debug.print("\n4. Writing HTML to clipboard...\n", .{});
    try clipboard.handleMessageWithData("writeHTML", "{\"html\":\"<h1>Hello</h1><p>From Craft!</p>\"}");
    std.debug.print("   Done!\n", .{});

    std.time.sleep(1 * std.time.ns_per_s);

    // Demo 5: Clear clipboard
    std.debug.print("\n5. Clearing clipboard...\n", .{});
    try clipboard.handleMessageWithData("clear", null);
    std.debug.print("   Done!\n", .{});

    std.debug.print("\n=== Demo Complete ===\n", .{});
}

// Example: Using clipboard in a web app via JavaScript bridge
// The JavaScript side would call these through the bridge:
//
// ```javascript
// // Write to clipboard
// await craft.invoke('clipboard.writeText', { text: 'Hello!' });
//
// // Read from clipboard
// const result = await craft.invoke('clipboard.readText');
// console.log(result.text);
//
// // Check clipboard contents
// const hasText = await craft.invoke('clipboard.hasText');
// console.log(hasText.value); // true or false
//
// // Clear clipboard
// await craft.invoke('clipboard.clear');
// ```
