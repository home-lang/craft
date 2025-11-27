const std = @import("std");
const windows = std.os.windows;

// ============================================
// Windows Type Definitions
// ============================================

pub const HWND = windows.HWND;
pub const HICON = *opaque {};
pub const HINSTANCE = windows.HINSTANCE;
pub const HRESULT = windows.HRESULT;
pub const BOOL = windows.BOOL;
pub const DWORD = windows.DWORD;
pub const UINT = c_uint;
pub const WPARAM = windows.WPARAM;
pub const LPARAM = windows.LPARAM;
pub const LPCWSTR = [*:0]const u16;
pub const LPWSTR = [*:0]u16;
pub const GUID = windows.GUID;
pub const RECT = windows.RECT;

// ============================================
// Jump List Support
// ============================================

pub const JumpListItem = struct {
    title: []const u8,
    description: ?[]const u8,
    icon_path: ?[]const u8,
    icon_index: i32,
    arguments: ?[]const u8,
    working_directory: ?[]const u8,
};

pub const JumpListCategory = struct {
    title: []const u8,
    items: []const JumpListItem,
};

pub const JumpList = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    app_id: []const u8,
    categories: std.ArrayList(JumpListCategory),
    recent_items: std.ArrayList(JumpListItem),
    frequent_items: std.ArrayList(JumpListItem),
    tasks: std.ArrayList(JumpListItem),

    pub fn init(allocator: std.mem.Allocator, app_id: []const u8) Self {
        return Self{
            .allocator = allocator,
            .app_id = app_id,
            .categories = std.ArrayList(JumpListCategory).init(allocator),
            .recent_items = std.ArrayList(JumpListItem).init(allocator),
            .frequent_items = std.ArrayList(JumpListItem).init(allocator),
            .tasks = std.ArrayList(JumpListItem).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.categories.deinit();
        self.recent_items.deinit();
        self.frequent_items.deinit();
        self.tasks.deinit();
    }

    pub fn addCategory(self: *Self, category: JumpListCategory) !void {
        try self.categories.append(category);
    }

    pub fn addTask(self: *Self, item: JumpListItem) !void {
        try self.tasks.append(item);
    }

    pub fn addRecentItem(self: *Self, item: JumpListItem) !void {
        try self.recent_items.append(item);
    }

    pub fn addFrequentItem(self: *Self, item: JumpListItem) !void {
        try self.frequent_items.append(item);
    }

    pub fn clear(self: *Self) void {
        self.categories.clearRetainingCapacity();
        self.recent_items.clearRetainingCapacity();
        self.frequent_items.clearRetainingCapacity();
        self.tasks.clearRetainingCapacity();
    }

    /// Commit the jump list to Windows
    pub fn commit(self: *Self) !void {
        // This would call ICustomDestinationList COM interface
        // Implementation requires COM initialization
        _ = self;
    }
};

// ============================================
// Taskbar Progress
// ============================================

pub const TaskbarProgressState = enum(c_int) {
    no_progress = 0,
    indeterminate = 1,
    normal = 2,
    error_state = 4,
    paused = 8,
};

pub const TaskbarProgress = struct {
    const Self = @This();

    hwnd: HWND,

    pub fn init(hwnd: HWND) Self {
        return Self{ .hwnd = hwnd };
    }

    pub fn setState(self: *Self, state: TaskbarProgressState) void {
        // Would call ITaskbarList3::SetProgressState
        _ = self;
        _ = state;
    }

    pub fn setValue(self: *Self, completed: u64, total: u64) void {
        // Would call ITaskbarList3::SetProgressValue
        _ = self;
        _ = completed;
        _ = total;
    }

    pub fn setOverlayIcon(self: *Self, icon: ?HICON, description: ?LPCWSTR) void {
        // Would call ITaskbarList3::SetOverlayIcon
        _ = self;
        _ = icon;
        _ = description;
    }

    pub fn flash(self: *Self, count: u32) void {
        // Would call FlashWindowEx
        _ = self;
        _ = count;
    }
};

// ============================================
// Toast Notifications (Windows 10+)
// ============================================

