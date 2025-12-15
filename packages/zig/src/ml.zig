//! Machine Learning support for Craft
//! Provides cross-platform abstractions for Core ML, TensorFlow Lite,
//! ONNX Runtime, and on-device AI inference.

const std = @import("std");

/// ML framework/runtime type
pub const MLFramework = enum {
    core_ml,
    tensorflow_lite,
    onnx_runtime,
    pytorch_mobile,
    ml_kit,
    windows_ml,
    openvino,
    unknown,

    pub fn toString(self: MLFramework) []const u8 {
        return switch (self) {
            .core_ml => "Core ML",
            .tensorflow_lite => "TensorFlow Lite",
            .onnx_runtime => "ONNX Runtime",
            .pytorch_mobile => "PyTorch Mobile",
            .ml_kit => "ML Kit",
            .windows_ml => "Windows ML",
            .openvino => "OpenVINO",
            .unknown => "Unknown",
        };
    }

    pub fn fileExtension(self: MLFramework) []const u8 {
        return switch (self) {
            .core_ml => ".mlmodel",
            .tensorflow_lite => ".tflite",
            .onnx_runtime => ".onnx",
            .pytorch_mobile => ".ptl",
            .ml_kit => ".tflite",
            .windows_ml => ".onnx",
            .openvino => ".xml",
            .unknown => "",
        };
    }

    pub fn supportsGPU(self: MLFramework) bool {
        return switch (self) {
            .core_ml, .tensorflow_lite, .onnx_runtime, .pytorch_mobile, .openvino => true,
            .ml_kit, .windows_ml, .unknown => false,
        };
    }

    pub fn supportsNPU(self: MLFramework) bool {
        return switch (self) {
            .core_ml, .tensorflow_lite => true,
            else => false,
        };
    }
};

/// Compute device for inference
pub const ComputeDevice = enum {
    cpu,
    gpu,
    npu, // Neural Processing Unit
    auto,

    pub fn toString(self: ComputeDevice) []const u8 {
        return switch (self) {
            .cpu => "CPU",
            .gpu => "GPU",
            .npu => "NPU",
            .auto => "Auto",
        };
    }

    pub fn isHardwareAccelerated(self: ComputeDevice) bool {
        return self != .cpu;
    }
};

/// Model precision/quantization
pub const ModelPrecision = enum {
    float32,
    float16,
    int8,
    int4,
    mixed,

    pub fn toString(self: ModelPrecision) []const u8 {
        return switch (self) {
            .float32 => "FP32",
            .float16 => "FP16",
            .int8 => "INT8",
            .int4 => "INT4",
            .mixed => "Mixed",
        };
    }

    pub fn bitsPerWeight(self: ModelPrecision) u8 {
        return switch (self) {
            .float32 => 32,
            .float16 => 16,
            .int8 => 8,
            .int4 => 4,
            .mixed => 16, // Average
        };
    }

    pub fn isQuantized(self: ModelPrecision) bool {
        return self == .int8 or self == .int4;
    }
};

/// Tensor data type
pub const TensorDataType = enum {
    float32,
    float16,
    float64,
    int8,
    int16,
    int32,
    int64,
    uint8,
    uint16,
    uint32,
    uint64,
    bool_type,
    string_type,

    pub fn toString(self: TensorDataType) []const u8 {
        return switch (self) {
            .float32 => "float32",
            .float16 => "float16",
            .float64 => "float64",
            .int8 => "int8",
            .int16 => "int16",
            .int32 => "int32",
            .int64 => "int64",
            .uint8 => "uint8",
            .uint16 => "uint16",
            .uint32 => "uint32",
            .uint64 => "uint64",
            .bool_type => "bool",
            .string_type => "string",
        };
    }

    pub fn byteSize(self: TensorDataType) u8 {
        return switch (self) {
            .float32, .int32, .uint32 => 4,
            .float16, .int16, .uint16 => 2,
            .float64, .int64, .uint64 => 8,
            .int8, .uint8, .bool_type => 1,
            .string_type => 0, // Variable
        };
    }

    pub fn isFloatingPoint(self: TensorDataType) bool {
        return self == .float32 or self == .float16 or self == .float64;
    }

    pub fn isInteger(self: TensorDataType) bool {
        return switch (self) {
            .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64 => true,
            else => false,
        };
    }
};

