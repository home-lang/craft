/**
 * @fileoverview Cross-Platform Native Sidebar API
 * @description Unified sidebar component that renders with native styling
 * on macOS, Windows, and Linux.
 * @module @craft/api/sidebar
 */

import { isCraft, getPlatform, type Platform } from './process'

// ============================================================================
// Types
// ============================================================================

export interface SidebarItem {
  id: string
  label: string
  icon?: string
  badge?: string | number
  selected?: boolean
  children?: SidebarItem[]
  expanded?: boolean
  enabled?: boolean
  tintColor?: string
  tooltip?: string
}

export interface SidebarSection {
  id: string
  title?: string
  items: SidebarItem[]
  collapsible?: boolean
  collapsed?: boolean
}

export interface SidebarConfig {
  /** Sidebar width in pixels */
  width?: number
  /** Sections with grouped items */
  sections?: SidebarSection[]
  /** Flat list of items (no sections) */
  items?: SidebarItem[]
  /** Show search field */
  showSearch?: boolean
  /** Search placeholder */
  searchPlaceholder?: string
  /** Header title */
  headerTitle?: string
  /** Header subtitle */
  headerSubtitle?: string
  /** Allow resizing */
  resizable?: boolean
  /** Platform-specific style overrides */
  platform?: {
    macos?: MacOSSidebarConfig
    windows?: WindowsSidebarConfig
    linux?: LinuxSidebarConfig
  }
}

export interface MacOSSidebarConfig {
  /** Use vibrancy effect */
  vibrancy?: boolean
  /** Material type for vibrancy */
  material?: 'sidebar' | 'headerView' | 'menu' | 'popover'
  /** Position traffic lights in sidebar (Settings/Tahoe style) */
  trafficLightsInSidebar?: boolean
  /** Hide titlebar separator */
  hideTitlebarSeparator?: boolean
}

export interface WindowsSidebarConfig {
  /** Use Mica/Acrylic material */
  material?: 'mica' | 'acrylic' | 'none'
  /** Use Windows 11 rounded corners */
  rounded?: boolean
}

export interface LinuxSidebarConfig {
  /** GTK theme variant */
  theme?: 'adwaita' | 'breeze' | 'auto'
}

export interface SidebarSelectEvent {
  itemId: string
  sectionId?: string
  item: SidebarItem
}

export interface SidebarSearchEvent {
  query: string
}

// ============================================================================
// Platform Detection & Defaults
// ============================================================================

function getDefaults(platform: Platform): Partial<SidebarConfig> {
  switch (platform) {
    case 'macos':
      return {
        width: 220,
        platform: {
          macos: {
            vibrancy: true,
            material: 'sidebar',
            trafficLightsInSidebar: false,
            hideTitlebarSeparator: false
          }
        }
      }
    case 'windows':
      return {
        width: 200,
        platform: {
          windows: {
            material: 'mica',
            rounded: true
          }
        }
      }
    case 'linux':
      return {
        width: 200,
        platform: {
          linux: {
            theme: 'auto'
          }
        }
      }
    default:
      return { width: 220 }
  }
}

// ============================================================================
// CSS Generation
// ============================================================================

