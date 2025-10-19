import { dts } from 'bun-plugin-dtsx'

await Bun.build({
  entrypoints: ['bin/cli.ts'],
  outdir: './dist',
  minify: true,
  target: 'node',
  plugins: [dts()],
})
