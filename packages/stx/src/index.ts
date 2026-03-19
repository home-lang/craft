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
export { state, derived, effect, batch, onMount, onDestroy, onUpdate, nextTick } from './runtime'
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

// Router
export { createRouter, navigate, getCurrentRoute, StxLink, loadShell, injectPage } from './router'
export type { Route, RouterOptions, StxLinkProps } from './router'
