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
    storage_key: []const u8 = "zyte_hotreload_state",
    preserve_scroll: bool = true,
    preserve_form_data: bool = true,
    preserve_focus: bool = true,
    preserve_custom_state: bool = true,
};

// Client-side hot reload script with state preservation
pub const client_script =
    \\<script>
    \\(function() {
    \\  const WS_URL = 'ws://localhost:3456/_zyte_reload';
    \\  const STATE_KEY = 'zyte_hotreload_state';
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
    \\    console.log('[Zyte HotReload] State saved');
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
    \\        window.dispatchEvent(new CustomEvent('zyte:state-restored', { detail: state.customState }));
    \\      }
    \\
    \\      console.log('[Zyte HotReload] State restored');
    \\    } catch (e) {
    \\      console.error('[Zyte HotReload] Failed to restore state:', e);
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
    \\      console.log('[Zyte HotReload] Connected');
    \\      reconnectAttempts = 0;
    \\    };
    \\
    \\    ws.onmessage = (event) => {
    \\      if (event.data === 'reload') {
    \\        console.log('[Zyte HotReload] Reloading...');
    \\        saveState();
    \\        location.reload();
    \\      }
    \\    };
    \\
    \\    ws.onclose = () => {
    \\      console.log('[Zyte HotReload] Disconnected');
    \\      if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
    \\        reconnectAttempts++;
    \\        setTimeout(connect, 1000 * reconnectAttempts);
    \\      }
    \\    };
    \\
    \\    ws.onerror = (error) => {
    \\      console.error('[Zyte HotReload] Error:', error);
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
