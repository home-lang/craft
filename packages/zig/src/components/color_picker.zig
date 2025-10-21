const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// ColorPicker Component - Color selection interface
pub const ColorPicker = struct {
    component: Component,
    color: Color,
    format: ColorFormat,
    show_alpha: bool,
    show_presets: bool,
    presets: std.ArrayList(Color),
    disabled: bool,
    on_change: ?*const fn (Color) void,

    pub const Color = struct {
        r: u8,
        g: u8,
        b: u8,
        a: u8 = 255,

        pub fn fromRGB(r: u8, g: u8, b: u8) Color {
            return .{ .r = r, .g = g, .b = b };
        }

        pub fn fromRGBA(r: u8, g: u8, b: u8, a: u8) Color {
            return .{ .r = r, .g = g, .b = b, .a = a };
        }

        pub fn fromHex(hex: []const u8) !Color {
            if (hex.len != 6 and hex.len != 8) return error.InvalidHexColor;

            const r = try std.fmt.parseInt(u8, hex[0..2], 16);
            const g = try std.fmt.parseInt(u8, hex[2..4], 16);
            const b = try std.fmt.parseInt(u8, hex[4..6], 16);
            const a = if (hex.len == 8) try std.fmt.parseInt(u8, hex[6..8], 16) else 255;

            return Color{ .r = r, .g = g, .b = b, .a = a };
        }

        pub fn toHex(self: Color, allocator: std.mem.Allocator, include_alpha: bool) ![]const u8 {
            if (include_alpha) {
                return std.fmt.allocPrint(allocator, "{X:0>2}{X:0>2}{X:0>2}{X:0>2}", .{ self.r, self.g, self.b, self.a });
            } else {
                return std.fmt.allocPrint(allocator, "{X:0>2}{X:0>2}{X:0>2}", .{ self.r, self.g, self.b });
            }
        }

        pub fn toHSL(self: Color) HSL {
            const r_norm = @as(f32, @floatFromInt(self.r)) / 255.0;
            const g_norm = @as(f32, @floatFromInt(self.g)) / 255.0;
            const b_norm = @as(f32, @floatFromInt(self.b)) / 255.0;

            const max = @max(@max(r_norm, g_norm), b_norm);
            const min = @min(@min(r_norm, g_norm), b_norm);
            const delta = max - min;

            const l = (max + min) / 2.0;

            if (delta == 0) {
                return HSL{ .h = 0, .s = 0, .l = l };
            }

            const s = if (l > 0.5) delta / (2.0 - max - min) else delta / (max + min);

            var h: f32 = 0;
            if (max == r_norm) {
                h = @mod((g_norm - b_norm) / delta + 6.0, 6.0);
            } else if (max == g_norm) {
                h = (b_norm - r_norm) / delta + 2.0;
            } else {
                h = (r_norm - g_norm) / delta + 4.0;
            }
            h *= 60.0;

            return HSL{ .h = h, .s = s, .l = l };
        }

        pub fn equals(self: Color, other: Color) bool {
            return self.r == other.r and self.g == other.g and self.b == other.b and self.a == other.a;
        }
    };

    pub const HSL = struct {
        h: f32, // 0-360
        s: f32, // 0-1
        l: f32, // 0-1

        pub fn toRGB(self: HSL) Color {
            const c = (1.0 - @abs(2.0 * self.l - 1.0)) * self.s;
            const x = c * (1.0 - @abs(@mod(self.h / 60.0, 2.0) - 1.0));
            const m = self.l - c / 2.0;

            var r: f32 = 0;
            var g: f32 = 0;
            var b: f32 = 0;

            if (self.h < 60) {
                r = c;
                g = x;
            } else if (self.h < 120) {
                r = x;
                g = c;
            } else if (self.h < 180) {
                g = c;
                b = x;
            } else if (self.h < 240) {
                g = x;
                b = c;
            } else if (self.h < 300) {
                r = x;
                b = c;
            } else {
                r = c;
                b = x;
            }

            return Color{
                .r = @intFromFloat((r + m) * 255.0),
                .g = @intFromFloat((g + m) * 255.0),
                .b = @intFromFloat((b + m) * 255.0),
            };
        }
    };

    pub const ColorFormat = enum {
        hex,
        rgb,
        rgba,
        hsl,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*ColorPicker {
        const picker = try allocator.create(ColorPicker);
        picker.* = ColorPicker{
            .component = try Component.init(allocator, "color_picker", props),
            .color = Color.fromRGB(0, 0, 0),
            .format = .hex,
            .show_alpha = false,
            .show_presets = true,
            .presets = .{},
            .disabled = false,
            .on_change = null,
        };

        // Add default presets
        try picker.addPreset(Color.fromRGB(255, 0, 0)); // Red
        try picker.addPreset(Color.fromRGB(0, 255, 0)); // Green
        try picker.addPreset(Color.fromRGB(0, 0, 255)); // Blue
        try picker.addPreset(Color.fromRGB(255, 255, 0)); // Yellow
        try picker.addPreset(Color.fromRGB(255, 0, 255)); // Magenta
        try picker.addPreset(Color.fromRGB(0, 255, 255)); // Cyan
        try picker.addPreset(Color.fromRGB(255, 255, 255)); // White
        try picker.addPreset(Color.fromRGB(0, 0, 0)); // Black

        return picker;
    }

    pub fn deinit(self: *ColorPicker) void {
        self.presets.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setColor(self: *ColorPicker, color: Color) void {
        if (self.disabled) return;

        const old_color = self.color;
        self.color = color;

        if (!old_color.equals(color)) {
            if (self.on_change) |callback| {
                callback(color);
            }
        }
    }

    pub fn setColorFromHex(self: *ColorPicker, hex: []const u8) !void {
        const color = try Color.fromHex(hex);
        self.setColor(color);
    }

    pub fn setColorFromRGB(self: *ColorPicker, r: u8, g: u8, b: u8) void {
        self.setColor(Color.fromRGB(r, g, b));
    }

    pub fn setColorFromRGBA(self: *ColorPicker, r: u8, g: u8, b: u8, a: u8) void {
        self.setColor(Color.fromRGBA(r, g, b, a));
    }

    pub fn setColorFromHSL(self: *ColorPicker, h: f32, s: f32, l: f32) void {
        const hsl = HSL{ .h = h, .s = s, .l = l };
        self.setColor(hsl.toRGB());
    }

    pub fn setFormat(self: *ColorPicker, format: ColorFormat) void {
        self.format = format;
    }

    pub fn setShowAlpha(self: *ColorPicker, show: bool) void {
        self.show_alpha = show;
    }

    pub fn setShowPresets(self: *ColorPicker, show: bool) void {
        self.show_presets = show;
    }

    pub fn setDisabled(self: *ColorPicker, disabled: bool) void {
        self.disabled = disabled;
    }

    pub fn addPreset(self: *ColorPicker, color: Color) !void {
        try self.presets.append(self.component.allocator, color);
    }

    pub fn clearPresets(self: *ColorPicker) void {
        self.presets.clearRetainingCapacity();
    }

    pub fn getColorString(self: *const ColorPicker, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self.format) {
            .hex => try self.color.toHex(allocator, false),
            .rgb => try std.fmt.allocPrint(allocator, "rgb({d},{d},{d})", .{ self.color.r, self.color.g, self.color.b }),
            .rgba => try std.fmt.allocPrint(allocator, "rgba({d},{d},{d},{d})", .{ self.color.r, self.color.g, self.color.b, self.color.a }),
            .hsl => blk: {
                const hsl = self.color.toHSL();
                break :blk try std.fmt.allocPrint(allocator, "hsl({d:.0},{d:.0}%,{d:.0}%)", .{ hsl.h, hsl.s * 100, hsl.l * 100 });
            },
        };
    }

    pub fn onChange(self: *ColorPicker, callback: *const fn (Color) void) void {
        self.on_change = callback;
    }
};
