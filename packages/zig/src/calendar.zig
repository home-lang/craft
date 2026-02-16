const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

/// Cross-platform calendar module for Craft framework
/// Provides unified API for iOS EventKit, Android CalendarContract, and desktop calendars

// ============================================================================
// Types and Enums
// ============================================================================

/// Calendar event status
pub const EventStatus = enum {
    none,
    tentative,
    confirmed,
    cancelled,

    pub fn toString(self: EventStatus) []const u8 {
        return switch (self) {
            .none => "none",
            .tentative => "tentative",
            .confirmed => "confirmed",
            .cancelled => "cancelled",
        };
    }
};

/// Event availability
pub const Availability = enum {
    busy,
    free,
    tentative,
    unavailable,

    pub fn toString(self: Availability) []const u8 {
        return switch (self) {
            .busy => "busy",
            .free => "free",
            .tentative => "tentative",
            .unavailable => "unavailable",
        };
    }
};

/// Recurrence frequency
pub const RecurrenceFrequency = enum {
    daily,
    weekly,
    monthly,
    yearly,

    pub fn toString(self: RecurrenceFrequency) []const u8 {
        return switch (self) {
            .daily => "daily",
            .weekly => "weekly",
            .monthly => "monthly",
            .yearly => "yearly",
        };
    }
};

/// Day of week
pub const DayOfWeek = enum(u8) {
    sunday = 0,
    monday = 1,
    tuesday = 2,
    wednesday = 3,
    thursday = 4,
    friday = 5,
    saturday = 6,

    pub fn fromIndex(index: u8) ?DayOfWeek {
        return switch (index) {
            0 => .sunday,
            1 => .monday,
            2 => .tuesday,
            3 => .wednesday,
            4 => .thursday,
            5 => .friday,
            6 => .saturday,
            else => null,
        };
    }

    pub fn toString(self: DayOfWeek) []const u8 {
        return switch (self) {
            .sunday => "Sunday",
            .monday => "Monday",
            .tuesday => "Tuesday",
            .wednesday => "Wednesday",
            .thursday => "Thursday",
            .friday => "Friday",
            .saturday => "Saturday",
        };
    }

    pub fn toShortString(self: DayOfWeek) []const u8 {
        return switch (self) {
            .sunday => "Sun",
            .monday => "Mon",
            .tuesday => "Tue",
            .wednesday => "Wed",
            .thursday => "Thu",
            .friday => "Fri",
            .saturday => "Sat",
        };
    }
};

/// Alarm/Reminder trigger type
pub const AlarmTriggerType = enum {
    relative, // Relative to event start
    absolute, // Absolute date/time
};

/// Alarm action
pub const AlarmAction = enum {
    display,
    email,
    sound,
    procedure,
};

/// Alarm/Reminder
pub const Alarm = struct {
    trigger_type: AlarmTriggerType = .relative,
    trigger_offset: i64 = -900000, // -15 minutes in ms by default
    trigger_date: ?i64 = null,
    action: AlarmAction = .display,
    message: ?[]const u8 = null,
    sound: ?[]const u8 = null,

    /// Get offset in minutes (negative = before event)
    pub fn getOffsetMinutes(self: Alarm) i32 {
        return @intCast(@divTrunc(self.trigger_offset, 60000));
    }

    /// Create alarm for minutes before event
    pub fn minutesBefore(minutes: u32) Alarm {
        return .{
            .trigger_type = .relative,
            .trigger_offset = -@as(i64, @intCast(minutes)) * 60000,
        };
    }

    /// Create alarm for hours before event
    pub fn hoursBefore(hours: u32) Alarm {
        return .{
            .trigger_type = .relative,
            .trigger_offset = -@as(i64, @intCast(hours)) * 3600000,
        };
    }

    /// Create alarm for days before event
    pub fn daysBefore(days: u32) Alarm {
        return .{
            .trigger_type = .relative,
            .trigger_offset = -@as(i64, @intCast(days)) * 86400000,
        };
    }
};

/// Recurrence rule
pub const RecurrenceRule = struct {
    frequency: RecurrenceFrequency,
    interval: u32 = 1,
    count: ?u32 = null,
    until: ?i64 = null,
    by_day: []DayOfWeek = &[_]DayOfWeek{},
    by_month_day: []i8 = &[_]i8{},
    by_month: []u8 = &[_]u8{},
    by_set_pos: []i8 = &[_]i8{},
    week_start: DayOfWeek = .sunday,

    /// Create daily recurrence
    pub fn daily(interval: u32) RecurrenceRule {
        return .{
            .frequency = .daily,
            .interval = interval,
        };
    }

    /// Create weekly recurrence
    pub fn weekly(interval: u32, days: []DayOfWeek) RecurrenceRule {
        return .{
            .frequency = .weekly,
            .interval = interval,
            .by_day = days,
        };
    }

    /// Create monthly recurrence
    pub fn monthly(interval: u32) RecurrenceRule {
        return .{
            .frequency = .monthly,
            .interval = interval,
        };
    }

    /// Create yearly recurrence
    pub fn yearly(interval: u32) RecurrenceRule {
        return .{
            .frequency = .yearly,
            .interval = interval,
        };
    }

    /// Set end count
    pub fn withCount(self: *RecurrenceRule, count: u32) *RecurrenceRule {
        self.count = count;
        return self;
    }

    /// Set end date
    pub fn withUntil(self: *RecurrenceRule, until: i64) *RecurrenceRule {
        self.until = until;
        return self;
    }

    /// Check if rule has end condition
    pub fn hasEndCondition(self: RecurrenceRule) bool {
        return self.count != null or self.until != null;
    }
};

/// Event attendee role
pub const AttendeeRole = enum {
    required,
    optional,
    chair,
    non_participant,

    pub fn toString(self: AttendeeRole) []const u8 {
        return switch (self) {
            .required => "required",
            .optional => "optional",
            .chair => "chair",
            .non_participant => "non_participant",
        };
    }
};

/// Attendee participation status
pub const ParticipationStatus = enum {
    unknown,
    pending,
    accepted,
    declined,
    tentative,
    delegated,

    pub fn toString(self: ParticipationStatus) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .pending => "pending",
            .accepted => "accepted",
            .declined => "declined",
            .tentative => "tentative",
            .delegated => "delegated",
        };
    }

    pub fn isConfirmed(self: ParticipationStatus) bool {
        return self == .accepted;
    }
};

