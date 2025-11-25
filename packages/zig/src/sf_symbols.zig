const std = @import("std");
const builtin = @import("builtin");

/// SF Symbols support for macOS
/// Provides access to Apple's SF Symbols icon library
/// Available on macOS 11.0+ (Big Sur and later)

pub const SFSymbolError = error{
    PlatformNotSupported,
    SymbolNotFound,
    InvalidConfiguration,
};

/// SF Symbol configuration
pub const SymbolConfiguration = struct {
    /// Point size for the symbol
    point_size: ?f64 = null,

    /// Weight of the symbol
    weight: Weight = .regular,

    /// Scale of the symbol relative to surrounding text
    scale: Scale = .medium,

    /// Rendering mode
    rendering_mode: RenderingMode = .monochrome,

    /// Primary color (for hierarchical/palette modes)
    primary_color: ?Color = null,

    /// Secondary color (for palette mode)
    secondary_color: ?Color = null,

    /// Tertiary color (for palette mode)
    tertiary_color: ?Color = null,

    pub const Weight = enum {
        ultralight,
        thin,
        light,
        regular,
        medium,
        semibold,
        bold,
        heavy,
        black,
    };

    pub const Scale = enum {
        small,
        medium,
        large,
    };

    pub const RenderingMode = enum {
        monochrome,
        hierarchical,
        palette,
        multicolor,
    };

    pub const Color = struct {
        r: f64,
        g: f64,
        b: f64,
        a: f64 = 1.0,
    };
};

/// SF Symbol representation
pub const SFSymbol = struct {
    name: []const u8,
    config: SymbolConfiguration,
    platform_handle: ?*anyopaque = null,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !Self {
        if (builtin.target.os.tag != .macos) {
            return SFSymbolError.PlatformNotSupported;
        }

        return Self{
            .name = try allocator.dupe(u8, name),
            .config = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        if (self.platform_handle) |handle| {
            releasePlatformHandle(handle);
        }
    }

    /// Create NSImage for this symbol
    pub fn createImage(self: *Self) !*anyopaque {
        if (builtin.target.os.tag != .macos) {
            return SFSymbolError.PlatformNotSupported;
        }

        const handle = try createNSImage(self.name, self.config);
        self.platform_handle = handle;
        return handle;
    }

    /// Configure the symbol
    pub fn configure(self: *Self, config: SymbolConfiguration) void {
        self.config = config;
    }

    /// Set point size
    pub fn setPointSize(self: *Self, size: f64) void {
        self.config.point_size = size;
    }

    /// Set weight
    pub fn setWeight(self: *Self, weight: SymbolConfiguration.Weight) void {
        self.config.weight = weight;
    }

    /// Set scale
    pub fn setScale(self: *Self, scale: SymbolConfiguration.Scale) void {
        self.config.scale = scale;
    }

    /// Set rendering mode
    pub fn setRenderingMode(self: *Self, mode: SymbolConfiguration.RenderingMode) void {
        self.config.rendering_mode = mode;
    }

    /// Set primary color (for hierarchical/palette modes)
    pub fn setPrimaryColor(self: *Self, color: SymbolConfiguration.Color) void {
        self.config.primary_color = color;
    }
};

/// SF Symbols manager
pub const SFSymbolsManager = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    /// Check if a symbol exists
    pub fn symbolExists(self: *Self, name: []const u8) bool {
        if (builtin.target.os.tag != .macos) return false;

        _ = self;
        return checkSymbolExists(name);
    }

    /// Get all available symbol names (if possible)
    pub fn getAllSymbols(self: *Self) ![][]const u8 {
        if (builtin.target.os.tag != .macos) {
            return SFSymbolError.PlatformNotSupported;
        }

        // This would require reading SF Symbols catalog
        // For now, return common symbols
        const common_symbols = [_][]const u8{
            "house",
            "house.fill",
            "gear",
            "person",
            "person.fill",
            "star",
            "star.fill",
            "heart",
            "heart.fill",
            "envelope",
            "envelope.fill",
            "trash",
            "trash.fill",
            "folder",
            "folder.fill",
            "doc",
            "doc.fill",
            "bell",
            "bell.fill",
            "tag",
            "tag.fill",
            "bookmark",
            "bookmark.fill",
            "plus",
            "minus",
            "multiply",
            "divide",
            "checkmark",
            "xmark",
            "arrow.up",
            "arrow.down",
            "arrow.left",
            "arrow.right",
            "chevron.up",
            "chevron.down",
            "chevron.left",
            "chevron.right",
            "circle",
            "circle.fill",
            "square",
            "square.fill",
            "triangle",
            "triangle.fill",
            "play",
            "play.fill",
            "pause",
            "pause.fill",
            "stop",
            "stop.fill",
            "forward",
            "forward.fill",
            "backward",
            "backward.fill",
        };

        var result = try self.allocator.alloc([]const u8, common_symbols.len);
        for (common_symbols, 0..) |symbol, i| {
            result[i] = try self.allocator.dupe(u8, symbol);
        }

        return result;
    }

    /// Free symbol list
    pub fn freeSymbolList(self: *Self, symbols: [][]const u8) void {
        for (symbols) |symbol| {
            self.allocator.free(symbol);
        }
        self.allocator.free(symbols);
    }
};

// ============================================================================
// macOS Implementation using NSImage and SF Symbols
// ============================================================================

const objc = if (builtin.target.os.tag == .macos) @cImport({
    @cInclude("objc/message.h");
    @cInclude("objc/runtime.h");
}) else struct {};

fn msgSend0(target: anytype, selector: [*:0]const u8) if (builtin.target.os.tag == .macos) objc.id else *anyopaque {
    if (builtin.target.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, objc.sel_registerName(selector));
}

