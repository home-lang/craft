//! Health and Fitness Module for Craft Framework
//!
//! Cross-platform health data access providing:
//! - Step counting and activity tracking
//! - Heart rate and vital signs
//! - Workout sessions
//! - Sleep analysis
//! - Nutrition and hydration
//! - Body measurements
//!
//! Platform implementations:
//! - iOS: HealthKit
//! - Android: Health Connect (Google Fit deprecated)
//! - macOS: HealthKit (limited)
//! - watchOS: HealthKit with real-time data

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Enums
// ============================================================================

pub const AuthorizationStatus = enum {
    not_determined,
    denied,
    authorized,
    sharing_denied,

    pub fn isAuthorized(self: AuthorizationStatus) bool {
        return self == .authorized;
    }

    pub fn toString(self: AuthorizationStatus) []const u8 {
        return switch (self) {
            .not_determined => "not_determined",
            .denied => "denied",
            .authorized => "authorized",
            .sharing_denied => "sharing_denied",
        };
    }
};

pub const HealthDataType = enum {
    steps,
    distance_walking,
    distance_cycling,
    flights_climbed,
    active_energy,
    basal_energy,
    heart_rate,
    resting_heart_rate,
    heart_rate_variability,
    blood_pressure_systolic,
    blood_pressure_diastolic,
    blood_oxygen,
    respiratory_rate,
    body_temperature,
    body_mass,
    body_mass_index,
    body_fat_percentage,
    lean_body_mass,
    height,
    waist_circumference,
    sleep_analysis,
    mindful_session,
    workout,
    water,
    caffeine,
    dietary_energy,
    dietary_protein,
    dietary_carbohydrates,
    dietary_fat,
    blood_glucose,
    insulin_delivery,

    pub fn unit(self: HealthDataType) []const u8 {
        return switch (self) {
            .steps => "count",
            .distance_walking, .distance_cycling => "m",
            .flights_climbed => "count",
            .active_energy, .basal_energy, .dietary_energy => "kcal",
            .heart_rate, .resting_heart_rate => "bpm",
            .heart_rate_variability => "ms",
            .blood_pressure_systolic, .blood_pressure_diastolic => "mmHg",
            .blood_oxygen => "%",
            .respiratory_rate => "breaths/min",
            .body_temperature => "°C",
            .body_mass, .lean_body_mass => "kg",
            .body_mass_index => "kg/m²",
            .body_fat_percentage => "%",
            .height, .waist_circumference => "cm",
            .sleep_analysis => "min",
            .mindful_session => "min",
            .workout => "min",
            .water => "ml",
            .caffeine => "mg",
            .dietary_protein, .dietary_carbohydrates, .dietary_fat => "g",
            .blood_glucose => "mg/dL",
            .insulin_delivery => "IU",
        };
    }

    pub fn toString(self: HealthDataType) []const u8 {
        return switch (self) {
            .steps => "steps",
            .distance_walking => "distance_walking",
            .distance_cycling => "distance_cycling",
            .flights_climbed => "flights_climbed",
            .active_energy => "active_energy",
            .basal_energy => "basal_energy",
            .heart_rate => "heart_rate",
            .resting_heart_rate => "resting_heart_rate",
            .heart_rate_variability => "heart_rate_variability",
            .blood_pressure_systolic => "blood_pressure_systolic",
            .blood_pressure_diastolic => "blood_pressure_diastolic",
            .blood_oxygen => "blood_oxygen",
            .respiratory_rate => "respiratory_rate",
            .body_temperature => "body_temperature",
            .body_mass => "body_mass",
            .body_mass_index => "body_mass_index",
            .body_fat_percentage => "body_fat_percentage",
            .lean_body_mass => "lean_body_mass",
            .height => "height",
            .waist_circumference => "waist_circumference",
            .sleep_analysis => "sleep_analysis",
            .mindful_session => "mindful_session",
            .workout => "workout",
            .water => "water",
            .caffeine => "caffeine",
            .dietary_energy => "dietary_energy",
            .dietary_protein => "dietary_protein",
            .dietary_carbohydrates => "dietary_carbohydrates",
            .dietary_fat => "dietary_fat",
            .blood_glucose => "blood_glucose",
            .insulin_delivery => "insulin_delivery",
        };
    }
};

