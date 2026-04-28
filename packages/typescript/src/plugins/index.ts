/**
 * Craft Plugin System
 * Manage, install, and run plugins for extending Craft functionality
 */

import { existsSync, mkdirSync, writeFileSync, readFileSync, rmSync, renameSync } from 'fs'
import { join, isAbsolute, normalize } from 'path'
import { execFileSync } from 'child_process'
import { EventEmitter } from 'events'

/**
 * Extract a tarball to `dest`, refusing entries that would write outside
 * `dest`. Tar archives can contain `../` paths or absolute paths; without
 * this check a malicious plugin could write to arbitrary filesystem
 * locations during install.
 *
 * We use `-tvzf` (verbose) so the listing includes type characters
 * (`-`/`d`/`l`/`h`) and reject hardlinks and symlinks unconditionally —
 * even a relative-looking link target can dereference outside `dest` once
 * tar follows it during the next file write.
 */
/**
 * Maximum bytes accepted for a downloaded plugin tarball. A hostile manifest
 * URL could otherwise stream gigabytes and OOM the process.
 */
const MAX_PLUGIN_BYTES = 50 * 1024 * 1024 // 50 MB

/**
 * Fetch a plugin tarball with a hard size cap. Throws if the server reports
 * Content-Length larger than `MAX_PLUGIN_BYTES`, OR if the streamed body
 * exceeds the cap (covers servers that omit Content-Length).
 */
async function fetchPluginPackage(url: string): Promise<ArrayBuffer> {
  const response = await fetch(url)
  if (!response.ok) {
    throw new Error(`Failed to fetch plugin package: HTTP ${response.status}`)
  }
  const contentLength = Number.parseInt(response.headers.get('content-length') || '', 10)
  if (Number.isFinite(contentLength) && contentLength > MAX_PLUGIN_BYTES) {
    throw new Error(`Plugin package too large: ${contentLength} bytes > ${MAX_PLUGIN_BYTES}`)
  }

  if (!response.body) {
    return response.arrayBuffer()
  }
  // Stream and tally so a missing/lying Content-Length can't smuggle past.
  const reader = response.body.getReader()
  const chunks: Uint8Array[] = []
  let total = 0
  for (;;) {
    const { value, done } = await reader.read()
    if (done) break
    if (value) {
      total += value.byteLength
      if (total > MAX_PLUGIN_BYTES) {
        try {
          await reader.cancel()
        }
        catch {
          // ignore — we're already aborting
        }
        throw new Error(`Plugin package exceeded ${MAX_PLUGIN_BYTES} bytes mid-stream`)
      }
      chunks.push(value)
    }
  }
  const out = new Uint8Array(total)
  let offset = 0
  for (const chunk of chunks) {
    out.set(chunk, offset)
    offset += chunk.byteLength
  }
  return out.buffer
}

function safeExtractTar(tarballPath: string, dest: string): void {
  const listOutput = execFileSync('tar', ['-tvzf', tarballPath], {
    cwd: dest,
    encoding: 'utf8',
    timeout: 30_000,
  })
  for (const rawLine of listOutput.split('\n')) {
    const line = rawLine.trim()
    if (!line) continue
    const typeChar = line[0]
    // Reject symlinks (`l`) and hardlinks (`h`) outright.
    if (typeChar === 'l' || typeChar === 'h') {
      throw new Error(`Plugin tarball contains a ${typeChar === 'l' ? 'symlink' : 'hardlink'} (refusing to extract): ${line}`)
    }
    // Path is the last whitespace-delimited token; for symlink listings
    // it'd be `target -> name`, but we already rejected those above.
    const tokens = line.split(/\s+/)
    const entry = tokens[tokens.length - 1]
    if (!entry) continue
    if (isAbsolute(entry)) {
      throw new Error(`Plugin tarball contains absolute path: ${entry}`)
    }
    const normalized = normalize(entry)
    if (normalized === '..' || normalized.startsWith('../') || normalized.includes('/../')) {
      throw new Error(`Plugin tarball contains traversal path: ${entry}`)
    }
  }
  // `--no-overwrite-dir` keeps tar from clobbering directory permissions.
  execFileSync('tar', ['-xzf', tarballPath, '--no-overwrite-dir'], {
    cwd: dest,
    timeout: 60_000,
  })
}

// Types
export interface Plugin {
  name: string
  version: string
  description: string
  author?: string
  repository?: string
  main: string
  permissions: PluginPermission[]
  hooks?: PluginHooks
}

export type PluginPermission =
  | 'fs:read'
  | 'fs:write'
  | 'net:fetch'
  | 'net:listen'
  | 'process:spawn'
  | 'env:read'
  | 'clipboard'

