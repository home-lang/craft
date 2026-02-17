/**
 * Craft Native UI Components
 * Type-safe bindings for native platform UI components
 * @module @craft/components/native
 */

import { getBridge } from '../bridge/core'

// ============================================================================
// Base Types
// ============================================================================

/**
 * Base component props
 */
export interface ComponentProps {
  /** Unique component ID */
  id?: string
  /** CSS class names */
  className?: string
  /** Inline styles */
  style?: Record<string, any>
  /** Hidden state */
  hidden?: boolean
  /** Disabled state */
  disabled?: boolean
  /** Tooltip text */
  tooltip?: string
}

/**
 * Component instance
 */
export interface ComponentInstance {
  /** Component ID */
  id: string
  /** Component type */
  type: string
  /** Update component properties */
  update(props: Record<string, any>): Promise<void>
  /** Destroy component */
  destroy(): Promise<void>
  /** Show component */
  show(): Promise<void>
  /** Hide component */
  hide(): Promise<void>
  /** Focus component */
  focus(): Promise<void>
  /** Register event handler */
  on(event: string, handler: Function): () => void
}

// ============================================================================
// Split View
// ============================================================================

/**
 * Split view orientation
 */
export type SplitViewOrientation = 'horizontal' | 'vertical'

/**
 * Split view divider style
 */
export type SplitViewDividerStyle = 'thin' | 'thick' | 'paneSplitter'

/**
 * Split view configuration
 */
export interface SplitViewConfig extends ComponentProps {
  /** Split orientation */
  orientation?: SplitViewOrientation
  /** Divider style */
  dividerStyle?: SplitViewDividerStyle
  /** Initial divider position (percentage or pixels) */
  position?: number
  /** Minimum position for each pane */
  minPositions?: [number, number]
  /** Maximum position for each pane */
  maxPositions?: [number, number]
  /** Autosave position with key */
  autosaveName?: string
}

/**
 * Create a native split view
 */
export async function createSplitView(config: SplitViewConfig = {}): Promise<SplitViewInstance> {
  const id = config.id || `splitview_${Date.now()}`
  await callNative('component.createSplitView', { id, config })
  return new SplitViewInstance(id, config)
}

/**
 * Split view instance
 */
export class SplitViewInstance implements ComponentInstance {
  id: string
  type = 'splitView'
  private _config: SplitViewConfig
  private _listeners: Map<string, Set<Function>> = new Map()

  constructor(id: string, config: SplitViewConfig) {
    this.id = id
    this._config = config
    this._setupListeners()
  }

  private _setupListeners(): void {
    if (typeof window !== 'undefined') {
      window.addEventListener(`craft:splitView:${this.id}:resize` as any, (e: CustomEvent) => {
        this._emit('resize', e.detail)
      })
    }
  }

  private _emit(event: string, data?: any): void {
    this._listeners.get(event)?.forEach(fn => fn(data))
  }

  on(event: string, handler: Function): () => void {
    if (!this._listeners.has(event)) {
      this._listeners.set(event, new Set())
    }
    this._listeners.get(event)!.add(handler)
    return () => this._listeners.get(event)?.delete(handler)
  }

  async update(props: Partial<SplitViewConfig>): Promise<void> {
    Object.assign(this._config, props)
    await callNative('component.update', { id: this.id, props })
  }

  async destroy(): Promise<void> {
    await callNative('component.destroy', { id: this.id })
  }

  async show(): Promise<void> {
    await callNative('component.show', { id: this.id })
  }

  async hide(): Promise<void> {
    await callNative('component.hide', { id: this.id })
  }

  async focus(): Promise<void> {
    await callNative('component.focus', { id: this.id })
  }

  /**
   * Set divider position
   */
  async setPosition(position: number, animated?: boolean): Promise<void> {
    this._config.position = position
    await callNative('splitView.setPosition', { id: this.id, position, animated })
  }

  /**
   * Get current divider position
   */
  async getPosition(): Promise<number> {
    return callNative('splitView.getPosition', { id: this.id })
  }

  /**
   * Collapse a pane
   */
  async collapsePane(index: 0 | 1): Promise<void> {
    await callNative('splitView.collapsePane', { id: this.id, index })
  }

  /**
   * Expand a pane
   */
  async expandPane(index: 0 | 1): Promise<void> {
    await callNative('splitView.expandPane', { id: this.id, index })
  }
}

