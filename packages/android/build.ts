/**
 * Build script for @craft-native/android
 */

await Bun.build({
  entrypoints: ['./src/index.ts'],
  outdir: './dist',
  target: 'bun',
  format: 'esm',
  minify: false,
  sourcemap: 'external',
})

console.log('✅ Build complete')
