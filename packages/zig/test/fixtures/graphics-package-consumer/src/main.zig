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
    var gpu = try craft.gpu.GPU.init(std.heap.page_allocator, .{ .backend = .software });
    defer gpu.deinit();
    const capabilities = gpu.getRenderingCapabilities();
    if (!capabilities.offscreen_clear or capabilities.presentation or capabilities.draw or capabilities.shader_compilation) return error.InaccurateCapabilities;
    var shader = try craft.gpu.Shader.init(std.heap.page_allocator, .{ .type = .fragment, .code = "void main() {}" });
    defer shader.deinit();
    try std.testing.expectError(error.ShaderCompilationUnavailable, shader.compile());
    if (shader.isReady()) return error.UncompiledShaderReady;
    std.debug.print("documented package consumer drew exact CPU pixels without a window\n", .{});
}
