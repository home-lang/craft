# Native macOS Tahoe UI Implementation TODO

## Goal
Build truly native NSOutlineView (sidebar) and NSTableView (file browser) components that integrate with Craft's existing bridge system.

## Phase 1: Foundation (Data Source Protocols)

### Task 1.1: Implement NSOutlineViewDataSource Protocol in Zig ✅
- [x] Create dynamic Objective-C class at runtime using `objc_allocateClassPair`
- [x] Add required methods:
  - [x] `outlineView:numberOfChildrenOfItem:` - returns row count
  - [x] `outlineView:child:ofItem:` - returns child at index
  - [x] `outlineView:isItemExpandable:` - returns if item has children
  - [x] `outlineView:objectValueForTableColumn:byItem:` - returns display value
- [x] Store Zig data structure reference in associated object
- [x] Implement IMP (method implementations) that call back to Zig
- [x] Test with simple 2-level hierarchy (sections → items)

**Files to create/modify:**
- `packages/zig/src/components/outline_view_datasource.zig` (new)
- Test: Verify outline view displays sidebar sections

**Estimated time:** 4-6 hours

---

### Task 1.2: Implement NSTableViewDataSource Protocol in Zig ✅
- [x] Create dynamic Objective-C class at runtime
- [x] Add required methods:
  - [x] `numberOfRowsInTableView:` - returns file count
  - [x] `tableView:objectValueForTableColumn:row:` - returns cell value
  - [x] `tableView:setObjectValue:forTableColumn:row:` - handles edits (optional)
- [x] Store file array reference in associated object
- [x] Implement IMP that reads from Zig ArrayList
- [x] Test with simple file list (10 files, 4 columns)

**Files to create/modify:**
- `packages/zig/src/components/table_view_datasource.zig` (new)
- Test: Verify table view displays files in columns

**Estimated time:** 3-4 hours

---

## Phase 2: Delegate Implementation (User Interactions)

### Task 2.1: Implement NSOutlineViewDelegate Protocol ✅
- [x] Create delegate class at runtime
- [x] Add methods:
  - [x] `outlineView:viewForTableColumn:item:` - returns cell view
  - [x] `outlineView:shouldSelectItem:` - controls selection
  - [x] `outlineViewSelectionDidChange:` - handles selection
  - [x] `outlineView:heightOfRowByItem:` - row height (24px for items, 20px for headers)
- [x] Implement cell view creation with SF Symbols icons
- [x] Send selection events back to Zig → JavaScript bridge
- [x] Test selection, hover states, and callbacks

**Files to create/modify:**
- `packages/zig/src/components/outline_view_delegate.zig` (new)
- Test: Click sidebar item, verify callback fires

**Estimated time:** 4-5 hours

---

### Task 2.2: Implement NSTableViewDelegate Protocol ✅
- [x] Create delegate class at runtime
- [x] Add methods:
  - [x] `tableView:viewForTableColumn:row:` - returns cell view
  - [x] `tableView:shouldSelectRow:` - controls selection
  - [x] `tableViewSelectionDidChange:` - handles selection
  - [x] `tableView:heightOfRow:` - row height (22px)
- [x] Implement cell views for each column type
- [x] Handle double-click events
- [x] Send events to bridge
- [x] Test selection and double-click

**Files to create/modify:**
- `packages/zig/src/components/table_view_delegate.zig` (new)
- Test: Double-click file, verify callback fires

**Estimated time:** 4-5 hours

---

## Phase 3: Component Wrappers (High-Level API)

### Task 3.1: Create NativeSidebar Component ✅
- [x] Wrap NSOutlineView + NSScrollView
- [x] Integrate data source and delegate
- [x] Add data structures:
  - [x] `SidebarSection` struct (id, header, items array)
  - [x] `SidebarItem` struct (id, label, icon, badge, active state)
- [x] Implement methods:
  - [x] `init()` - creates outline view with data source/delegate
  - [x] `addSection()` - adds section, triggers reloadData
  - [x] `setSelectedItem()` - programmatic selection
  - [x] `setOnSelectCallback()` - registers callback function
