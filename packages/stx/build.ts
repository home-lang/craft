/**
 * Build script for @craft-native/stx
 */

import { cpSync } from 'node:fs'

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

// Copy crosswind CSS to dist
cpSync('./src/crosswind.css', './dist/crosswind.css')

console.log('build complete')
