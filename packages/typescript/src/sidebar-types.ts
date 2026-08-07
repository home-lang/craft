/**
 * @fileoverview Shared sidebar item and section shapes
 * @description One definition for `api/sidebar` and `components/sidebar`.
 *
 * These two modules each used to declare their own `SidebarItem` with a
 * different set of fields, and the top-level package re-exported only the
 * `api` one — so reaching into `craft-native/components` silently handed you a
 * different type with the same name. Worse, the two disagreed about polarity:
 * `api` had `enabled`, `components` had `disabled`. An object that satisfied
 * one could mean the opposite to the other.
 *
 * This is the union of both, so nothing that compiled before stops compiling.
 * @module @craft-native/sidebar-types
 */

/**
 * Context menu item.
 *
 * Lives here rather than in `components/sidebar` because `SidebarItem`
 * references it, and a shared type cannot depend on one of the two modules it
 * is shared between without making the cycle real.
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
  /**
   * Whether the item is disabled. Prefer this over `enabled` — the two express
   * the same thing with opposite polarity, and mixing them is how an item ends
   * up enabled in one code path and disabled in another.
   */
  disabled?: boolean
  /**
   * @deprecated Use `disabled` instead. Retained so existing `api/sidebar`
   * callers keep working; when both are set, `disabled` wins.
   */
  enabled?: boolean
  /** Whether item is expandable/collapsible */
  expandable?: boolean
  /** Whether item is expanded (if expandable) */
  expanded?: boolean
  /** Child items */
  children?: SidebarItem[]
  /** Tint applied to the item's icon and label */
  tintColor?: string
  /** Custom data carried alongside the item */
  data?: Record<string, unknown>
  /** Tooltip */
  tooltip?: string
  /** Context menu items */
  contextMenu?: ContextMenuItem[]
  /** Whether item is draggable */
  draggable?: boolean
  /** Drop target types accepted */
  dropTypes?: string[]
}

export interface SidebarSection {
  /** Section ID */
  id: string
  /** Section title (can be empty for an untitled section) */
  title?: string
  /** Items in this section */
  items: SidebarItem[]
  /** Whether section is collapsible */
  collapsible?: boolean
  /** Whether section is collapsed */
  collapsed?: boolean
}

/**
 * Resolve the two polarities to one answer.
 *
 * `disabled` is authoritative when present; `enabled: false` still disables for
 * callers written against the older `api/sidebar` shape. Absent both, an item
 * is interactive.
 */
export function isSidebarItemDisabled(item: SidebarItem): boolean {
  if (item.disabled !== undefined)
    return item.disabled
  if (item.enabled !== undefined)
    return !item.enabled
  return false
}