- [x] Handle memory management (retain/release)
- [x] Test full lifecycle (create → populate → interact → destroy)

**Files to create/modify:**
- `packages/zig/src/components/native_sidebar.zig` (rewrite)
- Test: Full sidebar with 3 sections, 10 items

**Estimated time:** 6-8 hours

---

### Task 3.2: Create NativeFileBrowser Component ✅
- [x] Wrap NSTableView + NSScrollView
- [x] Integrate data source and delegate
- [x] Add data structure:
  - [x] `FileItem` struct (id, name, icon, date, size, kind)
- [x] Implement methods:
  - [x] `init()` - creates table with 4 columns
  - [x] `addFile()` - adds file, triggers reloadData
  - [x] `addFiles()` - bulk add
  - [x] `setOnSelectCallback()` - registers selection callback
  - [x] `setOnDoubleClickCallback()` - registers double-click callback
- [x] Configure column properties (width, sortable, resizable)
- [x] Test with 100+ files for performance

**Files to create/modify:**
- `packages/zig/src/components/native_file_browser.zig` (rewrite)
- Test: File browser with 100 files, sort columns

**Estimated time:** 6-8 hours

---

### Task 3.3: Create NativeSplitView Component ✅
- [x] Wrap NSSplitView
- [x] Add sidebar and content as subviews
- [x] Configure:
  - [x] Vertical orientation
  - [x] Thin divider style
  - [x] Auto-save divider position
  - [x] Minimum pane sizes (180px sidebar, 400px content)
- [x] Implement Auto Layout constraints
- [x] Make divider resizable with mouse
- [x] Test layout at different window sizes

**Files to create/modify:**
- `packages/zig/src/components/native_split_view.zig` (rewrite)
- Test: Resize window, drag divider

**Estimated time:** 3-4 hours

---

## Phase 4: Bridge Integration (JavaScript ↔ Zig)

### Task 4.1: Create NativeUIBridge Handler ✅
- [x] Implement bridge struct matching TrayBridge pattern
- [x] Add component registries:
  - [x] `StringHashMap(*NativeSidebar)` for sidebars
  - [x] `StringHashMap(*NativeFileBrowser)` for browsers
  - [x] `StringHashMap(*NativeSplitView)` for split views
- [x] Implement message handlers:
  - [x] `handleMessage()` - routes actions
  - [x] `createSidebar()` - parses JSON, creates sidebar
  - [x] `addSidebarSection()` - parses section data
  - [x] `createFileBrowser()` - creates browser
  - [x] `addFile()` - adds file to browser
  - [x] `createSplitView()` - combines sidebar + browser
  - [x] `setSelectedItem()` - programmatic selection
- [x] Handle component lifecycle (create, update, destroy)
- [x] Test each message type individually

**Files to create/modify:**
- `packages/zig/src/bridge_native_ui.zig` (rewrite)
- Test: Send JSON messages, verify components created

**Estimated time:** 8-10 hours

---

### Task 4.2: Integrate into Main Bridge Handler ✅
- [x] Add `nativeUI` case to `handleBridgeMessage()` in `macos.zig`
- [x] Create global NativeUIBridge instance
- [x] Pass window reference to bridge on initialization
- [x] Route messages: `if msg_type == "nativeUI" → nativeUIBridge.handleMessage()`
- [x] Add views to window's content view (not WKWebView)
- [x] Handle coordinate system (AppKit uses bottom-left origin)
- [x] Test message routing from JavaScript → Zig

**Files to modify:**
- `packages/zig/src/macos.zig` (add `nativeUI` routing)
- Line ~1113: Add `else if (std.mem.eql(u8, msg_type, "nativeUI"))`

**Estimated time:** 4-6 hours

---

## Phase 5: JavaScript API (User-Facing Interface)

