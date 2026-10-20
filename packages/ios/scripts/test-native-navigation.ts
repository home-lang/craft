import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { bootSimulator, build, init, pickSimulator } from '../src/index'
import { addSchemeTestTargets, insertProjectTargetsBeforeSchemes } from './insert-project-targets'
import { nativeNavigationGroup, verifyNativeNavigationResults } from './native-navigation-groups'
import { nativeNavigationResultBundle } from './native-navigation-result'
import { createTempDir, keepTempDir, removeTempDir } from '../../typescript/src/temp-dir'

const fixture = join(import.meta.dir, '..', 'fixtures', 'native-navigation')
// The @stacksjs/stx CLI (`stx native compile`), from a sibling checkout unless CI pins one.
const stxCli = process.env.STX_CLI || resolve(import.meta.dir, '../../../../stx/packages/stx/bin/cli.ts')
const workspace = createTempDir('craft-native-navigation-')
const output = join(workspace, 'NativeNavigation')
const bundle = join(workspace, 'routes.js')
const prepareOnly = process.argv.includes('--prepare-only')

function run(args: string[], cwd: string): void {
  console.log(args.join(' '))
  const result = Bun.spawnSync(args, { cwd, stdout: 'inherit', stderr: 'inherit' })
  if (result.exitCode !== 0)
    throw new Error(`${args[0]} exited with ${result.exitCode}`)
}

