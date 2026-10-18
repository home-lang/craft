import { dirname, join, resolve } from 'node:path'
import { createAndroidEmulator } from '../packages/android/src/emulator'

// The SDK owns startup and disposal; acceptance still requires a responsive
// native launcher and rejects every platform ANR/crash before and after tests.
const api = process.env.CRAFT_ANDROID_NATIVE_API
if (!['34', '35'].includes(api ?? '')) throw new Error('Select a maintained Android native acceptance API: 34 or 35')
if (!process.env.CRAFT_NATIVE_TEST_PROJECT) throw new Error('Compile the native fixture before booting Android')
const sdkRoot = process.env.ANDROID_HOME ?? process.env.ANDROID_SDK_ROOT
const sdkmanager = Bun.which('sdkmanager')
const avdmanager = Bun.which('avdmanager')
if (!sdkRoot || !sdkmanager || !avdmanager) throw new Error('Install the normal Android SDK command-line tools first')
const abi = process.arch === 'arm64' ? 'arm64-v8a' : 'x86_64'
const session = await createAndroidEmulator({
  sdkRoot, sdkmanager, avdmanager, image: `system-images;android-${api};default;${abi}`,
  acceleration: 'hardware', acceptLicenses: true,
  artifactsDirectory: resolve('artifacts/android-navigation/emulator'),
})
try {
  const test = Bun.spawn(['bash', '-x', 'packages/android/scripts/run-native-navigation-device.sh'], {
    env: { ...session.env, PATH: `${dirname(session.adb)}:${session.env.PATH ?? ''}` },
    stdout: 'inherit', stderr: 'inherit',
  })
  const code = await test.exited
  if (code !== 0) {
    // Retain the owned device state before disposal, including failures before
    // Gradle/instrumentation produces any JUnit result. Diagnostic failure must
    // not replace the original acceptance exit or turn it into a pass.
    for (const [name, args] of [
      ['device-state', ['get-state']],
      ['platform-events', ['logcat', '-b', 'events', '-d', '-v', 'threadtime']],
      ['platform-properties', ['shell', 'getprop']],
    ] as const) {
      try {
        const diagnostic = Bun.spawn([session.adb, '-s', session.serial, ...args], {
          env: session.env, stdout: 'pipe', stderr: 'pipe', signal: AbortSignal.timeout(10_000),
        })
        const [status, stdout, stderr] = await Promise.all([diagnostic.exited, new Response(diagnostic.stdout).text(), new Response(diagnostic.stderr).text()])
        await Bun.write(join('artifacts/android-navigation', `failure-${name}.json`), JSON.stringify({ status, stdout, stderr }, null, 2) + '\n')
      }
      catch (error) { console.error(`Could not retain Android ${name}: ${error}`) }
    }
    throw new Error(`Native Android acceptance failed with exit ${code}`)
  }
}
finally {
  await session.dispose()
}