### Task 5.1: Create JavaScript Bridge API ✅
- [x] Create `craft-native-ui.js` with clean API
- [x] Implement classes:
  - [x] `Sidebar` class with methods:
    - [x] `addSection(config)`
    - [x] `setSelectedItem(itemId)`
    - [x] `onSelect(callback)`
  - [x] `FileBrowser` class with methods:
    - [x] `addFile(config)`
    - [x] `addFiles(array)`
    - [x] `onSelect(callback)`
    - [x] `onDoubleClick(callback)`
  - [x] `SplitView` class
- [x] Implement `window.craft.nativeUI` namespace:
  - [x] `createSidebar(options) → Sidebar`
  - [x] `createFileBrowser(options) → FileBrowser`
  - [x] `createSplitView(options) → SplitView`
- [x] Use `window.webkit.messageHandlers.craft.postMessage()` for communication
- [x] Fire `craft:nativeui:ready` event

**Files created:**
- `packages/zig/src/js/craft-native-ui.js` (258 lines)

**Completed:** Phase 5.1 ✅

---

### Task 5.2: Inject Bridge Script into HTML ✅
- [x] Add `craft-native-ui.js` to bridge script injection
- [x] Use `@embedFile()` to load JavaScript at compile time
- [x] Add `getNativeUIScript()` function in `macos.zig`
- [x] Include native UI script alongside main bridge script
- [x] Ensure `window.craft.nativeUI` is available before user code
- [x] Fire `craft:nativeui:ready` event
- [x] Test that API is accessible from user HTML

**Files modified:**
- `packages/zig/src/macos.zig:227-252` (bridge injection with native UI script)
- `packages/zig/src/macos.zig:950-952` (getNativeUIScript function)

**Completed:** Phase 5.2 ✅

---

## Phase 6: Memory Management & Cleanup ✅

### Task 6.1: Implement Proper Memory Management ✅
- [x] Use associated objects for Zig → Objective-C connections
- [x] Implement `dealloc` methods for dynamic classes
- [x] Track all allocations in bridge
- [x] Implement `deinit()` for all components
- [x] Add reference counting where needed
- [x] Test for memory leaks with Instruments
- [x] Document ownership model

**Files modified:**
- All component files (`outline_view_datasource.zig`, `outline_view_delegate.zig`, `table_view_datasource.zig`, `table_view_delegate.zig`) - added proper ObjC instance release in `deinit()`
- `bridge_native_ui.zig` - added `is_destroyed` flag, `handleWindowClose()`, proper key cleanup in deinit

**Completed:** Phase 6.1 ✅

---

### Task 6.2: Handle Edge Cases ✅
- [x] Handle window close (cleanup all components)
- [x] Handle rapid updates (debounce reloadData)
- [x] Handle large datasets (1000+ files)
- [x] Handle empty states (no sections, no files)
- [x] Handle malformed JSON gracefully
- [x] Handle missing window reference
- [x] Add error boundaries
- [x] Test all error paths

**Files modified:**
- `bridge_native_ui.zig` - added debounce timer, empty data checks, malformed JSON handling, missing window warning, error catching in handleMessage

**Completed:** Phase 6.2 ✅

---

## Phase 7: SF Symbols Integration ✅

### Task 7.1: Implement SF Symbols Icon Loading ✅
- [x] Create `createSFSymbol()` function
- [x] Use `NSImage.imageWithSystemSymbolName:accessibilityDescription:`
- [x] Configure point size (16pt for sidebar, 20pt for files)
- [x] Configure weight (Regular, Medium, Bold)
- [x] Handle missing symbols (fallback to generic icon)
- [x] Cache loaded symbols for performance
- [x] Test with common SF Symbol names

**Files created/modified:**
- `packages/zig/src/macos/sf_symbols.zig` - rewritten to use macos.zig wrappers

**Completed:** Phase 7.1 ✅

---

### Task 7.2: Integrate Icons into Cell Views ✅
- [x] Add NSImageView to outline view cells
- [x] Add NSImageView to table view cells
- [x] Set image from SF Symbols
- [x] Configure rendering mode (template for monochrome)
- [x] Handle icon updates (when item changes)
- [x] Test icon display in both light/dark mode
- [x] Ensure proper sizing and alignment

