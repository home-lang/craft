const std = @import("std");
const testing = std.testing;
const gpu = @import("../src/gpu.zig");

test "Backend enum" {
    try testing.expectEqual(gpu.Backend.vulkan, .vulkan);
    try testing.expectEqual(gpu.Backend.metal, .metal);
    try testing.expectEqual(gpu.Backend.directx, .directx);
    try testing.expectEqual(gpu.Backend.opengl, .opengl);
}

test "Context - initialization" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    try testing.expectEqual(gpu.Backend.vulkan, ctx.backend);
}

test "Context - different backends" {
    const allocator = testing.allocator;

    var vulkan_ctx = try gpu.Context.init(allocator, .vulkan);
    defer vulkan_ctx.deinit();
    try testing.expectEqual(gpu.Backend.vulkan, vulkan_ctx.backend);

    var metal_ctx = try gpu.Context.init(allocator, .metal);
    defer metal_ctx.deinit();
    try testing.expectEqual(gpu.Backend.metal, metal_ctx.backend);

    var dx_ctx = try gpu.Context.init(allocator, .directx);
    defer dx_ctx.deinit();
    try testing.expectEqual(gpu.Backend.directx, dx_ctx.backend);

    var gl_ctx = try gpu.Context.init(allocator, .opengl);
    defer gl_ctx.deinit();
    try testing.expectEqual(gpu.Backend.opengl, gl_ctx.backend);
}

test "ShaderType enum" {
    try testing.expectEqual(gpu.ShaderType.vertex, .vertex);
    try testing.expectEqual(gpu.ShaderType.fragment, .fragment);
    try testing.expectEqual(gpu.ShaderType.compute, .compute);
}

test "TextureFormat enum" {
    try testing.expectEqual(gpu.TextureFormat.rgba8, .rgba8);
    try testing.expectEqual(gpu.TextureFormat.rgba16f, .rgba16f);
    try testing.expectEqual(gpu.TextureFormat.rgba32f, .rgba32f);
    try testing.expectEqual(gpu.TextureFormat.depth24, .depth24);
    try testing.expectEqual(gpu.TextureFormat.depth32f, .depth32f);
}

test "BufferType enum" {
    try testing.expectEqual(gpu.BufferType.vertex, .vertex);
    try testing.expectEqual(gpu.BufferType.index, .index);
    try testing.expectEqual(gpu.BufferType.uniform, .uniform);
    try testing.expectEqual(gpu.BufferType.storage, .storage);
}

test "RenderPipeline - initialization" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    var pipeline = try gpu.RenderPipeline.init(allocator, &ctx);
    defer pipeline.deinit();

    // Pipeline should be created successfully
    try testing.expect(true);
}

test "ShaderSource - vertex only" {
    const source = gpu.ShaderSource{
        .vertex = "vertex_shader.glsl",
        .fragment = null,
        .compute = null,
    };

    try testing.expectEqualStrings("vertex_shader.glsl", source.vertex.?);
    try testing.expectEqual(@as(?[]const u8, null), source.fragment);
    try testing.expectEqual(@as(?[]const u8, null), source.compute);
}

test "ShaderSource - vertex and fragment" {
    const source = gpu.ShaderSource{
        .vertex = "vertex.glsl",
        .fragment = "fragment.glsl",
        .compute = null,
    };

    try testing.expectEqualStrings("vertex.glsl", source.vertex.?);
    try testing.expectEqualStrings("fragment.glsl", source.fragment.?);
    try testing.expectEqual(@as(?[]const u8, null), source.compute);
}

test "ShaderSource - compute shader" {
    const source = gpu.ShaderSource{
        .vertex = null,
        .fragment = null,
        .compute = "compute.glsl",
    };

    try testing.expectEqualStrings("compute.glsl", source.compute.?);
}

test "Buffer - initialization" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    const data = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var buffer = try gpu.Buffer.init(allocator, &ctx, .vertex, @sizeOf(@TypeOf(data)));
    defer buffer.deinit();

    try testing.expectEqual(gpu.BufferType.vertex, buffer.buffer_type);
    try testing.expectEqual(@as(usize, @sizeOf(@TypeOf(data))), buffer.size);
}

test "Buffer - different types" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    var vertex_buffer = try gpu.Buffer.init(allocator, &ctx, .vertex, 1024);
    defer vertex_buffer.deinit();
    try testing.expectEqual(gpu.BufferType.vertex, vertex_buffer.buffer_type);

    var index_buffer = try gpu.Buffer.init(allocator, &ctx, .index, 512);
    defer index_buffer.deinit();
    try testing.expectEqual(gpu.BufferType.index, index_buffer.buffer_type);

    var uniform_buffer = try gpu.Buffer.init(allocator, &ctx, .uniform, 256);
    defer uniform_buffer.deinit();
    try testing.expectEqual(gpu.BufferType.uniform, uniform_buffer.buffer_type);

    var storage_buffer = try gpu.Buffer.init(allocator, &ctx, .storage, 2048);
    defer storage_buffer.deinit();
    try testing.expectEqual(gpu.BufferType.storage, storage_buffer.buffer_type);
}

