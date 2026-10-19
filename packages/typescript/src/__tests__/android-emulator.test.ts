import { expect, test } from 'bun:test'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createAndroidEmulator } from '../../../android/src/emulator'
import type { AndroidEmulatorOptions } from '../../../android/src/emulator'

function fixture(hardware: boolean, delayedSettings = false, delayedEvents = false, delayedHome = false, bootstrapHome = 'com.android.sdksetup/.DefaultActivity'): { root: string, options: AndroidEmulatorOptions } {
  const root = mkdtempSync(join(tmpdir(), 'craft emulator fixture '))
  const sdk = join(root, 'managed sdk')
  for (const directory of ['bin', 'platform-tools', 'emulator']) mkdirSync(join(sdk, directory), { recursive: true })
  const program = (name: string, body: string): string => {
    const file = join(sdk, name)
    writeFileSync(file, `#!/bin/sh\nset -eu\n${body}\n`, { mode: 0o755 })
    return file
  }
  const sdkmanager = program('bin/sdkmanager', 'printf "sdkmanager %s\\n" "$*" >> "$ANDROID_HOME/calls"')
  const avdmanager = program('bin/avdmanager', `printf "avdmanager %s\\n" "$*" >> "$ANDROID_HOME/calls"
if [ "$1" = create ]; then printf '%s' "$ANDROID_AVD_HOME" > "$ANDROID_HOME/owned"; else touch "$ANDROID_HOME/deleted"; fi`)
  program('platform-tools/adb', `if [ "$1" = devices ]; then
  printf 'List of devices attached\\n'
  if [ -f "$ANDROID_HOME/started" ]; then printf '%s\\tdevice\\n' "$ANDROID_SERIAL"; fi
else
  case "$*" in
    *'settings get global animator_duration_scale')
      if [ '${delayedSettings ? 'yes' : 'no'}' = yes ] && [ ! -f "$ANDROID_HOME/settings-ready" ]; then
        touch "$ANDROID_HOME/settings-ready"
        exit 255
      fi
      printf '1\\n' ;;
    *'pm path android') printf 'package:/system/framework/framework-res.apk\\n' ;;
    *'pidof com.android.systemui') printf '1234\\n' ;;
    *'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME')
      if [ '${delayedHome ? 'yes' : 'no'}' = yes ] && [ ! -f "$ANDROID_HOME/home-ready" ]; then
        touch "$ANDROID_HOME/home-ready"
        printf '${bootstrapHome}\\n'
      else
        printf 'com.android.launcher3/.Launcher\\n'
      fi ;;
    *'logcat -b events -d -t 1')
      if [ '${delayedEvents ? 'yes' : 'no'}' = yes ] && [ ! -f "$ANDROID_HOME/events-ready" ]; then
        touch "$ANDROID_HOME/events-ready"
        exit 255
      fi
      printf 'event stream ready\\n' ;;
    *) printf '1\\n' ;;
  esac
fi`)
  program('emulator/emulator', `if [ "$1" = -accel-check ]; then exit ${hardware ? 0 : 1}; fi
printf '%s' "$$" > "$ANDROID_HOME/emulator.pid"
printf 'emulator %s\\n' "$*" >> "$ANDROID_HOME/calls"
touch "$ANDROID_HOME/started"
trap 'exit 0' TERM INT
while :; do sleep 1; done`)
  return { root, options: {
    sdkRoot: sdk, sdkmanager, avdmanager,
    image: `system-images;android-35;google_apis_playstore;${process.arch === 'arm64' ? 'arm64-v8a' : 'x86_64'}`,
    acceleration: 'hardware', artifactsDirectory: join(root, 'artifacts'), temporaryDirectory: join(root, 'temporary'),
  } }
}

test('hardware emulation refuses unavailable acceleration before creating a device', async () => {
  const { root, options } = fixture(false)
  try {
    await expect(createAndroidEmulator(options)).rejects.toThrow('hardware acceleration is unavailable')
    expect(existsSync(join(options.sdkRoot, 'owned'))).toBe(false)
    expect(existsSync(options.sdkmanager)).toBe(true)
  }
  finally { rmSync(root, { recursive: true, force: true }) }
})

