/**
 * Craft Hot Reload
 * Hot module replacement and live reload for development
 */

import { existsSync, readFileSync, watch, type FSWatcher } from 'fs'
import { extname, join, relative, resolve } from 'path'
import { EventEmitter } from 'events'
import type { Server, ServerWebSocket } from 'bun'
import { secureUUID } from '../bridge/ids'

/** Per-connection state carried on each Bun WebSocket (set at upgrade). */
interface HmrSocketData {
  id: string
  platform: string
}

// Types
export interface HotReloadConfig {
  port?: number
  watchDir: string
  extensions?: string[]
  ignored?: (string | RegExp)[]
  cssOnly?: boolean
  preserveState?: boolean
  verbose?: boolean
}

export interface HotReloadClient {
  ws: ServerWebSocket<HmrSocketData>
  id: string
  platform: string
}

export interface FileChange {
  path: string
  type: 'add' | 'change' | 'unlink'
  timestamp: number
}

// Hot Reload Server
export class HotReloadServer extends EventEmitter {
  private config: HotReloadConfig
  private server: Server<HmrSocketData> | null = null
  private clients: Map<string, HotReloadClient> = new Map()
  private fileVersions: Map<string, number> = new Map()
  private debounceTimers: Map<string, NodeJS.Timeout> = new Map()
  private stateSnapshots: Map<string, any> = new Map()
  // Track the FSWatcher so stop() can release it. The previous version
  // dropped the return value of fs.watch, leaving the OS handle open
  // forever after stop().
  private watcher: FSWatcher | null = null

  constructor(config: HotReloadConfig) {
    super()
    this.config = {
      port: 3001,
      extensions: ['.ts', '.tsx', '.js', '.jsx', '.css', '.html', '.vue', '.svelte'],
      ignored: [/node_modules/, /\.git/, /dist/, /build/],
      cssOnly: false,
      preserveState: true,
      verbose: false,
      ...config,
    }
  }

  /**
   * Start the hot reload server
   */
  /**
   * The port the server is actually listening on. With `port: 0` the OS
   * assigns a free port at start(); this resolves to that concrete value.
   */
  get port(): number {
    return this.server?.port ?? this.config.port ?? 0
  }

  start(): void {
    // Bun.serve handles HTTP (HMR runtime) and WebSocket upgrades in one
    // server — no separate `ws` WebSocketServer. Per-connection identity is
    // attached at upgrade via `data` and read back off `ws.data`.
    this.server = Bun.serve<HmrSocketData>({
      port: this.config.port,
      fetch: (req, server) => {
        const platform = req.headers.get('x-craft-platform') || 'unknown'
        if (server.upgrade(req, { data: { id: this.generateClientId(), platform } }))
          return undefined // upgraded to a WebSocket; handled below
        return this.handleHttpRequest(req)
      },
      websocket: {
        open: (ws) => {
          const client: HotReloadClient = { ws, id: ws.data.id, platform: ws.data.platform }
          this.clients.set(ws.data.id, client)

          if (this.config.verbose)
            console.log(`[HMR] Client connected: ${ws.data.id} (${ws.data.platform})`)

          ws.send(JSON.stringify({
            type: 'connected',
            clientId: ws.data.id,
            config: {
              cssOnly: this.config.cssOnly,
              preserveState: this.config.preserveState,
            },
          }))
        },
        message: (ws, data) => {
          const client = this.clients.get(ws.data.id)
          if (!client)
            return
          try {
            const message = JSON.parse(typeof data === 'string' ? data : data.toString())
            this.handleClientMessage(client, message)
          }
          catch (e) {
            console.error('[HMR] Failed to parse message:', e)
          }
        },
        close: (ws) => {
          this.clients.delete(ws.data.id)
          if (this.config.verbose)
            console.log(`[HMR] Client disconnected: ${ws.data.id}`)
        },
      },
    })

    // Start file watcher
    this.startWatching()

    console.log(`[HMR] Server running on ws://localhost:${this.config.port}`)
  }

