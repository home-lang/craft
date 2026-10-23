const std = @import("std");
const craft = @import("craft");
pub fn main() !void {
    var canvas = try craft.graphics.Canvas.init(std.heap.page_allocator, 2, 1);
    defer canvas.deinit();
    canvas.clear(craft.graphics.Color.rgb(0, 0, 0));
    const atlas = [_]u8{ 255, 0, 0, 255 };
    try canvas.drawBitmap(.{ .width = 1, .height = 1, .pixels = &atlas }, .{ .x = 0, .y = 0, .width = 1, .height = 1 }, .{ .x = 1, .y = 0 });
    if (!std.mem.eql(u32, &.{ 0xff000000, 0xffff0000 }, canvas.pixels)) return error.WrongNativePixels;
    if (craft.renderer.Canvas != craft.graphics.Canvas) @compileError("Canvas must have one public owner");
    try std.testing.expectError(error.TextRenderingUnavailable, canvas.drawText("x", .{ .x = 0, .y = 0 }, .{ .family = "sans-serif", .size = 12 }, craft.graphics.Color.rgb(255, 255, 255)));
    if (!std.mem.eql(u32, &.{ 0xff000000, 0xffff0000 }, canvas.pixels)) return error.UnavailableTextChangedPixels;
    const scene = craft.graphics.scene;
    var frame = try craft.graphics.Canvas.init(std.heap.page_allocator, 4, 4);
    defer frame.deinit();
    frame.clear(craft.graphics.Color.rgb(0, 0, 0));
    const translucent_red = [_]u8{ 255, 0, 0, 128 };
    const white = [_]u8{ 255, 255, 255, 255 };
    const blue = [_]u8{ 0, 0, 255, 255 };
    const terrain: craft.graphics.Bitmap = .{ .width = 1, .height = 1, .pixels = &translucent_red };
    const glyphs = [_]scene.Glyph{.{ .codepoint = 'Ω', .source = .{ .x = 0, .y = 0, .width = 1, .height = 1 }, .advance = 1 }};
    const font: scene.BitmapFont = .{ .bitmap = .{ .width = 1, .height = 1, .pixels = &white }, .glyphs = &glyphs, .line_height = 1 };
    const sprite: scene.Sprite = .{ .bitmap = .{ .width = 1, .height = 1, .pixels = &blue }, .source = .{ .x = 0, .y = 0, .width = 1, .height = 1 }, .transform = .{ .tx = 3, .ty = 3 } };
    try scene.drawFrame(&frame, &.{
        .{ .triangle = .{ .bitmap = terrain, .vertices = .{ .{ .x = 0, .y = 0, .u = 0, .v = 0 }, .{ .x = 2, .y = 0, .u = 1, .v = 0 }, .{ .x = 0, .y = 2, .u = 0, .v = 1 } } } },
        .{ .triangle = .{ .bitmap = terrain, .vertices = .{ .{ .x = 2, .y = 0, .u = 1, .v = 0 }, .{ .x = 2, .y = 2, .u = 1, .v = 1 }, .{ .x = 0, .y = 2, .u = 0, .v = 1 } } } },
        .{ .text = .{ .font = font, .text = "ΩΩ\nΩ", .transform = .{ .tx = 2, .ty = 1 } } },
        .{ .sprite = sprite },
    }, .{});
    const expected_frame = [_]u32{
        0xff800000, 0xff800000, 0xff000000, 0xff000000,
        0xff800000, 0xff800000, 0xffffffff, 0xffffffff,
        0xff000000, 0xff000000, 0xffffffff, 0xff000000,
        0xff000000, 0xff000000, 0xff000000, 0xff0000ff,
    };
    if (!std.mem.eql(u32, &expected_frame, frame.pixels)) return error.WrongPublicScenePixels;
    // A later invalid command must reject the complete frame before the first
    // otherwise-valid command can change any pixel.
    var moved_sprite = sprite;
    moved_sprite.transform = .{};
    try std.testing.expectError(error.MissingGlyph, scene.drawFrame(&frame, &.{
        .{ .sprite = moved_sprite },
        .{ .text = .{ .font = font, .text = "missing" } },
    }, .{}));
    if (!std.mem.eql(u32, &expected_frame, frame.pixels)) return error.InvalidPublicSceneChangedPixels;
    var gpu = try craft.gpu.GPU.init(std.heap.page_allocator, .{ .backend = .software });
    defer gpu.deinit();
    const capabilities = gpu.getRenderingCapabilities();
    if (!capabilities.offscreen_clear or capabilities.presentation or capabilities.draw or capabilities.shader_compilation) return error.InaccurateCapabilities;
    var shader = try craft.gpu.Shader.init(std.heap.page_allocator, .{ .type = .fragment, .code = "void main() {}" });
    defer shader.deinit();
    try std.testing.expectError(error.ShaderCompilationUnavailable, shader.compile());
    if (shader.isReady()) return error.UncompiledShaderReady;
    std.debug.print("documented package consumer verified exact bitmap, terrain, glyph and atomic CPU frame pixels without a window\n", .{});
}
