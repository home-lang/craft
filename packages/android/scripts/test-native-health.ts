import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { build, init } from '../src/index'
import { createTempDir, keepTempDir, removeTempDir } from '../../typescript/src/temp-dir'

// CraftNativeHealth against a real Health Connect: an Android 14+ emulator
// or device (Health Connect is part of the platform there) with adb on PATH.
// `--prepare-only` generates the project without running it.
const workspace = createTempDir('craft-android-native-health-')
const output = join(workspace, 'NativeHealth')
const packageName = 'dev.craft.healthtest'

function run(args: string[], cwd: string): void {
  console.log(args.join(' '))
  const result = Bun.spawnSync(args, { cwd, stdout: 'inherit', stderr: 'inherit' })
  if (result.exitCode !== 0) throw new Error(`${args[0]} exited with ${result.exitCode}`)
}

try {
  const bundle = join(workspace, 'screen.js')
  writeFileSync(bundle, 'globalThis.__stxNativeRoute = "home";')
  await init({
    name: 'NativeHealth',
    packageName,
    output,
    runtimeDir: null,
    config: {
      renderer: 'native',
      enableHealthConnect: true,
      // Every type the test reads, and the writes it makes for its own data.
      healthConnect: {
        read: ['workouts', 'steps', 'sleep', 'bodyMass', 'dietaryEnergy', 'mindful', 'heartRate'],
        write: ['workouts', 'mindful'],
      },
    },
  })
  // The fixture's own test data needs these writes too (an app would not ask
  // for them: HQ does not write steps), so they are added to the test app only.
  const manifestPath = join(output, 'app/src/main/AndroidManifest.xml')
  const extra = ['WRITE_STEPS', 'WRITE_HEART_RATE', 'WRITE_SLEEP', 'WRITE_WEIGHT', 'WRITE_NUTRITION']
    .map(permission => `    <uses-permission android:name="android.permission.health.${permission}" />`).join('\n')
  writeFileSync(manifestPath, readFileSync(manifestPath, 'utf8').replace('<uses-permission', `${extra}\n    <uses-permission`))
  await build({ output, nativeBundlePath: bundle, compile: false, runtimeDir: null })

  const testDirectory = join(output, 'app/src/androidTest/java', ...packageName.split('.'))
  mkdirSync(testDirectory, { recursive: true })
  writeFileSync(
    join(testDirectory, 'NativeHealthConnectTest.kt'),
    readFileSync(join(import.meta.dir, '../fixtures/native-health/NativeHealthConnectTest.kt'), 'utf8').replace(/\{\{PACKAGE_NAME\}\}/g, packageName),
  )

  if (!process.argv.includes('--prepare-only')) {
    try {
      run(['gradle', '--no-daemon', ':app:connectedDebugAndroidTest'], output)
    }
    catch (error) {
      run(['adb', 'logcat', '-d', '-s', 'CraftNativeHealth:V', 'TestRunner:V', 'AndroidRuntime:E'], output)
      throw error
    }
  }
  console.log(process.argv.includes('--prepare-only') ? 'Android Health Connect fixture prepared' : 'Android Health Connect test passed')
}
finally {
  if (process.env.CRAFT_KEEP_ANDROID_NATIVE_PROJECT === '1') {
    keepTempDir(workspace)
    console.log(`Kept generated test project: ${workspace}`)
  }
  else {
    removeTempDir(workspace)
  }
}
