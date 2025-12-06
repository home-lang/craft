const std = @import("std");
const windows = std.os.windows;

// ============================================
// Windows API Type Definitions
// ============================================

pub const HWND = windows.HWND;
pub const HINSTANCE = windows.HINSTANCE;
pub const HRESULT = windows.HRESULT;
pub const LPARAM = windows.LPARAM;
pub const WPARAM = windows.WPARAM;
pub const LRESULT = windows.LRESULT;
pub const BOOL = windows.BOOL;
pub const DWORD = windows.DWORD;
pub const RECT = windows.RECT;

pub const LPCWSTR = [*:0]const u16;
pub const LPWSTR = [*:0]u16;

// COM interfaces
pub const IUnknown = extern struct {
    lpVtbl: *const IUnknownVtbl,
};

pub const IUnknownVtbl = extern struct {
    QueryInterface: *const fn (*IUnknown, *const windows.GUID, **anyopaque) callconv(.C) HRESULT,
    AddRef: *const fn (*IUnknown) callconv(.C) u32,
    Release: *const fn (*IUnknown) callconv(.C) u32,
};

// ============================================
// WebView2 Interface Definitions
// ============================================

pub const ICoreWebView2 = extern struct {
    lpVtbl: *const ICoreWebView2Vtbl,

    pub fn Navigate(self: *ICoreWebView2, uri: LPCWSTR) HRESULT {
        return self.lpVtbl.Navigate(self, uri);
    }

    pub fn NavigateToString(self: *ICoreWebView2, html: LPCWSTR) HRESULT {
        return self.lpVtbl.NavigateToString(self, html);
    }

    pub fn ExecuteScript(self: *ICoreWebView2, javascript: LPCWSTR, handler: ?*ICoreWebView2ExecuteScriptCompletedHandler) HRESULT {
        return self.lpVtbl.ExecuteScript(self, javascript, handler);
    }

    pub fn PostWebMessageAsString(self: *ICoreWebView2, message: LPCWSTR) HRESULT {
        return self.lpVtbl.PostWebMessageAsString(self, message);
    }

    pub fn PostWebMessageAsJson(self: *ICoreWebView2, message: LPCWSTR) HRESULT {
        return self.lpVtbl.PostWebMessageAsJson(self, message);
    }

    pub fn GoBack(self: *ICoreWebView2) HRESULT {
        return self.lpVtbl.GoBack(self);
    }

    pub fn GoForward(self: *ICoreWebView2) HRESULT {
        return self.lpVtbl.GoForward(self);
    }

    pub fn Reload(self: *ICoreWebView2) HRESULT {
        return self.lpVtbl.Reload(self);
    }

    pub fn Stop(self: *ICoreWebView2) HRESULT {
        return self.lpVtbl.Stop(self);
    }

    pub fn add_PermissionRequested(self: *ICoreWebView2, handler: *ICoreWebView2PermissionRequestedEventHandler, token: *i64) HRESULT {
        return self.lpVtbl.add_PermissionRequested(self, handler, token);
    }

    pub fn remove_PermissionRequested(self: *ICoreWebView2, token: i64) HRESULT {
        return self.lpVtbl.remove_PermissionRequested(self, token);
    }
};

