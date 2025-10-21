/**
 * Zyte Packaging API
 *
 * Enables users to create installers for their Zyte applications
 * across all platforms (macOS, Windows, Linux)
 */

import { spawn } from 'child_process'
import { existsSync, mkdirSync, writeFileSync } from 'fs'
import { join } from 'path'

export interface PackageConfig {
  /** Application name */
  name: string

  /** Application version (semver) */
  version: string

  /** Application description */
  description?: string

  /** Author/Maintainer */
  author?: string

  /** Homepage URL */
  homepage?: string

  /** Path to application binary */
  binaryPath: string

  /** Path to application icon (platform-specific formats) */
  iconPath?: string

  /** Output directory for installers */
  outDir?: string

  /** Bundle identifier (macOS/iOS) */
  bundleId?: string

  /** Platforms to build for */
  platforms?: Array<'macos' | 'windows' | 'linux'>

  /** macOS-specific options */
  macos?: {
    /** Create DMG installer */
    dmg?: boolean

    /** Create PKG installer */
    pkg?: boolean

    /** Code signing identity */
    signIdentity?: string

    /** Notarize the app */
    notarize?: boolean

    /** Apple ID for notarization */
    appleId?: string

    /** App-specific password */
    applePassword?: string
  }

  /** Windows-specific options */
  windows?: {
    /** Create MSI installer */
    msi?: boolean

    /** Create ZIP archive */
    zip?: boolean

    /** Code signing certificate */
    certificatePath?: string

    /** Certificate password */
    certificatePassword?: string
  }

  /** Linux-specific options */
  linux?: {
    /** Create DEB package */
    deb?: boolean

    /** Create RPM package */
    rpm?: boolean

    /** Create AppImage */
    appImage?: boolean

    /** Desktop categories */
    categories?: string[]

    /** Dependencies (Debian) */
    debDependencies?: string[]

    /** Dependencies (RPM) */
    rpmDependencies?: string[]
  }
}

export interface PackageResult {
  success: boolean
  platform: string
  format: string
  outputPath?: string
  error?: string
}

/**
 * Package a Zyte application for distribution
 */
export async function packageApp(config: PackageConfig): Promise<PackageResult[]> {
  const results: PackageResult[] = []

  // Validate config
  if (!config.binaryPath || !existsSync(config.binaryPath)) {
    throw new Error(`Binary not found: ${config.binaryPath}`)
  }

  // Default platforms: current platform only
  const platforms = config.platforms || [detectPlatform()]

  // Create output directory
  const outDir = config.outDir || join(process.cwd(), 'dist')
  if (!existsSync(outDir)) {
    mkdirSync(outDir, { recursive: true })
  }

  // Package for each platform
  for (const platform of platforms) {
    switch (platform) {
      case 'macos':
        results.push(...await packageMacOS(config, outDir))
        break
      case 'windows':
        results.push(...await packageWindows(config, outDir))
        break
      case 'linux':
        results.push(...await packageLinux(config, outDir))
        break
    }
  }

  return results
}

/**
 * Package for macOS (DMG + PKG)
 */
async function packageMacOS(config: PackageConfig, outDir: string): Promise<PackageResult[]> {
  const results: PackageResult[] = []
  const { name, version, bundleId = `com.myapp.${name.toLowerCase()}` } = config
  const opts = config.macos || {}

  // Create app bundle
  const appBundlePath = join(outDir, `${name}.app`)
  const appBundle = createMacOSAppBundle({
    name,
    version,
    bundleId,
    binaryPath: config.binaryPath,
    iconPath: config.iconPath,
    outputPath: appBundlePath,
  })

  if (!appBundle.success) {
    results.push({
      success: false,
      platform: 'macos',
      format: 'app',
      error: appBundle.error,
    })
    return results
  }

  // Create DMG
  if (opts.dmg !== false) {
    const dmgResult = await createDMG({
      appBundlePath,
      outputPath: join(outDir, `${name}-${version}.dmg`),
      volumeName: name,
    })
    results.push({
      success: dmgResult.success,
      platform: 'macos',
      format: 'dmg',
      outputPath: dmgResult.outputPath,
      error: dmgResult.error,
    })
  }

  // Create PKG
  if (opts.pkg) {
    const pkgResult = await createPKG({
      appBundlePath,
      outputPath: join(outDir, `${name}-${version}.pkg`),
      identifier: bundleId,
      version,
    })
    results.push({
      success: pkgResult.success,
      platform: 'macos',
      format: 'pkg',
      outputPath: pkgResult.outputPath,
      error: pkgResult.error,
    })
  }

  return results
}

/**
 * Package for Windows (MSI + ZIP)
 */