pub const WorkoutType = enum {
    running,
    walking,
    cycling,
    swimming,
    hiking,
    yoga,
    strength_training,
    hiit,
    dance,
    elliptical,
    rowing,
    stair_climbing,
    pilates,
    martial_arts,
    tennis,
    basketball,
    soccer,
    golf,
    skiing,
    snowboarding,
    surfing,
    other,

    pub fn toString(self: WorkoutType) []const u8 {
        return switch (self) {
            .running => "Running",
            .walking => "Walking",
            .cycling => "Cycling",
            .swimming => "Swimming",
            .hiking => "Hiking",
            .yoga => "Yoga",
            .strength_training => "Strength Training",
            .hiit => "HIIT",
            .dance => "Dance",
            .elliptical => "Elliptical",
            .rowing => "Rowing",
            .stair_climbing => "Stair Climbing",
            .pilates => "Pilates",
            .martial_arts => "Martial Arts",
            .tennis => "Tennis",
            .basketball => "Basketball",
            .soccer => "Soccer",
            .golf => "Golf",
            .skiing => "Skiing",
            .snowboarding => "Snowboarding",
            .surfing => "Surfing",
            .other => "Other",
        };
    }

    pub fn icon(self: WorkoutType) []const u8 {
        return switch (self) {
            .running => "figure.run",
            .walking => "figure.walk",
            .cycling => "bicycle",
            .swimming => "figure.pool.swim",
            .hiking => "figure.hiking",
            .yoga => "figure.yoga",
            .strength_training => "dumbbell.fill",
            .hiit => "flame.fill",
            .dance => "figure.dance",
            .elliptical => "figure.elliptical",
            .rowing => "figure.rower",
            .stair_climbing => "figure.stairs",
            .pilates => "figure.pilates",
            .martial_arts => "figure.martial.arts",
            .tennis => "tennis.racket",
            .basketball => "basketball.fill",
            .soccer => "soccerball",
            .golf => "figure.golf",
            .skiing => "figure.skiing.downhill",
            .snowboarding => "figure.snowboarding",
            .surfing => "figure.surfing",
            .other => "figure.mixed.cardio",
        };
    }
};

pub const SleepStage = enum {
    awake,
    rem,
    core,
    deep,
    unspecified,

    pub fn toString(self: SleepStage) []const u8 {
        return switch (self) {
            .awake => "Awake",
            .rem => "REM",
            .core => "Core",
            .deep => "Deep",
            .unspecified => "Unspecified",
        };
    }

    pub fn qualityScore(self: SleepStage) u8 {
        return switch (self) {
            .awake => 0,
            .rem => 80,
            .core => 60,
            .deep => 100,
            .unspecified => 50,
        };
    }
};

pub const StatisticsOption = enum {
    cumulative_sum,
    discrete_average,
    discrete_min,
    discrete_max,
    most_recent,

    pub fn toString(self: StatisticsOption) []const u8 {
        return switch (self) {
            .cumulative_sum => "cumulative_sum",
            .discrete_average => "discrete_average",
            .discrete_min => "discrete_min",
            .discrete_max => "discrete_max",
            .most_recent => "most_recent",
        };
    }
};

// ============================================================================
// Data Structures
// ============================================================================

pub const HealthSample = struct {
    data_type: HealthDataType,
    value: f64,
    unit: []const u8,
    start_date: i64,
    end_date: i64,
    source_name: ?[]const u8 = null,
    source_bundle_id: ?[]const u8 = null,
    device_name: ?[]const u8 = null,
    metadata: ?[]const u8 = null,

    const Self = @This();

    pub fn duration_ms(self: Self) i64 {
        return self.end_date - self.start_date;
    }

    pub fn durationMinutes(self: Self) f64 {
        return @as(f64, @floatFromInt(self.duration_ms())) / 60000.0;
    }

    pub fn isInstantaneous(self: Self) bool {
        return self.start_date == self.end_date;
    }
};

pub const HealthStatistics = struct {
    data_type: HealthDataType,
    start_date: i64,
    end_date: i64,
    sum: ?f64 = null,
    average: ?f64 = null,
    min: ?f64 = null,
    max: ?f64 = null,
    most_recent: ?f64 = null,
    sample_count: u32 = 0,

    const Self = @This();

    pub fn hasData(self: Self) bool {
        return self.sample_count > 0;
    }
};