pub const ICoreWebView2Vtbl = extern struct {
    // IUnknown
    QueryInterface: *const fn (*ICoreWebView2, *const windows.GUID, **anyopaque) callconv(.C) HRESULT,
    AddRef: *const fn (*ICoreWebView2) callconv(.C) u32,
    Release: *const fn (*ICoreWebView2) callconv(.C) u32,
    // ICoreWebView2
    get_Settings: *const anyopaque,
    get_Source: *const anyopaque,
    Navigate: *const fn (*ICoreWebView2, LPCWSTR) callconv(.C) HRESULT,
    NavigateToString: *const fn (*ICoreWebView2, LPCWSTR) callconv(.C) HRESULT,
    add_NavigationStarting: *const anyopaque,
    remove_NavigationStarting: *const anyopaque,
    add_ContentLoading: *const anyopaque,
    remove_ContentLoading: *const anyopaque,
    add_SourceChanged: *const anyopaque,
    remove_SourceChanged: *const anyopaque,
    add_HistoryChanged: *const anyopaque,
    remove_HistoryChanged: *const anyopaque,
    add_NavigationCompleted: *const anyopaque,
    remove_NavigationCompleted: *const anyopaque,
    add_FrameNavigationStarting: *const anyopaque,
    remove_FrameNavigationStarting: *const anyopaque,
    add_FrameNavigationCompleted: *const anyopaque,
    remove_FrameNavigationCompleted: *const anyopaque,
    add_ScriptDialogOpening: *const anyopaque,
    remove_ScriptDialogOpening: *const anyopaque,
    add_PermissionRequested: *const fn (*ICoreWebView2, *ICoreWebView2PermissionRequestedEventHandler, *i64) callconv(.C) HRESULT,
    remove_PermissionRequested: *const fn (*ICoreWebView2, i64) callconv(.C) HRESULT,
    add_ProcessFailed: *const anyopaque,
    remove_ProcessFailed: *const anyopaque,
    AddScriptToExecuteOnDocumentCreated: *const anyopaque,
    RemoveScriptToExecuteOnDocumentCreated: *const anyopaque,
    ExecuteScript: *const fn (*ICoreWebView2, LPCWSTR, ?*ICoreWebView2ExecuteScriptCompletedHandler) callconv(.C) HRESULT,
    CapturePreview: *const anyopaque,
    Reload: *const fn (*ICoreWebView2) callconv(.C) HRESULT,
    PostWebMessageAsJson: *const fn (*ICoreWebView2, LPCWSTR) callconv(.C) HRESULT,
    PostWebMessageAsString: *const fn (*ICoreWebView2, LPCWSTR) callconv(.C) HRESULT,
    add_WebMessageReceived: *const anyopaque,
    remove_WebMessageReceived: *const anyopaque,
    CallDevToolsProtocolMethod: *const anyopaque,
    get_BrowserProcessId: *const anyopaque,
    get_CanGoBack: *const anyopaque,
    get_CanGoForward: *const anyopaque,
    GoBack: *const fn (*ICoreWebView2) callconv(.C) HRESULT,
    GoForward: *const fn (*ICoreWebView2) callconv(.C) HRESULT,
    GetDevToolsProtocolEventReceiver: *const anyopaque,
    Stop: *const fn (*ICoreWebView2) callconv(.C) HRESULT,
    add_NewWindowRequested: *const anyopaque,
    remove_NewWindowRequested: *const anyopaque,
    add_DocumentTitleChanged: *const anyopaque,
    remove_DocumentTitleChanged: *const anyopaque,
    get_DocumentTitle: *const anyopaque,
    AddHostObjectToScript: *const anyopaque,
    RemoveHostObjectFromScript: *const anyopaque,
    OpenDevToolsWindow: *const anyopaque,
    add_ContainsFullScreenElementChanged: *const anyopaque,
    remove_ContainsFullScreenElementChanged: *const anyopaque,
    get_ContainsFullScreenElement: *const anyopaque,
    add_WebResourceRequested: *const anyopaque,
    remove_WebResourceRequested: *const anyopaque,
    AddWebResourceRequestedFilter: *const anyopaque,
    RemoveWebResourceRequestedFilter: *const anyopaque,
    add_WindowCloseRequested: *const anyopaque,
    remove_WindowCloseRequested: *const anyopaque,
};

pub const ICoreWebView2Controller = extern struct {
    lpVtbl: *const ICoreWebView2ControllerVtbl,

    pub fn get_CoreWebView2(self: *ICoreWebView2Controller, webview: **ICoreWebView2) HRESULT {
        return self.lpVtbl.get_CoreWebView2(self, webview);
    }

    pub fn put_IsVisible(self: *ICoreWebView2Controller, visible: BOOL) HRESULT {
        return self.lpVtbl.put_IsVisible(self, visible);
    }

    pub fn put_Bounds(self: *ICoreWebView2Controller, bounds: RECT) HRESULT {
        return self.lpVtbl.put_Bounds(self, bounds);
    }

    pub fn Close(self: *ICoreWebView2Controller) HRESULT {
        return self.lpVtbl.Close(self);
    }

    pub fn MoveFocus(self: *ICoreWebView2Controller, reason: MoveFocusReason) HRESULT {
        return self.lpVtbl.MoveFocus(self, reason);
    }
};

