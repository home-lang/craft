/**
 * Craft Sidebar Styles
 * CSS/Tailwind-based sidebar implementations
 *
 * Three styles:
 * - Tahoe: macOS Sonoma/Sequoia Finder style
 * - Arc: Arc browser vertical tabs style
 * - OrbStack: Dark minimal style
 *
 * @module @craft/styles/sidebars
 */

// ============================================================================
// Tahoe Style (macOS Finder)
// ============================================================================

/**
 * Tahoe sidebar - macOS Sonoma/Sequoia Finder style
 *
 * Features:
 * - Translucent vibrancy background
 * - Source list appearance
 * - Rounded selection highlights
 * - Section headers in small caps
 * - SF Symbol-style icons
 */
export const tahoeStyles = {
  // Container
  sidebar: `
    w-56 h-full flex flex-col
    bg-white/70 dark:bg-neutral-900/70
    backdrop-blur-xl backdrop-saturate-150
    border-r border-black/5 dark:border-white/5
    select-none
  `,

  // Scrollable content area
  content: `
    flex-1 overflow-y-auto overflow-x-hidden
    py-2 px-2
    scrollbar-thin scrollbar-thumb-black/10 dark:scrollbar-thumb-white/10
  `,

  // Section container
  section: `
    mb-4
  `,

  // Section header
  sectionHeader: `
    px-2 py-1.5 mb-1
    text-[11px] font-semibold uppercase tracking-wider
    text-neutral-500 dark:text-neutral-400
  `,

  // Section header (collapsible)
  sectionHeaderCollapsible: `
    px-2 py-1.5 mb-1 flex items-center gap-1 cursor-pointer
    text-[11px] font-semibold uppercase tracking-wider
    text-neutral-500 dark:text-neutral-400
    hover:text-neutral-700 dark:hover:text-neutral-200
    transition-colors duration-150
  `,

  // Collapse chevron
  collapseChevron: `
    w-3 h-3 transition-transform duration-200
  `,

  // Item
  item: `
    flex items-center gap-2.5 px-2 py-1.5 mx-1 rounded-md
    text-[13px] text-neutral-700 dark:text-neutral-200
    cursor-pointer transition-all duration-150
    hover:bg-black/5 dark:hover:bg-white/5
  `,

  // Item selected
  itemSelected: `
    flex items-center gap-2.5 px-2 py-1.5 mx-1 rounded-md
    text-[13px] text-white
    cursor-pointer
    bg-blue-500 dark:bg-blue-600
    shadow-sm
  `,

  // Item icon
  itemIcon: `
    w-4 h-4 flex-shrink-0
    text-neutral-500 dark:text-neutral-400
  `,

  // Item icon (selected)
  itemIconSelected: `
    w-4 h-4 flex-shrink-0
    text-white/90
  `,

  // Item label
  itemLabel: `
    flex-1 truncate
  `,

  // Item badge
  itemBadge: `
    px-1.5 py-0.5 rounded-full text-[10px] font-medium
    bg-neutral-200 dark:bg-neutral-700
    text-neutral-600 dark:text-neutral-300
  `,

  // Item badge (selected)
  itemBadgeSelected: `
    px-1.5 py-0.5 rounded-full text-[10px] font-medium
    bg-white/20 text-white
  `,

  // Expandable item children container
  children: `
    ml-4 mt-0.5 border-l border-neutral-200 dark:border-neutral-700
  `,

  // Drag indicator
  dragIndicator: `
    absolute left-0 right-0 h-0.5 bg-blue-500
    pointer-events-none
  `,

  // Search input
  searchContainer: `
    px-2 pb-2
  `,

  searchInput: `
    w-full px-3 py-1.5 rounded-md
    text-[13px] placeholder:text-neutral-400
    bg-black/5 dark:bg-white/5
    border border-transparent
    focus:outline-none focus:border-blue-500/50 focus:bg-white dark:focus:bg-neutral-800
    transition-all duration-150
  `,

  // Header area (for profile/title)
  header: `
    px-3 py-3 border-b border-black/5 dark:border-white/5
    flex items-center gap-3
  `,

  headerAvatar: `
    w-8 h-8 rounded-full bg-gradient-to-br from-blue-400 to-blue-600
    flex items-center justify-center text-white text-sm font-medium
  `,

  headerTitle: `
    text-[13px] font-medium text-neutral-800 dark:text-neutral-100
  `,

  headerSubtitle: `
    text-[11px] text-neutral-500 dark:text-neutral-400
  `,

  // Footer
  footer: `
    px-2 py-2 border-t border-black/5 dark:border-white/5
    flex items-center gap-2
  `,

  footerButton: `
    p-1.5 rounded-md
    text-neutral-500 dark:text-neutral-400
    hover:bg-black/5 dark:hover:bg-white/5
    hover:text-neutral-700 dark:hover:text-neutral-200
    transition-colors duration-150
  `,
}

