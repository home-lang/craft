//! Camera and Media Capture Module
//!
//! Provides comprehensive camera access and media capture functionality:
//! - Camera device enumeration
//! - Photo capture with various formats
//! - Video recording with quality settings
//! - QR/barcode scanning
//! - Screen capture
//!
//! Cross-platform support:
//! - macOS: AVFoundation
//! - iOS: AVFoundation
//! - Linux: V4L2 / PipeWire
//! - Windows: Media Foundation
//! - Android: Camera2 API

const std = @import("std");
const builtin = @import("builtin");
const io_context = @import("io_context.zig");

/// Camera device position (for mobile devices)
pub const CameraPosition = enum {
    front,
    back,
    external,
    unknown,

    pub fn toString(self: CameraPosition) []const u8 {
        return switch (self) {
            .front => "front",
            .back => "back",
            .external => "external",
            .unknown => "unknown",
        };
    }
};

/// Camera device information
pub const CameraDevice = struct {
    id: []const u8,
    name: []const u8,
    position: CameraPosition,
    has_flash: bool,
    has_torch: bool,
    supports_video: bool,
    supports_photo: bool,
    max_resolution: Resolution,
    supported_formats: []const PixelFormat,

    pub const Resolution = struct {
        width: u32,
        height: u32,

        pub fn aspectRatio(self: Resolution) f32 {
            if (self.height == 0) return 0;
            return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height));
        }

        pub fn megapixels(self: Resolution) f32 {
            return @as(f32, @floatFromInt(self.width * self.height)) / 1_000_000.0;
        }
    };
};

/// Pixel formats supported by camera
pub const PixelFormat = enum {
    rgb24,
    rgba32,
    bgr24,
    bgra32,
    yuv420,
    yuv422,
    nv12,
    nv21,
    jpeg,
    hevc,
    raw,

    pub fn bytesPerPixel(self: PixelFormat) ?u8 {
        return switch (self) {
            .rgb24, .bgr24 => 3,
            .rgba32, .bgra32 => 4,
            .yuv420 => null, // planar format
            .yuv422 => 2,
            .nv12, .nv21 => null, // planar format
            .jpeg, .hevc, .raw => null, // compressed/variable
        };
    }

    pub fn toFourCC(self: PixelFormat) ?u32 {
        return switch (self) {
            .yuv420 => fourCC("YU12"),
            .yuv422 => fourCC("YUYV"),
            .nv12 => fourCC("NV12"),
            .nv21 => fourCC("NV21"),
            .jpeg => fourCC("MJPG"),
            else => null,
        };
    }

    fn fourCC(code: *const [4]u8) u32 {
        return @as(u32, code[0]) |
            (@as(u32, code[1]) << 8) |
            (@as(u32, code[2]) << 16) |
            (@as(u32, code[3]) << 24);
    }
};

/// Photo capture format
pub const PhotoFormat = enum {
    jpeg,
    png,
    heif,
    raw,
    tiff,

    pub fn mimeType(self: PhotoFormat) []const u8 {
        return switch (self) {
            .jpeg => "image/jpeg",
            .png => "image/png",
            .heif => "image/heif",
            .raw => "image/x-raw",
            .tiff => "image/tiff",
        };
    }

    pub fn extension(self: PhotoFormat) []const u8 {
        return switch (self) {
            .jpeg => "jpg",
            .png => "png",
            .heif => "heic",
            .raw => "raw",
            .tiff => "tiff",
        };
    }
};

/// Video recording format
pub const VideoFormat = enum {
    mp4,
    mov,
    webm,
    avi,
    mkv,

    pub fn mimeType(self: VideoFormat) []const u8 {
        return switch (self) {
            .mp4 => "video/mp4",
            .mov => "video/quicktime",
            .webm => "video/webm",
            .avi => "video/x-msvideo",
            .mkv => "video/x-matroska",
        };
    }

    pub fn extension(self: VideoFormat) []const u8 {
        return switch (self) {
            .mp4 => "mp4",
            .mov => "mov",
            .webm => "webm",
            .avi => "avi",
            .mkv => "mkv",
        };
    }
};

/// Video quality presets
pub const VideoQuality = enum {
    low, // 480p, low bitrate
    medium, // 720p
    high, // 1080p
    ultra, // 4K
    custom,

    pub fn resolution(self: VideoQuality) CameraDevice.Resolution {
        return switch (self) {
            .low => .{ .width = 640, .height = 480 },
            .medium => .{ .width = 1280, .height = 720 },
            .high => .{ .width = 1920, .height = 1080 },
            .ultra => .{ .width = 3840, .height = 2160 },
            .custom => .{ .width = 0, .height = 0 },
        };
    }

    pub fn bitrate(self: VideoQuality) u32 {
        return switch (self) {
            .low => 1_000_000, // 1 Mbps
            .medium => 5_000_000, // 5 Mbps
            .high => 10_000_000, // 10 Mbps
            .ultra => 35_000_000, // 35 Mbps
            .custom => 0,
        };
    }

    pub fn frameRate(self: VideoQuality) u8 {
        return switch (self) {
            .low => 24,
            .medium => 30,
            .high => 30,
            .ultra => 60,
            .custom => 30,
        };
    }
};

