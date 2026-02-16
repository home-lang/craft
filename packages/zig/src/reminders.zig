//! Reminders/Tasks Module for Craft Framework
//!
//! Cross-platform task and reminder management providing:
//! - Task creation and management
//! - Due dates and priorities
//! - Recurrence rules
//! - List/folder organization
//! - Location-based reminders
//! - Subtasks and checklists
//!
//! Platform implementations:
//! - iOS: EventKit (EKReminder)
//! - Android: Tasks API / CalendarContract
//! - macOS: EventKit
//! - Windows: Microsoft To Do API
//! - Linux: CalDAV / local storage

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Enums
// ============================================================================

pub const TaskPriority = enum(u8) {
    none = 0,
    low = 1,
    medium = 5,
    high = 9,

    pub fn toValue(self: TaskPriority) u8 {
        return @intFromEnum(self);
    }

    pub fn toString(self: TaskPriority) []const u8 {
        return switch (self) {
            .none => "none",
            .low => "low",
            .medium => "medium",
            .high => "high",
        };
    }

    pub fn fromValue(value: u8) TaskPriority {
        if (value == 0) return .none;
        if (value <= 3) return .low;
        if (value <= 6) return .medium;
        return .high;
    }
};

pub const TaskStatus = enum {
    pending,
    in_progress,
    completed,
    cancelled,
    deferred,

    pub fn isActive(self: TaskStatus) bool {
        return self == .pending or self == .in_progress;
    }

    pub fn isDone(self: TaskStatus) bool {
        return self == .completed or self == .cancelled;
    }

    pub fn toString(self: TaskStatus) []const u8 {
        return switch (self) {
            .pending => "pending",
            .in_progress => "in_progress",
            .completed => "completed",
            .cancelled => "cancelled",
            .deferred => "deferred",
        };
    }
};

pub const RecurrenceFrequency = enum {
    daily,
    weekly,
    biweekly,
    monthly,
    yearly,
    custom,

    pub fn toString(self: RecurrenceFrequency) []const u8 {
        return switch (self) {
            .daily => "daily",
            .weekly => "weekly",
            .biweekly => "biweekly",
            .monthly => "monthly",
            .yearly => "yearly",
            .custom => "custom",
        };
    }
};

