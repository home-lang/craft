//! Game services support for Craft
//! Provides cross-platform abstractions for Game Center (iOS/macOS), Google Play Games,
//! Steam, and other gaming platforms. Covers achievements, leaderboards, and multiplayer.

const std = @import("std");

/// Game service provider
pub const GameProvider = enum {
    game_center,
    google_play,
    steam,
    xbox_live,
    playstation,
    epic,
    gog,
    unknown,

    pub fn toString(self: GameProvider) []const u8 {
        return switch (self) {
            .game_center => "Game Center",
            .google_play => "Google Play Games",
            .steam => "Steam",
            .xbox_live => "Xbox Live",
            .playstation => "PlayStation Network",
            .epic => "Epic Games",
            .gog => "GOG Galaxy",
            .unknown => "Unknown",
        };
    }

    pub fn supportsAchievements(self: GameProvider) bool {
        return self != .unknown;
    }

    pub fn supportsLeaderboards(self: GameProvider) bool {
        return self != .unknown;
    }

    pub fn supportsMultiplayer(self: GameProvider) bool {
        return switch (self) {
            .game_center, .google_play, .steam, .xbox_live, .playstation, .epic => true,
            .gog, .unknown => false,
        };
    }

    pub fn supportsCloudSave(self: GameProvider) bool {
        return switch (self) {
            .game_center, .google_play, .steam, .xbox_live, .playstation, .epic, .gog => true,
            .unknown => false,
        };
    }
};

/// Authentication state
pub const AuthState = enum {
    not_authenticated,
    authenticating,
    authenticated,
    auth_failed,
    restricted,

    pub fn isSignedIn(self: AuthState) bool {
        return self == .authenticated;
    }

    pub fn canRetry(self: AuthState) bool {
        return self == .not_authenticated or self == .auth_failed;
    }

    pub fn toString(self: AuthState) []const u8 {
        return switch (self) {
            .not_authenticated => "Not Authenticated",
            .authenticating => "Authenticating",
            .authenticated => "Authenticated",
            .auth_failed => "Authentication Failed",
            .restricted => "Restricted",
        };
    }
};

/// Player information
pub const Player = struct {
    player_id: []const u8,
    display_name: []const u8,
    alias: []const u8,
    avatar_url: ?[]const u8,
    is_local: bool,

    pub fn init(player_id: []const u8, display_name: []const u8) Player {
        return .{
            .player_id = player_id,
            .display_name = display_name,
            .alias = display_name,
            .avatar_url = null,
            .is_local = true,
        };
    }

    pub fn withAlias(self: Player, alias: []const u8) Player {
        var player = self;
        player.alias = alias;
        return player;
    }

    pub fn withAvatar(self: Player, url: []const u8) Player {
        var player = self;
        player.avatar_url = url;
        return player;
    }

    pub fn asRemote(self: Player) Player {
        var player = self;
        player.is_local = false;
        return player;
    }
};

/// Achievement state
pub const AchievementState = enum {
    locked,
    in_progress,
    unlocked,
    hidden,

    pub fn isUnlocked(self: AchievementState) bool {
        return self == .unlocked;
    }

    pub fn isVisible(self: AchievementState) bool {
        return self != .hidden;
    }

    pub fn toString(self: AchievementState) []const u8 {
        return switch (self) {
            .locked => "Locked",
            .in_progress => "In Progress",
            .unlocked => "Unlocked",
            .hidden => "Hidden",
        };
    }
};

/// Achievement type
pub const AchievementType = enum {
    standard,
    incremental,
    hidden,
    rare,

    pub fn toString(self: AchievementType) []const u8 {
        return switch (self) {
            .standard => "Standard",
            .incremental => "Incremental",
            .hidden => "Hidden",
            .rare => "Rare",
        };
    }

    pub fn supportsProgress(self: AchievementType) bool {
        return self == .incremental;
    }
};