// ============================================================================
// File Browser
// ============================================================================

/**
 * File browser configuration
 */
export interface FileBrowserConfig extends ComponentProps {
  /** Root path to browse */
  rootPath?: string
  /** Show hidden files */
  showHidden?: boolean
  /** Selection mode */
  selectionMode?: 'single' | 'multiple' | 'none'
  /** File filter */
  fileFilter?: Array<{ name: string; extensions: string[] }>
  /** Show path bar */
  showPathBar?: boolean
  /** Show toolbar */
  showToolbar?: boolean
  /** Show sidebar */
  showSidebar?: boolean
  /** Show preview */
  showPreview?: boolean
  /** View mode */
  viewMode?: 'list' | 'icon' | 'column' | 'gallery'
  /** Sort by */
  sortBy?: 'name' | 'date' | 'size' | 'kind'
  /** Sort order */
  sortOrder?: 'ascending' | 'descending'
  /** Allow directory selection */
  allowDirectorySelection?: boolean
  /** Allow file creation */
  allowFileCreation?: boolean
}

/**
 * File browser selection
 */
export interface FileBrowserSelection {
  /** Selected file paths */
  paths: string[]
  /** Selected file info */
  files: Array<{
    path: string
    name: string
    isDirectory: boolean
    size: number
    modified: Date
  }>
}

/**
 * Create a native file browser
 */
export async function createFileBrowser(config: FileBrowserConfig = {}): Promise<FileBrowserInstance> {
  const id = config.id || `filebrowser_${Date.now()}`
  await callNative('component.createFileBrowser', { id, config })
  return new FileBrowserInstance(id, config)
}

/**
 * File browser instance
 */
export class FileBrowserInstance implements ComponentInstance {
  id: string
  type = 'fileBrowser'
  private _config: FileBrowserConfig
  private _listeners: Map<string, Set<Function>> = new Map()

  constructor(id: string, config: FileBrowserConfig) {
    this.id = id
    this._config = config
    this._setupListeners()
  }

  private _setupListeners(): void {
    if (typeof window !== 'undefined') {
      const events = ['select', 'open', 'navigate', 'context-menu']
      events.forEach(event => {
        window.addEventListener(`craft:fileBrowser:${this.id}:${event}` as any, (e: CustomEvent) => {
          this._emit(event, e.detail)
        })
      })
    }
  }

  private _emit(event: string, data?: any): void {
    this._listeners.get(event)?.forEach(fn => fn(data))
  }

  on(event: string, handler: Function): () => void {
    if (!this._listeners.has(event)) {
      this._listeners.set(event, new Set())
    }
    this._listeners.get(event)!.add(handler)
    return () => this._listeners.get(event)?.delete(handler)
  }

  async update(props: Partial<FileBrowserConfig>): Promise<void> {
    Object.assign(this._config, props)
    await callNative('component.update', { id: this.id, props })
  }

  async destroy(): Promise<void> {
    await callNative('component.destroy', { id: this.id })
  }

  async show(): Promise<void> {
    await callNative('component.show', { id: this.id })
  }

  async hide(): Promise<void> {
    await callNative('component.hide', { id: this.id })
  }

  async focus(): Promise<void> {
    await callNative('component.focus', { id: this.id })
  }

  /**
   * Get current selection
   */
  async getSelection(): Promise<FileBrowserSelection> {
    return callNative('fileBrowser.getSelection', { id: this.id })
  }

  /**
   * Set selection
   */
  async setSelection(paths: string[]): Promise<void> {
    await callNative('fileBrowser.setSelection', { id: this.id, paths })
  }

  /**
   * Navigate to path
   */
  async navigateTo(path: string): Promise<void> {
    await callNative('fileBrowser.navigateTo', { id: this.id, path })
  }

  /**
   * Go back in history
   */
  async goBack(): Promise<void> {
    await callNative('fileBrowser.goBack', { id: this.id })
  }

  /**
   * Go forward in history
   */
  async goForward(): Promise<void> {
    await callNative('fileBrowser.goForward', { id: this.id })
  }

  /**
   * Go to parent directory
   */
  async goUp(): Promise<void> {
    await callNative('fileBrowser.goUp', { id: this.id })
  }