  /**
   * Stop the hot reload server
   */
  /**
   * Stop the hot-reload server and release every resource it acquired.
   *
   * Returns a Promise so callers that need to know when the server has
   * actually torn down (tests, lifecycle managers) can `await stop()`.
   * The return value is non-breaking: synchronous callers can still
   * fire-and-forget `server.stop()`.
   */
  async stop(): Promise<void> {
    // Release the OS-level filesystem watcher; without this stop() left
    // the inotify/FSEvents handle open forever even though the
    // websocket and HTTP servers had been torn down.
    this.watcher?.close()
    this.watcher = null

    for (const timer of this.debounceTimers.values()) {
      clearTimeout(timer)
    }
    this.debounceTimers.clear()

    // Tear down the server, closing active WebSocket + HTTP connections
    // (Bun.serve owns both). `stop(true)` forces open sockets closed so a
    // lingering HMR client can't keep the process alive after stop().
    this.server?.stop(true)
    this.server = null
    this.clients.clear()
  }

  /**
   * Start watching files for changes. Stores the FSWatcher reference so
   * stop() can release it.
   */
  private startWatching(): void {
    const watchOptions = { recursive: true }

    this.watcher = watch(this.config.watchDir, watchOptions, (eventType, filename) => {
      if (!filename) return

      const fullPath = join(this.config.watchDir, filename)
      const ext = extname(filename)

      // Check if file should be ignored
      if (this.shouldIgnore(fullPath)) return

      // Check if extension is watched
      if (!this.config.extensions!.includes(ext)) return

      // Debounce rapid changes
      const existingTimer = this.debounceTimers.get(fullPath)
      if (existingTimer) {
        clearTimeout(existingTimer)
      }

      this.debounceTimers.set(
        fullPath,
        setTimeout(() => {
          this.handleFileChange(fullPath, eventType as 'rename' | 'change')
        }, 100),
      )
    })
  }

  /**
   * Handle file change
   */
  private handleFileChange(filePath: string, eventType: 'rename' | 'change'): void {
    const exists = existsSync(filePath)
    const changeType = eventType === 'rename' ? (exists ? 'add' : 'unlink') : 'change'

    const change: FileChange = {
      path: relative(this.config.watchDir, filePath),
      type: changeType,
      timestamp: Date.now(),
    }

    // Update version
    const version = (this.fileVersions.get(filePath) || 0) + 1
    this.fileVersions.set(filePath, version)

    if (this.config.verbose) {
      console.log(`[HMR] ${change.type}: ${change.path}`)
    }

    this.emit('change', change)

    // Determine update type
    const ext = extname(filePath)
    const isCss = ext === '.css' || ext === '.scss' || ext === '.less'
    const isHtml = ext === '.html'

    if (isCss) {
      this.broadcastCssUpdate(change, filePath)
    }
else if (isHtml) {
      this.broadcastFullReload('HTML changed')
    }
else if (this.config.cssOnly) {
      // Only reload CSS in cssOnly mode
      return
    }
else {
      this.broadcastHotUpdate(change, filePath, version)
    }
  }

  /**
   * Broadcast CSS update (no full reload needed)
   */
  private broadcastCssUpdate(change: FileChange, filePath: string): void {
    let content = ''
    if (change.type !== 'unlink' && existsSync(filePath)) {
      content = readFileSync(filePath, 'utf-8')
    }

    this.broadcast({
      type: 'css-update',
      path: change.path,
      content,
      timestamp: change.timestamp,
    })
  }

  /**
   * Broadcast hot module update
   */
  private broadcastHotUpdate(change: FileChange, filePath: string, version: number): void {
    let content = ''
    if (change.type !== 'unlink' && existsSync(filePath)) {
      content = readFileSync(filePath, 'utf-8')
    }

    this.broadcast({
      type: 'hot-update',
      path: change.path,
      content,
      version,
      timestamp: change.timestamp,
      acceptDeps: this.getAcceptDependencies(filePath),
    })
  }

  /**
   * Broadcast full reload
   */
  private broadcastFullReload(reason: string): void {
    this.broadcast({
      type: 'full-reload',
      reason,
      timestamp: Date.now(),
    })
  }

  /**
   * Broadcast message to all clients
   */
  private broadcast(message: object): void {
    const data = JSON.stringify(message)

    for (const client of this.clients.values()) {
      // Bun's ServerWebSocket.readyState: 1 === OPEN (WebSocket.OPEN).
      if (client.ws.readyState === 1) {
        client.ws.send(data)
      }
    }
  }