pub const DayOfWeek = enum(u8) {
    sunday = 0,
    monday = 1,
    tuesday = 2,
    wednesday = 3,
    thursday = 4,
    friday = 5,
    saturday = 6,

    pub fn toValue(self: DayOfWeek) u8 {
        return @intFromEnum(self);
    }

    pub fn fromValue(value: u8) ?DayOfWeek {
        if (value > 6) return null;
        return @enumFromInt(value);
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

    pub fn shortName(self: DayOfWeek) []const u8 {
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

pub const ReminderTriggerType = enum {
    time,
    location_enter,
    location_exit,
    location_dwell,

    pub fn toString(self: ReminderTriggerType) []const u8 {
        return switch (self) {
            .time => "time",
            .location_enter => "location_enter",
            .location_exit => "location_exit",
            .location_dwell => "location_dwell",
        };
    }
};

pub const AuthorizationStatus = enum {
    not_determined,
    restricted,
    denied,
    authorized,
    authorized_full,

    pub fn isAuthorized(self: AuthorizationStatus) bool {
        return self == .authorized or self == .authorized_full;
    }

    pub fn toString(self: AuthorizationStatus) []const u8 {
        return switch (self) {
            .not_determined => "not_determined",
            .restricted => "restricted",
            .denied => "denied",
            .authorized => "authorized",
            .authorized_full => "authorized_full",
        };
    }
};

// ============================================================================
// Data Structures
// ============================================================================

pub const RecurrenceRule = struct {
    frequency: RecurrenceFrequency,
    interval: u32 = 1,
    count: ?u32 = null,
    until: ?i64 = null,
    by_day: []DayOfWeek = &[_]DayOfWeek{},
    by_month_day: []i8 = &[_]i8{},
    by_month: []u8 = &[_]u8{},

    const Self = @This();

    pub fn daily(interval: u32) Self {
        return .{ .frequency = .daily, .interval = interval };
    }

    pub fn weekly(interval: u32) Self {
        return .{ .frequency = .weekly, .interval = interval };
    }

    pub fn weeklyOnDays(days: []DayOfWeek) Self {
        return .{ .frequency = .weekly, .interval = 1, .by_day = days };
    }

    pub fn monthly(interval: u32) Self {
        return .{ .frequency = .monthly, .interval = interval };
    }

    pub fn yearly(interval: u32) Self {
        return .{ .frequency = .yearly, .interval = interval };
    }

    pub fn withCount(self: Self, max_count: u32) Self {
        var result = self;
        result.count = max_count;
        return result;
    }

    pub fn withEndDate(self: Self, end_date: i64) Self {
        var result = self;
        result.until = end_date;
        return result;
    }

    pub fn getNextOccurrence(self: Self, from_timestamp: i64) ?i64 {
        const day_ms: i64 = 86400000;
        const week_ms: i64 = day_ms * 7;

        return switch (self.frequency) {
            .daily => from_timestamp + day_ms * @as(i64, self.interval),
            .weekly => from_timestamp + week_ms * @as(i64, self.interval),
            .biweekly => from_timestamp + week_ms * 2,
            .monthly => from_timestamp + day_ms * 30 * @as(i64, self.interval),
            .yearly => from_timestamp + day_ms * 365 * @as(i64, self.interval),
            .custom => null,
        };
    }
};

pub const ReminderTrigger = struct {
    trigger_type: ReminderTriggerType = .time,
    time: ?i64 = null,
    location: ?Location = null,
    radius_meters: f64 = 100.0,
    dwell_time_seconds: ?u32 = null,

    pub const Location = struct {
        latitude: f64,
        longitude: f64,
        name: ?[]const u8 = null,
        address: ?[]const u8 = null,
    };

    const Self = @This();

    pub fn atTime(timestamp: i64) Self {
        return .{ .trigger_type = .time, .time = timestamp };
    }

    pub fn onEnterLocation(lat: f64, lng: f64, radius: f64) Self {
        return .{
            .trigger_type = .location_enter,
            .location = .{ .latitude = lat, .longitude = lng },
            .radius_meters = radius,
        };
    }

    pub fn onExitLocation(lat: f64, lng: f64, radius: f64) Self {
        return .{
            .trigger_type = .location_exit,
            .location = .{ .latitude = lat, .longitude = lng },
            .radius_meters = radius,
        };
    }

    pub fn isTimeBased(self: Self) bool {
        return self.trigger_type == .time;
    }

    pub fn isLocationBased(self: Self) bool {
        return self.trigger_type == .location_enter or
            self.trigger_type == .location_exit or
            self.trigger_type == .location_dwell;
    }
};

pub const Subtask = struct {
    id: []const u8 = "",
    title: []const u8,
    is_completed: bool = false,
    completed_at: ?i64 = null,
    sort_order: u32 = 0,

    const Self = @This();

    pub fn complete(self: *Self) void {
        self.is_completed = true;
        self.completed_at = getTimestampMs();
    }

    pub fn uncomplete(self: *Self) void {
        self.is_completed = false;
        self.completed_at = null;
    }
};

pub const Attachment = struct {
    id: []const u8 = "",
    file_path: ?[]const u8 = null,
    url: ?[]const u8 = null,
    mime_type: ?[]const u8 = null,
    name: ?[]const u8 = null,
    size_bytes: ?u64 = null,
};

pub const Task = struct {
    id: []const u8 = "",
    title: []const u8,
    notes: ?[]const u8 = null,
    list_id: ?[]const u8 = null,
    priority: TaskPriority = .none,
    status: TaskStatus = .pending,
    due_date: ?i64 = null,
    start_date: ?i64 = null,
    completed_at: ?i64 = null,
    created_at: i64 = 0,
    modified_at: i64 = 0,
    recurrence: ?RecurrenceRule = null,
    reminders: []ReminderTrigger = &[_]ReminderTrigger{},
    subtasks: []Subtask = &[_]Subtask{},
    tags: [][]const u8 = &[_][]const u8{},
    attachments: []Attachment = &[_]Attachment{},
    url: ?[]const u8 = null,
    external_id: ?[]const u8 = null,

    const Self = @This();

    pub fn isOverdue(self: Self) bool {
        if (self.status.isDone()) return false;
        if (self.due_date) |due| {
            return getTimestampMs() > due;
        }
        return false;
    }

    pub fn isDueToday(self: Self) bool {
        if (self.due_date) |due| {
            const now = getTimestampMs();
            return DateUtils.isSameDay(now, due);
        }
        return false;
    }

    pub fn isDueSoon(self: Self, within_hours: u32) bool {
        if (self.status.isDone()) return false;
        if (self.due_date) |due| {
            const now = getTimestampMs();
            const threshold = now + @as(i64, within_hours) * 3600000;
            return due <= threshold and due > now;
        }
        return false;
    }

    pub fn complete(self: *Self) void {
        self.status = .completed;
        self.completed_at = getTimestampMs();
        self.modified_at = getTimestampMs();
    }

    pub fn uncomplete(self: *Self) void {
        self.status = .pending;
        self.completed_at = null;
        self.modified_at = getTimestampMs();
    }

    pub fn getProgress(self: Self) f32 {
        if (self.subtasks.len == 0) {
            return if (self.status == .completed) 1.0 else 0.0;
        }

        var completed: u32 = 0;
        for (self.subtasks) |subtask| {
            if (subtask.is_completed) completed += 1;
        }

        return @as(f32, @floatFromInt(completed)) / @as(f32, @floatFromInt(self.subtasks.len));
    }

    pub fn hasReminders(self: Self) bool {
        return self.reminders.len > 0;
    }

    pub fn hasRecurrence(self: Self) bool {
        return self.recurrence != null;
    }

    pub fn hasSubtasks(self: Self) bool {
        return self.subtasks.len > 0;
    }

    pub fn hasAttachments(self: Self) bool {
        return self.attachments.len > 0;
    }

    pub fn hasTags(self: Self) bool {
        return self.tags.len > 0;
    }

    pub fn hasTag(self: Self, tag: []const u8) bool {
        for (self.tags) |t| {
            if (std.mem.eql(u8, t, tag)) return true;
        }
        return false;
    }

    pub fn getNextReminder(self: Self) ?i64 {
        var earliest: ?i64 = null;
        const now = getTimestampMs();

        for (self.reminders) |reminder| {
            if (reminder.time) |time| {
                if (time > now) {
                    if (earliest) |e| {
                        if (time < e) earliest = time;
                    } else {
                        earliest = time;
                    }
                }
            }
        }

        return earliest;
    }
};

pub const TaskList = struct {
    id: []const u8 = "",
    name: []const u8,
    color: ?[]const u8 = null,
    icon: ?[]const u8 = null,
    is_default: bool = false,
    is_smart: bool = false,
    sort_order: u32 = 0,
    created_at: i64 = 0,
    modified_at: i64 = 0,
    task_count: u32 = 0,
    completed_count: u32 = 0,

    const Self = @This();

    pub fn getPendingCount(self: Self) u32 {
        if (self.task_count >= self.completed_count) {
            return self.task_count - self.completed_count;
        }
        return 0;
    }

    pub fn getCompletionPercentage(self: Self) f32 {
        if (self.task_count == 0) return 0.0;
        return @as(f32, @floatFromInt(self.completed_count)) / @as(f32, @floatFromInt(self.task_count)) * 100.0;
    }
};

pub const SmartListType = enum {
    today,
    scheduled,
    all,
    flagged,
    completed,
    assigned_to_me,
    overdue,

    pub fn toString(self: SmartListType) []const u8 {
        return switch (self) {
            .today => "Today",
            .scheduled => "Scheduled",
            .all => "All",
            .flagged => "Flagged",
            .completed => "Completed",
            .assigned_to_me => "Assigned to Me",
            .overdue => "Overdue",
        };
    }
};

// ============================================================================
// Task Store
// ============================================================================

pub const TaskStore = struct {
    allocator: Allocator,
    tasks: std.ArrayListUnmanaged(Task) = .{},
    lists: std.ArrayListUnmanaged(TaskList) = .{},
    change_history: std.ArrayListUnmanaged(TaskChange) = .{},
    authorization_status: AuthorizationStatus = .not_determined,

    pub const TaskChange = struct {
        task_id: []const u8,
        change_type: ChangeType,
        timestamp: i64,
        previous_value: ?[]const u8 = null,
        new_value: ?[]const u8 = null,

        pub const ChangeType = enum {
            created,
            updated,
            deleted,
            completed,
            uncompleted,
            moved,
        };
    };

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.tasks.deinit(self.allocator);
        self.lists.deinit(self.allocator);
        self.change_history.deinit(self.allocator);
    }

    pub fn requestAuthorization(self: *Self) !AuthorizationStatus {
        self.authorization_status = .authorized;
        return self.authorization_status;
    }

    pub fn isAuthorized(self: Self) bool {
        return self.authorization_status.isAuthorized();
    }

    pub fn addTask(self: *Self, task: Task) ![]const u8 {
        const now = getTimestampMs();
        const id = try std.fmt.allocPrint(self.allocator, "task_{d}", .{now});

        var new_task = task;
        new_task.id = id;
        new_task.created_at = now;
        new_task.modified_at = now;

        try self.tasks.append(self.allocator, new_task);

        try self.change_history.append(self.allocator, .{
            .task_id = id,
            .change_type = .created,
            .timestamp = now,
        });

        if (task.list_id) |list_id| {
            self.updateListCounts(list_id);
        }

        return id;
    }

    pub fn updateTask(self: *Self, task_id: []const u8, updates: TaskUpdates) !void {
        for (self.tasks.items) |*task| {
            if (std.mem.eql(u8, task.id, task_id)) {
                if (updates.title) |title| task.title = title;
                if (updates.notes) |notes| task.notes = notes;
                if (updates.priority) |priority| task.priority = priority;
                if (updates.status) |status| task.status = status;
                if (updates.due_date) |due_date| task.due_date = due_date;
                if (updates.recurrence) |recurrence| task.recurrence = recurrence;
                task.modified_at = getTimestampMs();

                try self.change_history.append(self.allocator, .{
                    .task_id = task_id,
                    .change_type = .updated,
                    .timestamp = getTimestampMs(),
                });
                return;
            }
        }
        return error.TaskNotFound;
    }

    pub fn deleteTask(self: *Self, task_id: []const u8) !void {
        for (self.tasks.items, 0..) |task, i| {
            if (std.mem.eql(u8, task.id, task_id)) {
                const list_id = task.list_id;
                _ = self.tasks.orderedRemove(i);

                try self.change_history.append(self.allocator, .{
                    .task_id = task_id,
                    .change_type = .deleted,
                    .timestamp = getTimestampMs(),
                });

                if (list_id) |lid| {
                    self.updateListCounts(lid);
                }
                return;
            }
        }
        return error.TaskNotFound;
    }

    pub fn completeTask(self: *Self, task_id: []const u8) !void {
        for (self.tasks.items) |*task| {
            if (std.mem.eql(u8, task.id, task_id)) {
                task.complete();

                try self.change_history.append(self.allocator, .{
                    .task_id = task_id,
                    .change_type = .completed,
                    .timestamp = getTimestampMs(),
                });

                if (task.list_id) |list_id| {
                    self.updateListCounts(list_id);
                }
                return;
            }
        }
        return error.TaskNotFound;
    }

    pub fn uncompleteTask(self: *Self, task_id: []const u8) !void {
        for (self.tasks.items) |*task| {
            if (std.mem.eql(u8, task.id, task_id)) {
                task.uncomplete();

                try self.change_history.append(self.allocator, .{
                    .task_id = task_id,
                    .change_type = .uncompleted,
                    .timestamp = getTimestampMs(),
                });

                if (task.list_id) |list_id| {
                    self.updateListCounts(list_id);
                }
                return;
            }
        }
        return error.TaskNotFound;
    }

    pub fn moveTask(self: *Self, task_id: []const u8, new_list_id: []const u8) !void {
        for (self.tasks.items) |*task| {
            if (std.mem.eql(u8, task.id, task_id)) {
                const old_list_id = task.list_id;
                task.list_id = new_list_id;
                task.modified_at = getTimestampMs();

                try self.change_history.append(self.allocator, .{
                    .task_id = task_id,
                    .change_type = .moved,
                    .timestamp = getTimestampMs(),
                    .previous_value = old_list_id,
                    .new_value = new_list_id,
                });

                if (old_list_id) |lid| {
                    self.updateListCounts(lid);
                }
                self.updateListCounts(new_list_id);
                return;
            }
        }
        return error.TaskNotFound;
    }

    pub fn getTask(self: Self, task_id: []const u8) ?*const Task {
        for (self.tasks.items) |*task| {
            if (std.mem.eql(u8, task.id, task_id)) return task;
        }
        return null;
    }

    pub fn getTasksForList(self: Self, list_id: []const u8) []const Task {
        _ = list_id;
        return self.tasks.items;
    }

    pub fn getAllTasks(self: Self) []const Task {
        return self.tasks.items;
    }

    pub fn getOverdueTasks(self: Self) !std.ArrayListUnmanaged(Task) {
        var result: std.ArrayListUnmanaged(Task) = .{};
        for (self.tasks.items) |task| {
            if (task.isOverdue()) {
                try result.append(self.allocator, task);
            }
        }
        return result;
    }

    pub fn getTodayTasks(self: Self) !std.ArrayListUnmanaged(Task) {
        var result: std.ArrayListUnmanaged(Task) = .{};
        for (self.tasks.items) |task| {
            if (task.isDueToday() and !task.status.isDone()) {
                try result.append(self.allocator, task);
            }
        }
        return result;
    }

    pub fn searchTasks(self: Self, query: []const u8) !std.ArrayListUnmanaged(Task) {
        var result: std.ArrayListUnmanaged(Task) = .{};
        const lower_query = std.ascii.lowerString(@constCast(query[0..]), query);

        for (self.tasks.items) |task| {
            var title_lower: [256]u8 = undefined;
            const title_len = @min(task.title.len, 256);
            _ = std.ascii.lowerString(title_lower[0..title_len], task.title[0..title_len]);

            if (std.mem.indexOf(u8, title_lower[0..title_len], lower_query) != null) {
                try result.append(self.allocator, task);
                continue;
            }

            if (task.notes) |notes| {
                var notes_lower: [512]u8 = undefined;
                const notes_len = @min(notes.len, 512);
                _ = std.ascii.lowerString(notes_lower[0..notes_len], notes[0..notes_len]);

                if (std.mem.indexOf(u8, notes_lower[0..notes_len], lower_query) != null) {
                    try result.append(self.allocator, task);
                }
            }
        }
        return result;
    }

    pub fn addList(self: *Self, list: TaskList) ![]const u8 {
        const now = getTimestampMs();
        const id = try std.fmt.allocPrint(self.allocator, "list_{d}", .{now});

        var new_list = list;
        new_list.id = id;
        new_list.created_at = now;
        new_list.modified_at = now;

        try self.lists.append(self.allocator, new_list);
        return id;
    }

    pub fn updateList(self: *Self, list_id: []const u8, updates: ListUpdates) !void {
        for (self.lists.items) |*list| {
            if (std.mem.eql(u8, list.id, list_id)) {
                if (updates.name) |name| list.name = name;
                if (updates.color) |color| list.color = color;
                if (updates.icon) |icon| list.icon = icon;
                list.modified_at = getTimestampMs();
                return;
            }
        }
        return error.ListNotFound;
    }

    pub fn deleteList(self: *Self, list_id: []const u8) !void {
        for (self.lists.items, 0..) |list, i| {
            if (std.mem.eql(u8, list.id, list_id)) {
                _ = self.lists.orderedRemove(i);
                return;
            }
        }
        return error.ListNotFound;
    }

    pub fn getList(self: Self, list_id: []const u8) ?*const TaskList {
        for (self.lists.items) |*list| {
            if (std.mem.eql(u8, list.id, list_id)) return list;
        }
        return null;
    }

    pub fn getAllLists(self: Self) []const TaskList {
        return self.lists.items;
    }

    pub fn getTaskCount(self: Self) usize {
        return self.tasks.items.len;
    }

    pub fn getCompletedTaskCount(self: Self) usize {
        var count: usize = 0;
        for (self.tasks.items) |task| {
            if (task.status == .completed) count += 1;
        }
        return count;
    }

    pub fn getPendingTaskCount(self: Self) usize {
        var count: usize = 0;
        for (self.tasks.items) |task| {
            if (task.status.isActive()) count += 1;
        }
        return count;
    }

    fn updateListCounts(self: *Self, list_id: []const u8) void {
        var total: u32 = 0;
        var completed: u32 = 0;

        for (self.tasks.items) |task| {
            if (task.list_id) |lid| {
                if (std.mem.eql(u8, lid, list_id)) {
                    total += 1;
                    if (task.status == .completed) completed += 1;
                }
            }
        }

        for (self.lists.items) |*list| {
            if (std.mem.eql(u8, list.id, list_id)) {
                list.task_count = total;
                list.completed_count = completed;
                break;
            }
        }
    }
};

pub const TaskUpdates = struct {
    title: ?[]const u8 = null,
    notes: ?[]const u8 = null,
    priority: ?TaskPriority = null,
    status: ?TaskStatus = null,
    due_date: ?i64 = null,
    start_date: ?i64 = null,
    recurrence: ?RecurrenceRule = null,
};

pub const ListUpdates = struct {
    name: ?[]const u8 = null,
    color: ?[]const u8 = null,
    icon: ?[]const u8 = null,
};

// ============================================================================
// Task Builder
// ============================================================================

pub const TaskBuilder = struct {
    allocator: Allocator,
    task: Task,
    reminders_list: std.ArrayListUnmanaged(ReminderTrigger) = .{},
    subtasks_list: std.ArrayListUnmanaged(Subtask) = .{},
    tags_list: std.ArrayListUnmanaged([]const u8) = .{},

    const Self = @This();

    pub fn init(allocator: Allocator, title: []const u8) Self {
        return .{
            .allocator = allocator,
            .task = .{ .title = title },
        };
    }

    pub fn deinit(self: *Self) void {
        self.reminders_list.deinit(self.allocator);
        self.subtasks_list.deinit(self.allocator);
        self.tags_list.deinit(self.allocator);
    }

    pub fn withNotes(self: *Self, notes: []const u8) *Self {
        self.task.notes = notes;
        return self;
    }

    pub fn withPriority(self: *Self, priority: TaskPriority) *Self {
        self.task.priority = priority;
        return self;
    }

    pub fn withDueDate(self: *Self, due_date: i64) *Self {
        self.task.due_date = due_date;
        return self;
    }

    pub fn withStartDate(self: *Self, start_date: i64) *Self {
        self.task.start_date = start_date;
        return self;
    }

    pub fn withList(self: *Self, list_id: []const u8) *Self {
        self.task.list_id = list_id;
        return self;
    }

    pub fn withRecurrence(self: *Self, recurrence: RecurrenceRule) *Self {
        self.task.recurrence = recurrence;
        return self;
    }

    pub fn addReminder(self: *Self, trigger: ReminderTrigger) !*Self {
        try self.reminders_list.append(self.allocator, trigger);
        return self;
    }

    pub fn addSubtask(self: *Self, title: []const u8) !*Self {
        try self.subtasks_list.append(self.allocator, .{ .title = title });
        return self;
    }

    pub fn addTag(self: *Self, tag: []const u8) !*Self {
        try self.tags_list.append(self.allocator, tag);
        return self;
    }

    pub fn withUrl(self: *Self, url: []const u8) *Self {
        self.task.url = url;
        return self;
    }

    pub fn build(self: *Self) Task {
        if (self.reminders_list.items.len > 0) {
            self.task.reminders = self.reminders_list.items;
        }
        if (self.subtasks_list.items.len > 0) {
            self.task.subtasks = self.subtasks_list.items;
        }
        if (self.tags_list.items.len > 0) {
            self.task.tags = self.tags_list.items;
        }
        return self.task;
    }
};

// ============================================================================
// Date Utilities
// ============================================================================

pub const DateUtils = struct {
    const day_ms: i64 = 86400000;

    pub fn startOfDay(timestamp: i64) i64 {
        return timestamp - @mod(timestamp, day_ms);
    }

    pub fn endOfDay(timestamp: i64) i64 {
        return startOfDay(timestamp) + day_ms - 1;
    }

    pub fn isSameDay(ts1: i64, ts2: i64) bool {
        return startOfDay(ts1) == startOfDay(ts2);
    }

    pub fn addDays(timestamp: i64, days: i32) i64 {
        return timestamp + @as(i64, days) * day_ms;
    }

    pub fn addWeeks(timestamp: i64, weeks: i32) i64 {
        return timestamp + @as(i64, weeks) * day_ms * 7;
    }

    pub fn addMonths(timestamp: i64, months: i32) i64 {
        return timestamp + @as(i64, months) * day_ms * 30;
    }

    pub fn getDayOfWeek(timestamp: i64) DayOfWeek {
        const days_since_epoch = @divFloor(timestamp, day_ms);
        const dow = @mod(days_since_epoch + 4, 7);
        return @enumFromInt(@as(u8, @intCast(dow)));
    }

    pub fn isWeekend(timestamp: i64) bool {
        const dow = getDayOfWeek(timestamp);
        return dow == .saturday or dow == .sunday;
    }

    pub fn isWeekday(timestamp: i64) bool {
        return !isWeekend(timestamp);
    }

    pub fn daysBetween(ts1: i64, ts2: i64) i64 {
        return @divFloor(ts2 - ts1, day_ms);
    }

    pub fn getNextWeekday(timestamp: i64, target: DayOfWeek) i64 {
        const current = getDayOfWeek(timestamp);
        var days_to_add: i32 = @as(i32, target.toValue()) - @as(i32, current.toValue());
        if (days_to_add <= 0) days_to_add += 7;
        return addDays(timestamp, days_to_add);
    }
};

// ============================================================================
// Export Utilities
// ============================================================================

pub const VTodoGenerator = struct {
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn generate(self: Self, task: Task) ![]const u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .{};
        errdefer buffer.deinit(self.allocator);

        try buffer.appendSlice(self.allocator, "BEGIN:VTODO\r\n");

        const uid_line = try std.fmt.allocPrint(self.allocator, "UID:{s}\r\n", .{task.id});
        defer self.allocator.free(uid_line);
        try buffer.appendSlice(self.allocator, uid_line);

        const summary_line = try std.fmt.allocPrint(self.allocator, "SUMMARY:{s}\r\n", .{task.title});
        defer self.allocator.free(summary_line);
        try buffer.appendSlice(self.allocator, summary_line);

        if (task.notes) |notes| {
            const desc_line = try std.fmt.allocPrint(self.allocator, "DESCRIPTION:{s}\r\n", .{notes});
            defer self.allocator.free(desc_line);
            try buffer.appendSlice(self.allocator, desc_line);
        }

        const prio_line = try std.fmt.allocPrint(self.allocator, "PRIORITY:{d}\r\n", .{task.priority.toValue()});
        defer self.allocator.free(prio_line);
        try buffer.appendSlice(self.allocator, prio_line);

        if (task.due_date) |due| {
            const due_line = try std.fmt.allocPrint(self.allocator, "DUE:{d}\r\n", .{due});
            defer self.allocator.free(due_line);
            try buffer.appendSlice(self.allocator, due_line);
        }

        if (task.status == .completed) {
            try buffer.appendSlice(self.allocator, "STATUS:COMPLETED\r\n");
            if (task.completed_at) |completed| {
                const comp_line = try std.fmt.allocPrint(self.allocator, "COMPLETED:{d}\r\n", .{completed});
                defer self.allocator.free(comp_line);
                try buffer.appendSlice(self.allocator, comp_line);
            }
        } else {
            try buffer.appendSlice(self.allocator, "STATUS:NEEDS-ACTION\r\n");
        }

        try buffer.appendSlice(self.allocator, "END:VTODO\r\n");

        return buffer.toOwnedSlice(self.allocator);
    }
};

// ============================================================================
// Helper Functions
// ============================================================================

fn getTimestampMs() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
    }
    return 0;
}

