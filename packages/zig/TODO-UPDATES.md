# Zig 0.16 Migration Progress

This document tracks the progress of migrating the Craft framework to Zig 0.16.

## Migration Status

| Status | Description |
|--------|-------------|
| ✅ | Completed |
| 🔄 | In Progress |
| ❌ | Not Started |

---

## Completed Source File Fixes ✅

### Core API Changes Applied

| File | Issue | Fix | Status |
|------|-------|-----|--------|
| `src/animation.zig` | Variable shadowing (`start` parameter) | Renamed to `start_val`, `start_instant` | ✅ |
| `src/async.zig` | ArrayList API (Promise, EventLoop, Channels) | Changed to unmanaged pattern | ✅ |
| `src/toast.zig` | `std.time.milliTimestamp()` removed | Added `getMilliTimestamp()` helper | ✅ |
| `src/benchmark.zig` | `ArrayList.writer()` removed | Replaced with `allocPrint` + `appendSlice` | ✅ |
| `src/config.zig` | `file.readToEndAlloc()` and `file.writer()` removed | Used new `reader(&buf)` API | ✅ |
| `src/hotreload.zig` | HashMap API + `stat.mtime.sec` removed | Fixed managed HashMap + `mtime.nanoseconds` | ✅ |
| `src/ipc.zig` | ArrayList API (MessageQueue) | Changed to unmanaged pattern | ✅ |
| `src/objc_runtime.zig` | `objc_msgSend` not public | Made extern functions `pub` | ✅ |
| `src/memory.zig` | Allocator alignment type changed | Changed `u8` to `std.mem.Alignment` | ✅ |
| `src/mobile.zig` | `usingnamespace` keyword removed | Converted to `comptime` + `@export` | ✅ |
| `src/theme.zig` | ArrayList/HashMap API | Fixed both managed and unmanaged patterns | ✅ |
| `src/events.zig` | HashMap API | Fixed managed StringHashMap pattern | ✅ |
| `src/profiler.zig` | `ArrayList.writer()` removed | Fixed with `appendSlice` pattern | ✅ |
| `src/lifecycle.zig` | HashMap API | Fixed managed pattern | ✅ |
| `src/error_context.zig` | Timestamp + ArrayList API | Fixed both APIs | ✅ |

### CallingConvention Changes

The following files had `callconv(.C)` changed to `callconv(.c)`:
- `src/mobile.zig`
- `src/windows.zig`
- `src/system.zig`
- `src/objc_runtime.zig`
- `src/notifications.zig`
- `src/linux.zig`
- `src/js_bridge.zig`

---

## Build Status

- **Main Build**: ✅ Passes
- **Tests Passing**: 42 tests pass

---

## Remaining Work 🔄

### Test File Fixes Needed

| File | Issue | Status |
|------|-------|--------|
| `test/profiler_test.zig` | `std.time.sleep` removed, `ProfileEntry` field types | ❌ |
| `test/animation_test.zig` | Struct field mismatches | ✅ |
| `test/config_test.zig` | `parseToml` not public (test design issue) | ❌ |
| `test/log_test.zig` | Reader API changes | ❌ |
| `test/components_test.zig` | Missing component exports | ❌ |
| `test/ipc_test.zig` | Closure capture issues | ❌ |
| `test/hotreload_test.zig` | Closure capture issues | ❌ |
| `test/performance_test.zig` | Module path imports | ❌ |

---

## Zig 0.16 API Migration Guide

### ArrayList (Unmanaged)

**Before (0.13):**
```zig
var list = std.ArrayList(T).init(allocator);
try list.append(item);
list.deinit();
```

**After (0.16):**
```zig
var list: std.ArrayList(T) = .{};
try list.append(allocator, item);
list.deinit(allocator);
```

### StringHashMap (Managed)

**Before (0.13):**
```zig
var map = std.StringHashMap(V){};
try map.put(allocator, key, value);
map.deinit(allocator);
```

**After (0.16):**
```zig
var map = std.StringHashMap(V).init(allocator);
try map.put(key, value);
map.deinit();
```

### Time Functions

**Before (0.13):**
```zig
const timestamp = std.time.milliTimestamp();
std.time.sleep(1_000_000); // 1ms
```