  /**
   * Handle HTTP request (for HMR runtime).
   *
   * `/hmr-module/<path>` previously joined the user-supplied path with
   * `watchDir` and read it — letting any client on the dev port read
   * arbitrary files via `../../etc/passwd`. We now:
   *   - decode percent-encodes (so `..%2F` is caught),
   *   - reject any segment containing `..` or null bytes,
   *   - resolve the result and require it to live under `watchDir` (this
   *     also blocks symlink escapes that resolve outside the root).
   *
   * Anything else returns 403 — silently 404'ing made traversal probes
   * indistinguishable from "file not found".
   */
  private handleHttpRequest(req: Request): Response {
    const { pathname } = new URL(req.url)
    if (pathname === '/hmr-runtime.js') {
      return new Response(this.getHmrRuntime(), {
        headers: { 'Content-Type': 'application/javascript' },
      })
    }
    if (pathname.startsWith('/hmr-module/')) {
      const rawPath = pathname.replace('/hmr-module/', '')
      const safePath = this.resolveHmrModulePath(rawPath)
      if (!safePath)
        return new Response('Forbidden', { status: 403, headers: { 'Content-Type': 'text/plain' } })
      if (existsSync(safePath)) {
        return new Response(readFileSync(safePath, 'utf-8'), {
          headers: { 'Content-Type': 'application/javascript' },
        })
      }
      return new Response('Not found', { status: 404 })
    }
    return new Response('Craft HMR Server', { headers: { 'Content-Type': 'text/plain' } })
  }

  /**
   * Resolve an HMR-module URL path against `watchDir`. Returns null when
   * the path is empty, contains traversal sequences, embeds NULs, or
   * resolves outside the watch root. Exposed as a method so the test
   * suite can exercise the validator directly.
   */
  private resolveHmrModulePath(rawPath: string): string | null {
    if (!rawPath) return null
    let decoded: string
    try {
      decoded = decodeURIComponent(rawPath)
    }
    catch {
      return null
    }
    if (decoded.includes('\0')) return null
    // Reject `..` and absolute paths up front — even though `resolve` +
    // containment check would catch them, failing early avoids touching
    // the filesystem with attacker-controlled segments.
    if (decoded.split(/[/\\]/).some(seg => seg === '..')) return null
    if (decoded.startsWith('/') || /^[a-zA-Z]:[/\\]/.test(decoded)) return null

    const watchRoot = resolve(this.config.watchDir)
    const candidate = resolve(watchRoot, decoded)
    // Require the resolved path to be either equal to, or directly under,
    // the watch root.
    if (candidate !== watchRoot && !candidate.startsWith(watchRoot + (process.platform === 'win32' ? '\\' : '/'))) {
      return null
    }
    return candidate
  }

  /**
   * Handle client message
   */
  private handleClientMessage(client: HotReloadClient, message: any): void {
    switch (message.type) {
      case 'state-snapshot':
        // Client sends state before update
        if (this.config.preserveState) {
          this.stateSnapshots.set(client.id, message.state)
        }
        break

      case 'accept':
        // Module accepted update
        if (this.config.verbose) {
          console.log(`[HMR] Update accepted: ${message.path}`)
        }
        break

      case 'decline':
        // Module declined update, need full reload
        this.broadcastFullReload(`Module ${message.path} declined update`)
        break

      case 'error':
        console.error(`[HMR] Client error:`, message.error)
        break
    }
  }

