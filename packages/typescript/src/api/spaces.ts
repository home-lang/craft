/**
 * @fileoverview Native switcher for Arc-style sidebar spaces
 * @description Publishes a space list to a real control in the window chrome —
 * an NSSegmentedControl in the titlebar on macOS — and reports back what the
 * user picks.
 *
 * This is a *switcher*, not a second sidebar. The spaces, their rows and the
 * swipe stay in the webview (see `@stacksjs/components`' `<Sidebar :spaces>`);
 * only the chrome control is native. That is also why it does not collide with
 * `api/sidebar`'s one-native-sidebar-per-window rule: a window can have both.
 * @module @craft-native/api/spaces
 */

// ============================================================================
// Types
// ============================================================================

export interface SpaceDescriptor {
  /** Stable id. Also what comes back from `onSpaceChange`. */
  id: string
  /** Shown on the native control. Falls back to `id`. */
  label?: string
  /** SF Symbol name, where the host can render one. */
  icon?: string
  /**
   * Accent colour as `#rrggbb`. The host tints the selected segment with it so
   * the window chrome agrees with the pane instead of staying neutral grey
   * while the sidebar is deep blue.
   */
  tint?: string
}

export interface SpacesSidebarOptions {
  /** Supply one to keep a stable id across reloads; generated otherwise. */
  id?: string
  /**
   * Fewer than two and the native control stays hidden — one space renders as a
   * single selected segment naming the space the user is already in. It is
   * hidden rather than destroyed, so a later `setSpaces` with two or more
   * brings it straight back.
   */
  spaces?: SpaceDescriptor[]
  /** Which space opens selected. Defaults to the first. */
  activeSpace?: string
}

export interface SpacesSidebarHandle {
  readonly id: string
  /** Fires when the user picks a space in the native control. */
  onSpaceChange: (listener: (spaceId: string) => void) => SpacesSidebarHandle
  /**
   * Replace the list. The active space is preserved **by id** when it survives
   * the replacement, so reordering or inserting does not silently move the user
   * to a different space.
   */
  setSpaces: (spaces: SpaceDescriptor[]) => SpacesSidebarHandle
  /** Follow a switch that happened in the webview, e.g. a swipe. */
  setActiveSpace: (spaceId: string) => SpacesSidebarHandle
  destroy: () => void
}

export interface NativeUIAPI {
  createSpacesSidebar?: (options?: SpacesSidebarOptions) => SpacesSidebarHandle
}

// ============================================================================
// API
// ============================================================================

/**
 * Whether this host can put a native space switcher in the window chrome.
 *
 * Unlike `hasNativeGestures`, this one is meaningful: `createSpacesSidebar` is
 * only defined where the native UI bridge exists, so a `false` here really does
 * mean the web rail should render itself.
 */
export function hasNativeSpaces(): boolean {
  const nativeUI = (globalThis.window?.craft as { nativeUI?: NativeUIAPI } | undefined)?.nativeUI
  return typeof nativeUI?.createSpacesSidebar === 'function'
}

/**
 * Create the native switcher, or return `null` in a plain browser so callers
 * can fall back to their own rail without a try/catch.
 *
 * @example
 * ```ts
 * const switcher = createSpacesSidebar({
 *   spaces: profiles.map(p => ({ id: p.id, label: p.name, tint: p.tint })),
 *   activeSpace: active.id,
 * })
 * switcher?.onSpaceChange(id => goToProfile(id))
 * ```
 */
export function createSpacesSidebar(options: SpacesSidebarOptions = {}): SpacesSidebarHandle | null {
  const nativeUI = (globalThis.window?.craft as { nativeUI?: NativeUIAPI } | undefined)?.nativeUI
  if (typeof nativeUI?.createSpacesSidebar !== 'function') return null
  return nativeUI.createSpacesSidebar(options)
}

/** Namespace form, for `import { spaces } from 'craft-native'`. */
export const spaces: {
  hasNativeSpaces: () => boolean
  createSpacesSidebar: (options?: SpacesSidebarOptions) => SpacesSidebarHandle | null
} = { hasNativeSpaces, createSpacesSidebar }