function generateCSS(config: SidebarConfig, platform: Platform): string {
  const width = config.width || 220

  // Base styles that work everywhere
  const baseStyles = `
    .craft-sidebar {
      width: ${width}px;
      height: 100%;
      display: flex;
      flex-direction: column;
      user-select: none;
      font-family: var(--craft-font-family, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif);
      font-size: var(--craft-font-size, 13px);
    }
    .craft-sidebar-header {
      padding: 12px 16px;
      border-bottom: 1px solid var(--craft-border);
    }
    .craft-sidebar-header-title {
      font-weight: 600;
      font-size: 14px;
    }
    .craft-sidebar-header-subtitle {
      font-size: 11px;
      opacity: 0.7;
      margin-top: 2px;
    }
    .craft-sidebar-search {
      padding: 8px 12px;
    }
    .craft-sidebar-search input {
      width: 100%;
      padding: 6px 10px;
      border-radius: var(--craft-radius, 6px);
      border: 1px solid var(--craft-border);
      background: var(--craft-input-bg);
      color: var(--craft-text);
      font-size: 13px;
      outline: none;
    }
    .craft-sidebar-search input:focus {
      border-color: var(--craft-accent);
    }
    .craft-sidebar-content {
      flex: 1;
      overflow-y: auto;
      overflow-x: hidden;
      padding: 4px 0;
    }
    .craft-sidebar-section {
      margin-bottom: 8px;
    }
    .craft-sidebar-section-header {
      display: flex;
      align-items: center;
      padding: 6px 12px;
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      opacity: 0.6;
      cursor: pointer;
    }
    .craft-sidebar-section-header:hover {
      opacity: 0.8;
    }
    .craft-sidebar-section-chevron {
      width: 12px;
      height: 12px;
      margin-right: 4px;
      transition: transform 0.15s;
    }
    .craft-sidebar-section-header.collapsed .craft-sidebar-section-chevron {
      transform: rotate(-90deg);
    }
    .craft-sidebar-section-items {
      transition: max-height 0.2s ease-out, opacity 0.15s;
    }
    .craft-sidebar-section-items.collapsed {
      max-height: 0;
      opacity: 0;
      overflow: hidden;
    }
    .craft-sidebar-item {
      display: flex;
      align-items: center;
      padding: 6px 12px 6px 16px;
      margin: 1px 8px;
      border-radius: var(--craft-radius, 6px);
      cursor: pointer;
      gap: 8px;
      transition: background 0.1s;
    }
    .craft-sidebar-item:hover {
      background: var(--craft-hover);
    }
    .craft-sidebar-item.selected {
      background: var(--craft-accent);
      color: var(--craft-accent-text, #fff);
    }
    .craft-sidebar-item-icon {
      width: 16px;
      height: 16px;
      flex-shrink: 0;
    }
    .craft-sidebar-item-label {
      flex: 1;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .craft-sidebar-item-badge {
      padding: 2px 6px;
      border-radius: 10px;
      font-size: 11px;
      font-weight: 500;
      background: var(--craft-badge-bg);
    }
    .craft-sidebar-item.selected .craft-sidebar-item-badge {
      background: rgba(255,255,255,0.25);
    }
    .craft-sidebar-footer {
      padding: 8px 12px;
      border-top: 1px solid var(--craft-border);
      display: flex;
      gap: 4px;
    }
  `

  // Platform-specific styles
  let platformStyles = ''

  if (platform === 'macos') {
    const macConfig = config.platform?.macos
    platformStyles = `
      :root {
        --craft-font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
        --craft-bg: ${macConfig?.vibrancy ? 'rgba(246,246,246,0.8)' : '#f6f6f6'};
        --craft-bg-dark: ${macConfig?.vibrancy ? 'rgba(30,30,30,0.8)' : '#1e1e1e'};
        --craft-text: #1d1d1f;
        --craft-text-dark: #f5f5f7;
        --craft-border: rgba(0,0,0,0.1);
        --craft-border-dark: rgba(255,255,255,0.1);
        --craft-hover: rgba(0,0,0,0.04);
        --craft-hover-dark: rgba(255,255,255,0.06);
        --craft-accent: #007aff;
        --craft-accent-text: #fff;
        --craft-input-bg: rgba(0,0,0,0.05);
        --craft-input-bg-dark: rgba(255,255,255,0.08);
        --craft-badge-bg: rgba(0,0,0,0.08);
        --craft-badge-bg-dark: rgba(255,255,255,0.1);
        --craft-radius: 6px;
      }
      .craft-sidebar {
        background: var(--craft-bg);
        color: var(--craft-text);
        ${macConfig?.vibrancy ? 'backdrop-filter: blur(20px) saturate(180%); -webkit-backdrop-filter: blur(20px) saturate(180%);' : ''}
        border-right: 1px solid var(--craft-border);
      }
      @media (prefers-color-scheme: dark) {
        .craft-sidebar {
          background: var(--craft-bg-dark);
          color: var(--craft-text-dark);
          border-color: var(--craft-border-dark);
        }
        .craft-sidebar-item:hover { background: var(--craft-hover-dark); }
        .craft-sidebar-search input { background: var(--craft-input-bg-dark); }
        .craft-sidebar-item-badge { background: var(--craft-badge-bg-dark); }
      }
    `
  } else if (platform === 'windows') {
    const winConfig = config.platform?.windows
    platformStyles = `
      :root {
        --craft-font-family: 'Segoe UI Variable', 'Segoe UI', sans-serif;
        --craft-bg: ${winConfig?.material === 'mica' ? 'rgba(243,243,243,0.9)' : '#f3f3f3'};
        --craft-bg-dark: ${winConfig?.material === 'mica' ? 'rgba(32,32,32,0.9)' : '#202020'};
        --craft-text: #1a1a1a;
        --craft-text-dark: #fff;
        --craft-border: rgba(0,0,0,0.08);
        --craft-border-dark: rgba(255,255,255,0.08);
        --craft-hover: rgba(0,0,0,0.04);
        --craft-hover-dark: rgba(255,255,255,0.06);
        --craft-accent: #0078d4;
        --craft-accent-text: #fff;
        --craft-input-bg: #fff;
        --craft-input-bg-dark: rgba(255,255,255,0.06);
        --craft-badge-bg: rgba(0,0,0,0.05);
        --craft-badge-bg-dark: rgba(255,255,255,0.08);
        --craft-radius: ${winConfig?.rounded ? '4px' : '0'};
      }
      .craft-sidebar {
        background: var(--craft-bg);
        color: var(--craft-text);
        ${winConfig?.material !== 'none' ? 'backdrop-filter: blur(30px); -webkit-backdrop-filter: blur(30px);' : ''}
      }
      @media (prefers-color-scheme: dark) {
        .craft-sidebar {
          background: var(--craft-bg-dark);
          color: var(--craft-text-dark);
        }
        .craft-sidebar-item:hover { background: var(--craft-hover-dark); }
        .craft-sidebar-search input { background: var(--craft-input-bg-dark); border-color: var(--craft-border-dark); }
        .craft-sidebar-item-badge { background: var(--craft-badge-bg-dark); }
      }
    `
  } else {
    // Linux / GTK style
    platformStyles = `
      :root {
        --craft-font-family: 'Cantarell', 'Ubuntu', sans-serif;
        --craft-bg: #f6f5f4;
        --craft-bg-dark: #303030;
        --craft-text: #2e3436;
        --craft-text-dark: #fff;
        --craft-border: rgba(0,0,0,0.12);
        --craft-border-dark: rgba(255,255,255,0.12);
        --craft-hover: rgba(0,0,0,0.05);
        --craft-hover-dark: rgba(255,255,255,0.08);
        --craft-accent: #3584e4;
        --craft-accent-text: #fff;
        --craft-input-bg: #fff;
        --craft-input-bg-dark: rgba(255,255,255,0.08);
        --craft-badge-bg: rgba(0,0,0,0.08);
        --craft-badge-bg-dark: rgba(255,255,255,0.12);
        --craft-radius: 6px;
      }
      .craft-sidebar {
        background: var(--craft-bg);
        color: var(--craft-text);
        border-right: 1px solid var(--craft-border);
      }
      @media (prefers-color-scheme: dark) {
        .craft-sidebar {
          background: var(--craft-bg-dark);
          color: var(--craft-text-dark);
          border-color: var(--craft-border-dark);
        }
        .craft-sidebar-item:hover { background: var(--craft-hover-dark); }
        .craft-sidebar-search input { background: var(--craft-input-bg-dark); border-color: var(--craft-border-dark); }
        .craft-sidebar-item-badge { background: var(--craft-badge-bg-dark); }
      }
    `
  }

  return baseStyles + platformStyles
}