// ============================================================================
// Arc Style (Arc Browser)
// ============================================================================

/**
 * Arc sidebar - Arc browser vertical tabs style
 *
 * Features:
 * - Pill-shaped selection with gradient
 * - Collapsible to icon-only mode
 * - Colorful accent options
 * - Pinned items section
 * - Animated transitions
 */
export const arcStyles = {
  // Container - expanded
  sidebar: `
    w-64 h-full flex flex-col
    bg-neutral-100 dark:bg-neutral-900
    border-r border-neutral-200 dark:border-neutral-800
    transition-all duration-300 ease-out
    select-none
  `,

  // Container - collapsed (icon only)
  sidebarCollapsed: `
    w-12 h-full flex flex-col
    bg-neutral-100 dark:bg-neutral-900
    border-r border-neutral-200 dark:border-neutral-800
    transition-all duration-300 ease-out
    select-none
  `,

  // Top bar with controls
  topBar: `
    h-10 px-2 flex items-center justify-between
    border-b border-neutral-200 dark:border-neutral-800
  `,

  // Collapse toggle button
  collapseButton: `
    p-1.5 rounded-lg
    text-neutral-500 dark:text-neutral-400
    hover:bg-neutral-200 dark:hover:bg-neutral-800
    transition-colors duration-150
  `,

  // New tab button
  newTabButton: `
    p-1.5 rounded-lg
    text-neutral-500 dark:text-neutral-400
    hover:bg-neutral-200 dark:hover:bg-neutral-800
    transition-colors duration-150
  `,

  // Content area
  content: `
    flex-1 overflow-y-auto overflow-x-hidden
    py-2
    scrollbar-thin scrollbar-thumb-neutral-300 dark:scrollbar-thumb-neutral-700
  `,

  // Pinned section
  pinnedSection: `
    px-2 pb-3 mb-2 border-b border-neutral-200 dark:border-neutral-800
  `,

  pinnedLabel: `
    px-2 py-1 text-[10px] font-semibold uppercase tracking-wider
    text-neutral-400 dark:text-neutral-500
  `,

  // Section header
  sectionHeader: `
    px-3 py-2 flex items-center justify-between
    text-[11px] font-semibold uppercase tracking-wider
    text-neutral-500 dark:text-neutral-400
  `,

  // Space/folder container
  space: `
    mb-3
  `,

  spaceHeader: `
    px-2 py-1.5 mx-2 rounded-lg flex items-center gap-2
    cursor-pointer
    hover:bg-neutral-200/50 dark:hover:bg-neutral-800/50
    transition-colors duration-150
  `,

  spaceIcon: `
    w-5 h-5 rounded-md flex items-center justify-center text-xs
  `,

  spaceName: `
    flex-1 text-[12px] font-medium text-neutral-700 dark:text-neutral-200
  `,

  spaceCount: `
    text-[11px] text-neutral-400 dark:text-neutral-500
  `,

  // Item (tab)
  item: `
    flex items-center gap-2.5 px-3 py-2 mx-2 rounded-xl
    text-[13px] text-neutral-700 dark:text-neutral-300
    cursor-pointer transition-all duration-200
    hover:bg-neutral-200/70 dark:hover:bg-neutral-800/70
    group
  `,

  // Item selected - with gradient pill
  itemSelected: `
    flex items-center gap-2.5 px-3 py-2 mx-2 rounded-xl
    text-[13px] text-white font-medium
    cursor-pointer transition-all duration-200
    bg-gradient-to-r from-purple-500 to-pink-500
    shadow-lg shadow-purple-500/25
  `,

  // Item (collapsed mode - icon only)
  itemCollapsed: `
    flex items-center justify-center p-2.5 mx-1.5 rounded-xl
    cursor-pointer transition-all duration-200
    hover:bg-neutral-200/70 dark:hover:bg-neutral-800/70
    group relative
  `,

  itemCollapsedSelected: `
    flex items-center justify-center p-2.5 mx-1.5 rounded-xl
    cursor-pointer transition-all duration-200
    bg-gradient-to-r from-purple-500 to-pink-500
    shadow-lg shadow-purple-500/25
  `,

  // Favicon/icon container
  itemFavicon: `
    w-4 h-4 rounded flex-shrink-0
    bg-neutral-300 dark:bg-neutral-700
  `,

  itemFaviconSelected: `
    w-4 h-4 rounded flex-shrink-0
  `,

  // Item label
  itemLabel: `
    flex-1 truncate
  `,

  // Close button (visible on hover)
  itemClose: `
    p-0.5 rounded opacity-0 group-hover:opacity-100
    text-neutral-400 hover:text-neutral-600
    dark:text-neutral-500 dark:hover:text-neutral-300
    hover:bg-neutral-300/50 dark:hover:bg-neutral-700/50
    transition-all duration-150
  `,

  itemCloseSelected: `
    p-0.5 rounded opacity-0 group-hover:opacity-100
    text-white/60 hover:text-white
    hover:bg-white/20
    transition-all duration-150
  `,

  // Tooltip for collapsed mode
  tooltip: `
    absolute left-full ml-2 px-2 py-1 rounded-md
    text-[12px] text-white bg-neutral-800 dark:bg-neutral-700
    whitespace-nowrap opacity-0 group-hover:opacity-100
    pointer-events-none transition-opacity duration-150
    z-50
  `,

  // Today section
  todaySection: `
    px-2 pt-2
  `,

  todayLabel: `
    px-2 py-1 text-[10px] font-semibold uppercase tracking-wider
    text-neutral-400 dark:text-neutral-500
  `,

  // Bottom bar
  bottomBar: `
    px-2 py-2 border-t border-neutral-200 dark:border-neutral-800
    flex items-center gap-1
  `,

  bottomButton: `
    flex-1 py-2 rounded-lg flex items-center justify-center gap-2
    text-[12px] text-neutral-600 dark:text-neutral-400
    hover:bg-neutral-200 dark:hover:bg-neutral-800
    transition-colors duration-150
  `,

  // Color options for spaces
  spaceColors: {
    red: 'bg-red-500',
    orange: 'bg-orange-500',
    yellow: 'bg-yellow-500',
    green: 'bg-green-500',
    blue: 'bg-blue-500',
    purple: 'bg-purple-500',
    pink: 'bg-pink-500',
  },

  // Gradient options for selected items
  selectedGradients: {
    purple: 'bg-gradient-to-r from-purple-500 to-pink-500 shadow-purple-500/25',
    blue: 'bg-gradient-to-r from-blue-500 to-cyan-500 shadow-blue-500/25',
    green: 'bg-gradient-to-r from-green-500 to-emerald-500 shadow-green-500/25',
    orange: 'bg-gradient-to-r from-orange-500 to-amber-500 shadow-orange-500/25',
    red: 'bg-gradient-to-r from-red-500 to-rose-500 shadow-red-500/25',
  },
}