// ============================================================================
// Tests
// ============================================================================

test "TaskPriority values" {
    try std.testing.expectEqual(@as(u8, 0), TaskPriority.none.toValue());
    try std.testing.expectEqual(@as(u8, 1), TaskPriority.low.toValue());
    try std.testing.expectEqual(@as(u8, 5), TaskPriority.medium.toValue());
    try std.testing.expectEqual(@as(u8, 9), TaskPriority.high.toValue());
}

test "TaskPriority fromValue" {
    try std.testing.expectEqual(TaskPriority.none, TaskPriority.fromValue(0));
    try std.testing.expectEqual(TaskPriority.low, TaskPriority.fromValue(2));
    try std.testing.expectEqual(TaskPriority.medium, TaskPriority.fromValue(5));
    try std.testing.expectEqual(TaskPriority.high, TaskPriority.fromValue(9));
}

test "TaskStatus isActive" {
    try std.testing.expect(TaskStatus.pending.isActive());
    try std.testing.expect(TaskStatus.in_progress.isActive());
    try std.testing.expect(!TaskStatus.completed.isActive());
    try std.testing.expect(!TaskStatus.cancelled.isActive());
}

test "TaskStatus isDone" {
    try std.testing.expect(!TaskStatus.pending.isDone());
    try std.testing.expect(TaskStatus.completed.isDone());
    try std.testing.expect(TaskStatus.cancelled.isDone());
}