/// Achievement definition
pub const Achievement = struct {
    achievement_id: []const u8,
    title: []const u8,
    description: []const u8,
    achievement_type: AchievementType,
    points: u32,
    state: AchievementState,
    progress: f32,
    unlock_timestamp: ?u64,

    pub fn init(achievement_id: []const u8, title: []const u8) Achievement {
        return .{
            .achievement_id = achievement_id,
            .title = title,
            .description = "",
            .achievement_type = .standard,
            .points = 10,
            .state = .locked,
            .progress = 0,
            .unlock_timestamp = null,
        };
    }

    pub fn withDescription(self: Achievement, description: []const u8) Achievement {
        var achievement = self;
        achievement.description = description;
        return achievement;
    }

    pub fn withPoints(self: Achievement, points: u32) Achievement {
        var achievement = self;
        achievement.points = points;
        return achievement;
    }

    pub fn withType(self: Achievement, achievement_type: AchievementType) Achievement {
        var achievement = self;
        achievement.achievement_type = achievement_type;
        return achievement;
    }

    pub fn unlock(self: *Achievement) void {
        self.state = .unlocked;
        self.progress = 100.0;
        self.unlock_timestamp = getCurrentTimestamp();
    }

    pub fn setProgress(self: *Achievement, progress: f32) void {
        self.progress = @min(100.0, @max(0.0, progress));
        if (self.progress > 0 and self.progress < 100.0) {
            self.state = .in_progress;
        } else if (self.progress >= 100.0) {
            self.unlock();
        }
    }

    pub fn isUnlocked(self: Achievement) bool {
        return self.state.isUnlocked();
    }

    pub fn progressPercent(self: Achievement) f32 {
        return self.progress;
    }
};

/// Leaderboard time scope
pub const TimeScope = enum {
    today,
    week,
    all_time,

    pub fn toString(self: TimeScope) []const u8 {
        return switch (self) {
            .today => "Today",
            .week => "This Week",
            .all_time => "All Time",
        };
    }
};

/// Leaderboard player scope
pub const PlayerScope = enum {
    global,
    friends,

    pub fn toString(self: PlayerScope) []const u8 {
        return switch (self) {
            .global => "Global",
            .friends => "Friends",
        };
    }
};

/// Score format type
pub const ScoreFormat = enum {
    integer,
    fixed_point_1,
    fixed_point_2,
    fixed_point_3,
    time_seconds,
    time_centiseconds,
    time_milliseconds,
    money,

    pub fn format(self: ScoreFormat, value: i64, buf: []u8) []const u8 {
        const result = switch (self) {
            .integer => std.fmt.bufPrint(buf, "{d}", .{value}),
            .fixed_point_1 => std.fmt.bufPrint(buf, "{d}.{d}", .{ @divTrunc(value, 10), @mod(@abs(value), 10) }),
            .fixed_point_2 => std.fmt.bufPrint(buf, "{d}.{d:0>2}", .{ @divTrunc(value, 100), @mod(@abs(value), 100) }),
            .fixed_point_3 => std.fmt.bufPrint(buf, "{d}.{d:0>3}", .{ @divTrunc(value, 1000), @mod(@abs(value), 1000) }),
            .time_seconds => std.fmt.bufPrint(buf, "{d}:{d:0>2}", .{ @divTrunc(value, 60), @mod(@abs(value), 60) }),
            .time_centiseconds => std.fmt.bufPrint(buf, "{d}.{d:0>2}s", .{ @divTrunc(value, 100), @mod(@abs(value), 100) }),
            .time_milliseconds => std.fmt.bufPrint(buf, "{d}.{d:0>3}s", .{ @divTrunc(value, 1000), @mod(@abs(value), 1000) }),
            .money => std.fmt.bufPrint(buf, "${d}.{d:0>2}", .{ @divTrunc(value, 100), @mod(@abs(value), 100) }),
        };
        return result catch buf[0..0];
    }
};

/// Score order
pub const ScoreOrder = enum {
    higher_is_better,
    lower_is_better,

    pub fn compare(self: ScoreOrder, a: i64, b: i64) bool {
        return switch (self) {
            .higher_is_better => a > b,
            .lower_is_better => a < b,
        };
    }
};

