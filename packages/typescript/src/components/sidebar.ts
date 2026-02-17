/**
 * Craft Sidebar Components
 * Native sidebar implementations with different styles:
 * - Tahoe (macOS Sonoma/Sequoia Finder style)
 * - Arc (Browser-style collapsible vertical tabs)
 * - OrbStack (Dark minimal sidebar)
 * @module @craft/components/sidebar
 */

import { getBridge } from '../bridge/core'

// ============================================================================
// Types
// ============================================================================

/**
 * Sidebar item
 */
export interface SidebarItem {
  /** Unique identifier */
  id: string
  /** Display label */
  label: string
  /** Icon (SF Symbol name, path, or emoji) */
  icon?: string
  /** Badge text/number */
  badge?: string | number
  /** Badge color */
  badgeColor?: string
  /** Whether item is selected */
  selected?: boolean
  /** Whether item is disabled */
  disabled?: boolean
  /** Whether item is expandable/collapsible */
  expandable?: boolean
  /** Whether item is expanded (if expandable) */
  expanded?: boolean
  /** Child items */
  children?: SidebarItem[]
  /** Custom data */
  data?: Record<string, any>
  /** Tooltip */
  tooltip?: string
  /** Context menu items */
  contextMenu?: ContextMenuItem[]
  /** Whether item is draggable */
  draggable?: boolean
  /** Drop target types accepted */
  dropTypes?: string[]
}

/**
 * Sidebar section (group of items)
 */
export interface SidebarSection {
  /** Section ID */
  id: string
  /** Section title (can be empty for untitled section) */
  title?: string
  /** Items in this section */
  items: SidebarItem[]
  /** Whether section is collapsible */
  collapsible?: boolean
  /** Whether section is collapsed */
  collapsed?: boolean
}

/**
 * Context menu item
 */
export interface ContextMenuItem {
  /** Item ID */
  id?: string
  /** Label */
  label?: string
  /** Item type */
  type?: 'normal' | 'separator' | 'checkbox'
  /** Icon */
  icon?: string
  /** Keyboard shortcut */
  shortcut?: string
  /** Checked state */
  checked?: boolean
  /** Disabled state */
  disabled?: boolean
  /** Submenu items */
  submenu?: ContextMenuItem[]
}

/**
 * Sidebar style presets
 */
export type SidebarStyle = 'tahoe' | 'arc' | 'orbstack' | 'custom'

/**
 * Sidebar position
 */
export type SidebarPosition = 'left' | 'right'

/**
 * Sidebar configuration
 */
export interface SidebarConfig {
  /** Sidebar style preset */
  style?: SidebarStyle
  /** Position (left or right) */
  position?: SidebarPosition
  /** Width in pixels */
  width?: number
  /** Minimum width */
  minWidth?: number
  /** Maximum width */
  maxWidth?: number
  /** Whether sidebar is collapsible */
  collapsible?: boolean
  /** Whether sidebar starts collapsed */
  collapsed?: boolean
  /** Collapsed width (for icon-only mode) */
  collapsedWidth?: number
  /** Enable resizing */
  resizable?: boolean
  /** Background color (or vibrancy for macOS) */
  background?: string | 'sidebar' | 'window' | 'selection' | 'menu' | 'popover' | 'under-window'
  /** Show separator line */
  showSeparator?: boolean
  /** Separator color */
  separatorColor?: string
  /** Enable search */
  searchable?: boolean
  /** Search placeholder */
  searchPlaceholder?: string
  /** Enable drag and drop */
  dragAndDrop?: boolean
  /** Sections */
  sections?: SidebarSection[]
  /** Flat items (no sections) */
  items?: SidebarItem[]
  /** Header content */
  header?: SidebarHeaderConfig
  /** Footer content */
  footer?: SidebarFooterConfig
}

/**
 * Sidebar header configuration
 */
export interface SidebarHeaderConfig {
  /** Title */
  title?: string
  /** Subtitle */
  subtitle?: string
  /** Icon/avatar */
  icon?: string
  /** Custom height */
  height?: number
  /** Show collapse button */
  showCollapseButton?: boolean
  /** Custom actions */
  actions?: Array<{ id: string; icon: string; tooltip?: string }>
}