/// Tensor shape
pub const TensorShape = struct {
    dims: [8]u32,
    rank: u8,

    pub fn init(dimensions: []const u32) TensorShape {
        var shape = TensorShape{
            .dims = [_]u32{0} ** 8,
            .rank = @intCast(@min(dimensions.len, 8)),
        };
        for (dimensions[0..shape.rank], 0..) |dim, i| {
            shape.dims[i] = dim;
        }
        return shape;
    }

    pub fn scalar() TensorShape {
        return .{ .dims = [_]u32{0} ** 8, .rank = 0 };
    }

    pub fn vector(size: u32) TensorShape {
        var shape = TensorShape{ .dims = [_]u32{0} ** 8, .rank = 1 };
        shape.dims[0] = size;
        return shape;
    }

    pub fn matrix(rows: u32, cols: u32) TensorShape {
        var shape = TensorShape{ .dims = [_]u32{0} ** 8, .rank = 2 };
        shape.dims[0] = rows;
        shape.dims[1] = cols;
        return shape;
    }

    pub fn image(batch: u32, height: u32, width: u32, channels: u32) TensorShape {
        var shape = TensorShape{ .dims = [_]u32{0} ** 8, .rank = 4 };
        shape.dims[0] = batch;
        shape.dims[1] = height;
        shape.dims[2] = width;
        shape.dims[3] = channels;
        return shape;
    }

    pub fn elementCount(self: TensorShape) u64 {
        if (self.rank == 0) return 1;
        var count: u64 = 1;
        for (self.dims[0..self.rank]) |dim| {
            count *= dim;
        }
        return count;
    }

    pub fn dimension(self: TensorShape, index: u8) u32 {
        if (index >= self.rank) return 0;
        return self.dims[index];
    }

    pub fn isScalar(self: TensorShape) bool {
        return self.rank == 0;
    }

    pub fn isVector(self: TensorShape) bool {
        return self.rank == 1;
    }

    pub fn isMatrix(self: TensorShape) bool {
        return self.rank == 2;
    }
};

/// Tensor specification
pub const TensorSpec = struct {
    name: []const u8,
    data_type: TensorDataType,
    shape: TensorShape,

    pub fn init(name: []const u8, data_type: TensorDataType, shape: TensorShape) TensorSpec {
        return .{
            .name = name,
            .data_type = data_type,
            .shape = shape,
        };
    }

    pub fn bytesRequired(self: TensorSpec) u64 {
        return self.shape.elementCount() * self.data_type.byteSize();
    }
};

/// Model task type
pub const ModelTask = enum {
    image_classification,
    object_detection,
    image_segmentation,
    pose_estimation,
    face_detection,
    text_classification,
    text_generation,
    translation,
    speech_recognition,
    text_to_speech,
    embedding,
    recommendation,
    anomaly_detection,
    regression,
    custom,

    pub fn toString(self: ModelTask) []const u8 {
        return switch (self) {
            .image_classification => "Image Classification",
            .object_detection => "Object Detection",
            .image_segmentation => "Image Segmentation",
            .pose_estimation => "Pose Estimation",
            .face_detection => "Face Detection",
            .text_classification => "Text Classification",
            .text_generation => "Text Generation",
            .translation => "Translation",
            .speech_recognition => "Speech Recognition",
            .text_to_speech => "Text to Speech",
            .embedding => "Embedding",
            .recommendation => "Recommendation",
            .anomaly_detection => "Anomaly Detection",
            .regression => "Regression",
            .custom => "Custom",
        };
    }

    pub fn isVision(self: ModelTask) bool {
        return switch (self) {
            .image_classification, .object_detection, .image_segmentation, .pose_estimation, .face_detection => true,
            else => false,
        };
    }

    pub fn isNLP(self: ModelTask) bool {
        return switch (self) {
            .text_classification, .text_generation, .translation, .embedding => true,
            else => false,
        };
    }

    pub fn isAudio(self: ModelTask) bool {
        return self == .speech_recognition or self == .text_to_speech;
    }
};