/// Leaderboard entry
pub const LeaderboardEntry = struct {
    player: Player,
    rank: u32,
    score: i64,
    formatted_score: []const u8,
    timestamp: u64,

    pub fn init(player: Player, rank: u32, score: i64) LeaderboardEntry {
        return .{
            .player = player,
            .rank = rank,
            .score = score,
            .formatted_score = "",
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withFormattedScore(self: LeaderboardEntry, formatted: []const u8) LeaderboardEntry {
        var entry = self;
        entry.formatted_score = formatted;
        return entry;
    }
};

/// Leaderboard definition
pub const Leaderboard = struct {
    leaderboard_id: []const u8,
    title: []const u8,
    score_format: ScoreFormat,
    score_order: ScoreOrder,
    entry_count: u32,
    local_player_rank: ?u32,
    local_player_score: ?i64,

    pub fn init(leaderboard_id: []const u8, title: []const u8) Leaderboard {
        return .{
            .leaderboard_id = leaderboard_id,
            .title = title,
            .score_format = .integer,
            .score_order = .higher_is_better,
            .entry_count = 0,
            .local_player_rank = null,
            .local_player_score = null,
        };
    }

    pub fn withScoreFormat(self: Leaderboard, format: ScoreFormat) Leaderboard {
        var lb = self;
        lb.score_format = format;
        return lb;
    }

    pub fn withScoreOrder(self: Leaderboard, order: ScoreOrder) Leaderboard {
        var lb = self;
        lb.score_order = order;
        return lb;
    }

    pub fn setLocalPlayerScore(self: *Leaderboard, rank: u32, score: i64) void {
        self.local_player_rank = rank;
        self.local_player_score = score;
    }

    pub fn hasLocalPlayerEntry(self: Leaderboard) bool {
        return self.local_player_rank != null;
    }
};

/// Multiplayer match state
pub const MatchState = enum {
    pending,
    matching,
    matched,
    active,
    completed,
    cancelled,
    timeout,

    pub fn isActive(self: MatchState) bool {
        return self == .active;
    }

    pub fn isFinished(self: MatchState) bool {
        return self == .completed or self == .cancelled or self == .timeout;
    }

    pub fn toString(self: MatchState) []const u8 {
        return switch (self) {
            .pending => "Pending",
            .matching => "Matching",
            .matched => "Matched",
            .active => "Active",
            .completed => "Completed",
            .cancelled => "Cancelled",
            .timeout => "Timeout",
        };
    }
};

/// Match type
pub const MatchType = enum {
    real_time,
    turn_based,
    async_match,

    pub fn toString(self: MatchType) []const u8 {
        return switch (self) {
            .real_time => "Real-Time",
            .turn_based => "Turn-Based",
            .async_match => "Async",
        };
    }

    pub fn requiresRealTimeConnection(self: MatchType) bool {
        return self == .real_time;
    }
};

/// Match request configuration
pub const MatchRequest = struct {
    min_players: u32,
    max_players: u32,
    match_type: MatchType,
    player_group: u32,
    player_attributes: u32,

    pub fn init(min_players: u32, max_players: u32) MatchRequest {
        return .{
            .min_players = min_players,
            .max_players = max_players,
            .match_type = .real_time,
            .player_group = 0,
            .player_attributes = 0,
        };
    }

    pub fn withMatchType(self: MatchRequest, match_type: MatchType) MatchRequest {
        var request = self;
        request.match_type = match_type;
        return request;
    }

    pub fn withPlayerGroup(self: MatchRequest, group: u32) MatchRequest {
        var request = self;
        request.player_group = group;
        return request;
    }

    pub fn isValid(self: MatchRequest) bool {
        return self.min_players >= 2 and self.max_players >= self.min_players;
    }
};

/// Multiplayer match
pub const Match = struct {
    match_id: []const u8,
    state: MatchState,
    match_type: MatchType,
    player_count: u32,
    max_players: u32,
    current_turn: ?[]const u8,
    created_at: u64,

    pub fn init(match_id: []const u8, match_type: MatchType, max_players: u32) Match {
        return .{
            .match_id = match_id,
            .state = .pending,
            .match_type = match_type,
            .player_count = 0,
            .max_players = max_players,
            .current_turn = null,
            .created_at = getCurrentTimestamp(),
        };
    }

    pub fn start(self: *Match) void {
        self.state = .active;
    }

    pub fn complete(self: *Match) void {
        self.state = .completed;
    }

    pub fn cancel(self: *Match) void {
        self.state = .cancelled;
    }

    pub fn addPlayer(self: *Match) bool {
        if (self.player_count >= self.max_players) return false;
        self.player_count += 1;
        return true;
    }

    pub fn removePlayer(self: *Match) bool {
        if (self.player_count == 0) return false;
        self.player_count -= 1;
        return true;
    }

    pub fn isFull(self: Match) bool {
        return self.player_count >= self.max_players;
    }

    pub fn isActive(self: Match) bool {
        return self.state.isActive();
    }
};

/// Challenge type
pub const ChallengeType = enum {
    score,
    achievement,
    custom,

    pub fn toString(self: ChallengeType) []const u8 {
        return switch (self) {
            .score => "Score Challenge",
            .achievement => "Achievement Challenge",
            .custom => "Custom Challenge",
        };
    }
};

/// Challenge state
pub const ChallengeState = enum {
    pending,
    accepted,
    declined,
    completed,
    expired,

    pub fn isActive(self: ChallengeState) bool {
        return self == .pending or self == .accepted;
    }

    pub fn toString(self: ChallengeState) []const u8 {
        return switch (self) {
            .pending => "Pending",
            .accepted => "Accepted",
            .declined => "Declined",
            .completed => "Completed",
            .expired => "Expired",
        };
    }
};

/// Game challenge
pub const Challenge = struct {
    challenge_id: []const u8,
    challenger: Player,
    recipient: Player,
    challenge_type: ChallengeType,
    state: ChallengeState,
    target_value: i64,
    current_value: i64,
    expires_at: u64,

    pub fn init(challenge_id: []const u8, challenger: Player, recipient: Player) Challenge {
        return .{
            .challenge_id = challenge_id,
            .challenger = challenger,
            .recipient = recipient,
            .challenge_type = .score,
            .state = .pending,
            .target_value = 0,
            .current_value = 0,
            .expires_at = getCurrentTimestamp() + 86400000, // 24 hours
        };
    }

    pub fn withTargetValue(self: Challenge, target: i64) Challenge {
        var challenge = self;
        challenge.target_value = target;
        return challenge;
    }

    pub fn withChallengeType(self: Challenge, challenge_type: ChallengeType) Challenge {
        var challenge = self;
        challenge.challenge_type = challenge_type;
        return challenge;
    }

    pub fn accept(self: *Challenge) void {
        self.state = .accepted;
    }

    pub fn decline(self: *Challenge) void {
        self.state = .declined;
    }

    pub fn updateProgress(self: *Challenge, value: i64) void {
        self.current_value = value;
        if (self.current_value >= self.target_value) {
            self.state = .completed;
        }
    }

    pub fn isExpired(self: Challenge) bool {
        return getCurrentTimestamp() >= self.expires_at;
    }

    pub fn progressPercent(self: Challenge) f32 {
        if (self.target_value == 0) return 0;
        return @as(f32, @floatFromInt(self.current_value)) / @as(f32, @floatFromInt(self.target_value)) * 100.0;
    }
};

/// Cloud save conflict resolution
pub const ConflictResolution = enum {
    use_local,
    use_remote,
    merge,
    manual,

    pub fn toString(self: ConflictResolution) []const u8 {
        return switch (self) {
            .use_local => "Use Local",
            .use_remote => "Use Remote",
            .merge => "Merge",
            .manual => "Manual Resolution",
        };
    }
};

/// Save game metadata
pub const SaveGameMetadata = struct {
    slot_name: []const u8,
    description: []const u8,
    play_time_seconds: u64,
    progress_value: i64,
    modified_at: u64,
    data_size: u64,

    pub fn init(slot_name: []const u8) SaveGameMetadata {
        return .{
            .slot_name = slot_name,
            .description = "",
            .play_time_seconds = 0,
            .progress_value = 0,
            .modified_at = getCurrentTimestamp(),
            .data_size = 0,
        };
    }

    pub fn withDescription(self: SaveGameMetadata, description: []const u8) SaveGameMetadata {
        var meta = self;
        meta.description = description;
        return meta;
    }

    pub fn withPlayTime(self: SaveGameMetadata, seconds: u64) SaveGameMetadata {
        var meta = self;
        meta.play_time_seconds = seconds;
        return meta;
    }

    pub fn withProgress(self: SaveGameMetadata, progress: i64) SaveGameMetadata {
        var meta = self;
        meta.progress_value = progress;
        return meta;
    }

    pub fn playTimeFormatted(self: SaveGameMetadata) struct { hours: u64, minutes: u64 } {
        return .{
            .hours = self.play_time_seconds / 3600,
            .minutes = (self.play_time_seconds % 3600) / 60,
        };
    }
};

/// Game services controller
pub const GameServicesController = struct {
    provider: GameProvider,
    auth_state: AuthState,
    local_player: ?Player,
    achievement_count: u32,
    unlocked_count: u32,
    total_score: i64,

    pub fn init(provider: GameProvider) GameServicesController {
        return .{
            .provider = provider,
            .auth_state = .not_authenticated,
            .local_player = null,
            .achievement_count = 0,
            .unlocked_count = 0,
            .total_score = 0,
        };
    }

    pub fn authenticate(self: *GameServicesController) void {
        self.auth_state = .authenticating;
    }

    pub fn onAuthSuccess(self: *GameServicesController, player: Player) void {
        self.auth_state = .authenticated;
        self.local_player = player;
    }

    pub fn onAuthFailure(self: *GameServicesController) void {
        self.auth_state = .auth_failed;
        self.local_player = null;
    }

    pub fn signOut(self: *GameServicesController) void {
        self.auth_state = .not_authenticated;
        self.local_player = null;
    }

    pub fn isSignedIn(self: GameServicesController) bool {
        return self.auth_state.isSignedIn();
    }

    pub fn unlockAchievement(self: *GameServicesController, points: u32) void {
        self.unlocked_count += 1;
        self.total_score += points;
    }

    pub fn completionPercent(self: GameServicesController) f32 {
        if (self.achievement_count == 0) return 0;
        return @as(f32, @floatFromInt(self.unlocked_count)) / @as(f32, @floatFromInt(self.achievement_count)) * 100.0;
    }

    pub fn setAchievementCount(self: *GameServicesController, count: u32) void {
        self.achievement_count = count;
    }
};

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() u64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        const ms = @divTrunc(ts.nsec, 1_000_000);
        return @intCast(@as(i128, ts.sec) * 1000 + ms);
    }
    return 0;
}

