const std = @import("std");
const log = @import("log.zig");

pub const HotReloadConfig = struct {
    enabled: bool = true,
    watch_paths: []const []const u8 = &.{},
    ignore_patterns: []const []const u8 = &.{ ".git", "node_modules", ".DS_Store" },
    debounce_ms: u64 = 300,
    auto_reload: bool = true,
    reload_on_save: bool = true,
};

pub const FileWatcher = struct {
    watched_paths: std.StringHashMap(i64),
    ignore_patterns: []const []const u8,
    allocator: std.mem.Allocator,
    last_reload: i64 = 0,
    debounce_ms: u64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: HotReloadConfig) !Self {
        var watcher = Self{
            .watched_paths = std.StringHashMap(i64).init(allocator),
            .ignore_patterns = config.ignore_patterns,
            .allocator = allocator,
            .debounce_ms = config.debounce_ms,
        };

        // Add watch paths
        for (config.watch_paths) |path| {
            try watcher.addPath(path);
        }

        return watcher;
    }

    pub fn deinit(self: *Self) void {
        self.watched_paths.deinit();
    }

    pub fn addPath(self: *Self, path: []const u8) !void {
        const stat = std.fs.cwd().statFile(path) catch |err| {
            log.warn("Failed to stat {s}: {}", .{ path, err });
            return;
        };

        const mtime = @as(i64, @intCast(stat.mtime));
        try self.watched_paths.put(path, mtime);
        log.debug("Watching: {s}", .{path});
    }

    pub fn check(self: *Self) !bool {
        const now = std.time.milliTimestamp();

        // Debounce check
        if (now - self.last_reload < self.debounce_ms) {
            return false;
        }

        var iter = self.watched_paths.iterator();
        while (iter.next()) |entry| {
            const path = entry.key_ptr.*;
            const old_mtime = entry.value_ptr.*;

            const stat = std.fs.cwd().statFile(path) catch continue;
            const new_mtime = @as(i64, @intCast(stat.mtime));

            if (new_mtime > old_mtime) {
                log.info("File changed: {s}", .{path});
                entry.value_ptr.* = new_mtime;
                self.last_reload = now;
                return true;
            }
        }

        return false;
    }

    fn shouldIgnore(self: Self, path: []const u8) bool {
        for (self.ignore_patterns) |pattern| {
            if (std.mem.indexOf(u8, path, pattern) != null) {
                return true;
            }
        }
        return false;
    }
};

pub const HotReload = struct {
    config: HotReloadConfig,
    watcher: ?FileWatcher = null,
    callback: ?*const fn () void = null,
    allocator: std.mem.Allocator,
    running: bool = false,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: HotReloadConfig) !Self {
        var hr = Self{
            .config = config,
            .allocator = allocator,
        };

        if (config.enabled and config.watch_paths.len > 0) {
            hr.watcher = try FileWatcher.init(allocator, config);
        }

        return hr;
    }

    pub fn deinit(self: *Self) void {
        if (self.watcher) |*w| {
            w.deinit();
        }
    }

    pub fn setCallback(self: *Self, callback: *const fn () void) void {
        self.callback = callback;
    }

    pub fn start(self: *Self) void {
        self.running = true;
        log.info("Hot reload started", .{});
    }

    pub fn stop(self: *Self) void {
        self.running = false;
        log.info("Hot reload stopped", .{});
    }

    pub fn poll(self: *Self) !void {
        if (!self.running or self.watcher == null) return;

        if (try self.watcher.?.check()) {
            log.info("Changes detected, triggering reload...", .{});

            if (self.callback) |cb| {
                cb();
            }
        }
    }
};

/// State preservation for hot reload
pub const StatePreservation = struct {
    enabled: bool = true,
    storage_key: []const u8 = "craft_hotreload_state",
    preserve_scroll: bool = true,
    preserve_form_data: bool = true,
    preserve_focus: bool = true,
    preserve_custom_state: bool = true,
};

