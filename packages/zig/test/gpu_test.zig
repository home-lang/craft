const std = @import("std");
const testing = std.testing;
const gpu = @import("../src/gpu.zig");

test "shader source is not a compiled program without a compiler backend" {
    var shader = try gpu.Shader.init(testing.allocator, .{
        .type = .vertex,
        .code = "void main() { gl_Position = vec4(0.0); }",
    });
    defer shader.deinit();

    try testing.expectError(error.ShaderCompilationUnavailable, shader.compile());
    try testing.expect(!shader.isReady());
    try testing.expect(!shader.compiled);
    try testing.expect(!shader.validated);
    try testing.expectEqual(@as(usize, 0), shader.uniforms.items.len);
}

test "rendering support is distinct from a requested hardware backend" {
    var g = try gpu.GPU.init(testing.allocator, .{ .backend = .metal });
    defer g.deinit();
    const capabilities = g.getRenderingCapabilities();
    try testing.expect(capabilities.offscreen_clear);
    try testing.expect(!capabilities.hardware_canvas);
    try testing.expect(!capabilities.shader_compilation);
    try testing.expect(!capabilities.draw);
    try testing.expect(!capabilities.compute);
    try testing.expect(!capabilities.presentation);
}

test "hardware canvas calls refuse work without a drawing backend" {
    var g = try gpu.GPU.init(testing.allocator, .{});
    defer g.deinit();
    var accelerator = gpu.CanvasAccelerator.init(&g);
    try testing.expect(!accelerator.enabled);
    try testing.expectError(error.UnsupportedOperation, accelerator.drawRect(0, 0, 2, 2));
    try testing.expectError(error.UnsupportedOperation, accelerator.drawCircle(1, 1, 2));
    try testing.expectError(error.UnsupportedOperation, accelerator.clear());
}

test "offscreen pipeline clear changes pixels and unsupported work is not counted" {
    var g = try gpu.GPU.init(testing.allocator, .{});
    defer g.deinit();
    var pipeline = gpu.RenderPipeline.init(testing.allocator, &g);
    defer pipeline.deinit();
    const target = try pipeline.createRenderTarget(2, 2, .rgba8);
    try pipeline.submit(.{ .set_render_target = target });
    try pipeline.submit(.{ .clear = .{ .color = .{ 1, 0, 0, 1 } } });
    try pipeline.submit(.{ .draw = .{ .vertex_count = 3 } });
    try testing.expectError(error.UnsupportedOperation, pipeline.flush());
    try testing.expectEqual([4]u8{ 255, 0, 0, 255 }, target.getColorTexture().?.getPixel(1, 1).?);
    try testing.expectEqual(@as(u32, 2), pipeline.getStatistics().commands_executed);
    try testing.expectEqual(@as(u32, 0), pipeline.getStatistics().draw_calls);
    try testing.expectEqual(@as(u32, 0), pipeline.getStatistics().vertices_processed);
    try testing.expectEqual(@as(usize, 0), pipeline.command_buffer.items.len);
    try pipeline.flush();
    try testing.expectEqual(@as(u32, 2), pipeline.getStatistics().commands_executed);
}

test "indexed and compute commands refuse work without recording success" {
    var g = try gpu.GPU.init(testing.allocator, .{});
    defer g.deinit();
    var pipeline = gpu.RenderPipeline.init(testing.allocator, &g);
    defer pipeline.deinit();
    const indexed = [_]gpu.RenderCommand{.{ .draw_indexed = .{ .index_count = 3 } }};
    try testing.expectError(error.UnsupportedOperation, pipeline.render(&indexed));
    const compute = [_]gpu.RenderCommand{.{ .dispatch_compute = .{ .groups_x = 1, .groups_y = 1, .groups_z = 1 } }};
    try testing.expectError(error.UnsupportedOperation, pipeline.render(&compute));
    try testing.expectEqual(@as(u32, 0), pipeline.getStatistics().commands_executed);
    try testing.expectEqual(@as(u32, 0), pipeline.getStatistics().triangles_drawn);
}

