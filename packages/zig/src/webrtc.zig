//! WebRTC support for Craft
//! Provides cross-platform abstractions for real-time communication,
//! video/audio calling, peer-to-peer connections, and data channels.

const std = @import("std");

/// WebRTC signaling state
pub const SignalingState = enum {
    stable,
    have_local_offer,
    have_remote_offer,
    have_local_pranswer,
    have_remote_pranswer,
    closed,

    pub fn toString(self: SignalingState) []const u8 {
        return switch (self) {
            .stable => "stable",
            .have_local_offer => "have-local-offer",
            .have_remote_offer => "have-remote-offer",
            .have_local_pranswer => "have-local-pranswer",
            .have_remote_pranswer => "have-remote-pranswer",
            .closed => "closed",
        };
    }

    pub fn canCreateOffer(self: SignalingState) bool {
        return self == .stable or self == .have_local_offer;
    }

    pub fn canCreateAnswer(self: SignalingState) bool {
        return self == .have_remote_offer or self == .have_local_pranswer;
    }
};

/// ICE gathering state
pub const IceGatheringState = enum {
    new_state,
    gathering,
    complete,

    pub fn toString(self: IceGatheringState) []const u8 {
        return switch (self) {
            .new_state => "new",
            .gathering => "gathering",
            .complete => "complete",
        };
    }

    pub fn isGathering(self: IceGatheringState) bool {
        return self == .gathering;
    }
};

/// ICE connection state
pub const IceConnectionState = enum {
    new_state,
    checking,
    connected,
    completed,
    failed,
    disconnected,
    closed,

    pub fn toString(self: IceConnectionState) []const u8 {
        return switch (self) {
            .new_state => "new",
            .checking => "checking",
            .connected => "connected",
            .completed => "completed",
            .failed => "failed",
            .disconnected => "disconnected",
            .closed => "closed",
        };
    }

    pub fn isConnected(self: IceConnectionState) bool {
        return self == .connected or self == .completed;
    }

    pub fn isFailed(self: IceConnectionState) bool {
        return self == .failed;
    }

    pub fn isActive(self: IceConnectionState) bool {
        return self != .closed and self != .failed;
    }
};

/// Peer connection state
pub const PeerConnectionState = enum {
    new_state,
    connecting,
    connected,
    disconnected,
    failed,
    closed,

    pub fn toString(self: PeerConnectionState) []const u8 {
        return switch (self) {
            .new_state => "new",
            .connecting => "connecting",
            .connected => "connected",
            .disconnected => "disconnected",
            .failed => "failed",
            .closed => "closed",
        };
    }

    pub fn isConnected(self: PeerConnectionState) bool {
        return self == .connected;
    }

    pub fn canReconnect(self: PeerConnectionState) bool {
        return self == .disconnected;
    }
};

/// ICE transport policy
pub const IceTransportPolicy = enum {
    all,
    relay,

    pub fn toString(self: IceTransportPolicy) []const u8 {
        return switch (self) {
            .all => "all",
            .relay => "relay",
        };
    }
};

/// Bundle policy
pub const BundlePolicy = enum {
    balanced,
    max_compat,
    max_bundle,

    pub fn toString(self: BundlePolicy) []const u8 {
        return switch (self) {
            .balanced => "balanced",
            .max_compat => "max-compat",
            .max_bundle => "max-bundle",
        };
    }
};

/// RTCP mux policy
pub const RtcpMuxPolicy = enum {
    negotiate,
    require,

    pub fn toString(self: RtcpMuxPolicy) []const u8 {
        return switch (self) {
            .negotiate => "negotiate",
            .require => "require",
        };
    }
};

/// ICE server configuration
pub const IceServer = struct {
    urls: []const u8,
    username: ?[]const u8,
    credential: ?[]const u8,

    pub fn stun(url: []const u8) IceServer {
        return .{
            .urls = url,
            .username = null,
            .credential = null,
        };
    }

    pub fn turn(url: []const u8, username: []const u8, credential: []const u8) IceServer {
        return .{
            .urls = url,
            .username = username,
            .credential = credential,
        };
    }

    pub fn isStun(self: IceServer) bool {
        return std.mem.startsWith(u8, self.urls, "stun:");
    }

    pub fn isTurn(self: IceServer) bool {
        return std.mem.startsWith(u8, self.urls, "turn:") or
            std.mem.startsWith(u8, self.urls, "turns:");
    }

    pub fn requiresCredentials(self: IceServer) bool {
        return self.isTurn();
    }
};

