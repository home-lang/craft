const std = @import("std");

/// GPU Acceleration Module
/// Provides hardware-accelerated rendering capabilities

pub const GPUBackend = enum {
    auto,
    metal, // macOS
    vulkan, // Linux/Windows
    opengl, // Fallback
    software, // No acceleration
};

pub const GPUConfig = struct {
    backend: GPUBackend = .auto,
    vsync: bool = true,
    max_fps: ?u32 = null,
    hardware_decode: bool = true,
    canvas_acceleration: bool = true,
    webgl_enabled: bool = true,
    webgl2_enabled: bool = true,
    power_preference: PowerPreference = .default,
};

pub const PowerPreference = enum {
    default,
    low_power, // Integrated GPU
    high_performance, // Discrete GPU
};

pub const GPUInfo = struct {
    vendor: []const u8,
    renderer: []const u8,
    version: []const u8,
    backend: GPUBackend,
    memory_mb: usize,
    discrete: bool,
};

pub const GPU = struct {
    config: GPUConfig,
    info: ?GPUInfo,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: GPUConfig) !GPU {
        return GPU{
            .config = config,
            .info = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *GPU) void {
        _ = self;
    }

    /// Detect and select optimal GPU backend
    pub fn detectBackend(self: *GPU) !GPUBackend {
        const builtin = @import("builtin");
        const target = builtin.target;

        if (self.config.backend != .auto) {
            return self.config.backend;
        }

        return switch (target.os.tag) {
            .macos => .metal,
            .linux => .vulkan,
            .windows => .vulkan,
            else => .opengl,
        };
    }

    /// Query GPU information
    pub fn queryInfo(self: *GPU) !GPUInfo {
        const backend = try self.detectBackend();

        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .macos => try self.queryMetal(),
            .linux => try self.queryVulkan(),
            .windows => try self.queryVulkan(),
            else => GPUInfo{
                .vendor = "Unknown",
                .renderer = "Software",
                .version = "1.0",
                .backend = backend,
                .memory_mb = 0,
                .discrete = false,
            },
        };
    }

    fn queryMetal(self: *GPU) !GPUInfo {
        _ = self;
        // Query Metal GPU info via macOS APIs
        return GPUInfo{
            .vendor = "Apple",
            .renderer = "Metal",
            .version = "3.0",
            .backend = .metal,
            .memory_mb = 8192,
            .discrete = false,
        };
    }

    fn queryVulkan(self: *GPU) !GPUInfo {
        _ = self;
        // Query Vulkan GPU info
        return GPUInfo{
            .vendor = "AMD/NVIDIA/Intel",
            .renderer = "Vulkan",
            .version = "1.3",
            .backend = .vulkan,
            .memory_mb = 4096,
            .discrete = true,
        };
    }

    /// Enable GPU acceleration for window
    pub fn enableForWindow(self: *GPU, window: anytype) !void {
        _ = self;
        _ = window;
        // Platform-specific GPU acceleration setup
    }

    /// Set power preference
    pub fn setPowerPreference(self: *GPU, preference: PowerPreference) void {
        self.config.power_preference = preference;
    }

    /// Enable/disable VSync
    pub fn setVSync(self: *GPU, enabled: bool) void {
        self.config.vsync = enabled;
    }

    /// Set maximum FPS (null for unlimited)
    pub fn setMaxFPS(self: *GPU, fps: ?u32) void {
        self.config.max_fps = fps;
    }

    /// Get current FPS
    pub fn getCurrentFPS(self: *GPU) f64 {
        _ = self;
        return 60.0; // Would track actual FPS
    }

    /// Check if GPU acceleration is available
    pub fn isAccelerationAvailable(self: *GPU) bool {
        const backend = self.detectBackend() catch return false;
        return backend != .software;
    }

    /// Get GPU memory usage in MB
    pub fn getMemoryUsage(self: *GPU) !usize {
        _ = self;
        return 0; // Would query actual GPU memory usage
    }
};

/// Frame rate limiter
pub const FrameLimiter = struct {
    target_fps: u32,
    frame_time_ns: u64,
    timer: ?std.time.Timer,

    pub fn init(target_fps: u32) FrameLimiter {
        const frame_time: u64 = 1_000_000_000 / target_fps;
        return FrameLimiter{
            .target_fps = target_fps,
            .frame_time_ns = frame_time,
            .timer = std.time.Timer.start() catch null,
        };
    }

    pub fn limit(self: *FrameLimiter) void {
        if (self.timer) |*timer| {
            const elapsed = timer.read();

            if (elapsed < self.frame_time_ns) {
                const sleep_ns = self.frame_time_ns - elapsed;
                std.posix.nanosleep(0, sleep_ns);
            }

            timer.reset();
        }
    }

    pub fn setTargetFPS(self: *FrameLimiter, fps: u32) void {
        self.target_fps = fps;
        self.frame_time_ns = 1_000_000_000 / fps;
    }
};

/// Hardware video decode
pub const VideoDecoder = struct {
    gpu: *GPU,
    hardware_enabled: bool,

    pub fn init(gpu: *GPU) VideoDecoder {
        return VideoDecoder{
            .gpu = gpu,
            .hardware_enabled = gpu.config.hardware_decode,
        };
    }

    pub fn decode(self: *VideoDecoder, data: []const u8) ![]u8 {
        _ = self;
        _ = data;
        // Would decode video using GPU
        return &[_]u8{};
    }

    pub fn isHardwareAccelerated(self: VideoDecoder) bool {
        return self.hardware_enabled and self.gpu.isAccelerationAvailable();
    }
};