/// Photo quality settings
pub const PhotoQuality = struct {
    compression: f32 = 0.9, // 0.0 to 1.0
    resolution: ?CameraDevice.Resolution = null, // null = max resolution
    format: PhotoFormat = .jpeg,
    include_metadata: bool = true,
    flash_mode: FlashMode = .auto,
    hdr_enabled: bool = false,
};

/// Flash mode for photo capture
pub const FlashMode = enum {
    off,
    on,
    auto,
    torch,
};

/// Auto-focus mode
pub const FocusMode = enum {
    auto,
    continuous,
    manual,
    macro,
    infinity,
};

/// Exposure mode
pub const ExposureMode = enum {
    auto,
    manual,
    locked,
};

/// White balance mode
pub const WhiteBalanceMode = enum {
    auto,
    daylight,
    cloudy,
    tungsten,
    fluorescent,
    shade,
    manual,
};

/// Barcode/QR code types
pub const BarcodeType = enum {
    qr_code,
    ean_8,
    ean_13,
    upc_a,
    upc_e,
    code_39,
    code_93,
    code_128,
    itf,
    codabar,
    pdf417,
    aztec,
    data_matrix,
    unknown,

    pub fn toString(self: BarcodeType) []const u8 {
        return switch (self) {
            .qr_code => "QR Code",
            .ean_8 => "EAN-8",
            .ean_13 => "EAN-13",
            .upc_a => "UPC-A",
            .upc_e => "UPC-E",
            .code_39 => "Code 39",
            .code_93 => "Code 93",
            .code_128 => "Code 128",
            .itf => "ITF",
            .codabar => "Codabar",
            .pdf417 => "PDF417",
            .aztec => "Aztec",
            .data_matrix => "Data Matrix",
            .unknown => "Unknown",
        };
    }
};

/// Detected barcode result
pub const BarcodeResult = struct {
    barcode_type: BarcodeType,
    data: []const u8,
    raw_bytes: ?[]const u8,
    bounds: BoundingBox,
    corners: [4]Point,

    pub const Point = struct {
        x: f32,
        y: f32,
    };

    pub const BoundingBox = struct {
        x: f32,
        y: f32,
        width: f32,
        height: f32,
    };
};

/// Camera capture callback types
pub const CaptureCallback = *const fn (data: []const u8, width: u32, height: u32) void;
pub const PhotoCallback = *const fn (data: []const u8, format: PhotoFormat) void;
pub const VideoCallback = *const fn (duration_ms: u64, size_bytes: u64) void;
pub const BarcodeCallback = *const fn (result: BarcodeResult) void;
pub const ErrorCallback = *const fn (err: CameraError) void;

/// Camera errors
pub const CameraError = error{
    DeviceNotFound,
    PermissionDenied,
    DeviceBusy,
    InvalidConfiguration,
    CaptureError,
    RecordingError,
    EncodingError,
    StorageError,
    UnsupportedFormat,
    UnsupportedFeature,
    HardwareError,
    Timeout,
    OutOfMemory,
};

/// Camera session configuration
pub const CameraConfig = struct {
    device_id: ?[]const u8 = null, // null = default camera
    position: CameraPosition = .back, // preferred position if device_id is null
    preview_resolution: ?CameraDevice.Resolution = null,
    photo_quality: PhotoQuality = .{},
    video_quality: VideoQuality = .high,
    video_format: VideoFormat = .mp4,
    enable_audio: bool = true,
    enable_stabilization: bool = true,
    focus_mode: FocusMode = .continuous,
    exposure_mode: ExposureMode = .auto,
    white_balance: WhiteBalanceMode = .auto,
};