/// Mobile hot reload support
pub const MobileReloadConfig = struct {
    enabled: bool = true,
    port: u16 = 3456,
    host: []const u8 = "0.0.0.0", // Listen on all interfaces for mobile access
    broadcast: bool = true, // Broadcast to all connected clients
    platform: enum { ios, android, both } = .both,
};

/// WebSocket server for hot reload
pub const ReloadServer = struct {
    allocator: std.mem.Allocator,
    config: MobileReloadConfig,
    running: bool = false,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: MobileReloadConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn start(self: *Self) !void {
        self.running = true;
        log.info("Hot reload server starting on {s}:{d}", .{ self.config.host, self.config.port });
        // TODO: Implement WebSocket server using std.net
    }

    pub fn stop(self: *Self) void {
        self.running = false;
        log.info("Hot reload server stopped", .{});
    }

    pub fn broadcast(self: *Self, message: []const u8) !void {
        _ = self;
        _ = message;
        // TODO: Broadcast to all connected WebSocket clients
    }

    pub fn triggerReload(self: *Self) !void {
        try self.broadcast("reload");
        log.info("Reload triggered for all connected clients", .{});
    }
};

/// Mobile-specific hot reload script (works for iOS and Android WebViews)
pub const mobile_client_script =
    \\<script>
    \\(function() {
    \\  // Auto-detect dev server URL from current location or use localhost
    \\  const WS_HOST = window.location.hostname || 'localhost';
    \\  const WS_PORT = 3456;
    \\  const WS_URL = `ws://${WS_HOST}:${WS_PORT}/_craft_reload`;
    \\  const STATE_KEY = 'craft_hotreload_state';
    \\  let ws = null;
    \\  let reconnectAttempts = 0;
    \\  const MAX_RECONNECT_ATTEMPTS = 20; // More attempts for mobile
    \\
    \\  // Detect platform
    \\  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
    \\  const isAndroid = /Android/.test(navigator.userAgent);
    \\  const isMobile = isIOS || isAndroid;
    \\
    \\  console.log(`[Craft Mobile HotReload] Platform: ${isIOS ? 'iOS' : isAndroid ? 'Android' : 'Unknown'}`);
    \\
    \\  // State preservation with mobile-specific considerations
    \\  function saveState() {
    \\    const state = {
    \\      scroll: { x: window.scrollX, y: window.scrollY },
    \\      focus: document.activeElement ? {
    \\        selector: getSelector(document.activeElement),
    \\        selectionStart: document.activeElement.selectionStart,
    \\        selectionEnd: document.activeElement.selectionEnd
    \\      } : null,
    \\      forms: Array.from(document.forms).map(form => ({
    \\        id: form.id,
    \\        data: Array.from(new FormData(form).entries())
    \\      })),
    \\      customState: window.__CRAFT_STATE__ || {},
    \\      viewport: {
    \\        width: window.innerWidth,
    \\        height: window.innerHeight,
    \\        scale: window.devicePixelRatio
    \\      },
    \\      orientation: screen.orientation?.type || 'unknown',
    \\      timestamp: Date.now()
    \\    };
    \\    try {
    \\      sessionStorage.setItem(STATE_KEY, JSON.stringify(state));
    \\      console.log('[Craft Mobile HotReload] State saved');
    \\    } catch (e) {
    \\      console.error('[Craft Mobile HotReload] Failed to save state:', e);
    \\    }
    \\  }
    \\
    \\  function restoreState() {
    \\    const stateStr = sessionStorage.getItem(STATE_KEY);
    \\    if (!stateStr) return;
    \\
    \\    try {
    \\      const state = JSON.parse(stateStr);
    \\
    \\      // Restore scroll position (delayed for mobile)
    \\      if (state.scroll) {
    \\        const restoreScroll = () => window.scrollTo(state.scroll.x, state.scroll.y);
    \\        setTimeout(restoreScroll, 100);
    \\      }
    \\
    \\      // Restore form data
    \\      if (state.forms) {
    \\        state.forms.forEach(formState => {
    \\          const form = document.getElementById(formState.id);
    \\          if (form) {
    \\            formState.data.forEach(([name, value]) => {
    \\              const field = form.elements[name];
    \\              if (field) field.value = value;
    \\            });
    \\          }
    \\        });
    \\      }
    \\
    \\      // Restore focus (skip on mobile soft keyboard)
    \\      if (!isMobile && state.focus && state.focus.selector) {
    \\        const element = document.querySelector(state.focus.selector);
    \\        if (element) {
    \\          element.focus();
    \\          if (element.setSelectionRange && state.focus.selectionStart !== undefined) {
    \\            element.setSelectionRange(state.focus.selectionStart, state.focus.selectionEnd);
    \\          }
    \\        }
    \\      }
    \\
    \\      // Restore custom state
    \\      if (state.customState) {
    \\        window.__CRAFT_STATE__ = state.customState;
    \\        window.dispatchEvent(new CustomEvent('craft:state-restored', { detail: state.customState }));
    \\      }
    \\
    \\      console.log('[Craft Mobile HotReload] State restored');
    \\    } catch (e) {
    \\      console.error('[Craft Mobile HotReload] Failed to restore state:', e);
    \\    }
    \\  }
    \\
    \\  function getSelector(element) {
    \\    if (element.id) return '#' + element.id;
    \\    if (element.className) return element.tagName.toLowerCase() + '.' + element.className.split(' ').join('.');
    \\    return element.tagName.toLowerCase();
    \\  }
    \\
    \\  function connect() {
    \\    try {
    \\      ws = new WebSocket(WS_URL);
    \\
    \\      ws.onopen = () => {
    \\        console.log('[Craft Mobile HotReload] Connected to ' + WS_URL);
    \\        reconnectAttempts = 0;
    \\        // Send platform info to server
    \\        ws.send(JSON.stringify({ type: 'hello', platform: isIOS ? 'ios' : 'android' }));
    \\      };
    \\
    \\      ws.onmessage = (event) => {
    \\        console.log('[Craft Mobile HotReload] Message:', event.data);
    \\        if (event.data === 'reload') {
    \\          console.log('[Craft Mobile HotReload] Reloading...');
    \\          saveState();
    \\          // Mobile-friendly reload with slight delay
    \\          setTimeout(() => location.reload(), 50);
    \\        }
    \\      };
    \\
    \\      ws.onclose = () => {
    \\        console.log('[Craft Mobile HotReload] Disconnected');
    \\        if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
    \\          reconnectAttempts++;
    \\          const delay = Math.min(1000 * reconnectAttempts, 10000); // Max 10s
    \\          console.log(`[Craft Mobile HotReload] Reconnecting in ${delay}ms... (${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})`);
    \\          setTimeout(connect, delay);
    \\        }
    \\      };
    \\
    \\      ws.onerror = (error) => {
    \\        console.error('[Craft Mobile HotReload] Error:', error);
    \\      };
    \\    } catch (e) {
    \\      console.error('[Craft Mobile HotReload] Failed to connect:', e);
    \\      // Retry on error
    \\      if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
    \\        reconnectAttempts++;
    \\        setTimeout(connect, 2000);
    \\      }
    \\    }
    \\  }
    \\
    \\  // Restore state on page load
    \\  if (document.readyState === 'loading') {
    \\    document.addEventListener('DOMContentLoaded', restoreState);
    \\  } else {
    \\    restoreState();
    \\  }
    \\
    \\  // Start connection
    \\  connect();
    \\
    \\  // Expose reload function for native bridge
    \\  if (window.craft) {
    \\    window.craft.__hotReload = {
    \\      saveState,
    \\      restoreState,
    \\      reload: () => {
    \\        saveState();
    \\        location.reload();
    \\      }
    \\    };
    \\  }
    \\})();
    \\</script>