/// Peer connection configuration
pub const PeerConnectionConfig = struct {
    ice_transport_policy: IceTransportPolicy,
    bundle_policy: BundlePolicy,
    rtcp_mux_policy: RtcpMuxPolicy,
    ice_candidate_pool_size: u8,
    server_count: u32,

    pub fn defaults() PeerConnectionConfig {
        return .{
            .ice_transport_policy = .all,
            .bundle_policy = .balanced,
            .rtcp_mux_policy = .require,
            .ice_candidate_pool_size = 0,
            .server_count = 0,
        };
    }

    pub fn withIceTransportPolicy(self: PeerConnectionConfig, policy: IceTransportPolicy) PeerConnectionConfig {
        var config = self;
        config.ice_transport_policy = policy;
        return config;
    }

    pub fn withBundlePolicy(self: PeerConnectionConfig, policy: BundlePolicy) PeerConnectionConfig {
        var config = self;
        config.bundle_policy = policy;
        return config;
    }

    pub fn withCandidatePoolSize(self: PeerConnectionConfig, size: u8) PeerConnectionConfig {
        var config = self;
        config.ice_candidate_pool_size = size;
        return config;
    }
};

/// SDP type
pub const SdpType = enum {
    offer,
    pranswer,
    answer,
    rollback,

    pub fn toString(self: SdpType) []const u8 {
        return switch (self) {
            .offer => "offer",
            .pranswer => "pranswer",
            .answer => "answer",
            .rollback => "rollback",
        };
    }
};

/// Session description
pub const SessionDescription = struct {
    sdp_type: SdpType,
    sdp: []const u8,

    pub fn init(sdp_type: SdpType, sdp: []const u8) SessionDescription {
        return .{
            .sdp_type = sdp_type,
            .sdp = sdp,
        };
    }

    pub fn isOffer(self: SessionDescription) bool {
        return self.sdp_type == .offer;
    }

    pub fn isAnswer(self: SessionDescription) bool {
        return self.sdp_type == .answer;
    }
};

/// ICE candidate
pub const IceCandidate = struct {
    candidate: []const u8,
    sdp_mid: ?[]const u8,
    sdp_mline_index: ?u16,
    username_fragment: ?[]const u8,

    pub fn init(candidate: []const u8) IceCandidate {
        return .{
            .candidate = candidate,
            .sdp_mid = null,
            .sdp_mline_index = null,
            .username_fragment = null,
        };
    }

    pub fn withSdpMid(self: IceCandidate, mid: []const u8) IceCandidate {
        var c = self;
        c.sdp_mid = mid;
        return c;
    }

    pub fn withMlineIndex(self: IceCandidate, index: u16) IceCandidate {
        var c = self;
        c.sdp_mline_index = index;
        return c;
    }

    pub fn isEmpty(self: IceCandidate) bool {
        return self.candidate.len == 0;
    }
};

/// Media stream track kind
pub const TrackKind = enum {
    audio,
    video,

    pub fn toString(self: TrackKind) []const u8 {
        return switch (self) {
            .audio => "audio",
            .video => "video",
        };
    }
};

/// Track state
pub const TrackState = enum {
    live,
    ended,

    pub fn toString(self: TrackState) []const u8 {
        return switch (self) {
            .live => "live",
            .ended => "ended",
        };
    }

    pub fn isLive(self: TrackState) bool {
        return self == .live;
    }
};

/// Media stream track
pub const MediaStreamTrack = struct {
    track_id: []const u8,
    kind: TrackKind,
    label: []const u8,
    state: TrackState,
    enabled: bool,
    muted: bool,

    pub fn init(track_id: []const u8, kind: TrackKind) MediaStreamTrack {
        return .{
            .track_id = track_id,
            .kind = kind,
            .label = "",
            .state = .live,
            .enabled = true,
            .muted = false,
        };
    }

    pub fn withLabel(self: MediaStreamTrack, label: []const u8) MediaStreamTrack {
        var track = self;
        track.label = label;
        return track;
    }

    pub fn setEnabled(self: *MediaStreamTrack, enabled: bool) void {
        self.enabled = enabled;
    }

    pub fn stop(self: *MediaStreamTrack) void {
        self.state = .ended;
    }

    pub fn isAudio(self: MediaStreamTrack) bool {
        return self.kind == .audio;
    }

    pub fn isVideo(self: MediaStreamTrack) bool {
        return self.kind == .video;
    }

    pub fn isLive(self: MediaStreamTrack) bool {
        return self.state.isLive();
    }
};