test "DayOfWeek values" {
    try std.testing.expectEqual(@as(u8, 0), DayOfWeek.sunday.toValue());
    try std.testing.expectEqual(@as(u8, 1), DayOfWeek.monday.toValue());
    try std.testing.expectEqual(@as(u8, 6), DayOfWeek.saturday.toValue());
}

test "DayOfWeek names" {
    try std.testing.expectEqualStrings("Monday", DayOfWeek.monday.toString());
    try std.testing.expectEqualStrings("Mon", DayOfWeek.monday.shortName());
}

test "RecurrenceRule daily" {
    const rule = RecurrenceRule.daily(1);
    try std.testing.expectEqual(RecurrenceFrequency.daily, rule.frequency);
    try std.testing.expectEqual(@as(u32, 1), rule.interval);
}

test "RecurrenceRule weekly" {
    const rule = RecurrenceRule.weekly(2);
    try std.testing.expectEqual(RecurrenceFrequency.weekly, rule.frequency);
    try std.testing.expectEqual(@as(u32, 2), rule.interval);
}

test "RecurrenceRule withCount" {
    const rule = RecurrenceRule.daily(1).withCount(10);
    try std.testing.expectEqual(@as(?u32, 10), rule.count);
}

test "RecurrenceRule getNextOccurrence" {
    const rule = RecurrenceRule.daily(1);
    const base_time: i64 = 1000000000;
    const next = rule.getNextOccurrence(base_time);
    try std.testing.expectEqual(@as(?i64, base_time + 86400000), next);
}