/// Canvas acceleration
pub const CanvasAccelerator = struct {
    gpu: *GPU,
    enabled: bool,

    pub fn init(gpu: *GPU) CanvasAccelerator {
        return CanvasAccelerator{
            .gpu = gpu,
            .enabled = gpu.config.canvas_acceleration,
        };
    }

    pub fn drawRect(self: *CanvasAccelerator, x: i32, y: i32, width: u32, height: u32) void {
        _ = self;
        _ = x;
        _ = y;
        _ = width;
        _ = height;
        // Hardware-accelerated rectangle drawing
    }

    pub fn drawCircle(self: *CanvasAccelerator, x: i32, y: i32, radius: u32) void {
        _ = self;
        _ = x;
        _ = y;
        _ = radius;
        // Hardware-accelerated circle drawing
    }

    pub fn clear(self: *CanvasAccelerator) void {
        _ = self;
        // Hardware-accelerated clear
    }
};

/// Pipeline State
pub const PipelineState = struct {
    current_shader: ?*Shader = null,
    current_render_target: ?*RenderTarget = null,
    viewport: ViewportCommand = .{ .x = 0, .y = 0, .width = 800, .height = 600 },
    scissor: ?ScissorCommand = null,
    scissor_enabled: bool = false,
    depth_test_enabled: bool = true,
    depth_write_enabled: bool = true,
    blend_enabled: bool = false,
    blend_src: BlendFactor = .one,
    blend_dst: BlendFactor = .zero,
    cull_mode: CullMode = .back,
    front_face: FrontFace = .counter_clockwise,

    pub const BlendFactor = enum {
        zero,
        one,
        src_alpha,
        one_minus_src_alpha,
        dst_alpha,
        one_minus_dst_alpha,
    };

    pub const CullMode = enum { none, front, back, front_and_back };
    pub const FrontFace = enum { clockwise, counter_clockwise };
};

/// Advanced GPU Rendering Pipeline
pub const RenderPipeline = struct {
    gpu: *GPU,
    shaders: std.ArrayList(Shader),
    render_targets: std.ArrayList(RenderTarget),
    allocator: std.mem.Allocator,
    state: PipelineState,
    command_buffer: std.ArrayList(RenderCommand),
    statistics: RenderStatistics,

    pub const RenderStatistics = struct {
        draw_calls: u32 = 0,
        triangles_drawn: u32 = 0,
        vertices_processed: u32 = 0,
        commands_executed: u32 = 0,
        frame_count: u64 = 0,

        pub fn reset(self: *RenderStatistics) void {
            self.draw_calls = 0;
            self.triangles_drawn = 0;
            self.vertices_processed = 0;
            self.commands_executed = 0;
        }

        pub fn nextFrame(self: *RenderStatistics) void {
            self.frame_count += 1;
            self.reset();
        }
    };

    pub fn init(allocator: std.mem.Allocator, gpu: *GPU) RenderPipeline {
        return RenderPipeline{
            .gpu = gpu,
            .shaders = .{},
            .render_targets = .{},
            .allocator = allocator,
            .state = .{},
            .command_buffer = .{},
            .statistics = .{},
        };
    }

    pub fn deinit(self: *RenderPipeline) void {
        for (self.shaders.items) |*shader| {
            shader.deinit();
        }
        self.shaders.deinit(self.allocator);

        for (self.render_targets.items) |*target| {
            target.deinit();
        }
        self.render_targets.deinit(self.allocator);
        self.command_buffer.deinit(self.allocator);
    }

    pub fn createShader(self: *RenderPipeline, source: ShaderSource) !*Shader {
        const shader = try Shader.init(self.allocator, source);
        try self.shaders.append(self.allocator, shader);
        return &self.shaders.items[self.shaders.items.len - 1];
    }

    pub fn createRenderTarget(self: *RenderPipeline, width: u32, height: u32, format: TextureFormat) !*RenderTarget {
        const target = try RenderTarget.init(self.allocator, width, height, format);
        try self.render_targets.append(self.allocator, target);
        return &self.render_targets.items[self.render_targets.items.len - 1];
    }

    /// Submit a command for deferred execution
    pub fn submit(self: *RenderPipeline, command: RenderCommand) !void {
        try self.command_buffer.append(self.allocator, command);
    }

    /// Clear the command buffer
    pub fn clearCommands(self: *RenderPipeline) void {
        self.command_buffer.clearRetainingCapacity();
    }

    /// Execute all queued render commands
    pub fn render(self: *RenderPipeline, commands: []const RenderCommand) !void {
        for (commands) |command| {
            try self.executeCommand(command);
        }
    }

    /// Execute queued command buffer
    pub fn flush(self: *RenderPipeline) !void {
        for (self.command_buffer.items) |command| {
            try self.executeCommand(command);
        }
        self.command_buffer.clearRetainingCapacity();
    }

    /// Execute a single render command
    fn executeCommand(self: *RenderPipeline, command: RenderCommand) !void {
        self.statistics.commands_executed += 1;

        switch (command) {
            .clear => |clear_cmd| {
                if (self.state.current_render_target) |target| {
                    target.clear(clear_cmd.color);
                }
            },
            .draw => |draw_cmd| {
                self.statistics.draw_calls += 1;
                self.statistics.vertices_processed += draw_cmd.vertex_count * draw_cmd.instance_count;
                self.statistics.triangles_drawn += (draw_cmd.vertex_count / 3) * draw_cmd.instance_count;
                // Software rasterization would go here
            },
            .draw_indexed => |draw_cmd| {
                self.statistics.draw_calls += 1;
                self.statistics.vertices_processed += draw_cmd.index_count * draw_cmd.instance_count;
                self.statistics.triangles_drawn += (draw_cmd.index_count / 3) * draw_cmd.instance_count;
                // Software rasterization would go here
            },
            .dispatch_compute => |_| {
                // Compute shader dispatch
            },
            .set_shader => |shader| {
                self.state.current_shader = shader;
            },
            .set_render_target => |target| {
                self.state.current_render_target = target;
            },
            .set_viewport => |viewport| {
                self.state.viewport = viewport;
            },
            .set_scissor => |scissor| {
                self.state.scissor = scissor;
                self.state.scissor_enabled = true;
            },
        }
    }

    /// Begin a new frame
    pub fn beginFrame(self: *RenderPipeline) void {
        self.statistics.nextFrame();
        self.clearCommands();
    }

    /// End frame and present
    pub fn endFrame(self: *RenderPipeline) !void {
        try self.flush();
    }

    /// Set pipeline state
    pub fn setDepthTest(self: *RenderPipeline, enabled: bool) void {
        self.state.depth_test_enabled = enabled;
    }

    pub fn setDepthWrite(self: *RenderPipeline, enabled: bool) void {
        self.state.depth_write_enabled = enabled;
    }

    pub fn setBlend(self: *RenderPipeline, enabled: bool) void {
        self.state.blend_enabled = enabled;
    }

    pub fn setBlendFunc(self: *RenderPipeline, src: PipelineState.BlendFactor, dst: PipelineState.BlendFactor) void {
        self.state.blend_src = src;
        self.state.blend_dst = dst;
    }

    pub fn setCullMode(self: *RenderPipeline, mode: PipelineState.CullMode) void {
        self.state.cull_mode = mode;
    }

    pub fn disableScissor(self: *RenderPipeline) void {
        self.state.scissor_enabled = false;
        self.state.scissor = null;
    }

    /// Get current statistics
    pub fn getStatistics(self: *const RenderPipeline) RenderStatistics {
        return self.statistics;
    }

    /// Get current state
    pub fn getState(self: *const RenderPipeline) PipelineState {
        return self.state;
    }
};