// ============================================================================
// HTML Generation
// ============================================================================

function generateHTML(config: SidebarConfig): string {
  const renderItem = (item: SidebarItem): string => `
    <div class="craft-sidebar-item${item.selected ? ' selected' : ''}" data-id="${item.id}">
      ${item.icon ? `<span class="craft-sidebar-item-icon">${getIcon(item.icon, item.tintColor)}</span>` : ''}
      <span class="craft-sidebar-item-label">${item.label}</span>
      ${item.badge !== undefined ? `<span class="craft-sidebar-item-badge">${item.badge}</span>` : ''}
    </div>
  `

  const renderSection = (section: SidebarSection): string => `
    <div class="craft-sidebar-section" data-section="${section.id}">
      ${section.title ? `
        <div class="craft-sidebar-section-header${section.collapsed ? ' collapsed' : ''}" data-section-toggle="${section.id}">
          ${section.collapsible !== false ? `<svg class="craft-sidebar-section-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg>` : ''}
          ${section.title}
        </div>
      ` : ''}
      <div class="craft-sidebar-section-items${section.collapsed ? ' collapsed' : ''}" data-section-items="${section.id}">
        ${section.items.map(renderItem).join('')}
      </div>
    </div>
  `

  return `
    <aside class="craft-sidebar">
      ${config.headerTitle ? `
        <div class="craft-sidebar-header">
          <div class="craft-sidebar-header-title">${config.headerTitle}</div>
          ${config.headerSubtitle ? `<div class="craft-sidebar-header-subtitle">${config.headerSubtitle}</div>` : ''}
        </div>
      ` : ''}
      ${config.showSearch ? `
        <div class="craft-sidebar-search">
          <input type="text" placeholder="${config.searchPlaceholder || 'Search'}" data-sidebar-search>
        </div>
      ` : ''}
      <div class="craft-sidebar-content">
        ${config.sections?.map(renderSection).join('') || ''}
        ${config.items?.map(renderItem).join('') || ''}
      </div>
    </aside>
  `
}