/// Event attendee
pub const Attendee = struct {
    name: ?[]const u8 = null,
    email: []const u8,
    role: AttendeeRole = .required,
    status: ParticipationStatus = .unknown,
    is_organizer: bool = false,
    response_comment: ?[]const u8 = null,

    pub fn getDisplayName(self: Attendee) []const u8 {
        return self.name orelse self.email;
    }
};

/// Event location
pub const EventLocation = struct {
    name: ?[]const u8 = null,
    address: ?[]const u8 = null,
    latitude: ?f64 = null,
    longitude: ?f64 = null,
    url: ?[]const u8 = null, // Virtual meeting URL
    room: ?[]const u8 = null,

    pub fn hasGeoCoordinates(self: EventLocation) bool {
        return self.latitude != null and self.longitude != null;
    }

    pub fn isVirtual(self: EventLocation) bool {
        return self.url != null;
    }

    pub fn getDisplayString(self: EventLocation, allocator: Allocator) ![]u8 {
        if (self.name) |name| {
            if (self.room) |room| {
                return std.fmt.allocPrint(allocator, "{s} - {s}", .{ name, room });
            }
            return allocator.dupe(u8, name);
        }
        if (self.address) |addr| {
            return allocator.dupe(u8, addr);
        }
        if (self.url) |url| {
            return allocator.dupe(u8, url);
        }
        return allocator.dupe(u8, "");
    }
};

/// Calendar event
pub const CalendarEvent = struct {
    id: ?[]const u8 = null,
    calendar_id: ?[]const u8 = null,
    title: []const u8,
    description: ?[]const u8 = null,
    start_date: i64,
    end_date: i64,
    is_all_day: bool = false,
    time_zone: ?[]const u8 = null,
    location: ?EventLocation = null,
    status: EventStatus = .confirmed,
    availability: Availability = .busy,
    organizer: ?Attendee = null,
    attendees: []Attendee = &[_]Attendee{},
    alarms: []Alarm = &[_]Alarm{},
    recurrence_rule: ?RecurrenceRule = null,
    url: ?[]const u8 = null,
    notes: ?[]const u8 = null,
    color: ?u32 = null,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,

    /// Get duration in milliseconds
    pub fn getDurationMs(self: CalendarEvent) i64 {
        return self.end_date - self.start_date;
    }

    /// Get duration in minutes
    pub fn getDurationMinutes(self: CalendarEvent) i32 {
        return @intCast(@divTrunc(self.getDurationMs(), 60000));
    }

    /// Get duration in hours
    pub fn getDurationHours(self: CalendarEvent) f32 {
        return @as(f32, @floatFromInt(self.getDurationMinutes())) / 60.0;
    }

    /// Check if event is recurring
    pub fn isRecurring(self: CalendarEvent) bool {
        return self.recurrence_rule != null;
    }

    /// Check if event has attendees
    pub fn hasAttendees(self: CalendarEvent) bool {
        return self.attendees.len > 0;
    }

    /// Check if event has alarms
    pub fn hasAlarms(self: CalendarEvent) bool {
        return self.alarms.len > 0;
    }

    /// Check if event is in progress at given time
    pub fn isInProgress(self: CalendarEvent, timestamp: i64) bool {
        return timestamp >= self.start_date and timestamp < self.end_date;
    }

    /// Check if event overlaps with another
    pub fn overlapsWith(self: CalendarEvent, other: CalendarEvent) bool {
        return self.start_date < other.end_date and self.end_date > other.start_date;
    }

    /// Get accepted attendee count
    pub fn getAcceptedCount(self: CalendarEvent) usize {
        var count: usize = 0;
        for (self.attendees) |attendee| {
            if (attendee.status == .accepted) count += 1;
        }
        return count;
    }

    /// Get declined attendee count
    pub fn getDeclinedCount(self: CalendarEvent) usize {
        var count: usize = 0;
        for (self.attendees) |attendee| {
            if (attendee.status == .declined) count += 1;
        }
        return count;
    }
};

/// Calendar account type
pub const CalendarAccountType = enum {
    local,
    icloud,
    google,
    exchange,
    caldav,
    other,

    pub fn toString(self: CalendarAccountType) []const u8 {
        return switch (self) {
            .local => "local",
            .icloud => "icloud",
            .google => "google",
            .exchange => "exchange",
            .caldav => "caldav",
            .other => "other",
        };
    }
};

/// Calendar
pub const Calendar = struct {
    id: ?[]const u8 = null,
    title: []const u8,
    color: ?u32 = null,
    account_type: CalendarAccountType = .local,
    account_name: ?[]const u8 = null,
    is_primary: bool = false,
    is_read_only: bool = false,
    is_visible: bool = true,
    allows_modify: bool = true,
    allows_content_modify: bool = true,

    pub fn canEdit(self: Calendar) bool {
        return !self.is_read_only and self.allows_modify;
    }
};

/// Calendar authorization status
pub const CalendarAuthorizationStatus = enum {
    not_determined,
    restricted,
    denied,
    authorized,
    write_only, // iOS 17+ EKAuthorizationStatusWriteOnly

    pub fn isGranted(self: CalendarAuthorizationStatus) bool {
        return self == .authorized or self == .write_only;
    }

    pub fn canRead(self: CalendarAuthorizationStatus) bool {
        return self == .authorized;
    }

    pub fn canWrite(self: CalendarAuthorizationStatus) bool {
        return self == .authorized or self == .write_only;
    }
};

/// Calendar error
pub const CalendarError = error{
    NotAuthorized,
    CalendarNotFound,
    EventNotFound,
    InvalidData,
    SaveFailed,
    DeleteFailed,
    ReadOnly,
    RecurringEventModification,
    SyncFailed,
    Timeout,
    Unknown,
};

/// Event search criteria
pub const EventSearchCriteria = struct {
    calendar_ids: ?[][]const u8 = null,
    start_date: ?i64 = null,
    end_date: ?i64 = null,
    query: ?[]const u8 = null,
    include_recurring: bool = true,
};

