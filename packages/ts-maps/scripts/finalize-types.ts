#!/usr/bin/env bun
import { cpSync, existsSync, readdirSync, rmSync, statSync } from 'node:fs'
import { join } from 'node:path'

// tsc derives rootDir from the common ancestor of every file it compiles, and
// this package deliberately imports a few modules straight out of
// ../typescript/src (see MapView.ts and FilesystemTileBackend.ts). That pushes
// the ancestor up to `packages/`, so the declarations land in a nested tree
// rather than in dist/ — and exactly how deep that tree is depends on where the
// checkout happens to live.
//
// So find it rather than assume it. The previous version of this script looked
// for `dist/Tools/craft/packages/ts-maps/src`, which existed only on the
// machine it was written on and failed everywhere else, CI included.

const DIST = 'dist'

/** The emitted declarations for *this* package: a `.../ts-maps/src` holding index.d.ts. */
function findDeclarationRoot(dir: string): string | null {
  if (dir.endsWith(join('ts-maps', 'src')) && existsSync(join(dir, 'index.d.ts')))
    return dir

  for (const entry of readdirSync(dir)) {
    const child = join(dir, entry)
    if (!statSync(child).isDirectory())
      continue
    const found = findDeclarationRoot(child)
    if (found)
      return found
  }
  return null
}

// Nothing to flatten if tsc already emitted at the top level — which is what
// happens the moment those cross-package imports go away.
if (!existsSync(join(DIST, 'index.d.ts'))) {
  const declarations = findDeclarationRoot(DIST)
  if (!declarations)
    throw new Error(`No TypeScript declarations found anywhere under ${DIST}/`)

  // Every top-level directory here is part of the nested emit: the bundler
  // writes only files to dist/. Capture them before the copy adds more.
  const nested = readdirSync(DIST).filter(entry => statSync(join(DIST, entry)).isDirectory())

  cpSync(declarations, DIST, { recursive: true })
  for (const dir of nested) rmSync(join(DIST, dir), { recursive: true, force: true })
}