test "clear without a target and uncompiled shader cannot report success" {
    var g = try gpu.GPU.init(testing.allocator, .{});
    defer g.deinit();
    var pipeline = gpu.RenderPipeline.init(testing.allocator, &g);
    defer pipeline.deinit();
    const clear = [_]gpu.RenderCommand{.{ .clear = .{ .color = .{ 1, 0, 0, 1 } } }};
    try testing.expectError(error.MissingRenderTarget, pipeline.render(&clear));
    var shader = try gpu.Shader.init(testing.allocator, .{ .type = .vertex, .code = "void main() {}" });
    defer shader.deinit();
    const set_shader = [_]gpu.RenderCommand{.{ .set_shader = &shader }};
    try testing.expectError(error.ShaderNotReady, pipeline.render(&set_shader));
    try testing.expectEqual(@as(u32, 0), pipeline.getStatistics().commands_executed);
    try testing.expect(pipeline.getState().current_shader == null);
}

test "compute shader dispatch does not pretend to execute" {
    var shader = try gpu.ComputeShader.init(testing.allocator, "void main() {}", .{ 1, 1, 1 });
    defer shader.deinit();
    try testing.expectError(error.UnsupportedOperation, shader.dispatch(1, 1, 1));
}

fn createOffscreenTarget(allocator: std.mem.Allocator) !void {
    var g = try gpu.GPU.init(allocator, .{});
    defer g.deinit();
    var pipeline = gpu.RenderPipeline.init(allocator, &g);
    defer pipeline.deinit();
    _ = try pipeline.createRenderTarget(2, 2, .rgba8);
}

test "offscreen target creation releases every allocation on failure" {
    try testing.checkAllAllocationFailures(testing.allocator, createOffscreenTarget, .{});
}

test "GPUBackend enum" {
    try testing.expectEqual(gpu.GPUBackend.vulkan, .vulkan);
    try testing.expectEqual(gpu.GPUBackend.metal, .metal);
    try testing.expectEqual(gpu.GPUBackend.opengl, .opengl);
    try testing.expectEqual(gpu.GPUBackend.auto, .auto);
    try testing.expectEqual(gpu.GPUBackend.software, .software);
}

test "PowerPreference enum" {
    try testing.expectEqual(gpu.PowerPreference.default, .default);
    try testing.expectEqual(gpu.PowerPreference.low_power, .low_power);
    try testing.expectEqual(gpu.PowerPreference.high_performance, .high_performance);
}

test "GPUConfig - default values" {
    const config = gpu.GPUConfig{};

    try testing.expectEqual(gpu.GPUBackend.auto, config.backend);
    try testing.expectEqual(gpu.PowerPreference.default, config.power_preference);
    try testing.expect(config.vsync);
    try testing.expect(config.hardware_decode);
    try testing.expect(config.canvas_acceleration);
    try testing.expect(config.webgl_enabled);
    try testing.expect(config.webgl2_enabled);
    try testing.expectEqual(@as(?u32, null), config.max_fps);
}

test "GPUConfig - custom values" {
    const config = gpu.GPUConfig{
        .backend = .metal,
        .power_preference = .high_performance,
        .vsync = false,
        .max_fps = 120,
        .hardware_decode = false,
        .canvas_acceleration = false,
        .webgl_enabled = false,
        .webgl2_enabled = false,
    };

    try testing.expectEqual(gpu.GPUBackend.metal, config.backend);
    try testing.expectEqual(gpu.PowerPreference.high_performance, config.power_preference);
    try testing.expect(!config.vsync);
    try testing.expectEqual(@as(?u32, 120), config.max_fps);
    try testing.expect(!config.hardware_decode);
    try testing.expect(!config.canvas_acceleration);
    try testing.expect(!config.webgl_enabled);
    try testing.expect(!config.webgl2_enabled);
}