/// Get current game provider based on platform
pub fn currentProvider() GameProvider {
    return .unknown; // Would use runtime detection
}

/// Check if game services are available
pub fn isAvailable() bool {
    return currentProvider() != .unknown;
}

// ============================================================================
// Tests
// ============================================================================

test "GameProvider properties" {
    try std.testing.expect(GameProvider.game_center.supportsAchievements());
    try std.testing.expect(GameProvider.steam.supportsLeaderboards());
    try std.testing.expect(GameProvider.game_center.supportsMultiplayer());
    try std.testing.expect(!GameProvider.gog.supportsMultiplayer());
    try std.testing.expect(GameProvider.steam.supportsCloudSave());
}

test "GameProvider toString" {
    try std.testing.expectEqualStrings("Game Center", GameProvider.game_center.toString());
    try std.testing.expectEqualStrings("Steam", GameProvider.steam.toString());
    try std.testing.expectEqualStrings("Google Play Games", GameProvider.google_play.toString());
}

test "AuthState properties" {
    try std.testing.expect(AuthState.authenticated.isSignedIn());
    try std.testing.expect(!AuthState.not_authenticated.isSignedIn());
    try std.testing.expect(AuthState.not_authenticated.canRetry());
    try std.testing.expect(AuthState.auth_failed.canRetry());
    try std.testing.expect(!AuthState.authenticated.canRetry());
}

