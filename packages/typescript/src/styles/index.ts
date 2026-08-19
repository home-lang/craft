/**
 * Craft Styles
 * CSS/Tailwind utilities and pre-built component styles
 * @module @craft-native/styles
 */

// Headwind (Tailwind-compatible) utilities
export {
  tw,
  cx,
  variants,
  style,
  generateConfig,
  buildCSS
} from './headwind.js'
export type {
  ClassValue,
  VariantConfig,
  HeadwindConfig
} from './headwind.js'

// Sidebar styles (Tahoe, Arc, OrbStack)
export {
  tahoeStyles,
  arcStyles,
  orbstackStyles,
  sidebarUtils,
  sidebarCSSVariables,
  getSidebarStyle
} from './sidebars.js'

// Sidebar HTML templates
export {
  renderTahoeSidebar,
  renderArcSidebar,
  renderOrbStackSidebar,
  tahoeDemoData,
  arcDemoData,
  orbstackDemoData,
  getFullPageHTML
} from './sidebar-templates.js'
export type {
  SidebarItemData,
  SidebarSectionData,
  SidebarData
} from './sidebar-templates.js'

// Re-export cx as clsx alias for familiarity
export { cx as clsx } from './headwind.js'

// Re-export sidebar defaults
import { tahoeStyles, arcStyles, orbstackStyles } from './sidebars.js'
import { renderTahoeSidebar, renderArcSidebar, renderOrbStackSidebar } from './sidebar-templates.js'
import { tw, cx, variants } from './headwind.js'

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