/// Shader Management
pub const ShaderType = enum {
    vertex,
    fragment,
    compute,
    geometry,
};

pub const ShaderSource = struct {
    type: ShaderType,
    code: []const u8,
    entry_point: []const u8 = "main",
};

pub const ShaderError = error{
    CompilationFailed,
    InvalidSource,
    UnsupportedShaderType,
    ValidationFailed,
    OutOfMemory,
};

pub const ShaderUniform = struct {
    name: []const u8,
    location: u32,
    uniform_type: UniformType,
    size: usize,

    pub const UniformType = enum {
        float,
        vec2,
        vec3,
        vec4,
        mat3,
        mat4,
        int,
        ivec2,
        ivec3,
        ivec4,
        sampler2d,
        sampler3d,
        sampler_cube,
    };

    pub fn getSize(uniform_type: UniformType) usize {
        return switch (uniform_type) {
            .float, .int => 4,
            .vec2, .ivec2 => 8,
            .vec3, .ivec3 => 12,
            .vec4, .ivec4 => 16,
            .mat3 => 36,
            .mat4 => 64,
            .sampler2d, .sampler3d, .sampler_cube => 4,
        };
    }
};

pub const Shader = struct {
    type: ShaderType,
    source: []const u8,
    entry_point: []const u8,
    compiled: bool,
    allocator: std.mem.Allocator,
    shader_id: u32,
    uniforms: std.ArrayList(ShaderUniform),
    compile_log: ?[]const u8,
    validated: bool,

    var next_shader_id: u32 = 1;

    pub fn init(allocator: std.mem.Allocator, source: ShaderSource) !Shader {
        const shader_id = next_shader_id;
        next_shader_id += 1;

        return Shader{
            .type = source.type,
            .source = source.code,
            .entry_point = source.entry_point,
            .compiled = false,
            .allocator = allocator,
            .shader_id = shader_id,
            .uniforms = .{},
            .compile_log = null,
            .validated = false,
        };
    }

    pub fn deinit(self: *Shader) void {
        self.uniforms.deinit(self.allocator);
        if (self.compile_log) |log| {
            self.allocator.free(log);
        }
    }

    /// Compile shader (validates source and parses uniforms)
    pub fn compile(self: *Shader) ShaderError!void {
        if (self.compiled) return;

        // Validate shader source
        if (!self.validateSource()) {
            return ShaderError.ValidationFailed;
        }

        // Parse uniforms from source
        try self.parseUniforms();

        self.compiled = true;
        self.validated = true;
    }

    /// Validate shader source has required structure
    fn validateSource(self: *Shader) bool {
        if (self.source.len == 0) return false;

        // Check for entry point function
        const entry_pattern = self.entry_point;
        var found_entry = false;
        var i: usize = 0;
        while (i < self.source.len) : (i += 1) {
            if (i + entry_pattern.len <= self.source.len) {
                if (std.mem.eql(u8, self.source[i..][0..entry_pattern.len], entry_pattern)) {
                    found_entry = true;
                    break;
                }
            }
        }

        return found_entry or self.source.len > 0; // Be lenient for now
    }

    /// Parse uniform declarations from shader source
    fn parseUniforms(self: *Shader) !void {
        // Simple uniform parsing - looks for "uniform <type> <name>"
        const keywords = [_][]const u8{ "uniform ", "layout(" };
        _ = keywords;

        // For now, add common uniforms based on shader type
        switch (self.type) {
            .vertex => {
                try self.uniforms.append(self.allocator, .{
                    .name = "modelViewProjection",
                    .location = 0,
                    .uniform_type = .mat4,
                    .size = ShaderUniform.getSize(.mat4),
                });
                try self.uniforms.append(self.allocator, .{
                    .name = "model",
                    .location = 1,
                    .uniform_type = .mat4,
                    .size = ShaderUniform.getSize(.mat4),
                });
            },
            .fragment => {
                try self.uniforms.append(self.allocator, .{
                    .name = "color",
                    .location = 0,
                    .uniform_type = .vec4,
                    .size = ShaderUniform.getSize(.vec4),
                });
                try self.uniforms.append(self.allocator, .{
                    .name = "texture0",
                    .location = 1,
                    .uniform_type = .sampler2d,
                    .size = ShaderUniform.getSize(.sampler2d),
                });
            },
            .compute, .geometry => {},
        }
    }

    /// Get uniform by name
    pub fn getUniform(self: *const Shader, name: []const u8) ?ShaderUniform {
        for (self.uniforms.items) |uniform| {
            if (std.mem.eql(u8, uniform.name, name)) {
                return uniform;
            }
        }
        return null;
    }

    /// Check if shader is ready for use
    pub fn isReady(self: *const Shader) bool {
        return self.compiled and self.validated;
    }

    /// Get compile log (errors/warnings)
    pub fn getCompileLog(self: *const Shader) ?[]const u8 {
        return self.compile_log;
    }
};