/**
 * Sidebar footer configuration
 */
export interface SidebarFooterConfig {
  /** Items */
  items?: SidebarItem[]
  /** Custom height */
  height?: number
  /** Show settings button */
  showSettings?: boolean
  /** Custom content */
  content?: string
}

/**
 * Sidebar event types
 */
export type SidebarEventType =
  | 'select'
  | 'double-click'
  | 'context-menu'
  | 'expand'
  | 'collapse'
  | 'resize'
  | 'search'
  | 'drag-start'
  | 'drag-end'
  | 'drop'
  | 'reorder'
  | 'header-action'
  | 'footer-action'

/**
 * Sidebar event data map
 */
export interface SidebarEventMap {
  'select': { item: SidebarItem; section?: SidebarSection }
  'double-click': { item: SidebarItem; section?: SidebarSection }
  'context-menu': { item: SidebarItem; section?: SidebarSection; menuItemId: string }
  'expand': { item: SidebarItem }
  'collapse': { item: SidebarItem }
  'resize': { width: number }
  'search': { query: string }
  'drag-start': { item: SidebarItem }
  'drag-end': { item: SidebarItem; cancelled: boolean }
  'drop': { item: SidebarItem; target: SidebarItem | null; position: 'before' | 'after' | 'inside' }
  'reorder': { items: SidebarItem[]; section?: SidebarSection }
  'header-action': { actionId: string }
  'footer-action': { actionId: string }
}

/**
 * Sidebar event handler
 */
export type SidebarEventHandler<T extends SidebarEventType> = (data: SidebarEventMap[T]) => void

// ============================================================================
// Style Presets
// ============================================================================

/**
 * Tahoe style (macOS Sonoma/Sequoia Finder)
 * - Source list appearance
 * - Translucent sidebar background
 * - SF Symbol icons
 * - Native selection highlighting
 */
export const tahoeStyle: Partial<SidebarConfig> = {
  style: 'tahoe',
  width: 220,
  minWidth: 150,
  maxWidth: 350,
  collapsible: true,
  collapsedWidth: 0,
  resizable: true,
  background: 'sidebar',
  showSeparator: false,
  searchable: true,
  searchPlaceholder: 'Search',
  dragAndDrop: true
}

/**
 * Arc style (Browser vertical tabs)
 * - Compact, icon-focused when collapsed
 * - Animated expand/collapse
 * - Pill-shaped selection
 * - Hover preview
 */
export const arcStyle: Partial<SidebarConfig> = {
  style: 'arc',
  width: 260,
  minWidth: 48,
  maxWidth: 320,
  collapsible: true,
  collapsedWidth: 48,
  resizable: true,
  background: 'under-window',
  showSeparator: true,
  searchable: true,
  searchPlaceholder: 'Search tabs...',
  dragAndDrop: true
}

/**
 * OrbStack style (Dark minimal)
 * - Dark background
 * - Minimal chrome
 * - Subtle hover states
 * - Compact spacing
 */
export const orbstackStyle: Partial<SidebarConfig> = {
  style: 'orbstack',
  width: 200,
  minWidth: 160,
  maxWidth: 280,
  collapsible: true,
  collapsedWidth: 0,
  resizable: false,
  background: '#1a1a1a',
  showSeparator: true,
  separatorColor: '#333',
  searchable: false,
  dragAndDrop: false
}

// ============================================================================
// Sidebar Class
// ============================================================================

/**
 * Native sidebar component
 */
export class Sidebar {
  private _id: string
  private _config: SidebarConfig
  private _listeners: Map<string, Set<Function>> = new Map()
  private _items: Map<string, SidebarItem> = new Map()
  private _selectedId: string | null = null
  private _destroyed: boolean = false

  constructor(config: SidebarConfig = {}) {
    this._id = `sidebar_${Date.now()}`
    this._config = this._applyStylePreset(config)
    this._indexItems()
    this._setupEventListeners()
  }

  /**
   * Get sidebar ID
   */
  get id(): string {
    return this._id
  }

  /**
   * Get current configuration
   */
  get config(): SidebarConfig {
    return { ...this._config }
  }