test "Player creation" {
    const player = Player.init("player123", "TestPlayer")
        .withAlias("Test")
        .withAvatar("https://example.com/avatar.png");

    try std.testing.expectEqualStrings("player123", player.player_id);
    try std.testing.expectEqualStrings("TestPlayer", player.display_name);
    try std.testing.expectEqualStrings("Test", player.alias);
    try std.testing.expect(player.is_local);
}

test "Player asRemote" {
    const player = Player.init("p1", "Player1").asRemote();
    try std.testing.expect(!player.is_local);
}

test "AchievementState properties" {
    try std.testing.expect(AchievementState.unlocked.isUnlocked());
    try std.testing.expect(!AchievementState.locked.isUnlocked());
    try std.testing.expect(AchievementState.locked.isVisible());
    try std.testing.expect(!AchievementState.hidden.isVisible());
}

test "AchievementType properties" {
    try std.testing.expect(AchievementType.incremental.supportsProgress());
    try std.testing.expect(!AchievementType.standard.supportsProgress());
}

test "Achievement creation" {
    const achievement = Achievement.init("ach_001", "First Steps")
        .withDescription("Complete the tutorial")
        .withPoints(25)
        .withType(.standard);

    try std.testing.expectEqualStrings("ach_001", achievement.achievement_id);
    try std.testing.expectEqualStrings("First Steps", achievement.title);
    try std.testing.expectEqual(@as(u32, 25), achievement.points);
    try std.testing.expectEqual(AchievementState.locked, achievement.state);
}