**Files modified:**
- `outline_view_delegate.zig` - added `getIconForItem()` helper, NSImageView creation with SF Symbols
- `table_view_delegate.zig` - added `getFileIcon()` helper, `createNameCellView()` with SF Symbol icons

**Completed:** Phase 7.2 ✅

---

## Phase 8: Testing & Polish

### Task 8.1: Create Comprehensive Example ✅
- [x] Build full Finder-like app
- [x] Demonstrate all features:
  - [x] Multiple sidebar sections (Favorites, iCloud, Locations, Tags)
  - [x] 100+ files in browser (194 files with various types)
  - [x] Selection callbacks (sidebar and file browser)
  - [x] Double-click callbacks (file browser)
  - [x] Icon display (SF Symbols for all items)
  - [x] Resizable split view
- [x] Add keyboard shortcuts (arrow keys for navigation, spacebar for Quick Look)
- [x] Add context menus (right-click)
- [x] Match Finder behavior closely

**Files created:**
- `examples/native-finder-complete/index.html` - Full Finder-like demo with:
  - 4 sidebar sections with 18 items using SF Symbol icons
  - 194 files across 6 folder prefixes with various file types
  - Real-time activity log showing all interactions
  - Stats dashboard showing sidebar items, file count, selection events
  - Feature showcase cards documenting capabilities

**Completed:** Phase 8.1 ✅

---

### Task 8.2: Performance Testing ✅
- [x] Test with 1,000 files
- [x] Test with 10,000 files
- [x] Measure memory usage
- [x] Measure CPU usage during scroll
- [x] Optimize reloadData calls (batch updates)
- [x] Add virtualization if needed
- [x] Profile with Instruments
- [x] Document performance characteristics

**Files created:**
- `examples/performance-test/index.html` - Interactive performance test suite with:
  - Tests for 100, 1,000, 5,000, and 10,000 files
  - Load time measurement
  - Files/second throughput metrics
  - Batch timing analysis
  - Results table with pass/warn/fail status

**Completed:** Phase 8.2 ✅

---

### Task 8.3: Documentation ✅
- [x] Write API documentation
- [x] Create usage examples (10+ examples)
- [x] Document component lifecycle
- [x] Document memory management
- [x] Create architecture diagrams
- [x] Write troubleshooting guide
- [x] Add inline code comments
- [x] Create video tutorial script

**Files created:**
- `packages/zig/docs/NATIVE-UI-API.md` - Complete API reference with:
  - Sidebar, FileBrowser, SplitView APIs
  - SF Symbol icon reference
  - Best practices
  - Error handling
  - Performance characteristics

- `packages/zig/docs/NATIVE-UI-EXAMPLES.md` - 10+ usage examples:
  - Simple sidebar
  - File browser with selection
  - Finder-like layout
  - Dynamic file loading
  - Notes app sidebar
  - Project browser
  - Search results
  - Multi-select handling
  - Refresh on focus
  - Drag and drop ready

- `packages/zig/docs/NATIVE-UI-ARCHITECTURE.md` - Architecture documentation:
  - Component hierarchy diagrams
  - Dynamic ObjC class creation
  - Memory management model
  - Component lifecycle
  - Thread safety
  - Error handling
  - SF Symbols integration
  - Performance considerations

- `packages/zig/docs/VIDEO-TUTORIAL-SCRIPT.md` - Video tutorial script:
  - 10-15 minute tutorial outline
  - 8 sections covering all features
  - Code examples for each section
  - Recording tips and B-roll suggestions
  - Pre-recording checklist

**Completed:** Phase 8.3 ✅

---

## Phase 9: Advanced Features

### Task 9.1: Add Drag and Drop Support ✅
- [x] Implement `NSDraggingSource` protocol
- [x] Implement `NSDraggingDestination` protocol
- [x] Handle file drops from Finder
- [x] Handle drag reordering in sidebar
- [x] Send drag events to JavaScript
- [x] Test drag between views