/// Media stream
pub const MediaStream = struct {
    stream_id: []const u8,
    active: bool,
    audio_track_count: u32,
    video_track_count: u32,

    pub fn init(stream_id: []const u8) MediaStream {
        return .{
            .stream_id = stream_id,
            .active = true,
            .audio_track_count = 0,
            .video_track_count = 0,
        };
    }

    pub fn addAudioTrack(self: *MediaStream) void {
        self.audio_track_count += 1;
    }

    pub fn addVideoTrack(self: *MediaStream) void {
        self.video_track_count += 1;
    }

    pub fn removeAudioTrack(self: *MediaStream) void {
        if (self.audio_track_count > 0) {
            self.audio_track_count -= 1;
        }
    }

    pub fn removeVideoTrack(self: *MediaStream) void {
        if (self.video_track_count > 0) {
            self.video_track_count -= 1;
        }
    }

    pub fn trackCount(self: MediaStream) u32 {
        return self.audio_track_count + self.video_track_count;
    }

    pub fn hasAudio(self: MediaStream) bool {
        return self.audio_track_count > 0;
    }

    pub fn hasVideo(self: MediaStream) bool {
        return self.video_track_count > 0;
    }
};

/// Video resolution preset
pub const VideoResolution = enum {
    qvga, // 320x240
    vga, // 640x480
    hd, // 1280x720
    full_hd, // 1920x1080
    uhd_4k, // 3840x2160

    pub fn width(self: VideoResolution) u32 {
        return switch (self) {
            .qvga => 320,
            .vga => 640,
            .hd => 1280,
            .full_hd => 1920,
            .uhd_4k => 3840,
        };
    }

    pub fn height(self: VideoResolution) u32 {
        return switch (self) {
            .qvga => 240,
            .vga => 480,
            .hd => 720,
            .full_hd => 1080,
            .uhd_4k => 2160,
        };
    }

    pub fn toString(self: VideoResolution) []const u8 {
        return switch (self) {
            .qvga => "QVGA (320x240)",
            .vga => "VGA (640x480)",
            .hd => "HD (1280x720)",
            .full_hd => "Full HD (1920x1080)",
            .uhd_4k => "4K UHD (3840x2160)",
        };
    }

    pub fn pixelCount(self: VideoResolution) u64 {
        return @as(u64, self.width()) * @as(u64, self.height());
    }
};

/// Audio codec
pub const AudioCodec = enum {
    opus,
    g711_pcmu,
    g711_pcma,
    g722,
    isac,

    pub fn toString(self: AudioCodec) []const u8 {
        return switch (self) {
            .opus => "opus",
            .g711_pcmu => "PCMU",
            .g711_pcma => "PCMA",
            .g722 => "G722",
            .isac => "iSAC",
        };
    }

    pub fn mimeType(self: AudioCodec) []const u8 {
        return switch (self) {
            .opus => "audio/opus",
            .g711_pcmu => "audio/PCMU",
            .g711_pcma => "audio/PCMA",
            .g722 => "audio/G722",
            .isac => "audio/iSAC",
        };
    }

    pub fn clockRate(self: AudioCodec) u32 {
        return switch (self) {
            .opus => 48000,
            .g711_pcmu, .g711_pcma => 8000,
            .g722 => 8000,
            .isac => 16000,
        };
    }
};

/// Video codec
pub const VideoCodec = enum {
    vp8,
    vp9,
    h264,
    h265,
    av1,

    pub fn toString(self: VideoCodec) []const u8 {
        return switch (self) {
            .vp8 => "VP8",
            .vp9 => "VP9",
            .h264 => "H.264",
            .h265 => "H.265",
            .av1 => "AV1",
        };
    }

    pub fn mimeType(self: VideoCodec) []const u8 {
        return switch (self) {
            .vp8 => "video/VP8",
            .vp9 => "video/VP9",
            .h264 => "video/H264",
            .h265 => "video/H265",
            .av1 => "video/AV1",
        };
    }

    pub fn supportsHardwareAcceleration(self: VideoCodec) bool {
        return switch (self) {
            .h264, .h265, .vp9, .av1 => true,
            .vp8 => false,
        };
    }
};

