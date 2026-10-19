const controlsCase = 'testPushNativeBackSwipeReplaceAndRetainedHomeState'

/** Partition every UI case; new cases automatically join the core suite. */
export function nativeNavigationGroup(source: string, group: string): string[] {
  if (group !== 'core' && group !== 'controls')
    throw new Error(`Unknown native navigation UI group: ${group}`)
  const cases = [...source.matchAll(/^\s*func\s+(test\w+)\s*\(/gm)].map(match => match[1]!)
  if (cases.length < 2 || new Set(cases).size !== cases.length || !cases.includes(controlsCase))
    throw new Error('Native navigation UI coverage must contain unique cases and the controls journey')
  const selected = cases.filter(name => group === 'controls' ? name === controlsCase : name !== controlsCase)
  if (!selected.length) throw new Error(`Empty native navigation UI group: ${group}`)
  return selected.map(name => `NativeNavigationUITests/NativeNavigationUITests/${name}`)
}

/** An ignored XCTest selector must not silently reduce required coverage. */
export function verifyNativeNavigationResults(counts: Record<string, unknown>, expectedTestCount?: number): number {
  const count = counts.totalTestCount
  if (counts.result !== 'Passed' || typeof count !== 'number' || !Number.isInteger(count) || count < 1
    || counts.passedTests !== count || counts.failedTests !== 0 || counts.skippedTests !== 0
    || (expectedTestCount !== undefined && count !== expectedTestCount))
    throw new Error(`Expected complete native navigation coverage (${expectedTestCount ?? 'nonempty'} tests): ${JSON.stringify(counts)}`)
  return count
}