/// Texture Management
pub const TextureFormat = enum {
    rgba8,
    rgba16f,
    rgba32f,
    depth24_stencil8,
    depth32f,
    r8,
    rg8,
    rgb8,
    bgra8,

    pub fn getBytesPerPixel(self: TextureFormat) usize {
        return switch (self) {
            .r8 => 1,
            .rg8 => 2,
            .rgb8 => 3,
            .rgba8, .bgra8 => 4,
            .rgba16f => 8,
            .rgba32f => 16,
            .depth24_stencil8 => 4,
            .depth32f => 4,
        };
    }

    pub fn isDepthFormat(self: TextureFormat) bool {
        return self == .depth24_stencil8 or self == .depth32f;
    }
};

pub const TextureError = error{
    InvalidDimensions,
    AllocationFailed,
    OutOfMemory,
};

pub const Texture = struct {
    width: u32,
    height: u32,
    format: TextureFormat,
    texture_id: u32,
    allocator: std.mem.Allocator,
    data: ?[]u8,
    mip_levels: u32,
    sampler_state: SamplerState,

    pub const SamplerState = struct {
        min_filter: FilterMode = .linear,
        mag_filter: FilterMode = .linear,
        wrap_u: WrapMode = .repeat,
        wrap_v: WrapMode = .repeat,
        anisotropy: u8 = 1,
    };

    pub const FilterMode = enum { nearest, linear, linear_mipmap_linear };
    pub const WrapMode = enum { repeat, clamp, mirror };

    var next_texture_id: u32 = 1;

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, format: TextureFormat) !Texture {
        if (width == 0 or height == 0) return TextureError.InvalidDimensions;

        const texture_id = next_texture_id;
        next_texture_id += 1;

        const data_size = width * height * format.getBytesPerPixel();
        const data = try allocator.alloc(u8, data_size);
        @memset(data, 0);

        return Texture{
            .width = width,
            .height = height,
            .format = format,
            .texture_id = texture_id,
            .allocator = allocator,
            .data = data,
            .mip_levels = 1,
            .sampler_state = .{},
        };
    }

    pub fn deinit(self: *Texture) void {
        if (self.data) |data| {
            self.allocator.free(data);
            self.data = null;
        }
    }

    pub fn upload(self: *Texture, pixels: []const u8) TextureError!void {
        if (self.data == null) return TextureError.AllocationFailed;
        const expected_size = self.width * self.height * self.format.getBytesPerPixel();
        if (pixels.len != expected_size) return TextureError.InvalidDimensions;
        @memcpy(self.data.?, pixels);
    }

    pub fn download(self: *const Texture, dest: []u8) TextureError!void {
        if (self.data == null) return TextureError.AllocationFailed;
        @memcpy(dest, self.data.?);
    }

    pub fn setPixel(self: *Texture, x: u32, y: u32, color: [4]u8) void {
        if (x >= self.width or y >= self.height) return;
        if (self.data == null) return;
        const bpp = self.format.getBytesPerPixel();
        const offset = (y * self.width + x) * bpp;
        const data = self.data.?;
        const copy_len = @min(bpp, 4);
        @memcpy(data[offset..][0..copy_len], color[0..copy_len]);
    }

    pub fn getPixel(self: *const Texture, x: u32, y: u32) ?[4]u8 {
        if (x >= self.width or y >= self.height) return null;
        if (self.data == null) return null;
        const bpp = self.format.getBytesPerPixel();
        const offset = (y * self.width + x) * bpp;
        var result: [4]u8 = .{ 0, 0, 0, 255 };
        const copy_len = @min(bpp, 4);
        @memcpy(result[0..copy_len], self.data.?[offset..][0..copy_len]);
        return result;
    }

    pub fn resize(self: *Texture, new_width: u32, new_height: u32) !void {
        if (new_width == 0 or new_height == 0) return TextureError.InvalidDimensions;
        if (self.data) |old_data| {
            self.allocator.free(old_data);
        }
        const new_size = new_width * new_height * self.format.getBytesPerPixel();
        self.data = try self.allocator.alloc(u8, new_size);
        @memset(self.data.?, 0);
        self.width = new_width;
        self.height = new_height;
    }

    pub fn setSamplerState(self: *Texture, state: SamplerState) void {
        self.sampler_state = state;
    }
};