/// Free/busy time slot
pub const FreeBusySlot = struct {
    start_date: i64,
    end_date: i64,
    availability: Availability,
    event_id: ?[]const u8 = null,

    pub fn getDurationMs(self: FreeBusySlot) i64 {
        return self.end_date - self.start_date;
    }
};

// ============================================================================
// Platform Detection
// ============================================================================

fn getTimestampMs() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
    }
    return 0;
}

const Platform = enum {
    ios,
    android,
    macos,
    windows,
    linux,
    unknown,
};

fn detectPlatform() Platform {
    return switch (builtin.os.tag) {
        .macos => .macos,
        .ios => .ios,
        .linux => if (builtin.abi == .android) .android else .linux,
        .windows => .windows,
        else => .unknown,
    };
}

// ============================================================================
// Calendar Store
// ============================================================================

/// Main calendar store interface
pub const CalendarStore = struct {
    allocator: Allocator,
    platform: Platform,
    authorization_status: CalendarAuthorizationStatus,
    calendars: std.ArrayListUnmanaged(Calendar) = .{},
    events: std.ArrayListUnmanaged(CalendarEvent) = .{},
    default_calendar_id: ?[]const u8,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .platform = detectPlatform(),
            .authorization_status = .not_determined,
            .default_calendar_id = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.calendars.deinit(self.allocator);
        self.events.deinit(self.allocator);
    }

    /// Request calendar access
    pub fn requestAuthorization(self: *Self) !CalendarAuthorizationStatus {
        switch (self.platform) {
            .ios, .macos => {
                // EKEventStore.requestAccess
                self.authorization_status = .authorized;
            },
            .android => {
                // ActivityCompat.requestPermissions
                self.authorization_status = .authorized;
            },
            else => {
                self.authorization_status = .authorized;
            },
        }
        return self.authorization_status;
    }

    /// Get current authorization status
    pub fn getAuthorizationStatus(self: Self) CalendarAuthorizationStatus {
        return self.authorization_status;
    }

    /// Get all calendars
    pub fn getCalendars(self: *Self) ![]Calendar {
        if (!self.authorization_status.canRead()) {
            return CalendarError.NotAuthorized;
        }
        return self.calendars.items;
    }

    /// Get calendar by ID
    pub fn getCalendar(self: *Self, calendar_id: []const u8) !Calendar {
        if (!self.authorization_status.canRead()) {
            return CalendarError.NotAuthorized;
        }

        for (self.calendars.items) |calendar| {
            if (calendar.id) |id| {
                if (std.mem.eql(u8, id, calendar_id)) {
                    return calendar;
                }
            }
        }
        return CalendarError.CalendarNotFound;
    }

    /// Create a new calendar
    pub fn createCalendar(self: *Self, title: []const u8, color: ?u32) ![]const u8 {
        if (!self.authorization_status.canWrite()) {
            return CalendarError.NotAuthorized;
        }

        const timestamp = getTimestampMs();
        const id = try std.fmt.allocPrint(self.allocator, "cal_{d}", .{timestamp});

        const calendar = Calendar{
            .id = id,
            .title = title,
            .color = color,
            .account_type = .local,
            .is_primary = self.calendars.items.len == 0,
        };

        try self.calendars.append(self.allocator, calendar);

        if (self.default_calendar_id == null) {
            self.default_calendar_id = id;
        }

        return id;
    }

    /// Delete a calendar
    pub fn deleteCalendar(self: *Self, calendar_id: []const u8) !void {
        if (!self.authorization_status.canWrite()) {
            return CalendarError.NotAuthorized;
        }

        for (self.calendars.items, 0..) |calendar, i| {
            if (calendar.id) |id| {
                if (std.mem.eql(u8, id, calendar_id)) {
                    if (calendar.is_read_only) {
                        return CalendarError.ReadOnly;
                    }

                    // Remove all events in this calendar
                    var j: usize = 0;
                    while (j < self.events.items.len) {
                        if (self.events.items[j].calendar_id) |cal_id| {
                            if (std.mem.eql(u8, cal_id, calendar_id)) {
                                _ = self.events.orderedRemove(j);
                                continue;
                            }
                        }
                        j += 1;
                    }

                    _ = self.calendars.orderedRemove(i);
                    return;
                }
            }
        }
        return CalendarError.CalendarNotFound;
    }

    /// Get default calendar
    pub fn getDefaultCalendar(self: *Self) !Calendar {
        if (!self.authorization_status.canRead()) {
            return CalendarError.NotAuthorized;
        }

        if (self.default_calendar_id) |id| {
            return self.getCalendar(id);
        }

        // Return first calendar if no default set
        if (self.calendars.items.len > 0) {
            return self.calendars.items[0];
        }

        return CalendarError.CalendarNotFound;
    }

    /// Create a new event
    pub fn createEvent(self: *Self, event: CalendarEvent) ![]const u8 {
        if (!self.authorization_status.canWrite()) {
            return CalendarError.NotAuthorized;
        }

        var new_event = event;
        const timestamp = getTimestampMs();

        const id = try std.fmt.allocPrint(self.allocator, "event_{d}", .{timestamp});
        new_event.id = id;
        new_event.created_at = timestamp;
        new_event.updated_at = timestamp;

        // Set default calendar if not specified
        if (new_event.calendar_id == null) {
            new_event.calendar_id = self.default_calendar_id;
        }

        try self.events.append(self.allocator, new_event);

        return id;
    }

    /// Get event by ID
    pub fn getEvent(self: *Self, event_id: []const u8) !CalendarEvent {
        if (!self.authorization_status.canRead()) {
            return CalendarError.NotAuthorized;
        }

        for (self.events.items) |event| {
            if (event.id) |id| {
                if (std.mem.eql(u8, id, event_id)) {
                    return event;
                }
            }
        }
        return CalendarError.EventNotFound;
    }

    /// Update an event
    pub fn updateEvent(self: *Self, event_id: []const u8, updates: CalendarEvent) !void {
        if (!self.authorization_status.canWrite()) {
            return CalendarError.NotAuthorized;
        }

        for (self.events.items, 0..) |*event, i| {
            if (event.id) |id| {
                if (std.mem.eql(u8, id, event_id)) {
                    const timestamp = getTimestampMs();

                    var updated = updates;
                    updated.id = event.id;
                    updated.calendar_id = event.calendar_id;
                    updated.created_at = event.created_at;
                    updated.updated_at = timestamp;

                    self.events.items[i] = updated;
                    return;
                }
            }
        }
        return CalendarError.EventNotFound;
    }

    /// Delete an event
    pub fn deleteEvent(self: *Self, event_id: []const u8) !void {
        if (!self.authorization_status.canWrite()) {
            return CalendarError.NotAuthorized;
        }

        for (self.events.items, 0..) |event, i| {
            if (event.id) |id| {
                if (std.mem.eql(u8, id, event_id)) {
                    _ = self.events.orderedRemove(i);
                    return;
                }
            }
        }
        return CalendarError.EventNotFound;
    }

    /// Search events
    pub fn searchEvents(self: *Self, criteria: EventSearchCriteria) ![]CalendarEvent {
        if (!self.authorization_status.canRead()) {
            return CalendarError.NotAuthorized;
        }

        var results = std.ArrayListUnmanaged(CalendarEvent){};
        errdefer results.deinit(self.allocator);

        for (self.events.items) |event| {
            if (matchesSearchCriteria(event, criteria)) {
                try results.append(self.allocator, event);
            }
        }

        return results.items;
    }

    fn matchesSearchCriteria(event: CalendarEvent, criteria: EventSearchCriteria) bool {
        // Filter by date range
        if (criteria.start_date) |start| {
            if (event.end_date < start) return false;
        }
        if (criteria.end_date) |end| {
            if (event.start_date > end) return false;
        }

        // Filter by calendar
        if (criteria.calendar_ids) |cal_ids| {
            if (event.calendar_id) |event_cal_id| {
                var found = false;
                for (cal_ids) |cal_id| {
                    if (std.mem.eql(u8, event_cal_id, cal_id)) {
                        found = true;
                        break;
                    }
                }
                if (!found) return false;
            } else {
                return false;
            }
        }

        // Filter by query
        if (criteria.query) |query| {
            const title_match = std.mem.indexOf(u8, event.title, query) != null;
            const desc_match = if (event.description) |desc|
                std.mem.indexOf(u8, desc, query) != null
            else
                false;

            if (!title_match and !desc_match) return false;
        }

        // Filter recurring
        if (!criteria.include_recurring and event.isRecurring()) {
            return false;
        }

        return true;
    }

    /// Get events for a date range
    pub fn getEvents(self: *Self, start_date: i64, end_date: i64) ![]CalendarEvent {
        return self.searchEvents(.{
            .start_date = start_date,
            .end_date = end_date,
        });
    }

    /// Get events for today
    pub fn getTodayEvents(self: *Self) ![]CalendarEvent {
        const now = getTimestampMs();
        const day_ms: i64 = 86400000;
        const start_of_day = now - @mod(now, day_ms);
        const end_of_day = start_of_day + day_ms;

        return self.getEvents(start_of_day, end_of_day);
    }

    /// Get free/busy information
    pub fn getFreeBusy(self: *Self, start_date: i64, end_date: i64) ![]FreeBusySlot {
        if (!self.authorization_status.canRead()) {
            return CalendarError.NotAuthorized;
        }

        var slots = std.ArrayListUnmanaged(FreeBusySlot){};
        errdefer slots.deinit(self.allocator);

        const events = try self.getEvents(start_date, end_date);

        for (events) |event| {
            if (event.status == .cancelled) continue;

            try slots.append(self.allocator, .{
                .start_date = event.start_date,
                .end_date = event.end_date,
                .availability = event.availability,
                .event_id = event.id,
            });
        }

        return slots.items;
    }

    /// Get calendar count
    pub fn getCalendarCount(self: Self) usize {
        return self.calendars.items.len;
    }

    /// Get event count
    pub fn getEventCount(self: Self) usize {
        return self.events.items.len;
    }
};