/// Media constraints for getUserMedia
pub const MediaConstraints = struct {
    audio_enabled: bool,
    video_enabled: bool,
    video_resolution: VideoResolution,
    frame_rate: u8,
    facing_mode: FacingMode,
    echo_cancellation: bool,
    noise_suppression: bool,
    auto_gain_control: bool,

    pub const FacingMode = enum {
        user,
        environment,
        any,

        pub fn toString(self: FacingMode) []const u8 {
            return switch (self) {
                .user => "user",
                .environment => "environment",
                .any => "any",
            };
        }
    };

    pub fn audioOnly() MediaConstraints {
        return .{
            .audio_enabled = true,
            .video_enabled = false,
            .video_resolution = .vga,
            .frame_rate = 30,
            .facing_mode = .user,
            .echo_cancellation = true,
            .noise_suppression = true,
            .auto_gain_control = true,
        };
    }

    pub fn videoOnly() MediaConstraints {
        return .{
            .audio_enabled = false,
            .video_enabled = true,
            .video_resolution = .hd,
            .frame_rate = 30,
            .facing_mode = .user,
            .echo_cancellation = false,
            .noise_suppression = false,
            .auto_gain_control = false,
        };
    }

    pub fn audioVideo() MediaConstraints {
        return .{
            .audio_enabled = true,
            .video_enabled = true,
            .video_resolution = .hd,
            .frame_rate = 30,
            .facing_mode = .user,
            .echo_cancellation = true,
            .noise_suppression = true,
            .auto_gain_control = true,
        };
    }

    pub fn withResolution(self: MediaConstraints, resolution: VideoResolution) MediaConstraints {
        var c = self;
        c.video_resolution = resolution;
        return c;
    }

    pub fn withFrameRate(self: MediaConstraints, fps: u8) MediaConstraints {
        var c = self;
        c.frame_rate = fps;
        return c;
    }

    pub fn withFacingMode(self: MediaConstraints, mode: FacingMode) MediaConstraints {
        var c = self;
        c.facing_mode = mode;
        return c;
    }
};

/// Data channel state
pub const DataChannelState = enum {
    connecting,
    open,
    closing,
    closed,

    pub fn toString(self: DataChannelState) []const u8 {
        return switch (self) {
            .connecting => "connecting",
            .open => "open",
            .closing => "closing",
            .closed => "closed",
        };
    }

    pub fn isOpen(self: DataChannelState) bool {
        return self == .open;
    }

    pub fn canSend(self: DataChannelState) bool {
        return self == .open;
    }
};

/// Data channel configuration
pub const DataChannelConfig = struct {
    ordered: bool,
    max_packet_life_time: ?u16,
    max_retransmits: ?u16,
    protocol: []const u8,
    negotiated: bool,
    channel_id: ?u16,

    pub fn defaults() DataChannelConfig {
        return .{
            .ordered = true,
            .max_packet_life_time = null,
            .max_retransmits = null,
            .protocol = "",
            .negotiated = false,
            .channel_id = null,
        };
    }

    pub fn unreliable(max_retransmits: u16) DataChannelConfig {
        return .{
            .ordered = false,
            .max_packet_life_time = null,
            .max_retransmits = max_retransmits,
            .protocol = "",
            .negotiated = false,
            .channel_id = null,
        };
    }

    pub fn withProtocol(self: DataChannelConfig, protocol: []const u8) DataChannelConfig {
        var config = self;
        config.protocol = protocol;
        return config;
    }

    pub fn withChannelId(self: DataChannelConfig, id: u16) DataChannelConfig {
        var config = self;
        config.channel_id = id;
        config.negotiated = true;
        return config;
    }
};

