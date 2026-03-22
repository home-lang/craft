import { describe, expect, test } from 'bun:test'
import { STXTransition } from '../src/transitions'

describe('transitions', () => {
  test('STXTransition has enter/leave/toggle methods', () => {
    expect(typeof STXTransition.enter).toBe('function')
    expect(typeof STXTransition.leave).toBe('function')
    expect(typeof STXTransition.toggle).toBe('function')
  })
})
