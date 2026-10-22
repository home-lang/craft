//! Authorized native sharing indicators for browsers and conferencing apps.
//! Browser web content and conferencing chat/message lists are excluded.
//! All IPC runs on a bounded worker, never on the UI thread.
const std = @import("std");
const builtin = @import("builtin");
const detect = @import("screen_sharing.zig");

pub fn matches(bundle_id: []const u8, title: []const u8) bool {
    if (!std.mem.eql(u8, bundle_id, "com.google.Chrome")) return false;
    const suffix = " - Tab content shared - Google Chrome";
    return title.len >= suffix.len and detect.containsIgnoreCase(title[title.len - suffix.len ..], suffix);
}

/// The caller supplies an autorelease pool and runs off AppKit's main thread.
/// A stalled browser gets a short IPC timeout and cannot stall other UI work.
pub fn visit(context: anytype, comptime onWindow: anytype) !void {
    if (comptime builtin.os.tag != .macos) return;
    if (!AXIsProcessTrusted()) return;
    const macos = @import("macos.zig");
    const io = @import("io_context.zig").get();
    const workspace = macos.msgSend0(macos.getClass("NSWorkspace"), "sharedWorkspace");
    const apps = macos.msgSend0(workspace, "runningApplications");
    const Count = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_ulong;
    const count: Count = @ptrCast(&macos.objc.objc_msgSend);
    const Pid = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_int;
    const pid: Pid = @ptrCast(&macos.objc.objc_msgSend);
    var index: c_ulong = 0;
    while (index < count(apps, macos.sel("count"))) : (index += 1) {
        const app = macos.msgSend1(apps, "objectAtIndex:", index);
        const bundle_id = string(macos.msgSend0(app, "bundleIdentifier")) orelse continue;
        const provider = providerFor(bundle_id) orelse continue;
        // An unrelated browser with many windows must not consume another
        // application's detection budget. Each trusted app gets bounded IPC.
        const deadline = std.Io.Clock.awake.now(io).nanoseconds + 750 * std.time.ns_per_ms;
        const element = AXUIElementCreateApplication(pid(app, macos.sel("processIdentifier"))) orelse continue;
        defer CFRelease(element);
        _ = AXUIElementSetMessagingTimeout(element, 0.05);
        if (provider == .discord or provider == .slack) enableElectronAccessibility(element);
        var windows: ?*anyopaque = null;
        if (AXUIElementCopyAttributeValue(element, macos.createNSString("AXWindows"), &windows) != 0 or windows == null) continue;
        defer CFRelease(windows);
        const length = @min(CFArrayGetCount(windows), 128);
        var ordered: [128]?*anyopaque = undefined;
        var window_index: c_long = 0;
        while (window_index < length) : (window_index += 1)
            ordered[@intCast(window_index)] = CFArrayGetValueAtIndex(windows, window_index);
        // Slack's floating capture toolbar is much cheaper to inspect than
        // its full workspace. Read that live surface before huddle windows.
        var floating_slack = false;
        if (provider == .slack) {
            window_index = 0;
            while (window_index < length and std.Io.Clock.awake.now(io).nanoseconds < deadline) : (window_index += 1) {
                const window = ordered[@intCast(window_index)] orelse continue;
                _ = AXUIElementSetMessagingTimeout(window, 0.05);
                const title = copyAttribute(window, "AXTitle") orelse continue;
                defer CFRelease(title);
                if (!std.mem.eql(u8, string(title) orelse continue, "Slack")) continue;
                std.mem.swap(?*anyopaque, &ordered[0], &ordered[@intCast(window_index)]);
                floating_slack = true;
                break;
            }
        }
        window_index = 0;
        while (window_index < length) : (window_index += 1) {
            if (std.Io.Clock.awake.now(io).nanoseconds >= deadline) break;
            const window = ordered[@intCast(window_index)] orelse continue;
            _ = AXUIElementSetMessagingTimeout(window, 0.05);
            if (provider == .dia) {
                var reader = NativeBannerReader{ .deadline = deadline };
                if (reader.containsBanner(window, 0)) {
                    try onWindow(context, "Dia", "Browser tab sharing");
                    break;
                }
                continue;
            }
            if (provider == .discord or provider == .slack) {
                var reader = NativeBannerReader{ .deadline = deadline, .remaining = 512 };
                if (reader.containsConferenceControl(window, 0, false, provider, floating_slack and window_index == 0)) {
                    try onWindow(context, if (provider == .discord) "Discord" else "Slack", "Screen sharing controls");
                    break;
                }
                continue;
            }
            var title: ?*anyopaque = null;
            if (AXUIElementCopyAttributeValue(window, macos.createNSString("AXTitle"), &title) != 0 or title == null) continue;
            defer CFRelease(title);
            const text = string(title) orelse continue;
            if (matches(bundle_id, text)) {
                try onWindow(context, "Google Chrome", text);
                break;
            }
        }
    }
}