/// Data channel
pub const DataChannel = struct {
    label: []const u8,
    state: DataChannelState,
    buffered_amount: u64,
    buffered_amount_low_threshold: u64,
    config: DataChannelConfig,
    messages_sent: u64,
    messages_received: u64,
    bytes_sent: u64,
    bytes_received: u64,

    pub fn init(label: []const u8, config: DataChannelConfig) DataChannel {
        return .{
            .label = label,
            .state = .connecting,
            .buffered_amount = 0,
            .buffered_amount_low_threshold = 0,
            .config = config,
            .messages_sent = 0,
            .messages_received = 0,
            .bytes_sent = 0,
            .bytes_received = 0,
        };
    }

    pub fn open(self: *DataChannel) void {
        self.state = .open;
    }

    pub fn close(self: *DataChannel) void {
        self.state = .closing;
    }

    pub fn onClosed(self: *DataChannel) void {
        self.state = .closed;
    }

    pub fn recordSend(self: *DataChannel, bytes: u64) void {
        self.messages_sent += 1;
        self.bytes_sent += bytes;
    }

    pub fn recordReceive(self: *DataChannel, bytes: u64) void {
        self.messages_received += 1;
        self.bytes_received += bytes;
    }

    pub fn isOpen(self: DataChannel) bool {
        return self.state.isOpen();
    }

    pub fn canSend(self: DataChannel) bool {
        return self.state.canSend();
    }
};

/// RTC statistics type
pub const StatsType = enum {
    codec,
    inbound_rtp,
    outbound_rtp,
    remote_inbound_rtp,
    remote_outbound_rtp,
    media_source,
    peer_connection,
    data_channel,
    transport,
    candidate_pair,
    local_candidate,
    remote_candidate,

    pub fn toString(self: StatsType) []const u8 {
        return switch (self) {
            .codec => "codec",
            .inbound_rtp => "inbound-rtp",
            .outbound_rtp => "outbound-rtp",
            .remote_inbound_rtp => "remote-inbound-rtp",
            .remote_outbound_rtp => "remote-outbound-rtp",
            .media_source => "media-source",
            .peer_connection => "peer-connection",
            .data_channel => "data-channel",
            .transport => "transport",
            .candidate_pair => "candidate-pair",
            .local_candidate => "local-candidate",
            .remote_candidate => "remote-candidate",
        };
    }
};

/// RTC connection statistics
pub const ConnectionStats = struct {
    bytes_sent: u64,
    bytes_received: u64,
    packets_sent: u64,
    packets_received: u64,
    packets_lost: u64,
    jitter: f64,
    round_trip_time: f64,
    timestamp: u64,

    pub fn init() ConnectionStats {
        return .{
            .bytes_sent = 0,
            .bytes_received = 0,
            .packets_sent = 0,
            .packets_received = 0,
            .packets_lost = 0,
            .jitter = 0,
            .round_trip_time = 0,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn packetLossRate(self: ConnectionStats) f64 {
        const total = self.packets_received + self.packets_lost;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.packets_lost)) / @as(f64, @floatFromInt(total)) * 100.0;
    }

    pub fn update(self: *ConnectionStats, sent: u64, received: u64, lost: u64) void {
        self.bytes_sent += sent;
        self.bytes_received += received;
        self.packets_sent += 1;
        self.packets_received += 1;
        self.packets_lost += lost;
        self.timestamp = getCurrentTimestamp();
    }
};

