/**
 * Craft Process API
 * Provides process management and system information
 */

/**
 * Process environment variables
 */
export const env: Record<string, string | undefined> = typeof process !== 'undefined'
  ? process.env
  : {}

/**
 * Current platform
 */
export type Platform = 'darwin' | 'macos' | 'win32' | 'windows' | 'linux' | 'ios' | 'android' | 'unknown'

/**
 * Get current platform
 */
export function getPlatform(): Platform {
  // Check window.craft first for mobile platforms
  if (typeof window !== 'undefined' && window.craft) {
    const info = (window.craft as any)._platform
    if (info === 'ios' || info === 'android') {
      return info
    }
  }

  // Node.js/Bun
  if (typeof process !== 'undefined' && process.platform) {
    return process.platform as Platform
  }

  // Browser detection fallback
  if (typeof navigator !== 'undefined') {
    const ua = navigator.userAgent.toLowerCase()
    if (ua.includes('mac')) return 'darwin'
    if (ua.includes('win')) return 'win32'
    if (ua.includes('linux')) return 'linux'
    if (ua.includes('iphone') || ua.includes('ipad')) return 'ios'
    if (ua.includes('android')) return 'android'
  }

  return 'unknown'
}

/**
 * Check if running on desktop
 */
export function isDesktop(): boolean {
  const platform = getPlatform()
  return platform === 'darwin' || platform === 'win32' || platform === 'linux'
}

/**
 * Check if running on mobile
 */
export function isMobile(): boolean {
  const platform = getPlatform()
  return platform === 'ios' || platform === 'android'
}

/**
 * Check if running in Craft environment
 */
export function isCraft(): boolean {
  return typeof window !== 'undefined' && typeof window.craft !== 'undefined'
}

/**
 * System information
 */
export interface SystemInfo {
  platform: Platform
  arch: string
  osVersion: string
  hostname: string
  cpuCount: number
  totalMemory: number
  freeMemory: number
  uptime: number
}

/**
 * Get system information
 */
export async function getSystemInfo(): Promise<SystemInfo> {
  if (typeof window !== 'undefined' && window.craft) {
    const info = await (window.craft as any).bridge?.call('process.getSystemInfo')
    return info as SystemInfo
  }

  // Node.js fallback
  if (typeof process !== 'undefined') {
    const os = await import('node:os')
    return {
      platform: process.platform as Platform,
      arch: process.arch,
      osVersion: os.release(),
      hostname: os.hostname(),
      cpuCount: os.cpus().length,
      totalMemory: os.totalmem(),
      freeMemory: os.freemem(),
      uptime: os.uptime()
    }
  }

  return {
    platform: getPlatform(),
    arch: 'unknown',
    osVersion: 'unknown',
    hostname: 'unknown',
    cpuCount: navigator?.hardwareConcurrency || 1,
    totalMemory: 0,
    freeMemory: 0,
    uptime: 0
  }
}

/**
 * Execute shell command (requires Craft environment)
 */
export interface ExecOptions {
  cwd?: string
  env?: Record<string, string>
  timeout?: number
  maxBuffer?: number
}

export interface ExecResult {
  stdout: string
  stderr: string
  exitCode: number
}

export async function exec(command: string, options?: ExecOptions): Promise<ExecResult> {
  if (typeof window !== 'undefined' && window.craft) {
    return (window.craft as any).bridge?.call('process.exec', {
      command,
      ...options
    })
  }

  // Node.js fallback
  const { exec: nodeExec } = await import('node:child_process')
  const { promisify } = await import('node:util')
  const execPromise = promisify(nodeExec)

  try {
    const { stdout, stderr } = await execPromise(command, {
      cwd: options?.cwd,
      env: options?.env ? { ...process.env, ...options.env } : undefined,
      timeout: options?.timeout,
      maxBuffer: options?.maxBuffer || 1024 * 1024
    })
    return { stdout, stderr, exitCode: 0 }
  } catch (error: any) {
    return {
      stdout: error.stdout || '',
      stderr: error.stderr || error.message,
      exitCode: error.code || 1
    }
  }
}

/**
 * Spawn a child process
 */
export interface SpawnOptions {
  cwd?: string
  env?: Record<string, string>
  shell?: boolean
}

export class ChildProcess {
  private processId: string | null = null
  private onStdoutHandlers: ((data: string) => void)[] = []
  private onStderrHandlers: ((data: string) => void)[] = []
  private onExitHandlers: ((code: number) => void)[] = []

  constructor(
    private command: string,
    private args: string[] = [],
    private options: SpawnOptions = {}
  ) {}