test "Achievement unlock" {
    var achievement = Achievement.init("ach_002", "Test");
    try std.testing.expect(!achievement.isUnlocked());

    achievement.unlock();
    try std.testing.expect(achievement.isUnlocked());
    try std.testing.expect(achievement.progress >= 100.0);
    try std.testing.expect(achievement.unlock_timestamp != null);
}

test "Achievement progress" {
    var achievement = Achievement.init("ach_003", "Progressive")
        .withType(.incremental);

    achievement.setProgress(50.0);
    try std.testing.expectEqual(AchievementState.in_progress, achievement.state);
    try std.testing.expect(achievement.progressPercent() > 49.9);

    achievement.setProgress(100.0);
    try std.testing.expect(achievement.isUnlocked());
}

test "TimeScope and PlayerScope" {
    try std.testing.expectEqualStrings("Today", TimeScope.today.toString());
    try std.testing.expectEqualStrings("All Time", TimeScope.all_time.toString());
    try std.testing.expectEqualStrings("Global", PlayerScope.global.toString());
    try std.testing.expectEqualStrings("Friends", PlayerScope.friends.toString());
}

test "ScoreFormat integer" {
    var buf: [64]u8 = undefined;
    const result = ScoreFormat.integer.format(12345, &buf);
    try std.testing.expectEqualStrings("12345", result);
}

test "ScoreFormat fixed point" {
    var buf: [64]u8 = undefined;
    const result = ScoreFormat.fixed_point_2.format(12345, &buf);
    try std.testing.expectEqualStrings("123.45", result);
}

test "ScoreOrder compare" {
    try std.testing.expect(ScoreOrder.higher_is_better.compare(100, 50));
    try std.testing.expect(!ScoreOrder.higher_is_better.compare(50, 100));
    try std.testing.expect(ScoreOrder.lower_is_better.compare(50, 100));
}

test "LeaderboardEntry creation" {
    const player = Player.init("p1", "Player1");
    const entry = LeaderboardEntry.init(player, 1, 50000)
        .withFormattedScore("50,000");

    try std.testing.expectEqual(@as(u32, 1), entry.rank);
    try std.testing.expectEqual(@as(i64, 50000), entry.score);
    try std.testing.expectEqualStrings("50,000", entry.formatted_score);
}

test "Leaderboard creation" {
    const lb = Leaderboard.init("lb_highscore", "High Scores")
        .withScoreFormat(.integer)
        .withScoreOrder(.higher_is_better);

    try std.testing.expectEqualStrings("lb_highscore", lb.leaderboard_id);
    try std.testing.expect(!lb.hasLocalPlayerEntry());
}

test "Leaderboard local player" {
    var lb = Leaderboard.init("lb_test", "Test");
    lb.setLocalPlayerScore(5, 25000);

    try std.testing.expect(lb.hasLocalPlayerEntry());
    try std.testing.expectEqual(@as(?u32, 5), lb.local_player_rank);
    try std.testing.expectEqual(@as(?i64, 25000), lb.local_player_score);
}

test "MatchState properties" {
    try std.testing.expect(MatchState.active.isActive());
    try std.testing.expect(!MatchState.pending.isActive());
    try std.testing.expect(MatchState.completed.isFinished());
    try std.testing.expect(MatchState.cancelled.isFinished());
    try std.testing.expect(!MatchState.active.isFinished());
}

test "MatchType properties" {
    try std.testing.expect(MatchType.real_time.requiresRealTimeConnection());
    try std.testing.expect(!MatchType.turn_based.requiresRealTimeConnection());
}

test "MatchRequest creation" {
    const request = MatchRequest.init(2, 4)
        .withMatchType(.turn_based)
        .withPlayerGroup(1);

    try std.testing.expectEqual(@as(u32, 2), request.min_players);
    try std.testing.expectEqual(@as(u32, 4), request.max_players);
    try std.testing.expect(request.isValid());
}

test "MatchRequest invalid" {
    const request = MatchRequest.init(1, 4); // min_players < 2
    try std.testing.expect(!request.isValid());
}