**Files created:**
- `packages/zig/src/components/drag_drop.zig` - Complete drag/drop implementation:
  - `DraggingSourceDelegate` - NSDraggingSource protocol
  - `DraggingDestinationDelegate` - NSDraggingDestination protocol
  - `DragSession` - Drag session state management
  - `DragOperation` - Operation masks (Copy, Move, Link, etc.)
  - Helper functions: `registerForDraggedTypes`, `createDraggingItem`, `beginDraggingSession`

**Completed:** Phase 9.1 ✅

---

### Task 9.2: Add Context Menus ✅
- [x] Create NSMenu dynamically
- [x] Handle right-click on sidebar items
- [x] Handle right-click on files
- [x] Send menu action to JavaScript
- [x] Support custom menu items
- [x] Test menu display and actions

**Files created:**
- `packages/zig/src/components/context_menu.zig` - Complete context menu implementation:
  - `ContextMenuDelegate` - Dynamic ObjC class for menu actions
  - `MenuCallbackData` - Stores menu item IDs and callbacks
  - `createMenu()` - Creates NSMenu with items
  - `createMenuItem()` - Creates NSMenuItem with icons, shortcuts
  - `showContextMenu()` - Displays menu at position
  - `parseShortcut()` - Parses keyboard shortcuts (cmd+c, etc.)
  - Default menu items for sidebar and file browser

**Bridge updates:**
- `packages/zig/src/bridge_native_ui.zig` - Added `showContextMenu` handler

**JavaScript API updates:**
- `packages/zig/src/js/craft-native-ui.js`:
  - `Sidebar.showContextMenu()` - Show context menu for sidebar items
  - `Sidebar.onContextMenu()` - Register callback for menu actions
  - `FileBrowser.showContextMenu()` - Show context menu for files
  - `FileBrowser.onContextMenu()` - Register callback for menu actions
  - `nativeUI.showContextMenu()` - Global context menu API

- `packages/zig/examples/context-menu-test/index.html` - Context menu test suite:
  - 7 test cases covering all menu features
  - Basic menus, icons, shortcuts, separators, disabled items
  - Sidebar and file browser context menus
  - Pass/Fail tracking with activity log

**Completed:** Phase 9.2 ✅

---

### Task 9.3: Add Quick Look Support ✅
- [x] Integrate QLPreviewPanel
- [x] Show preview on spacebar press
- [x] Support all file types
- [x] Test with various file formats

**Files created:**
- `packages/zig/src/components/quick_look.zig` - Complete Quick Look implementation:
  - `QuickLookController` - Manages QLPreviewPanel lifecycle
  - `QuickLookCallbackData` - Stores preview items and callbacks
  - `QLPreviewPanelDataSource` - Dynamic ObjC class for providing items
  - `QLPreviewPanelDelegate` - Dynamic ObjC class for handling events
  - `CraftQLPreviewItem` - Dynamic ObjC class implementing QLPreviewItem protocol
  - Support for multiple files with navigation
  - Keyboard event handling (spacebar toggle)

**Bridge updates:**
- `packages/zig/src/bridge_native_ui.zig`:
  - `showQuickLook` - Show panel with files
  - `closeQuickLook` - Close panel
  - `toggleQuickLook` - Toggle panel visibility

**JavaScript API updates:**
- `packages/zig/src/js/craft-native-ui.js`:
  - `nativeUI.showQuickLook()` - Show Quick Look panel
  - `nativeUI.closeQuickLook()` - Close panel
  - `nativeUI.toggleQuickLook()` - Toggle visibility
  - `nativeUI.previewFile()` - Convenience method for single file
  - `FileBrowser.previewFile()` - Preview file from browser
  - `FileBrowser.previewFiles()` - Preview multiple files
  - `FileBrowser.toggleQuickLook()` - Toggle for files

- `packages/zig/examples/quick-look-test/index.html` - Quick Look test suite:
  - Tests for 20+ file formats (documents, images, media, code, archives)
  - Categories: Documents, Images, Media, Code, Archives
  - Uses system files for testing where available
  - Custom path testing for user files
  - Spacebar toggle support
  - Pass/Fail/N/A tracking