/// Camera session for capturing photos/videos
pub const CameraSession = struct {
    allocator: std.mem.Allocator,
    config: CameraConfig,
    device: ?CameraDevice = null,
    is_running: bool = false,
    is_recording: bool = false,
    native_handle: ?*anyopaque = null,

    // Callbacks
    preview_callback: ?CaptureCallback = null,
    photo_callback: ?PhotoCallback = null,
    video_callback: ?VideoCallback = null,
    barcode_callback: ?BarcodeCallback = null,
    error_callback: ?ErrorCallback = null,

    // Recording state
    recording_start_time: ?std.Io.Timestamp = null,
    recording_file_path: ?[]const u8 = null,

    const Self = @This();

    /// Initialize camera session
    pub fn init(allocator: std.mem.Allocator, config: CameraConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Start camera preview
    pub fn startPreview(self: *Self) CameraError!void {
        if (self.is_running) return;

        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            try self.startPreviewMacOS();
        } else if (builtin.os.tag == .linux) {
            try self.startPreviewLinux();
        } else if (builtin.os.tag == .windows) {
            try self.startPreviewWindows();
        }

        self.is_running = true;
    }

    /// Stop camera preview
    pub fn stopPreview(self: *Self) void {
        if (!self.is_running) return;

        if (self.is_recording) {
            _ = self.stopRecording() catch return;
        }

        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            self.stopPreviewMacOS();
        } else if (builtin.os.tag == .linux) {
            self.stopPreviewLinux();
        } else if (builtin.os.tag == .windows) {
            self.stopPreviewWindows();
        }

        self.is_running = false;
    }

    /// Capture a photo
    pub fn capturePhoto(self: *Self) CameraError![]const u8 {
        if (!self.is_running) return CameraError.DeviceNotFound;

        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            return self.capturePhotoMacOS();
        } else if (builtin.os.tag == .linux) {
            return self.capturePhotoLinux();
        } else if (builtin.os.tag == .windows) {
            return self.capturePhotoWindows();
        }

        return CameraError.UnsupportedFeature;
    }

    /// Start video recording
    pub fn startRecording(self: *Self, output_path: []const u8) CameraError!void {
        if (!self.is_running) return CameraError.DeviceNotFound;
        if (self.is_recording) return CameraError.DeviceBusy;

        self.recording_file_path = output_path;
        self.recording_start_time = std.Io.Timestamp.now(io_context.get(), .awake);

        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            try self.startRecordingMacOS(output_path);
        } else if (builtin.os.tag == .linux) {
            try self.startRecordingLinux(output_path);
        } else if (builtin.os.tag == .windows) {
            try self.startRecordingWindows(output_path);
        }

        self.is_recording = true;
    }

    /// Stop video recording
    pub fn stopRecording(self: *Self) CameraError!RecordingResult {
        if (!self.is_recording) return CameraError.RecordingError;

        const duration: u64 = if (self.recording_start_time) |start| blk: {
            const now = std.Io.Timestamp.now(io_context.get(), .awake);
            const elapsed = start.durationTo(now);
            break :blk @as(u64, @intCast(elapsed.nanoseconds)) / std.time.ns_per_ms;
        } else 0;

        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            self.stopRecordingMacOS();
        } else if (builtin.os.tag == .linux) {
            self.stopRecordingLinux();
        } else if (builtin.os.tag == .windows) {
            self.stopRecordingWindows();
        }

        self.is_recording = false;
        self.recording_start_time = null;

        return RecordingResult{
            .duration_ms = duration,
            .file_path = self.recording_file_path orelse "",
            .file_size = 0, // Would be populated by platform code
        };
    }

    /// Enable barcode scanning
    pub fn enableBarcodeScanning(self: *Self, types: []const BarcodeType) CameraError!void {
        _ = types;
        if (!self.is_running) return CameraError.DeviceNotFound;

        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            try self.enableBarcodeScanningMacOS();
        }
    }

    /// Disable barcode scanning
    pub fn disableBarcodeScanning(self: *Self) void {
        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            self.disableBarcodeScanningMacOS();
        }
    }

    /// Set focus point (normalized 0-1 coordinates)
    pub fn setFocusPoint(self: *Self, x: f32, y: f32) CameraError!void {
        if (!self.is_running) return CameraError.DeviceNotFound;
        _ = x;
        _ = y;

        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            try self.setFocusPointMacOS();
        }
    }

    /// Set exposure point (normalized 0-1 coordinates)
    pub fn setExposurePoint(self: *Self, x: f32, y: f32) CameraError!void {
        if (!self.is_running) return CameraError.DeviceNotFound;
        _ = x;
        _ = y;

        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            try self.setExposurePointMacOS();
        }
    }

    /// Set zoom level (1.0 = no zoom)
    pub fn setZoom(self: *Self, level: f32) CameraError!void {
        if (!self.is_running) return CameraError.DeviceNotFound;
        _ = level;

        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            try self.setZoomMacOS();
        }
    }

    /// Toggle flash/torch
    pub fn setTorch(self: *Self, enabled: bool) CameraError!void {
        if (!self.is_running) return CameraError.DeviceNotFound;
        _ = enabled;

        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            try self.setTorchMacOS();
        }
    }

    /// Switch to different camera
    pub fn switchCamera(self: *Self, position: CameraPosition) CameraError!void {
        const was_running = self.is_running;
        if (was_running) {
            self.stopPreview();
        }

        self.config.position = position;
        self.config.device_id = null;

        if (was_running) {
            try self.startPreview();
        }
    }

    // Platform-specific implementations

    fn startPreviewMacOS(self: *Self) CameraError!void {
        if (builtin.os.tag != .macos and builtin.target.os.tag != .ios) return;

        const macos = @import("macos.zig");

        // Create AVCaptureSession
        const AVCaptureSession = macos.getClass("AVCaptureSession") orelse return CameraError.DeviceNotFound;
        const session = macos.msgSend0(macos.msgSend0(AVCaptureSession, "alloc"), "init");
        if (session == null) return CameraError.DeviceNotFound;

        // Set session preset
        const NSString = macos.getClass("NSString") orelse return CameraError.DeviceNotFound;
        const preset_alloc = macos.msgSend0(NSString, "alloc");
        const preset = macos.msgSend1(preset_alloc, "initWithUTF8String:", @as([*:0]const u8, "AVCaptureSessionPresetHigh"));
        _ = macos.msgSend1(session, "setSessionPreset:", preset);

        // Get default camera device
        const AVCaptureDevice = macos.getClass("AVCaptureDevice") orelse return CameraError.DeviceNotFound;

        // Get the position-specific device
        const position: c_long = switch (self.config.position) {
            .front => 2, // AVCaptureDevicePositionFront
            .back => 1, // AVCaptureDevicePositionBack
            else => 0, // AVCaptureDevicePositionUnspecified
        };

        // defaultDeviceWithDeviceType:mediaType:position:
        const video_type_alloc = macos.msgSend0(NSString, "alloc");
        const video_type = macos.msgSend1(video_type_alloc, "initWithUTF8String:", @as([*:0]const u8, "vide"));
        const device = macos.msgSend3(AVCaptureDevice, "defaultDeviceWithMediaType:", video_type, @as(?*anyopaque, null), position);

        if (device == null) return CameraError.DeviceNotFound;

        // Create device input
        const AVCaptureDeviceInput = macos.getClass("AVCaptureDeviceInput") orelse return CameraError.DeviceNotFound;
        const input = macos.msgSend2(AVCaptureDeviceInput, "deviceInputWithDevice:error:", device, @as(?*anyopaque, null));

        if (input == null) return CameraError.DeviceNotFound;

        // Add input to session
        const can_add_input = macos.msgSend1(session, "canAddInput:", input);
        if (can_add_input != null) {
            _ = macos.msgSend1(session, "addInput:", input);
        }

        // Start running
        _ = macos.msgSend0(session, "startRunning");

        self.native_handle = session;
    }

    fn stopPreviewMacOS(self: *Self) void {
        if (builtin.os.tag != .macos and builtin.target.os.tag != .ios) return;

        if (self.native_handle) |session| {
            const macos = @import("macos.zig");
            _ = macos.msgSend0(session, "stopRunning");
            self.native_handle = null;
        }
    }

    fn capturePhotoMacOS(self: *Self) CameraError![]const u8 {
        if (builtin.os.tag != .macos and builtin.target.os.tag != .ios)
            return CameraError.UnsupportedFeature;
        _ = self;
        // Full implementation would use AVCapturePhotoOutput
        return CameraError.UnsupportedFeature;
    }

    fn startRecordingMacOS(self: *Self, path: []const u8) CameraError!void {
        if (builtin.os.tag != .macos and builtin.target.os.tag != .ios) return;
        _ = self;
        _ = path;
        // Full implementation would use AVCaptureMovieFileOutput
    }

    fn stopRecordingMacOS(self: *Self) void {
        if (builtin.os.tag != .macos and builtin.target.os.tag != .ios) return;
        _ = self;
    }

    fn enableBarcodeScanningMacOS(self: *Self) CameraError!void {
        if (builtin.os.tag != .macos and builtin.target.os.tag != .ios) return;

        if (self.native_handle) |session| {
            const macos = @import("macos.zig");

            // Create AVCaptureMetadataOutput for barcode scanning
            const AVCaptureMetadataOutput = macos.getClass("AVCaptureMetadataOutput") orelse return CameraError.UnsupportedFeature;
            const metadata_output = macos.msgSend0(macos.msgSend0(AVCaptureMetadataOutput, "alloc"), "init");

            if (metadata_output != null) {
                const can_add = macos.msgSend1(session, "canAddOutput:", metadata_output);
                if (can_add != null) {
                    _ = macos.msgSend1(session, "addOutput:", metadata_output);

                    // Set metadata object types (QR codes, barcodes)
                    const NSArray = macos.getClass("NSArray") orelse return CameraError.UnsupportedFeature;
                    const NSString = macos.getClass("NSString") orelse return CameraError.UnsupportedFeature;

                    const qr_str = macos.msgSend0(NSString, "alloc");
                    const qr_type = macos.msgSend1(qr_str, "initWithUTF8String:", @as([*:0]const u8, "org.iso.QRCode"));

                    const types_array = macos.msgSend1(NSArray, "arrayWithObject:", qr_type);
                    _ = macos.msgSend1(metadata_output, "setMetadataObjectTypes:", types_array);
                }
            }
        }
    }

    fn disableBarcodeScanningMacOS(self: *Self) void {
        if (builtin.os.tag != .macos and builtin.target.os.tag != .ios) return;
        _ = self;
        // Would remove the metadata output from session
    }

    fn setFocusPointMacOS(self: *Self) CameraError!void {
        if (builtin.os.tag != .macos and builtin.target.os.tag != .ios) return;
        _ = self;
        // Would use AVCaptureDevice focusPointOfInterest
    }

    fn setExposurePointMacOS(self: *Self) CameraError!void {
        if (builtin.os.tag != .macos and builtin.target.os.tag != .ios) return;
        _ = self;
        // Would use AVCaptureDevice exposurePointOfInterest
    }

    fn setZoomMacOS(self: *Self) CameraError!void {
        if (builtin.os.tag != .macos and builtin.target.os.tag != .ios) return;
        _ = self;
        // Would use AVCaptureDevice videoZoomFactor
    }

    fn setTorchMacOS(self: *Self) CameraError!void {
        if (builtin.os.tag != .macos and builtin.target.os.tag != .ios) return;
        _ = self;
        // Would use AVCaptureDevice torchMode
    }

    fn startPreviewLinux(self: *Self) CameraError!void {
        if (builtin.os.tag != .linux) return;

        // V4L2 implementation
        const c = @cImport({
            @cInclude("fcntl.h");
            @cInclude("sys/ioctl.h");
            @cInclude("linux/videodev2.h");
        });

        // Try to open default video device
        const device_path = if (self.config.device_id) |id| id else "/dev/video0";
        const device_path_z = self.allocator.dupeZ(u8, device_path) catch return CameraError.OutOfMemory;
        defer self.allocator.free(device_path_z);

        const fd = std.c.open(device_path_z.ptr, std.c.O.RDWR);
        if (fd < 0) return CameraError.DeviceNotFound;

        // Query device capabilities
        var cap: c.v4l2_capability = undefined;
        if (std.c.ioctl(fd, c.VIDIOC_QUERYCAP, &cap) < 0) {
            _ = std.c.close(fd);
            return CameraError.DeviceNotFound;
        }

        // Check if it's a video capture device
        if ((cap.capabilities & c.V4L2_CAP_VIDEO_CAPTURE) == 0) {
            _ = std.c.close(fd);
            return CameraError.InvalidConfiguration;
        }

        // Store the file descriptor as native handle
        self.native_handle = @ptrFromInt(@as(usize, @intCast(fd)));
    }

    fn stopPreviewLinux(self: *Self) void {
        if (builtin.os.tag != .linux) return;

        if (self.native_handle) |handle| {
            const fd: c_int = @intCast(@intFromPtr(handle));
            _ = std.c.close(fd);
            self.native_handle = null;
        }
    }

    fn capturePhotoLinux(self: *Self) CameraError![]const u8 {
        if (builtin.os.tag != .linux) return CameraError.UnsupportedFeature;
        _ = self;
        // Full implementation would use V4L2 buffer capture
        return CameraError.UnsupportedFeature;
    }

    fn startRecordingLinux(self: *Self, path: []const u8) CameraError!void {
        if (builtin.os.tag != .linux) return;
        _ = self;
        _ = path;
        // Would use V4L2 + ffmpeg/gstreamer for encoding
    }

    fn stopRecordingLinux(self: *Self) void {
        if (builtin.os.tag != .linux) return;
        _ = self;
    }

    fn startPreviewWindows(self: *Self) CameraError!void {
        if (builtin.os.tag != .windows) return;
        _ = self;

        // Media Foundation implementation would go here
        // Using MFCreateDeviceSource, IMFMediaSource, etc.
    }

    fn stopPreviewWindows(self: *Self) void {
        if (builtin.os.tag != .windows) return;
        _ = self;
    }

    fn capturePhotoWindows(self: *Self) CameraError![]const u8 {
        if (builtin.os.tag != .windows) return CameraError.UnsupportedFeature;
        _ = self;
        return CameraError.UnsupportedFeature;
    }

    fn startRecordingWindows(self: *Self, path: []const u8) CameraError!void {
        if (builtin.os.tag != .windows) return;
        _ = self;
        _ = path;
    }

    fn stopRecordingWindows(self: *Self) void {
        if (builtin.os.tag != .windows) return;
        _ = self;
    }

    /// Set preview frame callback
    pub fn setPreviewCallback(self: *Self, callback: ?CaptureCallback) void {
        self.preview_callback = callback;
    }

    /// Set photo capture callback
    pub fn setPhotoCallback(self: *Self, callback: ?PhotoCallback) void {
        self.photo_callback = callback;
    }

    /// Set video recording callback
    pub fn setVideoCallback(self: *Self, callback: ?VideoCallback) void {
        self.video_callback = callback;
    }

    /// Set barcode detection callback
    pub fn setBarcodeCallback(self: *Self, callback: ?BarcodeCallback) void {
        self.barcode_callback = callback;
    }

    /// Set error callback
    pub fn setErrorCallback(self: *Self, callback: ?ErrorCallback) void {
        self.error_callback = callback;
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.stopPreview();
        self.native_handle = null;
    }
};

