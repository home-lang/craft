/**
 * Craft Styles
 * CSS/Tailwind utilities and pre-built component styles
 * @module @craft/styles
 */

// Headwind (Tailwind-compatible) utilities
export {
  tw,
  cx,
  variants,
  style,
  generateConfig,
  buildCSS
} from './headwind'
export type {
  ClassValue,
  VariantConfig,
  HeadwindConfig
} from './headwind'

// Sidebar styles (Tahoe, Arc, OrbStack)
export {
  tahoeStyles,
  arcStyles,
  orbstackStyles,
  sidebarUtils,
  sidebarCSSVariables,
  getSidebarStyle
} from './sidebars'

// Sidebar HTML templates
export {
  renderTahoeSidebar,
  renderArcSidebar,
  renderOrbStackSidebar,
  tahoeDemoData,
  arcDemoData,
  orbstackDemoData,
  getFullPageHTML
} from './sidebar-templates'
export type {
  SidebarItemData,
  SidebarSectionData,
  SidebarData
} from './sidebar-templates'

// Re-export cx as clsx alias for familiarity
export { cx as clsx } from './headwind'

// Re-export sidebar defaults
import { tahoeStyles, arcStyles, orbstackStyles } from './sidebars'
import { renderTahoeSidebar, renderArcSidebar, renderOrbStackSidebar } from './sidebar-templates'
import { tw, cx, variants } from './headwind'

export const styles: {
  tw: typeof tw;
  cx: typeof cx;
  variants: typeof variants;
  sidebar: {
    tahoe: typeof tahoeStyles;
    arc: typeof arcStyles;
    orbstack: typeof orbstackStyles;
  };
  templates: {
    tahoe: typeof renderTahoeSidebar;
    arc: typeof renderArcSidebar;
    orbstack: typeof renderOrbStackSidebar;
  };
} = {
  // Headwind utilities
  tw,
  cx,
  variants,

  // Sidebar style objects
  sidebar: {
    tahoe: tahoeStyles,
    arc: arcStyles,
    orbstack: orbstackStyles,
  },

  // HTML template renderers
  templates: {
    tahoe: renderTahoeSidebar,
    arc: renderArcSidebar,
    orbstack: renderOrbStackSidebar,
  }
}

export default styles