async function packageWindows(config: PackageConfig, outDir: string): Promise<PackageResult[]> {
  const results: PackageResult[] = []
  const { name, version } = config
  const opts = config.windows || {}

  // Create MSI (if WiX available)
  if (opts.msi !== false) {
    const msiResult = await createMSI({
      name,
      version,
      binaryPath: config.binaryPath,
      outputPath: join(outDir, `${name}-${version}.msi`),
      manufacturer: config.author || 'Unknown',
    })
    results.push({
      success: msiResult.success,
      platform: 'windows',
      format: 'msi',
      outputPath: msiResult.outputPath,
      error: msiResult.error,
    })
  }

  // Create ZIP (fallback)
  if (opts.zip || opts.msi === false) {
    const zipResult = await createZIP({
      name,
      version,
      binaryPath: config.binaryPath,
      outputPath: join(outDir, `${name}-${version}-windows.zip`),
    })
    results.push({
      success: zipResult.success,
      platform: 'windows',
      format: 'zip',
      outputPath: zipResult.outputPath,
      error: zipResult.error,
    })
  }

  return results
}

/**
 * Package for Linux (DEB + RPM + AppImage)
 */
async function packageLinux(config: PackageConfig, outDir: string): Promise<PackageResult[]> {
  const results: PackageResult[] = []
  const { name, version } = config
  const opts = config.linux || {}

  // Create DEB
  if (opts.deb !== false) {
    const debResult = await createDEB({
      name,
      version,
      binaryPath: config.binaryPath,
      outputPath: join(outDir, `${name}_${version}_amd64.deb`),
      description: config.description || '',
      maintainer: config.author || 'Unknown',
      dependencies: opts.debDependencies || ['libgtk-3-0', 'libwebkit2gtk-4.0-37'],
    })
    results.push({
      success: debResult.success,
      platform: 'linux',
      format: 'deb',
      outputPath: debResult.outputPath,
      error: debResult.error,
    })
  }

  // Create RPM
  if (opts.rpm) {
    const rpmResult = await createRPM({
      name,
      version,
      binaryPath: config.binaryPath,
      outputPath: join(outDir, `${name}-${version}-1.x86_64.rpm`),
      description: config.description || '',
      requires: opts.rpmDependencies || ['gtk3', 'webkit2gtk3'],
    })
    results.push({
      success: rpmResult.success,
      platform: 'linux',
      format: 'rpm',
      outputPath: rpmResult.outputPath,
      error: rpmResult.error,
    })
  }

  // Create AppImage
  if (opts.appImage) {
    const appImageResult = await createAppImage({
      name,
      version,
      binaryPath: config.binaryPath,
      outputPath: join(outDir, `${name}-${version}-x86_64.AppImage`),
      iconPath: config.iconPath,
    })
    results.push({
      success: appImageResult.success,
      platform: 'linux',
      format: 'appimage',
      outputPath: appImageResult.outputPath,
      error: appImageResult.error,
    })
  }

  return results
}

/**
 * Helper: Create macOS app bundle
 */