export interface PluginHooks {
  build?: string
  dev?: string
  package?: string
  deploy?: string
}

export interface PluginManifest {
  plugins: Record<string, { version: string; enabled: boolean }>
  registry: string
}

export interface PluginRegistry {
  plugins: Record<string, PluginRegistryEntry>
}

export interface PluginRegistryEntry {
  name: string
  description: string
  versions: Record<string, { url: string; checksum: string }>
  latest: string
}

/**
 * Events emitted by `PluginManager`.
 *
 *   `plugin:error` — `{ name, hookName, error }` — a plugin's hook crashed.
 *                    Subscribe to surface failures in your own UI / logs.
 */
export interface PluginEvents {
  'plugin:error': { name: string; hookName: string; error: unknown }
}

// Plugin Manager
export class PluginManager extends EventEmitter {
  private pluginsDir: string
  private manifestPath: string
  private manifest: PluginManifest

  constructor(projectRoot: string) {
    super()
    this.pluginsDir = join(projectRoot, '.craft', 'plugins')
    this.manifestPath = join(projectRoot, '.craft', 'plugins.json')

    if (!existsSync(this.pluginsDir)) {
      mkdirSync(this.pluginsDir, { recursive: true })
    }

    this.manifest = this.loadManifest()
  }

  private loadManifest(): PluginManifest {
    if (existsSync(this.manifestPath)) {
      return JSON.parse(readFileSync(this.manifestPath, 'utf-8'))
    }
    return {
      plugins: {},
      registry: 'https://plugins.craft.dev',
    }
  }

  private saveManifest(): void {
    writeFileSync(this.manifestPath, JSON.stringify(this.manifest, null, 2))
  }

  /**
   * Install a plugin from the registry or a URL
   */
  async install(nameOrUrl: string, version?: string): Promise<void> {
    console.log(`Installing plugin: ${nameOrUrl}${version ? `@${version}` : ''}`)

    let plugin: Plugin
    let pluginDir: string

    if (nameOrUrl.startsWith('http://') || nameOrUrl.startsWith('https://')) {
      // Install from URL
      plugin = await this.installFromUrl(nameOrUrl)
    }
else if (nameOrUrl.startsWith('git://') || nameOrUrl.includes('github.com')) {
      // Install from Git
      plugin = await this.installFromGit(nameOrUrl)
    }
else {
      // Install from registry
      plugin = await this.installFromRegistry(nameOrUrl, version)
    }

    pluginDir = join(this.pluginsDir, plugin.name)

    // Verify plugin
    await this.verifyPlugin(plugin, pluginDir)

    // Update manifest
    this.manifest.plugins[plugin.name] = {
      version: plugin.version,
      enabled: true,
    }
    this.saveManifest()

    console.log(`✓ Installed ${plugin.name}@${plugin.version}`)
  }

  private async installFromRegistry(name: string, version?: string): Promise<Plugin> {
    // Fetch plugin info from registry
    const registryUrl = `${this.manifest.registry}/plugins/${name}`
    const response = await fetch(registryUrl)

    if (!response.ok) {
      throw new Error(`Plugin not found: ${name}`)
    }

    const entry: PluginRegistryEntry = await response.json()
    const targetVersion = version || entry.latest
    const versionInfo = entry.versions[targetVersion]

    if (!versionInfo) {
      throw new Error(`Version ${targetVersion} not found for plugin ${name}`)
    }

    // Download plugin
    const pluginDir = join(this.pluginsDir, name)
    mkdirSync(pluginDir, { recursive: true })

    const packageData = await fetchPluginPackage(versionInfo.url)

    // Verify checksum
    const checksum = await this.computeChecksum(packageData)
    if (checksum !== versionInfo.checksum) {
      throw new Error('Plugin checksum mismatch - download may be corrupted')
    }

    // Extract package (validates archive entries first so a hostile tar
    // can't write outside pluginDir).
    const tarPath = join(pluginDir, 'package.tgz')
    writeFileSync(tarPath, Buffer.from(packageData))
    safeExtractTar(tarPath, pluginDir)
    rmSync(tarPath)

    // Load plugin manifest
    const pluginManifest = JSON.parse(
      readFileSync(join(pluginDir, 'craft-plugin.json'), 'utf-8')
    )

    return pluginManifest
  }