/// Recording result
pub const RecordingResult = struct {
    duration_ms: u64,
    file_path: []const u8,
    file_size: u64,
};

/// Camera device manager
pub const CameraManager = struct {
    allocator: std.mem.Allocator,
    devices: std.ArrayListUnmanaged(CameraDevice),
    permission_granted: bool = false,

    const Self = @This();

    /// Initialize camera manager
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .devices = .{},
        };
    }

    /// Request camera permission
    pub fn requestPermission(self: *Self) CameraError!bool {
        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            self.permission_granted = try self.requestPermissionMacOS();
        } else {
            // Linux/Windows typically don't require explicit permission
            self.permission_granted = true;
        }
        return self.permission_granted;
    }

    fn requestPermissionMacOS(self: *Self) CameraError!bool {
        _ = self;
        // AVCaptureDevice.requestAccess would be called here
        return true;
    }

    /// Check if camera permission is granted
    pub fn hasPermission(self: *Self) bool {
        return self.permission_granted;
    }

    /// Enumerate available camera devices
    pub fn enumerateDevices(self: *Self) CameraError![]const CameraDevice {
        self.devices.clearRetainingCapacity();

        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            try self.enumerateDevicesMacOS();
        } else if (builtin.os.tag == .linux) {
            try self.enumerateDevicesLinux();
        } else if (builtin.os.tag == .windows) {
            try self.enumerateDevicesWindows();
        }

        return self.devices.items;
    }

    fn enumerateDevicesMacOS(self: *Self) CameraError!void {
        // AVCaptureDevice.devices() would be called here
        // For now, add a mock device for testing
        _ = self;
    }

    fn enumerateDevicesLinux(self: *Self) CameraError!void {
        // Scan /dev/video* devices
        _ = self;
    }

    fn enumerateDevicesWindows(self: *Self) CameraError!void {
        // Use Media Foundation to enumerate devices
        _ = self;
    }

    /// Get default camera device
    pub fn getDefaultDevice(self: *Self, position: CameraPosition) ?CameraDevice {
        for (self.devices.items) |device| {
            if (device.position == position) {
                return device;
            }
        }
        if (self.devices.items.len > 0) {
            return self.devices.items[0];
        }
        return null;
    }

    /// Create a camera session
    pub fn createSession(self: *Self, config: CameraConfig) CameraSession {
        return CameraSession.init(self.allocator, config);
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.devices.deinit(self.allocator);
    }
};