pub const ToastNotification = struct {
    const Self = @This();

    app_id: []const u8,
    title: []const u8,
    body: []const u8,
    image_path: ?[]const u8,
    hero_image_path: ?[]const u8,
    attribution_text: ?[]const u8,
    actions: std.ArrayList(ToastAction),
    audio: ?ToastAudio,
    scenario: ToastScenario,
    duration: ToastDuration,
    allocator: std.mem.Allocator,

    pub const ToastAction = struct {
        content: []const u8,
        arguments: []const u8,
        action_type: ActionType,

        pub const ActionType = enum {
            button,
            text_input,
            selection_input,
        };
    };

    pub const ToastAudio = struct {
        src: []const u8,
        loop: bool,
        silent: bool,
    };

    pub const ToastScenario = enum {
        default,
        alarm,
        reminder,
        incoming_call,
        urgent,
    };

    pub const ToastDuration = enum {
        short,
        long,
    };

    pub fn init(allocator: std.mem.Allocator, app_id: []const u8) Self {
        return Self{
            .app_id = app_id,
            .title = "",
            .body = "",
            .image_path = null,
            .hero_image_path = null,
            .attribution_text = null,
            .actions = std.ArrayList(ToastAction).init(allocator),
            .audio = null,
            .scenario = .default,
            .duration = .short,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.actions.deinit();
    }

    pub fn setTitle(self: *Self, title: []const u8) void {
        self.title = title;
    }

    pub fn setBody(self: *Self, body: []const u8) void {
        self.body = body;
    }

    pub fn setImage(self: *Self, path: []const u8) void {
        self.image_path = path;
    }

    pub fn setHeroImage(self: *Self, path: []const u8) void {
        self.hero_image_path = path;
    }

    pub fn addAction(self: *Self, action: ToastAction) !void {
        try self.actions.append(action);
    }

    pub fn setAudio(self: *Self, audio: ToastAudio) void {
        self.audio = audio;
    }

    pub fn setScenario(self: *Self, scenario: ToastScenario) void {
        self.scenario = scenario;
    }

    pub fn setDuration(self: *Self, duration: ToastDuration) void {
        self.duration = duration;
    }

    /// Show the notification
    pub fn show(self: *Self) !void {
        // Would use Windows.UI.Notifications API via WinRT
        _ = self;
    }

    /// Build XML for the toast
    pub fn buildXml(self: *Self, allocator: std.mem.Allocator) ![]u8 {
        var xml = std.ArrayList(u8).init(allocator);
        const writer = xml.writer();

        try writer.writeAll("<toast");
        if (self.scenario != .default) {
            try writer.print(" scenario=\"{s}\"", .{@tagName(self.scenario)});
        }
        if (self.duration == .long) {
            try writer.writeAll(" duration=\"long\"");
        }
        try writer.writeAll(">\n");

        try writer.writeAll("  <visual>\n");
        try writer.writeAll("    <binding template=\"ToastGeneric\">\n");

        if (self.title.len > 0) {
            try writer.print("      <text>{s}</text>\n", .{self.title});
        }
        if (self.body.len > 0) {
            try writer.print("      <text>{s}</text>\n", .{self.body});
        }
        if (self.attribution_text) |attr| {
            try writer.print("      <text placement=\"attribution\">{s}</text>\n", .{attr});
        }
        if (self.image_path) |img| {
            try writer.print("      <image placement=\"appLogoOverride\" src=\"{s}\"/>\n", .{img});
        }
        if (self.hero_image_path) |hero| {
            try writer.print("      <image placement=\"hero\" src=\"{s}\"/>\n", .{hero});
        }

        try writer.writeAll("    </binding>\n");
        try writer.writeAll("  </visual>\n");

        if (self.actions.items.len > 0) {
            try writer.writeAll("  <actions>\n");
            for (self.actions.items) |action| {
                switch (action.action_type) {
                    .button => {
                        try writer.print("    <action content=\"{s}\" arguments=\"{s}\"/>\n", .{ action.content, action.arguments });
                    },
                    .text_input => {
                        try writer.print("    <input id=\"{s}\" type=\"text\" placeHolderContent=\"{s}\"/>\n", .{ action.arguments, action.content });
                    },
                    .selection_input => {
                        try writer.writeAll("    <input id=\"selection\" type=\"selection\">\n");
                        try writer.writeAll("    </input>\n");
                    },
                }
            }
            try writer.writeAll("  </actions>\n");
        }

        if (self.audio) |audio| {
            try writer.print("  <audio src=\"{s}\"", .{audio.src});
            if (audio.loop) try writer.writeAll(" loop=\"true\"");
            if (audio.silent) try writer.writeAll(" silent=\"true\"");
            try writer.writeAll("/>\n");
        }

        try writer.writeAll("</toast>");

        return xml.toOwnedSlice();
    }
};

// ============================================
// Windows Theme Support
// ============================================

pub const WindowsTheme = struct {
    const HKEY_CURRENT_USER = @as(*anyopaque, @ptrFromInt(0x80000001));
    const PERSONALIZE_KEY = "Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";

    pub const Theme = enum {
        light,
        dark,
        system,
    };

    pub const AccentColor = struct {
        r: u8,
        g: u8,
        b: u8,
        a: u8,
    };

    /// Check if dark mode is enabled
    pub fn isDarkMode() bool {
        // Would read from registry:
        // HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize
        // AppsUseLightTheme = 0 means dark mode
        return false;
    }

    /// Get the system accent color
    pub fn getAccentColor() AccentColor {
        // Would call DwmGetColorizationColor or read from registry
        return AccentColor{ .r = 0, .g = 120, .b = 215, .a = 255 };
    }

    /// Check if transparency effects are enabled
    pub fn isTransparencyEnabled() bool {
        // Would read from registry EnableTransparency
        return true;
    }

    /// Apply immersive dark mode to a window (Windows 10 1809+)
    pub fn setImmersiveDarkMode(hwnd: HWND, dark: bool) void {
        // Would call DwmSetWindowAttribute with DWMWA_USE_IMMERSIVE_DARK_MODE
        _ = hwnd;
        _ = dark;
    }

    /// Set window backdrop (Windows 11)
    pub fn setBackdrop(hwnd: HWND, backdrop_type: BackdropType) void {
        // Would call DwmSetWindowAttribute with DWMWA_SYSTEMBACKDROP_TYPE
        _ = hwnd;
        _ = backdrop_type;
    }

    pub const BackdropType = enum(c_int) {
        auto = 0,
        none = 1,
        main_window = 2, // Mica
        transient_window = 3, // Acrylic
        tabbed_window = 4, // Tabbed Mica
    };

    /// Set Mica effect (Windows 11)
    pub fn setMica(hwnd: HWND, enable: bool) void {
        setBackdrop(hwnd, if (enable) .main_window else .none);
    }

    /// Set Acrylic effect (Windows 11)
    pub fn setAcrylic(hwnd: HWND, enable: bool) void {
        setBackdrop(hwnd, if (enable) .transient_window else .none);
    }
};

// ============================================
// Windows Power Management
// ============================================

pub const PowerManagement = struct {
    pub const PowerState = enum {
        unknown,
        ac_power,
        battery,
        battery_saver,
    };

    pub const BatteryStatus = struct {
        ac_online: bool,
        battery_present: bool,
        charging: bool,
        battery_percent: u8,
        battery_life_time: ?u32, // seconds remaining
        battery_full_life_time: ?u32, // seconds when full
    };

    /// Get current power state
    pub fn getPowerState() PowerState {
        // Would call GetSystemPowerStatus
        return .unknown;
    }

    /// Get battery status
    pub fn getBatteryStatus() BatteryStatus {
        // Would call GetSystemPowerStatus
        return BatteryStatus{
            .ac_online = true,
            .battery_present = false,
            .charging = false,
            .battery_percent = 100,
            .battery_life_time = null,
            .battery_full_life_time = null,
        };
    }

    /// Prevent system from sleeping
    pub fn preventSleep(display: bool, system: bool) void {
        // Would call SetThreadExecutionState
        _ = display;
        _ = system;
    }

    /// Allow system to sleep
    pub fn allowSleep() void {
        // Would call SetThreadExecutionState with ES_CONTINUOUS
    }

    /// Register for power setting notifications
    pub fn registerPowerNotification(hwnd: HWND, setting: PowerSetting) ?*anyopaque {
        // Would call RegisterPowerSettingNotification
        _ = hwnd;
        _ = setting;
        return null;
    }

    pub const PowerSetting = enum {
        ac_dc_power_source,
        battery_percentage_remaining,
        console_display_state,
        global_user_presence,
        idle_background_task,
        monitor_power_on,
        power_saving_status,
        session_display_status,
        session_user_presence,
        system_awaymode,
    };
};

// ============================================
// Windows Credential Manager
// ============================================

pub const CredentialManager = struct {
    pub const CredentialType = enum(c_int) {
        generic = 1,
        domain_password = 2,
        domain_certificate = 3,
        domain_visible_password = 4,
        generic_certificate = 5,
        domain_extended = 6,
    };

    pub const Credential = struct {
        target_name: []const u8,
        username: []const u8,
        credential_blob: []const u8,
        credential_type: CredentialType,
        persist: CredentialPersist,
    };

    pub const CredentialPersist = enum(c_int) {
        session = 1,
        local_machine = 2,
        enterprise = 3,
    };

    /// Store a credential
    pub fn write(credential: Credential) !void {
        // Would call CredWriteW
        _ = credential;
    }

    /// Read a credential
    pub fn read(target_name: []const u8, credential_type: CredentialType) !?Credential {
        // Would call CredReadW
        _ = target_name;
        _ = credential_type;
        return null;
    }

    /// Delete a credential
    pub fn delete(target_name: []const u8, credential_type: CredentialType) !void {
        // Would call CredDeleteW
        _ = target_name;
        _ = credential_type;
    }

    /// Enumerate credentials
    pub fn enumerate(filter: ?[]const u8, allocator: std.mem.Allocator) ![]Credential {
        // Would call CredEnumerateW
        _ = filter;
        return allocator.alloc(Credential, 0);
    }
};

// ============================================
// Windows Hello (Biometric Authentication)
// ============================================

pub const WindowsHello = struct {
    pub const AuthResult = enum {
        success,
        canceled,
        not_available,
        device_not_found,
        unknown_error,
    };

    /// Check if Windows Hello is available
    pub fn isAvailable() bool {
        // Would check UserConsentVerifierAvailability
        return false;
    }

    /// Request Windows Hello authentication
    pub fn authenticate(message: []const u8, callback: *const fn (AuthResult, ?*anyopaque) void, user_data: ?*anyopaque) void {
        // Would use Windows.Security.Credentials.UI.UserConsentVerifier
        _ = message;
        callback(.not_available, user_data);
    }
};

// ============================================
// Windows Share Contract
// ============================================

pub const ShareContract = struct {
    const Self = @This();

    title: []const u8,
    description: ?[]const u8,
    text: ?[]const u8,
    uri: ?[]const u8,
    html: ?[]const u8,
    rtf: ?[]const u8,
    files: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .title = "",
            .description = null,
            .text = null,
            .uri = null,
            .html = null,
            .rtf = null,
            .files = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.files.deinit();
    }

    pub fn setTitle(self: *Self, title: []const u8) void {
        self.title = title;
    }

    pub fn setDescription(self: *Self, desc: []const u8) void {
        self.description = desc;
    }

    pub fn setText(self: *Self, text: []const u8) void {
        self.text = text;
    }

    pub fn setUri(self: *Self, uri: []const u8) void {
        self.uri = uri;
    }

    pub fn setHtml(self: *Self, html: []const u8) void {
        self.html = html;
    }

    pub fn addFile(self: *Self, path: []const u8) !void {
        try self.files.append(path);
    }

    /// Show the share UI
    pub fn show(self: *Self, hwnd: HWND) !void {
        // Would use Windows.ApplicationModel.DataTransfer
        _ = self;
        _ = hwnd;
    }
};

