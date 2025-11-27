/**
 * Craft Code Signing & Notarization
 * Sign and notarize applications for all platforms
 */

import { execSync, exec } from 'child_process'
import { existsSync, readFileSync, writeFileSync } from 'fs'
import { join, basename } from 'path'
import { promisify } from 'util'

const execAsync = promisify(exec)

// Types
export interface SigningConfig {
  platform: 'macos' | 'windows' | 'linux'
  identity?: string // macOS: signing identity
  certificate?: string // Windows: path to .pfx certificate
  password?: string // Certificate password
  timestampServer?: string
  entitlements?: string // macOS: path to entitlements file
  hardened?: boolean // macOS: enable hardened runtime
}

export interface NotarizationConfig {
  appleId: string
  teamId: string
  password: string // App-specific password
  bundleId: string
}

export interface SigningResult {
  success: boolean
  path: string
  signature?: string
  errors?: string[]
}

// Code Signer
export class CodeSigner {
  private config: SigningConfig

  constructor(config: SigningConfig) {
    this.config = config
  }

  /**
   * Sign an application or binary
   */
  async sign(path: string): Promise<SigningResult> {
    if (!existsSync(path)) {
      return { success: false, path, errors: [`File not found: ${path}`] }
    }

    switch (this.config.platform) {
      case 'macos':
        return this.signMacOS(path)
      case 'windows':
        return this.signWindows(path)
      case 'linux':
        return this.signLinux(path)
      default:
        return { success: false, path, errors: ['Unsupported platform'] }
    }
  }

  private async signMacOS(path: string): Promise<SigningResult> {
    const identity = this.config.identity || '-'
    const entitlements = this.config.entitlements
    const hardened = this.config.hardened !== false

    try {
      // Build codesign command
      const args = ['codesign', '--force', '--sign', `"${identity}"`]

      if (hardened) {
        args.push('--options', 'runtime')
      }

      if (entitlements && existsSync(entitlements)) {
        args.push('--entitlements', `"${entitlements}"`)
      }

      args.push('--deep', `"${path}"`)

      const command = args.join(' ')
      console.log(`Signing: ${basename(path)}`)

      await execAsync(command)

      // Verify signature
      const verifyResult = await execAsync(`codesign --verify --verbose "${path}"`)

      return {
        success: true,
        path,
        signature: identity,
      }
    } catch (error: any) {
      return {
        success: false,
        path,
        errors: [error.message || 'Signing failed'],
      }
    }
  }

  private async signWindows(path: string): Promise<SigningResult> {
    const certificate = this.config.certificate
    const password = this.config.password
    const timestampServer = this.config.timestampServer || 'http://timestamp.digicert.com'

    if (!certificate) {
      return { success: false, path, errors: ['Certificate path is required for Windows signing'] }
    }

    try {
      // Try signtool first (Windows SDK)
      const args = [
        'signtool',
        'sign',
        '/f',
        `"${certificate}"`,
        password ? `/p "${password}"` : '',
        '/t',
        timestampServer,
        '/fd',
        'SHA256',
        `"${path}"`,
      ].filter(Boolean)

      const command = args.join(' ')
      console.log(`Signing: ${basename(path)}`)

      await execAsync(command)

      return {
        success: true,
        path,
        signature: certificate,
      }
    } catch (error: any) {
      // Try osslsigncode as fallback (cross-platform)
      try {
        const args = [
          'osslsigncode',
          'sign',
          '-pkcs12',
          `"${certificate}"`,
          password ? `-pass "${password}"` : '',
          '-t',
          timestampServer,
          '-h',
          'sha256',
          '-in',
          `"${path}"`,
          '-out',
          `"${path}.signed"`,
        ].filter(Boolean)

        await execAsync(args.join(' '))
        execSync(`mv "${path}.signed" "${path}"`)

        return {
          success: true,
          path,
          signature: certificate,
        }
      } catch (fallbackError: any) {
        return {
          success: false,
          path,
          errors: [error.message || 'Signing failed', fallbackError.message],
        }
      }
    }
  }