  /**
   * Get currently selected item ID
   */
  get selectedId(): string | null {
    return this._selectedId
  }

  /**
   * Get currently selected item
   */
  get selectedItem(): SidebarItem | null {
    return this._selectedId ? this._items.get(this._selectedId) || null : null
  }

  /**
   * Check if sidebar is collapsed
   */
  get isCollapsed(): boolean {
    return this._config.collapsed || false
  }

  private _applyStylePreset(config: SidebarConfig): SidebarConfig {
    let preset: Partial<SidebarConfig> = {}

    switch (config.style) {
      case 'tahoe':
        preset = tahoeStyle
        break
      case 'arc':
        preset = arcStyle
        break
      case 'orbstack':
        preset = orbstackStyle
        break
    }

    return { ...preset, ...config }
  }

  private _indexItems(): void {
    this._items.clear()

    const index = (items: SidebarItem[] | undefined) => {
      if (!items) return
      items.forEach(item => {
        this._items.set(item.id, item)
        if (item.children) {
          index(item.children)
        }
      })
    }

    index(this._config.items)
    this._config.sections?.forEach(section => {
      index(section.items)
    })
  }

  private _setupEventListeners(): void {
    if (typeof window !== 'undefined') {
      const events: SidebarEventType[] = [
        'select', 'double-click', 'context-menu', 'expand', 'collapse',
        'resize', 'search', 'drag-start', 'drag-end', 'drop', 'reorder',
        'header-action', 'footer-action'
      ]

      events.forEach(event => {
        window.addEventListener(`craft:sidebar:${event}` as any, (e: CustomEvent) => {
          if (e.detail?.sidebarId === this._id) {
            if (event === 'select') {
              this._selectedId = e.detail?.item?.id || null
            }
            this._emit(event, e.detail)
          }
        })
      })
    }
  }

  private _emit(event: string, data?: any): void {
    const listeners = this._listeners.get(event)
    if (listeners) {
      listeners.forEach(fn => fn(data))
    }
  }

  /**
   * Register an event handler
   */
  on<T extends SidebarEventType>(event: T, handler: SidebarEventHandler<T>): () => void {
    if (!this._listeners.has(event)) {
      this._listeners.set(event, new Set())
    }
    this._listeners.get(event)!.add(handler)

    return () => {
      this._listeners.get(event)?.delete(handler)
    }
  }

  /**
   * Register a one-time event handler
   */
  once<T extends SidebarEventType>(event: T, handler: SidebarEventHandler<T>): () => void {
    const wrapper = (data: SidebarEventMap[T]) => {
      this._listeners.get(event)?.delete(wrapper)
      handler(data)
    }
    return this.on(event, wrapper as any)
  }

  /**
   * Remove event handler
   */
  off<T extends SidebarEventType>(event: T, handler: SidebarEventHandler<T>): void {
    this._listeners.get(event)?.delete(handler)
  }

  // ==========================================================================
  // Sidebar Control
  // ==========================================================================

  /**
   * Initialize and render the sidebar
   */
  async create(): Promise<void> {
    await this._call('create', { config: this._config })
  }

  /**
   * Update sidebar configuration
   */
  async update(config: Partial<SidebarConfig>): Promise<void> {
    this._config = { ...this._config, ...config }
    this._indexItems()
    await this._call('update', { config: this._config })
  }

  /**
   * Collapse the sidebar
   */
  async collapse(): Promise<void> {
    this._config.collapsed = true
    await this._call('collapse')
  }

  /**
   * Expand the sidebar
   */
  async expand(): Promise<void> {
    this._config.collapsed = false
    await this._call('expand')
  }

  /**
   * Toggle sidebar collapsed state
   */
  async toggle(): Promise<void> {
    if (this._config.collapsed) {
      await this.expand()
    } else {
      await this.collapse()
    }
  }

  /**
   * Set sidebar width
   */
  async setWidth(width: number): Promise<void> {
    this._config.width = Math.max(
      this._config.minWidth || 0,
      Math.min(width, this._config.maxWidth || Infinity)
    )
    await this._call('setWidth', { width: this._config.width })
  }