/// Both controls must belong to the same native surface. A page can contain
/// identical words, so AXWebArea descendants are excluded before traversal.
const Banner = struct {
    sharing: bool = false,
    stop: bool = false,
    other_tab: bool = false,
    switch_tab: bool = false,

    fn observe(self: *Banner, role: []const u8, label: []const u8) void {
        if (std.mem.eql(u8, role, "AXStaticText") and std.mem.eql(u8, label, "Sharing this tab")) self.sharing = true;
        if (std.mem.eql(u8, role, "AXButton") and std.mem.eql(u8, label, "Stop Sharing")) self.stop = true;
        if (std.mem.eql(u8, role, "AXStaticText") and std.mem.startsWith(u8, label, "Sharing ") and
            !std.mem.eql(u8, label, "Sharing this tab") and std.mem.indexOf(u8, label, " — ") != null) self.other_tab = true;
        if (std.mem.eql(u8, role, "AXButton") and std.mem.eql(u8, label, "Share This Tab")) self.switch_tab = true;
    }

    fn active(self: Banner) bool {
        return (self.sharing and self.stop) or (self.other_tab and self.switch_tab);
    }
};

/// Slack's compact huddle moves capture controls into a separate app-owned
/// "Slack" window. Require both controls in its toolbar, never chat labels.
const SlackShareControls = struct {
    stop: bool = false,
    draw: bool = false,

    fn observe(self: *SlackShareControls, role: []const u8, label: []const u8) void {
        if (std.mem.eql(u8, role, "AXButton") and std.mem.eql(u8, label, "Stop sharing your screen")) self.stop = true;
        if (std.mem.eql(u8, role, "AXCheckBox") and std.mem.eql(u8, label, "Draw on your own screen")) self.draw = true;
    }

    fn active(self: SlackShareControls) bool {
        return self.stop and self.draw;
    }
};

