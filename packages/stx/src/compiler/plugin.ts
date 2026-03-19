/**
 * STX Bun Plugin (v2)
 *
 * Registers .stx file handling with Bun's bundler.
 * Also handles app.stx shell detection.
 *
 * Usage:
 *   import { stxPlugin } from '@craft-native/stx/compiler'
 *   Bun.plugin(stxPlugin())
 *
 * Then import .stx files directly:
 *   import App from './App.stx'
 */

import { compile } from './compile'
import type { CompileOptions } from './compile'

export interface StxPluginOptions {
  ssr?: boolean
  /** Path to app.stx shell. Auto-detected if not set. */
  shell?: string | false
}

export function stxPlugin(options: StxPluginOptions = {}) {
  return {
    name: 'stx',

    setup(build: {
      onLoad: (opts: { filter: RegExp }, cb: (args: { path: string }) => Promise<{ contents: string; loader: string }>) => void
      onResolve?: (opts: { filter: RegExp }, cb: (args: { path: string }) => { path: string } | undefined) => void
    }) {
      build.onLoad({ filter: /\.stx$/ }, async (args: { path: string }) => {
        const source = await Bun.file(args.path).text()
        const compileOpts: CompileOptions = {
          filename: args.path,
          ssr: options.ssr,
        }

        const code = compile(source, compileOpts)

        return {
          contents: code,
          loader: 'js',
        }
      })
    },
  }
}
