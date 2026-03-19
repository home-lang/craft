/**
 * STX Client-Side Router (v2)
 *
 * - Fragment-based SPA navigation via X-STX-Fragment header
 * - View Transitions API with CSS fallback
 * - <StxLink> component for navigation with active class
 * - App shell support (app.stx with <slot />)
 */

export { createRouter, navigate, getCurrentRoute } from './router'
export type { Route, RouterOptions } from './router'
export { StxLink } from './link'
export type { StxLinkProps } from './link'
export { loadShell, injectPage } from './shell'