const NativeBannerReader = struct {
    deadline: i96,
    remaining: usize = 256,

    fn containsBanner(self: *NativeBannerReader, element: ?*anyopaque, depth: usize) bool {
        if (depth > 6 or self.remaining == 0 or self.expired()) return false;
        self.remaining -= 1;
        _ = AXUIElementSetMessagingTimeout(element, 0.05);
        const role = copyAttribute(element, "AXRole") orelse return false;
        defer CFRelease(role);
        if (!nativeContainer(string(role) orelse return false)) return false;
        const children = copyAttribute(element, "AXChildren") orelse return false;
        defer CFRelease(children);
        if (CFGetTypeID(children) != CFArrayGetTypeID()) return false;
        const length = @min(CFArrayGetCount(children), 128);
        var banner = Banner{};
        var index: c_long = 0;
        while (index < length and self.remaining > 0 and !self.expired()) : (index += 1) {
            const child = CFArrayGetValueAtIndex(children, index) orelse continue;
            self.remaining -= 1;
            _ = AXUIElementSetMessagingTimeout(child, 0.05);
            const child_role = copyAttribute(child, "AXRole") orelse continue;
            defer CFRelease(child_role);
            const role_text = string(child_role) orelse continue;
            // Do not read labels from web content, including its root.
            if (!std.mem.eql(u8, role_text, "AXStaticText") and !std.mem.eql(u8, role_text, "AXButton")) continue;
            for ([_][:0]const u8{ "AXTitle", "AXDescription", "AXValue" }) |attribute| {
                if (self.expired()) return false;
                const label = copyAttribute(child, attribute) orelse continue;
                defer CFRelease(label);
                banner.observe(role_text, string(label) orelse continue);
            }
            if (banner.active()) return true;
        }
        index = 0;
        while (index < length and !self.expired()) : (index += 1) {
            if (self.containsBanner(CFArrayGetValueAtIndex(children, index), depth + 1)) return true;
        }
        return false;
    }

    /// App-owned voice controls are outside message lists. Never
    /// infer sharing from arbitrary chat text or controls elsewhere in the app.
    fn containsConferenceControl(self: *NativeBannerReader, element: ?*anyopaque, depth: usize, within_panel: bool, provider: Provider, floating_slack: bool) bool {
        if (depth > 24 or self.remaining == 0 or self.expired()) return false;
        self.remaining -= 1;
        _ = AXUIElementSetMessagingTimeout(element, 0.05);
        const role_value = copyAttribute(element, "AXRole") orelse return false;
        defer CFRelease(role_value);
        const role = string(role_value) orelse return false;
        if (floating_slack and std.mem.eql(u8, role, "AXToolbar")) {
            var controls = SlackShareControls{};
            if (self.containsSlackShareControls(element, 0, &controls)) return true;
        }
        const control = std.mem.eql(u8, role, "AXButton") or std.mem.eql(u8, role, "AXCheckBox");
        if (within_panel and control) return hasLabel(element, if (provider == .discord) "Stop Streaming" else "Stop sharing screen");
        // Electron exposes its application UI as AXWebArea. Lists, outlines,
        // message text, editors and arbitrary buttons are not traversed.
        if (!conferenceContainer(role)) return false;
        const scope_role = if (provider == .discord) "AXGroup" else "AXToolbar";
        const scope_label = if (provider == .discord) "User status and settings" else "Huddles actions";
        const in_panel = within_panel or (std.mem.eql(u8, role, scope_role) and hasLabel(element, scope_label));
        const children = copyAttribute(element, "AXChildren") orelse return false;
        defer CFRelease(children);
        if (CFGetTypeID(children) != CFArrayGetTypeID()) return false;
        const length = @min(CFArrayGetCount(children), 128);
        var index: c_long = 0;
        while (index < length and !self.expired()) : (index += 1) {
            if (self.containsConferenceControl(CFArrayGetValueAtIndex(children, index), depth + 1, in_panel, provider, floating_slack)) return true;
        }
        return false;
    }

    fn containsSlackShareControls(self: *NativeBannerReader, element: ?*anyopaque, depth: usize, controls: *SlackShareControls) bool {
        if (depth > 4 or self.remaining == 0 or self.expired()) return false;
        const children = copyAttribute(element, "AXChildren") orelse return false;
        defer CFRelease(children);
        if (CFGetTypeID(children) != CFArrayGetTypeID()) return false;
        const length = @min(CFArrayGetCount(children), 128);
        var index: c_long = 0;
        while (index < length and self.remaining > 0 and !self.expired()) : (index += 1) {
            self.remaining -= 1;
            const child = CFArrayGetValueAtIndex(children, index) orelse continue;
            _ = AXUIElementSetMessagingTimeout(child, 0.05);
            const role_value = copyAttribute(child, "AXRole") orelse continue;
            defer CFRelease(role_value);
            const role = string(role_value) orelse continue;
            // Electron wraps individual toolbar controls in presentation
            // groups. Stay inside this toolbar; lists, editors, nested web
            // areas and other toolbars cannot contribute matching labels.
            if (std.mem.eql(u8, role, "AXGroup")) {
                if (self.containsSlackShareControls(child, depth + 1, controls)) return true;
                continue;
            }
            if (!std.mem.eql(u8, role, "AXButton") and !std.mem.eql(u8, role, "AXCheckBox")) continue;
            for ([_][:0]const u8{ "AXTitle", "AXDescription", "AXValue" }) |attribute| {
                if (self.expired()) return false;
                const label = copyAttribute(child, attribute) orelse continue;
                defer CFRelease(label);
                controls.observe(role, string(label) orelse continue);
            }
            if (controls.active()) return true;
        }
        return false;
    }

    fn expired(self: *NativeBannerReader) bool {
        return std.Io.Clock.awake.now(@import("io_context.zig").get()).nanoseconds >= self.deadline;
    }
};