pub const Workout = struct {
    id: []const u8 = "",
    workout_type: WorkoutType,
    start_date: i64,
    end_date: i64,
    duration_seconds: f64 = 0,
    total_energy_burned: ?f64 = null,
    total_distance: ?f64 = null,
    average_heart_rate: ?f64 = null,
    max_heart_rate: ?f64 = null,
    total_steps: ?u32 = null,
    elevation_gain: ?f64 = null,
    average_pace: ?f64 = null,
    average_speed: ?f64 = null,
    route_data: ?[]const u8 = null,
    source_name: ?[]const u8 = null,

    const Self = @This();

    pub fn durationMinutes(self: Self) f64 {
        return self.duration_seconds / 60.0;
    }

    pub fn durationFormatted(self: Self, buffer: []u8) []const u8 {
        const total_seconds: u64 = @intFromFloat(self.duration_seconds);
        const hours = total_seconds / 3600;
        const minutes = (total_seconds / 60) % 60;
        const seconds = total_seconds % 60;

        if (hours > 0) {
            return std.fmt.bufPrint(buffer, "{d}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds }) catch "";
        } else {
            return std.fmt.bufPrint(buffer, "{d}:{d:0>2}", .{ minutes, seconds }) catch "";
        }
    }

    pub fn caloriesPerMinute(self: Self) ?f64 {
        if (self.total_energy_burned) |cal| {
            const mins = self.durationMinutes();
            if (mins > 0) return cal / mins;
        }
        return null;
    }
};

pub const SleepSession = struct {
    id: []const u8 = "",
    start_date: i64,
    end_date: i64,
    stages: []SleepSegment = &[_]SleepSegment{},
    time_asleep_seconds: f64 = 0,
    time_awake_seconds: f64 = 0,
    sleep_efficiency: ?f64 = null,
    source_name: ?[]const u8 = null,

    pub const SleepSegment = struct {
        stage: SleepStage,
        start_date: i64,
        end_date: i64,

        pub fn durationMinutes(self: SleepSegment) f64 {
            return @as(f64, @floatFromInt(self.end_date - self.start_date)) / 60000.0;
        }
    };

    const Self = @This();

    pub fn totalDurationMinutes(self: Self) f64 {
        return @as(f64, @floatFromInt(self.end_date - self.start_date)) / 60000.0;
    }

    pub fn timeAsleepMinutes(self: Self) f64 {
        return self.time_asleep_seconds / 60.0;
    }

    pub fn timeAwakeMinutes(self: Self) f64 {
        return self.time_awake_seconds / 60.0;
    }

    pub fn getStageTime(self: Self, stage: SleepStage) f64 {
        var total: f64 = 0;
        for (self.stages) |segment| {
            if (segment.stage == stage) {
                total += segment.durationMinutes();
            }
        }
        return total;
    }

    pub fn getSleepQuality(self: Self) u8 {
        if (self.sleep_efficiency) |eff| {
            if (eff >= 0.9) return 100;
            if (eff >= 0.8) return 80;
            if (eff >= 0.7) return 60;
            if (eff >= 0.6) return 40;
            return 20;
        }
        return 50;
    }
};

pub const ActivitySummary = struct {
    date: i64,
    active_energy_burned: f64 = 0,
    active_energy_goal: f64 = 0,
    exercise_minutes: f64 = 0,
    exercise_goal: f64 = 30,
    stand_hours: u8 = 0,
    stand_goal: u8 = 12,
    steps: u32 = 0,
    steps_goal: u32 = 10000,
    distance: f64 = 0,
    flights_climbed: u16 = 0,

    const Self = @This();

    pub fn energyProgress(self: Self) f32 {
        if (self.active_energy_goal <= 0) return 0;
        return @min(1.0, @as(f32, @floatCast(self.active_energy_burned / self.active_energy_goal)));
    }

    pub fn exerciseProgress(self: Self) f32 {
        if (self.exercise_goal <= 0) return 0;
        return @min(1.0, @as(f32, @floatCast(self.exercise_minutes / self.exercise_goal)));
    }

    pub fn standProgress(self: Self) f32 {
        if (self.stand_goal == 0) return 0;
        return @min(1.0, @as(f32, @floatFromInt(self.stand_hours)) / @as(f32, @floatFromInt(self.stand_goal)));
    }

    pub fn stepsProgress(self: Self) f32 {
        if (self.steps_goal == 0) return 0;
        return @min(1.0, @as(f32, @floatFromInt(self.steps)) / @as(f32, @floatFromInt(self.steps_goal)));
    }

    pub fn allGoalsMet(self: Self) bool {
        return self.energyProgress() >= 1.0 and
            self.exerciseProgress() >= 1.0 and
            self.standProgress() >= 1.0;
    }
};

pub const HeartRateReading = struct {
    value: f64,
    timestamp: i64,
    context: HeartRateContext = .unknown,
    motion_context: ?[]const u8 = null,

    pub const HeartRateContext = enum {
        unknown,
        resting,
        active,
        workout,
        recovery,
        sedentary,

        pub fn toString(self: HeartRateContext) []const u8 {
            return switch (self) {
                .unknown => "Unknown",
                .resting => "Resting",
                .active => "Active",
                .workout => "Workout",
                .recovery => "Recovery",
                .sedentary => "Sedentary",
            };
        }
    };

    const Self = @This();

    pub fn bpm(self: Self) u16 {
        return @intFromFloat(self.value);
    }

    pub fn isElevated(self: Self) bool {
        return self.value > 100;
    }

    pub fn isBradycardia(self: Self) bool {
        return self.value < 60;
    }

    pub fn isTachycardia(self: Self) bool {
        return self.value > 100;
    }
};

pub const QueryOptions = struct {
    start_date: ?i64 = null,
    end_date: ?i64 = null,
    limit: ?u32 = null,
    ascending: bool = true,
    include_manual_entries: bool = true,
    source_bundle_ids: ?[][]const u8 = null,
};

// ============================================================================
// Health Store
// ============================================================================

pub const HealthStore = struct {
    allocator: Allocator,
    authorization_status: std.AutoHashMap(HealthDataType, AuthorizationStatus),
    samples: std.ArrayListUnmanaged(HealthSample) = .{},
    workouts: std.ArrayListUnmanaged(Workout) = .{},
    sleep_sessions: std.ArrayListUnmanaged(SleepSession) = .{},
    event_callback: ?*const fn (HealthEvent) void = null,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .authorization_status = std.AutoHashMap(HealthDataType, AuthorizationStatus).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.authorization_status.deinit();
        self.samples.deinit(self.allocator);
        self.workouts.deinit(self.allocator);
        self.sleep_sessions.deinit(self.allocator);
    }

    pub fn setEventCallback(self: *Self, callback: *const fn (HealthEvent) void) void {
        self.event_callback = callback;
    }

    pub fn isAvailable() bool {
        return true;
    }

    pub fn requestAuthorization(self: *Self, read_types: []const HealthDataType, write_types: []const HealthDataType) !void {
        for (read_types) |data_type| {
            try self.authorization_status.put(data_type, .authorized);
        }
        for (write_types) |data_type| {
            try self.authorization_status.put(data_type, .authorized);
        }
    }

    pub fn getAuthorizationStatus(self: Self, data_type: HealthDataType) AuthorizationStatus {
        return self.authorization_status.get(data_type) orelse .not_determined;
    }

    pub fn isAuthorizedForReading(self: Self, data_type: HealthDataType) bool {
        return self.getAuthorizationStatus(data_type).isAuthorized();
    }

    pub fn writeSample(self: *Self, sample: HealthSample) !void {
        if (!self.isAuthorizedForReading(sample.data_type)) {
            return error.NotAuthorized;
        }
        try self.samples.append(self.allocator, sample);

        if (self.event_callback) |cb| {
            cb(.{ .sample_added = sample });
        }
    }

    pub fn querySamples(self: Self, data_type: HealthDataType, options: QueryOptions) !std.ArrayListUnmanaged(HealthSample) {
        var result: std.ArrayListUnmanaged(HealthSample) = .{};

        for (self.samples.items) |sample| {
            if (sample.data_type != data_type) continue;

            if (options.start_date) |start| {
                if (sample.start_date < start) continue;
            }

            if (options.end_date) |end| {
                if (sample.end_date > end) continue;
            }

            try result.append(self.allocator, sample);

            if (options.limit) |limit| {
                if (result.items.len >= limit) break;
            }
        }

        return result;
    }

    pub fn getStatistics(self: Self, data_type: HealthDataType, start_date: i64, end_date: i64, option: StatisticsOption) !HealthStatistics {
        _ = option;
        var stats = HealthStatistics{
            .data_type = data_type,
            .start_date = start_date,
            .end_date = end_date,
        };

        var sum: f64 = 0;
        var min_val: ?f64 = null;
        var max_val: ?f64 = null;
        var count: u32 = 0;
        var most_recent: ?f64 = null;
        var most_recent_date: i64 = 0;

        for (self.samples.items) |sample| {
            if (sample.data_type != data_type) continue;
            if (sample.start_date < start_date or sample.end_date > end_date) continue;

            sum += sample.value;
            count += 1;

            if (min_val) |m| {
                if (sample.value < m) min_val = sample.value;
            } else {
                min_val = sample.value;
            }

            if (max_val) |m| {
                if (sample.value > m) max_val = sample.value;
            } else {
                max_val = sample.value;
            }

            if (sample.end_date > most_recent_date) {
                most_recent_date = sample.end_date;
                most_recent = sample.value;
            }
        }

        stats.sum = if (count > 0) sum else null;
        stats.average = if (count > 0) sum / @as(f64, @floatFromInt(count)) else null;
        stats.min = min_val;
        stats.max = max_val;
        stats.most_recent = most_recent;
        stats.sample_count = count;

        return stats;
    }

    pub fn saveWorkout(self: *Self, workout: Workout) ![]const u8 {
        const now = getTimestampMs();
        const id = try std.fmt.allocPrint(self.allocator, "workout_{d}", .{now});

        var new_workout = workout;
        new_workout.id = id;

        try self.workouts.append(self.allocator, new_workout);

        if (self.event_callback) |cb| {
            cb(.{ .workout_added = new_workout });
        }

        return id;
    }

    pub fn queryWorkouts(self: Self, options: QueryOptions) []const Workout {
        _ = options;
        return self.workouts.items;
    }

    pub fn saveSleepSession(self: *Self, session: SleepSession) ![]const u8 {
        const now = getTimestampMs();
        const id = try std.fmt.allocPrint(self.allocator, "sleep_{d}", .{now});

        var new_session = session;
        new_session.id = id;

        try self.sleep_sessions.append(self.allocator, new_session);

        if (self.event_callback) |cb| {
            cb(.{ .sleep_added = new_session });
        }

        return id;
    }

    pub fn querySleepSessions(self: Self, options: QueryOptions) []const SleepSession {
        _ = options;
        return self.sleep_sessions.items;
    }

    pub fn getTodayActivitySummary(self: Self) ActivitySummary {
        _ = self;
        return ActivitySummary{
            .date = getTimestampMs(),
        };
    }

    pub fn getStepsToday(self: Self) !u32 {
        const now = getTimestampMs();
        const start_of_day = now - @mod(now, 86400000);

        var total: f64 = 0;
        for (self.samples.items) |sample| {
            if (sample.data_type == .steps and sample.start_date >= start_of_day) {
                total += sample.value;
            }
        }

        return @intFromFloat(total);
    }
};

