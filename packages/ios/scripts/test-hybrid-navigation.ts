import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { bootSimulator, build, init, pickSimulator } from '../src/index'
import { addSchemeTestTargets, insertProjectTargetsBeforeSchemes } from './insert-project-targets'
import { createTempDir, keepTempDir, removeTempDir } from '../../typescript/src/temp-dir'

const fixture = join(import.meta.dir, '..', 'fixtures', 'hybrid-navigation')
const stxCli = process.env.STX_CLI || resolve(import.meta.dir, '../../../../stx/packages/stx/bin/cli.ts')
const workspace = createTempDir('craft-hybrid-navigation-')
const output = join(workspace, 'HybridNavigation')
const bundle = join(workspace, 'native-screen.js')
const resultBundle = join(workspace, 'HybridNavigation.xcresult')
const prepareOnly = process.argv.includes('--prepare-only')
const testIterations = Number(process.env.CRAFT_HYBRID_NAVIGATION_ITERATIONS ?? 1)
if (!Number.isSafeInteger(testIterations) || testIterations < 1)
  throw new Error('CRAFT_HYBRID_NAVIGATION_ITERATIONS must be a positive integer')
const page = readFileSync(join(fixture, 'index.html'))
let servedRequests = 0

function servePage(body: Buffer) {
  const firstPort = 38000 + (process.pid % 1000)
  for (let offset = 0; offset < 32; offset++) {
    try {
      return Bun.serve({
        port: firstPort + offset,
        fetch: (request) => {
          servedRequests++
          console.log(`Hybrid HTTP fixture request: ${request.method} ${request.url}`)
          return new Response(body, { headers: { 'content-type': 'text/html; charset=utf-8' } })
        },
      })
    }
    catch (error) {
      if (offset === 31) throw error
    }
  }
  throw new Error('could not allocate a local hybrid fixture port')
}

const server = prepareOnly ? undefined : servePage(page)
const devServerURL = server?.url.toString() ?? 'http://127.0.0.1:38000/'

function run(args: string[], cwd: string): void {
  console.log(args.join(' '))
  const result = Bun.spawnSync(args, { cwd, stdout: 'inherit', stderr: 'inherit' })
  if (result.exitCode !== 0)
    throw new Error(`${args[0]} exited with ${result.exitCode}`)
}

async function runXcodeTests(args: string[], cwd: string, resultBundle: string): Promise<void> {
  console.log(args.join(' '))
  // Keep Bun's HTTP server responsive while the simulator requests pages.
  const result = Bun.spawn(args, { cwd, stdout: 'inherit', stderr: 'inherit' })
  const code = await result.exited
  if (code === 0) return

  if (existsSync(resultBundle)) {
    console.log('xcodebuild failed; extracting test failure details from the result bundle')
    Bun.spawnSync(
      ['xcrun', 'xcresulttool', 'get', 'test-results', 'tests', '--path', resultBundle],
      { cwd, stdout: 'inherit', stderr: 'inherit' },
    )
  }
  throw new Error(`${args[0]} exited with ${code}`)
}