fn nativeContainer(role: []const u8) bool {
    return std.mem.eql(u8, role, "AXWindow") or std.mem.eql(u8, role, "AXGroup") or
        std.mem.eql(u8, role, "AXScrollArea") or std.mem.eql(u8, role, "AXSplitGroup");
}

const Provider = enum { chrome, dia, discord, slack };

fn providerFor(bundle_id: []const u8) ?Provider {
    if (std.mem.eql(u8, bundle_id, "com.google.Chrome")) return .chrome;
    if (std.mem.eql(u8, bundle_id, "company.thebrowser.dia")) return .dia;
    if (std.mem.eql(u8, bundle_id, "com.hnc.Discord")) return .discord;
    if (std.mem.eql(u8, bundle_id, "com.tinyspeck.slackmacgap")) return .slack;
    return null;
}

fn conferenceContainer(role: []const u8) bool {
    return nativeContainer(role) or std.mem.eql(u8, role, "AXWebArea") or std.mem.eql(u8, role, "AXToolbar");
}

fn hasLabel(element: ?*anyopaque, label: []const u8) bool {
    for ([_][:0]const u8{ "AXTitle", "AXDescription", "AXValue" }) |attribute| {
        const value = copyAttribute(element, attribute) orelse continue;
        defer CFRelease(value);
        if (std.mem.eql(u8, string(value) orelse continue, label)) return true;
    }
    return false;
}

fn enableElectronAccessibility(element: ?*anyopaque) void {
    // Electron's documented third-party accessibility interface, not a
    // command-line switch or injected renderer script:
    // https://www.electronjs.org/docs/latest/tutorial/accessibility
    if (copyAttribute(element, "AXManualAccessibility")) |enabled| {
        defer CFRelease(enabled);
        if (CFGetTypeID(enabled) == CFBooleanGetTypeID() and CFBooleanGetValue(enabled)) return;
    }
    _ = AXUIElementSetAttributeValue(element, @import("macos.zig").createNSString("AXManualAccessibility"), kCFBooleanTrue);
}

fn copyAttribute(element: ?*anyopaque, name: [:0]const u8) ?*anyopaque {
    var value: ?*anyopaque = null;
    if (AXUIElementCopyAttributeValue(element, @import("macos.zig").createNSString(name), &value) != 0) return null;
    return value;
}

fn string(value: ?*anyopaque) ?[]const u8 {
    if (value == null or CFGetTypeID(value) != CFStringGetTypeID()) return null;
    const macos = @import("macos.zig");
    const utf8 = macos.msgSend0(value, "UTF8String");
    if (utf8 == null) return null;
    return std.mem.span(@as([*:0]const u8, @ptrCast(utf8)));
}

extern "c" fn AXIsProcessTrusted() bool;
extern "c" fn AXUIElementCreateApplication(pid: c_int) ?*anyopaque;
extern "c" fn AXUIElementSetMessagingTimeout(element: ?*anyopaque, timeout: f32) c_int;
extern "c" fn AXUIElementCopyAttributeValue(element: ?*anyopaque, attribute: ?*anyopaque, value: *?*anyopaque) c_int;
extern "c" fn AXUIElementSetAttributeValue(element: ?*anyopaque, attribute: ?*anyopaque, value: ?*anyopaque) c_int;
extern "c" var kCFBooleanTrue: ?*anyopaque;
extern "c" fn CFBooleanGetTypeID() c_ulong;
extern "c" fn CFBooleanGetValue(value: ?*anyopaque) bool;
extern "c" fn CFArrayGetCount(array: ?*anyopaque) c_long;
extern "c" fn CFArrayGetValueAtIndex(array: ?*anyopaque, index: c_long) ?*anyopaque;
extern "c" fn CFGetTypeID(value: ?*anyopaque) c_ulong;
extern "c" fn CFStringGetTypeID() c_ulong;
extern "c" fn CFArrayGetTypeID() c_ulong;
extern "c" fn CFRelease(value: ?*anyopaque) void;