  private async installFromUrl(url: string): Promise<Plugin> {
    const packageData = await fetchPluginPackage(url)
    const tempDir = join(this.pluginsDir, '_temp')
    mkdirSync(tempDir, { recursive: true })

    const tarPath = join(tempDir, 'package.tgz')
    writeFileSync(tarPath, Buffer.from(packageData))
    safeExtractTar(tarPath, tempDir)

    const pluginManifest: Plugin = JSON.parse(
      readFileSync(join(tempDir, 'craft-plugin.json'), 'utf-8')
    )

    // Move to proper location
    const pluginDir = join(this.pluginsDir, pluginManifest.name)
    if (existsSync(pluginDir)) {
      rmSync(pluginDir, { recursive: true })
    }
    renameSync(tempDir, pluginDir)

    return pluginManifest
  }

  private async installFromGit(url: string): Promise<Plugin> {
    const tempDir = join(this.pluginsDir, '_git_temp')
    if (existsSync(tempDir)) {
      rmSync(tempDir, { recursive: true })
    }

    // Validate URL scheme to prevent git option injection (e.g. --upload-pack)
    if (!/^(?:https?|git|ssh):\/\//i.test(url)) {
      throw new Error(`Unsupported git URL scheme for plugin install: ${url}`)
    }
    execFileSync('git', ['clone', '--depth', '1', '--', url, tempDir])

    const pluginManifest: Plugin = JSON.parse(
      readFileSync(join(tempDir, 'craft-plugin.json'), 'utf-8')
    )

    // Remove .git directory
    rmSync(join(tempDir, '.git'), { recursive: true })

    // Move to proper location
    const pluginDir = join(this.pluginsDir, pluginManifest.name)
    if (existsSync(pluginDir)) {
      rmSync(pluginDir, { recursive: true })
    }
    renameSync(tempDir, pluginDir)

    return pluginManifest
  }

  private async computeChecksum(data: ArrayBuffer): Promise<string> {
    const hashBuffer = await crypto.subtle.digest('SHA-256', data)
    const hashArray = Array.from(new Uint8Array(hashBuffer))
    return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('')
  }

  private async verifyPlugin(plugin: Plugin, pluginDir: string): Promise<void> {
    // Check main file exists
    const mainPath = join(pluginDir, plugin.main)
    if (!existsSync(mainPath)) {
      throw new Error(`Plugin main file not found: ${plugin.main}`)
    }

    // Validate permissions are allowed
    const allowedPermissions: PluginPermission[] = [
      'fs:read',
      'fs:write',
      'net:fetch',
      'net:listen',
      'process:spawn',
      'env:read',
      'clipboard',
    ]

    for (const permission of plugin.permissions) {
      if (!allowedPermissions.includes(permission)) {
        throw new Error(`Unknown permission requested: ${permission}`)
      }
    }

    console.log(`Plugin ${plugin.name} requests permissions: ${plugin.permissions.join(', ')}`)
  }

  /**
   * Uninstall a plugin
   */
  async uninstall(name: string): Promise<void> {
    if (!this.manifest.plugins[name]) {
      throw new Error(`Plugin not installed: ${name}`)
    }

    const pluginDir = join(this.pluginsDir, name)
    if (existsSync(pluginDir)) {
      rmSync(pluginDir, { recursive: true })
    }

    delete this.manifest.plugins[name]
    this.saveManifest()

    console.log(`✓ Uninstalled ${name}`)
  }

  /**
   * Enable a plugin
   */
  enable(name: string): void {
    if (!this.manifest.plugins[name]) {
      throw new Error(`Plugin not installed: ${name}`)
    }

    this.manifest.plugins[name].enabled = true
    this.saveManifest()
    console.log(`✓ Enabled ${name}`)
  }

  /**
   * Disable a plugin
   */
  disable(name: string): void {
    if (!this.manifest.plugins[name]) {
      throw new Error(`Plugin not installed: ${name}`)
    }

    this.manifest.plugins[name].enabled = false
    this.saveManifest()
    console.log(`✓ Disabled ${name}`)
  }

  /**
   * List installed plugins
   */
  list(): Array<{ name: string; version: string; enabled: boolean }> {
    return Object.entries(this.manifest.plugins).map(([name, info]) => ({
      name,
      version: info.version,
      enabled: info.enabled,
    }))
  }

  /**
   * Update a plugin to the latest version
   */
  async update(name: string): Promise<void> {
    if (!this.manifest.plugins[name]) {
      throw new Error(`Plugin not installed: ${name}`)
    }

    await this.install(name) // Will fetch latest
    console.log(`✓ Updated ${name}`)
  }

  /**
   * Update all plugins
   */
  async updateAll(): Promise<void> {
    const plugins = Object.keys(this.manifest.plugins)
    for (const name of plugins) {
      await this.update(name)
    }
  }