/// Peer connection
pub const PeerConnection = struct {
    connection_id: []const u8,
    signaling_state: SignalingState,
    ice_gathering_state: IceGatheringState,
    ice_connection_state: IceConnectionState,
    connection_state: PeerConnectionState,
    config: PeerConnectionConfig,
    local_streams: u32,
    remote_streams: u32,
    data_channels: u32,
    stats: ConnectionStats,

    pub fn init(connection_id: []const u8, config: PeerConnectionConfig) PeerConnection {
        return .{
            .connection_id = connection_id,
            .signaling_state = .stable,
            .ice_gathering_state = .new_state,
            .ice_connection_state = .new_state,
            .connection_state = .new_state,
            .config = config,
            .local_streams = 0,
            .remote_streams = 0,
            .data_channels = 0,
            .stats = ConnectionStats.init(),
        };
    }

    pub fn setLocalDescription(self: *PeerConnection, desc: SessionDescription) void {
        if (desc.isOffer()) {
            self.signaling_state = .have_local_offer;
        } else if (desc.isAnswer()) {
            self.signaling_state = .stable;
        }
    }

    pub fn setRemoteDescription(self: *PeerConnection, desc: SessionDescription) void {
        if (desc.isOffer()) {
            self.signaling_state = .have_remote_offer;
        } else if (desc.isAnswer()) {
            self.signaling_state = .stable;
        }
    }

    pub fn addLocalStream(self: *PeerConnection) void {
        self.local_streams += 1;
    }

    pub fn addRemoteStream(self: *PeerConnection) void {
        self.remote_streams += 1;
    }

    pub fn createDataChannel(self: *PeerConnection) void {
        self.data_channels += 1;
    }

    pub fn onIceCandidate(self: *PeerConnection) void {
        if (self.ice_gathering_state == .new_state) {
            self.ice_gathering_state = .gathering;
        }
    }

    pub fn onIceGatheringComplete(self: *PeerConnection) void {
        self.ice_gathering_state = .complete;
    }

    pub fn onIceConnected(self: *PeerConnection) void {
        self.ice_connection_state = .connected;
        self.connection_state = .connected;
    }

    pub fn onIceFailed(self: *PeerConnection) void {
        self.ice_connection_state = .failed;
        self.connection_state = .failed;
    }

    pub fn close(self: *PeerConnection) void {
        self.signaling_state = .closed;
        self.ice_connection_state = .closed;
        self.connection_state = .closed;
    }

    pub fn isConnected(self: PeerConnection) bool {
        return self.connection_state.isConnected();
    }

    pub fn canCreateOffer(self: PeerConnection) bool {
        return self.signaling_state.canCreateOffer();
    }

    pub fn canCreateAnswer(self: PeerConnection) bool {
        return self.signaling_state.canCreateAnswer();
    }
};

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() u64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    const ms = @divTrunc(ts.nsec, 1_000_000);
    return @intCast(@as(i128, ts.sec) * 1000 + ms);
}

/// Check if WebRTC is supported
pub fn isSupported() bool {
    return true; // WebRTC is widely supported
}

// ============================================================================
// Tests
// ============================================================================

test "SignalingState properties" {
    try std.testing.expect(SignalingState.stable.canCreateOffer());
    try std.testing.expect(SignalingState.have_remote_offer.canCreateAnswer());
    try std.testing.expect(!SignalingState.stable.canCreateAnswer());
    try std.testing.expectEqualStrings("stable", SignalingState.stable.toString());
}

test "IceGatheringState properties" {
    try std.testing.expect(IceGatheringState.gathering.isGathering());
    try std.testing.expect(!IceGatheringState.complete.isGathering());
    try std.testing.expectEqualStrings("gathering", IceGatheringState.gathering.toString());
}

test "IceConnectionState properties" {
    try std.testing.expect(IceConnectionState.connected.isConnected());
    try std.testing.expect(IceConnectionState.completed.isConnected());
    try std.testing.expect(!IceConnectionState.checking.isConnected());
    try std.testing.expect(IceConnectionState.failed.isFailed());
    try std.testing.expect(IceConnectionState.connected.isActive());
    try std.testing.expect(!IceConnectionState.closed.isActive());
}

test "PeerConnectionState properties" {
    try std.testing.expect(PeerConnectionState.connected.isConnected());
    try std.testing.expect(PeerConnectionState.disconnected.canReconnect());
    try std.testing.expect(!PeerConnectionState.failed.canReconnect());
}

test "IceServer STUN" {
    const server = IceServer.stun("stun:stun.l.google.com:19302");
    try std.testing.expect(server.isStun());
    try std.testing.expect(!server.isTurn());
    try std.testing.expect(!server.requiresCredentials());
}

test "IceServer TURN" {
    const server = IceServer.turn("turn:turn.example.com:3478", "user", "pass");
    try std.testing.expect(!server.isStun());
    try std.testing.expect(server.isTurn());
    try std.testing.expect(server.requiresCredentials());
    try std.testing.expectEqualStrings("user", server.username.?);
}

test "PeerConnectionConfig defaults" {
    const config = PeerConnectionConfig.defaults();
    try std.testing.expectEqual(IceTransportPolicy.all, config.ice_transport_policy);
    try std.testing.expectEqual(BundlePolicy.balanced, config.bundle_policy);
    try std.testing.expectEqual(RtcpMuxPolicy.require, config.rtcp_mux_policy);
}

