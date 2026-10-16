import { expect, test } from 'bun:test'
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

test.skipIf(process.platform !== 'darwin')('the Swift launch state waits for intent and never promotes a warm link to the initial URL', async () => {
  const template = readFileSync(join(import.meta.dir, '../templates/CraftApp.swift'), 'utf8')
  const state = template.slice(template.indexOf('final class CraftInitialLinkState {'), template.indexOf('\nclass DeepLinkManager {'))
  const root = mkdtempSync(join(tmpdir(), 'craft-launch-link-state-'))
  try {
    const source = join(root, 'main.swift')
    writeFileSync(source, `import Foundation\n${state}\n
let cold = CraftInitialLinkState()
var coldAnswers: [URL?] = []
cold.resolve { coldAnswers.append($0) }
cold.resolve { coldAnswers.append($0) }
assert(coldAnswers.isEmpty, "reading before UIKit's launch intent must wait")
let first = URL(string: "https://hq.training/diego-ruiz")!
cold.receive(first)
assert(coldAnswers == [first, first])
cold.receive(URL(string: "https://hq.training/pawel")!)
cold.settle()
assert(cold.url == first && coldAnswers.count == 2)
cold.resolve { assert($0 == first) }
let ordinary = CraftInitialLinkState()
var noURLAnswers: [URL?] = []
ordinary.resolve { noURLAnswers.append($0) }
ordinary.settle()
ordinary.receive(first)
ordinary.resolve { noURLAnswers.append($0) }
assert(ordinary.url == nil && noURLAnswers.count == 2 && noURLAnswers.allSatisfy { $0 == nil })
print("launch-link-state OK")
`)
    const child = Bun.spawn(['swift', source], { stdout: 'pipe', stderr: 'pipe' })
    const [status, stdout, stderr] = await Promise.all([child.exited, new Response(child.stdout).text(), new Response(child.stderr).text()])
    expect(status, stderr).toBe(0)
    expect(stdout).toContain('launch-link-state OK')
  }
  finally { rmSync(root, { recursive: true, force: true }) }
}, 30_000)