  /**
   * Run a plugin hook
   */
  async runHook(hookName: keyof PluginHooks, context: Record<string, unknown>): Promise<void> {
    for (const [name, info] of Object.entries(this.manifest.plugins)) {
      if (!info.enabled) continue

      const pluginDir = join(this.pluginsDir, name)
      const manifestPath = join(pluginDir, 'craft-plugin.json')

      if (!existsSync(manifestPath)) continue

      const plugin: Plugin = JSON.parse(readFileSync(manifestPath, 'utf-8'))

      if (plugin.hooks?.[hookName]) {
        const hookPath = join(pluginDir, plugin.hooks[hookName]!)
        if (existsSync(hookPath)) {
          console.log(`Running ${name} ${hookName} hook...`)
          try {
            const hook = await import(hookPath)
            if (typeof hook.default === 'function') {
              await hook.default(context)
            }
          }
          catch (error) {
            console.error(`Error running ${name} ${hookName} hook:`, error)
            // Surface the failure so subscribers can react (e.g. show a UI
            // toast or fail the build) — previously a crashing plugin only
            // logged and continued silently.
            this.emit('plugin:error', { name, hookName, error })
          }
        }
      }
    }
  }

  /**
   * Search plugins in registry
   */
  async search(query: string): Promise<PluginRegistryEntry[]> {
    const response = await fetch(`${this.manifest.registry}/search?q=${encodeURIComponent(query)}`)
    if (!response.ok) {
      throw new Error('Failed to search plugin registry')
    }

    const results: { plugins: PluginRegistryEntry[] } = await response.json()
    return results.plugins
  }

  /**
   * Get plugin info
   */
  async info(name: string): Promise<PluginRegistryEntry> {
    const response = await fetch(`${this.manifest.registry}/plugins/${name}`)
    if (!response.ok) {
      throw new Error(`Plugin not found: ${name}`)
    }

    return response.json()
  }
}

// CLI Commands
export async function pluginCommand(args: string[]): Promise<void> {
  const [subcommand, ...rest] = args
  const manager = new PluginManager(process.cwd())

  switch (subcommand) {
    case 'add':
    case 'install':
      if (!rest[0]) {
        console.error('Usage: craft plugin add <name|url> [version]')
        process.exit(1)
      }
      await manager.install(rest[0], rest[1])
      break

    case 'remove':
    case 'uninstall':
      if (!rest[0]) {
        console.error('Usage: craft plugin remove <name>')
        process.exit(1)
      }
      await manager.uninstall(rest[0])
      break

    case 'enable':
      if (!rest[0]) {
        console.error('Usage: craft plugin enable <name>')
        process.exit(1)
      }
      manager.enable(rest[0])
      break

    case 'disable':
      if (!rest[0]) {
        console.error('Usage: craft plugin disable <name>')
        process.exit(1)
      }
      manager.disable(rest[0])
      break

    case 'list':
    case 'ls':
      const plugins = manager.list()
      if (plugins.length === 0) {
        console.log('No plugins installed')
      }
else {
        console.log('Installed plugins:')
        for (const plugin of plugins) {
          const status = plugin.enabled ? '✓' : '○'
          console.log(`  ${status} ${plugin.name}@${plugin.version}`)
        }
      }
      break

    case 'update':
      if (rest[0]) {
        await manager.update(rest[0])
      }
else {
        await manager.updateAll()
      }
      break

    case 'search':
      if (!rest[0]) {
        console.error('Usage: craft plugin search <query>')
        process.exit(1)
      }
      const results = await manager.search(rest.join(' '))
      if (results.length === 0) {
        console.log('No plugins found')
      }
else {
        console.log('Search results:')
        for (const plugin of results) {
          console.log(`  ${plugin.name} - ${plugin.description}`)
        }
      }
      break

    case 'info':
      if (!rest[0]) {
        console.error('Usage: craft plugin info <name>')
        process.exit(1)
      }
      const info = await manager.info(rest[0])
      console.log(`Name: ${info.name}`)
      console.log(`Description: ${info.description}`)
      console.log(`Latest: ${info.latest}`)
      console.log(`Versions: ${Object.keys(info.versions).join(', ')}`)
      break

    default:
      console.log(`
Craft Plugin Manager

Usage: craft plugin <command> [args]

Commands:
  add <name|url> [version]  Install a plugin
  remove <name>             Uninstall a plugin
  enable <name>             Enable a plugin
  disable <name>            Disable a plugin
  list                      List installed plugins
  update [name]             Update plugin(s)
  search <query>            Search plugin registry
  info <name>               Show plugin info
`)
  }
}

export default PluginManager