/// Model metadata
pub const ModelMetadata = struct {
    name: []const u8,
    version: []const u8,
    author: ?[]const u8,
    description: ?[]const u8,
    task: ModelTask,
    framework: MLFramework,
    precision: ModelPrecision,
    size_bytes: u64,
    input_count: u32,
    output_count: u32,

    pub fn init(name: []const u8, task: ModelTask, framework: MLFramework) ModelMetadata {
        return .{
            .name = name,
            .version = "1.0",
            .author = null,
            .description = null,
            .task = task,
            .framework = framework,
            .precision = .float32,
            .size_bytes = 0,
            .input_count = 1,
            .output_count = 1,
        };
    }

    pub fn withVersion(self: ModelMetadata, version: []const u8) ModelMetadata {
        var meta = self;
        meta.version = version;
        return meta;
    }

    pub fn withAuthor(self: ModelMetadata, author: []const u8) ModelMetadata {
        var meta = self;
        meta.author = author;
        return meta;
    }

    pub fn withPrecision(self: ModelMetadata, precision: ModelPrecision) ModelMetadata {
        var meta = self;
        meta.precision = precision;
        return meta;
    }

    pub fn withSize(self: ModelMetadata, size_bytes: u64) ModelMetadata {
        var meta = self;
        meta.size_bytes = size_bytes;
        return meta;
    }

    pub fn sizeMB(self: ModelMetadata) f64 {
        return @as(f64, @floatFromInt(self.size_bytes)) / (1024.0 * 1024.0);
    }
};

/// Model loading state
pub const ModelState = enum {
    unloaded,
    loading,
    loaded,
    compiling,
    ready,
    error_state,

    pub fn toString(self: ModelState) []const u8 {
        return switch (self) {
            .unloaded => "Unloaded",
            .loading => "Loading",
            .loaded => "Loaded",
            .compiling => "Compiling",
            .ready => "Ready",
            .error_state => "Error",
        };
    }

    pub fn isReady(self: ModelState) bool {
        return self == .ready;
    }

    pub fn canInfer(self: ModelState) bool {
        return self == .ready;
    }
};

/// Inference configuration
pub const InferenceConfig = struct {
    compute_device: ComputeDevice,
    num_threads: u8,
    enable_profiling: bool,
    max_batch_size: u32,
    timeout_ms: u32,

    pub fn defaults() InferenceConfig {
        return .{
            .compute_device = .auto,
            .num_threads = 4,
            .enable_profiling = false,
            .max_batch_size = 1,
            .timeout_ms = 30000,
        };
    }

    pub fn cpuOnly() InferenceConfig {
        return .{
            .compute_device = .cpu,
            .num_threads = 4,
            .enable_profiling = false,
            .max_batch_size = 1,
            .timeout_ms = 30000,
        };
    }

    pub fn gpuAccelerated() InferenceConfig {
        return .{
            .compute_device = .gpu,
            .num_threads = 1,
            .enable_profiling = false,
            .max_batch_size = 8,
            .timeout_ms = 10000,
        };
    }

    pub fn withDevice(self: InferenceConfig, device: ComputeDevice) InferenceConfig {
        var config = self;
        config.compute_device = device;
        return config;
    }

    pub fn withThreads(self: InferenceConfig, threads: u8) InferenceConfig {
        var config = self;
        config.num_threads = threads;
        return config;
    }

    pub fn withProfiling(self: InferenceConfig, enabled: bool) InferenceConfig {
        var config = self;
        config.enable_profiling = enabled;
        return config;
    }

    pub fn withBatchSize(self: InferenceConfig, size: u32) InferenceConfig {
        var config = self;
        config.max_batch_size = size;
        return config;
    }
};

/// Classification result
pub const ClassificationResult = struct {
    label: []const u8,
    class_index: u32,
    confidence: f32,

    pub fn init(label: []const u8, class_index: u32, confidence: f32) ClassificationResult {
        return .{
            .label = label,
            .class_index = class_index,
            .confidence = confidence,
        };
    }

    pub fn confidencePercent(self: ClassificationResult) f32 {
        return self.confidence * 100.0;
    }

    pub fn isConfident(self: ClassificationResult, threshold: f32) bool {
        return self.confidence >= threshold;
    }
};