  /**
   * Start the process
   */
  async start(): Promise<void> {
    if (typeof window !== 'undefined' && window.craft) {
      const result = await (window.craft as any).bridge?.call('process.spawn', {
        command: this.command,
        args: this.args,
        ...this.options
      })
      this.processId = result.pid

      // Set up event listeners
      window.addEventListener('craft:process:stdout' as any, ((event: CustomEvent) => {
        if (event.detail.pid === this.processId) {
          this.onStdoutHandlers.forEach(h => h(event.detail.data))
        }
      }) as EventListener)

      window.addEventListener('craft:process:stderr' as any, ((event: CustomEvent) => {
        if (event.detail.pid === this.processId) {
          this.onStderrHandlers.forEach(h => h(event.detail.data))
        }
      }) as EventListener)

      window.addEventListener('craft:process:exit' as any, ((event: CustomEvent) => {
        if (event.detail.pid === this.processId) {
          this.onExitHandlers.forEach(h => h(event.detail.code))
        }
      }) as EventListener)

      return
    }

    throw new Error('spawn() requires Craft environment')
  }

  /**
   * Write to stdin
   */
  async write(data: string): Promise<void> {
    if (typeof window !== 'undefined' && window.craft && this.processId) {
      await (window.craft as any).bridge?.call('process.stdin', {
        pid: this.processId,
        data
      })
    }
  }

  /**
   * Kill the process
   */
  async kill(signal: string = 'SIGTERM'): Promise<void> {
    if (typeof window !== 'undefined' && window.craft && this.processId) {
      await (window.craft as any).bridge?.call('process.kill', {
        pid: this.processId,
        signal
      })
    }
  }

  /**
   * Listen for stdout data
   */
  onStdout(handler: (data: string) => void): () => void {
    this.onStdoutHandlers.push(handler)
    return () => {
      const idx = this.onStdoutHandlers.indexOf(handler)
      if (idx >= 0) this.onStdoutHandlers.splice(idx, 1)
    }
  }

  /**
   * Listen for stderr data
   */
  onStderr(handler: (data: string) => void): () => void {
    this.onStderrHandlers.push(handler)
    return () => {
      const idx = this.onStderrHandlers.indexOf(handler)
      if (idx >= 0) this.onStderrHandlers.splice(idx, 1)
    }
  }

  /**
   * Listen for exit
   */
  onExit(handler: (code: number) => void): () => void {
    this.onExitHandlers.push(handler)
    return () => {
      const idx = this.onExitHandlers.indexOf(handler)
      if (idx >= 0) this.onExitHandlers.splice(idx, 1)
    }
  }
}

/**
 * Spawn a child process
 */
export function spawn(
  command: string,
  args?: string[],
  options?: SpawnOptions
): ChildProcess {
  return new ChildProcess(command, args, options)
}

/**
 * Get current working directory
 */
export function cwd(): string {
  if (typeof process !== 'undefined') {
    return process.cwd()
  }
  return '/'
}

/**
 * Get home directory
 */
export async function homeDir(): Promise<string> {
  if (typeof window !== 'undefined' && window.craft) {
    return (window.craft as any).bridge?.call('process.homeDir')
  }

  if (typeof process !== 'undefined') {
    const os = await import('node:os')
    return os.homedir()
  }

  return '/'
}

/**
 * Get temp directory
 */
export async function tempDir(): Promise<string> {
  if (typeof window !== 'undefined' && window.craft) {
    return (window.craft as any).bridge?.call('process.tempDir')
  }

  if (typeof process !== 'undefined') {
    const os = await import('node:os')
    return os.tmpdir()
  }

  return '/tmp'
}

/**
 * Exit the application
 */
export function exit(code: number = 0): void {
  if (typeof window !== 'undefined' && window.craft?.app) {
    window.craft.app.quit()
  } else if (typeof process !== 'undefined') {
    process.exit(code)
  }
}

/**
 * Get command line arguments
 */
export function argv(): string[] {
  if (typeof process !== 'undefined') {
    return process.argv
  }
  return []
}

/**
 * Open URL or file in default application
 */
export async function open(target: string): Promise<void> {
  if (typeof window !== 'undefined' && window.craft) {
    await (window.craft as any).bridge?.call('process.open', { target })
    return
  }

  // Node.js fallback using platform-specific commands
  const platform = getPlatform()
  let command: string

  switch (platform) {
    case 'darwin':
      command = 'open'
      break
    case 'win32':
      command = 'start'
      break
    case 'linux':
      command = 'xdg-open'
      break
    default:
      throw new Error(`Unsupported platform: ${platform}`)
  }

  await exec(`${command} "${target}"`)
}

const processApi: {
  env: typeof env
  getPlatform: typeof getPlatform
  isDesktop: typeof isDesktop
  isMobile: typeof isMobile
  isCraft: typeof isCraft
  getSystemInfo: typeof getSystemInfo
  exec: typeof exec
  spawn: typeof spawn
  cwd: typeof cwd
  homeDir: typeof homeDir
  tempDir: typeof tempDir
  exit: typeof exit
  argv: typeof argv
  open: typeof open
} = {
  env: env,
  getPlatform: getPlatform,
  isDesktop: isDesktop,
  isMobile: isMobile,
  isCraft: isCraft,
  getSystemInfo: getSystemInfo,
  exec: exec,
  spawn: spawn,
  cwd: cwd,
  homeDir: homeDir,
  tempDir: tempDir,
  exit: exit,
  argv: argv,
  open: open
}

export default processApi