  private async signLinux(path: string): Promise<SigningResult> {
    // Linux uses GPG signatures
    try {
      const signatureFile = `${path}.sig`

      // Sign with GPG
      await execAsync(`gpg --detach-sign --armor -o "${signatureFile}" "${path}"`)

      console.log(`Signed: ${basename(path)} -> ${basename(signatureFile)}`)

      return {
        success: true,
        path,
        signature: signatureFile,
      }
    } catch (error: any) {
      return {
        success: false,
        path,
        errors: [error.message || 'GPG signing failed'],
      }
    }
  }

  /**
   * Verify a signature
   */
  async verify(path: string): Promise<boolean> {
    try {
      switch (this.config.platform) {
        case 'macos':
          await execAsync(`codesign --verify --verbose "${path}"`)
          return true

        case 'windows':
          await execAsync(`signtool verify /pa "${path}"`)
          return true

        case 'linux':
          const sigPath = `${path}.sig`
          if (existsSync(sigPath)) {
            await execAsync(`gpg --verify "${sigPath}" "${path}"`)
            return true
          }
          return false

        default:
          return false
      }
    } catch {
      return false
    }
  }
}

// Notarization (macOS only)
export class Notarizer {
  private config: NotarizationConfig

  constructor(config: NotarizationConfig) {
    this.config = config
  }

  /**
   * Submit app for notarization
   */
  async notarize(path: string): Promise<{ success: boolean; requestId?: string; error?: string }> {
    if (!existsSync(path)) {
      return { success: false, error: `File not found: ${path}` }
    }

    const isApp = path.endsWith('.app')
    const isZip = path.endsWith('.zip')
    const isDmg = path.endsWith('.dmg')
    const isPkg = path.endsWith('.pkg')

    if (!isApp && !isZip && !isDmg && !isPkg) {
      return { success: false, error: 'File must be .app, .zip, .dmg, or .pkg' }
    }

    let submitPath = path

    // If it's a .app, create a zip for submission
    if (isApp) {
      submitPath = `${path}.zip`
      console.log('Creating zip for notarization...')
      await execAsync(`ditto -c -k --keepParent "${path}" "${submitPath}"`)
    }

    try {
      console.log('Submitting for notarization...')

      // Use notarytool (macOS 12+)
      const { stdout } = await execAsync(`
        xcrun notarytool submit "${submitPath}" \
          --apple-id "${this.config.appleId}" \
          --team-id "${this.config.teamId}" \
          --password "${this.config.password}" \
          --wait \
          --timeout 30m
      `)

      // Extract request ID
      const requestIdMatch = stdout.match(/id: ([a-f0-9-]+)/i)
      const requestId = requestIdMatch?.[1]

      // Check if successful
      if (stdout.includes('status: Accepted') || stdout.includes('Successfully uploaded')) {
        console.log('Notarization successful!')

        // Staple the notarization ticket
        if (isApp || isDmg || isPkg) {
          console.log('Stapling ticket...')
          await execAsync(`xcrun stapler staple "${path}"`)
        }

        return { success: true, requestId }
      } else {
        // Get detailed log
        if (requestId) {
          const { stdout: logOutput } = await execAsync(`
            xcrun notarytool log "${requestId}" \
              --apple-id "${this.config.appleId}" \
              --team-id "${this.config.teamId}" \
              --password "${this.config.password}"
          `)
          return { success: false, requestId, error: logOutput }
        }

        return { success: false, error: stdout }
      }
    } catch (error: any) {
      return { success: false, error: error.message }
    } finally {
      // Clean up temporary zip
      if (isApp && existsSync(submitPath)) {
        execSync(`rm "${submitPath}"`)
      }
    }
  }

  /**
   * Check notarization status
   */
  async checkStatus(requestId: string): Promise<{ status: string; message?: string }> {
    try {
      const { stdout } = await execAsync(`
        xcrun notarytool info "${requestId}" \
          --apple-id "${this.config.appleId}" \
          --team-id "${this.config.teamId}" \
          --password "${this.config.password}"
      `)

      const statusMatch = stdout.match(/status: (\w+)/i)
      const status = statusMatch?.[1] || 'unknown'

      return { status, message: stdout }
    } catch (error: any) {
      return { status: 'error', message: error.message }
    }
  }

