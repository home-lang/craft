//! SharePlay Module
//! FaceTime Group Activities and Shared Experiences
//! Provides cross-platform abstractions for collaborative features

const std = @import("std");
const builtin = @import("builtin");

/// Platform support for SharePlay
pub const Platform = enum {
    ios, // SharePlay via FaceTime
    macos, // SharePlay via FaceTime
    tvos, // SharePlay support
    android, // Simulated via WebRTC/custom
    unsupported,

    pub fn current() Platform {
        return switch (builtin.os.tag) {
            .ios => .ios,
            .macos => .macos,
            .tvos => .tvos,
            else => if (builtin.abi == .android) .android else .unsupported,
        };
    }

    pub fn supportsNativeSharePlay(self: Platform) bool {
        return self == .ios or self == .macos or self == .tvos;
    }
};

/// Group session state
pub const SessionState = enum {
    waiting, // Waiting for participants
    joined, // User has joined
    active, // Activity is running
    invalidated, // Session ended
    suspended, // Temporarily paused

    pub fn isActive(self: SessionState) bool {
        return self == .joined or self == .active;
    }

    pub fn canSendMessages(self: SessionState) bool {
        return self == .active;
    }
};

/// Participant state
pub const ParticipantState = enum {
    waiting,
    connected,
    disconnected,
};

/// Participant in a group session
pub const Participant = struct {
    id: []const u8,
    display_name: ?[]const u8 = null,
    is_local: bool = false,
    state: ParticipantState = .waiting,
    joined_at: i64 = 0,
    role: ParticipantRole = .participant,

    pub const ParticipantRole = enum {
        host,
        participant,
        spectator,
    };

    pub fn init(id: []const u8) Participant {
        return .{
            .id = id,
            .joined_at = getCurrentTimestamp(),
        };
    }

    pub fn withName(self: Participant, name: []const u8) Participant {
        var copy = self;
        copy.display_name = name;
        return copy;
    }

    pub fn withRole(self: Participant, role: ParticipantRole) Participant {
        var copy = self;
        copy.role = role;
        return copy;
    }

    pub fn asLocal(self: Participant) Participant {
        var copy = self;
        copy.is_local = true;
        return copy;
    }

    pub fn isConnected(self: *const Participant) bool {
        return self.state == .connected;
    }
};

/// Activity type for SharePlay
pub const ActivityType = enum {
    media_playback, // Watch together
    gaming, // Play together
    collaboration, // Work together
    fitness, // Workout together
    education, // Learn together
    custom,
};

/// Synchronization mode
pub const SyncMode = enum {
    automatic, // System handles sync
    manual, // App controls sync
    loose, // Best effort, allow drift
    strict, // Tight synchronization
};

/// Message reliability
pub const MessageReliability = enum {
    reliable, // Guaranteed delivery, ordered
    unreliable, // Best effort, may drop
};

/// Group activity definition
pub const GroupActivity = struct {
    id: []const u8,
    title: []const u8,
    subtitle: ?[]const u8 = null,
    activity_type: ActivityType = .custom,
    supports_group_session: bool = true,
    fallback_url: ?[]const u8 = null,
    prepares_content: bool = false,
    metadata: std.ArrayListUnmanaged(MetadataEntry) = .empty,

    pub const MetadataEntry = struct {
        key: []const u8,
        value: []const u8,
    };

    pub fn init(id: []const u8, title: []const u8) GroupActivity {
        return .{
            .id = id,
            .title = title,
        };
    }

    pub fn withSubtitle(self: GroupActivity, subtitle: []const u8) GroupActivity {
        var copy = self;
        copy.subtitle = subtitle;
        return copy;
    }

    pub fn withType(self: GroupActivity, activity_type: ActivityType) GroupActivity {
        var copy = self;
        copy.activity_type = activity_type;
        return copy;
    }

    pub fn withFallbackURL(self: GroupActivity, url: []const u8) GroupActivity {
        var copy = self;
        copy.fallback_url = url;
        return copy;
    }

    pub fn withContentPreparation(self: GroupActivity, prepares: bool) GroupActivity {
        var copy = self;
        copy.prepares_content = prepares;
        return copy;
    }
};