// ============================================================================
// OrbStack Style (Dark Minimal)
// ============================================================================

/**
 * OrbStack sidebar - Dark minimal style
 *
 * Features:
 * - Dark theme optimized
 * - Compact spacing
 * - Subtle hover states
 * - Monochrome icons
 * - Clean, utilitarian design
 */
export const orbstackStyles = {
  // Container
  sidebar: `
    w-52 h-full flex flex-col
    bg-[#1a1a1a] dark:bg-[#1a1a1a]
    border-r border-[#2a2a2a]
    select-none
  `,

  // Header
  header: `
    h-12 px-3 flex items-center justify-between
    border-b border-[#2a2a2a]
  `,

  headerTitle: `
    text-[13px] font-semibold text-white
  `,

  headerAction: `
    p-1 rounded
    text-neutral-500 hover:text-neutral-300
    hover:bg-white/5
    transition-colors duration-150
  `,

  // Content
  content: `
    flex-1 overflow-y-auto overflow-x-hidden
    py-1
    scrollbar-thin scrollbar-thumb-neutral-700 scrollbar-track-transparent
  `,

  // Section
  section: `
    py-1
  `,

  sectionHeader: `
    px-3 py-2 flex items-center justify-between
    text-[11px] font-medium uppercase tracking-wider
    text-neutral-500
  `,

  sectionHeaderClickable: `
    px-3 py-2 flex items-center justify-between cursor-pointer
    text-[11px] font-medium uppercase tracking-wider
    text-neutral-500 hover:text-neutral-400
    transition-colors duration-150
  `,

  sectionCount: `
    text-[10px] px-1.5 py-0.5 rounded
    bg-neutral-800 text-neutral-400
  `,

  // Divider
  divider: `
    my-1 mx-3 border-t border-[#2a2a2a]
  `,

  // Item
  item: `
    flex items-center gap-2.5 px-3 py-1.5
    text-[13px] text-neutral-300
    cursor-pointer transition-colors duration-150
    hover:bg-white/5 hover:text-white
  `,

  // Item selected
  itemSelected: `
    flex items-center gap-2.5 px-3 py-1.5
    text-[13px] text-white font-medium
    cursor-pointer
    bg-white/10
  `,

  // Item with indicator (running state)
  itemWithIndicator: `
    flex items-center gap-2.5 px-3 py-1.5
    text-[13px] text-neutral-300
    cursor-pointer transition-colors duration-150
    hover:bg-white/5 hover:text-white
    relative
  `,

  // Running indicator dot
  runningIndicator: `
    w-1.5 h-1.5 rounded-full bg-green-500
    absolute left-1
  `,

  // Stopped indicator
  stoppedIndicator: `
    w-1.5 h-1.5 rounded-full bg-neutral-600
    absolute left-1
  `,

  // Item icon
  itemIcon: `
    w-4 h-4 flex-shrink-0
    text-neutral-500
  `,

  itemIconSelected: `
    w-4 h-4 flex-shrink-0
    text-white
  `,

  // Item label
  itemLabel: `
    flex-1 truncate
  `,

  // Item status text
  itemStatus: `
    text-[11px] text-neutral-500
  `,

  // Item actions (show on hover)
  itemActions: `
    flex items-center gap-1 opacity-0 group-hover:opacity-100
    transition-opacity duration-150
  `,

  itemActionButton: `
    p-1 rounded
    text-neutral-500 hover:text-white
    hover:bg-white/10
    transition-colors duration-150
  `,

  // Expandable group
  group: `
    group
  `,

  groupHeader: `
    flex items-center gap-2 px-3 py-1.5 cursor-pointer
    text-[13px] text-neutral-400
    hover:bg-white/5 hover:text-neutral-200
    transition-colors duration-150
  `,

  groupChevron: `
    w-3 h-3 text-neutral-600
    transition-transform duration-200
  `,

  groupChevronExpanded: `
    w-3 h-3 text-neutral-600
    transition-transform duration-200
    rotate-90
  `,

  groupContent: `
    overflow-hidden transition-all duration-200
  `,

  // Footer
  footer: `
    px-3 py-2 border-t border-[#2a2a2a]
    flex items-center justify-between
  `,

  footerText: `
    text-[11px] text-neutral-500
  `,

  footerButton: `
    p-1.5 rounded
    text-neutral-500 hover:text-white
    hover:bg-white/10
    transition-colors duration-150
  `,

  // Context menu
  contextMenu: `
    min-w-40 py-1 rounded-lg
    bg-[#252525] border border-[#3a3a3a]
    shadow-xl shadow-black/50
  `,

  contextMenuItem: `
    px-3 py-1.5 flex items-center gap-2
    text-[13px] text-neutral-300
    cursor-pointer
    hover:bg-white/10
    transition-colors duration-100
  `,

  contextMenuItemDanger: `
    px-3 py-1.5 flex items-center gap-2
    text-[13px] text-red-400
    cursor-pointer
    hover:bg-red-500/10
    transition-colors duration-100
  `,

  contextMenuDivider: `
    my-1 border-t border-[#3a3a3a]
  `,

  // Empty state
  emptyState: `
    flex flex-col items-center justify-center py-8
    text-neutral-500
  `,

  emptyStateIcon: `
    w-8 h-8 mb-2 text-neutral-600
  `,

  emptyStateText: `
    text-[13px]
  `,

  // Loading state
  loadingSpinner: `
    w-4 h-4 border-2 border-neutral-600 border-t-neutral-400
    rounded-full animate-spin
  `,
}