test "tab capture requires Chrome's native sharing suffix" {
    try std.testing.expect(matches("com.google.Chrome", "Hush capture check - Tab content shared - Google Chrome"));
    try std.testing.expect(!matches("com.google.Chrome", "Tab content shared - Google Chrome"));
    try std.testing.expect(!matches("com.google.Chrome", "Hush capture check - Google Chrome"));
    try std.testing.expect(!matches("com.apple.TextEdit", "Hush capture check - Tab content shared - Google Chrome"));
    try std.testing.expect(!matches("com.google.Chrome", "Hush capture check - Tab content shared - Google Chrome Notes"));
}

test "Dia requires both native controls on one surface" {
    var banner = Banner{};
    banner.observe("AXStaticText", "Sharing this tab");
    try std.testing.expect(!banner.active());
    banner.observe("AXButton", "Stop Sharing");
    try std.testing.expect(banner.active());
    var wrong_roles = Banner{};
    wrong_roles.observe("AXButton", "Sharing this tab");
    wrong_roles.observe("AXStaticText", "Stop Sharing");
    try std.testing.expect(!wrong_roles.active());
    var wrong_labels = Banner{};
    wrong_labels.observe("AXStaticText", "Sharing this tab soon");
    wrong_labels.observe("AXButton", "Stop Sharing");
    try std.testing.expect(!wrong_labels.active());
    try std.testing.expect(nativeContainer("AXWindow"));
    try std.testing.expect(nativeContainer("AXGroup"));
    try std.testing.expect(!nativeContainer("AXWebArea"));
    try std.testing.expect(!nativeContainer("AXStaticText"));
}

test "Dia keeps detecting capture when another tab is selected" {
    var banner = Banner{};
    banner.observe("AXStaticText", "Sharing Hush capture check — 127.0.0.1");
    try std.testing.expect(!banner.active());
    banner.observe("AXButton", "Share This Tab");
    try std.testing.expect(banner.active());
    var mixed = Banner{};
    mixed.observe("AXStaticText", "Sharing this tab");
    mixed.observe("AXButton", "Share This Tab");
    try std.testing.expect(!mixed.active());
}

test "only trusted app identities can expose conferencing renderer controls" {
    try std.testing.expectEqual(Provider.discord, providerFor("com.hnc.Discord").?);
    try std.testing.expectEqual(Provider.slack, providerFor("com.tinyspeck.slackmacgap").?);
    try std.testing.expect(providerFor("com.example.Discord") == null);
    try std.testing.expect(providerFor("com.google.Chrome.beta") == null);
    try std.testing.expect(conferenceContainer("AXWebArea"));
    try std.testing.expect(!conferenceContainer("AXList"));
    try std.testing.expect(!conferenceContainer("AXOutline"));
    try std.testing.expect(!conferenceContainer("AXTextArea"));
    try std.testing.expect(!conferenceContainer("AXStaticText"));
    try std.testing.expect(!conferenceContainer("AXButton"));
}

test "Slack floating capture toolbar requires its stop and drawing controls" {
    var controls = SlackShareControls{};
    controls.observe("AXButton", "Stop sharing your screen");
    try std.testing.expect(!controls.active());
    controls.observe("AXCheckBox", "Draw on your own screen");
    try std.testing.expect(controls.active());

    var chat = SlackShareControls{};
    chat.observe("AXStaticText", "Stop sharing your screen");
    chat.observe("AXStaticText", "Draw on your own screen");
    try std.testing.expect(!chat.active());

    var idle = SlackShareControls{};
    idle.observe("AXButton", "Share your screen");
    idle.observe("AXButton", "Draw on your own screen");
    try std.testing.expect(!idle.active());

    var wrong_stop = SlackShareControls{};
    wrong_stop.observe("AXCheckBox", "Stop sharing your screen");
    wrong_stop.observe("AXSwitch", "Draw on your own screen");
    try std.testing.expect(!wrong_stop.active());

    var wrong_draw = SlackShareControls{};
    wrong_draw.observe("AXButton", "Stop sharing your screen");
    wrong_draw.observe("AXButton", "Draw on your own screen");
    try std.testing.expect(!wrong_draw.active());
}