  /**
   * Refresh content
   */
  async refresh(): Promise<void> {
    await callNative('fileBrowser.refresh', { id: this.id })
  }

  /**
   * Create new folder
   */
  async createFolder(name: string): Promise<string> {
    return callNative('fileBrowser.createFolder', { id: this.id, name })
  }

  /**
   * Delete selected files
   */
  async deleteSelection(moveToTrash?: boolean): Promise<void> {
    await callNative('fileBrowser.deleteSelection', { id: this.id, moveToTrash })
  }

  /**
   * Get current path
   */
  async getCurrentPath(): Promise<string> {
    return callNative('fileBrowser.getCurrentPath', { id: this.id })
  }
}

// ============================================================================
// Outline View (Tree View)
// ============================================================================

/**
 * Outline item
 */
export interface OutlineItem {
  /** Item ID */
  id: string
  /** Display label */
  label: string
  /** Icon */
  icon?: string
  /** Children */
  children?: OutlineItem[]
  /** Expanded state */
  expanded?: boolean
  /** Selectable */
  selectable?: boolean
  /** Editable */
  editable?: boolean
  /** Draggable */
  draggable?: boolean
  /** Custom data */
  data?: Record<string, any>
}

/**
 * Outline view configuration
 */
export interface OutlineViewConfig extends ComponentProps {
  /** Items */
  items?: OutlineItem[]
  /** Allow multiple selection */
  multiSelect?: boolean
  /** Allow reordering */
  allowReorder?: boolean
  /** Show expand buttons */
  showExpandButtons?: boolean
  /** Row height */
  rowHeight?: number
  /** Indent per level */
  indentation?: number
}

/**
 * Create a native outline view (tree view)
 */
export async function createOutlineView(config: OutlineViewConfig = {}): Promise<OutlineViewInstance> {
  const id = config.id || `outlineview_${Date.now()}`
  await callNative('component.createOutlineView', { id, config })
  return new OutlineViewInstance(id, config)
}

/**
 * Outline view instance
 */
export class OutlineViewInstance implements ComponentInstance {
  id: string
  type = 'outlineView'
  private _config: OutlineViewConfig
  private _listeners: Map<string, Set<Function>> = new Map()

  constructor(id: string, config: OutlineViewConfig) {
    this.id = id
    this._config = config
    this._setupListeners()
  }

  private _setupListeners(): void {
    if (typeof window !== 'undefined') {
      const events = ['select', 'double-click', 'expand', 'collapse', 'reorder', 'edit']
      events.forEach(event => {
        window.addEventListener(`craft:outlineView:${this.id}:${event}` as any, (e: CustomEvent) => {
          this._emit(event, e.detail)
        })
      })
    }
  }

  private _emit(event: string, data?: any): void {
    this._listeners.get(event)?.forEach(fn => fn(data))
  }

  on(event: string, handler: Function): () => void {
    if (!this._listeners.has(event)) {
      this._listeners.set(event, new Set())
    }
    this._listeners.get(event)!.add(handler)
    return () => this._listeners.get(event)?.delete(handler)
  }

  async update(props: Partial<OutlineViewConfig>): Promise<void> {
    Object.assign(this._config, props)
    await callNative('component.update', { id: this.id, props })
  }

  async destroy(): Promise<void> {
    await callNative('component.destroy', { id: this.id })
  }

  async show(): Promise<void> {
    await callNative('component.show', { id: this.id })
  }

  async hide(): Promise<void> {
    await callNative('component.hide', { id: this.id })
  }

  async focus(): Promise<void> {
    await callNative('component.focus', { id: this.id })
  }

  /**
   * Set items
   */
  async setItems(items: OutlineItem[]): Promise<void> {
    this._config.items = items
    await callNative('outlineView.setItems', { id: this.id, items })
  }

  /**
   * Add item
   */
  async addItem(item: OutlineItem, parentId?: string, index?: number): Promise<void> {
    await callNative('outlineView.addItem', { id: this.id, item, parentId, index })
  }

  /**
   * Update item
   */
  async updateItem(itemId: string, updates: Partial<OutlineItem>): Promise<void> {
    await callNative('outlineView.updateItem', { id: this.id, itemId, updates })
  }

  /**
   * Remove item
   */
  async removeItem(itemId: string): Promise<void> {
    await callNative('outlineView.removeItem', { id: this.id, itemId })
  }