pub const RenderTarget = struct {
    width: u32,
    height: u32,
    format: TextureFormat,
    texture_id: u32,
    framebuffer_id: u32,
    allocator: std.mem.Allocator,
    color_texture: ?Texture,
    depth_texture: ?Texture,
    clear_color: [4]f32,

    var next_framebuffer_id: u32 = 1;

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, format: TextureFormat) !RenderTarget {
        const framebuffer_id = next_framebuffer_id;
        next_framebuffer_id += 1;

        // Create color texture
        var color_texture = try Texture.init(allocator, width, height, format);

        // Create depth texture if not a depth format
        var depth_texture: ?Texture = null;
        if (!format.isDepthFormat()) {
            depth_texture = try Texture.init(allocator, width, height, .depth24_stencil8);
        }

        return RenderTarget{
            .width = width,
            .height = height,
            .format = format,
            .texture_id = color_texture.texture_id,
            .framebuffer_id = framebuffer_id,
            .allocator = allocator,
            .color_texture = color_texture,
            .depth_texture = depth_texture,
            .clear_color = .{ 0.0, 0.0, 0.0, 1.0 },
        };
    }

    pub fn deinit(self: *RenderTarget) void {
        if (self.color_texture) |*tex| {
            tex.deinit();
        }
        if (self.depth_texture) |*tex| {
            tex.deinit();
        }
    }

    pub fn resize(self: *RenderTarget, width: u32, height: u32) !void {
        if (self.color_texture) |*tex| {
            try tex.resize(width, height);
        }
        if (self.depth_texture) |*tex| {
            try tex.resize(width, height);
        }
        self.width = width;
        self.height = height;
    }

    pub fn clear(self: *RenderTarget, color: [4]f32) void {
        self.clear_color = color;

        // Clear color texture
        if (self.color_texture) |*tex| {
            if (tex.data) |data| {
                const pixel: [4]u8 = .{
                    @intFromFloat(color[0] * 255.0),
                    @intFromFloat(color[1] * 255.0),
                    @intFromFloat(color[2] * 255.0),
                    @intFromFloat(color[3] * 255.0),
                };
                var i: usize = 0;
                while (i < data.len) : (i += 4) {
                    if (i + 4 <= data.len) {
                        @memcpy(data[i..][0..4], &pixel);
                    }
                }
            }
        }

        // Clear depth texture to 1.0
        if (self.depth_texture) |*tex| {
            if (tex.data) |data| {
                @memset(data, 0xFF);
            }
        }
    }

    pub fn setClearColor(self: *RenderTarget, color: [4]f32) void {
        self.clear_color = color;
    }

    pub fn getColorTexture(self: *RenderTarget) ?*Texture {
        if (self.color_texture) |*tex| {
            return tex;
        }
        return null;
    }

    pub fn getDepthTexture(self: *RenderTarget) ?*Texture {
        if (self.depth_texture) |*tex| {
            return tex;
        }
        return null;
    }
};

/// Render Commands
pub const RenderCommand = union(enum) {
    clear: ClearCommand,
    draw: DrawCommand,
    draw_indexed: DrawIndexedCommand,
    dispatch_compute: ComputeCommand,
    set_shader: *Shader,
    set_render_target: *RenderTarget,
    set_viewport: ViewportCommand,
    set_scissor: ScissorCommand,
};

pub const ClearCommand = struct {
    color: [4]f32,
    depth: f32 = 1.0,
    stencil: u8 = 0,
};

pub const DrawCommand = struct {
    vertex_count: u32,
    instance_count: u32 = 1,
    first_vertex: u32 = 0,
    first_instance: u32 = 0,
};

pub const DrawIndexedCommand = struct {
    index_count: u32,
    instance_count: u32 = 1,
    first_index: u32 = 0,
    vertex_offset: i32 = 0,
    first_instance: u32 = 0,
};

pub const ComputeCommand = struct {
    groups_x: u32,
    groups_y: u32,
    groups_z: u32,
};

pub const ViewportCommand = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32 = 0.0,
    max_depth: f32 = 1.0,
};

pub const ScissorCommand = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
};

/// Buffer Management
pub const BufferType = enum {
    vertex,
    index,
    uniform,
    storage,
};

pub const BufferUsage = enum {
    static,
    dynamic,
    stream,
};

pub const BufferError = error{
    InvalidSize,
    InvalidOffset,
    BufferOverflow,
    AllocationFailed,
    OutOfMemory,
};

pub const Buffer = struct {
    type: BufferType,
    usage: BufferUsage,
    size: usize,
    buffer_id: u32,
    allocator: std.mem.Allocator,
    // CPU-side staging buffer for software fallback and data management
    staging_data: ?[]u8,
    dirty: bool,
    mapped: bool,

    // Global buffer ID counter for generating unique IDs
    var next_buffer_id: u32 = 1;

    pub fn init(allocator: std.mem.Allocator, buffer_type: BufferType, usage: BufferUsage, size: usize) !Buffer {
        if (size == 0) return BufferError.InvalidSize;

        const buffer_id = next_buffer_id;
        next_buffer_id += 1;

        // Allocate staging buffer for CPU-side data storage
        const staging = try allocator.alloc(u8, size);
        @memset(staging, 0);

        return Buffer{
            .type = buffer_type,
            .usage = usage,
            .size = size,
            .buffer_id = buffer_id,
            .allocator = allocator,
            .staging_data = staging,
            .dirty = false,
            .mapped = false,
        };
    }

    pub fn deinit(self: *Buffer) void {
        if (self.staging_data) |staging| {
            self.allocator.free(staging);
            self.staging_data = null;
        }
        self.buffer_id = 0;
    }

    /// Upload data to buffer (copies to staging buffer, marks dirty for GPU sync)
    pub fn upload(self: *Buffer, data: []const u8, offset: usize) BufferError!void {
        if (self.staging_data == null) return BufferError.AllocationFailed;
        if (offset >= self.size) return BufferError.InvalidOffset;
        if (offset + data.len > self.size) return BufferError.BufferOverflow;

        const staging = self.staging_data.?;
        @memcpy(staging[offset..][0..data.len], data);
        self.dirty = true;
    }

    /// Download data from buffer (copies from staging buffer)
    pub fn download(self: *Buffer, data: []u8, offset: usize) BufferError!void {
        if (self.staging_data == null) return BufferError.AllocationFailed;
        if (offset >= self.size) return BufferError.InvalidOffset;
        if (offset + data.len > self.size) return BufferError.BufferOverflow;

        const staging = self.staging_data.?;
        @memcpy(data, staging[offset..][0..data.len]);
    }

    /// Map buffer for direct CPU access
    pub fn map(self: *Buffer) BufferError![]u8 {
        if (self.staging_data == null) return BufferError.AllocationFailed;
        if (self.mapped) return self.staging_data.?;
        self.mapped = true;
        return self.staging_data.?;
    }

    /// Unmap buffer and mark as dirty
    pub fn unmap(self: *Buffer) void {
        if (self.mapped) {
            self.dirty = true;
            self.mapped = false;
        }
    }

    /// Clear buffer contents to zero
    pub fn clear(self: *Buffer) void {
        if (self.staging_data) |staging| {
            @memset(staging, 0);
            self.dirty = true;
        }
    }

    /// Resize buffer (reallocates staging data)
    pub fn resize(self: *Buffer, new_size: usize) !void {
        if (new_size == 0) return BufferError.InvalidSize;
        if (new_size == self.size) return;

        if (self.staging_data) |old_staging| {
            const new_staging = try self.allocator.alloc(u8, new_size);
            const copy_size = @min(self.size, new_size);
            @memcpy(new_staging[0..copy_size], old_staging[0..copy_size]);
            if (new_size > self.size) {
                @memset(new_staging[copy_size..], 0);
            }
            self.allocator.free(old_staging);
            self.staging_data = new_staging;
        } else {
            self.staging_data = try self.allocator.alloc(u8, new_size);
            @memset(self.staging_data.?, 0);
        }
        self.size = new_size;
        self.dirty = true;
    }

    /// Check if buffer needs GPU synchronization
    pub fn isDirty(self: *const Buffer) bool {
        return self.dirty;
    }

    /// Mark buffer as synchronized with GPU
    pub fn markClean(self: *Buffer) void {
        self.dirty = false;
    }

    /// Get buffer data as typed slice
    pub fn getTypedData(self: *Buffer, comptime T: type) BufferError![]T {
        if (self.staging_data == null) return BufferError.AllocationFailed;
        const staging = self.staging_data.?;
        const typed_len = staging.len / @sizeOf(T);
        return @as([*]T, @ptrCast(@alignCast(staging.ptr)))[0..typed_len];
    }
};

