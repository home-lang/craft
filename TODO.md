# Native macOS Tahoe UI Implementation TODO

## Goal
Build truly native NSOutlineView (sidebar) and NSTableView (file browser) components that integrate with Craft's existing bridge system.

## Phase 1: Foundation (Data Source Protocols)

### Task 1.1: Implement NSOutlineViewDataSource Protocol in Zig
- [ ] Create dynamic Objective-C class at runtime using `objc_allocateClassPair`
- [ ] Add required methods:
  - [ ] `outlineView:numberOfChildrenOfItem:` - returns row count
  - [ ] `outlineView:child:ofItem:` - returns child at index
  - [ ] `outlineView:isItemExpandable:` - returns if item has children
  - [ ] `outlineView:objectValueForTableColumn:byItem:` - returns display value
- [ ] Store Zig data structure reference in associated object
- [ ] Implement IMP (method implementations) that call back to Zig
- [ ] Test with simple 2-level hierarchy (sections → items)

**Files to create/modify:**
- `packages/zig/src/components/outline_view_datasource.zig` (new)
- Test: Verify outline view displays sidebar sections

**Estimated time:** 4-6 hours

---

### Task 1.2: Implement NSTableViewDataSource Protocol in Zig
- [ ] Create dynamic Objective-C class at runtime
- [ ] Add required methods:
  - [ ] `numberOfRowsInTableView:` - returns file count
  - [ ] `tableView:objectValueForTableColumn:row:` - returns cell value
  - [ ] `tableView:setObjectValue:forTableColumn:row:` - handles edits (optional)
- [ ] Store file array reference in associated object
- [ ] Implement IMP that reads from Zig ArrayList
- [ ] Test with simple file list (10 files, 4 columns)

**Files to create/modify:**
- `packages/zig/src/components/table_view_datasource.zig` (new)
- Test: Verify table view displays files in columns

**Estimated time:** 3-4 hours

---

## Phase 2: Delegate Implementation (User Interactions)

### Task 2.1: Implement NSOutlineViewDelegate Protocol
- [ ] Create delegate class at runtime
- [ ] Add methods:
  - [ ] `outlineView:viewForTableColumn:item:` - returns cell view
  - [ ] `outlineView:shouldSelectItem:` - controls selection
  - [ ] `outlineViewSelectionDidChange:` - handles selection
  - [ ] `outlineView:heightOfRowByItem:` - row height (24px for items, 20px for headers)
- [ ] Implement cell view creation with SF Symbols icons
- [ ] Send selection events back to Zig → JavaScript bridge
- [ ] Test selection, hover states, and callbacks

**Files to create/modify:**
- `packages/zig/src/components/outline_view_delegate.zig` (new)
- Test: Click sidebar item, verify callback fires

**Estimated time:** 4-5 hours

---

### Task 2.2: Implement NSTableViewDelegate Protocol
- [ ] Create delegate class at runtime
- [ ] Add methods:
  - [ ] `tableView:viewForTableColumn:row:` - returns cell view
  - [ ] `tableView:shouldSelectRow:` - controls selection
  - [ ] `tableViewSelectionDidChange:` - handles selection
  - [ ] `tableView:heightOfRow:` - row height (22px)
- [ ] Implement cell views for each column type
- [ ] Handle double-click events
- [ ] Send events to bridge
- [ ] Test selection and double-click

**Files to create/modify:**
- `packages/zig/src/components/table_view_delegate.zig` (new)
- Test: Double-click file, verify callback fires

**Estimated time:** 4-5 hours

---

## Phase 3: Component Wrappers (High-Level API)

### Task 3.1: Create NativeSidebar Component
- [ ] Wrap NSOutlineView + NSScrollView
- [ ] Integrate data source and delegate
- [ ] Add data structures:
  - [ ] `SidebarSection` struct (id, header, items array)
  - [ ] `SidebarItem` struct (id, label, icon, badge, active state)
- [ ] Implement methods:
  - [ ] `init()` - creates outline view with data source/delegate
  - [ ] `addSection()` - adds section, triggers reloadData
  - [ ] `setSelectedItem()` - programmatic selection
  - [ ] `setOnSelectCallback()` - registers callback function
- [ ] Handle memory management (retain/release)
- [ ] Test full lifecycle (create → populate → interact → destroy)

**Files to create/modify:**
- `packages/zig/src/components/native_sidebar.zig` (rewrite)
- Test: Full sidebar with 3 sections, 10 items

