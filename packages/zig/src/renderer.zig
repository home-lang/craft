const std = @import("std");

/// Legacy UI facade over the window-independent raster core. Selecting a
/// RenderBackend does not create a native window, text backend or GPU surface.
pub const RenderBackend = enum {
    webview, // Default WebView rendering
    native, // Pure native rendering
    hybrid, // Mix of native and web
};

const graphics = @import("graphics.zig");

pub const Color = graphics.Color;
pub const Point = graphics.Point;
pub const Size = graphics.Size;
pub const Rect = graphics.Rect;
pub const Bitmap = graphics.Bitmap;
pub const BitmapError = graphics.BitmapError;
pub const Font = graphics.Font;
pub const FontWeight = graphics.FontWeight;
pub const FontStyle = graphics.FontStyle;
pub const Canvas = graphics.Canvas;

pub const Renderer = struct {
    backend: RenderBackend,
    canvas: ?*Canvas,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, backend: RenderBackend) Renderer {
        return Renderer{
            .backend = backend,
            .canvas = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Renderer) void {
        if (self.canvas) |canvas| {
            canvas.deinit();
            self.allocator.destroy(canvas);
            self.canvas = null;
        }
    }

    pub fn createCanvas(self: *Renderer, width: u32, height: u32) !*Canvas {
        if (self.canvas != null) return error.CanvasAlreadyExists;
        const canvas = try self.allocator.create(Canvas);
        // Without this errdefer, a failure inside `Canvas.init` below leaks
        // the outer allocation.
        errdefer self.allocator.destroy(canvas);
        canvas.* = try Canvas.init(self.allocator, width, height);
        self.canvas = canvas;
        return canvas;
    }
};

/// UI Component system for native rendering
pub const Component = struct {
    bounds: Rect,
    visible: bool,
    children: std.ArrayList(*Component),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, bounds: Rect) Component {
        return Component{
            .bounds = bounds,
            .visible = true,
            .children = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Component) void {
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit(self.allocator);
    }

    pub fn addChild(self: *Component, child: *Component) !void {
        try self.children.append(self.allocator, child);
    }

    pub fn render(self: *Component, canvas: *Canvas) void {
        if (!self.visible) return;

        // Render self
        canvas.drawRect(self.bounds, Color.rgb(200, 200, 200));

        // Render children
        for (self.children.items) |child| {
            child.render(canvas);
        }
    }
};

/// Button component
pub const Button = struct {
    component: Component,
    text: []const u8,
    background: Color,
    foreground: Color,
    font: Font,

    pub fn init(allocator: std.mem.Allocator, bounds: Rect, text: []const u8) Button {
        return Button{
            .component = Component.init(allocator, bounds),
            .text = text,
            .background = Color.rgb(100, 100, 200),
            .foreground = Color.rgb(255, 255, 255),
            .font = Font{
                .family = "system",
                .size = 14.0,
            },
        };
    }

    pub fn render(self: *Button, canvas: *Canvas) !void {
        canvas.drawRect(self.component.bounds, self.background);
        try canvas.drawText(self.text, .{ .x = self.component.bounds.x, .y = self.component.bounds.y }, self.font, self.foreground);
    }
};

/// Label component
pub const Label = struct {
    component: Component,
    text: []const u8,
    color: Color,
    font: Font,

    pub fn init(allocator: std.mem.Allocator, bounds: Rect, text: []const u8) Label {
        return Label{
            .component = Component.init(allocator, bounds),
            .text = text,
            .color = Color.rgb(0, 0, 0),
            .font = Font{
                .family = "system",
                .size = 14.0,
            },
        };
    }

    pub fn render(self: *Label, canvas: *Canvas) !void {
        try canvas.drawText(self.text, Point{ .x = self.component.bounds.x, .y = self.component.bounds.y }, self.font, self.color);
    }
};