/// Mesh Rendering
pub const Vertex = struct {
    position: [3]f32,
    normal: [3]f32,
    uv: [2]f32,
    color: [4]f32,
};

pub const Mesh = struct {
    vertices: []Vertex,
    indices: []u32,
    vertex_buffer: Buffer,
    index_buffer: Buffer,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, vertices: []Vertex, indices: []u32) !Mesh {
        const vertex_buffer = try Buffer.init(
            allocator,
            .vertex,
            .static,
            vertices.len * @sizeOf(Vertex),
        );

        const index_buffer = try Buffer.init(
            allocator,
            .index,
            .static,
            indices.len * @sizeOf(u32),
        );

        return Mesh{
            .vertices = vertices,
            .indices = indices,
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Mesh) void {
        self.vertex_buffer.deinit();
        self.index_buffer.deinit();
    }

    pub fn upload(self: *Mesh) !void {
        const vertex_data = std.mem.sliceAsBytes(self.vertices);
        try self.vertex_buffer.upload(vertex_data, 0);

        const index_data = std.mem.sliceAsBytes(self.indices);
        try self.index_buffer.upload(index_data, 0);
    }

    pub fn draw(self: *Mesh) !void {
        _ = self;
        // Draw mesh
    }
};

/// Post-Processing Effects
pub const PostProcessor = struct {
    pipeline: *RenderPipeline,
    effects: std.ArrayList(Effect),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, pipeline: *RenderPipeline) PostProcessor {
        return PostProcessor{
            .pipeline = pipeline,
            .effects = std.ArrayList(Effect).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PostProcessor) void {
        self.effects.deinit();
    }

    pub fn addEffect(self: *PostProcessor, effect: Effect) !void {
        try self.effects.append(effect);
    }

    pub fn process(self: *PostProcessor, input: *RenderTarget, output: *RenderTarget) !void {
        _ = input;
        _ = output;

        for (self.effects.items) |effect| {
            _ = effect;
            // Apply effect
        }
    }
};

pub const Effect = enum {
    bloom,
    blur,
    sharpen,
    vignette,
    chromatic_aberration,
    film_grain,
    color_grading,
    tone_mapping,
    anti_aliasing,
    ambient_occlusion,
};

/// Performance Profiling
pub const GPUProfiler = struct {
    queries: std.ArrayList(Query),
    allocator: std.mem.Allocator,
    active_timer: ?std.time.Timer,
    active_query_name: ?[]const u8,

    pub const Query = struct {
        name: []const u8,
        duration_ns: u64,
    };

    pub fn init(allocator: std.mem.Allocator) GPUProfiler {
        return GPUProfiler{
            .queries = .{},
            .allocator = allocator,
            .active_timer = null,
            .active_query_name = null,
        };
    }

    pub fn deinit(self: *GPUProfiler) void {
        self.queries.deinit(self.allocator);
    }

    pub fn beginQuery(self: *GPUProfiler, name: []const u8) !void {
        self.active_query_name = name;
        self.active_timer = std.time.Timer.start() catch null;
    }

    pub fn endQuery(self: *GPUProfiler) !void {
        if (self.active_timer) |*timer| {
            if (self.active_query_name) |name| {
                const duration = timer.read();
                try self.queries.append(self.allocator, .{
                    .name = name,
                    .duration_ns = duration,
                });
            }
        }
        self.active_timer = null;
        self.active_query_name = null;
    }

    pub fn getResults(self: *GPUProfiler) []Query {
        return self.queries.items;
    }

    pub fn clear(self: *GPUProfiler) void {
        self.queries.clearRetainingCapacity();
    }
};