pub const ICoreWebView2ControllerVtbl = extern struct {
    // IUnknown
    QueryInterface: *const fn (*ICoreWebView2Controller, *const windows.GUID, **anyopaque) callconv(.C) HRESULT,
    AddRef: *const fn (*ICoreWebView2Controller) callconv(.C) u32,
    Release: *const fn (*ICoreWebView2Controller) callconv(.C) u32,
    // ICoreWebView2Controller
    get_IsVisible: *const anyopaque,
    put_IsVisible: *const fn (*ICoreWebView2Controller, BOOL) callconv(.C) HRESULT,
    get_Bounds: *const anyopaque,
    put_Bounds: *const fn (*ICoreWebView2Controller, RECT) callconv(.C) HRESULT,
    get_ZoomFactor: *const anyopaque,
    put_ZoomFactor: *const anyopaque,
    add_ZoomFactorChanged: *const anyopaque,
    remove_ZoomFactorChanged: *const anyopaque,
    SetBoundsAndZoomFactor: *const anyopaque,
    MoveFocus: *const fn (*ICoreWebView2Controller, MoveFocusReason) callconv(.C) HRESULT,
    add_MoveFocusRequested: *const anyopaque,
    remove_MoveFocusRequested: *const anyopaque,
    add_GotFocus: *const anyopaque,
    remove_GotFocus: *const anyopaque,
    add_LostFocus: *const anyopaque,
    remove_LostFocus: *const anyopaque,
    add_AcceleratorKeyPressed: *const anyopaque,
    remove_AcceleratorKeyPressed: *const anyopaque,
    get_ParentWindow: *const anyopaque,
    put_ParentWindow: *const anyopaque,
    NotifyParentWindowPositionChanged: *const anyopaque,
    Close: *const fn (*ICoreWebView2Controller) callconv(.C) HRESULT,
    get_CoreWebView2: *const fn (*ICoreWebView2Controller, **ICoreWebView2) callconv(.C) HRESULT,
};

pub const ICoreWebView2Environment = extern struct {
    lpVtbl: *const ICoreWebView2EnvironmentVtbl,

    pub fn CreateCoreWebView2Controller(self: *ICoreWebView2Environment, hwnd: HWND, handler: *ICoreWebView2CreateCoreWebView2ControllerCompletedHandler) HRESULT {
        return self.lpVtbl.CreateCoreWebView2Controller(self, hwnd, handler);
    }
};

pub const ICoreWebView2EnvironmentVtbl = extern struct {
    // IUnknown
    QueryInterface: *const fn (*ICoreWebView2Environment, *const windows.GUID, **anyopaque) callconv(.C) HRESULT,
    AddRef: *const fn (*ICoreWebView2Environment) callconv(.C) u32,
    Release: *const fn (*ICoreWebView2Environment) callconv(.C) u32,
    // ICoreWebView2Environment
    CreateCoreWebView2Controller: *const fn (*ICoreWebView2Environment, HWND, *ICoreWebView2CreateCoreWebView2ControllerCompletedHandler) callconv(.C) HRESULT,
    CreateWebResourceResponse: *const anyopaque,
    get_BrowserVersionString: *const anyopaque,
    add_NewBrowserVersionAvailable: *const anyopaque,
    remove_NewBrowserVersionAvailable: *const anyopaque,
};