test "ReminderTrigger atTime" {
    const trigger = ReminderTrigger.atTime(1000000000);
    try std.testing.expectEqual(ReminderTriggerType.time, trigger.trigger_type);
    try std.testing.expectEqual(@as(?i64, 1000000000), trigger.time);
    try std.testing.expect(trigger.isTimeBased());
    try std.testing.expect(!trigger.isLocationBased());
}

test "ReminderTrigger location based" {
    const trigger = ReminderTrigger.onEnterLocation(37.7749, -122.4194, 100.0);
    try std.testing.expectEqual(ReminderTriggerType.location_enter, trigger.trigger_type);
    try std.testing.expect(trigger.isLocationBased());
    try std.testing.expect(!trigger.isTimeBased());
}

test "Subtask complete/uncomplete" {
    var subtask = Subtask{ .title = "Test subtask" };

    try std.testing.expect(!subtask.is_completed);
    try std.testing.expect(subtask.completed_at == null);

    subtask.complete();
    try std.testing.expect(subtask.is_completed);
    try std.testing.expect(subtask.completed_at != null);

    subtask.uncomplete();
    try std.testing.expect(!subtask.is_completed);
    try std.testing.expect(subtask.completed_at == null);
}

test "Task complete/uncomplete" {
    var task = Task{ .title = "Test task" };

    try std.testing.expectEqual(TaskStatus.pending, task.status);

    task.complete();
    try std.testing.expectEqual(TaskStatus.completed, task.status);
    try std.testing.expect(task.completed_at != null);

    task.uncomplete();
    try std.testing.expectEqual(TaskStatus.pending, task.status);
    try std.testing.expect(task.completed_at == null);
}