test('invalid boot budgets fail before starting tools or creating owned device data', async () => {
  const { root, options } = fixture(true)
  try {
    const modes: AndroidEmulatorOptions['acceleration'][] = process.arch === 'x64' ? ['hardware', 'software'] : ['hardware']
    for (const acceleration of modes) {
      const maximum = acceleration === 'software' ? 1_200_000 : 600_000
      for (const budget of [NaN, Infinity, -Infinity, -1, 0, 999, 1000.5, maximum + 1, Number.MAX_SAFE_INTEGER + 1]) {
        await expect(createAndroidEmulator({ ...options, acceleration, bootTimeoutMs: budget })).rejects.toThrow('bootTimeoutMs')
        expect(existsSync(join(options.sdkRoot, 'calls'))).toBe(false)
        expect(existsSync(options.temporaryDirectory!)).toBe(false)
      }
    }
  }
  finally { rmSync(root, { recursive: true, force: true }) }
})

test('boot completion alone does not admit a device before SettingsProvider is usable', async () => {
  const { root, options } = fixture(true, true)
  let session: Awaited<ReturnType<typeof createAndroidEmulator>> | undefined
  try {
    session = await createAndroidEmulator(options)
    expect(existsSync(join(options.sdkRoot, 'settings-ready'))).toBe(true)
    const identity = JSON.parse(readFileSync(join(options.artifactsDirectory, 'android-emulator.json'), 'utf8'))
    expect(identity.bootedAt).toBeString()
    expect(identity.bootTimeoutMs).toBe(600_000)
    const trace = readFileSync(join(options.artifactsDirectory, 'device-commands.jsonl'), 'utf8').trim().split('\n').map(line => JSON.parse(line))
    const readiness = trace.filter(entry => entry.args.includes('animator_duration_scale'))
    expect(readiness.map(entry => entry.code)).toEqual([255, 0])
    expect(trace.every(entry => Number.isFinite(Date.parse(entry.startedAt)) && Number.isFinite(Date.parse(entry.finishedAt)))).toBe(true)
    expect(trace.map(entry => entry.sequence)).toEqual(trace.map((_, index) => index + 1))
    expect(readdirSync(options.artifactsDirectory).sort()).toEqual(['android-emulator.json', 'device-commands.jsonl', 'emulator.log'])
  }
  finally { await session?.dispose(); rmSync(root, { recursive: true, force: true }) }
}, 10_000)

test('boot and System UI do not admit a device before its event log is readable', async () => {
  const { root, options } = fixture(true, false, true)
  let session: Awaited<ReturnType<typeof createAndroidEmulator>> | undefined
  try {
    session = await createAndroidEmulator(options)
    expect(existsSync(join(options.sdkRoot, 'events-ready'))).toBe(true)
    const trace = readFileSync(join(options.artifactsDirectory, 'device-commands.jsonl'), 'utf8').trim().split('\n').map(line => JSON.parse(line))
    const events = trace.filter(entry => entry.args.includes('logcat'))
    expect(events.map(entry => entry.code)).toEqual([255, 0])
    expect(events.every(entry => entry.args.includes('-d') && entry.args.includes('events'))).toBe(true)
    const identity = JSON.parse(readFileSync(join(options.artifactsDirectory, 'android-emulator.json'), 'utf8'))
    expect(Date.parse(events[1].finishedAt)).toBeLessThanOrEqual(Date.parse(identity.bootedAt))
  }
  finally { await session?.dispose(); rmSync(root, { recursive: true, force: true }) }
}, 10_000)

test('boot completion waits for the automatic SDK setup activity to release HOME', async () => {
  const { root, options } = fixture(true, false, false, true)
  let session: Awaited<ReturnType<typeof createAndroidEmulator>> | undefined
  try {
    session = await createAndroidEmulator(options)
    const trace = readFileSync(join(options.artifactsDirectory, 'device-commands.jsonl'), 'utf8').trim().split('\n').map(line => JSON.parse(line))
    const home = trace.filter(entry => entry.args.includes('resolve-activity'))
    expect(home.map(entry => entry.stdout.trim())).toEqual(['com.android.sdksetup/.DefaultActivity', 'com.android.launcher3/.Launcher'])
    const identity = JSON.parse(readFileSync(join(options.artifactsDirectory, 'android-emulator.json'), 'utf8'))
    expect(Date.parse(home[1].finishedAt)).toBeLessThanOrEqual(Date.parse(identity.bootedAt))
    expect(identity.bootTimeoutMs).toBe(600_000)
  }
  finally { await session?.dispose(); rmSync(root, { recursive: true, force: true }) }
}, 10_000)