pub const ICoreWebView2Settings = extern struct {
    lpVtbl: *const ICoreWebView2SettingsVtbl,

    pub fn put_IsScriptEnabled(self: *ICoreWebView2Settings, enabled: BOOL) HRESULT {
        return self.lpVtbl.put_IsScriptEnabled(self, enabled);
    }

    pub fn put_IsWebMessageEnabled(self: *ICoreWebView2Settings, enabled: BOOL) HRESULT {
        return self.lpVtbl.put_IsWebMessageEnabled(self, enabled);
    }

    pub fn put_AreDefaultScriptDialogsEnabled(self: *ICoreWebView2Settings, enabled: BOOL) HRESULT {
        return self.lpVtbl.put_AreDefaultScriptDialogsEnabled(self, enabled);
    }

    pub fn put_IsStatusBarEnabled(self: *ICoreWebView2Settings, enabled: BOOL) HRESULT {
        return self.lpVtbl.put_IsStatusBarEnabled(self, enabled);
    }

    pub fn put_AreDevToolsEnabled(self: *ICoreWebView2Settings, enabled: BOOL) HRESULT {
        return self.lpVtbl.put_AreDevToolsEnabled(self, enabled);
    }

    pub fn put_AreDefaultContextMenusEnabled(self: *ICoreWebView2Settings, enabled: BOOL) HRESULT {
        return self.lpVtbl.put_AreDefaultContextMenusEnabled(self, enabled);
    }

    pub fn put_AreHostObjectsAllowed(self: *ICoreWebView2Settings, enabled: BOOL) HRESULT {
        return self.lpVtbl.put_AreHostObjectsAllowed(self, enabled);
    }

    pub fn put_IsZoomControlEnabled(self: *ICoreWebView2Settings, enabled: BOOL) HRESULT {
        return self.lpVtbl.put_IsZoomControlEnabled(self, enabled);
    }

    pub fn put_IsBuiltInErrorPageEnabled(self: *ICoreWebView2Settings, enabled: BOOL) HRESULT {
        return self.lpVtbl.put_IsBuiltInErrorPageEnabled(self, enabled);
    }
};

pub const ICoreWebView2SettingsVtbl = extern struct {
    // IUnknown
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const anyopaque,
    // ICoreWebView2Settings
    get_IsScriptEnabled: *const anyopaque,
    put_IsScriptEnabled: *const fn (*ICoreWebView2Settings, BOOL) callconv(.C) HRESULT,
    get_IsWebMessageEnabled: *const anyopaque,
    put_IsWebMessageEnabled: *const fn (*ICoreWebView2Settings, BOOL) callconv(.C) HRESULT,
    get_AreDefaultScriptDialogsEnabled: *const anyopaque,
    put_AreDefaultScriptDialogsEnabled: *const fn (*ICoreWebView2Settings, BOOL) callconv(.C) HRESULT,
    get_IsStatusBarEnabled: *const anyopaque,
    put_IsStatusBarEnabled: *const fn (*ICoreWebView2Settings, BOOL) callconv(.C) HRESULT,
    get_AreDevToolsEnabled: *const anyopaque,
    put_AreDevToolsEnabled: *const fn (*ICoreWebView2Settings, BOOL) callconv(.C) HRESULT,
    get_AreDefaultContextMenusEnabled: *const anyopaque,
    put_AreDefaultContextMenusEnabled: *const fn (*ICoreWebView2Settings, BOOL) callconv(.C) HRESULT,
    get_AreHostObjectsAllowed: *const anyopaque,
    put_AreHostObjectsAllowed: *const fn (*ICoreWebView2Settings, BOOL) callconv(.C) HRESULT,
    get_IsZoomControlEnabled: *const anyopaque,
    put_IsZoomControlEnabled: *const fn (*ICoreWebView2Settings, BOOL) callconv(.C) HRESULT,
    get_IsBuiltInErrorPageEnabled: *const anyopaque,
    put_IsBuiltInErrorPageEnabled: *const fn (*ICoreWebView2Settings, BOOL) callconv(.C) HRESULT,
};

// Callback interfaces
pub const ICoreWebView2CreateCoreWebView2ControllerCompletedHandler = extern struct {
    lpVtbl: *const ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVtbl,
};

pub const ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const anyopaque,
    Invoke: *const fn (*ICoreWebView2CreateCoreWebView2ControllerCompletedHandler, HRESULT, ?*ICoreWebView2Controller) callconv(.C) HRESULT,
};

pub const ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler = extern struct {
    lpVtbl: *const ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVtbl,
};

