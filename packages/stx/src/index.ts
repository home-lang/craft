/**
 * @craft-native/stx
 *
 * STX component library for Craft — signal-driven UI primitives
 * with crosswind utility styling for desktop, mobile, and web.
 *
 * Aligned with stx syntax migration:
 * - state() / derived() / effect() reactivity
 * - defineProps / defineEmits / withDefaults composition API
 * - onMount / onDestroy / onUpdate lifecycle hooks
 * - @ directive syntax (@model, @show, @text, @class, @bind:*)
 */

// Core reactivity
export { state, derived, effect, batch, untrack, peek, isSignal, isDerived } from './runtime'
export { onMount, onDestroy, onUpdate, onMounted, onUnmounted, onUpdated, onBeforeMount, onBeforeUpdate, onBeforeUnmount, nextTick } from './runtime'
export type { State, Derived } from './runtime'

// Composition API
export { defineComponent, defineProps, defineEmits, withDefaults, defineExpose, provide, inject, h, mount } from './component'
export type { Component, ComponentDef, Props, Slot } from './component'

// Styles
export { tw, cx, variants, style } from './styles'

// Components
export * from './components'

// Composables
export * from './composables'

// Directives
export * from './directives'

// Store
export { defineStore } from './store'

// Form
export { defineForm, v } from './form'

// Transitions
export { transition, STXTransition } from './transitions'
export type { TransitionOptions } from './transitions'

// Error Boundaries
export { createErrorBoundary, withErrorBoundary } from './errorBoundary'
export type { ErrorBoundaryOptions, ErrorBoundaryInstance } from './errorBoundary'

// Keep-Alive
export { createKeepAlive } from './keepAlive'
export type { KeepAliveOptions } from './keepAlive'

// Partial Hydration (Islands)
export { hydrateIsland, hydrateByStrategy, hydrateAll, isHydrated, onHydrated, removeIsland, getIslandIds } from './hydration'
export type { HydrationStrategy, HydrationOptions } from './hydration'

// Router
export { createRouter, navigate, getCurrentRoute, StxLink, loadShell, injectPage } from './router'
export type { Route, RouterOptions, StxLinkProps } from './router'