// ============================================
// Windows File Association
// ============================================

pub const FileAssociation = struct {
    /// Register a file type association
    pub fn register(
        extension: []const u8,
        prog_id: []const u8,
        description: []const u8,
        icon_path: ?[]const u8,
        open_command: []const u8,
    ) !void {
        // Would write to registry HKEY_CLASSES_ROOT
        _ = extension;
        _ = prog_id;
        _ = description;
        _ = icon_path;
        _ = open_command;
    }

    /// Unregister a file type association
    pub fn unregister(extension: []const u8, prog_id: []const u8) !void {
        // Would delete from registry
        _ = extension;
        _ = prog_id;
    }

    /// Get the default application for a file type
    pub fn getDefault(extension: []const u8) ?[]const u8 {
        // Would call AssocQueryString
        _ = extension;
        return null;
    }

    /// Set the default application for a file type
    pub fn setDefault(extension: []const u8, prog_id: []const u8) !void {
        // Would use IApplicationAssociationRegistration
        _ = extension;
        _ = prog_id;
    }
};

// ============================================
// Windows Auto-Start
// ============================================

pub const AutoStart = struct {
    const RUN_KEY = "Software\\Microsoft\\Windows\\CurrentVersion\\Run";

    /// Enable auto-start for current user
    pub fn enable(name: []const u8, path: []const u8, args: ?[]const u8) !void {
        // Would write to HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
        _ = name;
        _ = path;
        _ = args;
    }

    /// Disable auto-start for current user
    pub fn disable(name: []const u8) !void {
        // Would delete from registry
        _ = name;
    }

    /// Check if auto-start is enabled
    pub fn isEnabled(name: []const u8) bool {
        // Would check registry
        _ = name;
        return false;
    }
};

