import { expect, test } from 'bun:test'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createAndroidEmulator } from '../../../android/src/emulator'
import type { AndroidEmulatorOptions } from '../../../android/src/emulator'

function fixture(hardware: boolean, delayedSettings = false, delayedEvents = false): { root: string, options: AndroidEmulatorOptions } {
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

test('boot completion alone does not admit a device before SettingsProvider is usable', async () => {
  const { root, options } = fixture(true, true)
  let session: Awaited<ReturnType<typeof createAndroidEmulator>> | undefined
  try {
    session = await createAndroidEmulator(options)
    expect(existsSync(join(options.sdkRoot, 'settings-ready'))).toBe(true)
    const identity = JSON.parse(readFileSync(join(options.artifactsDirectory, 'android-emulator.json'), 'utf8'))
    expect(identity.bootedAt).toBeString()
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

test('the SDK process fixture records hardware mode and reaps only its owned process', async () => {
  const { root, options } = fixture(true)
  let session: Awaited<ReturnType<typeof createAndroidEmulator>> | undefined
  try {
    session = await createAndroidEmulator(options)
    const identity = JSON.parse(readFileSync(join(options.artifactsDirectory, 'android-emulator.json'), 'utf8'))
    expect(identity.acceleration).toBe('hardware')
    expect(identity.bootedAt).toBeString()
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
    if (process.arch !== 'x64') {
      await expect(createAndroidEmulator(options)).rejects.toThrow('requires an x86_64 host')
      return
    }
    session = await createAndroidEmulator(options)
    const identity = JSON.parse(readFileSync(join(options.artifactsDirectory, 'android-emulator.json'), 'utf8'))
    expect(identity.acceleration).toBe('software')
    expect(identity.accelerationProbeExitCode).toBe(1)
    expect(readFileSync(join(options.sdkRoot, 'calls'), 'utf8')).toContain('-accel off')
  }
  finally { await session?.dispose(); rmSync(root, { recursive: true, force: true }) }
})