/// Bounding box for object detection
pub const BoundingBox = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn init(x: f32, y: f32, width: f32, height: f32) BoundingBox {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn center(self: BoundingBox) struct { x: f32, y: f32 } {
        return .{
            .x = self.x + self.width / 2.0,
            .y = self.y + self.height / 2.0,
        };
    }

    pub fn area(self: BoundingBox) f32 {
        return self.width * self.height;
    }

    pub fn contains(self: BoundingBox, px: f32, py: f32) bool {
        return px >= self.x and px <= self.x + self.width and
            py >= self.y and py <= self.y + self.height;
    }

    pub fn intersects(self: BoundingBox, other: BoundingBox) bool {
        return !(self.x + self.width < other.x or
            other.x + other.width < self.x or
            self.y + self.height < other.y or
            other.y + other.height < self.y);
    }

    pub fn iou(self: BoundingBox, other: BoundingBox) f32 {
        if (!self.intersects(other)) return 0;

        const x1 = @max(self.x, other.x);
        const y1 = @max(self.y, other.y);
        const x2 = @min(self.x + self.width, other.x + other.width);
        const y2 = @min(self.y + self.height, other.y + other.height);

        const intersection = (x2 - x1) * (y2 - y1);
        const union_area = self.area() + other.area() - intersection;

        if (union_area <= 0) return 0;
        return intersection / union_area;
    }
};

/// Object detection result
pub const DetectionResult = struct {
    label: []const u8,
    class_index: u32,
    confidence: f32,
    bounding_box: BoundingBox,

    pub fn init(label: []const u8, class_index: u32, confidence: f32, bbox: BoundingBox) DetectionResult {
        return .{
            .label = label,
            .class_index = class_index,
            .confidence = confidence,
            .bounding_box = bbox,
        };
    }

    pub fn isConfident(self: DetectionResult, threshold: f32) bool {
        return self.confidence >= threshold;
    }
};

/// Inference statistics
pub const InferenceStats = struct {
    inference_count: u64,
    total_time_ms: u64,
    min_time_ms: u64,
    max_time_ms: u64,
    last_inference_ms: u64,

    pub fn init() InferenceStats {
        return .{
            .inference_count = 0,
            .total_time_ms = 0,
            .min_time_ms = std.math.maxInt(u64),
            .max_time_ms = 0,
            .last_inference_ms = 0,
        };
    }

    pub fn record(self: *InferenceStats, time_ms: u64) void {
        self.inference_count += 1;
        self.total_time_ms += time_ms;
        self.last_inference_ms = time_ms;
        if (time_ms < self.min_time_ms) self.min_time_ms = time_ms;
        if (time_ms > self.max_time_ms) self.max_time_ms = time_ms;
    }

    pub fn averageTimeMs(self: InferenceStats) f64 {
        if (self.inference_count == 0) return 0;
        return @as(f64, @floatFromInt(self.total_time_ms)) / @as(f64, @floatFromInt(self.inference_count));
    }

    pub fn throughput(self: InferenceStats) f64 {
        const avg = self.averageTimeMs();
        if (avg <= 0) return 0;
        return 1000.0 / avg; // Inferences per second
    }

    pub fn reset(self: *InferenceStats) void {
        self.inference_count = 0;
        self.total_time_ms = 0;
        self.min_time_ms = std.math.maxInt(u64);
        self.max_time_ms = 0;
        self.last_inference_ms = 0;
    }
};

