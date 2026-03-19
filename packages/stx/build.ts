/**
 * Build script for @craft-native/stx
 */

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

console.log('build complete')