  /**
   * Expand item
   */
  async expandItem(itemId: string): Promise<void> {
    await callNative('outlineView.expandItem', { id: this.id, itemId })
  }

  /**
   * Collapse item
   */
  async collapseItem(itemId: string): Promise<void> {
    await callNative('outlineView.collapseItem', { id: this.id, itemId })
  }

  /**
   * Select item
   */
  async selectItem(itemId: string): Promise<void> {
    await callNative('outlineView.selectItem', { id: this.id, itemId })
  }

  /**
   * Get selection
   */
  async getSelection(): Promise<string[]> {
    return callNative('outlineView.getSelection', { id: this.id })
  }

  /**
   * Scroll to item
   */
  async scrollToItem(itemId: string): Promise<void> {
    await callNative('outlineView.scrollToItem', { id: this.id, itemId })
  }
}

// ============================================================================
// Table View
// ============================================================================

/**
 * Table column configuration
 */
export interface TableColumn {
  /** Column ID */
  id: string
  /** Column header title */
  title: string
  /** Column width */
  width?: number
  /** Minimum width */
  minWidth?: number
  /** Maximum width */
  maxWidth?: number
  /** Resizable */
  resizable?: boolean
  /** Sortable */
  sortable?: boolean
  /** Sort direction */
  sortDirection?: 'ascending' | 'descending' | null
  /** Hidden */
  hidden?: boolean
  /** Alignment */
  alignment?: 'left' | 'center' | 'right'
  /** Editable */
  editable?: boolean
}

/**
 * Table row
 */
export interface TableRow {
  /** Row ID */
  id: string
  /** Column values (column ID -> value) */
  values: Record<string, any>
  /** Row selected */
  selected?: boolean
  /** Row disabled */
  disabled?: boolean
  /** Custom data */
  data?: Record<string, any>
}

/**
 * Table view configuration
 */
export interface TableViewConfig extends ComponentProps {
  /** Columns */
  columns?: TableColumn[]
  /** Rows */
  rows?: TableRow[]
  /** Allow column reordering */
  allowColumnReorder?: boolean
  /** Allow row selection */
  allowSelection?: boolean
  /** Allow multiple selection */
  multiSelect?: boolean
  /** Alternating row colors */
  alternatingRows?: boolean
  /** Show column headers */
  showHeaders?: boolean
  /** Row height */
  rowHeight?: number
  /** Grid lines */
  gridLines?: 'none' | 'horizontal' | 'vertical' | 'both'
}

/**
 * Create a native table view
 */
export async function createTableView(config: TableViewConfig = {}): Promise<TableViewInstance> {
  const id = config.id || `tableview_${Date.now()}`
  await callNative('component.createTableView', { id, config })
  return new TableViewInstance(id, config)
}

/**
 * Table view instance
 */
export class TableViewInstance implements ComponentInstance {
  id: string
  type = 'tableView'
  private _config: TableViewConfig
  private _listeners: Map<string, Set<Function>> = new Map()

  constructor(id: string, config: TableViewConfig) {
    this.id = id
    this._config = config
    this._setupListeners()
  }

  private _setupListeners(): void {
    if (typeof window !== 'undefined') {
      const events = ['select', 'double-click', 'sort', 'edit', 'column-resize', 'column-reorder']
      events.forEach(event => {
        window.addEventListener(`craft:tableView:${this.id}:${event}` as any, (e: CustomEvent) => {
          this._emit(event, e.detail)
        })
      })
    }
  }

  private _emit(event: string, data?: any): void {
    this._listeners.get(event)?.forEach(fn => fn(data))
  }

  on(event: string, handler: Function): () => void {
    if (!this._listeners.has(event)) {
      this._listeners.set(event, new Set())
    }
    this._listeners.get(event)!.add(handler)
    return () => this._listeners.get(event)?.delete(handler)
  }

  async update(props: Partial<TableViewConfig>): Promise<void> {
    Object.assign(this._config, props)
    await callNative('component.update', { id: this.id, props })
  }

  async destroy(): Promise<void> {
    await callNative('component.destroy', { id: this.id })
  }

  async show(): Promise<void> {
    await callNative('component.show', { id: this.id })
  }

  async hide(): Promise<void> {
    await callNative('component.hide', { id: this.id })
  }