test "GPUInfo - structure" {
    const info = gpu.GPUInfo{
        .vendor = "Test Vendor",
        .renderer = "Test Renderer",
        .version = "1.0",
        .backend = .vulkan,
        .memory_mb = 8192,
        .discrete = true,
    };

    try testing.expectEqual(gpu.GPUBackend.vulkan, info.backend);
    try testing.expectEqualStrings("Test Vendor", info.vendor);
    try testing.expectEqualStrings("Test Renderer", info.renderer);
    try testing.expectEqualStrings("1.0", info.version);
    try testing.expectEqual(@as(usize, 8192), info.memory_mb);
    try testing.expect(info.discrete);
}

test "GPU - init and deinit" {
    const allocator = testing.allocator;
    const config = gpu.GPUConfig{};
    var g = try gpu.GPU.init(allocator, config);
    defer g.deinit();

    try testing.expectEqual(@as(?gpu.GPUInfo, null), g.info);
}

test "ShaderType enum" {
    try testing.expectEqual(gpu.ShaderType.vertex, .vertex);
    try testing.expectEqual(gpu.ShaderType.fragment, .fragment);
    try testing.expectEqual(gpu.ShaderType.compute, .compute);
}

test "ShaderSource - structure" {
    const source = gpu.ShaderSource{
        .code = "void main() {}",
        .entry_point = "main",
        .type = .vertex,
    };

    try testing.expectEqualStrings("void main() {}", source.code);
    try testing.expectEqualStrings("main", source.entry_point);
    try testing.expectEqual(gpu.ShaderType.vertex, source.type);
}

test "TextureFormat - all formats" {
    try testing.expectEqual(gpu.TextureFormat.rgba8, .rgba8);
    try testing.expectEqual(gpu.TextureFormat.rgba16f, .rgba16f);
    try testing.expectEqual(gpu.TextureFormat.rgba32f, .rgba32f);
    try testing.expectEqual(gpu.TextureFormat.depth24_stencil8, .depth24_stencil8);
    try testing.expectEqual(gpu.TextureFormat.depth32f, .depth32f);
}

test "ClearCommand - structure" {
    const clear = gpu.ClearCommand{
        .color = .{ 1.0, 0.5, 0.25, 1.0 },
    };

    try testing.expectEqual(@as(f32, 1.0), clear.color[0]);
    try testing.expectEqual(@as(f32, 0.5), clear.color[1]);
    try testing.expectEqual(@as(f32, 0.25), clear.color[2]);
    try testing.expectEqual(@as(f32, 1.0), clear.color[3]);
}

test "ViewportCommand - structure" {
    const viewport = gpu.ViewportCommand{
        .x = 0,
        .y = 0,
        .width = 1920,
        .height = 1080,
    };

    try testing.expectEqual(@as(u32, 0), viewport.x);
    try testing.expectEqual(@as(u32, 0), viewport.y);
    try testing.expectEqual(@as(u32, 1920), viewport.width);
    try testing.expectEqual(@as(u32, 1080), viewport.height);
}

test "DrawCommand - structure" {
    const draw = gpu.DrawCommand{
        .vertex_count = 3,
        .instance_count = 1,
    };

    try testing.expectEqual(@as(u32, 3), draw.vertex_count);
    try testing.expectEqual(@as(u32, 1), draw.instance_count);
}

test "DrawIndexedCommand - structure" {
    const draw_indexed = gpu.DrawIndexedCommand{
        .index_count = 6,
        .instance_count = 1,
        .first_index = 0,
    };

    try testing.expectEqual(@as(u32, 6), draw_indexed.index_count);
    try testing.expectEqual(@as(u32, 1), draw_indexed.instance_count);
    try testing.expectEqual(@as(u32, 0), draw_indexed.first_index);
}