// ============================================
// Windows Single Instance
// ============================================

pub const SingleInstance = struct {
    const Self = @This();

    mutex_handle: ?*anyopaque,
    app_id: []const u8,

    pub fn init(app_id: []const u8) Self {
        return Self{
            .mutex_handle = null,
            .app_id = app_id,
        };
    }

    /// Try to acquire single instance lock
    pub fn tryAcquire(self: *Self) bool {
        // Would call CreateMutexW
        _ = self;
        return true;
    }

    /// Release the lock
    pub fn release(self: *Self) void {
        if (self.mutex_handle) |handle| {
            // Would call CloseHandle
            _ = handle;
            self.mutex_handle = null;
        }
    }

    /// Send message to existing instance
    pub fn sendToExisting(self: *Self, message: []const u8) bool {
        // Would use WM_COPYDATA or named pipe
        _ = self;
        _ = message;
        return false;
    }
};

// ============================================
// Windows Clipboard
// ============================================

pub const Clipboard = struct {
    /// Get text from clipboard
    pub fn getText(allocator: std.mem.Allocator) !?[]u8 {
        // Would call OpenClipboard, GetClipboardData, CloseClipboard
        _ = allocator;
        return null;
    }

    /// Set text to clipboard
    pub fn setText(text: []const u8) !void {
        // Would call OpenClipboard, EmptyClipboard, SetClipboardData, CloseClipboard
        _ = text;
    }

    /// Check if clipboard has text
    pub fn hasText() bool {
        // Would call IsClipboardFormatAvailable
        return false;
    }

    /// Get image from clipboard
    pub fn getImage(allocator: std.mem.Allocator) !?[]u8 {
        // Would get CF_BITMAP or CF_DIB
        _ = allocator;
        return null;
    }

    /// Set image to clipboard
    pub fn setImage(data: []const u8) !void {
        // Would set CF_DIB
        _ = data;
    }

    /// Get files from clipboard
    pub fn getFiles(allocator: std.mem.Allocator) ![][]u8 {
        // Would get CF_HDROP
        return allocator.alloc([]u8, 0);
    }

    /// Set files to clipboard
    pub fn setFiles(paths: []const []const u8) !void {
        // Would set CF_HDROP
        _ = paths;
    }

    /// Clear clipboard
    pub fn clear() !void {
        // Would call EmptyClipboard
    }
};