  async focus(): Promise<void> {
    await callNative('component.focus', { id: this.id })
  }

  /**
   * Set columns
   */
  async setColumns(columns: TableColumn[]): Promise<void> {
    this._config.columns = columns
    await callNative('tableView.setColumns', { id: this.id, columns })
  }

  /**
   * Set rows
   */
  async setRows(rows: TableRow[]): Promise<void> {
    this._config.rows = rows
    await callNative('tableView.setRows', { id: this.id, rows })
  }

  /**
   * Add row
   */
  async addRow(row: TableRow, index?: number): Promise<void> {
    await callNative('tableView.addRow', { id: this.id, row, index })
  }

  /**
   * Update row
   */
  async updateRow(rowId: string, values: Record<string, any>): Promise<void> {
    await callNative('tableView.updateRow', { id: this.id, rowId, values })
  }

  /**
   * Remove row
   */
  async removeRow(rowId: string): Promise<void> {
    await callNative('tableView.removeRow', { id: this.id, rowId })
  }

  /**
   * Get selection
   */
  async getSelection(): Promise<string[]> {
    return callNative('tableView.getSelection', { id: this.id })
  }

  /**
   * Select rows
   */
  async selectRows(rowIds: string[]): Promise<void> {
    await callNative('tableView.selectRows', { id: this.id, rowIds })
  }

  /**
   * Sort by column
   */
  async sortBy(columnId: string, direction: 'ascending' | 'descending'): Promise<void> {
    await callNative('tableView.sortBy', { id: this.id, columnId, direction })
  }

  /**
   * Scroll to row
   */
  async scrollToRow(rowId: string): Promise<void> {
    await callNative('tableView.scrollToRow', { id: this.id, rowId })
  }
}

// ============================================================================
// Quick Look Preview
// ============================================================================

/**
 * Quick Look configuration
 */
export interface QuickLookConfig {
  /** File path to preview */
  path: string
  /** Panel position */
  position?: { x: number; y: number }
  /** Panel size */
  size?: { width: number; height: number }
}

/**
 * Show Quick Look preview for a file
 */
export async function showQuickLook(config: QuickLookConfig): Promise<void> {
  await callNative('quickLook.show', config)
}

/**
 * Hide Quick Look preview
 */
export async function hideQuickLook(): Promise<void> {
  await callNative('quickLook.hide', {})
}

/**
 * Check if Quick Look is available for a file
 */
export async function canQuickLook(path: string): Promise<boolean> {
  return callNative('quickLook.canPreview', { path })
}

// ============================================================================
// Color Picker
// ============================================================================

/**
 * Color picker configuration
 */
export interface ColorPickerConfig {
  /** Initial color (hex, rgb, or named) */
  color?: string
  /** Show alpha slider */
  showAlpha?: boolean
  /** Mode */
  mode?: 'wheel' | 'sliders' | 'palette' | 'list'
  /** Title */
  title?: string
}

/**
 * Show native color picker
 */
export async function showColorPicker(config: ColorPickerConfig = {}): Promise<string | null> {
  return callNative('colorPicker.show', config)
}

// ============================================================================
// Font Picker
// ============================================================================

/**
 * Font picker configuration
 */
export interface FontPickerConfig {
  /** Initial font */
  font?: { family: string; size: number; weight?: string; style?: string }
  /** Title */
  title?: string
  /** Show size picker */
  showSize?: boolean
  /** Show weight picker */
  showWeight?: boolean
  /** Show style picker */
  showStyle?: boolean
}

/**
 * Font result
 */
export interface FontResult {
  family: string
  size: number
  weight?: string
  style?: string
}

/**
 * Show native font picker
 */
export async function showFontPicker(config: FontPickerConfig = {}): Promise<FontResult | null> {
  return callNative('fontPicker.show', config)
}

// ============================================================================
// Date Picker
// ============================================================================

/**
 * Date picker configuration
 */
export interface DatePickerConfig {
  /** Initial date */
  date?: Date | string
  /** Minimum date */
  minDate?: Date | string
  /** Maximum date */
  maxDate?: Date | string
  /** Date format */
  format?: string
  /** Show time picker */
  showTime?: boolean
  /** Calendar style */
  style?: 'default' | 'graphical'
}

/**
 * Show native date picker
 */