  /**
   * Destroy the sidebar
   */
  async destroy(): Promise<void> {
    await this._call('destroy')
    this._destroyed = true
    this._listeners.clear()
  }

  // ==========================================================================
  // Item Management
  // ==========================================================================

  /**
   * Select an item by ID
   */
  async select(itemId: string): Promise<void> {
    this._selectedId = itemId
    await this._call('select', { itemId })
  }

  /**
   * Clear selection
   */
  async clearSelection(): Promise<void> {
    this._selectedId = null
    await this._call('clearSelection')
  }

  /**
   * Get item by ID
   */
  getItem(itemId: string): SidebarItem | undefined {
    return this._items.get(itemId)
  }

  /**
   * Add a new item
   */
  async addItem(item: SidebarItem, options?: { sectionId?: string; parentId?: string; index?: number }): Promise<void> {
    this._items.set(item.id, item)
    await this._call('addItem', { item, ...options })
  }

  /**
   * Update an existing item
   */
  async updateItem(itemId: string, updates: Partial<SidebarItem>): Promise<void> {
    const item = this._items.get(itemId)
    if (item) {
      Object.assign(item, updates)
      await this._call('updateItem', { itemId, updates })
    }
  }

  /**
   * Remove an item
   */
  async removeItem(itemId: string): Promise<void> {
    this._items.delete(itemId)
    if (this._selectedId === itemId) {
      this._selectedId = null
    }
    await this._call('removeItem', { itemId })
  }

  /**
   * Set items (replace all)
   */
  async setItems(items: SidebarItem[]): Promise<void> {
    this._config.items = items
    this._indexItems()
    await this._call('setItems', { items })
  }

  /**
   * Set sections (replace all)
   */
  async setSections(sections: SidebarSection[]): Promise<void> {
    this._config.sections = sections
    this._indexItems()
    await this._call('setSections', { sections })
  }

  /**
   * Expand an item (show children)
   */
  async expandItem(itemId: string): Promise<void> {
    const item = this._items.get(itemId)
    if (item) {
      item.expanded = true
      await this._call('expandItem', { itemId })
    }
  }

  /**
   * Collapse an item (hide children)
   */
  async collapseItem(itemId: string): Promise<void> {
    const item = this._items.get(itemId)
    if (item) {
      item.expanded = false
      await this._call('collapseItem', { itemId })
    }
  }

  /**
   * Scroll to item
   */
  async scrollToItem(itemId: string): Promise<void> {
    await this._call('scrollToItem', { itemId })
  }

  /**
   * Update item badge
   */
  async setBadge(itemId: string, badge: string | number | null): Promise<void> {
    const item = this._items.get(itemId)
    if (item) {
      item.badge = badge ?? undefined
      await this._call('setBadge', { itemId, badge })
    }
  }

  // ==========================================================================
  // Section Management
  // ==========================================================================

  /**
   * Add a new section
   */
  async addSection(section: SidebarSection, index?: number): Promise<void> {
    if (!this._config.sections) {
      this._config.sections = []
    }
    if (index !== undefined) {
      this._config.sections.splice(index, 0, section)
    } else {
      this._config.sections.push(section)
    }
    section.items.forEach(item => this._items.set(item.id, item))
    await this._call('addSection', { section, index })
  }

  /**
   * Update a section
   */
  async updateSection(sectionId: string, updates: Partial<SidebarSection>): Promise<void> {
    const section = this._config.sections?.find(s => s.id === sectionId)
    if (section) {
      Object.assign(section, updates)
      if (updates.items) {
        updates.items.forEach(item => this._items.set(item.id, item))
      }
      await this._call('updateSection', { sectionId, updates })
    }
  }

  /**
   * Remove a section
   */
  async removeSection(sectionId: string): Promise<void> {
    const index = this._config.sections?.findIndex(s => s.id === sectionId)
    if (index !== undefined && index >= 0 && this._config.sections) {
      const section = this._config.sections[index]
      section.items.forEach(item => this._items.delete(item.id))
      this._config.sections.splice(index, 1)
      await this._call('removeSection', { sectionId })
    }
  }

  /**
   * Collapse a section
   */
  async collapseSection(sectionId: string): Promise<void> {
    const section = this._config.sections?.find(s => s.id === sectionId)
    if (section) {
      section.collapsed = true
      await this._call('collapseSection', { sectionId })
    }
  }