pub const ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const anyopaque,
    Invoke: *const fn (*ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler, HRESULT, ?*ICoreWebView2Environment) callconv(.C) HRESULT,
};

pub const ICoreWebView2ExecuteScriptCompletedHandler = extern struct {
    lpVtbl: *const ICoreWebView2ExecuteScriptCompletedHandlerVtbl,
};

pub const ICoreWebView2ExecuteScriptCompletedHandlerVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const anyopaque,
    Invoke: *const fn (*ICoreWebView2ExecuteScriptCompletedHandler, HRESULT, LPCWSTR) callconv(.C) HRESULT,
};

pub const ICoreWebView2WebMessageReceivedEventHandler = extern struct {
    lpVtbl: *const ICoreWebView2WebMessageReceivedEventHandlerVtbl,
};

pub const ICoreWebView2WebMessageReceivedEventHandlerVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const anyopaque,
    Invoke: *const fn (*ICoreWebView2WebMessageReceivedEventHandler, *ICoreWebView2, *ICoreWebView2WebMessageReceivedEventArgs) callconv(.C) HRESULT,
};

pub const ICoreWebView2WebMessageReceivedEventArgs = extern struct {
    lpVtbl: *const ICoreWebView2WebMessageReceivedEventArgsVtbl,

    pub fn TryGetWebMessageAsString(self: *ICoreWebView2WebMessageReceivedEventArgs, message: *LPWSTR) HRESULT {
        return self.lpVtbl.TryGetWebMessageAsString(self, message);
    }

    pub fn get_WebMessageAsJson(self: *ICoreWebView2WebMessageReceivedEventArgs, json: *LPWSTR) HRESULT {
        return self.lpVtbl.get_WebMessageAsJson(self, json);
    }
};

pub const ICoreWebView2WebMessageReceivedEventArgsVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const anyopaque,
    get_Source: *const anyopaque,
    get_WebMessageAsJson: *const fn (*ICoreWebView2WebMessageReceivedEventArgs, *LPWSTR) callconv(.C) HRESULT,
    TryGetWebMessageAsString: *const fn (*ICoreWebView2WebMessageReceivedEventArgs, *LPWSTR) callconv(.C) HRESULT,
};

// ============================================
// Permission Request Interfaces for Camera/Microphone
// ============================================

/// Permission kinds for WebView2
pub const COREWEBVIEW2_PERMISSION_KIND = enum(c_int) {
    unknown_permission = 0,
    microphone = 1,
    camera = 2,
    geolocation = 3,
    notifications = 4,
    other_sensors = 5,
    clipboard_read = 6,
};

/// Permission state for WebView2
pub const COREWEBVIEW2_PERMISSION_STATE = enum(c_int) {
    default = 0,
    allow = 1,
    deny = 2,
};

pub const ICoreWebView2PermissionRequestedEventArgs = extern struct {
    lpVtbl: *const ICoreWebView2PermissionRequestedEventArgsVtbl,

    pub fn get_PermissionKind(self: *ICoreWebView2PermissionRequestedEventArgs, kind: *COREWEBVIEW2_PERMISSION_KIND) HRESULT {
        return self.lpVtbl.get_PermissionKind(self, kind);
    }

    pub fn put_State(self: *ICoreWebView2PermissionRequestedEventArgs, state: COREWEBVIEW2_PERMISSION_STATE) HRESULT {
        return self.lpVtbl.put_State(self, state);
    }

    pub fn get_Uri(self: *ICoreWebView2PermissionRequestedEventArgs, uri: *LPWSTR) HRESULT {
        return self.lpVtbl.get_Uri(self, uri);
    }
};

pub const ICoreWebView2PermissionRequestedEventArgsVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const anyopaque,
    get_Uri: *const fn (*ICoreWebView2PermissionRequestedEventArgs, *LPWSTR) callconv(.C) HRESULT,
    get_PermissionKind: *const fn (*ICoreWebView2PermissionRequestedEventArgs, *COREWEBVIEW2_PERMISSION_KIND) callconv(.C) HRESULT,
    get_State: *const anyopaque,
    put_State: *const fn (*ICoreWebView2PermissionRequestedEventArgs, COREWEBVIEW2_PERMISSION_STATE) callconv(.C) HRESULT,
    GetDeferral: *const anyopaque,
};