fn msgSend1(target: anytype, selector: [*:0]const u8, arg1: anytype) if (builtin.target.os.tag == .macos) objc.id else *anyopaque {
    if (builtin.target.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1)) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, objc.sel_registerName(selector), arg1);
}

fn msgSend2(target: anytype, selector: [*:0]const u8, arg1: anytype, arg2: anytype) if (builtin.target.os.tag == .macos) objc.id else *anyopaque {
    if (builtin.target.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1), @TypeOf(arg2)) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, objc.sel_registerName(selector), arg1, arg2);
}

fn createNSImage(name: []const u8, config: SymbolConfiguration) !*anyopaque {
    if (builtin.target.os.tag != .macos) return SFSymbolError.PlatformNotSupported;

    var allocator = std.heap.c_allocator;
    const name_z = try allocator.dupeZ(u8, name);
    defer allocator.free(name_z);

    // Get NSImage class
    const NSImage = objc.objc_getClass("NSImage");
    const NSString = objc.objc_getClass("NSString");

    // Create NSString from symbol name
    const symbolName = msgSend1(NSString, "stringWithUTF8String:", name_z.ptr);

    // Create image from system symbol name
    // [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil]
    const image = msgSend2(NSImage, "imageWithSystemSymbolName:accessibilityDescription:", symbolName, @as(?*anyopaque, null));

    if (image == null) {
        return SFSymbolError.SymbolNotFound;
    }

    // Apply configuration if needed
    if (config.point_size != null) {
        // Create NSImageSymbolConfiguration
        const NSImageSymbolConfiguration = objc.objc_getClass("NSImageSymbolConfiguration");

        // Set point size
        const point_size = config.point_size.?;
        const sizeConfig = msgSend1(NSImageSymbolConfiguration, "configurationWithPointSize:weight:", point_size);

        // Apply configuration to image
        const configuredImage = msgSend1(image, "imageWithSymbolConfiguration:", sizeConfig);
        _ = msgSend0(configuredImage, "retain");
        return @ptrFromInt(@intFromPtr(configuredImage));
    }

    _ = msgSend0(image, "retain");
    return @ptrFromInt(@intFromPtr(image));
}

fn checkSymbolExists(name: []const u8) bool {
    if (builtin.target.os.tag != .macos) return false;

    var allocator = std.heap.c_allocator;
    const name_z = allocator.dupeZ(u8, name) catch return false;
    defer allocator.free(name_z);

    const NSImage = objc.objc_getClass("NSImage");
    const NSString = objc.objc_getClass("NSString");

    const symbolName = msgSend1(NSString, "stringWithUTF8String:", name_z.ptr);
    const image = msgSend2(NSImage, "imageWithSystemSymbolName:accessibilityDescription:", symbolName, @as(?*anyopaque, null));

    return image != null;
}

fn releasePlatformHandle(handle: *anyopaque) void {
    if (builtin.target.os.tag != .macos) return;

    const image: objc.id = @ptrFromInt(@intFromPtr(handle));
    _ = msgSend0(image, "release");
}

// ============================================================================
// Common SF Symbols constants
// ============================================================================

pub const CommonSymbols = struct {
    // UI Elements
    pub const gear = "gear";
    pub const gear_fill = "gear.fill";
    pub const slider_horizontal = "slider.horizontal.3";
    pub const list_bullet = "list.bullet";
    pub const square_grid_2x2 = "square.grid.2x2";

    // Files & Folders
    pub const folder = "folder";
    pub const folder_fill = "folder.fill";
    pub const doc = "doc";
    pub const doc_fill = "doc.fill";
    pub const doc_text = "doc.text";

    // Communication
    pub const envelope = "envelope";
    pub const envelope_fill = "envelope.fill";
    pub const message = "message";
    pub const message_fill = "message.fill";
    pub const phone = "phone";
    pub const phone_fill = "phone.fill";

    // Media
    pub const play = "play";
    pub const play_fill = "play.fill";
    pub const pause = "pause";
    pub const pause_fill = "pause.fill";
    pub const stop = "stop";
    pub const stop_fill = "stop.fill";

    // Navigation
    pub const arrow_up = "arrow.up";
    pub const arrow_down = "arrow.down";
    pub const arrow_left = "arrow.left";
    pub const arrow_right = "arrow.right";
    pub const chevron_up = "chevron.up";
    pub const chevron_down = "chevron.down";

    // Actions
    pub const plus = "plus";
    pub const minus = "minus";
    pub const multiply = "multiply";
    pub const checkmark = "checkmark";
    pub const xmark = "xmark";
    pub const trash = "trash";
    pub const trash_fill = "trash.fill";

    // Shapes
    pub const circle = "circle";
    pub const circle_fill = "circle.fill";
    pub const square = "square";
    pub const square_fill = "square.fill";
    pub const star = "star";
    pub const star_fill = "star.fill";
    pub const heart = "heart";
    pub const heart_fill = "heart.fill";

    // System
    pub const house = "house";
    pub const house_fill = "house.fill";
    pub const person = "person";
    pub const person_fill = "person.fill";
    pub const bell = "bell";
    pub const bell_fill = "bell.fill";
    pub const tag = "tag";
    pub const tag_fill = "tag.fill";
};

// Tests
test "SF symbol creation" {
    if (builtin.target.os.tag != .macos) return error.SkipZigTest;

    const allocator = std.testing.allocator;

    var symbol = try SFSymbol.init(allocator, "heart.fill");
    defer symbol.deinit();

    symbol.setPointSize(24.0);
    symbol.setWeight(.bold);
}

test "SF symbols manager" {
    if (builtin.target.os.tag != .macos) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var manager = SFSymbolsManager.init(allocator);

    const exists = manager.symbolExists("house");
    try std.testing.expect(exists);
}