/// ML Model
pub const Model = struct {
    metadata: ModelMetadata,
    state: ModelState,
    config: InferenceConfig,
    stats: InferenceStats,
    loaded_at: u64,

    pub fn init(metadata: ModelMetadata) Model {
        return .{
            .metadata = metadata,
            .state = .unloaded,
            .config = InferenceConfig.defaults(),
            .stats = InferenceStats.init(),
            .loaded_at = 0,
        };
    }

    pub fn withConfig(self: Model, config: InferenceConfig) Model {
        var model = self;
        model.config = config;
        return model;
    }

    pub fn load(self: *Model) void {
        self.state = .loading;
    }

    pub fn onLoaded(self: *Model) void {
        self.state = .loaded;
    }

    pub fn compile(self: *Model) void {
        self.state = .compiling;
    }

    pub fn onReady(self: *Model) void {
        self.state = .ready;
        self.loaded_at = getCurrentTimestamp();
    }

    pub fn onError(self: *Model) void {
        self.state = .error_state;
    }

    pub fn unload(self: *Model) void {
        self.state = .unloaded;
        self.loaded_at = 0;
    }

    pub fn recordInference(self: *Model, time_ms: u64) void {
        self.stats.record(time_ms);
    }

    pub fn isReady(self: Model) bool {
        return self.state.isReady();
    }

    pub fn canInfer(self: Model) bool {
        return self.state.canInfer();
    }
};

/// Model registry for managing multiple models
pub const ModelRegistry = struct {
    model_count: u32,
    loaded_count: u32,
    total_size_bytes: u64,

    pub fn init() ModelRegistry {
        return .{
            .model_count = 0,
            .loaded_count = 0,
            .total_size_bytes = 0,
        };
    }

    pub fn registerModel(self: *ModelRegistry, size_bytes: u64) void {
        self.model_count += 1;
        self.total_size_bytes += size_bytes;
    }

    pub fn onModelLoaded(self: *ModelRegistry) void {
        self.loaded_count += 1;
    }

    pub fn onModelUnloaded(self: *ModelRegistry) void {
        if (self.loaded_count > 0) {
            self.loaded_count -= 1;
        }
    }

    pub fn totalSizeMB(self: ModelRegistry) f64 {
        return @as(f64, @floatFromInt(self.total_size_bytes)) / (1024.0 * 1024.0);
    }
};

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() u64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    const ms = @divTrunc(ts.nsec, 1_000_000);
    return @intCast(@as(i128, ts.sec) * 1000 + ms);
}

/// Get available ML framework for current platform
pub fn availableFramework() MLFramework {
    return .unknown; // Would use runtime detection
}

/// Check if ML is supported
pub fn isSupported() bool {
    return true; // Most platforms have some ML support
}

// ============================================================================
// Tests
// ============================================================================

test "MLFramework properties" {
    try std.testing.expectEqualStrings("Core ML", MLFramework.core_ml.toString());
    try std.testing.expectEqualStrings(".mlmodel", MLFramework.core_ml.fileExtension());
    try std.testing.expectEqualStrings(".tflite", MLFramework.tensorflow_lite.fileExtension());
    try std.testing.expect(MLFramework.core_ml.supportsGPU());
    try std.testing.expect(MLFramework.core_ml.supportsNPU());
    try std.testing.expect(!MLFramework.onnx_runtime.supportsNPU());
}

test "ComputeDevice properties" {
    try std.testing.expect(ComputeDevice.gpu.isHardwareAccelerated());
    try std.testing.expect(ComputeDevice.npu.isHardwareAccelerated());
    try std.testing.expect(!ComputeDevice.cpu.isHardwareAccelerated());
}

test "ModelPrecision properties" {
    try std.testing.expectEqual(@as(u8, 32), ModelPrecision.float32.bitsPerWeight());
    try std.testing.expectEqual(@as(u8, 8), ModelPrecision.int8.bitsPerWeight());
    try std.testing.expect(ModelPrecision.int8.isQuantized());
    try std.testing.expect(!ModelPrecision.float32.isQuantized());
}

test "TensorDataType properties" {
    try std.testing.expectEqual(@as(u8, 4), TensorDataType.float32.byteSize());
    try std.testing.expectEqual(@as(u8, 2), TensorDataType.float16.byteSize());
    try std.testing.expectEqual(@as(u8, 1), TensorDataType.uint8.byteSize());
    try std.testing.expect(TensorDataType.float32.isFloatingPoint());
    try std.testing.expect(TensorDataType.int32.isInteger());
}

test "TensorShape scalar" {
    const shape = TensorShape.scalar();
    try std.testing.expectEqual(@as(u8, 0), shape.rank);
    try std.testing.expectEqual(@as(u64, 1), shape.elementCount());
    try std.testing.expect(shape.isScalar());
}