// ============================================
// Windows System Dialogs
// ============================================

pub const SystemDialogs = struct {
    pub const FileDialogOptions = struct {
        title: ?[]const u8 = null,
        default_extension: ?[]const u8 = null,
        default_folder: ?[]const u8 = null,
        filters: ?[]const FileFilter = null,
        allow_multi_select: bool = false,
        show_hidden: bool = false,
    };

    pub const FileFilter = struct {
        name: []const u8,
        pattern: []const u8,
    };

    /// Show open file dialog
    pub fn openFile(hwnd: ?HWND, options: FileDialogOptions, allocator: std.mem.Allocator) !?[][]u8 {
        // Would use IFileOpenDialog
        _ = hwnd;
        _ = options;
        return allocator.alloc([]u8, 0);
    }

    /// Show save file dialog
    pub fn saveFile(hwnd: ?HWND, options: FileDialogOptions) !?[]u8 {
        // Would use IFileSaveDialog
        _ = hwnd;
        _ = options;
        return null;
    }

    /// Show folder picker dialog
    pub fn pickFolder(hwnd: ?HWND, options: FileDialogOptions) !?[]u8 {
        // Would use IFileOpenDialog with FOS_PICKFOLDERS
        _ = hwnd;
        _ = options;
        return null;
    }

    pub const MessageBoxType = enum {
        ok,
        ok_cancel,
        abort_retry_ignore,
        yes_no_cancel,
        yes_no,
        retry_cancel,
    };

    pub const MessageBoxIcon = enum {
        none,
        error_icon,
        question,
        warning,
        information,
    };

    pub const MessageBoxResult = enum {
        ok,
        cancel,
        abort,
        retry,
        ignore,
        yes,
        no,
    };

    /// Show message box
    pub fn messageBox(
        hwnd: ?HWND,
        text: []const u8,
        caption: []const u8,
        box_type: MessageBoxType,
        icon: MessageBoxIcon,
    ) MessageBoxResult {
        // Would call MessageBoxW
        _ = hwnd;
        _ = text;
        _ = caption;
        _ = box_type;
        _ = icon;
        return .ok;
    }

    /// Show color picker dialog
    pub fn colorPicker(hwnd: ?HWND, initial_color: ?u32) !?u32 {
        // Would use ChooseColorW
        _ = hwnd;
        _ = initial_color;
        return null;
    }

    /// Show font picker dialog
    pub fn fontPicker(hwnd: ?HWND) !?FontInfo {
        // Would use ChooseFontW
        _ = hwnd;
        return null;
    }

    pub const FontInfo = struct {
        name: []const u8,
        size: i32,
        weight: i32,
        italic: bool,
        underline: bool,
        strikeout: bool,
    };
};

