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

### Task 8.1: Create Comprehensive Example
- [ ] Build full Finder-like app
- [ ] Demonstrate all features:
  - [ ] Multiple sidebar sections
  - [ ] 100+ files in browser
  - [ ] Selection callbacks
  - [ ] Double-click callbacks
  - [ ] Icon display
  - [ ] Resizable split view
- [ ] Add keyboard shortcuts (arrow keys for navigation)
- [ ] Add context menus (right-click)
- [ ] Match Finder behavior exactly

**Files to create:**
- `examples/native-finder-complete.ts`

**Estimated time:** 8-10 hours

---

### Task 8.2: Performance Testing
- [ ] Test with 1,000 files
- [ ] Test with 10,000 files
- [ ] Measure memory usage
- [ ] Measure CPU usage during scroll
- [ ] Optimize reloadData calls (batch updates)
- [ ] Add virtualization if needed
- [ ] Profile with Instruments
- [ ] Document performance characteristics

**Estimated time:** 6-8 hours

---

### Task 8.3: Documentation
- [ ] Write API documentation
- [ ] Create usage examples (10+ examples)
- [ ] Document component lifecycle
- [ ] Document memory management
- [ ] Create architecture diagrams
- [ ] Write troubleshooting guide
- [ ] Add inline code comments
- [ ] Create video tutorial

**Files to create:**
- `packages/ui-components/NATIVE-UI-GUIDE.md`
- `packages/ui-components/API-REFERENCE.md`
- `packages/ui-components/EXAMPLES.md`

**Estimated time:** 8-10 hours

---

## Phase 9: Advanced Features

### Task 9.1: Add Drag and Drop Support
- [ ] Implement `NSDraggingSource` protocol
- [ ] Implement `NSDraggingDestination` protocol
- [ ] Handle file drops from Finder
- [ ] Handle drag reordering in sidebar
- [ ] Send drag events to JavaScript
- [ ] Test drag between views

**Estimated time:** 10-12 hours

---

### Task 9.2: Add Context Menus
- [ ] Create NSMenu dynamically
- [ ] Handle right-click on sidebar items
- [ ] Handle right-click on files
- [ ] Send menu action to JavaScript
- [ ] Support custom menu items
- [ ] Test menu display and actions

**Estimated time:** 6-8 hours

---

### Task 9.3: Add Quick Look Support
- [ ] Integrate QLPreviewPanel
- [ ] Show preview on spacebar press
- [ ] Support all file types
- [ ] Test with various file formats

**Estimated time:** 8-10 hours

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
- [ ] Performance with 1000+ files is acceptable
- [x] JavaScript API is easy to use
- [ ] Documentation is complete

---

## Current Status: Phase 7 Complete - SF Symbols Integration ✅

**COMPLETED:**
- ✅ Phase 1: NSOutlineViewDataSource and NSTableViewDataSource protocols
- ✅ Phase 2: NSOutlineViewDelegate and NSTableViewDelegate protocols
- ✅ Phase 3: NativeSidebar, NativeFileBrowser, and NativeSplitView components
- ✅ Phase 4: NativeUIBridge integration into macos.zig with full JSON parsing
- ✅ Phase 5: JavaScript API (`window.craft.nativeUI`) with class-based interface
- ✅ Phase 6: Memory management with proper deinit, ObjC release, and edge case handling
- ✅ Phase 7: SF Symbols integration with icons in sidebar and file browser cells
- ✅ All Zig 0.16 compatibility issues resolved
- ✅ Build succeeds with no errors
- ✅ Bridge script injection system working
- ✅ Test applications running successfully
- ✅ Comprehensive demo application created

**IMPLEMENTATION DETAILS (Phase 6-7):**
- Added proper ObjC instance release in all component deinit() methods
- Added `is_destroyed` flag and `handleWindowClose()` to bridge
- Added debounce support for rapid reloadData calls
- Added malformed JSON and empty data edge case handling
- Rewrote sf_symbols.zig to use macos.zig wrappers
- Integrated SF Symbols into outline_view_delegate.zig cell views
- Integrated SF Symbols into table_view_delegate.zig name column cells

**TESTING STATUS:**
- Native Finder Demo application running with complete UI examples
- JavaScript API successfully injected into HTML via bridge
- SF Symbols icons display in sidebar items and file browser name column
- Memory management with proper cleanup on component destruction

**NEXT STEPS:**
- Phase 8: Testing and polish (comprehensive example, performance testing, documentation)
- Phase 9: Advanced features (drag/drop, context menus, Quick Look)