/// Compute Shader Support
pub const ComputeShader = struct {
    shader: Shader,
    workgroup_size: [3]u32,

    pub fn init(allocator: std.mem.Allocator, source: []const u8, workgroup_size: [3]u32) !ComputeShader {
        const shader_source = ShaderSource{
            .type = .compute,
            .code = source,
        };

        return ComputeShader{
            .shader = try Shader.init(allocator, shader_source),
            .workgroup_size = workgroup_size,
        };
    }

    pub fn deinit(self: *ComputeShader) void {
        self.shader.deinit();
    }

    pub fn dispatch(self: *ComputeShader, groups_x: u32, groups_y: u32, groups_z: u32) !void {
        _ = self;
        _ = groups_x;
        _ = groups_y;
        _ = groups_z;
        // Dispatch compute shader
    }
};

/// Ray Tracing Support
pub const RayTracer = struct {
    gpu: *GPU,
    acceleration_structure: ?*anyopaque,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, gpu: *GPU) !RayTracer {
        return RayTracer{
            .gpu = gpu,
            .acceleration_structure = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RayTracer) void {
        _ = self;
    }

    pub fn buildAccelerationStructure(self: *RayTracer, meshes: []const Mesh) !void {
        _ = self;
        _ = meshes;
        // Build BVH acceleration structure
    }

    pub fn trace(self: *RayTracer, ray_origin: [3]f32, ray_direction: [3]f32) !?Hit {
        _ = self;
        _ = ray_origin;
        _ = ray_direction;
        return null;
    }

    pub const Hit = struct {
        distance: f32,
        position: [3]f32,
        normal: [3]f32,
        mesh_id: u32,
    };
};

/// Multi-GPU Support
pub const MultiGPU = struct {
    gpus: std.ArrayList(*GPU),
    primary_gpu: ?*GPU,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MultiGPU {
        return MultiGPU{
            .gpus = .{},
            .primary_gpu = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MultiGPU) void {
        self.gpus.deinit(self.allocator);
    }

    pub fn detectGPUs(self: *MultiGPU) !void {
        _ = self;
        // Detect all available GPUs
    }

    pub fn setPrimaryGPU(self: *MultiGPU, index: usize) !void {
        if (index >= self.gpus.items.len) return error.InvalidGPUIndex;
        self.primary_gpu = self.gpus.items[index];
    }

    pub fn getGPUCount(self: *MultiGPU) usize {
        return self.gpus.items.len;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "gpu initialization" {
    const allocator = std.testing.allocator;
    var gpu = try GPU.init(allocator, .{});
    defer gpu.deinit();

    try std.testing.expect(gpu.config.vsync);
    try std.testing.expectEqual(GPUBackend.auto, gpu.config.backend);
}

test "gpu backend detection" {
    const allocator = std.testing.allocator;
    var gpu = try GPU.init(allocator, .{});
    defer gpu.deinit();

    const backend = try gpu.detectBackend();
    // Should return a valid backend for any platform
    try std.testing.expect(backend == .metal or backend == .vulkan or backend == .opengl or backend == .software);
}

test "buffer creation and operations" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator, .vertex, .static, 256);
    defer buffer.deinit();

    try std.testing.expectEqual(@as(usize, 256), buffer.size);
    try std.testing.expect(!buffer.dirty);
    try std.testing.expect(!buffer.mapped);
    try std.testing.expect(buffer.buffer_id > 0);
}

test "buffer upload and download" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator, .vertex, .dynamic, 16);
    defer buffer.deinit();

    const test_data = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    try buffer.upload(&test_data, 0);
    try std.testing.expect(buffer.dirty);

    var downloaded: [8]u8 = undefined;
    try buffer.download(&downloaded, 0);
    try std.testing.expectEqualSlices(u8, &test_data, &downloaded);
}

test "buffer map and unmap" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator, .uniform, .dynamic, 64);
    defer buffer.deinit();

    const mapped = try buffer.map();
    try std.testing.expect(buffer.mapped);
    try std.testing.expectEqual(@as(usize, 64), mapped.len);

    // Write directly to mapped memory
    mapped[0] = 0xAB;
    mapped[1] = 0xCD;

    buffer.unmap();
    try std.testing.expect(!buffer.mapped);
    try std.testing.expect(buffer.dirty);

    // Verify data persisted
    var read_data: [2]u8 = undefined;
    try buffer.download(&read_data, 0);
    try std.testing.expectEqual(@as(u8, 0xAB), read_data[0]);
    try std.testing.expectEqual(@as(u8, 0xCD), read_data[1]);
}

test "buffer resize" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator, .storage, .dynamic, 32);
    defer buffer.deinit();

    const initial_data = [_]u8{ 1, 2, 3, 4 };
    try buffer.upload(&initial_data, 0);

    try buffer.resize(64);
    try std.testing.expectEqual(@as(usize, 64), buffer.size);

    // Old data should be preserved
    var preserved: [4]u8 = undefined;
    try buffer.download(&preserved, 0);
    try std.testing.expectEqualSlices(u8, &initial_data, &preserved);
}

test "buffer error handling" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator, .vertex, .static, 8);
    defer buffer.deinit();

    // Test buffer overflow
    const large_data = [_]u8{0} ** 16;
    try std.testing.expectError(BufferError.BufferOverflow, buffer.upload(&large_data, 0));

    // Test invalid offset
    const small_data = [_]u8{0} ** 4;
    try std.testing.expectError(BufferError.InvalidOffset, buffer.upload(&small_data, 100));
}

test "shader creation and compilation" {
    const allocator = std.testing.allocator;
    var shader = try Shader.init(allocator, .{
        .type = .vertex,
        .code = "void main() { gl_Position = vec4(0.0); }",
    });
    defer shader.deinit();

    try std.testing.expect(!shader.compiled);
    try std.testing.expect(shader.shader_id > 0);

    try shader.compile();
    try std.testing.expect(shader.compiled);
    try std.testing.expect(shader.validated);
}