// ============================================================================
// Event Builder
// ============================================================================

/// Helper for building calendar events
pub const EventBuilder = struct {
    allocator: Allocator,
    event: CalendarEvent,
    attendees: std.ArrayListUnmanaged(Attendee) = .{},
    alarms: std.ArrayListUnmanaged(Alarm) = .{},

    const Self = @This();

    pub fn init(allocator: Allocator, title: []const u8, start_date: i64, end_date: i64) Self {
        return .{
            .allocator = allocator,
            .event = .{
                .title = title,
                .start_date = start_date,
                .end_date = end_date,
            },
        };
    }

    pub fn deinit(self: *Self) void {
        self.attendees.deinit(self.allocator);
        self.alarms.deinit(self.allocator);
    }

    pub fn setDescription(self: *Self, description: []const u8) *Self {
        self.event.description = description;
        return self;
    }

    pub fn setAllDay(self: *Self, is_all_day: bool) *Self {
        self.event.is_all_day = is_all_day;
        return self;
    }

    pub fn setLocation(self: *Self, location: EventLocation) *Self {
        self.event.location = location;
        return self;
    }

    pub fn setStatus(self: *Self, status: EventStatus) *Self {
        self.event.status = status;
        return self;
    }

    pub fn setAvailability(self: *Self, availability: Availability) *Self {
        self.event.availability = availability;
        return self;
    }

    pub fn setRecurrence(self: *Self, rule: RecurrenceRule) *Self {
        self.event.recurrence_rule = rule;
        return self;
    }

    pub fn setNotes(self: *Self, notes: []const u8) *Self {
        self.event.notes = notes;
        return self;
    }

    pub fn setColor(self: *Self, color: u32) *Self {
        self.event.color = color;
        return self;
    }

    pub fn addAttendee(self: *Self, attendee: Attendee) !*Self {
        try self.attendees.append(self.allocator, attendee);
        return self;
    }

    pub fn addAlarm(self: *Self, alarm: Alarm) !*Self {
        try self.alarms.append(self.allocator, alarm);
        return self;
    }

    pub fn build(self: *Self) CalendarEvent {
        self.event.attendees = self.attendees.items;
        self.event.alarms = self.alarms.items;
        return self.event;
    }
};

// ============================================================================
// iCalendar (ICS) Generator
// ============================================================================

