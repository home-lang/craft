/**
 * Reuse Main's own acceptance of a release commit instead of running it again.
 *
 * `release:patch` pushes the release commit to main together with its tag.
 * Main then runs CI and Mobile E2E on that commit, and the tag's Releaser used
 * to call both workflows again on the very same SHA: every release ran the
 * whole macOS-heavy suite twice at once, the two copies queueing for the same
 * runners. A release took two hours and more of wall clock before it could
 * publish.
 *
 * So the release waits for Main's push run of the workflow on its exact SHA
 * and reuses its verdict. The guarantee does not change: the same workflow
 * file, at the same commit, ran to completion. It answers:
 *
 * - `reused=true` once that run succeeded;
 * - a failure as soon as any of its jobs fails, naming them, rather than
 *   after the slowest leg finishes;
 * - `reused=false` when there is no run to reuse - Main never ran the
 *   workflow on this commit (a path filter, a tag pushed on its own) or a
 *   newer commit superseded the pending run - and the release then runs the
 *   suite itself, as it always did.
 */
import { appendFileSync } from 'node:fs'
import process from 'node:process'

export interface Run {
  id: number
  status: string
  conclusion: string | null
  event: string
  head_branch: string | null
  head_sha: string
  run_attempt?: number
}

export interface RunJob {
  name: string
  status: string
  conclusion: string | null
}

export type Decision =
  | { kind: 'wait', reason: string }
  | { kind: 'reused', run: number }
  | { kind: 'run', reason: string }
  | { kind: 'failed', run: number, jobs: string[] }

const FAILED = new Set(['failure', 'timed_out', 'startup_failure'])

/**
 * What to do about one workflow on `sha`, given its push runs on main and the
 * latest attempt's jobs of the newest one. `appeared` is false until runs for
 * the commit have had time to be created.
 */
export function decide(sha: string, runs: Run[], jobs: RunJob[], appeared: boolean): Decision {
  const own = runs
    .filter(run => run.head_sha === sha && run.event === 'push' && run.head_branch === 'main')
    .sort((a, b) => b.id - a.id)
  const run = own[0]
  if (!run) return appeared ? { kind: 'run', reason: 'Main has no push run of this workflow on the release commit' } : { kind: 'wait', reason: 'waiting for Main\'s push run to be created' }
  const failed = jobs.filter(job => job.conclusion !== null && FAILED.has(job.conclusion)).map(job => job.name)
  if (failed.length) return { kind: 'failed', run: run.id, jobs: failed }
  if (run.status !== 'completed') return { kind: 'wait', reason: `Main's run ${run.id} is ${run.status}` }
  if (run.conclusion === 'success') return { kind: 'reused', run: run.id }
  if (run.conclusion !== null && FAILED.has(run.conclusion)) return { kind: 'failed', run: run.id, jobs: [] }
  // Cancelled, skipped or neutral: nothing finished to reuse.
  return { kind: 'run', reason: `Main's run ${run.id} ended ${run.conclusion ?? 'without a conclusion'}` }
}

async function github<T>(path: string): Promise<T> {
  const response = await fetch(`https://api.github.com${path}`, {
    headers: {
      'Accept': 'application/vnd.github+json',
      'Authorization': `Bearer ${process.env.GH_TOKEN}`,
      'X-GitHub-Api-Version': '2022-11-28',
    },
    signal: AbortSignal.timeout(30_000),
  })
  if (!response.ok) throw new Error(`GitHub ${path} answered ${response.status}: ${await response.text()}`)
  return await response.json() as T
}

async function main(): Promise<void> {
  const workflow = process.argv[2]
  const sha = process.env.RELEASE_SHA
  const repo = process.env.GITHUB_REPOSITORY
  if (!workflow || !sha || !repo || !process.env.GH_TOKEN) throw new Error('Usage: RELEASE_SHA=… GITHUB_REPOSITORY=… GH_TOKEN=… bun scripts/release-acceptance.ts <workflow file>')
  const output = (name: string, value: string): void => {
    if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, `${name}=${value}\n`)
  }
  // A push run is created within seconds of the push; three minutes covers a
  // slow API without making the fallback wait long for a run that never comes.
  const appearBy = Date.now() + 3 * 60_000
  let last = ''
  while (true) {
    const { workflow_runs: runs } = await github<{ workflow_runs: Run[] }>(`/repos/${repo}/actions/workflows/${workflow}/runs?head_sha=${sha}&event=push&branch=main&per_page=20`)
    const newest = runs.filter(run => run.head_sha === sha && run.event === 'push').sort((a, b) => b.id - a.id)[0]
    const jobs = newest
      ? (await github<{ jobs: RunJob[] }>(`/repos/${repo}/actions/runs/${newest.id}/attempts/${newest.run_attempt ?? 1}/jobs?per_page=100`)).jobs
      : []
    const decision = decide(sha, runs, jobs, Date.now() > appearBy)
    if (decision.kind === 'wait') {
      if (decision.reason !== last) console.log(decision.reason)
      last = decision.reason
      await Bun.sleep(60_000)
      continue
    }
    if (decision.kind === 'reused') {
      console.log(`Reusing Main's successful run ${decision.run} of ${workflow} on ${sha}: https://github.com/${repo}/actions/runs/${decision.run}`)
      output('reused', 'true')
      return
    }
    if (decision.kind === 'run') {
      console.log(`${decision.reason}; the release runs ${workflow} itself.`)
      output('reused', 'false')
      return
    }
    throw new Error(`Main's run ${decision.run} of ${workflow} on ${sha} failed${decision.jobs.length ? `: ${decision.jobs.join(', ')}` : ''}. Re-run its failed jobs (https://github.com/${repo}/actions/runs/${decision.run}), then this job.`)
  }
}

if (import.meta.main) await main()