export async function showDatePicker(config: DatePickerConfig = {}): Promise<Date | null> {
  const result = await callNative<string | null>('datePicker.show', config)
  return result ? new Date(result) : null
}

// ============================================================================
// Progress Indicator
// ============================================================================

/**
 * Progress indicator configuration
 */
export interface ProgressConfig extends ComponentProps {
  /** Progress value (0-1 for determinate, undefined for indeterminate) */
  value?: number
  /** Minimum value */
  min?: number
  /** Maximum value */
  max?: number
  /** Show as percentage text */
  showText?: boolean
  /** Inline styles */
  style?: Record<string, any>
  /** Size */
  size?: 'small' | 'regular' | 'large'
  /** Progress style variant */
  progressStyle?: 'bar' | 'spinning' | 'circular'
}

/**
 * Create a progress indicator
 */
export async function createProgress(config: ProgressConfig = {}): Promise<ProgressInstance> {
  const id = config.id || `progress_${Date.now()}`
  await callNative('component.createProgress', { id, config })
  return new ProgressInstance(id, config)
}

/**
 * Progress instance
 */
export class ProgressInstance implements ComponentInstance {
  id: string
  type = 'progress'
  private _config: ProgressConfig
  private _listeners: Map<string, Set<Function>> = new Map()

  constructor(id: string, config: ProgressConfig) {
    this.id = id
    this._config = config
  }

  on(event: string, handler: Function): () => void {
    if (!this._listeners.has(event)) {
      this._listeners.set(event, new Set())
    }
    this._listeners.get(event)!.add(handler)
    return () => this._listeners.get(event)?.delete(handler)
  }

  async update(props: Partial<ProgressConfig>): Promise<void> {
    Object.assign(this._config, props)
    await callNative('component.update', { id: this.id, props })
  }

  async destroy(): Promise<void> {
    await callNative('component.destroy', { id: this.id })
  }

  async show(): Promise<void> {
    await callNative('component.show', { id: this.id })
  }

  async hide(): Promise<void> {
    await callNative('component.hide', { id: this.id })
  }

  async focus(): Promise<void> {
    await callNative('component.focus', { id: this.id })
  }

  /**
   * Set progress value
   */
  async setValue(value: number): Promise<void> {
    this._config.value = value
    await callNative('progress.setValue', { id: this.id, value })
  }

  /**
   * Start indeterminate animation
   */
  async startAnimation(): Promise<void> {
    await callNative('progress.startAnimation', { id: this.id })
  }

  /**
   * Stop animation
   */
  async stopAnimation(): Promise<void> {
    await callNative('progress.stopAnimation', { id: this.id })
  }
}

// ============================================================================
// Toolbar
// ============================================================================

/**
 * Toolbar item
 */
export interface ToolbarItem {
  /** Item ID */
  id: string
  /** Item type */
  type?: 'button' | 'toggle' | 'segment' | 'search' | 'space' | 'flexibleSpace' | 'separator' | 'group'
  /** Label */
  label?: string
  /** Icon (SF Symbol or path) */
  icon?: string
  /** Tooltip */
  tooltip?: string
  /** Enabled */
  enabled?: boolean
  /** Selected (for toggle) */
  selected?: boolean
  /** Min width (for search) */
  minWidth?: number
  /** Max width (for search) */
  maxWidth?: number
  /** Segments (for segment control) */
  segments?: Array<{ id: string; label?: string; icon?: string }>
  /** Items (for group) */
  items?: ToolbarItem[]
}

/**
 * Toolbar configuration
 */
export interface ToolbarConfig {
  /** Toolbar items */
  items?: ToolbarItem[]
  /** Default item identifiers */
  defaultItems?: string[]
  /** Allow customization */
  allowsCustomization?: boolean
  /** Display mode */
  displayMode?: 'default' | 'iconOnly' | 'labelOnly' | 'iconAndLabel'
  /** Size mode */
  sizeMode?: 'default' | 'small' | 'regular'
  /** Show separator below toolbar */
  showBottomBorder?: boolean
}

/**
 * Set window toolbar
 */
export async function setToolbar(config: ToolbarConfig): Promise<void> {
  await callNative('toolbar.set', config)
}

/**
 * Update toolbar item
 */
export async function updateToolbarItem(itemId: string, updates: Partial<ToolbarItem>): Promise<void> {
  await callNative('toolbar.updateItem', { itemId, updates })
}

