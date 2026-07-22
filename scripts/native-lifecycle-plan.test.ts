import { describe, expect, test } from 'bun:test'
import { macOSRollbackPlan } from './native-lifecycle-plan'

describe('native lifecycle plans', () => {
  test('macOS rollback removes the newer payload and receipt before reinstalling', () => {
    expect(macOSRollbackPlan('/Applications/app.app', 'dev.craft.app', '/tmp/app-1.0.0.pkg')).toEqual([
      { name: 'remove current application before rollback', argv: ['sudo', 'rm', '-rf', '/Applications/app.app'] },
      { name: 'forget current receipt before rollback', argv: ['sudo', 'pkgutil', '--forget', 'dev.craft.app'] },
      { name: 'rollback to v1', argv: ['sudo', 'installer', '-pkg', '/tmp/app-1.0.0.pkg', '-target', '/'] },
    ])
  })
})