function createMacOSAppBundle(opts: {
  name: string
  version: string
  bundleId: string
  binaryPath: string
  iconPath?: string
  outputPath: string
}): { success: boolean; error?: string } {
  try {
    const { name, version, bundleId, binaryPath, outputPath } = opts

    // Create bundle structure
    mkdirSync(join(outputPath, 'Contents', 'MacOS'), { recursive: true })
    mkdirSync(join(outputPath, 'Contents', 'Resources'), { recursive: true })

    // Copy binary
    const { copyFileSync } = require('fs')
    copyFileSync(binaryPath, join(outputPath, 'Contents', 'MacOS', name))

    // Make executable
    const { chmodSync } = require('fs')
    chmodSync(join(outputPath, 'Contents', 'MacOS', name), 0o755)

    // Create Info.plist
    const infoPlist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${name}</string>
    <key>CFBundleIdentifier</key>
    <string>${bundleId}</string>
    <key>CFBundleName</key>
    <string>${name}</string>
    <key>CFBundleShortVersionString</key>
    <string>${version}</string>
    <key>CFBundleVersion</key>
    <string>${version}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>`

    writeFileSync(join(outputPath, 'Contents', 'Info.plist'), infoPlist)

    return { success: true }
  } catch (error) {
    return { success: false, error: (error as Error).message }
  }
}

/**
 * Helper: Create DMG from app bundle
 */
async function createDMG(opts: {
  appBundlePath: string
  outputPath: string
  volumeName: string
}): Promise<{ success: boolean; outputPath?: string; error?: string }> {
  return new Promise((resolve) => {
    const proc = spawn('hdiutil', [
      'create',
      '-volname', opts.volumeName,
      '-srcfolder', opts.appBundlePath,
      '-ov',
      '-format', 'UDZO',
      opts.outputPath,
    ])

    proc.on('close', (code) => {
      if (code === 0) {
        resolve({ success: true, outputPath: opts.outputPath })
      } else {
        resolve({ success: false, error: `hdiutil exited with code ${code}` })
      }
    })

    proc.on('error', (err) => {
      resolve({ success: false, error: err.message })
    })
  })
}

/**
 * Helper: Create PKG from app bundle
 */
async function createPKG(opts: {
  appBundlePath: string
  outputPath: string
  identifier: string
  version: string
}): Promise<{ success: boolean; outputPath?: string; error?: string }> {
  return new Promise((resolve) => {
    // Create temp directory structure
    const { mkdtempSync, cpSync, rmSync } = require('fs')
    const { tmpdir } = require('os')
    const tempDir = mkdtempSync(join(tmpdir(), 'zyte-pkg-'))
    const appsDir = join(tempDir, 'Applications')

    mkdirSync(appsDir, { recursive: true })
    cpSync(opts.appBundlePath, join(appsDir, require('path').basename(opts.appBundlePath)), { recursive: true })

    const proc = spawn('pkgbuild', [
      '--root', tempDir,
      '--identifier', opts.identifier,
      '--version', opts.version,
      '--install-location', '/',
      opts.outputPath,
    ])

    proc.on('close', (code) => {
      rmSync(tempDir, { recursive: true, force: true })

      if (code === 0) {
        resolve({ success: true, outputPath: opts.outputPath })
      } else {
        resolve({ success: false, error: `pkgbuild exited with code ${code}` })
      }
    })

    proc.on('error', (err) => {
      rmSync(tempDir, { recursive: true, force: true })
      resolve({ success: false, error: err.message })
    })
  })
}

/**
 * Helper: Create Windows MSI
 */
async function createMSI(opts: {
  name: string
  version: string
  binaryPath: string
  outputPath: string
  manufacturer: string
}): Promise<{ success: boolean; outputPath?: string; error?: string }> {
  // Check if WiX is available
  return new Promise((resolve) => {
    const { exec } = require('child_process')
    exec('candle.exe -?', (error: any) => {
      if (error) {
        resolve({
          success: false,
          error: 'WiX Toolset not found. Install from https://wixtoolset.org/',
        })
      } else {
        // WiX implementation would go here
        resolve({
          success: false,
          error: 'MSI creation requires Windows platform and WiX Toolset',
        })
      }
    })
  })
}

/**
 * Helper: Create Windows ZIP
 */
async function createZIP(opts: {
  name: string
  version: string
  binaryPath: string
  outputPath: string
}): Promise<{ success: boolean; outputPath?: string; error?: string }> {
  return new Promise((resolve) => {
    const { createWriteStream } = require('fs')
    const archiver = require('archiver')

    const output = createWriteStream(opts.outputPath)
    const archive = archiver('zip', { zlib: { level: 9 } })

    output.on('close', () => {
      resolve({ success: true, outputPath: opts.outputPath })
    })

    archive.on('error', (err: Error) => {
      resolve({ success: false, error: err.message })
    })

    archive.pipe(output)
    archive.file(opts.binaryPath, { name: `${opts.name}.exe` })
    archive.finalize()
  })
}

/**
 * Helper: Create Linux DEB package
 */
async function createDEB(opts: {
  name: string
  version: string
  binaryPath: string
  outputPath: string
  description: string
  maintainer: string
  dependencies: string[]
}): Promise<{ success: boolean; outputPath?: string; error?: string }> {
  // DEB creation logic (similar to package-linux.sh but in TypeScript)
  return { success: false, error: 'DEB creation not yet implemented in TS API' }
}

/**
 * Helper: Create Linux RPM package
 */
async function createRPM(opts: {
  name: string
  version: string
  binaryPath: string
  outputPath: string
  description: string
  requires: string[]
}): Promise<{ success: boolean; outputPath?: string; error?: string }> {
  return { success: false, error: 'RPM creation not yet implemented in TS API' }
}

/**
 * Helper: Create Linux AppImage
 */
async function createAppImage(opts: {
  name: string
  version: string
  binaryPath: string
  outputPath: string
  iconPath?: string
}): Promise<{ success: boolean; outputPath?: string; error?: string }> {
  return { success: false, error: 'AppImage creation not yet implemented in TS API' }
}

/**
 * Detect current platform
 */
function detectPlatform(): 'macos' | 'windows' | 'linux' {
  switch (process.platform) {
    case 'darwin':
      return 'macos'
    case 'win32':
      return 'windows'
    default:
      return 'linux'
  }
}

/**
 * Simple packaging function for quick use
 */
export async function pack(options: {
  name: string
  version: string
  binaryPath: string
  outDir?: string
}): Promise<PackageResult[]> {
  return packageApp({
    ...options,
    platforms: [detectPlatform()],
  })
}
