/**
 * Tiny Bun dev server for the ts-maps demo.
 *
 * Serves `src/index.html` + assets on http://localhost:3000 and bundles the
 * `.ts` entry on the fly via `Bun.build` so the browser receives a single
 * ES module with all workspace imports (e.g. `@craft-native/ts-maps`)
 * resolved. This is intentionally tiny — we don't need HMR or a production
 * bundler for a one-page demo.
 */

import { file } from 'bun'
import { extname, join, resolve } from 'node:path'
import process from 'node:process'

const root = resolve(import.meta.dir, '..')
const srcDir = join(root, 'src')

const PORT = Number(process.env.PORT ?? 3000)

const MIME: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
}

function pathFor(urlPath: string): string {
  const clean = urlPath.replace(/^\/+/, '').split('?')[0] || 'index.html'
  return join(srcDir, clean)
}

/** Bundle a TypeScript entry into a single browser-ready ES module. */
async function bundleTs(entry: string): Promise<string> {
  const result = await Bun.build({
    entrypoints: [entry],
    target: 'browser',
    format: 'esm',
    sourcemap: 'inline',
    minify: false,
  })
  if (!result.success) {
    const errs = result.logs.map(l => l.message).join('\n')
    throw new Error(`Bun.build failed:\n${errs}`)
  }
  const [out] = result.outputs
  return await out.text()
}

async function serveFile(fsPath: string): Promise<Response> {
  const ext = extname(fsPath).toLowerCase()
  const contentType = MIME[ext] ?? 'application/octet-stream'

  if (ext === '.ts') {
    try {
      const source = await bundleTs(fsPath)
      return new Response(source, {
        headers: { 'content-type': 'application/javascript; charset=utf-8' },
      })
    }
    catch (err) {
      console.error('[serve] bundle error:', err)
      return new Response(
        `/* Bundle error — see server logs */\nconsole.error(${JSON.stringify(String(err))})`,
        {
          status: 500,
          headers: { 'content-type': 'application/javascript; charset=utf-8' },
        },
      )
    }
  }

  const f = file(fsPath)
  if (!(await f.exists())) return new Response('not found', { status: 404 })
  return new Response(f, { headers: { 'content-type': contentType } })
}

const server = Bun.serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url)
    const fsPath = pathFor(url.pathname)
    try {
      return await serveFile(fsPath)
    }
    catch (err) {
      console.error('[serve] error:', err)
      return new Response('server error', { status: 500 })
    }
  },
})

console.log(`[ts-maps-demo] dev server running at http://localhost:${server.port}`)