test "Task progress with no subtasks" {
    var task = Task{ .title = "Test task" };
    try std.testing.expectEqual(@as(f32, 0.0), task.getProgress());

    task.complete();
    try std.testing.expectEqual(@as(f32, 1.0), task.getProgress());
}

test "Task progress with subtasks" {
    const subtasks = [_]Subtask{
        .{ .title = "Sub 1", .is_completed = true },
        .{ .title = "Sub 2", .is_completed = false },
        .{ .title = "Sub 3", .is_completed = true },
        .{ .title = "Sub 4", .is_completed = false },
    };

    const task = Task{
        .title = "Test task",
        .subtasks = @constCast(&subtasks),
    };

    try std.testing.expectEqual(@as(f32, 0.5), task.getProgress());
}

test "Task hasTag" {
    const tags = [_][]const u8{ "work", "urgent", "project" };
    const task = Task{
        .title = "Test task",
        .tags = @constCast(&tags),
    };

    try std.testing.expect(task.hasTag("work"));
    try std.testing.expect(task.hasTag("urgent"));
    try std.testing.expect(!task.hasTag("personal"));
}

test "Task property checks" {
    const task1 = Task{ .title = "Basic task" };
    try std.testing.expect(!task1.hasReminders());
    try std.testing.expect(!task1.hasRecurrence());
    try std.testing.expect(!task1.hasSubtasks());
    try std.testing.expect(!task1.hasTags());

    const task2 = Task{
        .title = "Complex task",
        .recurrence = RecurrenceRule.daily(1),
        .reminders = @constCast(&[_]ReminderTrigger{.{ .trigger_type = .time, .time = 1000 }}),
    };
    try std.testing.expect(task2.hasReminders());
    try std.testing.expect(task2.hasRecurrence());
}