  /**
   * Expand a section
   */
  async expandSection(sectionId: string): Promise<void> {
    const section = this._config.sections?.find(s => s.id === sectionId)
    if (section) {
      section.collapsed = false
      await this._call('expandSection', { sectionId })
    }
  }

  // ==========================================================================
  // Search
  // ==========================================================================

  /**
   * Set search query programmatically
   */
  async setSearchQuery(query: string): Promise<void> {
    await this._call('setSearchQuery', { query })
  }

  /**
   * Clear search
   */
  async clearSearch(): Promise<void> {
    await this._call('clearSearch')
  }

  /**
   * Focus search input
   */
  async focusSearch(): Promise<void> {
    await this._call('focusSearch')
  }

  // ==========================================================================
  // Helper Methods
  // ==========================================================================

  private async _call<T = void>(action: string, data?: Record<string, any>): Promise<T> {
    const payload = { sidebarId: this._id, ...data }

    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        try {
          (window as any).webkit.messageHandlers.craft.postMessage({
            type: 'sidebar',
            action,
            data: payload
          })
          resolve(undefined as T)
        } catch (error) {
          reject(error)
        }
      })
    }

    const bridge = getBridge()
    return bridge.request(`sidebar.${action}`, payload)
  }
}

// ============================================================================
// Factory Functions
// ============================================================================

/**
 * Create a Tahoe-style sidebar (macOS Finder)
 */
export function createTahoeSidebar(config: Omit<SidebarConfig, 'style'> = {}): Sidebar {
  return new Sidebar({ ...tahoeStyle, ...config, style: 'tahoe' })
}

/**
 * Create an Arc-style sidebar (Browser tabs)
 */
export function createArcSidebar(config: Omit<SidebarConfig, 'style'> = {}): Sidebar {
  return new Sidebar({ ...arcStyle, ...config, style: 'arc' })
}

/**
 * Create an OrbStack-style sidebar (Dark minimal)
 */
export function createOrbStackSidebar(config: Omit<SidebarConfig, 'style'> = {}): Sidebar {
  return new Sidebar({ ...orbstackStyle, ...config, style: 'orbstack' })
}

/**
 * Create a custom sidebar
 */
export function createSidebar(config: SidebarConfig = {}): Sidebar {
  return new Sidebar(config)
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Create a sidebar item
 */
export function sidebarItem(id: string, label: string, options: Omit<SidebarItem, 'id' | 'label'> = {}): SidebarItem {
  return { id, label, ...options }
}

/**
 * Create a sidebar section
 */
export function sidebarSection(id: string, items: SidebarItem[], options: Omit<SidebarSection, 'id' | 'items'> = {}): SidebarSection {
  return { id, items, ...options }
}

/**
 * Create a separator item (displayed as a divider)
 */
export function sidebarSeparator(id?: string): SidebarItem {
  return { id: id || `separator_${Date.now()}`, label: '', disabled: true }
}

// ============================================================================
// Exports
// ============================================================================

const sidebarModule: {
  Sidebar: typeof Sidebar
  createSidebar: typeof createSidebar
  createTahoeSidebar: typeof createTahoeSidebar
  createArcSidebar: typeof createArcSidebar
  createOrbStackSidebar: typeof createOrbStackSidebar
  sidebarItem: typeof sidebarItem
  sidebarSection: typeof sidebarSection
  sidebarSeparator: typeof sidebarSeparator
  tahoeStyle: typeof tahoeStyle
  arcStyle: typeof arcStyle
  orbstackStyle: typeof orbstackStyle
} = {
  Sidebar: Sidebar,
  createSidebar: createSidebar,
  createTahoeSidebar: createTahoeSidebar,
  createArcSidebar: createArcSidebar,
  createOrbStackSidebar: createOrbStackSidebar,
  sidebarItem: sidebarItem,
  sidebarSection: sidebarSection,
  sidebarSeparator: sidebarSeparator,
  tahoeStyle: tahoeStyle,
  arcStyle: arcStyle,
  orbstackStyle: orbstackStyle
}

export default sidebarModule