**Estimated time:** 6-8 hours

---

### Task 3.2: Create NativeFileBrowser Component
- [ ] Wrap NSTableView + NSScrollView
- [ ] Integrate data source and delegate
- [ ] Add data structure:
  - [ ] `FileItem` struct (id, name, icon, date, size, kind)
- [ ] Implement methods:
  - [ ] `init()` - creates table with 4 columns
  - [ ] `addFile()` - adds file, triggers reloadData
  - [ ] `addFiles()` - bulk add
  - [ ] `setOnSelectCallback()` - registers selection callback
  - [ ] `setOnDoubleClickCallback()` - registers double-click callback
- [ ] Configure column properties (width, sortable, resizable)
- [ ] Test with 100+ files for performance

**Files to create/modify:**
- `packages/zig/src/components/native_file_browser.zig` (rewrite)
- Test: File browser with 100 files, sort columns

**Estimated time:** 6-8 hours

---

### Task 3.3: Create NativeSplitView Component
- [ ] Wrap NSSplitView
- [ ] Add sidebar and content as subviews
- [ ] Configure:
  - [ ] Vertical orientation
  - [ ] Thin divider style
  - [ ] Auto-save divider position
  - [ ] Minimum pane sizes (180px sidebar, 400px content)
- [ ] Implement Auto Layout constraints
- [ ] Make divider resizable with mouse
- [ ] Test layout at different window sizes

**Files to create/modify:**
- `packages/zig/src/components/native_split_view.zig` (rewrite)
- Test: Resize window, drag divider

**Estimated time:** 3-4 hours

---

## Phase 4: Bridge Integration (JavaScript ↔ Zig)

### Task 4.1: Create NativeUIBridge Handler
- [ ] Implement bridge struct matching TrayBridge pattern
- [ ] Add component registries:
  - [ ] `StringHashMap(*NativeSidebar)` for sidebars
  - [ ] `StringHashMap(*NativeFileBrowser)` for browsers
  - [ ] `StringHashMap(*NativeSplitView)` for split views
- [ ] Implement message handlers:
  - [ ] `handleMessage()` - routes actions
  - [ ] `createSidebar()` - parses JSON, creates sidebar
  - [ ] `addSidebarSection()` - parses section data
  - [ ] `createFileBrowser()` - creates browser
  - [ ] `addFile()` - adds file to browser
  - [ ] `createSplitView()` - combines sidebar + browser
  - [ ] `setSelectedItem()` - programmatic selection
- [ ] Handle component lifecycle (create, update, destroy)
- [ ] Test each message type individually

**Files to create/modify:**
- `packages/zig/src/bridge_native_ui.zig` (rewrite)
- Test: Send JSON messages, verify components created

**Estimated time:** 8-10 hours

---

### Task 4.2: Integrate into Main Bridge Handler
- [ ] Add `nativeUI` case to `handleBridgeMessage()` in `macos.zig`
- [ ] Create global NativeUIBridge instance
- [ ] Pass window reference to bridge on initialization
- [ ] Route messages: `if msg_type == "nativeUI" → nativeUIBridge.handleMessage()`
- [ ] Add views to window's content view (not WKWebView)
- [ ] Handle coordinate system (AppKit uses bottom-left origin)
- [ ] Test message routing from JavaScript → Zig

**Files to modify:**
- `packages/zig/src/macos.zig` (add `nativeUI` routing)
- Line ~1113: Add `else if (std.mem.eql(u8, msg_type, "nativeUI"))`

**Estimated time:** 4-6 hours

---

## Phase 5: JavaScript API (User-Facing Interface)

### Task 5.1: Create JavaScript Bridge API
- [ ] Create `craft-native-ui.js` with clean API
- [ ] Implement classes:
  - [ ] `Sidebar` class with methods:
    - [ ] `addSection(config)`
    - [ ] `setSelectedItem(itemId)`
    - [ ] `onSelect(callback)`
  - [ ] `FileBrowser` class with methods:
    - [ ] `addFile(config)`
    - [ ] `addFiles(array)`
    - [ ] `onSelect(callback)`
    - [ ] `onDoubleClick(callback)`
  - [ ] `SplitView` class
- [ ] Implement `window.craft.nativeUI` namespace:
  - [ ] `createSidebar(options) → Promise<Sidebar>`
  - [ ] `createFileBrowser(options) → Promise<FileBrowser>`
  - [ ] `createSplitView(options) → Promise<SplitView>`