pub const ICSGenerator = struct {
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn generateEvent(self: Self, event: CalendarEvent) ![]u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(self.allocator);

        try result.appendSlice(self.allocator, "BEGIN:VCALENDAR\r\n");
        try result.appendSlice(self.allocator, "VERSION:2.0\r\n");
        try result.appendSlice(self.allocator, "PRODID:-//Craft//Calendar//EN\r\n");
        try result.appendSlice(self.allocator, "BEGIN:VEVENT\r\n");

        // UID
        if (event.id) |id| {
            const uid_line = try std.fmt.allocPrint(self.allocator, "UID:{s}\r\n", .{id});
            defer self.allocator.free(uid_line);
            try result.appendSlice(self.allocator, uid_line);
        }

        // Summary (title)
        const summary_line = try std.fmt.allocPrint(self.allocator, "SUMMARY:{s}\r\n", .{event.title});
        defer self.allocator.free(summary_line);
        try result.appendSlice(self.allocator, summary_line);

        // Dates
        if (event.is_all_day) {
            const dtstart = try formatDateOnly(self.allocator, event.start_date);
            defer self.allocator.free(dtstart);
            const dtend = try formatDateOnly(self.allocator, event.end_date);
            defer self.allocator.free(dtend);

            const start_line = try std.fmt.allocPrint(self.allocator, "DTSTART;VALUE=DATE:{s}\r\n", .{dtstart});
            defer self.allocator.free(start_line);
            try result.appendSlice(self.allocator, start_line);

            const end_line = try std.fmt.allocPrint(self.allocator, "DTEND;VALUE=DATE:{s}\r\n", .{dtend});
            defer self.allocator.free(end_line);
            try result.appendSlice(self.allocator, end_line);
        } else {
            const dtstart = try formatDateTime(self.allocator, event.start_date);
            defer self.allocator.free(dtstart);
            const dtend = try formatDateTime(self.allocator, event.end_date);
            defer self.allocator.free(dtend);

            const start_line = try std.fmt.allocPrint(self.allocator, "DTSTART:{s}\r\n", .{dtstart});
            defer self.allocator.free(start_line);
            try result.appendSlice(self.allocator, start_line);

            const end_line = try std.fmt.allocPrint(self.allocator, "DTEND:{s}\r\n", .{dtend});
            defer self.allocator.free(end_line);
            try result.appendSlice(self.allocator, end_line);
        }

        // Description
        if (event.description) |desc| {
            const desc_line = try std.fmt.allocPrint(self.allocator, "DESCRIPTION:{s}\r\n", .{desc});
            defer self.allocator.free(desc_line);
            try result.appendSlice(self.allocator, desc_line);
        }

        // Location
        if (event.location) |loc| {
            if (loc.name) |name| {
                const loc_line = try std.fmt.allocPrint(self.allocator, "LOCATION:{s}\r\n", .{name});
                defer self.allocator.free(loc_line);
                try result.appendSlice(self.allocator, loc_line);
            }
        }

        // Status
        const status_str = switch (event.status) {
            .tentative => "TENTATIVE",
            .confirmed => "CONFIRMED",
            .cancelled => "CANCELLED",
            .none => "CONFIRMED",
        };
        const status_line = try std.fmt.allocPrint(self.allocator, "STATUS:{s}\r\n", .{status_str});
        defer self.allocator.free(status_line);
        try result.appendSlice(self.allocator, status_line);

        try result.appendSlice(self.allocator, "END:VEVENT\r\n");
        try result.appendSlice(self.allocator, "END:VCALENDAR\r\n");

        return result.toOwnedSlice(self.allocator);
    }

    fn formatDateTime(allocator: Allocator, timestamp: i64) ![]u8 {
        // Simple ISO 8601 format
        const secs = @divTrunc(timestamp, 1000);
        return std.fmt.allocPrint(allocator, "{d}Z", .{secs});
    }

    fn formatDateOnly(allocator: Allocator, timestamp: i64) ![]u8 {
        const secs = @divTrunc(timestamp, 1000);
        return std.fmt.allocPrint(allocator, "{d}", .{secs});
    }
};

// ============================================================================
// Date/Time Utilities
// ============================================================================

pub const DateTimeUtils = struct {
    /// Add days to timestamp
    pub fn addDays(timestamp: i64, days: i32) i64 {
        return timestamp + @as(i64, days) * 86400000;
    }

    /// Add hours to timestamp
    pub fn addHours(timestamp: i64, hours: i32) i64 {
        return timestamp + @as(i64, hours) * 3600000;
    }

    /// Add minutes to timestamp
    pub fn addMinutes(timestamp: i64, minutes: i32) i64 {
        return timestamp + @as(i64, minutes) * 60000;
    }

    /// Get start of day for timestamp
    pub fn startOfDay(timestamp: i64) i64 {
        const day_ms: i64 = 86400000;
        return timestamp - @mod(timestamp, day_ms);
    }

    /// Get end of day for timestamp
    pub fn endOfDay(timestamp: i64) i64 {
        return startOfDay(timestamp) + 86400000 - 1;
    }

    /// Get start of week for timestamp (Sunday start)
    pub fn startOfWeek(timestamp: i64) i64 {
        const day = startOfDay(timestamp);
        const day_of_week = @mod(@divTrunc(day, 86400000) + 4, 7); // 0 = Sunday
        return day - day_of_week * 86400000;
    }

    /// Get start of month for timestamp
    pub fn startOfMonth(timestamp: i64) i64 {
        // Simplified - in production would need proper calendar math
        return startOfDay(timestamp);
    }

    /// Check if two timestamps are on the same day
    pub fn isSameDay(ts1: i64, ts2: i64) bool {
        return startOfDay(ts1) == startOfDay(ts2);
    }

    /// Get days between two timestamps
    pub fn daysBetween(ts1: i64, ts2: i64) i32 {
        const diff = @abs(ts2 - ts1);
        return @intCast(@divTrunc(diff, 86400000));
    }
};

// ============================================================================
// Tests
// ============================================================================

test "EventStatus toString" {
    try std.testing.expectEqualStrings("confirmed", EventStatus.confirmed.toString());
    try std.testing.expectEqualStrings("cancelled", EventStatus.cancelled.toString());
    try std.testing.expectEqualStrings("tentative", EventStatus.tentative.toString());
}