function runXcodeTests(args: string[], cwd: string, resultBundle: string, expectedTestCount?: number): void {
  console.log(args.join(' '))
  const result = Bun.spawnSync(args, { cwd, stdout: 'inherit', stderr: 'inherit' })
  const evidence = process.env.CRAFT_NATIVE_NAVIGATION_RESULT
  if (result.exitCode === 0) {
    const summary = Bun.spawnSync(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', resultBundle], { stdout: 'pipe', stderr: 'pipe' })
    if (summary.exitCode !== 0) throw new Error(`Could not read XCTest results: ${summary.stderr.toString()}`)
    const counts = JSON.parse(summary.stdout.toString())
    if (evidence) writeFileSync(`${resolve(evidence)}.summary.json`, summary.stdout)
    verifyNativeNavigationResults(counts, expectedTestCount)
    console.log(`XCTest verified ${counts.passedTests} passed tests, zero failures and skips`)
    return
  }

  if (existsSync(resultBundle)) {
    console.log('xcodebuild failed; extracting test failure details from the result bundle')
    Bun.spawnSync(
      ['xcrun', 'xcresulttool', 'get', 'test-results', 'tests', '--path', resultBundle],
      { cwd, stdout: 'inherit', stderr: 'inherit' },
    )
  }
  throw new Error(`${args[0]} exited with ${result.exitCode}`)
}

function assertMutationBundle(path: string): void {
  const source = readFileSync(path, 'utf8')
  const hasSharedRuntime = source.includes('__stxNativeUnmount') || source.includes('mutationProtocolVersion')
  if (!hasSharedRuntime || !/["']MUTATE["']/.test(source))
    throw new Error('stx native compile did not emit the native mutation protocol')
}

try {
  run([process.execPath, stxCli, 'native', 'compile', '--format', 'bundle', '--output', bundle], fixture)
  assertMutationBundle(bundle)
  await init({
    name: 'NativeNavigation',
    bundleId: 'dev.craft.native-navigation',
    output,
    config: {
      renderer: 'native',
      nativeScreens: {
        '/': 'home',
        '/identity': 'identity',
        '/details': 'details',
        '/linked-details': 'details',
        '/guarded': 'details',
        '/summary': 'summary',
        '/capabilities': 'capabilities',
        '/third': 'summary',
        '/fourth': 'details',
        '/fifth': 'summary',
      },
      tabs: [
        { id: '/', title: 'Home', symbol: 'house' },
        { id: '/details', title: 'Details', symbol: 'doc.text' },
        { id: '/third', title: 'Third', symbol: 'chart.bar' },
        { id: '/fourth', title: 'Fourth', symbol: 'heart' },
        { id: '/fifth', title: 'Fifth', symbol: 'person' },
      ],
      enableDeepLinks: true,
      enableLocalDatabase: true,
      enableLocalNotifications: true,
      enableSecureStorage: true,
      enableBiometric: true,
      urlSchemes: ['craft-native-test'],
    },
    runtimeDir: null,
  })
  await build({ output, nativeBundlePath: bundle, generateProject: false, runtimeDir: null })

  mkdirSync(join(output, 'UnitTests'))
  copyFileSync(join(fixture, 'NativeNavigationUnitTests.swift'), join(output, 'UnitTests', 'NativeNavigationUnitTests.swift'))
  mkdirSync(join(output, 'UITests'))
  copyFileSync(join(fixture, 'NativeNavigationUITests.swift'), join(output, 'UITests', 'NativeNavigationUITests.swift'))
  const project = join(output, 'project.yml')
  const projectWithTargets = insertProjectTargetsBeforeSchemes(readFileSync(project, 'utf8'), `
  NativeNavigationUnitTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - UnitTests
    settings:
      GENERATE_INFOPLIST_FILE: YES
      PRODUCT_NAME: "$(TARGET_NAME)"
      PRODUCT_BUNDLE_IDENTIFIER: dev.craft.native-navigation.unit-tests
      SWIFT_VERSION: "5.0"
      TEST_HOST: "$(BUILT_PRODUCTS_DIR)/NativeNavigation.app/NativeNavigation"
      BUNDLE_LOADER: "$(TEST_HOST)"
    dependencies:
      - target: NativeNavigation
  NativeNavigationUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - UITests
    settings:
      GENERATE_INFOPLIST_FILE: YES
      PRODUCT_NAME: "$(TARGET_NAME)"
      PRODUCT_BUNDLE_IDENTIFIER: dev.craft.native-navigation.ui-tests
      SWIFT_VERSION: "5.0"
    dependencies:
      - target: NativeNavigation
`)
  writeFileSync(project, addSchemeTestTargets(projectWithTargets, 'NativeNavigation', ['NativeNavigationUnitTests', 'NativeNavigationUITests']))
  run(['xcodegen', 'generate'], output)

  if (prepareOnly) {
    console.log('iOS native navigation fixture prepared')
  }
  else {
    const requested = process.env.CRAFT_NATIVE_NAVIGATION_SIMULATOR
    const device = requested ? { udid: requested, name: requested, state: 'Booted', runtime: 'iOS' } : await pickSimulator()
    if (!device) throw new Error('No iOS simulator is available for native navigation tests')
    await bootSimulator(device)
    // Write directly into retained evidence: a CI cancellation can terminate
    // this process before any post-test copy or finally block can run.
    const resultBundle = nativeNavigationResultBundle(workspace, process.env.CRAFT_NATIVE_NAVIGATION_RESULT)
    const selectedTest = process.env.CRAFT_NATIVE_NAVIGATION_TEST
    const selectedTarget = process.env.CRAFT_ONLY_TESTING
    const group = process.env.CRAFT_NATIVE_NAVIGATION_GROUP
    if (group && (selectedTarget || selectedTest)) throw new Error('A required native UI group cannot be combined with focused selectors')
    const groupCases = group ? nativeNavigationGroup(readFileSync(join(fixture, 'NativeNavigationUITests.swift'), 'utf8'), group) : undefined
    const selection = groupCases ? groupCases.map(target => `-only-testing:${target}`) : selectedTarget ? selectedTarget.split(',').map(target => target.trim()).filter(Boolean).map(target => `-only-testing:${target}`) : selectedTest
      ? [`-only-testing:NativeNavigationUITests/NativeNavigationUITests/${selectedTest}`]
      : []
    const xcodeArgs = [
      'xcodebuild', '-quiet', '-project', 'NativeNavigation.xcodeproj', '-scheme', 'NativeNavigation',
      '-configuration', 'Debug', '-destination', `id=${device.udid}`,
      '-derivedDataPath', join(workspace, 'DerivedData'),
      '-parallel-testing-enabled', 'NO', 'CODE_SIGN_IDENTITY=-', 'CODE_SIGNING_REQUIRED=NO', 'ENABLE_TESTABILITY=YES',
    ]
    // Separate build and test sessions: the combined action can stall before
    // launching a hosted XCTest bundle, even after compilation has finished.
    run([...xcodeArgs, 'build-for-testing'], output)
    runXcodeTests([
      // Retain live XCTest activity as well as the structured result bundle.
      ...xcodeArgs.filter(arg => arg !== '-quiet'),
      '-resultBundlePath', resultBundle,
      ...selection,
      'test-without-building',
    ], output, resultBundle, groupCases?.length)
    console.log('Native navigation simulator tests passed')
  }
}
finally {
  if (process.env.CRAFT_KEEP_NATIVE_NAVIGATION_PROJECT === '1') {
    keepTempDir(workspace)
    console.log(`Kept generated test project: ${workspace}`)
  }
  else {
    removeTempDir(workspace)
  }
}
