/**
 * Craft Hello World - Benchmark App
 *
 * Minimal Craft app for startup time measurement.
 * Uses the same HTML as Electron and Tauri versions.
 */
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { CraftApp } from '../../packages/typescript/src/index'

const html = readFileSync(join(import.meta.dir, 'hello.html'), 'utf-8')

const app = new CraftApp({
  html,
  window: {
    title: 'Hello World',
    width: 400,
    height: 300,
    resizable: false,
    devTools: false,
    hotReload: false,
  },
})

await app.show()