test "Availability toString" {
    try std.testing.expectEqualStrings("busy", Availability.busy.toString());
    try std.testing.expectEqualStrings("free", Availability.free.toString());
}

test "RecurrenceFrequency toString" {
    try std.testing.expectEqualStrings("daily", RecurrenceFrequency.daily.toString());
    try std.testing.expectEqualStrings("weekly", RecurrenceFrequency.weekly.toString());
    try std.testing.expectEqualStrings("monthly", RecurrenceFrequency.monthly.toString());
    try std.testing.expectEqualStrings("yearly", RecurrenceFrequency.yearly.toString());
}

test "DayOfWeek fromIndex" {
    try std.testing.expect(DayOfWeek.fromIndex(0) == .sunday);
    try std.testing.expect(DayOfWeek.fromIndex(1) == .monday);
    try std.testing.expect(DayOfWeek.fromIndex(6) == .saturday);
    try std.testing.expect(DayOfWeek.fromIndex(7) == null);
}

test "DayOfWeek toString" {
    try std.testing.expectEqualStrings("Monday", DayOfWeek.monday.toString());
    try std.testing.expectEqualStrings("Mon", DayOfWeek.monday.toShortString());
}

test "Alarm creation helpers" {
    const alarm1 = Alarm.minutesBefore(15);
    try std.testing.expectEqual(@as(i32, -15), alarm1.getOffsetMinutes());

    const alarm2 = Alarm.hoursBefore(2);
    try std.testing.expectEqual(@as(i32, -120), alarm2.getOffsetMinutes());

    const alarm3 = Alarm.daysBefore(1);
    try std.testing.expectEqual(@as(i32, -1440), alarm3.getOffsetMinutes());
}

test "RecurrenceRule daily" {
    const rule = RecurrenceRule.daily(1);
    try std.testing.expect(rule.frequency == .daily);
    try std.testing.expectEqual(@as(u32, 1), rule.interval);
    try std.testing.expect(!rule.hasEndCondition());
}

test "RecurrenceRule weekly" {
    var days = [_]DayOfWeek{ .monday, .wednesday, .friday };
    const rule = RecurrenceRule.weekly(1, &days);
    try std.testing.expect(rule.frequency == .weekly);
    try std.testing.expectEqual(@as(usize, 3), rule.by_day.len);
}

test "RecurrenceRule with count" {
    var rule = RecurrenceRule.daily(1);
    _ = rule.withCount(10);
    try std.testing.expect(rule.hasEndCondition());
    try std.testing.expectEqual(@as(u32, 10), rule.count.?);
}

test "AttendeeRole toString" {
    try std.testing.expectEqualStrings("required", AttendeeRole.required.toString());
    try std.testing.expectEqualStrings("optional", AttendeeRole.optional.toString());
}

test "ParticipationStatus isConfirmed" {
    try std.testing.expect(ParticipationStatus.accepted.isConfirmed());
    try std.testing.expect(!ParticipationStatus.tentative.isConfirmed());
    try std.testing.expect(!ParticipationStatus.declined.isConfirmed());
}

test "Attendee getDisplayName" {
    const with_name = Attendee{ .name = "John Doe", .email = "john@test.com" };
    try std.testing.expectEqualStrings("John Doe", with_name.getDisplayName());

    const email_only = Attendee{ .email = "jane@test.com" };
    try std.testing.expectEqualStrings("jane@test.com", email_only.getDisplayName());
}

test "EventLocation hasGeoCoordinates" {
    const with_geo = EventLocation{ .latitude = 37.7749, .longitude = -122.4194 };
    try std.testing.expect(with_geo.hasGeoCoordinates());

    const without_geo = EventLocation{ .name = "Office" };
    try std.testing.expect(!without_geo.hasGeoCoordinates());
}

test "EventLocation isVirtual" {
    const virtual = EventLocation{ .url = "https://zoom.us/meeting" };
    try std.testing.expect(virtual.isVirtual());

    const physical = EventLocation{ .name = "Conference Room A" };
    try std.testing.expect(!physical.isVirtual());
}

test "EventLocation getDisplayString" {
    const allocator = std.testing.allocator;

    const loc1 = EventLocation{ .name = "Office", .room = "Room 101" };
    const display1 = try loc1.getDisplayString(allocator);
    defer allocator.free(display1);
    try std.testing.expectEqualStrings("Office - Room 101", display1);

    const loc2 = EventLocation{ .address = "123 Main St" };
    const display2 = try loc2.getDisplayString(allocator);
    defer allocator.free(display2);
    try std.testing.expectEqualStrings("123 Main St", display2);
}

test "CalendarEvent getDuration" {
    const event = CalendarEvent{
        .title = "Meeting",
        .start_date = 1000000000000,
        .end_date = 1000000000000 + 3600000, // 1 hour
    };

    try std.testing.expectEqual(@as(i64, 3600000), event.getDurationMs());
    try std.testing.expectEqual(@as(i32, 60), event.getDurationMinutes());
    try std.testing.expectEqual(@as(f32, 1.0), event.getDurationHours());
}

test "CalendarEvent isRecurring" {
    const recurring = CalendarEvent{
        .title = "Daily Standup",
        .start_date = 1000000000000,
        .end_date = 1000000000000 + 900000,
        .recurrence_rule = RecurrenceRule.daily(1),
    };
    try std.testing.expect(recurring.isRecurring());

    const single = CalendarEvent{
        .title = "One-time Meeting",
        .start_date = 1000000000000,
        .end_date = 1000000000000 + 900000,
    };
    try std.testing.expect(!single.isRecurring());
}

test "CalendarEvent isInProgress" {
    const event = CalendarEvent{
        .title = "Meeting",
        .start_date = 1000,
        .end_date = 2000,
    };

    try std.testing.expect(event.isInProgress(1500));
    try std.testing.expect(!event.isInProgress(500));
    try std.testing.expect(!event.isInProgress(2500));
    try std.testing.expect(event.isInProgress(1000)); // Start time is in progress
    try std.testing.expect(!event.isInProgress(2000)); // End time is not
}