/**
 * Show/hide toolbar
 */
export async function setToolbarVisible(visible: boolean): Promise<void> {
  await callNative('toolbar.setVisible', { visible })
}

// ============================================================================
// Touch Bar (macOS)
// ============================================================================

/**
 * Touch Bar item
 */
export interface TouchBarItem {
  /** Item ID */
  id: string
  /** Item type */
  type: 'button' | 'label' | 'slider' | 'colorPicker' | 'popover' | 'group' | 'segmentedControl' | 'scrubber' | 'spacer'
  /** Label text */
  label?: string
  /** Icon */
  icon?: string
  /** Background color */
  backgroundColor?: string
  /** Text color */
  textColor?: string
  /** Enabled */
  enabled?: boolean
  /** Width */
  width?: number
  /** Items (for group/popover) */
  items?: TouchBarItem[]
  /** Segments (for segmented control) */
  segments?: Array<{ id: string; label?: string; icon?: string }>
  /** Min value (for slider) */
  min?: number
  /** Max value (for slider) */
  max?: number
  /** Value (for slider) */
  value?: number
  /** Spacer size */
  size?: 'small' | 'large' | 'flexible'
}

/**
 * Touch Bar configuration
 */
export interface TouchBarConfig {
  /** Touch Bar items */
  items?: TouchBarItem[]
  /** Escape item */
  escapeItem?: TouchBarItem
}

/**
 * Set Touch Bar
 */
export async function setTouchBar(config: TouchBarConfig): Promise<void> {
  await callNative('touchBar.set', config)
}

/**
 * Update Touch Bar item
 */
export async function updateTouchBarItem(itemId: string, updates: Partial<TouchBarItem>): Promise<void> {
  await callNative('touchBar.updateItem', { itemId, updates })
}

// ============================================================================
// Helper Functions
// ============================================================================

async function callNative<T = void>(method: string, params: Record<string, any>): Promise<T> {
  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    return new Promise((resolve, reject) => {
      try {
        (window as any).webkit.messageHandlers.craft.postMessage({
          type: 'native-ui',
          method,
          params
        })
        resolve(undefined as T)
      } catch (error) {
        reject(error)
      }
    })
  }

  const bridge = getBridge()
  return bridge.request(method, params)
}

// ============================================================================
// Exports
// ============================================================================

const nativeComponents: {
  createSplitView: typeof createSplitView
  SplitViewInstance: typeof SplitViewInstance
  createFileBrowser: typeof createFileBrowser
  FileBrowserInstance: typeof FileBrowserInstance
  createOutlineView: typeof createOutlineView
  OutlineViewInstance: typeof OutlineViewInstance
  createTableView: typeof createTableView
  TableViewInstance: typeof TableViewInstance
  showQuickLook: typeof showQuickLook
  hideQuickLook: typeof hideQuickLook
  canQuickLook: typeof canQuickLook
  showColorPicker: typeof showColorPicker
  showFontPicker: typeof showFontPicker
  showDatePicker: typeof showDatePicker
  createProgress: typeof createProgress
  ProgressInstance: typeof ProgressInstance
  setToolbar: typeof setToolbar
  updateToolbarItem: typeof updateToolbarItem
  setToolbarVisible: typeof setToolbarVisible
  setTouchBar: typeof setTouchBar
  updateTouchBarItem: typeof updateTouchBarItem
} = {
  createSplitView: createSplitView,
  SplitViewInstance: SplitViewInstance,
  createFileBrowser: createFileBrowser,
  FileBrowserInstance: FileBrowserInstance,
  createOutlineView: createOutlineView,
  OutlineViewInstance: OutlineViewInstance,
  createTableView: createTableView,
  TableViewInstance: TableViewInstance,
  showQuickLook: showQuickLook,
  hideQuickLook: hideQuickLook,
  canQuickLook: canQuickLook,
  showColorPicker: showColorPicker,
  showFontPicker: showFontPicker,
  showDatePicker: showDatePicker,
  createProgress: createProgress,
  ProgressInstance: ProgressInstance,
  setToolbar: setToolbar,
  updateToolbarItem: updateToolbarItem,
  setToolbarVisible: setToolbarVisible,
  setTouchBar: setTouchBar,
  updateTouchBarItem: updateTouchBarItem
}

export default nativeComponents