function assertMutationBundle(path: string): void {
  const source = readFileSync(path, 'utf8')
  const hasSharedRuntime = source.includes('__stxNativeUnmount') || source.includes('mutationProtocolVersion')
  if (!hasSharedRuntime || !/["']MUTATE["']/.test(source))
    throw new Error('stx native compile did not emit the native mutation protocol')
}

try {
  run([
    process.execPath,
    stxCli,
    'native',
    'compile',
    'HybridNative.stx',
    '--format',
    'bundle',
    '--output',
    bundle,
  ], fixture)
  assertMutationBundle(bundle)

  await init({
    name: 'HybridNavigation',
    bundleId: 'dev.craft.hybrid-navigation',
    output,
    config: {
      renderer: 'web',
      nativeScreens: { '/native': 'HybridNative' },
      devServerURL,
      backgroundColor: '#000000',
      backgroundColorDark: '#000000',
    },
    runtimeDir: null,
  })
  await build({ output, htmlPath: fixture, nativeBundlePath: bundle, generateProject: false, runtimeDir: null })

  mkdirSync(join(output, 'UITests'))
  mkdirSync(join(output, 'UnitTests'))
  copyFileSync(join(fixture, 'HybridNavigationUITests.swift'), join(output, 'UITests', 'HybridNavigationUITests.swift'))
  copyFileSync(join(fixture, 'HybridNavigationUnitTests.swift'), join(output, 'UnitTests', 'HybridNavigationUnitTests.swift'))
  const project = join(output, 'project.yml')
  const projectWithTargets = insertProjectTargetsBeforeSchemes(readFileSync(project, 'utf8'), `
  HybridNavigationUnitTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - UnitTests
    settings:
      TEST_HOST: "$(BUILT_PRODUCTS_DIR)/HybridNavigation.app/HybridNavigation"
      BUNDLE_LOADER: "$(TEST_HOST)"
      GENERATE_INFOPLIST_FILE: YES
      PRODUCT_NAME: "$(TARGET_NAME)"
      PRODUCT_BUNDLE_IDENTIFIER: dev.craft.hybrid-navigation.tests
      SWIFT_VERSION: "5.0"
    dependencies:
      - target: HybridNavigation
  HybridNavigationUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - UITests
    settings:
      TEST_TARGET_NAME: HybridNavigation
      GENERATE_INFOPLIST_FILE: YES
      PRODUCT_NAME: "$(TARGET_NAME)"
      PRODUCT_BUNDLE_IDENTIFIER: dev.craft.hybrid-navigation.uitests
      SWIFT_VERSION: "5.0"
    dependencies:
      - target: HybridNavigation
`)
  writeFileSync(project, addSchemeTestTargets(projectWithTargets, 'HybridNavigation', ['HybridNavigationUnitTests', 'HybridNavigationUITests']))
  run(['xcodegen', 'generate'], output)

  if (prepareOnly) {
    console.log('iOS hybrid navigation fixture prepared')
  }
  else {
    const requested = process.env.CRAFT_HYBRID_NAVIGATION_SIMULATOR
    const device = requested ? { udid: requested, name: requested, state: 'Booted', runtime: 'iOS' } : await pickSimulator()
    if (!device) throw new Error('No iOS simulator is available for hybrid navigation tests')
    await bootSimulator(device)
    const selectedTest = process.env.CRAFT_HYBRID_NAVIGATION_TEST
    const selection = selectedTest
      ? [`-only-testing:HybridNavigationUITests/HybridNavigationUITests/${selectedTest}`]
      : []
    const xcodeArgs = [
      'xcodebuild', '-quiet', '-project', 'HybridNavigation.xcodeproj', '-scheme', 'HybridNavigation',
      '-configuration', 'Debug', '-destination', `id=${device.udid}`,
      '-derivedDataPath', join(workspace, 'DerivedData'),
      '-parallel-testing-enabled', 'NO', 'CODE_SIGN_IDENTITY=-', 'CODE_SIGNING_REQUIRED=NO', 'ENABLE_TESTABILITY=YES',
    ]
    run([...xcodeArgs, 'build-for-testing'], output)
    await runXcodeTests([
      ...xcodeArgs,
      ...(testIterations > 1 ? ['-test-iterations', String(testIterations)] : []),
      '-resultBundlePath', resultBundle,
      ...selection,
      'test-without-building',
    ], output, resultBundle)
    if (servedRequests === 0) throw new Error('The hybrid simulator never reached its HTTP fixture server')
    console.log(`Hybrid HTTP fixture served ${servedRequests} requests`)
    console.log('Hybrid navigation simulator tests passed')
  }
}
finally {
  console.log(`Hybrid HTTP fixture served ${servedRequests} requests`)
  if (process.env.CI && existsSync(resultBundle)) {
    const evidence = resolve('artifacts/mobile-e2e/ios-simulator/HybridNavigation.xcresult')
    cpSync(resultBundle, evidence, { recursive: true })
    console.log(`Saved hybrid Xcode result: ${evidence}`)
  }
  server?.stop()
  if (process.env.CRAFT_KEEP_HYBRID_NAVIGATION_PROJECT === '1') {
    keepTempDir(workspace)
    console.log(`Kept generated test project: ${workspace}`)
  }
  else {
    removeTempDir(workspace)
  }
}