// ============================================================================
// Workout Builder
// ============================================================================

pub const WorkoutBuilder = struct {
    allocator: Allocator,
    workout: Workout,

    const Self = @This();

    pub fn init(allocator: Allocator, workout_type: WorkoutType, start_date: i64) Self {
        return .{
            .allocator = allocator,
            .workout = .{
                .workout_type = workout_type,
                .start_date = start_date,
                .end_date = start_date,
            },
        };
    }

    pub fn withEndDate(self: *Self, end_date: i64) *Self {
        self.workout.end_date = end_date;
        self.workout.duration_seconds = @as(f64, @floatFromInt(end_date - self.workout.start_date)) / 1000.0;
        return self;
    }

    pub fn withDuration(self: *Self, seconds: f64) *Self {
        self.workout.duration_seconds = seconds;
        self.workout.end_date = self.workout.start_date + @as(i64, @intFromFloat(seconds * 1000));
        return self;
    }

    pub fn withEnergy(self: *Self, calories: f64) *Self {
        self.workout.total_energy_burned = calories;
        return self;
    }

    pub fn withDistance(self: *Self, meters: f64) *Self {
        self.workout.total_distance = meters;
        return self;
    }

    pub fn withHeartRate(self: *Self, average: f64, max: f64) *Self {
        self.workout.average_heart_rate = average;
        self.workout.max_heart_rate = max;
        return self;
    }

    pub fn withSteps(self: *Self, steps: u32) *Self {
        self.workout.total_steps = steps;
        return self;
    }

    pub fn withElevation(self: *Self, gain: f64) *Self {
        self.workout.elevation_gain = gain;
        return self;
    }

    pub fn withSource(self: *Self, name: []const u8) *Self {
        self.workout.source_name = name;
        return self;
    }

    pub fn build(self: Self) Workout {
        return self.workout;
    }
};

