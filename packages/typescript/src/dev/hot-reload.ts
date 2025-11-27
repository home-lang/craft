/**
 * Craft Hot Reload
 * Hot module replacement and live reload for development
 */

import { existsSync, readFileSync, watch, statSync } from 'fs'
import { join, extname, relative } from 'path'
import { createServer, IncomingMessage, ServerResponse } from 'http'
import { WebSocketServer, WebSocket } from 'ws'
import { EventEmitter } from 'events'

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
  ws: WebSocket
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
  private server: ReturnType<typeof createServer> | null = null
  private wss: WebSocketServer | null = null
  private clients: Map<string, HotReloadClient> = new Map()
  private fileVersions: Map<string, number> = new Map()
  private debounceTimers: Map<string, NodeJS.Timeout> = new Map()
  private stateSnapshots: Map<string, any> = new Map()

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
  start(): void {
    // Create HTTP server for serving HMR runtime
    this.server = createServer((req, res) => this.handleHttpRequest(req, res))

    // Create WebSocket server
    this.wss = new WebSocketServer({ server: this.server })

    this.wss.on('connection', (ws, req) => {
      const clientId = this.generateClientId()
      const platform = req.headers['x-craft-platform'] as string || 'unknown'

      const client: HotReloadClient = { ws, id: clientId, platform }
      this.clients.set(clientId, client)

      if (this.config.verbose) {
        console.log(`[HMR] Client connected: ${clientId} (${platform})`)
      }

      ws.on('message', (data) => {
        try {
          const message = JSON.parse(data.toString())
          this.handleClientMessage(client, message)
        } catch (e) {
          console.error('[HMR] Failed to parse message:', e)
        }
      })

      ws.on('close', () => {
        this.clients.delete(clientId)
        if (this.config.verbose) {
          console.log(`[HMR] Client disconnected: ${clientId}`)
        }
      })

      // Send initial state
      ws.send(JSON.stringify({
        type: 'connected',
        clientId,
        config: {
          cssOnly: this.config.cssOnly,
          preserveState: this.config.preserveState,
        },
      }))
    })

    // Start file watcher
    this.startWatching()

    this.server.listen(this.config.port, () => {
      console.log(`[HMR] Server running on ws://localhost:${this.config.port}`)
    })
  }

  /**
   * Stop the hot reload server
   */
  stop(): void {
    this.wss?.close()
    this.server?.close()

    for (const timer of this.debounceTimers.values()) {
      clearTimeout(timer)
    }

    this.clients.clear()
    this.debounceTimers.clear()
  }

  /**
   * Start watching files for changes
   */
  private startWatching(): void {
    const watchOptions = { recursive: true }

    watch(this.config.watchDir, watchOptions, (eventType, filename) => {
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
        }, 100)
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
    } else if (isHtml) {
      this.broadcastFullReload('HTML changed')
    } else if (this.config.cssOnly) {
      // Only reload CSS in cssOnly mode
      return
    } else {
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
      if (client.ws.readyState === WebSocket.OPEN) {
        client.ws.send(data)
      }
    }
  }

  /**
   * Handle HTTP request (for HMR runtime)
   */
  private handleHttpRequest(req: IncomingMessage, res: ServerResponse): void {
    if (req.url === '/hmr-runtime.js') {
      res.writeHead(200, { 'Content-Type': 'application/javascript' })
      res.end(this.getHmrRuntime())
    } else if (req.url?.startsWith('/hmr-module/')) {
      const path = req.url.replace('/hmr-module/', '')
      const fullPath = join(this.config.watchDir, path)

      if (existsSync(fullPath)) {
        res.writeHead(200, { 'Content-Type': 'application/javascript' })
        res.end(readFileSync(fullPath, 'utf-8'))
      } else {
        res.writeHead(404)
        res.end('Not found')
      }
    } else {
      res.writeHead(200, { 'Content-Type': 'text/plain' })
      res.end('Craft HMR Server')
    }
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
        location.reload();
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
      } else {
        // Link tag - add cache buster
        existing.href = existing.href.split('?')[0] + '?t=' + message.timestamp;
      }
    } else if (message.content) {
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
      } else {
        // No hot accept, need full reload
        socket.send(JSON.stringify({ type: 'decline', path: message.path }));
      }
    } catch (error) {
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
      } else if (pattern.test(filePath)) {
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
    return Math.random().toString(36).substr(2, 9)
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
  return `
<script>
  (function() {
    const script = document.createElement('script');
    script.src = '${serverUrl}/hmr-runtime.js';
    document.head.appendChild(script);
  })();
</script>
`
}

export default HotReloadServer
