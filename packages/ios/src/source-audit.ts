import { readdirSync } from 'node:fs'
import { join, relative, sep } from 'node:path'

export interface SwiftSourceAuditOptions {
  /** Paths, relative to `root`, that are generated or otherwise owned by Craft. */
  ignoredPaths?: readonly string[]
}

const defaultIgnoredPaths = [
  '.git',
  'node_modules',
  'dist',
  'build',
  'storage/framework/mobile',
]

function normalisePath(path: string): string {
  return path.split(sep).join('/')
}

function isIgnored(path: string, ignoredPaths: readonly string[]): boolean {
  const normalised = normalisePath(path)
  return ignoredPaths.some((ignored) => {
    const prefix = normalisePath(ignored).replace(/\/+$/, '')
    return normalised === prefix || normalised.startsWith(`${prefix}/`)
  })
}

function visit(root: string, current: string, ignoredPaths: readonly string[], found: string[]): void {
  for (const entry of readdirSync(current, { withFileTypes: true })) {
    const absolute = join(current, entry.name)
    const relativePath = relative(root, absolute)
    if (isIgnored(relativePath, ignoredPaths)) continue
    if (entry.isDirectory()) {
      visit(root, absolute, ignoredPaths, found)
      continue
    }
    if (entry.isFile() && entry.name.endsWith('.swift')) found.push(normalisePath(relativePath))
  }
}

/** Return Swift files owned by an application rather than Craft's generated shell. */
export function findApplicationSwiftSources(root: string, options: SwiftSourceAuditOptions = {}): string[] {
  const ignoredPaths = [...defaultIgnoredPaths, ...(options.ignoredPaths ?? [])]
  const found: string[] = []
  visit(root, root, ignoredPaths, found)
  return found.sort()
}

/** Fail a build when an application has started maintaining its own Swift source. */
export function assertNoApplicationSwiftSources(root: string, options: SwiftSourceAuditOptions = {}): void {
  const sources = findApplicationSwiftSources(root, options)
  if (sources.length > 0) {
    throw new Error(`Application-owned Swift sources found:\n${sources.map(path => `- ${path}`).join('\n')}`)
  }
}