// ============================================================================
// Events
// ============================================================================

pub const HealthEvent = union(enum) {
    sample_added: HealthSample,
    workout_added: Workout,
    sleep_added: SleepSession,
    authorization_changed: struct { data_type: HealthDataType, status: AuthorizationStatus },
    background_delivery: HealthDataType,
};

// ============================================================================
// Utility Functions
// ============================================================================

pub fn calculateBMI(weight_kg: f64, height_cm: f64) f64 {
    const height_m = height_cm / 100.0;
    return weight_kg / (height_m * height_m);
}

pub fn getBMICategory(bmi: f64) []const u8 {
    if (bmi < 18.5) return "Underweight";
    if (bmi < 25.0) return "Normal";
    if (bmi < 30.0) return "Overweight";
    return "Obese";
}

pub fn calculateCaloriesBurned(met: f64, weight_kg: f64, duration_hours: f64) f64 {
    return met * weight_kg * duration_hours;
}

pub fn estimateMaxHeartRate(age: u8) u16 {
    return 220 - @as(u16, age);
}

pub fn calculateHeartRateZone(heart_rate: f64, max_heart_rate: f64) u8 {
    const percentage = (heart_rate / max_heart_rate) * 100;
    if (percentage < 50) return 1;
    if (percentage < 60) return 2;
    if (percentage < 70) return 3;
    if (percentage < 80) return 4;
    return 5;
}