test.each(['com.android.settings/.FallbackHome', 'android/com.android.internal.app.ResolverActivity'])('boot readiness rejects the temporary HOME destination %s', async (bootstrapHome) => {
  const { root, options } = fixture(true, false, false, true, bootstrapHome)
  let session: Awaited<ReturnType<typeof createAndroidEmulator>> | undefined
  try {
    session = await createAndroidEmulator(options)
    const trace = readFileSync(join(options.artifactsDirectory, 'device-commands.jsonl'), 'utf8').trim().split('\n').map(line => JSON.parse(line))
    const home = trace.filter(entry => entry.args.includes('resolve-activity'))
    expect(home.map(entry => entry.stdout.trim())).toEqual([bootstrapHome, 'com.android.launcher3/.Launcher'])
  }
  finally { await session?.dispose(); rmSync(root, { recursive: true, force: true }) }
}, 10_000)

test('the SDK process fixture records hardware mode and reaps only its owned process', async () => {
  const { root, options } = fixture(true)
  options.bootTimeoutMs = 42_000
  let session: Awaited<ReturnType<typeof createAndroidEmulator>> | undefined
  try {
    session = await createAndroidEmulator(options)
    const identity = JSON.parse(readFileSync(join(options.artifactsDirectory, 'android-emulator.json'), 'utf8'))
    expect(identity.acceleration).toBe('hardware')
    expect(identity.bootedAt).toBeString()
    expect(identity.bootTimeoutMs).toBe(42_000)
    expect(identity.bootElapsedMs).toBeGreaterThanOrEqual(0)
    expect(identity.bootElapsedMs).toBeLessThanOrEqual(identity.bootTimeoutMs)
    expect(identity.host.logicalCpus).toBeGreaterThan(0)
    expect(identity.hostCpuInterval.totalDeltaMs).toBeGreaterThanOrEqual(0)
    expect(session.serial).toBe('emulator-5558')
    expect(readFileSync(join(options.sdkRoot, 'calls'), 'utf8')).toContain('-gpu software')
    expect(readFileSync(join(options.sdkRoot, 'calls'), 'utf8')).not.toContain('swiftshader_indirect')
    const owned = readFileSync(join(options.sdkRoot, 'owned'), 'utf8')
    await session.dispose()
    await session.dispose()
    expect(existsSync(owned)).toBe(false)
    expect(existsSync(join(options.sdkRoot, 'deleted'))).toBe(true)
    expect(existsSync(options.sdkmanager)).toBe(true)
    expect(() => process.kill(identity.emulatorPid, 0)).toThrow()
  }
  finally { await session?.dispose(); rmSync(root, { recursive: true, force: true }) }
})

test('software execution is explicit and cannot be mistaken for hardware acceleration', async () => {
  const { root, options } = fixture(false)
  let session: Awaited<ReturnType<typeof createAndroidEmulator>> | undefined
  try {
    options.acceleration = 'software'
    options.bootTimeoutMs = 1_200_000
    if (process.arch !== 'x64') {
      await expect(createAndroidEmulator(options)).rejects.toThrow('requires an x86_64 host')
      return
    }
    session = await createAndroidEmulator(options)
    const identity = JSON.parse(readFileSync(join(options.artifactsDirectory, 'android-emulator.json'), 'utf8'))
    expect(identity.acceleration).toBe('software')
    expect(identity.bootTimeoutMs).toBe(1_200_000)
    expect(identity.accelerationProbeExitCode).toBe(1)
    expect(readFileSync(join(options.sdkRoot, 'calls'), 'utf8')).toContain('-accel off')
  }
  finally { await session?.dispose(); rmSync(root, { recursive: true, force: true }) }
})