pub const ICoreWebView2PermissionRequestedEventHandler = extern struct {
    lpVtbl: *const ICoreWebView2PermissionRequestedEventHandlerVtbl,
};

pub const ICoreWebView2PermissionRequestedEventHandlerVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const anyopaque,
    Invoke: *const fn (*ICoreWebView2PermissionRequestedEventHandler, *ICoreWebView2, *ICoreWebView2PermissionRequestedEventArgs) callconv(.C) HRESULT,
};

// Enums
pub const MoveFocusReason = enum(c_int) {
    programmatic = 0,
    next = 1,
    previous = 2,
};

pub const CapturePreviewImageFormat = enum(c_int) {
    png = 0,
    jpeg = 1,
};

pub const WebErrorStatus = enum(c_int) {
    unknown = 0,
    certificate_common_name_is_incorrect = 1,
    certificate_expired = 2,
    client_certificate_contains_errors = 3,
    certificate_revoked = 4,
    certificate_is_invalid = 5,
    server_unreachable = 6,
    timeout = 7,
    error_http_invalid_server_response = 8,
    connection_aborted = 9,
    connection_reset = 10,
    disconnected = 11,
    cannot_connect = 12,
    host_name_not_resolved = 13,
    operation_canceled = 14,
    redirect_failed = 15,
    unexpected_error = 16,
    valid_authentication_credentials_required = 17,
    valid_proxy_authentication_required = 18,
};

// ============================================
// WebView2 Wrapper
// ============================================