test "TaskList pending count" {
    const list = TaskList{
        .name = "Test List",
        .task_count = 10,
        .completed_count = 3,
    };

    try std.testing.expectEqual(@as(u32, 7), list.getPendingCount());
}

test "TaskList completion percentage" {
    const list = TaskList{
        .name = "Test List",
        .task_count = 4,
        .completed_count = 1,
    };

    try std.testing.expectEqual(@as(f32, 25.0), list.getCompletionPercentage());
}

test "TaskList completion percentage empty" {
    const list = TaskList{
        .name = "Empty List",
        .task_count = 0,
        .completed_count = 0,
    };

    try std.testing.expectEqual(@as(f32, 0.0), list.getCompletionPercentage());
}

test "SmartListType toString" {
    try std.testing.expectEqualStrings("Today", SmartListType.today.toString());
    try std.testing.expectEqualStrings("Overdue", SmartListType.overdue.toString());
}

test "TaskStore initialization" {
    var store = TaskStore.init(std.testing.allocator);
    defer store.deinit();

    try std.testing.expectEqual(@as(usize, 0), store.getTaskCount());
    try std.testing.expectEqual(AuthorizationStatus.not_determined, store.authorization_status);
}

test "TaskStore authorization" {
    var store = TaskStore.init(std.testing.allocator);
    defer store.deinit();

    try std.testing.expect(!store.isAuthorized());

    const status = try store.requestAuthorization();
    try std.testing.expectEqual(AuthorizationStatus.authorized, status);
    try std.testing.expect(store.isAuthorized());
}

test "TaskStore add task" {
    var store = TaskStore.init(std.testing.allocator);
    defer store.deinit();

    const task = Task{ .title = "Test task" };
    _ = try store.addTask(task);

    try std.testing.expectEqual(@as(usize, 1), store.getTaskCount());
}

test "TaskStore complete task" {
    var store = TaskStore.init(std.testing.allocator);
    defer store.deinit();

    const task = Task{ .title = "Test task" };
    const id = try store.addTask(task);

    try store.completeTask(id);

    const updated = store.getTask(id);
    try std.testing.expect(updated != null);
    try std.testing.expectEqual(TaskStatus.completed, updated.?.status);
}

test "TaskStore uncomplete task" {
    var store = TaskStore.init(std.testing.allocator);
    defer store.deinit();

    const task = Task{ .title = "Test task" };
    const id = try store.addTask(task);

    try store.completeTask(id);
    try store.uncompleteTask(id);

    const updated = store.getTask(id);
    try std.testing.expectEqual(TaskStatus.pending, updated.?.status);
}

test "TaskStore delete task" {
    var store = TaskStore.init(std.testing.allocator);
    defer store.deinit();

    const task = Task{ .title = "Test task" };
    const id = try store.addTask(task);

    try store.deleteTask(id);
    try std.testing.expectEqual(@as(usize, 0), store.getTaskCount());
}

test "TaskStore delete non-existent task" {
    var store = TaskStore.init(std.testing.allocator);
    defer store.deinit();

    const result = store.deleteTask("non-existent");
    try std.testing.expectError(error.TaskNotFound, result);
}

test "TaskStore update task" {
    var store = TaskStore.init(std.testing.allocator);
    defer store.deinit();

    const task = Task{ .title = "Original title" };
    const id = try store.addTask(task);

    try store.updateTask(id, .{ .title = "Updated title", .priority = .high });

    const updated = store.getTask(id);
    try std.testing.expect(updated != null);
    try std.testing.expectEqualStrings("Updated title", updated.?.title);
    try std.testing.expectEqual(TaskPriority.high, updated.?.priority);
}

test "TaskStore add list" {
    var store = TaskStore.init(std.testing.allocator);
    defer store.deinit();

    const list = TaskList{ .name = "Work" };
    _ = try store.addList(list);

    try std.testing.expectEqual(@as(usize, 1), store.getAllLists().len);
}

test "TaskStore delete list" {
    var store = TaskStore.init(std.testing.allocator);
    defer store.deinit();

    const list = TaskList{ .name = "Work" };
    const id = try store.addList(list);

    try store.deleteList(id);
    try std.testing.expectEqual(@as(usize, 0), store.getAllLists().len);
}

test "TaskStore task counts" {
    var store = TaskStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.addTask(.{ .title = "Task 1" });
    _ = try store.addTask(.{ .title = "Task 2" });
    const id3 = try store.addTask(.{ .title = "Task 3" });

    try store.completeTask(id3);

    try std.testing.expectEqual(@as(usize, 3), store.getTaskCount());
    try std.testing.expectEqual(@as(usize, 1), store.getCompletedTaskCount());
    try std.testing.expectEqual(@as(usize, 2), store.getPendingTaskCount());
}

test "TaskBuilder basic" {
    var builder = TaskBuilder.init(std.testing.allocator, "Test task");
    defer builder.deinit();

    _ = builder.withNotes("Some notes").withPriority(.high);

    const task = builder.build();

    try std.testing.expectEqualStrings("Test task", task.title);
    try std.testing.expectEqualStrings("Some notes", task.notes.?);
    try std.testing.expectEqual(TaskPriority.high, task.priority);
}