;

// Client-side hot reload script with state preservation
pub const client_script =
    \\<script>
    \\(function() {
    \\  const WS_URL = 'ws://localhost:3456/_craft_reload';
    \\  const STATE_KEY = 'craft_hotreload_state';
    \\  let ws = null;
    \\  let reconnectAttempts = 0;
    \\  const MAX_RECONNECT_ATTEMPTS = 10;
    \\
    \\  // State preservation
    \\  function saveState() {
    \\    const state = {
    \\      scroll: { x: window.scrollX, y: window.scrollY },
    \\      focus: document.activeElement ? {
    \\        selector: getSelector(document.activeElement),
    \\        selectionStart: document.activeElement.selectionStart,
    \\        selectionEnd: document.activeElement.selectionEnd
    \\      } : null,
    \\      forms: Array.from(document.forms).map(form => ({
    \\        id: form.id,
    \\        data: Array.from(new FormData(form).entries())
    \\      })),
    \\      customState: window.__ZYTE_STATE__ || {},
    \\      timestamp: Date.now()
    \\    };
    \\    sessionStorage.setItem(STATE_KEY, JSON.stringify(state));
    \\    console.log('[Craft HotReload] State saved');
    \\  }
    \\
    \\  function restoreState() {
    \\    const stateStr = sessionStorage.getItem(STATE_KEY);
    \\    if (!stateStr) return;
    \\
    \\    try {
    \\      const state = JSON.parse(stateStr);
    \\
    \\      // Restore scroll position
    \\      if (state.scroll) {
    \\        window.scrollTo(state.scroll.x, state.scroll.y);
    \\      }
    \\
    \\      // Restore form data
    \\      if (state.forms) {
    \\        state.forms.forEach(formState => {
    \\          const form = document.getElementById(formState.id);
    \\          if (form) {
    \\            formState.data.forEach(([name, value]) => {
    \\              const field = form.elements[name];
    \\              if (field) field.value = value;
    \\            });
    \\          }
    \\        });
    \\      }
    \\
    \\      // Restore focus
    \\      if (state.focus && state.focus.selector) {
    \\        const element = document.querySelector(state.focus.selector);
    \\        if (element) {
    \\          element.focus();
    \\          if (element.setSelectionRange && state.focus.selectionStart !== undefined) {
    \\            element.setSelectionRange(state.focus.selectionStart, state.focus.selectionEnd);
    \\          }
    \\        }
    \\      }
    \\
    \\      // Restore custom state
    \\      if (state.customState) {
    \\        window.__ZYTE_STATE__ = state.customState;
    \\        window.dispatchEvent(new CustomEvent('craft:state-restored', { detail: state.customState }));
    \\      }
    \\
    \\      console.log('[Craft HotReload] State restored');
    \\    } catch (e) {
    \\      console.error('[Craft HotReload] Failed to restore state:', e);
    \\    }
    \\  }
    \\
    \\  function getSelector(element) {
    \\    if (element.id) return '#' + element.id;
    \\    if (element.className) return element.tagName.toLowerCase() + '.' + element.className.split(' ').join('.');
    \\    return element.tagName.toLowerCase();
    \\  }
    \\
    \\  function connect() {
    \\    ws = new WebSocket(WS_URL);
    \\
    \\    ws.onopen = () => {
    \\      console.log('[Craft HotReload] Connected');
    \\      reconnectAttempts = 0;
    \\    };
    \\
    \\    ws.onmessage = (event) => {
    \\      if (event.data === 'reload') {
    \\        console.log('[Craft HotReload] Reloading...');
    \\        saveState();
    \\        location.reload();
    \\      }
    \\    };
    \\
    \\    ws.onclose = () => {
    \\      console.log('[Craft HotReload] Disconnected');
    \\      if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
    \\        reconnectAttempts++;
    \\        setTimeout(connect, 1000 * reconnectAttempts);
    \\      }
    \\    };
    \\
    \\    ws.onerror = (error) => {
    \\      console.error('[Craft HotReload] Error:', error);
    \\    };
    \\  }
    \\
    \\  // Restore state on page load
    \\  if (document.readyState === 'loading') {
    \\    document.addEventListener('DOMContentLoaded', restoreState);
    \\  } else {
    \\    restoreState();
    \\  }
    \\
    \\  connect();
    \\})();
    \\</script>
;
