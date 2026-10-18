import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, resolve, sep } from 'node:path'
import { createAndroidEmulator } from '../packages/android/src/emulator'

if (process.platform !== 'linux' || process.arch !== 'x64')
  throw new Error('The software emulator verification requires a Linux x86_64 host')

const managed = realpathSync(resolve('pantry'))
function tool(name: string): string {
  const file = realpathSync(join(managed, '.bin', name))
  if (!file.startsWith(managed + sep)) throw new Error(`${name} must belong to the Pantry toolchain`)
  return file
}

const sdkmanager = tool('sdkmanager')
const avdmanager = tool('avdmanager')
const javaHome = dirname(dirname(tool('javac')))
const artifacts = resolve('artifacts/android-software-emulator')
const owned = mkdtempSync(join(tmpdir(), 'craft-emulator-source-'))
mkdirSync(artifacts, { recursive: true })
let session: Awaited<ReturnType<typeof createAndroidEmulator>> | undefined
const proof: Record<string, unknown> = { platform: process.platform, architecture: process.arch, acceleration: 'software', sdkmanager, avdmanager, javaHome }

try {
  session = await createAndroidEmulator({
    sdkRoot: join(owned, 'sdk'), sdkmanager, avdmanager,
    image: 'system-images;android-35;google_apis_playstore;x86_64',
    // The stock Play image performs real first-boot dex optimization under TCG.
    // Keep every readiness and package assertion; give this software run an explicit bound.
    acceleration: 'software', artifactsDirectory: artifacts,
    bootTimeoutMs: 20 * 60_000,
    temporaryDirectory: owned, acceptLicenses: true,
    env: { JAVA_HOME: javaHome },
  })
  async function adb(args: string[]): Promise<string> {
    const child = Bun.spawn([session!.adb, '-s', session!.serial, ...args], {
      env: session!.env, stdout: 'pipe', stderr: 'pipe', signal: AbortSignal.timeout(30_000),
    })
    const [code, stdout, stderr] = await Promise.all([child.exited, new Response(child.stdout).text(), new Response(child.stderr).text()])
    if (code !== 0) throw new Error(`ADB verification failed: ${args.join(' ')}: ${stderr}`)
    return stdout.trim()
  }
  const api = await adb(['shell', 'getprop', 'ro.build.version.sdk'])
  const abi = await adb(['shell', 'getprop', 'ro.product.cpu.abi'])
  const playStore = await adb(['shell', 'pm', 'path', 'com.android.vending'])
  if (api !== '35' || abi !== 'x86_64' || !/^package:\/\S+/.test(playStore))
    throw new Error('The owned emulator must run the requested stock Play image')
  Object.assign(proof, { serial: session.serial, api, abi, playStore, verifiedAt: new Date().toISOString() })
}
finally {
  try {
    await session?.dispose()
    const identityPath = join(artifacts, 'android-emulator.json')
    if (existsSync(identityPath)) {
      const identity = JSON.parse(readFileSync(identityPath, 'utf8'))
      if (existsSync(identity.avdDirectory)) throw new Error('The disposable AVD was not removed')
      let alive = false
      try { process.kill(identity.emulatorPid, 0); alive = true }
      catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ESRCH') throw error }
      if (alive) throw new Error('The owned emulator process was not reaped')
    }
    proof.disposed = true
  }
  finally {
    rmSync(owned, { recursive: true, force: true })
    await Bun.write(join(artifacts, 'verification.json'), JSON.stringify(proof, null, 2) + '\n')
  }
}
