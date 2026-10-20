import { describe, expect, test } from 'bun:test'
import { decide, type Run, type RunJob } from './release-acceptance'

const sha = 'a'.repeat(40)
const run = (overrides: Partial<Run> = {}): Run => ({ id: 10, status: 'completed', conclusion: 'success', event: 'push', head_branch: 'main', head_sha: sha, ...overrides })
const job = (name: string, conclusion: string | null, status = conclusion === null ? 'in_progress' : 'completed'): RunJob => ({ name, status, conclusion })

describe('reusing Main\'s acceptance of a release commit', () => {
  test('reuses a successful push run on the exact commit', () => {
    expect(decide(sha, [run()], [job('lint', 'success')], true)).toEqual({ kind: 'reused', run: 10 })
  })

  test('waits while the run is queued or in progress', () => {
    expect(decide(sha, [run({ status: 'in_progress', conclusion: null })], [job('lint', 'success'), job('ios', null)], true).kind).toBe('wait')
    expect(decide(sha, [run({ status: 'queued', conclusion: null })], [], true).kind).toBe('wait')
  })

  test('fails as soon as any job fails, before the slowest leg finishes', () => {
    expect(decide(sha, [run({ status: 'in_progress', conclusion: null })], [job('windows-multi-window', 'failure'), job('ios', null)], false))
      .toEqual({ kind: 'failed', run: 10, jobs: ['windows-multi-window'] })
    expect(decide(sha, [run({ conclusion: 'failure' })], [], true)).toEqual({ kind: 'failed', run: 10, jobs: [] })
    expect(decide(sha, [run({ status: 'in_progress', conclusion: null })], [job('ios', 'timed_out')], true).kind).toBe('failed')
  })

  test('runs the suite itself when there is nothing finished to reuse', () => {
    // A newer commit replaced the release commit's pending run.
    expect(decide(sha, [run({ conclusion: 'cancelled' })], [job('lint', 'cancelled')], true).kind).toBe('run')
    // Main never ran this workflow on the commit (a path filter, a lone tag).
    expect(decide(sha, [], [], true).kind).toBe('run')
  })

  test('waits for the run to be created before deciding there is none', () => {
    expect(decide(sha, [], [], false).kind).toBe('wait')
  })

  test('only Main\'s push runs of the exact commit count', () => {
    for (const other of [run({ head_sha: 'b'.repeat(40) }), run({ event: 'pull_request' }), run({ head_branch: 'feature' }), run({ event: 'workflow_dispatch' })])
      expect(decide(sha, [other], [], true).kind).toBe('run')
  })

  test('the newest of several runs on the commit decides', () => {
    expect(decide(sha, [run({ id: 9, conclusion: 'failure' }), run({ id: 11 })], [], true)).toEqual({ kind: 'reused', run: 11 })
  })
})