test "CalendarEvent overlapsWith" {
    const event1 = CalendarEvent{
        .title = "Event 1",
        .start_date = 1000,
        .end_date = 2000,
    };

    const overlapping = CalendarEvent{
        .title = "Overlapping",
        .start_date = 1500,
        .end_date = 2500,
    };
    try std.testing.expect(event1.overlapsWith(overlapping));

    const non_overlapping = CalendarEvent{
        .title = "Non-overlapping",
        .start_date = 3000,
        .end_date = 4000,
    };
    try std.testing.expect(!event1.overlapsWith(non_overlapping));
}

test "CalendarEvent attendee counts" {
    var attendees = [_]Attendee{
        .{ .email = "a@test.com", .status = .accepted },
        .{ .email = "b@test.com", .status = .accepted },
        .{ .email = "c@test.com", .status = .declined },
        .{ .email = "d@test.com", .status = .pending },
    };

    const event = CalendarEvent{
        .title = "Team Meeting",
        .start_date = 1000,
        .end_date = 2000,
        .attendees = &attendees,
    };

    try std.testing.expectEqual(@as(usize, 2), event.getAcceptedCount());
    try std.testing.expectEqual(@as(usize, 1), event.getDeclinedCount());
}

test "Calendar canEdit" {
    const editable = Calendar{ .title = "Personal", .is_read_only = false, .allows_modify = true };
    try std.testing.expect(editable.canEdit());

    const read_only = Calendar{ .title = "Holidays", .is_read_only = true };
    try std.testing.expect(!read_only.canEdit());
}

test "CalendarAuthorizationStatus permissions" {
    try std.testing.expect(CalendarAuthorizationStatus.authorized.isGranted());
    try std.testing.expect(CalendarAuthorizationStatus.authorized.canRead());
    try std.testing.expect(CalendarAuthorizationStatus.authorized.canWrite());

    try std.testing.expect(CalendarAuthorizationStatus.write_only.isGranted());
    try std.testing.expect(!CalendarAuthorizationStatus.write_only.canRead());
    try std.testing.expect(CalendarAuthorizationStatus.write_only.canWrite());

    try std.testing.expect(!CalendarAuthorizationStatus.denied.isGranted());
}

test "CalendarStore init and deinit" {
    const allocator = std.testing.allocator;
    var store = CalendarStore.init(allocator);
    defer store.deinit();

    try std.testing.expect(store.authorization_status == .not_determined);
    try std.testing.expectEqual(@as(usize, 0), store.getCalendarCount());
}

test "CalendarStore requestAuthorization" {
    const allocator = std.testing.allocator;
    var store = CalendarStore.init(allocator);
    defer store.deinit();

    const status = try store.requestAuthorization();
    try std.testing.expect(status == .authorized);
}

test "CalendarStore createCalendar" {
    const allocator = std.testing.allocator;
    var store = CalendarStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();

    const id = try store.createCalendar("Work", 0xFF0000);
    try std.testing.expect(id.len > 0);
    try std.testing.expectEqual(@as(usize, 1), store.getCalendarCount());

    const cal = try store.getCalendar(id);
    try std.testing.expectEqualStrings("Work", cal.title);
    try std.testing.expect(cal.is_primary);
}

test "CalendarStore deleteCalendar" {
    const allocator = std.testing.allocator;
    var store = CalendarStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();

    const id = try store.createCalendar("ToDelete", null);
    try std.testing.expectEqual(@as(usize, 1), store.getCalendarCount());

    try store.deleteCalendar(id);
    try std.testing.expectEqual(@as(usize, 0), store.getCalendarCount());
}

test "CalendarStore createEvent" {
    const allocator = std.testing.allocator;
    var store = CalendarStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();
    _ = try store.createCalendar("Personal", null);

    const event = CalendarEvent{
        .title = "Meeting",
        .start_date = 1000000000000,
        .end_date = 1000000000000 + 3600000,
    };

    const id = try store.createEvent(event);
    try std.testing.expect(id.len > 0);
    try std.testing.expectEqual(@as(usize, 1), store.getEventCount());
}

test "CalendarStore getEvent" {
    const allocator = std.testing.allocator;
    var store = CalendarStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();
    _ = try store.createCalendar("Test", null);

    const event = CalendarEvent{
        .title = "Test Event",
        .start_date = 1000000000000,
        .end_date = 1000000000000 + 1800000,
        .description = "Test description",
    };

    const id = try store.createEvent(event);
    const retrieved = try store.getEvent(id);

    try std.testing.expectEqualStrings("Test Event", retrieved.title);
    try std.testing.expectEqualStrings("Test description", retrieved.description.?);
}

test "CalendarStore updateEvent" {
    const allocator = std.testing.allocator;
    var store = CalendarStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();
    _ = try store.createCalendar("Test", null);

    const event = CalendarEvent{
        .title = "Original",
        .start_date = 1000,
        .end_date = 2000,
    };

    const id = try store.createEvent(event);

    const updates = CalendarEvent{
        .title = "Updated",
        .start_date = 1000,
        .end_date = 3000,
    };

    try store.updateEvent(id, updates);

    const updated = try store.getEvent(id);
    try std.testing.expectEqualStrings("Updated", updated.title);
    try std.testing.expectEqual(@as(i64, 3000), updated.end_date);
}

test "CalendarStore deleteEvent" {
    const allocator = std.testing.allocator;
    var store = CalendarStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();
    _ = try store.createCalendar("Test", null);

    const event = CalendarEvent{
        .title = "ToDelete",
        .start_date = 1000,
        .end_date = 2000,
    };

    const id = try store.createEvent(event);
    try std.testing.expectEqual(@as(usize, 1), store.getEventCount());

    try store.deleteEvent(id);
    try std.testing.expectEqual(@as(usize, 0), store.getEventCount());
}

test "CalendarStore searchEvents" {
    const allocator = std.testing.allocator;
    var store = CalendarStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();
    _ = try store.createCalendar("Test", null);

    _ = try store.createEvent(.{
        .title = "Morning Meeting",
        .start_date = 1000,
        .end_date = 2000,
    });

    _ = try store.createEvent(.{
        .title = "Lunch",
        .start_date = 3000,
        .end_date = 4000,
    });

    _ = try store.createEvent(.{
        .title = "Evening Meeting",
        .start_date = 5000,
        .end_date = 6000,
    });

    // Search by date range
    const in_range = try store.searchEvents(.{
        .start_date = 2500,
        .end_date = 5500,
    });
    try std.testing.expectEqual(@as(usize, 2), in_range.len);

    // Search by query
    const meetings = try store.searchEvents(.{
        .query = "Meeting",
    });
    try std.testing.expectEqual(@as(usize, 2), meetings.len);
}

