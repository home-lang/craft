import { mkdirSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'

/** Destination of the XCTest bundle while the native test process runs. */
export function nativeNavigationResultBundle(workspace: string, evidencePath?: string): string {
  const result = evidencePath ? resolve(evidencePath) : join(workspace, 'NativeNavigation.xcresult')
  // xcodebuild creates the bundle itself and refuses an existing destination.
  mkdirSync(dirname(result), { recursive: true })
  return result
}