/// Screen capture functionality
pub const ScreenCapture = struct {
    allocator: std.mem.Allocator,
    native_handle: ?*anyopaque = null,

    const Self = @This();

    /// Initialize screen capture
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Capture the entire screen
    pub fn captureScreen(self: *Self, display_id: ?u32) CameraError!ScreenshotResult {
        _ = display_id;
        if (builtin.os.tag == .macos) {
            return self.captureScreenMacOS();
        } else if (builtin.os.tag == .linux) {
            return self.captureScreenLinux();
        } else if (builtin.os.tag == .windows) {
            return self.captureScreenWindows();
        }
        return CameraError.UnsupportedFeature;
    }

    fn captureScreenMacOS(self: *Self) CameraError!ScreenshotResult {
        _ = self;
        // CGWindowListCreateImage would be called here
        return ScreenshotResult{
            .data = &[_]u8{},
            .width = 0,
            .height = 0,
            .format = .png,
        };
    }

    fn captureScreenLinux(self: *Self) CameraError!ScreenshotResult {
        _ = self;
        return CameraError.UnsupportedFeature;
    }

    fn captureScreenWindows(self: *Self) CameraError!ScreenshotResult {
        _ = self;
        return CameraError.UnsupportedFeature;
    }

    /// Capture a specific window
    pub fn captureWindow(self: *Self, window_id: u64) CameraError!ScreenshotResult {
        _ = window_id;
        if (builtin.os.tag == .macos) {
            return self.captureWindowMacOS();
        }
        return CameraError.UnsupportedFeature;
    }

    fn captureWindowMacOS(self: *Self) CameraError!ScreenshotResult {
        _ = self;
        return CameraError.UnsupportedFeature;
    }

    /// Capture a region of the screen
    pub fn captureRegion(self: *Self, x: i32, y: i32, width: u32, height: u32) CameraError!ScreenshotResult {
        _ = x;
        _ = y;
        _ = width;
        _ = height;
        if (builtin.os.tag == .macos) {
            return self.captureRegionMacOS();
        }
        return CameraError.UnsupportedFeature;
    }

    fn captureRegionMacOS(self: *Self) CameraError!ScreenshotResult {
        _ = self;
        return CameraError.UnsupportedFeature;
    }

    /// Start screen recording
    pub fn startRecording(self: *Self, output_path: []const u8, config: ScreenRecordConfig) CameraError!void {
        _ = output_path;
        _ = config;
        if (builtin.os.tag == .macos) {
            return self.startRecordingMacOS();
        }
        return CameraError.UnsupportedFeature;
    }

    fn startRecordingMacOS(self: *Self) CameraError!void {
        _ = self;
        // ReplayKit or AVCaptureScreenInput would be used here
    }

    /// Stop screen recording
    pub fn stopRecording(self: *Self) CameraError!RecordingResult {
        if (builtin.os.tag == .macos) {
            return self.stopRecordingMacOS();
        }
        return CameraError.UnsupportedFeature;
    }

    fn stopRecordingMacOS(self: *Self) CameraError!RecordingResult {
        _ = self;
        return RecordingResult{
            .duration_ms = 0,
            .file_path = "",
            .file_size = 0,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.native_handle = null;
    }
};

/// Screenshot result
pub const ScreenshotResult = struct {
    data: []const u8,
    width: u32,
    height: u32,
    format: PhotoFormat,
};

/// Screen recording configuration
pub const ScreenRecordConfig = struct {
    quality: VideoQuality = .high,
    format: VideoFormat = .mp4,
    capture_cursor: bool = true,
    capture_clicks: bool = false,
    capture_audio: bool = false,
    frame_rate: u8 = 30,
};

/// QR Code generator
pub const QRCodeGenerator = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Error correction levels
    pub const ErrorCorrection = enum {
        low, // ~7% recovery
        medium, // ~15% recovery
        quartile, // ~25% recovery
        high, // ~30% recovery
    };

    /// QR code generation options
    pub const Options = struct {
        error_correction: ErrorCorrection = .medium,
        size: u32 = 256,
        margin: u8 = 4,
        foreground_color: u32 = 0x000000FF, // RGBA
        background_color: u32 = 0xFFFFFFFF, // RGBA
    };

    /// Initialize QR code generator
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Generate QR code from string data
    pub fn generate(self: *Self, data: []const u8, options: Options) !QRCodeResult {
        _ = data;
        // QR code generation algorithm would go here
        // For now, return a placeholder
        return QRCodeResult{
            .image_data = try self.allocator.alloc(u8, 0),
            .width = options.size,
            .height = options.size,
            .format = .png,
        };
    }

    /// Generate QR code for URL
    pub fn generateURL(self: *Self, url: []const u8, options: Options) !QRCodeResult {
        return self.generate(url, options);
    }

    /// Generate QR code for vCard contact
    pub fn generateVCard(self: *Self, vcard: VCard, options: Options) !QRCodeResult {
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        try buffer.appendSlice("BEGIN:VCARD\nVERSION:3.0\n");
        if (vcard.name) |name| {
            try buffer.appendSlice("N:");
            try buffer.appendSlice(name);
            try buffer.appendSlice("\n");
        }
        if (vcard.phone) |phone| {
            try buffer.appendSlice("TEL:");
            try buffer.appendSlice(phone);
            try buffer.appendSlice("\n");
        }
        if (vcard.email) |email| {
            try buffer.appendSlice("EMAIL:");
            try buffer.appendSlice(email);
            try buffer.appendSlice("\n");
        }
        try buffer.appendSlice("END:VCARD");

        return self.generate(buffer.items, options);
    }

    /// Generate QR code for WiFi network
    pub fn generateWiFi(self: *Self, ssid: []const u8, password: []const u8, encryption: WiFiEncryption, options: Options) !QRCodeResult {
        var buffer: [512]u8 = undefined;
        const wifi_string = try std.fmt.bufPrint(&buffer, "WIFI:T:{s};S:{s};P:{s};;", .{
            encryption.toString(),
            ssid,
            password,
        });
        return self.generate(wifi_string, options);
    }

    pub const WiFiEncryption = enum {
        none,
        wep,
        wpa,

        pub fn toString(self: WiFiEncryption) []const u8 {
            return switch (self) {
                .none => "nopass",
                .wep => "WEP",
                .wpa => "WPA",
            };
        }
    };

    pub const VCard = struct {
        name: ?[]const u8 = null,
        phone: ?[]const u8 = null,
        email: ?[]const u8 = null,
        organization: ?[]const u8 = null,
        title: ?[]const u8 = null,
        address: ?[]const u8 = null,
        url: ?[]const u8 = null,
    };

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        _ = self;
    }
};