- [ ] Use `window.webkit.messageHandlers.craft.postMessage()` for communication
- [ ] Handle async responses (Promise resolution)
- [ ] Add TypeScript type definitions

**Files to create:**
- `packages/zig/src/js/craft-native-ui.js`
- `packages/typescript/src/types/native-ui.d.ts`

**Estimated time:** 4-6 hours

---

### Task 5.2: Inject Bridge Script into HTML
- [ ] Add `craft-native-ui.js` to bridge script injection
- [ ] Modify `getCraftBridgeScript()` in `macos.zig`
- [ ] Include native UI script alongside tray/window/app scripts
- [ ] Ensure `window.craft.nativeUI` is available before `DOMContentLoaded`
- [ ] Fire `craft:nativeui:ready` event
- [ ] Test that API is accessible from user HTML

**Files to modify:**
- `packages/zig/src/macos.zig` (update `getCraftBridgeScript()`)

**Estimated time:** 2-3 hours

---

## Phase 6: Memory Management & Cleanup

### Task 6.1: Implement Proper Memory Management
- [ ] Use associated objects for Zig → Objective-C connections
- [ ] Implement `dealloc` methods for dynamic classes
- [ ] Track all allocations in bridge
- [ ] Implement `deinit()` for all components
- [ ] Add reference counting where needed
- [ ] Test for memory leaks with Instruments
- [ ] Document ownership model

**Files to modify:**
- All component files (add proper `deinit`)
- `bridge_native_ui.zig` (track allocations)

**Estimated time:** 6-8 hours

---

### Task 6.2: Handle Edge Cases
- [ ] Handle window close (cleanup all components)
- [ ] Handle rapid updates (debounce reloadData)
- [ ] Handle large datasets (1000+ files)
- [ ] Handle empty states (no sections, no files)
- [ ] Handle malformed JSON gracefully
- [ ] Handle missing window reference
- [ ] Add error boundaries
- [ ] Test all error paths

**Estimated time:** 6-8 hours

---

## Phase 7: SF Symbols Integration

### Task 7.1: Implement SF Symbols Icon Loading
- [ ] Create `createSFSymbol()` function
- [ ] Use `NSImage.imageWithSystemSymbolName:accessibilityDescription:`
- [ ] Configure point size (16pt for sidebar, 20pt for files)
- [ ] Configure weight (Regular, Medium, Bold)
- [ ] Handle missing symbols (fallback to generic icon)
- [ ] Cache loaded symbols for performance
- [ ] Test with common SF Symbol names

**Files to create:**
- `packages/zig/src/sf_symbols.zig`

**Estimated time:** 4-5 hours

---

### Task 7.2: Integrate Icons into Cell Views
- [ ] Add NSImageView to outline view cells
- [ ] Add NSImageView to table view cells
- [ ] Set image from SF Symbols
- [ ] Configure rendering mode (template for monochrome)
- [ ] Handle icon updates (when item changes)
- [ ] Test icon display in both light/dark mode
- [ ] Ensure proper sizing and alignment

**Estimated time:** 4-5 hours

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
- [ ] Sidebar displays sections and items with icons
- [ ] File browser displays files in sortable columns
- [ ] Selection callbacks fire correctly
- [ ] Double-click callbacks fire correctly
- [ ] Split view divider is resizable
- [ ] No memory leaks under heavy usage
- [ ] Performance with 1000+ files is acceptable
- [ ] JavaScript API is easy to use
- [ ] Documentation is complete

---

## Current Status: Phase 4 - Bridge Integration Complete ✅

**COMPLETED:**
- ✅ Phase 1: NSOutlineViewDataSource and NSTableViewDataSource protocols
- ✅ Phase 2: NSOutlineViewDelegate and NSTableViewDelegate protocols
- ✅ Phase 3: NativeSidebar, NativeFileBrowser, and NativeSplitView components
- ✅ Phase 4: NativeUIBridge integration into macos.zig
- ✅ All Zig 0.15 compatibility issues resolved
- ✅ Build succeeds with no errors

**CURRENT TASK:**
Testing the native UI components and implementing JSON parsing for full functionality

**NEXT STEPS:**
- Phase 5: JavaScript API implementation
- Phase 6: Memory management and cleanup
- Phase 7: SF Symbols integration
- Phase 8: Testing and polish
