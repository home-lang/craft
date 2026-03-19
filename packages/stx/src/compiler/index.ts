/**
 * STX SFC Compiler (v2)
 *
 * Compiles .stx single-file components into JavaScript.
 *
 * v2 format:
 *   <script>         — Client TS (default)
 *   <script server>  — SSR-only, stripped from client output
 *   <script js>      — Client JS (opt out of TS)
 *   <template>       — HTML with {{ }}, :bind, @event, @model, @if, @for
 *   <style scoped>   — Scoped CSS with data-v-stx-{hash}
 *
 * v2 features:
 *   - TypeScript by default (Bun.Transpiler)
 *   - Auto-binding (template refs matched to script declarations)
 *   - Composition API on window.stx (auto-imported)
 *   - data-stx-props serialization
 *   - Deterministic scope IDs
 *
 * Usage as Bun plugin:
 *   import { stxPlugin } from '@craft-native/stx/compiler'
 *   Bun.plugin(stxPlugin())
 */

export { parse } from './parser'
export type { SFCDescriptor, SFCBlock } from './parser'
export { compile } from './compile'
export type { CompileOptions } from './compile'
export { stxPlugin } from './plugin'
export type { StxPluginOptions } from './plugin'
