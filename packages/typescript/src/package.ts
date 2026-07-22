/**
 * Craft Packaging API
 *
 * Enables users to create installers for their Craft applications
 * across all platforms (macOS, Windows, Linux)
 */

import { spawn } from 'child_process'
import { createHash } from 'crypto'
import {
  chmodSync,
  copyFileSync,
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from 'fs'
import { homedir, tmpdir } from 'os'
import { basename, join } from 'path'
import { deflateRawSync } from 'zlib'

// Dependency-free ZIP writer. Craft used to pull `archiver` (→ archiver-utils →
// lazystream → readable-stream) solely to zip a single Windows binary; that
// transitive tree is heavy and broke downstream installs (lazystream requires
// the removed `readable-stream/passthrough` subpath). Bun/Node ship raw DEFLATE
// via node:zlib, so we assemble the ZIP container ourselves.
const CRC32_TABLE: Uint32Array = (() => {
  const table = new Uint32Array(256)
  for (let n = 0; n < 256; n++) {
    let c = n
    for (let k = 0; k < 8; k++)
      c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1
    table[n] = c >>> 0
  }
  return table
})()

function crc32(data: Uint8Array): number {
  let c = 0xFFFFFFFF
  for (let i = 0; i < data.length; i++)
    c = CRC32_TABLE[(c ^ data[i]) & 0xFF] ^ (c >>> 8)
  return (c ^ 0xFFFFFFFF) >>> 0
}

/** DOS-format date/time for ZIP local/central headers. */
function dosDateTime(d: Date): { time: number; date: number } {
  const time = (d.getHours() << 11) | (d.getMinutes() << 5) | (d.getSeconds() >> 1)
  const date = ((d.getFullYear() - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate()
  return { time: time & 0xFFFF, date: date & 0xFFFF }
}

/**
 * Build a ZIP archive (DEFLATE, level 9) from in-memory entries. Emits the
 * standard container: one local-file-header + data record per entry, a central
 * directory, and the end-of-central-directory record. No external dependencies.
 */
function buildZip(entries: Array<{ name: string; data: Uint8Array }>): Buffer {
  const { time, date } = dosDateTime(new Date())
  const locals: Buffer[] = []
  const central: Buffer[] = []
  let offset = 0

  for (const entry of entries) {
    const nameBytes = Buffer.from(entry.name, 'utf8')
    const compressed = deflateRawSync(entry.data, { level: 9 })
    const crc = crc32(entry.data)

    const lfh = Buffer.alloc(30)
    lfh.writeUInt32LE(0x04034B50, 0) // local file header signature
    lfh.writeUInt16LE(20, 4) // version needed to extract
    lfh.writeUInt16LE(0, 6) // general-purpose bit flag
    lfh.writeUInt16LE(8, 8) // compression method: deflate
    lfh.writeUInt16LE(time, 10)
    lfh.writeUInt16LE(date, 12)
    lfh.writeUInt32LE(crc, 14)
    lfh.writeUInt32LE(compressed.length, 18)
    lfh.writeUInt32LE(entry.data.length, 22)
    lfh.writeUInt16LE(nameBytes.length, 26)
    lfh.writeUInt16LE(0, 28) // extra field length
    locals.push(lfh, nameBytes, compressed)

    const cdh = Buffer.alloc(46)
    cdh.writeUInt32LE(0x02014B50, 0) // central directory header signature
    cdh.writeUInt16LE(20, 4) // version made by
    cdh.writeUInt16LE(20, 6) // version needed to extract
    cdh.writeUInt16LE(0, 8) // general-purpose bit flag
    cdh.writeUInt16LE(8, 10) // compression method
    cdh.writeUInt16LE(time, 12)
    cdh.writeUInt16LE(date, 14)
    cdh.writeUInt32LE(crc, 16)
    cdh.writeUInt32LE(compressed.length, 20)
    cdh.writeUInt32LE(entry.data.length, 24)
    cdh.writeUInt16LE(nameBytes.length, 28)
    cdh.writeUInt16LE(0, 30) // extra field length
    cdh.writeUInt16LE(0, 32) // file comment length
    cdh.writeUInt16LE(0, 34) // disk number start
    cdh.writeUInt16LE(0, 36) // internal file attributes
    cdh.writeUInt32LE(0, 38) // external file attributes
    cdh.writeUInt32LE(offset, 42) // relative offset of local header
    central.push(cdh, nameBytes)

    offset += lfh.length + nameBytes.length + compressed.length
  }

  const centralBuf = Buffer.concat(central)
  const eocd = Buffer.alloc(22)
  eocd.writeUInt32LE(0x06054B50, 0) // end of central directory signature
  eocd.writeUInt16LE(0, 4) // number of this disk
  eocd.writeUInt16LE(0, 6) // disk where central directory starts
  eocd.writeUInt16LE(entries.length, 8) // central directory records on this disk
  eocd.writeUInt16LE(entries.length, 10) // total central directory records
  eocd.writeUInt32LE(centralBuf.length, 12) // size of central directory
  eocd.writeUInt32LE(offset, 16) // offset of central directory
  eocd.writeUInt16LE(0, 20) // comment length
  return Buffer.concat([...locals, centralBuf, eocd])
}

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

interface MSIOptions {
  name: string
  version: string
  binaryPath: string
  outputPath: string
  manufacturer: string
  certificatePath?: string
  certificatePassword?: string
}

export interface PackageResult {
  success: boolean
  platform: string
  format: string
  outputPath?: string
  error?: string
}

export function formatPackagingCommandError(tool: string, code: number | null, stdout: string, stderr: string): string {
  const detail = `${stdout}${stderr}`.trim()
  return `${tool} exited with code ${code}${detail ? `: ${detail}` : ''}`
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
      certificatePath: opts.certificatePath,
      certificatePassword: opts.certificatePassword,
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
    copyFileSync(binaryPath, join(outputPath, 'Contents', 'MacOS', name))

    // Make executable
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
  }
catch (error) {
    return { success: false, error: (error as Error).message }
  }
}

const MEBIBYTE = 1024 * 1024

function pathContentBytes(path: string): number {
  const stat = lstatSync(path)
  if (!stat.isDirectory()) return stat.size
  return readdirSync(path).reduce((total, entry) => total + pathContentBytes(join(path, entry)), 0)
}

export function dmgCapacityMegabytes(contentBytes: number): number {
  if (!Number.isSafeInteger(contentBytes) || contentBytes < 0)
    throw new Error(`DMG content size must be a non-negative safe integer: ${contentBytes}`)
  const contentMegabytes = Math.ceil(contentBytes / MEBIBYTE)
  return Math.max(64, Math.ceil(contentMegabytes * 1.25) + 32)
}

export function dmgCreateArguments(opts: {
  appBundlePath: string
  outputPath: string
  volumeName: string
}, contentBytes: number): string[] {
  return [
    'create',
    '-volname', opts.volumeName,
    '-srcfolder', opts.appBundlePath,
    '-size', `${dmgCapacityMegabytes(contentBytes)}m`,
    '-ov',
    '-format', 'UDZO',
    opts.outputPath,
  ]
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
    // hdiutil rejects volume names containing `/`, `:`, or newlines and
    // truncates anything past 27 chars. Surfacing the error early gives a
    // clearer message than the cryptic exit-code-1 hdiutil returns.
    if (!/^[^/:\n]{1,27}$/.test(opts.volumeName)) {
      resolve({ success: false, error: `Invalid DMG volume name "${opts.volumeName}"; must be 1..27 chars without /, :, or newline` })
      return
    }
    const proc = spawn('hdiutil', dmgCreateArguments(opts, pathContentBytes(opts.appBundlePath)))
    let stdout = ''
    let stderr = ''
    proc.stdout?.on('data', chunk => { stdout += chunk.toString() })
    proc.stderr?.on('data', chunk => { stderr += chunk.toString() })

    proc.on('close', (code) => {
      if (code === 0) {
        resolve({ success: true, outputPath: opts.outputPath })
      }
else {
        resolve({ success: false, error: formatPackagingCommandError('hdiutil', code, stdout, stderr) })
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
    // pkgbuild requires reverse-DNS form for the identifier. Validate
    // upfront so the error message is actionable rather than the cryptic
    // pkgbuild "-identifier requires" output.
    if (!/^[a-zA-Z0-9._-]+$/.test(opts.identifier) || !opts.identifier.includes('.')) {
      resolve({ success: false, error: `Invalid pkg identifier "${opts.identifier}"; expected reverse-DNS like com.example.app` })
      return
    }
    if (!/^[A-Za-z0-9._+-]+$/.test(opts.version)) {
      resolve({ success: false, error: `Invalid pkg version "${opts.version}"` })
      return
    }
    // Create temp directory structure
    const tempDir = mkdtempSync(join(tmpdir(), 'craft-pkg-'))
    const appsDir = join(tempDir, 'Applications')

    mkdirSync(appsDir, { recursive: true })
    cpSync(opts.appBundlePath, join(appsDir, basename(opts.appBundlePath)), { recursive: true })

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
      }
else {
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
function xml(value: string): string {
  return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll(`'`, '&apos;')
}

function wixIdentifier(value: string): string {
  const sanitized = value.replace(/[^A-Za-z0-9_.]/g, '_')
  return /^[A-Za-z_]/.test(sanitized) ? sanitized : `_${sanitized}`
}

function deterministicGuid(value: string): string {
  const digest = createHash('sha256').update(value).digest('hex').slice(0, 32).split('')
  digest[12] = '4'
  digest[16] = ((Number.parseInt(digest[16]!, 16) & 0x3) | 0x8).toString(16)
  const hex = digest.join('').toUpperCase()
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
}

export function renderWixSource(opts: Pick<MSIOptions, 'name' | 'version' | 'manufacturer'>, sourceName: string): string {
  if (!/^[0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?$/.test(opts.version)) throw new Error(`MSI version must have 3 or 4 numeric parts: ${opts.version}`)
  const id = wixIdentifier(opts.name)
  const manufacturer = opts.manufacturer.trim() || 'Unknown'
  const upgradeCode = deterministicGuid(`${manufacturer}/${opts.name}`)
  return `<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*" Name="${xml(opts.name)}" Language="1033" Version="${opts.version}" Manufacturer="${xml(manufacturer)}" UpgradeCode="${upgradeCode}">
    <Package InstallerVersion="500" Compressed="yes" InstallScope="perMachine" />
    <MajorUpgrade AllowDowngrades="yes" />
    <MediaTemplate EmbedCab="yes" />
    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFilesFolder">
        <Directory Id="INSTALLFOLDER" Name="${xml(opts.name)}">
          <Component Id="${id}Executable" Guid="*">
            <File Id="${id}File" Source="${xml(sourceName)}" KeyPath="yes" />
          </Component>
        </Directory>
      </Directory>
    </Directory>
    <Feature Id="ProductFeature" Title="${xml(opts.name)}" Level="1">
      <ComponentRef Id="${id}Executable" />
    </Feature>
  </Product>
</Wix>
`
}

export function windowsExecutableName(name: string): string {
  if (name.length === 0 || name.trim() !== name || /[<>:"/\\|?*\u0000-\u001F]/.test(name) || /[. ]$/.test(name))
    throw new Error(`Invalid Windows application name: ${JSON.stringify(name)}`)
  if (/^(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)/i.test(name))
    throw new Error(`Reserved Windows application name: ${JSON.stringify(name)}`)
  return `${name}.exe`
}

function runCommand(command: string, args: string[], cwd?: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, stdio: 'inherit', windowsHide: true })
    child.once('error', reject)
    child.once('close', code => code === 0 ? resolve() : reject(new Error(`${command} exited with code ${code}`)))
  })
}

async function createMSI(opts: MSIOptions): Promise<{ success: boolean; outputPath?: string; error?: string }> {
  const tempDir = mkdtempSync(join(tmpdir(), 'craft-msi-'))
  try {
    const binaryName = windowsExecutableName(opts.name)
    const sourcePath = join(tempDir, binaryName)
    const wxsPath = join(tempDir, 'installer.wxs')
    const wixobjPath = join(tempDir, 'installer.wixobj')
    copyFileSync(opts.binaryPath, sourcePath)
    writeFileSync(wxsPath, renderWixSource(opts, binaryName))
    await runCommand('candle.exe', ['-nologo', '-out', wixobjPath, wxsPath], tempDir)
    await runCommand('light.exe', ['-nologo', '-sval', '-out', opts.outputPath, wixobjPath], tempDir)
    if (opts.certificatePath) {
      const signArgs = ['sign', '/fd', 'sha256', '/tr', 'https://timestamp.digicert.com', '/td', 'sha256', '/f', opts.certificatePath]
      if (opts.certificatePassword) signArgs.push('/p', opts.certificatePassword)
      signArgs.push(opts.outputPath)
      await runCommand('signtool.exe', signArgs)
      await runCommand('signtool.exe', ['verify', '/pa', '/all', opts.outputPath])
    }
    return { success: true, outputPath: opts.outputPath }
  }
  catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    const missingTool = /ENOENT|not found/i.test(message)
    return { success: false, error: missingTool ? `WiX Toolset not found: ${message}` : message }
  }
  finally {
    rmSync(tempDir, { recursive: true, force: true })
  }
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
  try {
    const data = new Uint8Array(readFileSync(opts.binaryPath))
    const zip = buildZip([{ name: `${opts.name}.exe`, data }])
    writeFileSync(opts.outputPath, zip)
    return { success: true, outputPath: opts.outputPath }
  }
  catch (err) {
    return { success: false, error: `Failed to write ZIP: ${(err as Error).message}` }
  }
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
    try {
      // Validate inputs that get interpolated into the DEBIAN/control file.
      // dpkg's control file is line-oriented; newlines or `,` in fields, or
      // `/` in the package name, corrupt the manifest.
      const sanitizedName = opts.name.toLowerCase()
      const safeDebName = /^[a-z0-9._+-]+$/
      const safeVersion = /^[A-Za-z0-9._+-]+$/
      if (!safeDebName.test(sanitizedName)) {
        resolve({ success: false, error: `DEB package name must match ${safeDebName} (got: ${sanitizedName})` })
        return
      }
      if (!safeVersion.test(opts.version)) {
        resolve({ success: false, error: `DEB version must match ${safeVersion} (got: ${opts.version})` })
        return
      }
      const cleanLine = (s: string): string => s.replace(/[\r\n]+/g, ' ').trim()
      const description = cleanLine(opts.description)
      const maintainer = cleanLine(opts.maintainer)
      for (const dep of opts.dependencies) {
        // Allow versioned constraints like `libgtk-3-0 (>= 3.22)`.
        if (!/^[a-z0-9._+-]+(?:\s*\([^)\n,]+\))?$/i.test(dep)) {
          resolve({ success: false, error: `Invalid DEB dependency "${dep}"` })
          return
        }
      }

      // Create DEB package structure
      const tempDir = mkdtempSync(join(tmpdir(), 'craft-deb-'))
      const debianDir = join(tempDir, 'DEBIAN')
      const binDir = join(tempDir, 'usr', 'bin')
      const applicationsDir = join(tempDir, 'usr', 'share', 'applications')

      mkdirSync(debianDir, { recursive: true })
      mkdirSync(binDir, { recursive: true })
      mkdirSync(applicationsDir, { recursive: true })

      // Copy binary
      const binaryName = sanitizedName
      copyFileSync(opts.binaryPath, join(binDir, binaryName))
      chmodSync(join(binDir, binaryName), 0o755)

      // Create control file. Every field has been sanitized above.
      const controlContent = `Package: ${sanitizedName}
Version: ${opts.version}
Section: utils
Priority: optional
Architecture: amd64
Depends: ${opts.dependencies.join(', ')}
Maintainer: ${maintainer}
Description: ${description || opts.name}
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
        }
else {
          resolve({ success: false, error: `dpkg-deb exited with code ${code}` })
        }
      })

      proc.on('error', (err) => {
        rmSync(tempDir, { recursive: true, force: true })
        resolve({ success: false, error: err.message })
      })
    }
catch (error) {
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

      // Validate inputs that get interpolated into the .spec file. RPM spec
      // files treat `%` as a macro prefix and parse line-by-line, so
      // newlines or `%` in user data could inject scriptlets / corrupt the
      // spec. Reject early with a clear message.
      const safePackageName = /^[a-z0-9._+-]+$/i
      const safeVersion = /^[A-Za-z0-9._+-]+$/
      const sanitizedName = opts.name.toLowerCase()
      if (!safePackageName.test(sanitizedName)) {
        return resolve({ success: false, error: `RPM package name must match ${safePackageName} (got: ${sanitizedName})` })
      }
      if (!safeVersion.test(opts.version)) {
        return resolve({ success: false, error: `RPM version must match ${safeVersion} (got: ${opts.version})` })
      }
      // Description / summary go into single-line spec headers; collapse
      // newlines and reject `%` to prevent macro expansion.
      const cleanLine = (s: string): string => s.replace(/[\r\n]+/g, ' ').replace(/%/g, '%%')
      const summary = cleanLine(opts.description || opts.name)
      const description = (opts.description || opts.name)
        .split(/\r?\n/).map(line => line.replace(/%/g, '%%')).join('\n')
      const requires = opts.requires.map((r) => {
        if (!safePackageName.test(r)) {
          throw new Error(`RPM Requires entry must match ${safePackageName} (got: ${r})`)
        }
        return r
      }).join(', ')

      // Copy binary to sources
      copyFileSync(opts.binaryPath, join(sourcesDir, sanitizedName))

      // Create spec file
      const specContent = `Name: ${sanitizedName}
Version: ${opts.version}
Release: 1%{?dist}
Summary: ${summary}
License: MIT
Requires: ${requires}

%description
${description}

%install
mkdir -p %{buildroot}/usr/bin
install -m 755 %{SOURCE0} %{buildroot}/usr/bin/${sanitizedName}

%files
/usr/bin/${sanitizedName}
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
          try {
            copyFileSync(builtRpmPath, opts.outputPath)
            resolve({ success: true, outputPath: opts.outputPath })
          }
catch {
            resolve({ success: false, error: 'Failed to copy built RPM' })
          }
        }
else {
          resolve({ success: false, error: `rpmbuild exited with code ${code}` })
        }
      })

      proc.on('error', (err) => {
        resolve({ success: false, error: err.message })
      })
    }
catch (error) {
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
      }
else {
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
        }
else {
          resolve({ success: false, error: `appimagetool exited with code ${code}. Install from https://appimage.github.io/appimagetool/` })
        }
      })

      proc.on('error', (err) => {
        rmSync(appDir, { recursive: true, force: true })
        resolve({ success: false, error: `appimagetool not found: ${err.message}` })
      })
    }
catch (error) {
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