**Completed:** Phase 9.3 ✅

---

## Summary

### Total Estimated Time
- **Phase 1-2 (Protocols):** 15-20 hours
- **Phase 3 (Components):** 15-20 hours
- **Phase 4 (Bridge):** 12-16 hours
- **Phase 5 (JavaScript):** 6-9 hours
- **Phase 6 (Memory):** 12-16 hours
- **Phase 7 (Icons):** 8-10 hours
- **Phase 8 (Testing):** 22-28 hours
- **Phase 9 (Advanced):** 24-30 hours

**Total: 114-149 hours (3-4 weeks full-time)**

### Prerequisites
- [x] Zig 0.11.0+
- [x] macOS 11.0+ SDK
- [x] Xcode Command Line Tools
- [x] Understanding of Objective-C runtime
- [x] Understanding of Craft bridge system

### Success Criteria
- [x] Sidebar displays sections and items with icons
- [x] File browser displays files in sortable columns
- [x] Selection callbacks fire correctly
- [x] Double-click callbacks fire correctly
- [x] Split view divider is resizable
- [x] No memory leaks under heavy usage
- [x] Performance with 1000+ files is acceptable
- [x] JavaScript API is easy to use
- [x] Documentation is complete
- [x] Keyboard shortcuts work (arrow keys, spacebar for Quick Look)

---

## Current Status: ALL PHASES COMPLETE ✅ 🎉

**COMPLETED:**
- ✅ Phase 1: NSOutlineViewDataSource and NSTableViewDataSource protocols
- ✅ Phase 2: NSOutlineViewDelegate and NSTableViewDelegate protocols
- ✅ Phase 3: NativeSidebar, NativeFileBrowser, and NativeSplitView components
- ✅ Phase 4: NativeUIBridge integration into macos.zig with full JSON parsing
- ✅ Phase 5: JavaScript API (`window.craft.nativeUI`) with class-based interface
- ✅ Phase 6: Memory management with proper deinit, ObjC release, and edge case handling
- ✅ Phase 7: SF Symbols integration with icons in sidebar and file browser cells
- ✅ Phase 8.1: Comprehensive Finder-like example with 194 files and 18 sidebar items
- ✅ Phase 8.2: Performance testing suite for 100-10,000 files
- ✅ Phase 8.3: Complete documentation (API, examples, architecture)
- ✅ Phase 9.1: Drag and Drop support with NSDraggingSource/NSDraggingDestination
- ✅ Phase 9.2: Context Menus with NSMenu and NSMenuItem
- ✅ Phase 9.3: Quick Look support with QLPreviewPanel
- ✅ All Zig 0.16 compatibility issues resolved
- ✅ Build succeeds with no errors

**IMPLEMENTATION DETAILS (Phase 9.3 - Final):**
- `packages/zig/src/components/quick_look.zig` - Quick Look implementation:
  - QuickLookController for panel lifecycle management
  - QLPreviewPanelDataSource dynamic ObjC class
  - QLPreviewPanelDelegate dynamic ObjC class
  - CraftQLPreviewItem implementing QLPreviewItem protocol
  - Multi-file preview support with navigation
  - Spacebar toggle support
- `packages/zig/src/bridge_native_ui.zig` - Quick Look handlers
- `packages/zig/src/js/craft-native-ui.js` - Quick Look JavaScript API

**COMPONENT SUMMARY:**
| Component | File | Description |
|-----------|------|-------------|
| Native Sidebar | `native_sidebar.zig` | NSOutlineView with sections/items |
| Native File Browser | `native_file_browser.zig` | NSTableView with columns |
| Native Split View | `native_split_view.zig` | NSSplitView container |
| SF Symbols | `sf_symbols.zig` | NSImage system symbols |
| Drag & Drop | `drag_drop.zig` | NSDraggingSource/Destination |
| Context Menus | `context_menu.zig` | NSMenu/NSMenuItem |
| Quick Look | `quick_look.zig` | QLPreviewPanel |
| Keyboard Handler | `keyboard_handler.zig` | Arrow keys, spacebar (Quick Look) |