/// Playback state for media sync
pub const PlaybackState = struct {
    is_playing: bool = false,
    position_ms: i64 = 0,
    rate: f32 = 1.0,
    timestamp: i64 = 0,

    pub fn init() PlaybackState {
        return .{};
    }

    pub fn initWithTimestamp() PlaybackState {
        return .{
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn playing(position: i64) PlaybackState {
        return .{
            .is_playing = true,
            .position_ms = position,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn paused(position: i64) PlaybackState {
        return .{
            .is_playing = false,
            .position_ms = position,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withRate(self: PlaybackState, rate: f32) PlaybackState {
        var copy = self;
        copy.rate = rate;
        return copy;
    }

    pub fn estimatedPosition(self: *const PlaybackState) i64 {
        if (!self.is_playing) {
            return self.position_ms;
        }
        const now = getCurrentTimestamp();
        const elapsed_sec = now - self.timestamp;
        const elapsed_ms = elapsed_sec * 1000;
        const adjusted = @as(i64, @intFromFloat(@as(f64, @floatFromInt(elapsed_ms)) * self.rate));
        return self.position_ms + adjusted;
    }
};

/// Coordinator configuration for media
pub const CoordinatorConfig = struct {
    sync_mode: SyncMode = .automatic,
    pause_on_participant_leave: bool = false,
    sync_tolerance_ms: i64 = 500,
    allow_seek: bool = true,
    allow_rate_change: bool = false,

    pub fn init() CoordinatorConfig {
        return .{};
    }

    pub fn withSyncMode(self: CoordinatorConfig, mode: SyncMode) CoordinatorConfig {
        var copy = self;
        copy.sync_mode = mode;
        return copy;
    }

    pub fn withPauseOnLeave(self: CoordinatorConfig, pause: bool) CoordinatorConfig {
        var copy = self;
        copy.pause_on_participant_leave = pause;
        return copy;
    }

    pub fn withSyncTolerance(self: CoordinatorConfig, ms: i64) CoordinatorConfig {
        var copy = self;
        copy.sync_tolerance_ms = ms;
        return copy;
    }
};

/// Message for group communication
pub const GroupMessage = struct {
    id: u64,
    sender_id: []const u8,
    payload: []const u8,
    message_type: MessageType = .data,
    reliability: MessageReliability = .reliable,
    timestamp: i64,

    pub const MessageType = enum {
        data,
        state_sync,
        action,
        heartbeat,
    };

    pub fn init(id: u64, sender_id: []const u8, payload: []const u8) GroupMessage {
        return .{
            .id = id,
            .sender_id = sender_id,
            .payload = payload,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withType(self: GroupMessage, msg_type: MessageType) GroupMessage {
        var copy = self;
        copy.message_type = msg_type;
        return copy;
    }

    pub fn withReliability(self: GroupMessage, reliability: MessageReliability) GroupMessage {
        var copy = self;
        copy.reliability = reliability;
        return copy;
    }
};

/// Session event for callbacks
pub const SessionEvent = struct {
    event_type: EventType,
    participant_id: ?[]const u8 = null,
    timestamp: i64,
    data: ?[]const u8 = null,

    pub const EventType = enum {
        session_started,
        session_ended,
        participant_joined,
        participant_left,
        state_changed,
        message_received,
        playback_synced,
        error_occurred,
    };

    pub fn init(event_type: EventType) SessionEvent {
        return .{
            .event_type = event_type,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withParticipant(self: SessionEvent, id: []const u8) SessionEvent {
        var copy = self;
        copy.participant_id = id;
        return copy;
    }

    pub fn withData(self: SessionEvent, data: []const u8) SessionEvent {
        var copy = self;
        copy.data = data;
        return copy;
    }
};

/// Group Session for SharePlay
pub const GroupSession = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    activity: GroupActivity,
    state: SessionState = .waiting,
    participants: std.ArrayListUnmanaged(Participant),
    local_participant_id: ?[]const u8 = null,
    created_at: i64,
    started_at: ?i64 = null,
    playback_state: PlaybackState = .{},
    coordinator_config: CoordinatorConfig = CoordinatorConfig.init(),
    message_counter: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, activity: GroupActivity) GroupSession {
        return .{
            .allocator = allocator,
            .id = id,
            .activity = activity,
            .participants = .empty,
            .created_at = getCurrentTimestamp(),
        };
    }

    pub fn deinit(self: *GroupSession) void {
        self.participants.deinit(self.allocator);
    }

    pub fn join(self: *GroupSession, participant: Participant) !void {
        if (self.state == .invalidated) {
            return error.SessionInvalidated;
        }

        var p = participant;
        p.state = .connected;

        if (participant.is_local) {
            self.local_participant_id = participant.id;
        }

        try self.participants.append(self.allocator, p);

        if (self.state == .waiting) {
            self.state = .joined;
        }
    }

    pub fn leave(self: *GroupSession, participant_id: []const u8) void {
        var i: usize = 0;
        while (i < self.participants.items.len) {
            if (std.mem.eql(u8, self.participants.items[i].id, participant_id)) {
                _ = self.participants.orderedRemove(i);
                break;
            }
            i += 1;
        }

        if (self.participants.items.len == 0) {
            self.state = .invalidated;
        }
    }

    pub fn start(self: *GroupSession) !void {
        if (self.state != .joined) {
            return error.NotJoined;
        }
        self.state = .active;
        self.started_at = getCurrentTimestamp();
    }

    pub fn end(self: *GroupSession) void {
        self.state = .invalidated;
    }

    pub fn suspend_session(self: *GroupSession) void {
        if (self.state == .active) {
            self.state = .suspended;
        }
    }

    pub fn resume_session(self: *GroupSession) void {
        if (self.state == .suspended) {
            self.state = .active;
        }
    }

    pub fn getParticipant(self: *const GroupSession, id: []const u8) ?*const Participant {
        for (self.participants.items) |*p| {
            if (std.mem.eql(u8, p.id, id)) {
                return p;
            }
        }
        return null;
    }

    pub fn getLocalParticipant(self: *const GroupSession) ?*const Participant {
        if (self.local_participant_id) |id| {
            return self.getParticipant(id);
        }
        return null;
    }

    pub fn participantCount(self: *const GroupSession) usize {
        return self.participants.items.len;
    }

    pub fn connectedParticipantCount(self: *const GroupSession) usize {
        var count: usize = 0;
        for (self.participants.items) |p| {
            if (p.state == .connected) {
                count += 1;
            }
        }
        return count;
    }

    pub fn updatePlayback(self: *GroupSession, playback: PlaybackState) void {
        self.playback_state = playback;
    }

    pub fn play(self: *GroupSession) void {
        self.playback_state.is_playing = true;
        self.playback_state.timestamp = getCurrentTimestamp();
    }

    pub fn pause(self: *GroupSession) void {
        self.playback_state.position_ms = self.playback_state.estimatedPosition();
        self.playback_state.is_playing = false;
        self.playback_state.timestamp = getCurrentTimestamp();
    }

    pub fn seek(self: *GroupSession, position_ms: i64) !void {
        if (!self.coordinator_config.allow_seek) {
            return error.SeekNotAllowed;
        }
        self.playback_state.position_ms = position_ms;
        self.playback_state.timestamp = getCurrentTimestamp();
    }

    pub fn createMessage(self: *GroupSession, payload: []const u8) GroupMessage {
        self.message_counter += 1;
        return GroupMessage.init(
            self.message_counter,
            self.local_participant_id orelse "unknown",
            payload,
        );
    }

    pub fn isHost(self: *const GroupSession) bool {
        if (self.getLocalParticipant()) |p| {
            return p.role == .host;
        }
        return false;
    }
};

/// SharePlay eligibility check
pub const EligibilityResult = struct {
    is_eligible: bool = false,
    reason: ?Reason = null,

    pub const Reason = enum {
        not_in_facetime,
        no_participants,
        activity_not_supported,
        system_restriction,
    };

    pub fn eligible() EligibilityResult {
        return .{ .is_eligible = true };
    }

    pub fn notEligible(reason: Reason) EligibilityResult {
        return .{ .is_eligible = false, .reason = reason };
    }
};

/// SharePlay Controller
pub const SharePlayController = struct {
    allocator: std.mem.Allocator,
    sessions: std.ArrayListUnmanaged(GroupSession),
    active_session_id: ?[]const u8 = null,
    event_history: std.ArrayListUnmanaged(SessionEvent),
    event_callback: ?*const fn (SessionEvent) void = null,
    is_eligible: bool = true,
    local_user_id: []const u8 = "local_user",

    pub fn init(allocator: std.mem.Allocator) SharePlayController {
        return .{
            .allocator = allocator,
            .sessions = .empty,
            .event_history = .empty,
        };
    }

    pub fn deinit(self: *SharePlayController) void {
        for (self.sessions.items) |*session| {
            session.deinit();
        }
        self.sessions.deinit(self.allocator);
        self.event_history.deinit(self.allocator);
    }

    pub fn checkEligibility(self: *const SharePlayController, activity: GroupActivity) EligibilityResult {
        _ = activity;
        if (!self.is_eligible) {
            return EligibilityResult.notEligible(.system_restriction);
        }
        return EligibilityResult.eligible();
    }

    pub fn prepareActivity(self: *SharePlayController, activity: GroupActivity) !*GroupSession {
        var id_buf: [32]u8 = undefined;
        const id = try std.fmt.bufPrint(&id_buf, "session_{d}", .{getCurrentTimestamp()});

        const session = GroupSession.init(self.allocator, id, activity);
        try self.sessions.append(self.allocator, session);

        return &self.sessions.items[self.sessions.items.len - 1];
    }

    pub fn activateSession(self: *SharePlayController, session_id: []const u8) !void {
        const session = self.findSession(session_id) orelse return error.SessionNotFound;

        // Add local participant
        const local = Participant.init(self.local_user_id)
            .withName("Local User")
            .withRole(.host)
            .asLocal();
        try session.join(local);

        try session.start();
        self.active_session_id = session_id;

        const event = SessionEvent.init(.session_started);
        try self.event_history.append(self.allocator, event);

        if (self.event_callback) |callback| {
            callback(event);
        }
    }

    pub fn endSession(self: *SharePlayController, session_id: []const u8) !void {
        const session = self.findSession(session_id) orelse return error.SessionNotFound;

        session.end();

        if (self.active_session_id) |active_id| {
            if (std.mem.eql(u8, active_id, session_id)) {
                self.active_session_id = null;
            }
        }

        const event = SessionEvent.init(.session_ended);
        try self.event_history.append(self.allocator, event);

        if (self.event_callback) |callback| {
            callback(event);
        }
    }

    pub fn findSession(self: *SharePlayController, session_id: []const u8) ?*GroupSession {
        for (self.sessions.items) |*session| {
            if (std.mem.eql(u8, session.id, session_id)) {
                return session;
            }
        }
        return null;
    }

    pub fn getActiveSession(self: *SharePlayController) ?*GroupSession {
        if (self.active_session_id) |id| {
            return self.findSession(id);
        }
        return null;
    }

    pub fn addParticipant(self: *SharePlayController, session_id: []const u8, participant: Participant) !void {
        const session = self.findSession(session_id) orelse return error.SessionNotFound;
        try session.join(participant);

        const event = SessionEvent.init(.participant_joined)
            .withParticipant(participant.id);
        try self.event_history.append(self.allocator, event);

        if (self.event_callback) |callback| {
            callback(event);
        }
    }

    pub fn removeParticipant(self: *SharePlayController, session_id: []const u8, participant_id: []const u8) !void {
        const session = self.findSession(session_id) orelse return error.SessionNotFound;
        session.leave(participant_id);

        const event = SessionEvent.init(.participant_left)
            .withParticipant(participant_id);
        try self.event_history.append(self.allocator, event);

        if (self.event_callback) |callback| {
            callback(event);
        }
    }

    pub fn sendMessage(self: *SharePlayController, session_id: []const u8, payload: []const u8) !GroupMessage {
        const session = self.findSession(session_id) orelse return error.SessionNotFound;

        if (!session.state.canSendMessages()) {
            return error.SessionNotActive;
        }

        return session.createMessage(payload);
    }

    pub fn syncPlayback(self: *SharePlayController, session_id: []const u8, playback: PlaybackState) !void {
        const session = self.findSession(session_id) orelse return error.SessionNotFound;
        session.updatePlayback(playback);

        const event = SessionEvent.init(.playback_synced);
        try self.event_history.append(self.allocator, event);
    }

    pub fn setEventCallback(self: *SharePlayController, callback: *const fn (SessionEvent) void) void {
        self.event_callback = callback;
    }

    pub fn sessionCount(self: *const SharePlayController) usize {
        return self.sessions.items.len;
    }

    pub fn activeSessionCount(self: *const SharePlayController) usize {
        var count: usize = 0;
        for (self.sessions.items) |session| {
            if (session.state.isActive()) {
                count += 1;
            }
        }
        return count;
    }

    pub fn getEventHistory(self: *const SharePlayController) []const SessionEvent {
        return self.event_history.items;
    }

    pub fn clearEventHistory(self: *SharePlayController) void {
        self.event_history.clearAndFree(self.allocator);
    }

    pub fn setLocalUserId(self: *SharePlayController, user_id: []const u8) void {
        self.local_user_id = user_id;
    }

    pub fn pruneInvalidatedSessions(self: *SharePlayController) void {
        var i: usize = 0;
        while (i < self.sessions.items.len) {
            if (self.sessions.items[i].state == .invalidated) {
                self.sessions.items[i].deinit();
                _ = self.sessions.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }
};

/// Helper to get current timestamp
fn getCurrentTimestamp() i64 {
    if (builtin.os.tag == .macos or builtin.os.tag == .ios or
        builtin.os.tag == .tvos or builtin.os.tag == .watchos)
    {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        return ts.sec;
    } else if (builtin.os.tag == .windows) {
        return std.time.timestamp();
    } else if (builtin.os.tag == .linux) {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        return ts.sec;
    } else {
        return 0;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "Platform detection" {
    const platform = Platform.current();
    try std.testing.expect(platform == .macos or platform != .macos);
}

test "Platform supportsNativeSharePlay" {
    try std.testing.expect(Platform.ios.supportsNativeSharePlay());
    try std.testing.expect(Platform.macos.supportsNativeSharePlay());
    try std.testing.expect(Platform.tvos.supportsNativeSharePlay());
    try std.testing.expect(!Platform.android.supportsNativeSharePlay());
    try std.testing.expect(!Platform.unsupported.supportsNativeSharePlay());
}

test "SessionState properties" {
    try std.testing.expect(SessionState.joined.isActive());
    try std.testing.expect(SessionState.active.isActive());
    try std.testing.expect(!SessionState.waiting.isActive());
    try std.testing.expect(!SessionState.invalidated.isActive());

    try std.testing.expect(SessionState.active.canSendMessages());
    try std.testing.expect(!SessionState.waiting.canSendMessages());
}

test "Participant init and builder" {
    const participant = Participant.init("user123")
        .withName("Test User")
        .withRole(.host)
        .asLocal();

    try std.testing.expectEqualStrings("user123", participant.id);
    try std.testing.expectEqualStrings("Test User", participant.display_name.?);
    try std.testing.expectEqual(Participant.ParticipantRole.host, participant.role);
    try std.testing.expect(participant.is_local);
}

test "Participant isConnected" {
    var participant = Participant.init("user123");
    try std.testing.expect(!participant.isConnected());

    participant.state = .connected;
    try std.testing.expect(participant.isConnected());
}

test "GroupActivity builder" {
    const activity = GroupActivity.init("activity_1", "Watch Together")
        .withSubtitle("Movie Night")
        .withType(.media_playback)
        .withFallbackURL("https://example.com/movie");

    try std.testing.expectEqualStrings("activity_1", activity.id);
    try std.testing.expectEqualStrings("Watch Together", activity.title);
    try std.testing.expectEqualStrings("Movie Night", activity.subtitle.?);
    try std.testing.expectEqual(ActivityType.media_playback, activity.activity_type);
}

test "PlaybackState init" {
    const state = PlaybackState.init();
    try std.testing.expect(!state.is_playing);
    try std.testing.expectEqual(@as(i64, 0), state.position_ms);
    try std.testing.expectEqual(@as(f32, 1.0), state.rate);
}

test "PlaybackState playing and paused" {
    const playing = PlaybackState.playing(5000);
    try std.testing.expect(playing.is_playing);
    try std.testing.expectEqual(@as(i64, 5000), playing.position_ms);

    const paused_state = PlaybackState.paused(10000);
    try std.testing.expect(!paused_state.is_playing);
    try std.testing.expectEqual(@as(i64, 10000), paused_state.position_ms);
}

test "PlaybackState withRate" {
    const state = PlaybackState.playing(0).withRate(1.5);
    try std.testing.expectEqual(@as(f32, 1.5), state.rate);
}

test "CoordinatorConfig builder" {
    const config = CoordinatorConfig.init()
        .withSyncMode(.strict)
        .withPauseOnLeave(true)
        .withSyncTolerance(250);

    try std.testing.expectEqual(SyncMode.strict, config.sync_mode);
    try std.testing.expect(config.pause_on_participant_leave);
    try std.testing.expectEqual(@as(i64, 250), config.sync_tolerance_ms);
}

test "GroupMessage init and builder" {
    const msg = GroupMessage.init(1, "sender123", "hello")
        .withType(.action)
        .withReliability(.unreliable);

    try std.testing.expectEqual(@as(u64, 1), msg.id);
    try std.testing.expectEqualStrings("sender123", msg.sender_id);
    try std.testing.expectEqualStrings("hello", msg.payload);
    try std.testing.expectEqual(GroupMessage.MessageType.action, msg.message_type);
    try std.testing.expectEqual(MessageReliability.unreliable, msg.reliability);
}

test "SessionEvent builder" {
    const event = SessionEvent.init(.participant_joined)
        .withParticipant("user123")
        .withData("extra_data");

    try std.testing.expectEqual(SessionEvent.EventType.participant_joined, event.event_type);
    try std.testing.expectEqualStrings("user123", event.participant_id.?);
    try std.testing.expectEqualStrings("extra_data", event.data.?);
}

test "GroupSession init and deinit" {
    const activity = GroupActivity.init("act1", "Test Activity");
    var session = GroupSession.init(std.testing.allocator, "session1", activity);
    defer session.deinit();

    try std.testing.expectEqualStrings("session1", session.id);
    try std.testing.expectEqual(SessionState.waiting, session.state);
    try std.testing.expectEqual(@as(usize, 0), session.participantCount());
}

test "GroupSession join" {
    const activity = GroupActivity.init("act1", "Test Activity");
    var session = GroupSession.init(std.testing.allocator, "session1", activity);
    defer session.deinit();

    const participant = Participant.init("user1").asLocal();
    try session.join(participant);

    try std.testing.expectEqual(@as(usize, 1), session.participantCount());
    try std.testing.expectEqual(SessionState.joined, session.state);
    try std.testing.expectEqualStrings("user1", session.local_participant_id.?);
}

test "GroupSession start" {
    const activity = GroupActivity.init("act1", "Test Activity");
    var session = GroupSession.init(std.testing.allocator, "session1", activity);
    defer session.deinit();

    try session.join(Participant.init("user1"));
    try session.start();

    try std.testing.expectEqual(SessionState.active, session.state);
    try std.testing.expect(session.started_at != null);
}

test "GroupSession start without join error" {
    const activity = GroupActivity.init("act1", "Test Activity");
    var session = GroupSession.init(std.testing.allocator, "session1", activity);
    defer session.deinit();

    const result = session.start();
    try std.testing.expectError(error.NotJoined, result);
}

test "GroupSession leave" {
    const activity = GroupActivity.init("act1", "Test Activity");
    var session = GroupSession.init(std.testing.allocator, "session1", activity);
    defer session.deinit();

    try session.join(Participant.init("user1"));
    try session.join(Participant.init("user2"));

    try std.testing.expectEqual(@as(usize, 2), session.participantCount());

    session.leave("user1");
    try std.testing.expectEqual(@as(usize, 1), session.participantCount());
}

test "GroupSession leave last participant invalidates" {
    const activity = GroupActivity.init("act1", "Test Activity");
    var session = GroupSession.init(std.testing.allocator, "session1", activity);
    defer session.deinit();

    try session.join(Participant.init("user1"));
    session.leave("user1");

    try std.testing.expectEqual(SessionState.invalidated, session.state);
}

test "GroupSession suspend and resume" {
    const activity = GroupActivity.init("act1", "Test Activity");
    var session = GroupSession.init(std.testing.allocator, "session1", activity);
    defer session.deinit();

    try session.join(Participant.init("user1"));
    try session.start();

    session.suspend_session();
    try std.testing.expectEqual(SessionState.suspended, session.state);

    session.resume_session();
    try std.testing.expectEqual(SessionState.active, session.state);
}

test "GroupSession playback controls" {
    const activity = GroupActivity.init("act1", "Test Activity");
    var session = GroupSession.init(std.testing.allocator, "session1", activity);
    defer session.deinit();

    session.play();
    try std.testing.expect(session.playback_state.is_playing);

    session.pause();
    try std.testing.expect(!session.playback_state.is_playing);
}

test "GroupSession seek" {
    const activity = GroupActivity.init("act1", "Test Activity");
    var session = GroupSession.init(std.testing.allocator, "session1", activity);
    defer session.deinit();

    try session.seek(30000);
    try std.testing.expectEqual(@as(i64, 30000), session.playback_state.position_ms);
}

test "GroupSession createMessage" {
    const activity = GroupActivity.init("act1", "Test Activity");
    var session = GroupSession.init(std.testing.allocator, "session1", activity);
    defer session.deinit();

    session.local_participant_id = "user1";

    const msg1 = session.createMessage("hello");
    try std.testing.expectEqual(@as(u64, 1), msg1.id);

    const msg2 = session.createMessage("world");
    try std.testing.expectEqual(@as(u64, 2), msg2.id);
}

test "EligibilityResult" {
    const eligible = EligibilityResult.eligible();
    try std.testing.expect(eligible.is_eligible);
    try std.testing.expect(eligible.reason == null);

    const not_eligible = EligibilityResult.notEligible(.not_in_facetime);
    try std.testing.expect(!not_eligible.is_eligible);
    try std.testing.expectEqual(EligibilityResult.Reason.not_in_facetime, not_eligible.reason.?);
}

test "SharePlayController init and deinit" {
    var controller = SharePlayController.init(std.testing.allocator);
    defer controller.deinit();

    try std.testing.expectEqual(@as(usize, 0), controller.sessionCount());
}

test "SharePlayController checkEligibility" {
    var controller = SharePlayController.init(std.testing.allocator);
    defer controller.deinit();

    const activity = GroupActivity.init("act1", "Test Activity");
    const result = controller.checkEligibility(activity);

    try std.testing.expect(result.is_eligible);
}

test "SharePlayController prepareActivity" {
    var controller = SharePlayController.init(std.testing.allocator);
    defer controller.deinit();

    const activity = GroupActivity.init("act1", "Test Activity");
    _ = try controller.prepareActivity(activity);

    try std.testing.expectEqual(@as(usize, 1), controller.sessionCount());
}

test "SharePlayController activateSession" {
    var controller = SharePlayController.init(std.testing.allocator);
    defer controller.deinit();

    const activity = GroupActivity.init("act1", "Test Activity");
    const session = try controller.prepareActivity(activity);

    try controller.activateSession(session.id);

    try std.testing.expect(controller.active_session_id != null);
    try std.testing.expectEqual(SessionState.active, session.state);
}

test "SharePlayController endSession" {
    var controller = SharePlayController.init(std.testing.allocator);
    defer controller.deinit();

    const activity = GroupActivity.init("act1", "Test Activity");
    const session = try controller.prepareActivity(activity);
    try controller.activateSession(session.id);

    try controller.endSession(session.id);

    try std.testing.expectEqual(SessionState.invalidated, session.state);
    try std.testing.expect(controller.active_session_id == null);
}

test "SharePlayController addParticipant" {
    var controller = SharePlayController.init(std.testing.allocator);
    defer controller.deinit();

    const activity = GroupActivity.init("act1", "Test Activity");
    const session = try controller.prepareActivity(activity);
    try controller.activateSession(session.id);

    const participant = Participant.init("user2").withName("Guest");
    try controller.addParticipant(session.id, participant);

    try std.testing.expectEqual(@as(usize, 2), session.participantCount());
}

test "SharePlayController sendMessage" {
    var controller = SharePlayController.init(std.testing.allocator);
    defer controller.deinit();

    const activity = GroupActivity.init("act1", "Test Activity");
    const session = try controller.prepareActivity(activity);
    try controller.activateSession(session.id);

    const msg = try controller.sendMessage(session.id, "test payload");
    try std.testing.expectEqualStrings("test payload", msg.payload);
}

test "SharePlayController syncPlayback" {
    var controller = SharePlayController.init(std.testing.allocator);
    defer controller.deinit();

    const activity = GroupActivity.init("act1", "Test Activity");
    const session = try controller.prepareActivity(activity);
    try controller.activateSession(session.id);

    const playback = PlaybackState.playing(5000);
    try controller.syncPlayback(session.id, playback);

    try std.testing.expectEqual(@as(i64, 5000), session.playback_state.position_ms);
}

test "SharePlayController pruneInvalidatedSessions" {
    var controller = SharePlayController.init(std.testing.allocator);
    defer controller.deinit();

    const activity = GroupActivity.init("act1", "Test Activity");
    const session = try controller.prepareActivity(activity);
    try controller.activateSession(session.id);
    try controller.endSession(session.id);

    try std.testing.expectEqual(@as(usize, 1), controller.sessionCount());

    controller.pruneInvalidatedSessions();

    try std.testing.expectEqual(@as(usize, 0), controller.sessionCount());
}

test "SharePlayController event history" {
    var controller = SharePlayController.init(std.testing.allocator);
    defer controller.deinit();

    const activity = GroupActivity.init("act1", "Test Activity");
    const session = try controller.prepareActivity(activity);
    try controller.activateSession(session.id);

    const history = controller.getEventHistory();
    try std.testing.expect(history.len > 0);
    try std.testing.expectEqual(SessionEvent.EventType.session_started, history[0].event_type);
}

test "ActivityType values" {
    try std.testing.expect(ActivityType.media_playback != ActivityType.gaming);
    try std.testing.expect(ActivityType.collaboration != ActivityType.custom);
}

test "SyncMode values" {
    try std.testing.expect(SyncMode.automatic != SyncMode.strict);
    try std.testing.expect(SyncMode.loose != SyncMode.manual);
}