// ============================================================================
// Utility Classes
// ============================================================================

/**
 * Common utility classes for all sidebar styles
 */
export const sidebarUtils = {
  // Transitions
  transitionFast: 'transition-all duration-150',
  transitionNormal: 'transition-all duration-200',
  transitionSlow: 'transition-all duration-300',

  // Scrollbar styles
  scrollbarThin: 'scrollbar-thin scrollbar-track-transparent',
  scrollbarLight: 'scrollbar-thumb-black/10 hover:scrollbar-thumb-black/20',
  scrollbarDark: 'scrollbar-thumb-white/10 hover:scrollbar-thumb-white/20',

  // Focus styles
  focusRing: 'focus:outline-none focus:ring-2 focus:ring-blue-500/50',
  focusRingInset: 'focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500/50',

  // Text truncation
  truncate: 'truncate',
  lineClamp2: 'line-clamp-2',

  // Flex utilities
  flexCenter: 'flex items-center justify-center',
  flexBetween: 'flex items-center justify-between',
  flexStart: 'flex items-center justify-start',

  // Hide scrollbar but keep functionality
  hideScrollbar: 'scrollbar-none [-ms-overflow-style:none] [scrollbar-width:none]',
}

// ============================================================================
// CSS Custom Properties (for dynamic theming)
// ============================================================================