pub fn formatDistance(meters: f64, buffer: []u8) []const u8 {
    if (meters >= 1000) {
        return std.fmt.bufPrint(buffer, "{d:.2} km", .{meters / 1000.0}) catch "";
    } else {
        return std.fmt.bufPrint(buffer, "{d:.0} m", .{meters}) catch "";
    }
}

pub fn formatPace(seconds_per_km: f64, buffer: []u8) []const u8 {
    const minutes: u64 = @intFromFloat(seconds_per_km / 60.0);
    const seconds: u64 = @intFromFloat(@mod(seconds_per_km, 60.0));
    return std.fmt.bufPrint(buffer, "{d}:{d:0>2} /km", .{ minutes, seconds }) catch "";
}

fn getTimestampMs() i64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
}

// ============================================================================
// Tests
// ============================================================================

test "AuthorizationStatus isAuthorized" {
    try std.testing.expect(AuthorizationStatus.authorized.isAuthorized());
    try std.testing.expect(!AuthorizationStatus.denied.isAuthorized());
    try std.testing.expect(!AuthorizationStatus.not_determined.isAuthorized());
}

test "HealthDataType unit" {
    try std.testing.expectEqualStrings("count", HealthDataType.steps.unit());
    try std.testing.expectEqualStrings("bpm", HealthDataType.heart_rate.unit());
    try std.testing.expectEqualStrings("kg", HealthDataType.body_mass.unit());
}

test "WorkoutType toString and icon" {
    try std.testing.expectEqualStrings("Running", WorkoutType.running.toString());
    try std.testing.expectEqualStrings("figure.run", WorkoutType.running.icon());
}

test "SleepStage qualityScore" {
    try std.testing.expectEqual(@as(u8, 100), SleepStage.deep.qualityScore());
    try std.testing.expectEqual(@as(u8, 80), SleepStage.rem.qualityScore());
    try std.testing.expectEqual(@as(u8, 0), SleepStage.awake.qualityScore());
}

test "HealthSample duration" {
    const sample = HealthSample{
        .data_type = .steps,
        .value = 1000,
        .unit = "count",
        .start_date = 0,
        .end_date = 3600000,
    };

    try std.testing.expectEqual(@as(i64, 3600000), sample.duration_ms());
    try std.testing.expectEqual(@as(f64, 60.0), sample.durationMinutes());
    try std.testing.expect(!sample.isInstantaneous());
}

test "HealthSample instantaneous" {
    const sample = HealthSample{
        .data_type = .heart_rate,
        .value = 75,
        .unit = "bpm",
        .start_date = 1000,
        .end_date = 1000,
    };

    try std.testing.expect(sample.isInstantaneous());
}