test "Texture - initialization" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    var texture = try gpu.Texture.init(allocator, &ctx, 1024, 768, .rgba8);
    defer texture.deinit();

    try testing.expectEqual(@as(u32, 1024), texture.width);
    try testing.expectEqual(@as(u32, 768), texture.height);
    try testing.expectEqual(gpu.TextureFormat.rgba8, texture.format);
}

test "Texture - different formats" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    var rgba8 = try gpu.Texture.init(allocator, &ctx, 512, 512, .rgba8);
    defer rgba8.deinit();
    try testing.expectEqual(gpu.TextureFormat.rgba8, rgba8.format);

    var rgba16f = try gpu.Texture.init(allocator, &ctx, 512, 512, .rgba16f);
    defer rgba16f.deinit();
    try testing.expectEqual(gpu.TextureFormat.rgba16f, rgba16f.format);

    var rgba32f = try gpu.Texture.init(allocator, &ctx, 512, 512, .rgba32f);
    defer rgba32f.deinit();
    try testing.expectEqual(gpu.TextureFormat.rgba32f, rgba32f.format);
}

test "RenderTarget - initialization" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    var target = try gpu.RenderTarget.init(allocator, &ctx, 1920, 1080, .rgba8);
    defer target.deinit();

    try testing.expectEqual(@as(u32, 1920), target.width);
    try testing.expectEqual(@as(u32, 1080), target.height);
    try testing.expectEqual(gpu.TextureFormat.rgba8, target.format);
}

test "Mesh - initialization without indices" {
    const allocator = testing.allocator;
    const vertices = [_]f32{
        0.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
    };

    var mesh = try gpu.Mesh.init(allocator, &vertices, null);
    defer mesh.deinit();

    try testing.expectEqual(@as(usize, 9), mesh.vertices.len);
}

test "Mesh - initialization with indices" {
    const allocator = testing.allocator;
    const vertices = [_]f32{
        0.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        1.0, 1.0, 0.0,
    };
    const indices = [_]u32{ 0, 1, 2, 1, 3, 2 };

    var mesh = try gpu.Mesh.init(allocator, &vertices, &indices);
    defer mesh.deinit();

    try testing.expectEqual(@as(usize, 12), mesh.vertices.len);
    try testing.expectEqual(@as(usize, 6), mesh.indices.?.len);
}

test "Effect enum - all effects" {
    try testing.expectEqual(gpu.Effect.bloom, .bloom);
    try testing.expectEqual(gpu.Effect.blur, .blur);
    try testing.expectEqual(gpu.Effect.sharpen, .sharpen);
    try testing.expectEqual(gpu.Effect.vignette, .vignette);
    try testing.expectEqual(gpu.Effect.chromatic_aberration, .chromatic_aberration);
    try testing.expectEqual(gpu.Effect.film_grain, .film_grain);
    try testing.expectEqual(gpu.Effect.color_grading, .color_grading);
    try testing.expectEqual(gpu.Effect.tone_mapping, .tone_mapping);
    try testing.expectEqual(gpu.Effect.anti_aliasing, .anti_aliasing);
    try testing.expectEqual(gpu.Effect.ambient_occlusion, .ambient_occlusion);
}

test "PostProcessor - initialization" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    var processor = try gpu.PostProcessor.init(allocator, &ctx);
    defer processor.deinit();

    try testing.expectEqual(@as(usize, 0), processor.effects.items.len);
}

test "PostProcessor - add effect" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    var processor = try gpu.PostProcessor.init(allocator, &ctx);
    defer processor.deinit();

    const params = gpu.EffectParams{ .intensity = 0.5 };
    try processor.addEffect(.bloom, params);

    try testing.expectEqual(@as(usize, 1), processor.effects.items.len);
    try testing.expectEqual(gpu.Effect.bloom, processor.effects.items[0].effect);
}

test "PostProcessor - multiple effects" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    var processor = try gpu.PostProcessor.init(allocator, &ctx);
    defer processor.deinit();

    try processor.addEffect(.bloom, .{ .intensity = 0.5 });
    try processor.addEffect(.blur, .{ .radius = 5.0 });
    try processor.addEffect(.vignette, .{ .intensity = 0.3 });

    try testing.expectEqual(@as(usize, 3), processor.effects.items.len);
}

test "PostProcessor - remove effect" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    var processor = try gpu.PostProcessor.init(allocator, &ctx);
    defer processor.deinit();

    try processor.addEffect(.bloom, .{ .intensity = 0.5 });
    try processor.addEffect(.blur, .{ .radius = 5.0 });

    try testing.expectEqual(@as(usize, 2), processor.effects.items.len);

    processor.removeEffect(0);

    try testing.expectEqual(@as(usize, 1), processor.effects.items.len);
}