test "Match creation" {
    var game_match = Match.init("match123", .real_time, 4);
    try std.testing.expectEqual(MatchState.pending, game_match.state);
    try std.testing.expectEqual(@as(u32, 0), game_match.player_count);
}

test "Match player management" {
    var game_match = Match.init("match456", .turn_based, 2);

    try std.testing.expect(game_match.addPlayer());
    try std.testing.expectEqual(@as(u32, 1), game_match.player_count);

    try std.testing.expect(game_match.addPlayer());
    try std.testing.expect(game_match.isFull());

    try std.testing.expect(!game_match.addPlayer()); // Can't add more

    try std.testing.expect(game_match.removePlayer());
    try std.testing.expect(!game_match.isFull());
}

test "Match lifecycle" {
    var game_match = Match.init("match789", .real_time, 2);

    game_match.start();
    try std.testing.expect(game_match.isActive());

    game_match.complete();
    try std.testing.expectEqual(MatchState.completed, game_match.state);
}

test "ChallengeType and ChallengeState" {
    try std.testing.expectEqualStrings("Score Challenge", ChallengeType.score.toString());
    try std.testing.expect(ChallengeState.pending.isActive());
    try std.testing.expect(ChallengeState.accepted.isActive());
    try std.testing.expect(!ChallengeState.completed.isActive());
}

test "Challenge creation" {
    const challenger = Player.init("p1", "Challenger");
    const recipient = Player.init("p2", "Recipient");
    const challenge = Challenge.init("ch001", challenger, recipient)
        .withTargetValue(1000)
        .withChallengeType(.score);

    try std.testing.expectEqualStrings("ch001", challenge.challenge_id);
    try std.testing.expectEqual(@as(i64, 1000), challenge.target_value);
    try std.testing.expectEqual(ChallengeState.pending, challenge.state);
}

test "Challenge progress" {
    const challenger = Player.init("p1", "C");
    const recipient = Player.init("p2", "R");
    var challenge = Challenge.init("ch002", challenger, recipient)
        .withTargetValue(100);

    challenge.accept();
    try std.testing.expectEqual(ChallengeState.accepted, challenge.state);

    challenge.updateProgress(50);
    try std.testing.expect(challenge.progressPercent() > 49.9);

    challenge.updateProgress(100);
    try std.testing.expectEqual(ChallengeState.completed, challenge.state);
}

test "SaveGameMetadata creation" {
    const meta = SaveGameMetadata.init("save_slot_1")
        .withDescription("Level 5 - Forest")
        .withPlayTime(7265)
        .withProgress(50);

    try std.testing.expectEqualStrings("save_slot_1", meta.slot_name);
    try std.testing.expectEqualStrings("Level 5 - Forest", meta.description);

    const time = meta.playTimeFormatted();
    try std.testing.expectEqual(@as(u64, 2), time.hours);
    try std.testing.expectEqual(@as(u64, 1), time.minutes);
}

test "GameServicesController init" {
    const controller = GameServicesController.init(.game_center);
    try std.testing.expectEqual(GameProvider.game_center, controller.provider);
    try std.testing.expectEqual(AuthState.not_authenticated, controller.auth_state);
    try std.testing.expect(!controller.isSignedIn());
}

test "GameServicesController auth flow" {
    var controller = GameServicesController.init(.steam);

    controller.authenticate();
    try std.testing.expectEqual(AuthState.authenticating, controller.auth_state);

    const player = Player.init("steam_123", "SteamUser");
    controller.onAuthSuccess(player);
    try std.testing.expect(controller.isSignedIn());
    try std.testing.expect(controller.local_player != null);

    controller.signOut();
    try std.testing.expect(!controller.isSignedIn());
    try std.testing.expect(controller.local_player == null);
}

test "GameServicesController achievements" {
    var controller = GameServicesController.init(.google_play);
    controller.setAchievementCount(10);

    controller.unlockAchievement(25);
    controller.unlockAchievement(50);

    try std.testing.expectEqual(@as(u32, 2), controller.unlocked_count);
    try std.testing.expectEqual(@as(i64, 75), controller.total_score);
    try std.testing.expect(controller.completionPercent() > 19.9);
}

test "currentProvider" {
    const provider = currentProvider();
    try std.testing.expectEqual(GameProvider.unknown, provider);
}

test "isAvailable" {
    try std.testing.expect(!isAvailable());
}
