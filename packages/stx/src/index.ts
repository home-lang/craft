/**
 * @craft-native/stx
 *
 * STX component library for Craft — signal-driven UI primitives
 * with crosswind utility styling for desktop, mobile, and web.
 */

// Core reactivity
export { signal, computed, effect, batch } from './runtime'
export type { Signal, Computed, ReadonlySignal } from './runtime'

// Component helpers
export { defineComponent, h, mount } from './component'
export type { Component, ComponentDef, Props, Slot } from './component'

// Styles
export { tw, cx, variants, style } from './styles'

// Components
export * from './components'

// Composables
export * from './composables'

// Directives
export * from './directives'
