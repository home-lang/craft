import { expect, test } from 'bun:test'
import { metalXCTestSteps } from './metal-xctest-steps'

test('Metal compilation and execution get separate command deadlines while reusing the built tests', () => {
  const [build, execute] = metalXCTestSteps('owned-simulator', '/owned/DerivedData', '/evidence/TestResults.xcresult')
  expect(build.name).not.toBe(execute.name)
  expect(build.args.at(-1)).toBe('build-for-testing')
  expect(execute.args.at(-1)).toBe('test-without-building')
  expect(build.args).not.toContain('test')
  expect(build.args).not.toContain('-resultBundlePath')
  expect(execute.args.slice(-3)).toEqual(['-resultBundlePath', '/evidence/TestResults.xcresult', 'test-without-building'])
  for (const step of [build, execute]) {
    expect(step.args[step.args.indexOf('-destination') + 1]).toBe('platform=iOS Simulator,id=owned-simulator')
    expect(step.args[step.args.indexOf('-derivedDataPath') + 1]).toBe('/owned/DerivedData')
    expect(step.args[step.args.indexOf('-parallel-testing-enabled') + 1]).toBe('NO')
    expect(step.timeoutMs).toBe(300_000)
  }
})