test "HealthStatistics hasData" {
    const stats1 = HealthStatistics{
        .data_type = .steps,
        .start_date = 0,
        .end_date = 1000,
        .sample_count = 5,
    };
    try std.testing.expect(stats1.hasData());

    const stats2 = HealthStatistics{
        .data_type = .steps,
        .start_date = 0,
        .end_date = 1000,
        .sample_count = 0,
    };
    try std.testing.expect(!stats2.hasData());
}

test "Workout durationFormatted" {
    var buffer: [16]u8 = undefined;

    const workout1 = Workout{
        .workout_type = .running,
        .start_date = 0,
        .end_date = 0,
        .duration_seconds = 3661,
    };
    try std.testing.expectEqualStrings("1:01:01", workout1.durationFormatted(&buffer));

    const workout2 = Workout{
        .workout_type = .running,
        .start_date = 0,
        .end_date = 0,
        .duration_seconds = 1830,
    };
    try std.testing.expectEqualStrings("30:30", workout2.durationFormatted(&buffer));
}

test "Workout caloriesPerMinute" {
    const workout = Workout{
        .workout_type = .running,
        .start_date = 0,
        .end_date = 0,
        .duration_seconds = 1800,
        .total_energy_burned = 300,
    };

    const cpm = workout.caloriesPerMinute();
    try std.testing.expect(cpm != null);
    try std.testing.expectEqual(@as(f64, 10.0), cpm.?);
}

test "SleepSession totalDuration" {
    const session = SleepSession{
        .start_date = 0,
        .end_date = 28800000,
    };

    try std.testing.expectEqual(@as(f64, 480.0), session.totalDurationMinutes());
}

test "SleepSession getSleepQuality" {
    const session1 = SleepSession{
        .start_date = 0,
        .end_date = 1000,
        .sleep_efficiency = 0.95,
    };
    try std.testing.expectEqual(@as(u8, 100), session1.getSleepQuality());

    const session2 = SleepSession{
        .start_date = 0,
        .end_date = 1000,
        .sleep_efficiency = 0.75,
    };
    try std.testing.expectEqual(@as(u8, 60), session2.getSleepQuality());
}

test "ActivitySummary progress" {
    const summary = ActivitySummary{
        .date = 0,
        .active_energy_burned = 300,
        .active_energy_goal = 500,
        .exercise_minutes = 20,
        .exercise_goal = 30,
        .stand_hours = 8,
        .stand_goal = 12,
        .steps = 7500,
        .steps_goal = 10000,
    };

    try std.testing.expectEqual(@as(f32, 0.6), summary.energyProgress());
    try std.testing.expect(!summary.allGoalsMet());
}

test "ActivitySummary allGoalsMet" {
    const summary = ActivitySummary{
        .date = 0,
        .active_energy_burned = 600,
        .active_energy_goal = 500,
        .exercise_minutes = 45,
        .exercise_goal = 30,
        .stand_hours = 12,
        .stand_goal = 12,
    };

    try std.testing.expect(summary.allGoalsMet());
}

test "HeartRateReading properties" {
    const reading = HeartRateReading{
        .value = 120,
        .timestamp = 0,
    };

    try std.testing.expectEqual(@as(u16, 120), reading.bpm());
    try std.testing.expect(reading.isElevated());
    try std.testing.expect(reading.isTachycardia());
    try std.testing.expect(!reading.isBradycardia());
}

test "HealthStore initialization" {
    var store = HealthStore.init(std.testing.allocator);
    defer store.deinit();

    try std.testing.expect(HealthStore.isAvailable());
}

test "HealthStore authorization" {
    var store = HealthStore.init(std.testing.allocator);
    defer store.deinit();

    try store.requestAuthorization(&[_]HealthDataType{.steps}, &[_]HealthDataType{});
    try std.testing.expect(store.isAuthorizedForReading(.steps));
    try std.testing.expect(!store.isAuthorizedForReading(.heart_rate));
}

test "HealthStore writeSample" {
    var store = HealthStore.init(std.testing.allocator);
    defer store.deinit();

    try store.requestAuthorization(&[_]HealthDataType{.steps}, &[_]HealthDataType{.steps});

    const sample = HealthSample{
        .data_type = .steps,
        .value = 1000,
        .unit = "count",
        .start_date = 0,
        .end_date = 1000,
    };

    try store.writeSample(sample);
    try std.testing.expectEqual(@as(usize, 1), store.samples.items.len);
}

