import { $ } from 'bun'

// Build TypeScript
await $`bun build src/index.ts --outdir dist --target bun`
await $`bun build src/cli.ts --outdir dist --target bun`

// Make CLI executable
await $`chmod +x dist/cli.js`

console.log('✅ Build complete')
