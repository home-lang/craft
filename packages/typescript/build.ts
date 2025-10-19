import { dts } from 'bun-plugin-dtsx'

await Bun.build({
  entrypoints: ['src/index.ts', 'bin/cli.ts'],
  outdir: './dist',
  splitting: true,
  minify: true,
  target: 'node',
  plugins: [dts()],
})