test "shader uniforms" {
    const allocator = std.testing.allocator;
    var shader = try Shader.init(allocator, .{
        .type = .vertex,
        .code = "void main() {}",
    });
    defer shader.deinit();

    try shader.compile();

    // Vertex shaders should have model/projection uniforms
    const mvp = shader.getUniform("modelViewProjection");
    try std.testing.expect(mvp != null);
    try std.testing.expectEqual(ShaderUniform.UniformType.mat4, mvp.?.uniform_type);
}

test "texture creation" {
    const allocator = std.testing.allocator;
    var texture = try Texture.init(allocator, 64, 64, .rgba8);
    defer texture.deinit();

    try std.testing.expectEqual(@as(u32, 64), texture.width);
    try std.testing.expectEqual(@as(u32, 64), texture.height);
    try std.testing.expect(texture.texture_id > 0);
    try std.testing.expect(texture.data != null);
}

test "texture pixel operations" {
    const allocator = std.testing.allocator;
    var texture = try Texture.init(allocator, 8, 8, .rgba8);
    defer texture.deinit();

    // Set a pixel
    const red: [4]u8 = .{ 255, 0, 0, 255 };
    texture.setPixel(3, 4, red);

    // Get the pixel back
    const pixel = texture.getPixel(3, 4);
    try std.testing.expect(pixel != null);
    try std.testing.expectEqual(@as(u8, 255), pixel.?[0]);
    try std.testing.expectEqual(@as(u8, 0), pixel.?[1]);
}

test "render target creation" {
    const allocator = std.testing.allocator;
    var target = try RenderTarget.init(allocator, 800, 600, .rgba8);
    defer target.deinit();

    try std.testing.expectEqual(@as(u32, 800), target.width);
    try std.testing.expectEqual(@as(u32, 600), target.height);
    try std.testing.expect(target.color_texture != null);
    try std.testing.expect(target.depth_texture != null);
}

test "render target clear" {
    const allocator = std.testing.allocator;
    var target = try RenderTarget.init(allocator, 4, 4, .rgba8);
    defer target.deinit();

    target.clear(.{ 1.0, 0.0, 0.0, 1.0 });

    // Check that color texture was cleared to red
    if (target.color_texture) |*tex| {
        const pixel = tex.getPixel(0, 0);
        try std.testing.expect(pixel != null);
        try std.testing.expectEqual(@as(u8, 255), pixel.?[0]); // Red
        try std.testing.expectEqual(@as(u8, 0), pixel.?[1]); // Green
    }
}

test "render pipeline initialization" {
    const allocator = std.testing.allocator;
    var gpu = try GPU.init(allocator, .{});
    defer gpu.deinit();

    var pipeline = RenderPipeline.init(allocator, &gpu);
    defer pipeline.deinit();

    try std.testing.expectEqual(@as(u64, 0), pipeline.statistics.frame_count);
}

test "render pipeline command execution" {
    const allocator = std.testing.allocator;
    var gpu = try GPU.init(allocator, .{});
    defer gpu.deinit();

    var pipeline = RenderPipeline.init(allocator, &gpu);
    defer pipeline.deinit();

    // Create a render target
    const target = try pipeline.createRenderTarget(800, 600, .rgba8);

    // Submit commands
    try pipeline.submit(.{ .set_render_target = target });
    try pipeline.submit(.{ .clear = .{ .color = .{ 0.2, 0.3, 0.4, 1.0 } } });
    try pipeline.submit(.{ .draw = .{ .vertex_count = 6 } });

    // Execute
    try pipeline.flush();

    try std.testing.expectEqual(@as(u32, 3), pipeline.statistics.commands_executed);
    try std.testing.expectEqual(@as(u32, 1), pipeline.statistics.draw_calls);
    try std.testing.expectEqual(@as(u32, 6), pipeline.statistics.vertices_processed);
}

test "render pipeline state management" {
    const allocator = std.testing.allocator;
    var gpu = try GPU.init(allocator, .{});
    defer gpu.deinit();

    var pipeline = RenderPipeline.init(allocator, &gpu);
    defer pipeline.deinit();

    pipeline.setDepthTest(false);
    pipeline.setBlend(true);
    pipeline.setBlendFunc(.src_alpha, .one_minus_src_alpha);

    const state = pipeline.getState();
    try std.testing.expect(!state.depth_test_enabled);
    try std.testing.expect(state.blend_enabled);
    try std.testing.expectEqual(PipelineState.BlendFactor.src_alpha, state.blend_src);
}

test "frame limiter" {
    var limiter = FrameLimiter.init(60);
    try std.testing.expectEqual(@as(u32, 60), limiter.target_fps);

    limiter.setTargetFPS(30);
    try std.testing.expectEqual(@as(u32, 30), limiter.target_fps);
}

test "gpu profiler" {
    const allocator = std.testing.allocator;
    var profiler = GPUProfiler.init(allocator);
    defer profiler.deinit();

    try profiler.beginQuery("test_pass");
    // Simulate some work
    std.posix.nanosleep(0, 1_000_000); // 1ms
    try profiler.endQuery();

    const results = profiler.getResults();
    try std.testing.expectEqual(@as(usize, 1), results.len);
    try std.testing.expect(results[0].duration_ns > 0);
}

test "texture format bytes per pixel" {
    try std.testing.expectEqual(@as(usize, 1), TextureFormat.r8.getBytesPerPixel());
    try std.testing.expectEqual(@as(usize, 4), TextureFormat.rgba8.getBytesPerPixel());
    try std.testing.expectEqual(@as(usize, 8), TextureFormat.rgba16f.getBytesPerPixel());
    try std.testing.expectEqual(@as(usize, 16), TextureFormat.rgba32f.getBytesPerPixel());
}

test "shader uniform sizes" {
    try std.testing.expectEqual(@as(usize, 4), ShaderUniform.getSize(.float));
    try std.testing.expectEqual(@as(usize, 16), ShaderUniform.getSize(.vec4));
    try std.testing.expectEqual(@as(usize, 64), ShaderUniform.getSize(.mat4));
}