  /**
   * Get HMR runtime code for injection into client
   */
  private getHmrRuntime(): string {
    return `
// Craft HMR Runtime
(function() {
  const socket = new WebSocket('ws://localhost:${this.config.port}');
  const modules = new Map();
  const hotState = new Map();
  let reloadTimer = null;

  socket.onopen = () => {
    console.log('[HMR] Connected');
  };

  socket.onmessage = (event) => {
    const message = JSON.parse(event.data);

    switch (message.type) {
      case 'css-update':
        handleCssUpdate(message);
        break;
      case 'hot-update':
        handleHotUpdate(message);
        break;
      case 'full-reload':
        console.log('[HMR] Full reload:', message.reason);
        if (!reloadTimer) {
          reloadTimer = setTimeout(() => {
            location.reload();
          }, 100); // Debounce 100ms to batch rapid changes
        }
        break;
      case 'connected':
        console.log('[HMR] Client ID:', message.clientId);
        break;
    }
  };

  socket.onclose = () => {
    console.log('[HMR] Disconnected, attempting reconnect...');
    setTimeout(() => location.reload(), 1000);
  };

  function handleCssUpdate(message) {
    // Find existing style tag or link
    const existing = document.querySelector(\`[data-hmr-path="\${message.path}"]\`);

    if (existing) {
      if (existing.tagName === 'STYLE') {
        existing.textContent = message.content;
      }
else {
        // Link tag - add cache buster
        existing.href = \`\${existing.href.split('?')[0]}?t=\${message.timestamp}\`;
      }
    }
else if (message.content) {
      // Create new style tag
      const style = document.createElement('style');
      style.setAttribute('data-hmr-path', message.path);
      style.textContent = message.content;
      document.head.appendChild(style);
    }

    console.log('[HMR] CSS updated:', message.path);
  }

  function handleHotUpdate(message) {
    // Save component state before update
    const state = captureState();
    socket.send(JSON.stringify({ type: 'state-snapshot', state }));

    try {
      // Try to hot replace module
      const module = modules.get(message.path);
      if (module && module.hot && module.hot.accept) {
        // Module can accept its own updates
        evalModule(message.content, message.path);
        socket.send(JSON.stringify({ type: 'accept', path: message.path }));
        console.log('[HMR] Module updated:', message.path);

        // Restore state
        restoreState(state);
      }
else {
        // No hot accept, need full reload
        socket.send(JSON.stringify({ type: 'decline', path: message.path }));
      }
    }
catch (error) {
      console.error('[HMR] Update failed:', error);
      socket.send(JSON.stringify({ type: 'error', error: error.message }));
      location.reload();
    }
  }

  function captureState() {
    // Capture form inputs, scroll positions, etc.
    const state = {
      scroll: { x: window.scrollX, y: window.scrollY },
      inputs: {},
      focus: document.activeElement?.id,
    };

    document.querySelectorAll('input, textarea, select').forEach((el, i) => {
      const id = el.id || \`hmr-input-\${i}\`;
      state.inputs[id] = el.value;
    });

    return state;
  }

  function restoreState(state) {
    if (!state) return;

    // Restore scroll position
    window.scrollTo(state.scroll.x, state.scroll.y);

    // Restore input values
    for (const [id, value] of Object.entries(state.inputs)) {
      const el = document.getElementById(id) || document.querySelector(\`[data-hmr-id="\${id}"]\`);
      if (el) el.value = value;
    }

    // Restore focus
    if (state.focus) {
      document.getElementById(state.focus)?.focus();
    }
  }

  function evalModule(code, path) {
    const module = { exports: {}, hot: { accept: null, dispose: null, data: hotState.get(path) } };
    modules.set(path, module);

    const fn = new Function('module', 'exports', 'require', code);
    fn(module, module.exports, (dep) => modules.get(dep)?.exports);

    return module.exports;
  }

  // Expose HMR API
  window.__HMR__ = {
    modules,
    hotState,
    accept: (path, callback) => {
      const module = modules.get(path);
      if (module) module.hot.accept = callback;
    },
    dispose: (path, callback) => {
      const module = modules.get(path);
      if (module) module.hot.dispose = callback;
    },
  };
})();
`
  }

  private shouldIgnore(filePath: string): boolean {
    for (const pattern of this.config.ignored!) {
      if (typeof pattern === 'string') {
        if (filePath.includes(pattern)) return true
      }
else if (pattern.test(filePath)) {
        return true
      }
    }
    return false
  }

  private getAcceptDependencies(_filePath: string): string[] {
    // In a real implementation, this would analyze imports
    return []
  }

  private generateClientId(): string {
    // secureUUID gives us 122 bits of entropy versus the 30-ish bits
    // Math.random produced — overkill for a dev server, but the helper
    // already exists and avoids any chance of two simultaneously-
    // connected clients colliding on the same id.
    return secureUUID()
  }

  /**
   * Get connected clients count
   */
  getClientCount(): number {
    return this.clients.size
  }

  /**
   * Get list of connected clients
   */
  getClients(): Array<{ id: string; platform: string }> {
    return Array.from(this.clients.values()).map((c) => ({
      id: c.id,
      platform: c.platform,
    }))
  }
}

/**
 * Create HMR client code for injection
 */
export function createHmrClient(serverUrl: string): string {
  // Sanitize URL to prevent script injection
  const sanitized = serverUrl.replace(/['"<>&]/g, '')
  return `
<script>
  (function() {
    const script = document.createElement('script');
    script.src = '${sanitized}/hmr-runtime.js';
    document.head.appendChild(script);
  })();
</script>
`
}

export default HotReloadServer