**After (0.16):**
```zig
// For timestamps:
fn getMilliTimestamp() i64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
}

// For sleep:
std.posix.nanosleep(0, 1_000_000); // 1ms
```

### File I/O

**Before (0.13):**
```zig
const content = try file.readToEndAlloc(allocator, max_size);
const writer = file.writer();
try writer.writeAll("data");
```

**After (0.16):**
```zig
// Reading:
var buf: [4096]u8 = undefined;
var reader = file.reader(&buf);
const content = try reader.readAllAlloc(allocator, max_size);

// Writing (direct):
_ = try file.write("data");

// Writing (formatted):
var line = try std.fmt.bufPrint(&buf, "value: {d}\n", .{value});
_ = try file.write(line);
```

### ArrayList Writer Pattern

**Before (0.13):**
```zig
var buf = std.ArrayList(u8).init(allocator);
const writer = buf.writer();
try writer.print("Hello {s}", .{name});
return buf.toOwnedSlice();
```

**After (0.16):**
```zig
var buf: std.ArrayList(u8) = .{};
errdefer buf.deinit(allocator);

const line = try std.fmt.allocPrint(allocator, "Hello {s}", .{name});
defer allocator.free(line);
try buf.appendSlice(allocator, line);

return buf.toOwnedSlice(allocator);
```

### Calling Convention

**Before (0.13):**
```zig
fn callback() callconv(.C) void {}
```

**After (0.16):**
```zig
fn callback() callconv(.c) void {}
```

### usingnamespace Removal

**Before (0.13):**
```zig
pub usingnamespace if (condition) struct {
    export fn foo() void {}
} else struct {};
```

**After (0.16):**
```zig
comptime {
    if (condition) {
        @export(&foo_impl, .{ .name = "foo" });
    }
}

fn foo_impl() callconv(.c) void {}
```

### Allocator VTable Alignment

**Before (0.13):**
```zig
fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
```

**After (0.16):**
```zig
fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
```

### File Stat mtime

**Before (0.13):**
```zig
const mtime = stat.mtime.sec;
```

**After (0.16):**
```zig
const mtime: i64 = @intCast(@divTrunc(stat.mtime.nanoseconds, 1_000_000_000));
```

---

## Feature Implementation Status (vs README Claims)

### UI Components

The README claims **35 native UI components**. Here's what's actually implemented:

#### Exported in `components.zig` (17 components) ✅

| Component | File | Status |
|-----------|------|--------|
| Button | `button.zig` | ✅ Implemented |
| TextInput | `text_input.zig` | ✅ Implemented |
| Tabs | `tabs.zig` | ✅ Implemented |
| Modal | `modal.zig` | ✅ Implemented |
| ProgressBar | `progress_bar.zig` | ✅ Implemented |
| Dropdown | `dropdown.zig` | ✅ Implemented |
| Toast/ToastManager | `toast.zig` | ✅ Implemented |
| TreeView | `tree_view.zig` | ✅ Implemented |
| DatePicker | `date_picker.zig` | ✅ Implemented |
| DataGrid | `data_grid.zig` | ✅ Implemented |
| Tooltip | `tooltip.zig` | ✅ Implemented |
| Slider | `slider.zig` | ✅ Implemented |
| Autocomplete | `autocomplete.zig` | ✅ Implemented |
| ColorPicker | `color_picker.zig` | ✅ Implemented |
| Chart | `chart.zig` | ✅ Implemented |
| MediaPlayer | `media_player.zig` | ✅ Implemented |
| CodeEditor | `code_editor.zig` | ✅ Implemented |

#### Implemented but NOT Exported (21 components) 🔄

These exist in `src/components/` but aren't exported in `components.zig`:

| Component | File | Status |
|-----------|------|--------|
| Accordion | `accordion.zig` | 🔄 Not exported |
| ContextMenu | `context_menu.zig` | 🔄 Not exported |
| DragDrop | `drag_drop.zig` | 🔄 Not exported |
| KeyboardHandler | `keyboard_handler.zig` | 🔄 Not exported |
| ListView | `list_view.zig` | 🔄 Not exported |
| Menu | `menu.zig` | 🔄 Not exported |
| NativeFileBrowser | `native_file_browser.zig` | 🔄 Not exported |
| NativeSidebar | `native_sidebar.zig` | 🔄 Not exported |
| NativeSplitView | `native_split_view.zig` | 🔄 Not exported |
| OutlineView | `outline_view_*.zig` | 🔄 Not exported |
| QuickLook | `quick_look.zig` | 🔄 Not exported |
| StatusBar | `status_bar.zig` | 🔄 Not exported |
| Stepper | `stepper.zig` | 🔄 Not exported |
| TableView | `table_view_*.zig` | 🔄 Not exported |
| TimePicker | `time_picker.zig` | 🔄 Not exported |
| Toolbar | `toolbar.zig` | 🔄 Not exported |

#### Missing Components (Claimed in README but don't exist) ❌

| Component | Status | Priority |
|-----------|--------|----------|
| Checkbox | ❌ Missing | High |
| Radio/RadioButton | ❌ Missing | High |
| Label | ❌ Missing | High |
| ImageView | ❌ Missing | Medium |
| ScrollView | ❌ Missing | Medium |
| Table (separate from DataGrid) | ❌ Missing | Low |
| TabView (vs Tabs?) | ❌ Clarify naming | Low |

### Core Features

| Feature | Status | Notes |
|---------|--------|-------|
| Window Management | ✅ | `api.zig`, platform-specific implementations |
| WebView Integration | ✅ | macOS (WKWebView), Linux (WebKit2GTK), Windows (WebView2) |
| GPU Rendering | ✅ | `gpu.zig` - 47KB implementation |
| Mobile Support | ✅ | `mobile.zig` - iOS/Android templates |
| System Integration | ✅ | Notifications, clipboard, dialogs, tray |
| Hot Reload | ✅ | `hotreload.zig` - file watching + state preservation |
| IPC | ✅ | `ipc.zig` - channels, message queue, RPC |
| Error Handling | ✅ | `error_context.zig` - 40+ error codes |
| Benchmarking | ✅ | `benchmark.zig` - statistical analysis |
| Profiler | ✅ | `profiler.zig` - timing + memory tracking |
| Accessibility | ✅ | `accessibility.zig` - ARIA roles |
| Theme System | ✅ | `theme.zig` - CSS generation |
| Animation | ✅ | `animation.zig` - 31 easing functions |

### Platform Support

| Platform | Window | WebView | Tray | Notifications | Status |
|----------|--------|---------|------|---------------|--------|
| macOS | ✅ | ✅ WKWebView | ✅ | ✅ | Full |
| Linux | ✅ | ✅ WebKit2GTK | ✅ | ✅ | Full |
| Windows | ✅ | ✅ WebView2 | ✅ | ✅ | Full |
| iOS | 🔄 | 🔄 | N/A | 🔄 | Template |
| Android | 🔄 | 🔄 | N/A | 🔄 | Template |

---

## Priority Tasks

### High Priority ❗

1. **Create missing core components:**
   - `checkbox.zig` - Basic form component
   - `radio.zig` - Radio button group
   - `label.zig` - Text label component

2. **Export existing components in `components.zig`:**
   - Add exports for ListView, StatusBar, Toolbar, TimePicker, etc.

3. **Fix remaining test files** for CI/CD

### Medium Priority

4. **Add missing components:**
   - `image_view.zig` - Image display
   - `scroll_view.zig` - Scrollable container

5. **Update README.md:**
   - Correct component count (currently 38 files, 17 exported)
   - Update Zig version requirement to 0.16

### Low Priority

6. **Mobile implementation completion** - iOS/Android beyond templates
7. **Documentation** - API docs for all components
8. **Examples** - More usage examples

---

## Notes

- The main library builds successfully with Zig 0.16
- 42 unit tests pass
- Remaining test file issues are mostly test infrastructure problems, not core functionality
- Some test files use patterns that require refactoring (closure captures, private function access)
- Total component files: 38 (in `src/components/`)
- Exported components: 17 (in `components.zig`)
- Missing claimed components: 5-7 (Checkbox, Radio, Label, ImageView, ScrollView, etc.)

---

*Last updated: 2025-12-10*