// Simple icon helper - returns SVG for common icons
function getIcon(name: string, tintColor?: string): string {
  const color = tintColor || 'currentColor'
  const icons: Record<string, string> = {
    folder: `<svg viewBox="0 0 24 24" fill="${color}"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>`,
    file: `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2"><path d="M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><polyline points="13 2 13 9 20 9"/></svg>`,
    home: `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>`,
    download: `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>`,
    cloud: `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2"><path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"/></svg>`,
    star: `<svg viewBox="0 0 24 24" fill="${color}"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`,
    settings: `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M12 1v2m0 18v2M4.22 4.22l1.42 1.42m12.72 12.72 1.42 1.42M1 12h2m18 0h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>`,
    user: `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>`,
    users: `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87m-4-12a4 4 0 0 1 0 7.75"/></svg>`,
    clock: `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`,
    computer: `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>`,
    globe: `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>`,
    tag: `<svg viewBox="0 0 24 24" fill="${color}"><circle cx="12" cy="12" r="8"/></svg>`,
    wifi: `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2"><path d="M5 12.55a11 11 0 0 1 14.08 0M1.42 9a16 16 0 0 1 21.16 0M8.53 16.11a6 6 0 0 1 6.95 0M12 20h.01"/></svg>`,
  }
  return icons[name] || icons.file
}

// ============================================================================
// Sidebar Class
// ============================================================================

export class Sidebar {
  private config: SidebarConfig
  private element: HTMLElement | null = null
  private onSelectHandler?: (event: SidebarSelectEvent) => void
  private onSearchHandler?: (event: SidebarSearchEvent) => void

  constructor(config: SidebarConfig = {}) {
    const platform = getPlatform()
    const defaults = getDefaults(platform)
    this.config = { ...defaults, ...config }
  }

  /** Render the sidebar and return HTML + CSS */
  render(): { html: string; css: string } {
    const platform = getPlatform()
    return {
      html: generateHTML(this.config),
      css: generateCSS(this.config, platform)
    }
  }

  /** Mount sidebar to a container element */
  mount(container: HTMLElement | string = 'body'): void {
    const target = typeof container === 'string'
      ? document.querySelector(container)
      : container

    if (!target) {
      console.error('[Sidebar] Container not found')
      return
    }

    const { html, css } = this.render()

    // Inject styles
    const styleEl = document.createElement('style')
    styleEl.textContent = css
    document.head.appendChild(styleEl)

    // Inject HTML
    target.insertAdjacentHTML('afterbegin', html)
    this.element = target.querySelector('.craft-sidebar')

    this.attachEventListeners()
  }

  /** Update configuration and re-render */
  update(config: Partial<SidebarConfig>): void {
    this.config = { ...this.config, ...config }
    if (this.element) {
      const { html } = this.render()
      this.element.outerHTML = html
      this.element = document.querySelector('.craft-sidebar')
      this.attachEventListeners()
    }
  }

  /** Select an item programmatically */
  selectItem(itemId: string): void {
    if (!this.element) return
    this.element.querySelectorAll('.craft-sidebar-item').forEach(el => {
      el.classList.toggle('selected', el.getAttribute('data-id') === itemId)
    })
  }

  /** Register selection handler */
  onSelect(handler: (event: SidebarSelectEvent) => void): void {
    this.onSelectHandler = handler
  }

  /** Register search handler */
  onSearch(handler: (event: SidebarSearchEvent) => void): void {
    this.onSearchHandler = handler
  }