test "Vertex - structure" {
    const vertex = gpu.Vertex{
        .position = .{ 0.0, 1.0, 0.0 },
        .normal = .{ 0.0, 0.0, 1.0 },
        .uv = .{ 0.5, 0.5 },
        .color = .{ 1.0, 1.0, 1.0, 1.0 },
    };

    try testing.expectEqual(@as(f32, 0.0), vertex.position[0]);
    try testing.expectEqual(@as(f32, 1.0), vertex.position[1]);
    try testing.expectEqual(@as(f32, 0.0), vertex.position[2]);
    try testing.expectEqual(@as(f32, 0.0), vertex.normal[0]);
    try testing.expectEqual(@as(f32, 0.5), vertex.uv[0]);
    try testing.expectEqual(@as(f32, 1.0), vertex.color[0]);
}

test "Mesh - init and deinit" {
    const allocator = testing.allocator;
    var vertices = [_]gpu.Vertex{
        .{ .position = .{ 0.0, 1.0, 0.0 }, .normal = .{ 0.0, 0.0, 1.0 }, .uv = .{ 0.5, 1.0 }, .color = .{ 1.0, 0.0, 0.0, 1.0 } },
        .{ .position = .{ -1.0, -1.0, 0.0 }, .normal = .{ 0.0, 0.0, 1.0 }, .uv = .{ 0.0, 0.0 }, .color = .{ 0.0, 1.0, 0.0, 1.0 } },
        .{ .position = .{ 1.0, -1.0, 0.0 }, .normal = .{ 0.0, 0.0, 1.0 }, .uv = .{ 1.0, 0.0 }, .color = .{ 0.0, 0.0, 1.0, 1.0 } },
    };

    var indices = [_]u32{ 0, 1, 2 };

    var mesh = try gpu.Mesh.init(allocator, &vertices, &indices);
    defer mesh.deinit();

    try testing.expectEqual(@as(usize, 3), mesh.vertices.len);
    try testing.expectEqual(@as(usize, 3), mesh.indices.len);
}

test "GPUProfiler - init" {
    const allocator = testing.allocator;
    var profiler = gpu.GPUProfiler.init(allocator);
    defer profiler.deinit();

    try testing.expect(true); // Basic initialization test
}

test "MultiGPU - init" {
    const allocator = testing.allocator;
    var multi = gpu.MultiGPU.init(allocator);
    defer multi.deinit();

    try testing.expectEqual(@as(usize, 0), multi.gpus.items.len);
}

test "RenderCommand - clear" {
    const cmd = gpu.RenderCommand{ .clear = .{ .color = .{ 0.0, 0.0, 0.0, 1.0 } } };

    try testing.expect(cmd == .clear);
    try testing.expectEqual(@as(f32, 0.0), cmd.clear.color[0]);
}

test "RenderCommand - draw" {
    const cmd = gpu.RenderCommand{ .draw = .{ .vertex_count = 6, .instance_count = 1 } };

    try testing.expect(cmd == .draw);
    try testing.expectEqual(@as(u32, 6), cmd.draw.vertex_count);
}

test "RenderCommand - draw_indexed" {
    const cmd = gpu.RenderCommand{ .draw_indexed = .{ .index_count = 6, .instance_count = 1, .first_index = 0 } };

    try testing.expect(cmd == .draw_indexed);
    try testing.expectEqual(@as(u32, 6), cmd.draw_indexed.index_count);
}

test "BufferType - all values" {
    try testing.expectEqual(gpu.BufferType.vertex, .vertex);
    try testing.expectEqual(gpu.BufferType.index, .index);
    try testing.expectEqual(gpu.BufferType.uniform, .uniform);
}

test "BufferUsage - all values" {
    try testing.expectEqual(gpu.BufferUsage.static, .static);
    try testing.expectEqual(gpu.BufferUsage.dynamic, .dynamic);
    try testing.expectEqual(gpu.BufferUsage.stream, .stream);
}
