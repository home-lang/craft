/** Bun-only controls for installed-app recovery tests. Never imports into a phone bundle. */
import { access } from 'node:fs/promises'
import { join } from 'node:path'

export type MobileTestDeviceOptions =
  | { platform: 'ios', device: string, appId: string, xcrun?: string }
  | { platform: 'android', device: string, appId: string, adb?: string }

export interface MobileTestDevice {
  restart: () => Promise<void>
  installUpdate: (artifact: string) => Promise<{ previousBuild: string, build: string }>
  installedBuild: () => Promise<string>
}

/**
 * Drives an explicitly selected simulator/emulator. Restart preserves its disk;
 * update installs over the existing app, without uninstalling or clearing data.
 * Keep product assertions in the app's journey, after these OS boundaries.
 */
export function createMobileTestDevice(options: MobileTestDeviceOptions): MobileTestDevice {
  if (!/^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$/.test(options.appId)) throw new Error('An explicit app identifier is required')
  if (options.platform === 'ios' && !/^[a-f\d]{8}(?:-[a-f\d]{4}){3}-[a-f\d]{12}$/i.test(options.device)) throw new Error('An explicit iOS simulator UUID is required')
  if (options.platform === 'android' && !/^emulator-\d+$/.test(options.device)) throw new Error('An explicit Android emulator serial is required')

  async function run(args: string[], timeout = 120_000): Promise<string> {
    const child = Bun.spawn(args, { stdout: 'pipe', stderr: 'pipe' })
    const deadline = setTimeout(() => child.kill(), timeout)
    try {
      const [output, errors, code] = await Promise.all([new Response(child.stdout).text(), new Response(child.stderr).text(), child.exited])
      if (code !== 0) throw new Error(`Mobile test command failed: ${args[0]} ${args[1]} (${code})\n${errors || output}`)
      return output.trim()
    }
    finally { clearTimeout(deadline) }
  }
  const ios = (...args: string[]) => run([options.platform === 'ios' ? options.xcrun || 'xcrun' : 'xcrun', 'simctl', ...args])
  const android = (...args: string[]) => run([options.platform === 'android' ? options.adb || 'adb' : 'adb', '-s', options.device, ...args])

  async function installedBuild(): Promise<string> {
    if (options.platform === 'ios') {
      const app = await ios('get_app_container', options.device, options.appId, 'app')
      // Plists in installed bundles are binary; read through Apple's plist tool.
      return run(['/usr/libexec/PlistBuddy', '-c', 'Print :CFBundleVersion', join(app, 'Info.plist')])
    }
    const result = await android('shell', 'dumpsys', 'package', options.appId)
    const version = result.match(/\bversionCode=(\d+)/)?.[1]
    if (!version) throw new Error(`App is not installed: ${options.appId}`)
    return version
  }

  async function restart(): Promise<void> {
    if (options.platform === 'ios') {
      await ios('shutdown', options.device)
      await ios('boot', options.device)
      await ios('bootstatus', options.device, '-b')
      return
    }
    const previousBoot = await android('shell', 'cat', '/proc/sys/kernel/random/boot_id')
    await android('reboot')
    const deadline = Date.now() + 120_000
    while (Date.now() < deadline) {
      try {
        await android('wait-for-device')
        const boot = await android('shell', 'cat', '/proc/sys/kernel/random/boot_id')
        if (boot !== previousBoot && await android('shell', 'getprop', 'sys.boot_completed') === '1') {
          await android('shell', 'input', 'keyevent', '82')
          return
        }
      }
      catch { /* ADB may reconnect briefly before the new system is ready. */ }
      await Bun.sleep(500)
    }
    throw new Error('Android emulator did not complete a new boot')
  }

  async function installUpdate(artifact: string): Promise<{ previousBuild: string, build: string }> {
    const previousBuild = await installedBuild() // Refuse a fresh install masquerading as an update.
    if (options.platform === 'ios') {
      const id = await run(['/usr/libexec/PlistBuddy', '-c', 'Print :CFBundleIdentifier', join(artifact, 'Info.plist')])
      if (id !== options.appId) throw new Error('Update bundle identifier differs from the installed app')
      await ios('install', options.device, artifact)
    }
    else {
      await access(artifact) // Fail before touching the installed app when the artifact is missing.
      await android('install', '-r', artifact)
    }
    return { previousBuild, build: await installedBuild() }
  }

  return { restart, installUpdate, installedBuild }
}
