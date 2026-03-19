/**
 * Build script for @craft-native/stx
 */

import { CSSGenerator } from '@cwcss/crosswind'
import type { CrosswindConfig } from '@cwcss/crosswind'
import { Glob } from 'bun'
import { resolve } from 'node:path'

// 1. Bundle TypeScript
await Bun.build({
  entrypoints: [
    './src/index.ts',
    './src/components/index.ts',
    './src/composables/index.ts',
    './src/directives/index.ts',
    './src/styles.ts',
  ],
  outdir: './dist',
  target: 'browser',
  format: 'esm',
  minify: false,
  sourcemap: 'external',
  splitting: true,
})

// 2. Extract utility classes from TS source and generate CSS via crosswind
const config: CrosswindConfig = {
  content: [],
  output: '',
  minify: false,
  watch: false,
  safelist: [],
  blocklist: [],
  shortcuts: {},
  rules: [],
  presets: [],
  preflights: [],
  theme: {
    colors: {},
    spacing: {},
    fontSize: {},
    fontFamily: {},
    screens: {},
    borderRadius: {},
    boxShadow: {},
  },
  variants: {
    responsive: true,
    hover: true,
    focus: true,
    active: true,
    disabled: true,
    dark: true,
    group: false,
    peer: false,
    before: false,
    after: false,
    marker: false,
    first: false,
    last: false,
    odd: false,
    even: false,
    'first-of-type': false,
    'last-of-type': false,
    visited: false,
    checked: false,
    'focus-within': true,
    'focus-visible': true,
    placeholder: true,
    selection: false,
    file: false,
    required: false,
    valid: false,
    invalid: false,
    'read-only': false,
    autofill: false,
    open: false,
    closed: false,
    empty: false,
    enabled: false,
    only: false,
    target: false,
    indeterminate: false,
    default: false,
    optional: false,
    print: false,
    rtl: false,
    ltr: false,
    'motion-safe': false,
    'motion-reduce': false,
    'contrast-more': false,
    'contrast-less': false,
  },
}

// Extract all string literals from TS files and collect potential class names
const classNames = new Set<string>()
const stringLiteralRegex = /['"`]([^'"`]*?)['"`]/g
const validClassRegex = /^[a-z@!-][\w:/.\-[\]]*$/

const srcDir = resolve(import.meta.dir, 'src')
const glob = new Glob('**/*.ts')

for await (const file of glob.scan({ cwd: srcDir })) {
  const content = await Bun.file(resolve(srcDir, file)).text()
  let match
  // eslint-disable-next-line no-cond-assign
  while ((match = stringLiteralRegex.exec(content)) !== null) {
    const str = match[1]
    // Split space-separated class strings
    for (const token of str.split(/\s+/)) {
      if (token && validClassRegex.test(token)) {
        classNames.add(token)
      }
    }
  }
}

// Feed classes to crosswind generator
const generator = new CSSGenerator(config)
for (const cls of classNames) {
  generator.generate(cls)
}

const css = generator.toCSS(true, false)
await Bun.write(resolve(import.meta.dir, 'dist/crosswind.css'), css)

console.log(`build complete (${classNames.size} classes scanned, ${css.length} bytes CSS)`)