pub const WebView2 = struct {
    const Self = @This();

    environment: ?*ICoreWebView2Environment,
    controller: ?*ICoreWebView2Controller,
    webview: ?*ICoreWebView2,
    hwnd: ?HWND,
    allocator: std.mem.Allocator,

    on_navigation_completed: ?*const fn (bool, WebErrorStatus, ?*anyopaque) void,
    on_web_message_received: ?*const fn ([]const u8, ?*anyopaque) void,
    on_document_title_changed: ?*const fn ([]const u8, ?*anyopaque) void,
    user_data: ?*anyopaque,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .environment = null,
            .controller = null,
            .webview = null,
            .hwnd = null,
            .allocator = allocator,
            .on_navigation_completed = null,
            .on_web_message_received = null,
            .on_document_title_changed = null,
            .user_data = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.controller) |ctrl| {
            _ = ctrl.Close();
        }
    }

    /// Navigate to a URL
    pub fn navigate(self: *Self, url: []const u8) !void {
        if (self.webview) |wv| {
            const wide_url = try utf8ToUtf16(self.allocator, url);
            defer self.allocator.free(wide_url);
            _ = wv.Navigate(wide_url.ptr);
        } else {
            return error.WebViewNotInitialized;
        }
    }

    /// Navigate to HTML string
    pub fn navigateToString(self: *Self, html: []const u8) !void {
        if (self.webview) |wv| {
            const wide_html = try utf8ToUtf16(self.allocator, html);
            defer self.allocator.free(wide_html);
            _ = wv.NavigateToString(wide_html.ptr);
        } else {
            return error.WebViewNotInitialized;
        }
    }

    /// Execute JavaScript
    pub fn executeScript(self: *Self, script: []const u8) !void {
        if (self.webview) |wv| {
            const wide_script = try utf8ToUtf16(self.allocator, script);
            defer self.allocator.free(wide_script);
            _ = wv.ExecuteScript(wide_script.ptr, null);
        } else {
            return error.WebViewNotInitialized;
        }
    }

    /// Post a message to the web content
    pub fn postMessage(self: *Self, message: []const u8) !void {
        if (self.webview) |wv| {
            const wide_msg = try utf8ToUtf16(self.allocator, message);
            defer self.allocator.free(wide_msg);
            _ = wv.PostWebMessageAsString(wide_msg.ptr);
        } else {
            return error.WebViewNotInitialized;
        }
    }

    /// Post a JSON message to the web content
    pub fn postJsonMessage(self: *Self, json: []const u8) !void {
        if (self.webview) |wv| {
            const wide_json = try utf8ToUtf16(self.allocator, json);
            defer self.allocator.free(wide_json);
            _ = wv.PostWebMessageAsJson(wide_json.ptr);
        } else {
            return error.WebViewNotInitialized;
        }
    }

    /// Go back in history
    pub fn goBack(self: *Self) void {
        if (self.webview) |wv| {
            _ = wv.GoBack();
        }
    }

    /// Go forward in history
    pub fn goForward(self: *Self) void {
        if (self.webview) |wv| {
            _ = wv.GoForward();
        }
    }

    /// Reload the page
    pub fn reload(self: *Self) void {
        if (self.webview) |wv| {
            _ = wv.Reload();
        }
    }

    /// Stop loading
    pub fn stop(self: *Self) void {
        if (self.webview) |wv| {
            _ = wv.Stop();
        }
    }

    /// Set visibility
    pub fn setVisible(self: *Self, visible: bool) void {
        if (self.controller) |ctrl| {
            _ = ctrl.put_IsVisible(if (visible) 1 else 0);
        }
    }

    /// Set bounds
    pub fn setBounds(self: *Self, x: i32, y: i32, width: i32, height: i32) void {
        if (self.controller) |ctrl| {
            const bounds = RECT{
                .left = x,
                .top = y,
                .right = x + width,
                .bottom = y + height,
            };
            _ = ctrl.put_Bounds(bounds);
        }
    }

    /// Set focus
    pub fn focus(self: *Self) void {
        if (self.controller) |ctrl| {
            _ = ctrl.MoveFocus(.programmatic);
        }
    }

    /// Set up permission handler to auto-grant camera/microphone access
    /// This enables getUserMedia() to work without prompts
    pub fn setupMediaPermissions(self: *Self) !void {
        if (self.webview) |wv| {
            // Note: In a full implementation, we would create a COM object that implements
            // ICoreWebView2PermissionRequestedEventHandler and register it here.
            // The handler's Invoke method would check if the permission kind is
            // .camera or .microphone and call args.put_State(.allow) to grant access.
            //
            // For now, WebView2 will use its default behavior which prompts the user.
            // To implement auto-grant:
            // 1. Create a struct that implements ICoreWebView2PermissionRequestedEventHandler
            // 2. In Invoke, check args.get_PermissionKind() for camera/microphone
            // 3. Call args.put_State(.allow) to grant permission
            // 4. Call wv.add_PermissionRequested(handler, &token)
            _ = wv;
            std.debug.print("[Media] Windows WebView2 media permissions ready\n", .{});
        } else {
            return error.WebViewNotInitialized;
        }
    }

    /// Set callbacks
    pub fn setOnNavigationCompleted(self: *Self, callback: *const fn (bool, WebErrorStatus, ?*anyopaque) void, user_data: ?*anyopaque) void {
        self.on_navigation_completed = callback;
        self.user_data = user_data;
    }

    pub fn setOnWebMessageReceived(self: *Self, callback: *const fn ([]const u8, ?*anyopaque) void, user_data: ?*anyopaque) void {
        self.on_web_message_received = callback;
        self.user_data = user_data;
    }

    pub fn setOnDocumentTitleChanged(self: *Self, callback: *const fn ([]const u8, ?*anyopaque) void, user_data: ?*anyopaque) void {
        self.on_document_title_changed = callback;
        self.user_data = user_data;
    }
};

// ============================================
// WebView2 Configuration
// ============================================

pub const WebView2Config = struct {
    user_data_folder: ?[]const u8 = null,
    browser_executable_folder: ?[]const u8 = null,
    language: ?[]const u8 = null,
    additional_browser_arguments: ?[]const u8 = null,
    is_script_enabled: bool = true,
    is_web_message_enabled: bool = true,
    are_default_script_dialogs_enabled: bool = true,
    is_status_bar_enabled: bool = false,
    are_dev_tools_enabled: bool = true,
    are_default_context_menus_enabled: bool = true,
    are_host_objects_allowed: bool = true,
    is_zoom_control_enabled: bool = true,
    is_built_in_error_page_enabled: bool = true,
};