test "PeerConnectionConfig builder" {
    const config = PeerConnectionConfig.defaults()
        .withIceTransportPolicy(.relay)
        .withBundlePolicy(.max_bundle)
        .withCandidatePoolSize(5);

    try std.testing.expectEqual(IceTransportPolicy.relay, config.ice_transport_policy);
    try std.testing.expectEqual(BundlePolicy.max_bundle, config.bundle_policy);
    try std.testing.expectEqual(@as(u8, 5), config.ice_candidate_pool_size);
}

test "SessionDescription creation" {
    const offer = SessionDescription.init(.offer, "v=0\r\no=...");
    try std.testing.expect(offer.isOffer());
    try std.testing.expect(!offer.isAnswer());

    const answer = SessionDescription.init(.answer, "v=0\r\no=...");
    try std.testing.expect(answer.isAnswer());
}

test "IceCandidate creation" {
    const candidate = IceCandidate.init("candidate:...")
        .withSdpMid("audio")
        .withMlineIndex(0);

    try std.testing.expectEqualStrings("audio", candidate.sdp_mid.?);
    try std.testing.expectEqual(@as(?u16, 0), candidate.sdp_mline_index);
    try std.testing.expect(!candidate.isEmpty());
}

test "MediaStreamTrack creation" {
    var track = MediaStreamTrack.init("track-001", .video)
        .withLabel("Camera");

    try std.testing.expect(track.isVideo());
    try std.testing.expect(!track.isAudio());
    try std.testing.expect(track.isLive());
    try std.testing.expect(track.enabled);

    track.setEnabled(false);
    try std.testing.expect(!track.enabled);

    track.stop();
    try std.testing.expect(!track.isLive());
}

test "MediaStream track management" {
    var stream = MediaStream.init("stream-001");
    try std.testing.expect(stream.active);
    try std.testing.expectEqual(@as(u32, 0), stream.trackCount());

    stream.addAudioTrack();
    stream.addVideoTrack();
    try std.testing.expectEqual(@as(u32, 2), stream.trackCount());
    try std.testing.expect(stream.hasAudio());
    try std.testing.expect(stream.hasVideo());

    stream.removeAudioTrack();
    try std.testing.expect(!stream.hasAudio());
    try std.testing.expect(stream.hasVideo());
}

test "VideoResolution properties" {
    try std.testing.expectEqual(@as(u32, 1280), VideoResolution.hd.width());
    try std.testing.expectEqual(@as(u32, 720), VideoResolution.hd.height());
    try std.testing.expectEqual(@as(u32, 1920), VideoResolution.full_hd.width());
    try std.testing.expectEqual(@as(u64, 1280 * 720), VideoResolution.hd.pixelCount());
}

test "AudioCodec properties" {
    try std.testing.expectEqualStrings("opus", AudioCodec.opus.toString());
    try std.testing.expectEqualStrings("audio/opus", AudioCodec.opus.mimeType());
    try std.testing.expectEqual(@as(u32, 48000), AudioCodec.opus.clockRate());
    try std.testing.expectEqual(@as(u32, 8000), AudioCodec.g711_pcmu.clockRate());
}

test "VideoCodec properties" {
    try std.testing.expectEqualStrings("H.264", VideoCodec.h264.toString());
    try std.testing.expectEqualStrings("video/H264", VideoCodec.h264.mimeType());
    try std.testing.expect(VideoCodec.h264.supportsHardwareAcceleration());
    try std.testing.expect(!VideoCodec.vp8.supportsHardwareAcceleration());
}

test "MediaConstraints presets" {
    const audio = MediaConstraints.audioOnly();
    try std.testing.expect(audio.audio_enabled);
    try std.testing.expect(!audio.video_enabled);
    try std.testing.expect(audio.echo_cancellation);

    const video = MediaConstraints.videoOnly();
    try std.testing.expect(!video.audio_enabled);
    try std.testing.expect(video.video_enabled);

    const av = MediaConstraints.audioVideo();
    try std.testing.expect(av.audio_enabled);
    try std.testing.expect(av.video_enabled);
}

test "MediaConstraints builder" {
    const constraints = MediaConstraints.audioVideo()
        .withResolution(.full_hd)
        .withFrameRate(60)
        .withFacingMode(.environment);

    try std.testing.expectEqual(VideoResolution.full_hd, constraints.video_resolution);
    try std.testing.expectEqual(@as(u8, 60), constraints.frame_rate);
    try std.testing.expectEqual(MediaConstraints.FacingMode.environment, constraints.facing_mode);
}