test "PostProcessor - clear effects" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    var processor = try gpu.PostProcessor.init(allocator, &ctx);
    defer processor.deinit();

    try processor.addEffect(.bloom, .{ .intensity = 0.5 });
    try processor.addEffect(.blur, .{ .radius = 5.0 });
    try processor.addEffect(.vignette, .{ .intensity = 0.3 });

    processor.clearEffects();

    try testing.expectEqual(@as(usize, 0), processor.effects.items.len);
}

test "EffectParams - intensity" {
    const params = gpu.EffectParams{ .intensity = 0.75 };
    try testing.expectEqual(@as(f32, 0.75), params.intensity);
}

test "EffectParams - radius" {
    const params = gpu.EffectParams{ .radius = 10.0 };
    try testing.expectEqual(@as(f32, 10.0), params.radius);
}

test "EffectParams - samples" {
    const params = gpu.EffectParams{ .samples = 8 };
    try testing.expectEqual(@as(u32, 8), params.samples);
}

test "GPUProfiler - initialization" {
    const allocator = testing.allocator;
    var profiler = try gpu.GPUProfiler.init(allocator);
    defer profiler.deinit();

    try testing.expectEqual(@as(usize, 0), profiler.timings.items.len);
}

test "GPUProfiler - record timing" {
    const allocator = testing.allocator;
    var profiler = try gpu.GPUProfiler.init(allocator);
    defer profiler.deinit();

    try profiler.recordTiming("render_pass", 16.67);

    try testing.expectEqual(@as(usize, 1), profiler.timings.items.len);
    try testing.expectEqualStrings("render_pass", profiler.timings.items[0].name);
    try testing.expectEqual(@as(f64, 16.67), profiler.timings.items[0].duration_ms);
}

test "ComputeShader - initialization" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    var shader = try gpu.ComputeShader.init(allocator, &ctx, "compute.glsl");
    defer shader.deinit();

    try testing.expectEqualStrings("compute.glsl", shader.source);
}

test "ComputeShader - set workgroup size" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    var shader = try gpu.ComputeShader.init(allocator, &ctx, "compute.glsl");
    defer shader.deinit();

    shader.setWorkgroupSize(8, 8, 1);

    try testing.expectEqual(@as(u32, 8), shader.workgroup_x);
    try testing.expectEqual(@as(u32, 8), shader.workgroup_y);
    try testing.expectEqual(@as(u32, 1), shader.workgroup_z);
}

test "RayTracer - initialization" {
    const allocator = testing.allocator;
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    var tracer = try gpu.RayTracer.init(allocator, &ctx);
    defer tracer.deinit();

    try testing.expect(!tracer.acceleration_built);
}

test "MultiGPU - initialization" {
    const allocator = testing.allocator;
    var multi = try gpu.MultiGPU.init(allocator);
    defer multi.deinit();

    try testing.expectEqual(@as(usize, 0), multi.devices.items.len);
}

test "MultiGPU - add device" {
    const allocator = testing.allocator;
    var multi = try gpu.MultiGPU.init(allocator);
    defer multi.deinit();

    const device = gpu.MultiGPU.Device{
        .id = 0,
        .name = "GPU 0",
        .memory = 8192,
    };

    try multi.addDevice(device);

    try testing.expectEqual(@as(usize, 1), multi.devices.items.len);
    try testing.expectEqual(@as(u32, 0), multi.devices.items[0].id);
    try testing.expectEqualStrings("GPU 0", multi.devices.items[0].name);
}

test "RenderCommand - draw mesh" {
    const allocator = testing.allocator;
    const vertices = [_]f32{ 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0 };
    var mesh = try gpu.Mesh.init(allocator, &vertices, null);
    defer mesh.deinit();

    const cmd = gpu.RenderCommand{ .draw_mesh = mesh };
    try testing.expect(cmd == .draw_mesh);
}

test "RenderCommand - clear color" {
    const cmd = gpu.RenderCommand{
        .clear_color = .{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 },
    };
    try testing.expect(cmd == .clear_color);
    try testing.expectEqual(@as(f32, 1.0), cmd.clear_color.r);
}

test "VertexAttribute - position" {
    const attr = gpu.VertexAttribute{
        .name = "position",
        .size = 3,
        .offset = 0,
    };

    try testing.expectEqualStrings("position", attr.name);
    try testing.expectEqual(@as(u32, 3), attr.size);
    try testing.expectEqual(@as(u32, 0), attr.offset);
}

test "VertexAttribute - texture coordinates" {
    const attr = gpu.VertexAttribute{
        .name = "texCoord",
        .size = 2,
        .offset = 12,
    };

    try testing.expectEqualStrings("texCoord", attr.name);
    try testing.expectEqual(@as(u32, 2), attr.size);
    try testing.expectEqual(@as(u32, 12), attr.offset);
}