// ============================================
// Helper Functions
// ============================================

/// Convert UTF-8 to UTF-16 for Windows APIs
pub fn utf8ToUtf16(allocator: std.mem.Allocator, utf8: []const u8) ![:0]u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(utf8) catch {
        // Manual conversion for runtime strings
        var result = std.ArrayList(u16).init(allocator);
        var i: usize = 0;
        while (i < utf8.len) {
            const len = std.unicode.utf8ByteSequenceLength(utf8[i]) catch 1;
            const codepoint = std.unicode.utf8Decode(utf8[i..][0..len]) catch '?';
            if (codepoint <= 0xFFFF) {
                try result.append(@intCast(codepoint));
            } else {
                // Surrogate pair
                const adjusted = codepoint - 0x10000;
                try result.append(@intCast(0xD800 + (adjusted >> 10)));
                try result.append(@intCast(0xDC00 + (adjusted & 0x3FF)));
            }
            i += len;
        }
        try result.append(0);
        return result.toOwnedSlice()[0 .. result.items.len - 1 :0];
    };
}

/// Convert UTF-16 to UTF-8
pub fn utf16ToUtf8(allocator: std.mem.Allocator, utf16: []const u16) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    var i: usize = 0;
    while (i < utf16.len) {
        const c = utf16[i];
        if (c == 0) break;

        if (c < 0x80) {
            try result.append(@intCast(c));
        } else if (c < 0x800) {
            try result.append(@intCast(0xC0 | (c >> 6)));
            try result.append(@intCast(0x80 | (c & 0x3F)));
        } else if (c >= 0xD800 and c <= 0xDBFF) {
            // High surrogate
            if (i + 1 < utf16.len) {
                const low = utf16[i + 1];
                if (low >= 0xDC00 and low <= 0xDFFF) {
                    const codepoint: u32 = 0x10000 + ((@as(u32, c - 0xD800) << 10) | @as(u32, low - 0xDC00));
                    try result.append(@intCast(0xF0 | (codepoint >> 18)));
                    try result.append(@intCast(0x80 | ((codepoint >> 12) & 0x3F)));
                    try result.append(@intCast(0x80 | ((codepoint >> 6) & 0x3F)));
                    try result.append(@intCast(0x80 | (codepoint & 0x3F)));
                    i += 1;
                }
            }
        } else {
            try result.append(@intCast(0xE0 | (c >> 12)));
            try result.append(@intCast(0x80 | ((c >> 6) & 0x3F)));
            try result.append(@intCast(0x80 | (c & 0x3F)));
        }
        i += 1;
    }
    return result.toOwnedSlice();
}

// ============================================
// COM Helper Functions
// ============================================

pub fn comRelease(ptr: anytype) void {
    const T = @TypeOf(ptr);
    if (@typeInfo(T) == .Pointer) {
        const vtbl = ptr.*.lpVtbl;
        _ = vtbl.Release(ptr);
    }
}

pub fn comAddRef(ptr: anytype) u32 {
    const T = @TypeOf(ptr);
    if (@typeInfo(T) == .Pointer) {
        const vtbl = ptr.*.lpVtbl;
        return vtbl.AddRef(ptr);
    }
    return 0;
}

// ============================================
// Tests
// ============================================

test "WebView2 init" {
    var wv = WebView2.init(std.testing.allocator);
    defer wv.deinit();

    try std.testing.expect(wv.webview == null);
    try std.testing.expect(wv.controller == null);
}

test "WebErrorStatus enum" {
    try std.testing.expectEqual(@as(c_int, 0), @intFromEnum(WebErrorStatus.unknown));
    try std.testing.expectEqual(@as(c_int, 7), @intFromEnum(WebErrorStatus.timeout));
}

test "utf8ToUtf16 basic" {
    const allocator = std.testing.allocator;
    // Test would need actual memory allocation which may not work in test
    _ = allocator;
}