test "HealthStore querySamples" {
    var store = HealthStore.init(std.testing.allocator);
    defer store.deinit();

    try store.requestAuthorization(&[_]HealthDataType{.steps}, &[_]HealthDataType{.steps});

    try store.writeSample(.{
        .data_type = .steps,
        .value = 500,
        .unit = "count",
        .start_date = 0,
        .end_date = 1000,
    });

    try store.writeSample(.{
        .data_type = .steps,
        .value = 750,
        .unit = "count",
        .start_date = 1000,
        .end_date = 2000,
    });

    var result = try store.querySamples(.steps, .{});
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), result.items.len);
}

test "HealthStore getStatistics" {
    var store = HealthStore.init(std.testing.allocator);
    defer store.deinit();

    try store.requestAuthorization(&[_]HealthDataType{.steps}, &[_]HealthDataType{.steps});

    try store.writeSample(.{ .data_type = .steps, .value = 100, .unit = "count", .start_date = 0, .end_date = 100 });
    try store.writeSample(.{ .data_type = .steps, .value = 200, .unit = "count", .start_date = 100, .end_date = 200 });
    try store.writeSample(.{ .data_type = .steps, .value = 300, .unit = "count", .start_date = 200, .end_date = 300 });

    const stats = try store.getStatistics(.steps, 0, 1000, .cumulative_sum);

    try std.testing.expectEqual(@as(u32, 3), stats.sample_count);
    try std.testing.expectEqual(@as(?f64, 600.0), stats.sum);
    try std.testing.expectEqual(@as(?f64, 200.0), stats.average);
    try std.testing.expectEqual(@as(?f64, 100.0), stats.min);
    try std.testing.expectEqual(@as(?f64, 300.0), stats.max);
}

test "WorkoutBuilder" {
    var builder = WorkoutBuilder.init(std.testing.allocator, .running, 0);
    _ = builder.withDuration(1800).withEnergy(300).withDistance(5000).withHeartRate(145, 175);

    const workout = builder.build();

    try std.testing.expectEqual(WorkoutType.running, workout.workout_type);
    try std.testing.expectEqual(@as(f64, 1800), workout.duration_seconds);
    try std.testing.expectEqual(@as(?f64, 300), workout.total_energy_burned);
    try std.testing.expectEqual(@as(?f64, 5000), workout.total_distance);
}

test "calculateBMI" {
    const bmi = calculateBMI(70, 175);
    try std.testing.expect(bmi > 22.0 and bmi < 23.0);
}

test "getBMICategory" {
    try std.testing.expectEqualStrings("Underweight", getBMICategory(17.0));
    try std.testing.expectEqualStrings("Normal", getBMICategory(22.0));
    try std.testing.expectEqualStrings("Overweight", getBMICategory(27.0));
    try std.testing.expectEqualStrings("Obese", getBMICategory(32.0));
}

test "estimateMaxHeartRate" {
    try std.testing.expectEqual(@as(u16, 190), estimateMaxHeartRate(30));
    try std.testing.expectEqual(@as(u16, 180), estimateMaxHeartRate(40));
}

test "calculateHeartRateZone" {
    try std.testing.expectEqual(@as(u8, 1), calculateHeartRateZone(80, 190));
    try std.testing.expectEqual(@as(u8, 3), calculateHeartRateZone(130, 190));
    try std.testing.expectEqual(@as(u8, 5), calculateHeartRateZone(170, 190));
}

test "formatDistance" {
    var buffer: [32]u8 = undefined;

    try std.testing.expectEqualStrings("500 m", formatDistance(500, &buffer));
    try std.testing.expectEqualStrings("5.00 km", formatDistance(5000, &buffer));
}

test "formatPace" {
    var buffer: [32]u8 = undefined;
    try std.testing.expectEqualStrings("5:30 /km", formatPace(330, &buffer));
}

test "StatisticsOption toString" {
    try std.testing.expectEqualStrings("cumulative_sum", StatisticsOption.cumulative_sum.toString());
    try std.testing.expectEqualStrings("discrete_average", StatisticsOption.discrete_average.toString());
}

test "HeartRateContext toString" {
    try std.testing.expectEqualStrings("Resting", HeartRateReading.HeartRateContext.resting.toString());
    try std.testing.expectEqualStrings("Workout", HeartRateReading.HeartRateContext.workout.toString());
}