// ============================================
// Windows Shell Integration
// ============================================

pub const Shell = struct {
    /// Open a file with default application
    pub fn open(path: []const u8) !void {
        // Would call ShellExecuteW with "open"
        _ = path;
    }

    /// Open URL in default browser
    pub fn openUrl(url: []const u8) !void {
        // Would call ShellExecuteW with "open"
        _ = url;
    }

    /// Show file in Explorer
    pub fn showInExplorer(path: []const u8) !void {
        // Would call SHOpenFolderAndSelectItems
        _ = path;
    }

    /// Get special folder path
    pub fn getSpecialFolder(folder: SpecialFolder, allocator: std.mem.Allocator) ![]u8 {
        // Would call SHGetKnownFolderPath
        _ = folder;
        return allocator.alloc(u8, 0);
    }

    pub const SpecialFolder = enum {
        desktop,
        documents,
        downloads,
        music,
        pictures,
        videos,
        app_data,
        local_app_data,
        program_files,
        windows,
        system,
        startup,
        recent,
        templates,
    };

    /// Create a shortcut
    pub fn createShortcut(
        shortcut_path: []const u8,
        target_path: []const u8,
        arguments: ?[]const u8,
        working_dir: ?[]const u8,
        description: ?[]const u8,
        icon_path: ?[]const u8,
        icon_index: i32,
    ) !void {
        // Would use IShellLink
        _ = shortcut_path;
        _ = target_path;
        _ = arguments;
        _ = working_dir;
        _ = description;
        _ = icon_path;
        _ = icon_index;
    }

    /// Delete to recycle bin
    pub fn recycleFile(path: []const u8) !void {
        // Would use SHFileOperation with FOF_ALLOWUNDO
        _ = path;
    }

    /// Empty recycle bin
    pub fn emptyRecycleBin(hwnd: ?HWND) !void {
        // Would call SHEmptyRecycleBin
        _ = hwnd;
    }
};

// ============================================
// Tests
// ============================================

test "TaskbarProgressState enum" {
    try std.testing.expectEqual(@as(c_int, 0), @intFromEnum(TaskbarProgressState.no_progress));
    try std.testing.expectEqual(@as(c_int, 2), @intFromEnum(TaskbarProgressState.normal));
}

test "ToastNotification init" {
    var toast = ToastNotification.init(std.testing.allocator, "TestApp");
    defer toast.deinit();

    toast.setTitle("Test Title");
    toast.setBody("Test Body");

    try std.testing.expectEqualStrings("Test Title", toast.title);
}

test "JumpList init" {
    var jl = JumpList.init(std.testing.allocator, "TestApp");
    defer jl.deinit();

    try jl.addTask(.{
        .title = "New Task",
        .description = "Description",
        .icon_path = null,
        .icon_index = 0,
        .arguments = "--new",
        .working_directory = null,
    });

    try std.testing.expectEqual(@as(usize, 1), jl.tasks.items.len);
}

test "WindowsTheme BackdropType" {
    try std.testing.expectEqual(@as(c_int, 2), @intFromEnum(WindowsTheme.BackdropType.main_window));
}