  private attachEventListeners(): void {
    if (!this.element) return

    // Item clicks
    this.element.querySelectorAll('.craft-sidebar-item').forEach(item => {
      item.addEventListener('click', () => {
        const itemId = item.getAttribute('data-id')
        if (!itemId) return

        // Update selection
        this.element?.querySelectorAll('.craft-sidebar-item').forEach(el => {
          el.classList.remove('selected')
        })
        item.classList.add('selected')

        // Fire event
        if (this.onSelectHandler) {
          const sidebarItem = this.findItem(itemId)
          this.onSelectHandler({
            itemId,
            item: sidebarItem || { id: itemId, label: '' }
          })
        }
      })
    })

    // Section toggle
    this.element.querySelectorAll('[data-section-toggle]').forEach(header => {
      header.addEventListener('click', () => {
        const sectionId = header.getAttribute('data-section-toggle')
        const items = this.element?.querySelector(`[data-section-items="${sectionId}"]`)
        if (items) {
          header.classList.toggle('collapsed')
          items.classList.toggle('collapsed')
        }
      })
    })

    // Search
    const searchInput = this.element.querySelector('[data-sidebar-search]') as HTMLInputElement
    if (searchInput) {
      searchInput.addEventListener('input', () => {
        const query = searchInput.value.toLowerCase()

        // Filter items
        this.element?.querySelectorAll('.craft-sidebar-item').forEach(item => {
          const label = item.querySelector('.craft-sidebar-item-label')?.textContent?.toLowerCase() || ''
          ;(item as HTMLElement).style.display = label.includes(query) ? '' : 'none'
        })

        // Fire event
        if (this.onSearchHandler) {
          this.onSearchHandler({ query: searchInput.value })
        }
      })
    }
  }

  private findItem(itemId: string): SidebarItem | undefined {
    const searchItems = (items: SidebarItem[]): SidebarItem | undefined => {
      for (const item of items) {
        if (item.id === itemId) return item
        if (item.children) {
          const found = searchItems(item.children)
          if (found) return found
        }
      }
    }

    if (this.config.items) {
      const found = searchItems(this.config.items)
      if (found) return found
    }

    for (const section of this.config.sections || []) {
      const found = searchItems(section.items)
      if (found) return found
    }
  }
}

// ============================================================================
// Factory Functions
// ============================================================================

/** Create a sidebar with platform-appropriate defaults */
export function createSidebar(config: SidebarConfig = {}): Sidebar {
  return new Sidebar(config)
}

/** Create a file-browser style sidebar (Finder/Explorer) */
export function createFileSidebar(sections?: SidebarSection[]): Sidebar {
  const defaultSections: SidebarSection[] = [
    {
      id: 'favorites',
      title: 'Favorites',
      collapsible: true,
      items: [
        { id: 'home', label: 'Home', icon: 'home' },
        { id: 'desktop', label: 'Desktop', icon: 'computer' },
        { id: 'documents', label: 'Documents', icon: 'folder' },
        { id: 'downloads', label: 'Downloads', icon: 'download' }
      ]
    },
    {
      id: 'cloud',
      title: getPlatform() === 'macos' ? 'iCloud' : 'Cloud',
      collapsible: true,
      items: [
        { id: 'cloud-drive', label: getPlatform() === 'macos' ? 'iCloud Drive' : 'Cloud Storage', icon: 'cloud' }
      ]
    },
    {
      id: 'locations',
      title: 'Locations',
      collapsible: true,
      items: [
        { id: 'this-pc', label: getPlatform() === 'macos' ? 'This Mac' : 'This PC', icon: 'computer' },
        { id: 'network', label: 'Network', icon: 'globe' }
      ]
    }
  ]

  return new Sidebar({
    sections: sections || defaultSections,
    showSearch: true,
    searchPlaceholder: 'Search'
  })
}

/** Create a settings/preferences style sidebar */
export function createSettingsSidebar(items: SidebarItem[]): Sidebar {
  return new Sidebar({
    items,
    showSearch: true,
    searchPlaceholder: 'Search settings',
    platform: {
      macos: {
        vibrancy: true,
        trafficLightsInSidebar: true,
        hideTitlebarSeparator: true
      },
      windows: {
        material: 'mica',
        rounded: true
      }
    }
  })
}

// ============================================================================
// Convenience Export
// ============================================================================

export const sidebar: {
  create: typeof createSidebar
  file: typeof createFileSidebar
  settings: typeof createSettingsSidebar
  Sidebar: typeof Sidebar
} = {
  create: createSidebar,
  file: createFileSidebar,
  settings: createSettingsSidebar,
  Sidebar: Sidebar
}

export default sidebar