test "TaskBuilder with subtasks" {
    var builder = TaskBuilder.init(std.testing.allocator, "Test task");
    defer builder.deinit();

    _ = try builder.addSubtask("Subtask 1");
    _ = try builder.addSubtask("Subtask 2");

    const task = builder.build();

    try std.testing.expect(task.hasSubtasks());
    try std.testing.expectEqual(@as(usize, 2), task.subtasks.len);
}

test "TaskBuilder with tags" {
    var builder = TaskBuilder.init(std.testing.allocator, "Test task");
    defer builder.deinit();

    _ = try builder.addTag("work");
    _ = try builder.addTag("urgent");

    const task = builder.build();

    try std.testing.expect(task.hasTags());
    try std.testing.expectEqual(@as(usize, 2), task.tags.len);
}

test "TaskBuilder with reminders" {
    var builder = TaskBuilder.init(std.testing.allocator, "Test task");
    defer builder.deinit();

    _ = try builder.addReminder(ReminderTrigger.atTime(1000000));

    const task = builder.build();

    try std.testing.expect(task.hasReminders());
    try std.testing.expectEqual(@as(usize, 1), task.reminders.len);
}

test "DateUtils startOfDay" {
    const timestamp: i64 = 86400000 + 3600000;
    const start = DateUtils.startOfDay(timestamp);
    try std.testing.expectEqual(@as(i64, 86400000), start);
}

test "DateUtils isSameDay" {
    const ts1: i64 = 86400000 + 1000;
    const ts2: i64 = 86400000 + 50000000;
    const ts3: i64 = 86400000 * 2 + 1000;

    try std.testing.expect(DateUtils.isSameDay(ts1, ts2));
    try std.testing.expect(!DateUtils.isSameDay(ts1, ts3));
}

test "DateUtils addDays" {
    const base: i64 = 1000000000;
    const result = DateUtils.addDays(base, 5);
    try std.testing.expectEqual(@as(i64, base + 86400000 * 5), result);
}

test "DateUtils getDayOfWeek" {
    const thursday_epoch: i64 = 0;
    try std.testing.expectEqual(DayOfWeek.thursday, DateUtils.getDayOfWeek(thursday_epoch));
}

test "DateUtils isWeekend" {
    const saturday: i64 = 86400000 * 2;
    const sunday: i64 = 86400000 * 3;
    const monday: i64 = 86400000 * 4;

    try std.testing.expect(DateUtils.isWeekend(saturday));
    try std.testing.expect(DateUtils.isWeekend(sunday));
    try std.testing.expect(!DateUtils.isWeekend(monday));
}

test "DateUtils daysBetween" {
    const ts1: i64 = 0;
    const ts2: i64 = 86400000 * 5;
    try std.testing.expectEqual(@as(i64, 5), DateUtils.daysBetween(ts1, ts2));
}

test "VTodoGenerator generate" {
    const generator = VTodoGenerator.init(std.testing.allocator);

    const task = Task{
        .id = "task-123",
        .title = "Test Task",
        .notes = "Test notes",
        .priority = .high,
    };

    const vtodo = try generator.generate(task);
    defer std.testing.allocator.free(vtodo);

    try std.testing.expect(std.mem.indexOf(u8, vtodo, "BEGIN:VTODO") != null);
    try std.testing.expect(std.mem.indexOf(u8, vtodo, "SUMMARY:Test Task") != null);
    try std.testing.expect(std.mem.indexOf(u8, vtodo, "END:VTODO") != null);
}

test "AuthorizationStatus isAuthorized" {
    try std.testing.expect(!AuthorizationStatus.not_determined.isAuthorized());
    try std.testing.expect(!AuthorizationStatus.denied.isAuthorized());
    try std.testing.expect(AuthorizationStatus.authorized.isAuthorized());
    try std.testing.expect(AuthorizationStatus.authorized_full.isAuthorized());
}

test "TaskStore move task" {
    var store = TaskStore.init(std.testing.allocator);
    defer store.deinit();

    const list1_id = try store.addList(.{ .name = "List 1" });
    const list2_id = try store.addList(.{ .name = "List 2" });

    const task = Task{ .title = "Test task", .list_id = list1_id };
    const task_id = try store.addTask(task);

    try store.moveTask(task_id, list2_id);

    const updated = store.getTask(task_id);
    try std.testing.expect(updated != null);
    try std.testing.expectEqualStrings(list2_id, updated.?.list_id.?);
}

test "TaskStore change history" {
    var store = TaskStore.init(std.testing.allocator);
    defer store.deinit();

    const task = Task{ .title = "Test task" };
    const id = try store.addTask(task);

    try store.completeTask(id);

    try std.testing.expectEqual(@as(usize, 2), store.change_history.items.len);
    try std.testing.expectEqual(TaskStore.TaskChange.ChangeType.created, store.change_history.items[0].change_type);
    try std.testing.expectEqual(TaskStore.TaskChange.ChangeType.completed, store.change_history.items[1].change_type);
}

test "RecurrenceFrequency toString" {
    try std.testing.expectEqualStrings("daily", RecurrenceFrequency.daily.toString());
    try std.testing.expectEqualStrings("weekly", RecurrenceFrequency.weekly.toString());
    try std.testing.expectEqualStrings("monthly", RecurrenceFrequency.monthly.toString());
}

test "ReminderTriggerType toString" {
    try std.testing.expectEqualStrings("time", ReminderTriggerType.time.toString());
    try std.testing.expectEqualStrings("location_enter", ReminderTriggerType.location_enter.toString());
}

test "Task isDueSoon" {
    const now = getTimestampMs();
    var task = Task{
        .title = "Test",
        .due_date = now + 1800000,
    };

    try std.testing.expect(task.isDueSoon(1));
    try std.testing.expect(!task.isDueSoon(0));

    task.status = .completed;
    try std.testing.expect(!task.isDueSoon(24));
}