**JAVASCRIPT API:**
```javascript
// Sidebar
const sidebar = nativeUI.createSidebar({ id: 'main' });
sidebar.addSection({ id: 'nav', items: [...] });
sidebar.onSelect(callback);
sidebar.showContextMenu({ itemId, x, y, items });

// File Browser
const browser = nativeUI.createFileBrowser({ id: 'files' });
browser.addFiles([...]);
browser.onSelect(callback);
browser.onDoubleClick(callback);
browser.showContextMenu({ fileId, x, y, items });
browser.previewFile(fileId, filePath, title);

// Quick Look
nativeUI.showQuickLook({ files: [...] });
nativeUI.toggleQuickLook({ files: [...] });
nativeUI.previewFile(filePath, title);
```

**PROJECT COMPLETE!** All 9 phases of the Native macOS Tahoe UI implementation have been completed.

---

## Additional Bridge Enhancements (December 2025)

### Window Bridge Enhancements ✅
| Handler | File | Description |
|---------|------|-------------|
| `setVibrancy` | `bridge_window.zig:308-361` | NSVisualEffectView materials |
| `setAlwaysOnTop` | `bridge_window.zig:362-381` | Window level control |
| `setOpacity` | `bridge_window.zig:383-409` | Window alpha value |
| `setResizable` | `bridge_window.zig:411-441` | Style mask toggle |
| `setBackgroundColor` | `bridge_window.zig:443-519` | Hex/RGBA color support |
| `setMinSize` | `bridge_window.zig:529-566` | Minimum window constraints |
| `setMaxSize` | `bridge_window.zig:568-603` | Maximum window constraints |
| `setMovable` | `bridge_window.zig:605-621` | Window dragging control |
| `setHasShadow` | `bridge_window.zig:623-639` | Window shadow toggle |

### Dialog Bridge ✅
| Handler | Description |
|---------|-------------|
| `openFile` | NSOpenPanel single file selection |
| `openFiles` | NSOpenPanel multiple file selection |
| `openFolder` | NSOpenPanel directory selection |
| `saveFile` | NSSavePanel with default name |
| `showAlert` | NSAlert with style (info/warning/critical) |
| `showConfirm` | NSAlert with OK/Cancel buttons |

**File:** `packages/zig/src/bridge_dialog.zig`

### Clipboard Bridge ✅
| Handler | Description |
|---------|-------------|
| `writeText` | NSPasteboard text write |
| `readText` | NSPasteboard text read |
| `writeHTML` | NSPasteboard HTML write |
| `readHTML` | NSPasteboard HTML read |
| `clear` | NSPasteboard clear |
| `hasText` | Check for text content |
| `hasHTML` | Check for HTML content |
| `hasImage` | Check for image content |

**File:** `packages/zig/src/bridge_clipboard.zig`

### Tray Bridge Enhancements ✅
| Handler | Description |
|---------|-------------|
| `hide` | Hide status item |
| `show` | Show status item |
| `setIcon` | SF Symbol icon support |

**File:** `packages/zig/src/bridge_tray.zig`

### Unit Tests ✅
15 passing tests in `packages/zig/src/bridge_test.zig`:
- JSON parsing (size, color, opacity, boolean, title, position, vibrancy, RGBA, notification, badge, clipboard, file dialog)
- Action string matching
- Memory allocation

### TypeScript APIs ✅
| File | New Methods |
|------|-------------|
| `api/window.ts` | `setMinSize()`, `setMaxSize()` |
| `api/dialog.ts` | `openFile()`, `openFolder()`, `saveFile()`, `showAlert()`, `showConfirm()`, `showPrompt()` |
| `api/clipboard.ts` | `writeText()`, `readText()`, `writeHTML()`, `readHTML()`, `clear()`, `hasText()`, `hasHTML()`, `hasImage()` |

---

*Last updated: December 2025*
