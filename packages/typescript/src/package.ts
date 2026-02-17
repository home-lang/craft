/**
 * Craft Packaging API
 *
 * Enables users to create installers for their Craft applications
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
 * Package a Craft application for distribution
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
      dependencies: opts.debDependencies || ['libgtk-3-0', 'libwebkit2gtk-4.1-37'],
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
    const tempDir = mkdtempSync(join(tmpdir(), 'craft-pkg-'))
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
  return new Promise((resolve) => {
    const { mkdtempSync, rmSync, copyFileSync, chmodSync } = require('fs')
    const { tmpdir } = require('os')

    try {
      // Create DEB package structure
      const tempDir = mkdtempSync(join(tmpdir(), 'craft-deb-'))
      const debianDir = join(tempDir, 'DEBIAN')
      const binDir = join(tempDir, 'usr', 'bin')
      const applicationsDir = join(tempDir, 'usr', 'share', 'applications')

      mkdirSync(debianDir, { recursive: true })
      mkdirSync(binDir, { recursive: true })
      mkdirSync(applicationsDir, { recursive: true })

      // Copy binary
      const binaryName = opts.name.toLowerCase()
      copyFileSync(opts.binaryPath, join(binDir, binaryName))
      chmodSync(join(binDir, binaryName), 0o755)

      // Create control file
      const controlContent = `Package: ${opts.name.toLowerCase()}
Version: ${opts.version}
Section: utils
Priority: optional
Architecture: amd64
Depends: ${opts.dependencies.join(', ')}
Maintainer: ${opts.maintainer}
Description: ${opts.description || opts.name}
`
      writeFileSync(join(debianDir, 'control'), controlContent)

      // Create .desktop file
      const desktopContent = `[Desktop Entry]
Type=Application
Name=${opts.name}
Exec=/usr/bin/${binaryName}
Terminal=false
Categories=Utility;
`
      writeFileSync(join(applicationsDir, `${binaryName}.desktop`), desktopContent)

      // Build DEB using dpkg-deb
      const proc = spawn('dpkg-deb', ['--build', tempDir, opts.outputPath])

      proc.on('close', (code) => {
        rmSync(tempDir, { recursive: true, force: true })
        if (code === 0) {
          resolve({ success: true, outputPath: opts.outputPath })
        } else {
          resolve({ success: false, error: `dpkg-deb exited with code ${code}` })
        }
      })

      proc.on('error', (err) => {
        rmSync(tempDir, { recursive: true, force: true })
        resolve({ success: false, error: err.message })
      })
    } catch (error) {
      resolve({ success: false, error: (error as Error).message })
    }
  })
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
  return new Promise((resolve) => {
    const { mkdtempSync, rmSync, copyFileSync, chmodSync } = require('fs')
    const { tmpdir, homedir } = require('os')

    try {
      // Create RPM build structure
      const buildRoot = join(homedir(), 'rpmbuild')
      const specDir = join(buildRoot, 'SPECS')
      const sourcesDir = join(buildRoot, 'SOURCES')
      const buildDir = join(buildRoot, 'BUILD')
      const rpmsDir = join(buildRoot, 'RPMS')

      mkdirSync(specDir, { recursive: true })
      mkdirSync(sourcesDir, { recursive: true })
      mkdirSync(buildDir, { recursive: true })
      mkdirSync(rpmsDir, { recursive: true })

      // Copy binary to sources
      copyFileSync(opts.binaryPath, join(sourcesDir, opts.name.toLowerCase()))

      // Create spec file
      const specContent = `Name: ${opts.name.toLowerCase()}
Version: ${opts.version}
Release: 1%{?dist}
Summary: ${opts.description || opts.name}
License: MIT
Requires: ${opts.requires.join(', ')}

%description
${opts.description || opts.name}

%install
mkdir -p %{buildroot}/usr/bin
install -m 755 %{SOURCE0} %{buildroot}/usr/bin/${opts.name.toLowerCase()}

%files
/usr/bin/${opts.name.toLowerCase()}
`
      const specPath = join(specDir, `${opts.name.toLowerCase()}.spec`)
      writeFileSync(specPath, specContent)

      // Build RPM
      const proc = spawn('rpmbuild', ['-bb', specPath])

      proc.on('close', (code) => {
        if (code === 0) {
          // Find the built RPM and move it
          const rpmName = `${opts.name.toLowerCase()}-${opts.version}-1.x86_64.rpm`
          const builtRpmPath = join(rpmsDir, 'x86_64', rpmName)
          const { copyFileSync: copy } = require('fs')
          try {
            copy(builtRpmPath, opts.outputPath)
            resolve({ success: true, outputPath: opts.outputPath })
          } catch {
            resolve({ success: false, error: 'Failed to copy built RPM' })
          }
        } else {
          resolve({ success: false, error: `rpmbuild exited with code ${code}` })
        }
      })

      proc.on('error', (err) => {
        resolve({ success: false, error: err.message })
      })
    } catch (error) {
      resolve({ success: false, error: (error as Error).message })
    }
  })
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
  return new Promise((resolve) => {
    const { mkdtempSync, rmSync, copyFileSync, chmodSync } = require('fs')
    const { tmpdir } = require('os')

    try {
      // Create AppDir structure
      const appDir = mkdtempSync(join(tmpdir(), 'craft-appimage-'))
      const appDirPath = join(appDir, `${opts.name}.AppDir`)
      const binDir = join(appDirPath, 'usr', 'bin')
      const shareDir = join(appDirPath, 'usr', 'share')

      mkdirSync(binDir, { recursive: true })
      mkdirSync(shareDir, { recursive: true })

      // Copy binary
      const binaryName = opts.name.toLowerCase()
      copyFileSync(opts.binaryPath, join(binDir, binaryName))
      chmodSync(join(binDir, binaryName), 0o755)

      // Create AppRun script
      const appRunContent = `#!/bin/bash
SELF=$(readlink -f "$0")
HERE=\${SELF%/*}
export PATH="\${HERE}/usr/bin/:\${PATH}"
exec "\${HERE}/usr/bin/${binaryName}" "$@"
`
      writeFileSync(join(appDirPath, 'AppRun'), appRunContent)
      chmodSync(join(appDirPath, 'AppRun'), 0o755)

      // Create .desktop file
      const desktopContent = `[Desktop Entry]
Type=Application
Name=${opts.name}
Exec=${binaryName}
Terminal=false
Categories=Utility;
Icon=${binaryName}
`
      writeFileSync(join(appDirPath, `${binaryName}.desktop`), desktopContent)

      // Copy or create icon
      if (opts.iconPath && existsSync(opts.iconPath)) {
        copyFileSync(opts.iconPath, join(appDirPath, `${binaryName}.png`))
      } else {
        // Create placeholder icon (1x1 PNG)
        const placeholderPng = Buffer.from([
          0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
          0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
          0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xde, 0x00, 0x00, 0x00,
          0x0c, 0x49, 0x44, 0x41, 0x54, 0x08, 0xd7, 0x63, 0xf8, 0xff, 0xff, 0x3f,
          0x00, 0x05, 0xfe, 0x02, 0xfe, 0xdc, 0xcc, 0x59, 0xe7, 0x00, 0x00, 0x00,
          0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82
        ])
        writeFileSync(join(appDirPath, `${binaryName}.png`), placeholderPng)
      }

      // Use appimagetool if available
      const proc = spawn('appimagetool', [appDirPath, opts.outputPath], {
        env: { ...process.env, ARCH: 'x86_64' }
      })

      proc.on('close', (code) => {
        rmSync(appDir, { recursive: true, force: true })
        if (code === 0) {
          chmodSync(opts.outputPath, 0o755)
          resolve({ success: true, outputPath: opts.outputPath })
        } else {
          resolve({ success: false, error: `appimagetool exited with code ${code}. Install from https://appimage.github.io/appimagetool/` })
        }
      })

      proc.on('error', (err) => {
        rmSync(appDir, { recursive: true, force: true })
        resolve({ success: false, error: `appimagetool not found: ${err.message}` })
      })
    } catch (error) {
      resolve({ success: false, error: (error as Error).message })
    }
  })
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