/**
 * CSS variables for sidebar theming
 * Inject these into your app's root styles
 */
export const sidebarCSSVariables = `
:root {
  /* Tahoe style variables */
  --sidebar-tahoe-bg: rgba(255, 255, 255, 0.7);
  --sidebar-tahoe-bg-dark: rgba(30, 30, 30, 0.7);
  --sidebar-tahoe-border: rgba(0, 0, 0, 0.05);
  --sidebar-tahoe-border-dark: rgba(255, 255, 255, 0.05);
  --sidebar-tahoe-text: #404040;
  --sidebar-tahoe-text-dark: #e5e5e5;
  --sidebar-tahoe-text-muted: #737373;
  --sidebar-tahoe-text-muted-dark: #a3a3a3;
  --sidebar-tahoe-selected: #3b82f6;
  --sidebar-tahoe-hover: rgba(0, 0, 0, 0.05);
  --sidebar-tahoe-hover-dark: rgba(255, 255, 255, 0.05);

  /* Arc style variables */
  --sidebar-arc-bg: #f5f5f5;
  --sidebar-arc-bg-dark: #171717;
  --sidebar-arc-border: #e5e5e5;
  --sidebar-arc-border-dark: #262626;
  --sidebar-arc-selected-from: #a855f7;
  --sidebar-arc-selected-to: #ec4899;
  --sidebar-arc-hover: rgba(0, 0, 0, 0.05);
  --sidebar-arc-hover-dark: rgba(255, 255, 255, 0.05);

  /* OrbStack style variables */
  --sidebar-orb-bg: #1a1a1a;
  --sidebar-orb-border: #2a2a2a;
  --sidebar-orb-text: #d4d4d4;
  --sidebar-orb-text-muted: #737373;
  --sidebar-orb-selected: rgba(255, 255, 255, 0.1);
  --sidebar-orb-hover: rgba(255, 255, 255, 0.05);
  --sidebar-orb-accent: #22c55e;
}
`

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Combine multiple class strings
 */
export function cx(...classes: (string | undefined | null | false)[]): string {
  return classes.filter(Boolean).join(' ').replace(/\s+/g, ' ').trim()
}

/**
 * Get style preset by name
 */
export function getSidebarStyle(name: 'tahoe' | 'arc' | 'orbstack') {
  switch (name) {
    case 'tahoe':
      return tahoeStyles
    case 'arc':
      return arcStyles
    case 'orbstack':
      return orbstackStyles
    default:
      return tahoeStyles
  }
}

// ============================================================================
// Export all styles
// ============================================================================

export default {
  tahoe: tahoeStyles,
  arc: arcStyles,
  orbstack: orbstackStyles,
  utils: sidebarUtils,
  cssVariables: sidebarCSSVariables,
  cx,
  getSidebarStyle,
}