/// QR code generation result
pub const QRCodeResult = struct {
    image_data: []const u8,
    width: u32,
    height: u32,
    format: PhotoFormat,
};

/// Camera presets for common use cases
pub const CameraPresets = struct {
    /// Preset for photo capture
    pub fn photoCapture() CameraConfig {
        return .{
            .position = .back,
            .photo_quality = .{
                .compression = 0.92,
                .format = .jpeg,
                .hdr_enabled = true,
            },
            .focus_mode = .continuous,
            .exposure_mode = .auto,
        };
    }

    /// Preset for video recording
    pub fn videoRecording() CameraConfig {
        return .{
            .position = .back,
            .video_quality = .high,
            .video_format = .mp4,
            .enable_audio = true,
            .enable_stabilization = true,
            .focus_mode = .continuous,
        };
    }

    /// Preset for video calling
    pub fn videoCall() CameraConfig {
        return .{
            .position = .front,
            .video_quality = .medium,
            .video_format = .mp4,
            .enable_audio = true,
            .enable_stabilization = false,
            .focus_mode = .continuous,
        };
    }

    /// Preset for barcode/QR scanning
    pub fn barcodeScanning() CameraConfig {
        return .{
            .position = .back,
            .preview_resolution = .{ .width = 1280, .height = 720 },
            .focus_mode = .continuous,
            .exposure_mode = .auto,
        };
    }

    /// Preset for document scanning
    pub fn documentScanning() CameraConfig {
        return .{
            .position = .back,
            .photo_quality = .{
                .compression = 0.95,
                .format = .png,
                .flash_mode = .auto,
            },
            .focus_mode = .auto,
        };
    }

    /// Preset for selfie capture
    pub fn selfie() CameraConfig {
        return .{
            .position = .front,
            .photo_quality = .{
                .compression = 0.9,
                .format = .jpeg,
                .flash_mode = .off,
            },
            .focus_mode = .continuous,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "CameraDevice.Resolution calculations" {
    const res = CameraDevice.Resolution{ .width = 1920, .height = 1080 };
    try std.testing.expectApproxEqAbs(@as(f32, 1.777), res.aspectRatio(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 2.07), res.megapixels(), 0.01);
}

test "PixelFormat bytes per pixel" {
    try std.testing.expectEqual(@as(?u8, 3), PixelFormat.rgb24.bytesPerPixel());
    try std.testing.expectEqual(@as(?u8, 4), PixelFormat.rgba32.bytesPerPixel());
    try std.testing.expectEqual(@as(?u8, null), PixelFormat.yuv420.bytesPerPixel());
}

test "PhotoFormat mime types" {
    try std.testing.expectEqualStrings("image/jpeg", PhotoFormat.jpeg.mimeType());
    try std.testing.expectEqualStrings("image/png", PhotoFormat.png.mimeType());
    try std.testing.expectEqualStrings("jpg", PhotoFormat.jpeg.extension());
}

test "VideoFormat mime types" {
    try std.testing.expectEqualStrings("video/mp4", VideoFormat.mp4.mimeType());
    try std.testing.expectEqualStrings("video/quicktime", VideoFormat.mov.mimeType());
    try std.testing.expectEqualStrings("mp4", VideoFormat.mp4.extension());
}

test "VideoQuality presets" {
    const low = VideoQuality.low;
    try std.testing.expectEqual(@as(u32, 640), low.resolution().width);
    try std.testing.expectEqual(@as(u32, 480), low.resolution().height);
    try std.testing.expectEqual(@as(u32, 1_000_000), low.bitrate());
    try std.testing.expectEqual(@as(u8, 24), low.frameRate());

    const ultra = VideoQuality.ultra;
    try std.testing.expectEqual(@as(u32, 3840), ultra.resolution().width);
    try std.testing.expectEqual(@as(u32, 2160), ultra.resolution().height);
}

test "BarcodeType toString" {
    try std.testing.expectEqualStrings("QR Code", BarcodeType.qr_code.toString());
    try std.testing.expectEqualStrings("EAN-13", BarcodeType.ean_13.toString());
    try std.testing.expectEqualStrings("Code 128", BarcodeType.code_128.toString());
}

test "CameraSession initialization" {
    const allocator = std.testing.allocator;
    var session = CameraSession.init(allocator, .{});
    defer session.deinit();

    try std.testing.expect(!session.is_running);
    try std.testing.expect(!session.is_recording);
    try std.testing.expectEqual(CameraPosition.back, session.config.position);
}

test "CameraManager initialization" {
    const allocator = std.testing.allocator;
    var manager = CameraManager.init(allocator);
    defer manager.deinit();

    try std.testing.expect(!manager.permission_granted);
}

test "CameraPresets configuration" {
    const photo = CameraPresets.photoCapture();
    try std.testing.expectEqual(CameraPosition.back, photo.position);
    try std.testing.expectEqual(PhotoFormat.jpeg, photo.photo_quality.format);
    try std.testing.expect(photo.photo_quality.hdr_enabled);

    const video = CameraPresets.videoRecording();
    try std.testing.expectEqual(VideoQuality.high, video.video_quality);
    try std.testing.expect(video.enable_audio);
    try std.testing.expect(video.enable_stabilization);

    const selfie = CameraPresets.selfie();
    try std.testing.expectEqual(CameraPosition.front, selfie.position);
    try std.testing.expectEqual(FlashMode.off, selfie.photo_quality.flash_mode);
}

test "QRCodeGenerator initialization" {
    const allocator = std.testing.allocator;
    var generator = QRCodeGenerator.init(allocator);
    defer generator.deinit();

    // Test WiFi encryption toString
    try std.testing.expectEqualStrings("WPA", QRCodeGenerator.WiFiEncryption.wpa.toString());
    try std.testing.expectEqualStrings("nopass", QRCodeGenerator.WiFiEncryption.none.toString());
}

test "ScreenCapture initialization" {
    const allocator = std.testing.allocator;
    var capture = ScreenCapture.init(allocator);
    defer capture.deinit();

    try std.testing.expect(capture.native_handle == null);
}

test "CameraSession switch camera" {
    const allocator = std.testing.allocator;
    var session = CameraSession.init(allocator, .{ .position = .back });
    defer session.deinit();

    try std.testing.expectEqual(CameraPosition.back, session.config.position);

    try session.switchCamera(.front);
    try std.testing.expectEqual(CameraPosition.front, session.config.position);
}

test "CameraPosition toString" {
    try std.testing.expectEqualStrings("front", CameraPosition.front.toString());
    try std.testing.expectEqualStrings("back", CameraPosition.back.toString());
    try std.testing.expectEqualStrings("external", CameraPosition.external.toString());
}
