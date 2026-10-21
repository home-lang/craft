import { describe, expect, it } from 'bun:test'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

/*
 * The screens' JavaScript shares one serial script thread, so a screen in
 * front can wait behind hidden tabs reloading after a sign-in. With frame
 * pacing on (CRAFT_FRAME_PACING=1), each piece of that work says how long it
 * waited and how long it ran, which is how the two are told apart.
 */
const templates = join(import.meta.dir, '../templates')
const screen = readFileSync(join(templates, 'CraftNativeScreen.swift'), 'utf8')
const hybrid = readFileSync(join(templates, 'CraftHybrid.swift'), 'utf8')

describe('script thread trace', () => {
  it('times queue wait apart from run time, only when frame pacing is on', () => {
    expect(screen).toContain('static func run(label: @autoclosure @escaping () -> String = "script", _ work: @escaping () -> Void) {')
    expect(screen).toContain('guard pacing.enabled else {')
    expect(screen).toContain('let waited = started - queued')
    expect(hybrid).toContain('func scriptWork(_ name: String, waited: CFTimeInterval, ran: CFTimeInterval) {')
    expect(hybrid).toContain('"script %@ waited=%.1fms ran=%.1fms"')
  })

  it('names what ran and for which screen', () => {
    for (const label of ['"mount \\(name)"', '"frame \\(route)"', '"params \\(route)"', '"unmount \\(route)"', '"\\(type) \\(route)"'])
      expect(screen).toContain(`CraftNativeScriptThread.run(label: ${label})`)
  })
})