  /**
   * Get notarization log
   */
  async getLog(requestId: string): Promise<string> {
    try {
      const { stdout } = await execAsync(`
        xcrun notarytool log "${requestId}" \
          --apple-id "${this.config.appleId}" \
          --team-id "${this.config.teamId}" \
          --password "${this.config.password}"
      `)
      return stdout
    } catch (error: any) {
      return error.message
    }
  }
}

// Generate entitlements file
export function generateEntitlements(options: {
  hardened?: boolean
  allowJit?: boolean
  allowUnsigned?: boolean
  allowDyld?: boolean
  network?: {
    client?: boolean
    server?: boolean
  }
  camera?: boolean
  microphone?: boolean
  usb?: boolean
  bluetooth?: boolean
  location?: boolean
  addressBook?: boolean
  calendar?: boolean
  photos?: boolean
  appleEvents?: boolean
}): string {
  const entitlements: Record<string, boolean | string[]> = {}

  // Hardened runtime
  if (options.hardened !== false) {
    if (options.allowJit) {
      entitlements['com.apple.security.cs.allow-jit'] = true
    }
    if (options.allowUnsigned) {
      entitlements['com.apple.security.cs.allow-unsigned-executable-memory'] = true
    }
    if (options.allowDyld) {
      entitlements['com.apple.security.cs.disable-library-validation'] = true
    }
  }

  // Network
  if (options.network?.client) {
    entitlements['com.apple.security.network.client'] = true
  }
  if (options.network?.server) {
    entitlements['com.apple.security.network.server'] = true
  }

  // Hardware
  if (options.camera) {
    entitlements['com.apple.security.device.camera'] = true
  }
  if (options.microphone) {
    entitlements['com.apple.security.device.microphone'] = true
  }
  if (options.usb) {
    entitlements['com.apple.security.device.usb'] = true
  }
  if (options.bluetooth) {
    entitlements['com.apple.security.device.bluetooth'] = true
  }

  // Personal data
  if (options.location) {
    entitlements['com.apple.security.personal-information.location'] = true
  }
  if (options.addressBook) {
    entitlements['com.apple.security.personal-information.addressbook'] = true
  }
  if (options.calendar) {
    entitlements['com.apple.security.personal-information.calendars'] = true
  }
  if (options.photos) {
    entitlements['com.apple.security.personal-information.photos-library'] = true
  }

  // Apple Events
  if (options.appleEvents) {
    entitlements['com.apple.security.automation.apple-events'] = true
  }

  // Generate plist
  let plist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
`

  for (const [key, value] of Object.entries(entitlements)) {
    plist += `    <key>${key}</key>\n`
    if (typeof value === 'boolean') {
      plist += `    <${value}/>\n`
    } else if (Array.isArray(value)) {
      plist += '    <array>\n'
      for (const item of value) {
        plist += `        <string>${item}</string>\n`
      }
      plist += '    </array>\n'
    }
  }

  plist += `</dict>
</plist>`

  return plist
}

// CLI Command
export async function signingCommand(args: string[]): Promise<void> {
  const [subcommand, ...rest] = args

  switch (subcommand) {
    case 'sign': {
      const path = rest[0]
      const platform = (rest.find((a) => a.startsWith('--platform='))?.split('=')[1] ||
        process.platform === 'darwin'
          ? 'macos'
          : process.platform === 'win32'
            ? 'windows'
            : 'linux') as SigningConfig['platform']

      if (!path) {
        console.error('Usage: craft sign <path> [--platform=macos|windows|linux]')
        process.exit(1)
      }

      const signer = new CodeSigner({
        platform,
        identity: rest.find((a) => a.startsWith('--identity='))?.split('=')[1],
        certificate: rest.find((a) => a.startsWith('--certificate='))?.split('=')[1],
        password: rest.find((a) => a.startsWith('--password='))?.split('=')[1],
        entitlements: rest.find((a) => a.startsWith('--entitlements='))?.split('=')[1],
        hardened: !rest.includes('--no-hardened'),
      })

      const result = await signer.sign(path)

      if (result.success) {
        console.log(`✓ Signed: ${path}`)
      } else {
        console.error(`✗ Failed to sign: ${path}`)
        result.errors?.forEach((e) => console.error(`  ${e}`))
        process.exit(1)
      }
      break
    }

    case 'notarize': {
      const path = rest[0]

      if (!path) {
        console.error('Usage: craft sign notarize <path>')
        process.exit(1)
      }

      const appleId = rest.find((a) => a.startsWith('--apple-id='))?.split('=')[1] || process.env.APPLE_ID
      const teamId = rest.find((a) => a.startsWith('--team-id='))?.split('=')[1] || process.env.APPLE_TEAM_ID
      const password =
        rest.find((a) => a.startsWith('--password='))?.split('=')[1] || process.env.APPLE_APP_PASSWORD
      const bundleId = rest.find((a) => a.startsWith('--bundle-id='))?.split('=')[1]

      if (!appleId || !teamId || !password) {
        console.error('Apple ID, Team ID, and password are required for notarization')
        console.error('Set via --apple-id=, --team-id=, --password= or environment variables')
        process.exit(1)
      }

      const notarizer = new Notarizer({
        appleId,
        teamId,
        password,
        bundleId: bundleId || '',
      })

      const result = await notarizer.notarize(path)

      if (result.success) {
        console.log(`✓ Notarized: ${path}`)
        if (result.requestId) {
          console.log(`  Request ID: ${result.requestId}`)
        }
      } else {
        console.error(`✗ Notarization failed: ${path}`)
        if (result.error) {
          console.error(result.error)
        }
        process.exit(1)
      }
      break
    }

    case 'verify': {
      const path = rest[0]

      if (!path) {
        console.error('Usage: craft sign verify <path>')
        process.exit(1)
      }

      const platform = (process.platform === 'darwin'
        ? 'macos'
        : process.platform === 'win32'
          ? 'windows'
          : 'linux') as SigningConfig['platform']

      const signer = new CodeSigner({ platform })
      const valid = await signer.verify(path)

      if (valid) {
        console.log(`✓ Signature valid: ${path}`)
      } else {
        console.log(`✗ Signature invalid or not found: ${path}`)
        process.exit(1)
      }
      break
    }

    case 'entitlements': {
      const output = rest[0] || 'entitlements.plist'

      const plist = generateEntitlements({
        hardened: true,
        network: { client: true, server: true },
        allowJit: rest.includes('--jit'),
        allowUnsigned: rest.includes('--unsigned-memory'),
        camera: rest.includes('--camera'),
        microphone: rest.includes('--microphone'),
      })

      writeFileSync(output, plist)
      console.log(`✓ Generated entitlements: ${output}`)
      break
    }

    default:
      console.log(`
Craft Code Signing

Usage: craft sign <command> [options]

Commands:
  sign <path>           Sign an application
  notarize <path>       Notarize a macOS application
  verify <path>         Verify a signature
  entitlements [output] Generate entitlements.plist

Sign Options:
  --platform=<p>        Platform (macos, windows, linux)
  --identity=<id>       macOS signing identity
  --certificate=<path>  Windows certificate (.pfx)
  --password=<pass>     Certificate password
  --entitlements=<path> macOS entitlements file
  --no-hardened         Disable hardened runtime (macOS)

Notarize Options:
  --apple-id=<email>    Apple ID (or APPLE_ID env)
  --team-id=<id>        Team ID (or APPLE_TEAM_ID env)
  --password=<pass>     App password (or APPLE_APP_PASSWORD env)
  --bundle-id=<id>      Bundle identifier

Entitlements Options:
  --jit                 Allow JIT compilation
  --unsigned-memory     Allow unsigned executable memory
  --camera              Request camera access
  --microphone          Request microphone access
`)
  }
}

export default CodeSigner
