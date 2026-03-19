/**
 * STX SFC Compiler
 *
 * Compiles .stx single-file components into JavaScript.
 * Format:
 *   <script server>  — SSR-only, stripped from client output
 *   <script client>  — Client-side, preserved
 *   <template>       — HTML template with {{ }} interpolation and @ directives
 *   <style scoped>   — Scoped CSS
 *
 * Usage as Bun plugin:
 *   import { stxPlugin } from '@craft-native/stx/compiler'
 *   Bun.plugin(stxPlugin())
 */

export { parse } from './parser'
export type { SFCDescriptor, SFCBlock } from './parser'
export { compile } from './compile'
export { stxPlugin } from './plugin'