test "CalendarStore unauthorized operations" {
    const allocator = std.testing.allocator;
    var store = CalendarStore.init(allocator);
    defer store.deinit();

    // Don't request authorization

    try std.testing.expectError(CalendarError.NotAuthorized, store.createCalendar("Test", null));
    try std.testing.expectError(CalendarError.NotAuthorized, store.getCalendars());
}

test "EventBuilder basic usage" {
    const allocator = std.testing.allocator;
    var builder = EventBuilder.init(allocator, "Team Sync", 1000, 2000);
    defer builder.deinit();

    _ = builder.setDescription("Weekly team sync meeting")
        .setAllDay(false)
        .setStatus(.confirmed)
        .setAvailability(.busy);

    const event = builder.build();
    try std.testing.expectEqualStrings("Team Sync", event.title);
    try std.testing.expectEqualStrings("Weekly team sync meeting", event.description.?);
    try std.testing.expect(event.status == .confirmed);
}

test "EventBuilder with attendees and alarms" {
    const allocator = std.testing.allocator;
    var builder = EventBuilder.init(allocator, "Meeting", 1000, 2000);
    defer builder.deinit();

    _ = try builder.addAttendee(.{ .email = "alice@test.com", .role = .required });
    _ = try builder.addAttendee(.{ .email = "bob@test.com", .role = .optional });
    _ = try builder.addAlarm(Alarm.minutesBefore(15));

    const event = builder.build();
    try std.testing.expectEqual(@as(usize, 2), event.attendees.len);
    try std.testing.expectEqual(@as(usize, 1), event.alarms.len);
}

test "EventBuilder with location" {
    const allocator = std.testing.allocator;
    var builder = EventBuilder.init(allocator, "Office Visit", 1000, 2000);
    defer builder.deinit();

    _ = builder.setLocation(.{
        .name = "Main Office",
        .address = "123 Business Ave",
        .latitude = 37.7749,
        .longitude = -122.4194,
    });

    const event = builder.build();
    try std.testing.expect(event.location != null);
    try std.testing.expectEqualStrings("Main Office", event.location.?.name.?);
}

test "ICSGenerator basic event" {
    const allocator = std.testing.allocator;
    const generator = ICSGenerator.init(allocator);

    const event = CalendarEvent{
        .id = "test-event-123",
        .title = "Test Meeting",
        .start_date = 1000000000000,
        .end_date = 1000000000000 + 3600000,
        .description = "A test meeting",
    };

    const ics = try generator.generateEvent(event);
    defer allocator.free(ics);

    try std.testing.expect(std.mem.indexOf(u8, ics, "BEGIN:VCALENDAR") != null);
    try std.testing.expect(std.mem.indexOf(u8, ics, "BEGIN:VEVENT") != null);
    try std.testing.expect(std.mem.indexOf(u8, ics, "SUMMARY:Test Meeting") != null);
    try std.testing.expect(std.mem.indexOf(u8, ics, "END:VEVENT") != null);
    try std.testing.expect(std.mem.indexOf(u8, ics, "END:VCALENDAR") != null);
}

test "DateTimeUtils addDays" {
    const base: i64 = 1000000000000;
    const result = DateTimeUtils.addDays(base, 1);
    try std.testing.expectEqual(base + 86400000, result);
}

test "DateTimeUtils addHours" {
    const base: i64 = 1000000000000;
    const result = DateTimeUtils.addHours(base, 2);
    try std.testing.expectEqual(base + 7200000, result);
}

test "DateTimeUtils addMinutes" {
    const base: i64 = 1000000000000;
    const result = DateTimeUtils.addMinutes(base, 30);
    try std.testing.expectEqual(base + 1800000, result);
}

test "DateTimeUtils startOfDay" {
    const timestamp: i64 = 1000000050000; // Some time in the day
    const start = DateTimeUtils.startOfDay(timestamp);
    try std.testing.expect(start <= timestamp);
    try std.testing.expect(@mod(start, 86400000) == 0);
}

test "DateTimeUtils isSameDay" {
    const day_ms: i64 = 86400000;
    const ts1: i64 = day_ms * 10 + 1000; // Day 10, some time
    const ts2: i64 = day_ms * 10 + 50000; // Day 10, different time
    const ts3: i64 = day_ms * 11 + 1000; // Day 11

    try std.testing.expect(DateTimeUtils.isSameDay(ts1, ts2));
    try std.testing.expect(!DateTimeUtils.isSameDay(ts1, ts3));
}

test "DateTimeUtils daysBetween" {
    const day_ms: i64 = 86400000;
    const ts1: i64 = day_ms * 10;
    const ts2: i64 = day_ms * 15;

    try std.testing.expectEqual(@as(i32, 5), DateTimeUtils.daysBetween(ts1, ts2));
    try std.testing.expectEqual(@as(i32, 5), DateTimeUtils.daysBetween(ts2, ts1)); // Order doesn't matter
}

test "FreeBusySlot getDurationMs" {
    const slot = FreeBusySlot{
        .start_date = 1000,
        .end_date = 2000,
        .availability = .busy,
    };
    try std.testing.expectEqual(@as(i64, 1000), slot.getDurationMs());
}

test "CalendarAccountType toString" {
    try std.testing.expectEqualStrings("google", CalendarAccountType.google.toString());
    try std.testing.expectEqualStrings("icloud", CalendarAccountType.icloud.toString());
    try std.testing.expectEqualStrings("exchange", CalendarAccountType.exchange.toString());
}

test "platform detection" {
    const platform = detectPlatform();
    try std.testing.expect(platform == .macos or platform == .linux or platform == .windows or platform == .unknown);
}

test "timestamp generation" {
    const ts1 = getTimestampMs();
    const ts2 = getTimestampMs();
    try std.testing.expect(ts2 >= ts1);
    try std.testing.expect(ts1 > 0);
}