test "TensorShape vector" {
    const shape = TensorShape.vector(128);
    try std.testing.expectEqual(@as(u8, 1), shape.rank);
    try std.testing.expectEqual(@as(u32, 128), shape.dimension(0));
    try std.testing.expectEqual(@as(u64, 128), shape.elementCount());
    try std.testing.expect(shape.isVector());
}

test "TensorShape matrix" {
    const shape = TensorShape.matrix(64, 128);
    try std.testing.expectEqual(@as(u8, 2), shape.rank);
    try std.testing.expectEqual(@as(u64, 64 * 128), shape.elementCount());
    try std.testing.expect(shape.isMatrix());
}

test "TensorShape image" {
    const shape = TensorShape.image(1, 224, 224, 3);
    try std.testing.expectEqual(@as(u8, 4), shape.rank);
    try std.testing.expectEqual(@as(u32, 1), shape.dimension(0));
    try std.testing.expectEqual(@as(u32, 224), shape.dimension(1));
    try std.testing.expectEqual(@as(u64, 1 * 224 * 224 * 3), shape.elementCount());
}

test "TensorSpec bytesRequired" {
    const shape = TensorShape.image(1, 224, 224, 3);
    const spec = TensorSpec.init("input", .float32, shape);
    const expected: u64 = 1 * 224 * 224 * 3 * 4;
    try std.testing.expectEqual(expected, spec.bytesRequired());
}

test "ModelTask properties" {
    try std.testing.expect(ModelTask.image_classification.isVision());
    try std.testing.expect(ModelTask.object_detection.isVision());
    try std.testing.expect(!ModelTask.text_classification.isVision());
    try std.testing.expect(ModelTask.text_generation.isNLP());
    try std.testing.expect(ModelTask.speech_recognition.isAudio());
}

test "ModelMetadata creation" {
    const meta = ModelMetadata.init("MobileNet", .image_classification, .core_ml)
        .withVersion("2.0")
        .withAuthor("Apple")
        .withPrecision(.float16)
        .withSize(10 * 1024 * 1024);

    try std.testing.expectEqualStrings("MobileNet", meta.name);
    try std.testing.expectEqualStrings("2.0", meta.version);
    try std.testing.expectEqual(ModelPrecision.float16, meta.precision);
    try std.testing.expect(meta.sizeMB() > 9.9);
}

test "ModelState properties" {
    try std.testing.expect(ModelState.ready.isReady());
    try std.testing.expect(ModelState.ready.canInfer());
    try std.testing.expect(!ModelState.loading.isReady());
    try std.testing.expect(!ModelState.error_state.canInfer());
}

test "InferenceConfig presets" {
    const defaults = InferenceConfig.defaults();
    try std.testing.expectEqual(ComputeDevice.auto, defaults.compute_device);
    try std.testing.expectEqual(@as(u8, 4), defaults.num_threads);

    const cpu = InferenceConfig.cpuOnly();
    try std.testing.expectEqual(ComputeDevice.cpu, cpu.compute_device);

    const gpu = InferenceConfig.gpuAccelerated();
    try std.testing.expectEqual(ComputeDevice.gpu, gpu.compute_device);
}

test "InferenceConfig builder" {
    const config = InferenceConfig.defaults()
        .withDevice(.npu)
        .withThreads(2)
        .withProfiling(true)
        .withBatchSize(4);

    try std.testing.expectEqual(ComputeDevice.npu, config.compute_device);
    try std.testing.expectEqual(@as(u8, 2), config.num_threads);
    try std.testing.expect(config.enable_profiling);
    try std.testing.expectEqual(@as(u32, 4), config.max_batch_size);
}

test "ClassificationResult" {
    const result = ClassificationResult.init("cat", 0, 0.95);
    try std.testing.expectEqualStrings("cat", result.label);
    try std.testing.expect(result.confidencePercent() > 94.9);
    try std.testing.expect(result.isConfident(0.9));
    try std.testing.expect(!result.isConfident(0.99));
}

test "BoundingBox center" {
    const bbox = BoundingBox.init(10, 20, 100, 50);
    const c = bbox.center();
    try std.testing.expect(c.x > 59.9 and c.x < 60.1);
    try std.testing.expect(c.y > 44.9 and c.y < 45.1);
}