test "DataChannelState properties" {
    try std.testing.expect(DataChannelState.open.isOpen());
    try std.testing.expect(DataChannelState.open.canSend());
    try std.testing.expect(!DataChannelState.connecting.canSend());
    try std.testing.expect(!DataChannelState.closed.isOpen());
}

test "DataChannelConfig defaults" {
    const config = DataChannelConfig.defaults();
    try std.testing.expect(config.ordered);
    try std.testing.expect(!config.negotiated);
}

test "DataChannelConfig unreliable" {
    const config = DataChannelConfig.unreliable(3);
    try std.testing.expect(!config.ordered);
    try std.testing.expectEqual(@as(?u16, 3), config.max_retransmits);
}

test "DataChannel lifecycle" {
    var channel = DataChannel.init("chat", DataChannelConfig.defaults());
    try std.testing.expectEqual(DataChannelState.connecting, channel.state);
    try std.testing.expect(!channel.isOpen());

    channel.open();
    try std.testing.expect(channel.isOpen());
    try std.testing.expect(channel.canSend());

    channel.recordSend(100);
    try std.testing.expectEqual(@as(u64, 1), channel.messages_sent);
    try std.testing.expectEqual(@as(u64, 100), channel.bytes_sent);

    channel.recordReceive(50);
    try std.testing.expectEqual(@as(u64, 1), channel.messages_received);

    channel.close();
    channel.onClosed();
    try std.testing.expect(!channel.isOpen());
}

test "ConnectionStats packetLossRate" {
    var stats = ConnectionStats.init();
    stats.packets_received = 90;
    stats.packets_lost = 10;

    try std.testing.expect(stats.packetLossRate() > 9.9);
    try std.testing.expect(stats.packetLossRate() < 10.1);
}

test "PeerConnection creation" {
    const config = PeerConnectionConfig.defaults();
    const pc = PeerConnection.init("pc-001", config);

    try std.testing.expectEqual(SignalingState.stable, pc.signaling_state);
    try std.testing.expectEqual(IceGatheringState.new_state, pc.ice_gathering_state);
    try std.testing.expect(!pc.isConnected());
    try std.testing.expect(pc.canCreateOffer());
}

test "PeerConnection offer/answer" {
    const config = PeerConnectionConfig.defaults();
    var pc = PeerConnection.init("pc-002", config);

    // Create and set local offer
    const offer = SessionDescription.init(.offer, "sdp...");
    pc.setLocalDescription(offer);
    try std.testing.expectEqual(SignalingState.have_local_offer, pc.signaling_state);

    // Receive and set remote answer
    const answer = SessionDescription.init(.answer, "sdp...");
    pc.setRemoteDescription(answer);
    try std.testing.expectEqual(SignalingState.stable, pc.signaling_state);
}

test "PeerConnection ICE flow" {
    const config = PeerConnectionConfig.defaults();
    var pc = PeerConnection.init("pc-003", config);

    pc.onIceCandidate();
    try std.testing.expectEqual(IceGatheringState.gathering, pc.ice_gathering_state);

    pc.onIceGatheringComplete();
    try std.testing.expectEqual(IceGatheringState.complete, pc.ice_gathering_state);

    pc.onIceConnected();
    try std.testing.expect(pc.isConnected());
}

test "PeerConnection streams and channels" {
    const config = PeerConnectionConfig.defaults();
    var pc = PeerConnection.init("pc-004", config);

    pc.addLocalStream();
    pc.addRemoteStream();
    pc.createDataChannel();

    try std.testing.expectEqual(@as(u32, 1), pc.local_streams);
    try std.testing.expectEqual(@as(u32, 1), pc.remote_streams);
    try std.testing.expectEqual(@as(u32, 1), pc.data_channels);
}

test "PeerConnection close" {
    const config = PeerConnectionConfig.defaults();
    var pc = PeerConnection.init("pc-005", config);

    pc.close();
    try std.testing.expectEqual(SignalingState.closed, pc.signaling_state);
    try std.testing.expectEqual(PeerConnectionState.closed, pc.connection_state);
}

test "isSupported" {
    try std.testing.expect(isSupported());
}