test "BoundingBox area" {
    const bbox = BoundingBox.init(0, 0, 100, 50);
    try std.testing.expect(bbox.area() > 4999.9 and bbox.area() < 5000.1);
}

test "BoundingBox contains" {
    const bbox = BoundingBox.init(10, 10, 100, 100);
    try std.testing.expect(bbox.contains(50, 50));
    try std.testing.expect(bbox.contains(10, 10));
    try std.testing.expect(!bbox.contains(5, 5));
    try std.testing.expect(!bbox.contains(200, 200));
}

test "BoundingBox intersects" {
    const box1 = BoundingBox.init(0, 0, 100, 100);
    const box2 = BoundingBox.init(50, 50, 100, 100);
    const box3 = BoundingBox.init(200, 200, 50, 50);

    try std.testing.expect(box1.intersects(box2));
    try std.testing.expect(!box1.intersects(box3));
}

test "BoundingBox IoU" {
    const box1 = BoundingBox.init(0, 0, 100, 100);
    const box2 = BoundingBox.init(0, 0, 100, 100);
    try std.testing.expect(box1.iou(box2) > 0.99); // Same box

    const box3 = BoundingBox.init(50, 0, 100, 100);
    const iou = box1.iou(box3);
    try std.testing.expect(iou > 0.3 and iou < 0.4); // Partial overlap
}

test "DetectionResult" {
    const bbox = BoundingBox.init(10, 20, 100, 100);
    const result = DetectionResult.init("dog", 1, 0.87, bbox);

    try std.testing.expectEqualStrings("dog", result.label);
    try std.testing.expect(result.isConfident(0.8));
    try std.testing.expect(!result.isConfident(0.9));
}

test "InferenceStats recording" {
    var stats = InferenceStats.init();
    stats.record(10);
    stats.record(20);
    stats.record(15);

    try std.testing.expectEqual(@as(u64, 3), stats.inference_count);
    try std.testing.expectEqual(@as(u64, 45), stats.total_time_ms);
    try std.testing.expectEqual(@as(u64, 10), stats.min_time_ms);
    try std.testing.expectEqual(@as(u64, 20), stats.max_time_ms);
    try std.testing.expect(stats.averageTimeMs() > 14.9);
}

test "InferenceStats throughput" {
    var stats = InferenceStats.init();
    stats.record(100); // 100ms per inference

    const throughput = stats.throughput();
    try std.testing.expect(throughput > 9.9 and throughput < 10.1); // ~10 per second
}

test "Model lifecycle" {
    const meta = ModelMetadata.init("TestModel", .custom, .tensorflow_lite);
    var model = Model.init(meta);

    try std.testing.expectEqual(ModelState.unloaded, model.state);
    try std.testing.expect(!model.isReady());

    model.load();
    try std.testing.expectEqual(ModelState.loading, model.state);

    model.onLoaded();
    try std.testing.expectEqual(ModelState.loaded, model.state);

    model.compile();
    try std.testing.expectEqual(ModelState.compiling, model.state);

    model.onReady();
    try std.testing.expect(model.isReady());
    try std.testing.expect(model.canInfer());

    model.unload();
    try std.testing.expect(!model.isReady());
}

test "Model inference tracking" {
    const meta = ModelMetadata.init("TestModel", .custom, .core_ml);
    var model = Model.init(meta);
    model.onReady();

    model.recordInference(15);
    model.recordInference(20);

    try std.testing.expectEqual(@as(u64, 2), model.stats.inference_count);
}

test "ModelRegistry" {
    var registry = ModelRegistry.init();

    registry.registerModel(5 * 1024 * 1024);
    registry.registerModel(10 * 1024 * 1024);

    try std.testing.expectEqual(@as(u32, 2), registry.model_count);
    try std.testing.expect(registry.totalSizeMB() > 14.9);

    registry.onModelLoaded();
    registry.onModelLoaded();
    try std.testing.expectEqual(@as(u32, 2), registry.loaded_count);

    registry.onModelUnloaded();
    try std.testing.expectEqual(@as(u32, 1), registry.loaded_count);
}

test "isSupported" {
    try std.testing.expect(isSupported());
}
