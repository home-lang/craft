/**
 * Craft DevTools
 * Chrome DevTools Protocol integration and custom debugging tools
 */

import { EventEmitter } from 'events'
import type { Server, ServerWebSocket } from 'bun'

/** A connected DevTools WebSocket (Bun-native; no per-connection data). */
type DevToolsSocket = ServerWebSocket<undefined>

// Types
export interface DevToolsConfig {
  port?: number
  enableConsole?: boolean
  enableNetwork?: boolean
  enablePerformance?: boolean
  enableMemory?: boolean
  enableElements?: boolean
}

export interface ConsoleMessage {
  type: 'log' | 'warn' | 'error' | 'info' | 'debug'
  args: any[]
  timestamp: number
  stack?: string
}

export interface NetworkRequest {
  id: string
  url: string
  method: string
  headers: Record<string, string>
  body?: string
  startTime: number
  endTime?: number
  status?: number
  responseHeaders?: Record<string, string>
  responseBody?: string
  responseSize?: number
  error?: string
}

export interface PerformanceEntry {
  name: string
  entryType: 'mark' | 'measure' | 'navigation' | 'resource' | 'paint'
  startTime: number
  duration: number
  detail?: any
}

export interface MemoryInfo {
  usedJSHeapSize: number
  totalJSHeapSize: number
  jsHeapSizeLimit: number
  timestamp: number
}

// DevTools Server
export class DevToolsServer extends EventEmitter {
  private config: DevToolsConfig
  private server: Server<undefined> | null = null
  private clients: Set<DevToolsSocket> = new Set()

  // Data stores
  private consoleLogs: ConsoleMessage[] = []
  private networkRequests: Map<string, NetworkRequest> = new Map()
  private performanceEntries: PerformanceEntry[] = []
  private memorySnapshots: MemoryInfo[] = []

  constructor(config: DevToolsConfig = {}) {
    super()
    this.config = {
      port: 9222,
      enableConsole: true,
      enableNetwork: true,
      enablePerformance: true,
      enableMemory: true,
      enableElements: true,
      ...config,
    }
  }

  /**
   * Start the DevTools server
   */
  start(): void {
    // Bun.serve serves the DevTools JSON API and upgrades inspector clients to
    // WebSockets in one server — no separate `ws` WebSocketServer.
    this.server = Bun.serve({
      hostname: '127.0.0.1',
      port: this.config.port,
      fetch: (req, server) => {
        if (req.headers.get('upgrade')?.toLowerCase() === 'websocket') {
          const origin = req.headers.get('origin') || ''
          if (!this.isAllowedOrigin(origin))
            return new Response('Forbidden WebSocket origin', { status: 403 })
          if (server.upgrade(req))
            return undefined // upgraded to a WebSocket; handled below
          return new Response('WebSocket upgrade failed', { status: 400 })
        }
        return this.handleHttp(req)
      },
      websocket: {
        open: (ws) => {
          this.clients.add(ws)
          console.log('[DevTools] Client connected')
          this.sendInitialState(ws)
        },
        message: (ws, data) => {
          try {
            const message = JSON.parse(typeof data === 'string' ? data : data.toString())
            this.handleMessage(ws, message)
          }
          catch (e) {
            console.error('[DevTools] Failed to parse message:', e)
          }
        },
        close: (ws) => {
          this.clients.delete(ws)
          console.log('[DevTools] Client disconnected')
        },
      },
    })

    console.log(`[DevTools] Server running on http://localhost:${this.config.port}`)
    console.log(`[DevTools] Open chrome://inspect or devtools://devtools/bundled/inspector.html?ws=localhost:${this.config.port}`)
  }

  /**
   * Stop the DevTools server
   */
  stop(): void {
    this.server?.stop(true)
    this.server = null
    this.clients.clear()
  }

  /**
   * Handle HTTP request (DevTools JSON API)
   */
  private handleHttp(req: Request): Response {
    const { pathname } = new URL(req.url)

    // CORS headers. Devtools is dev-only; echo the request's Origin only if
    // it's a localhost variant — DevTools clients always run there in practice.
    const headers = new Headers({
      'Vary': 'Origin',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    })
    const origin = req.headers.get('origin') || ''
    if (this.isAllowedOrigin(origin))
      headers.set('Access-Control-Allow-Origin', origin)

    if (req.method === 'OPTIONS')
      return new Response(null, { status: 204, headers })

    const json = (status: number, payload: unknown): Response => {
      headers.set('Content-Type', 'application/json')
      return new Response(JSON.stringify(payload), { status, headers })
    }
    const html = (status: number, body: string): Response => {
      headers.set('Content-Type', 'text/html')
      return new Response(body, { status, headers })
    }

    if (pathname === '/json' || pathname === '/json/list') {
      return json(200, [
        {
          description: 'Craft DevTools',
          devtoolsFrontendUrl: `devtools://devtools/bundled/inspector.html?ws=localhost:${this.config.port}`,
          id: 'craft-devtools',
          title: 'Craft App',
          type: 'page',
          url: 'craft://app',
          webSocketDebuggerUrl: `ws://localhost:${this.config.port}`,
        },
      ])
    }
    if (pathname === '/json/version') {
      return json(200, {
        'Browser': 'Craft DevTools/1.0',
        'Protocol-Version': '1.3',
        'User-Agent': 'Craft',
        'V8-Version': process.versions.v8,
        'WebKit-Version': 'N/A',
      })
    }
    if (pathname === '/')
      return html(200, this.getDashboardHtml())
    if (pathname === '/api/console')
      return json(200, this.consoleLogs)
    if (pathname === '/api/network')
      return json(200, Array.from(this.networkRequests.values()))
    if (pathname === '/api/performance')
      return json(200, this.performanceEntries)
    if (pathname === '/api/memory')
      return json(200, this.memorySnapshots)
    return new Response('Not found', { status: 404, headers })
  }

  private isAllowedOrigin(origin: string): boolean {
    return origin === 'null'
      || /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/i.test(origin)
      || /^devtools:\/\//i.test(origin)
  }

  /**
   * Handle WebSocket message (CDP protocol)
   */
  private handleMessage(ws: DevToolsSocket, message: any): void {
    const { id, method, params } = message

    // Chrome DevTools Protocol handlers
    switch (method) {
      case 'Runtime.enable':
        this.send(ws, { id, result: {} })
        break

      case 'Runtime.evaluate': {
        // This server observes the app; evaluating here would execute inside
        // the privileged Bun host, not the inspected webview.
        this.send(ws, {
          id,
          error: { code: -32601, message: 'Runtime.evaluate is unavailable without a webview execution transport' },
        })
        break
      }

      case 'Console.enable':
        this.send(ws, { id, result: {} })
        // Send existing logs
        for (const log of this.consoleLogs) {
          this.send(ws, {
            method: 'Console.messageAdded',
            params: { message: this.formatConsoleMessage(log) },
          })
        }
        break

      case 'Network.enable':
        this.send(ws, { id, result: {} })
        break

      case 'Performance.enable':
        this.send(ws, { id, result: {} })
        break

      case 'HeapProfiler.enable':
        this.send(ws, { id, result: {} })
        break

      case 'HeapProfiler.takeHeapSnapshot':
        this.takeMemorySnapshot()
        this.send(ws, { id, result: {} })
        break

      case 'Page.reload':
        this.emit('reload')
        this.send(ws, { id, result: {} })
        break

      case 'DOM.getDocument':
        this.send(ws, {
          id,
          result: {
            root: {
              nodeId: 1,
              nodeType: 9,
              nodeName: '#document',
              localName: '',
              nodeValue: '',
              childNodeCount: 1,
            },
          },
        })
        break

      default:
        // Unknown method
        this.send(ws, { id, error: { code: -32601, message: `Method not found: ${method}` } })
    }
  }

  /**
   * Send message to client
   */
  private send(ws: DevToolsSocket, message: object): void {
    if (ws.readyState === 1) {
      ws.send(JSON.stringify(message))
    }
  }

  /**
   * Broadcast to all clients
   */
  private broadcast(message: object): void {
    const data = JSON.stringify(message)
    for (const client of this.clients) {
      if (client.readyState === 1) {
        client.send(data)
      }
    }
  }

  /**
   * Send initial state to new client
   */
  private sendInitialState(ws: DevToolsSocket): void {
    // Send existing console logs
    for (const log of this.consoleLogs.slice(-100)) {
      this.send(ws, {
        method: 'Console.messageAdded',
        params: { message: this.formatConsoleMessage(log) },
      })
    }
  }

  // Public API for logging

  /**
   * Log a console message
   */
  log(type: ConsoleMessage['type'], ...args: any[]): void {
    if (!this.config.enableConsole) return

    const message: ConsoleMessage = {
      type,
      args,
      timestamp: Date.now(),
      stack: new Error().stack,
    }

    this.consoleLogs.push(message)
    if (this.consoleLogs.length > 1000) {
      this.consoleLogs.shift()
    }

    this.broadcast({
      method: 'Console.messageAdded',
      params: { message: this.formatConsoleMessage(message) },
    })

    this.emit('console', message)
  }

  private formatConsoleMessage(msg: ConsoleMessage) {
    return {
      source: 'javascript',
      level: msg.type,
      text: msg.args.map((a) => (typeof a === 'object' ? JSON.stringify(a) : String(a))).join(' '),
      timestamp: msg.timestamp / 1000,
      stackTrace: msg.stack
        ? {
            callFrames: this.parseStackTrace(msg.stack),
          }
        : undefined,
    }
  }

  private parseStackTrace(stack: string) {
    return stack
      .split('\n')
      .slice(1)
      .map((line) => {
        const match = line.match(/at (\S+) \((.+):(\d+):(\d+)\)/)
        if (match) {
          return {
            functionName: match[1],
            url: match[2],
            lineNumber: parseInt(match[3], 10),
            columnNumber: parseInt(match[4], 10),
          }
        }
        return { functionName: line.trim(), url: '', lineNumber: 0, columnNumber: 0 }
      })
  }

  /**
   * Log a network request
   */
  logNetworkRequest(request: NetworkRequest): void {
    if (!this.config.enableNetwork) return

    this.networkRequests.set(request.id, request)

    this.broadcast({
      method: 'Network.requestWillBeSent',
      params: {
        requestId: request.id,
        request: {
          url: request.url,
          method: request.method,
          headers: request.headers,
          postData: request.body,
        },
        timestamp: request.startTime / 1000,
      },
    })

    this.emit('network-request', request)
  }

  /**
   * Log network response
   */
  logNetworkResponse(
    requestId: string,
    status: number,
    headers: Record<string, string>,
    body?: string
  ): void {
    if (!this.config.enableNetwork) return

    const request = this.networkRequests.get(requestId)
    if (request) {
      request.endTime = Date.now()
      request.status = status
      request.responseHeaders = headers
      request.responseBody = body
      request.responseSize = body?.length || 0
    }

    this.broadcast({
      method: 'Network.responseReceived',
      params: {
        requestId,
        response: {
          url: request?.url,
          status,
          headers,
        },
        timestamp: Date.now() / 1000,
      },
    })

    this.emit('network-response', { requestId, status })
  }

  /**
   * Log performance entry
   */
  logPerformance(entry: PerformanceEntry): void {
    if (!this.config.enablePerformance) return

    this.performanceEntries.push(entry)
    if (this.performanceEntries.length > 1000) {
      this.performanceEntries.shift()
    }

    this.emit('performance', entry)
  }

  /**
   * Take memory snapshot
   */
  takeMemorySnapshot(): MemoryInfo {
    const memUsage = typeof process !== 'undefined' && process.memoryUsage
      ? process.memoryUsage()
      : { heapUsed: 0, heapTotal: 0, external: 0 }

    const info: MemoryInfo = {
      usedJSHeapSize: memUsage.heapUsed,
      totalJSHeapSize: memUsage.heapTotal,
      jsHeapSizeLimit: memUsage.external + memUsage.heapTotal,
      timestamp: Date.now(),
    }

    this.memorySnapshots.push(info)
    if (this.memorySnapshots.length > 100) {
      this.memorySnapshots.shift()
    }

    this.emit('memory', info)
    return info
  }

  /**
   * Clear all logs
   */
  clear(): void {
    this.consoleLogs = []
    this.networkRequests.clear()
    this.performanceEntries = []
    this.memorySnapshots = []

    this.broadcast({ method: 'Console.messagesCleared', params: {} })
  }

  /**
   * Get dashboard HTML
   */
  private getDashboardHtml(): string {
    return `
<!DOCTYPE html>
<html>
<head>
  <title>Craft DevTools</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: system-ui, sans-serif; background: #1e1e1e; color: #d4d4d4; }
    .header { background: #252526; padding: 12px 16px; border-bottom: 1px solid #3c3c3c; }
    .header h1 { font-size: 16px; font-weight: 500; }
    .tabs { display: flex; background: #252526; border-bottom: 1px solid #3c3c3c; }
    .tab { padding: 8px 16px; cursor: pointer; border-bottom: 2px solid transparent; }
    .tab.active { border-bottom-color: #007acc; color: #fff; }
    .content { padding: 16px; height: calc(100vh - 88px); overflow: auto; }
    .log { padding: 4px 8px; font-family: monospace; font-size: 12px; border-bottom: 1px solid #3c3c3c; }
    .log.error { color: #f48771; }
    .log.warn { color: #cca700; }
    .log.info { color: #75beff; }
    .request { padding: 8px; border-bottom: 1px solid #3c3c3c; }
    .request-url { font-family: monospace; font-size: 12px; }
    .request-status { font-size: 11px; color: #888; }
    .status-200 { color: #89d185; }
    .status-400, .status-500 { color: #f48771; }
  </style>
</head>
<body>
  <div class="header"><h1>Craft DevTools</h1></div>
  <div class="tabs">
    <div class="active tab" data-tab="console">Console</div>
    <div class="tab" data-tab="network">Network</div>
    <div class="tab" data-tab="performance">Performance</div>
    <div class="tab" data-tab="memory">Memory</div>
  </div>
  <div class="content" id="content"></div>
  <script>
    const ws = new WebSocket('ws://localhost:${this.config.port}');
    const logs = [];
    const requests = [];
    let activeTab = 'console';

    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      if (msg.method === 'Console.messageAdded') {
        logs.push(msg.params.message);
        if (activeTab === 'console') render();
      }
else if (msg.method === 'Network.requestWillBeSent') {
        requests.push({ ...msg.params, status: 'pending' });
        if (activeTab === 'network') render();
      }
else if (msg.method === 'Network.responseReceived') {
        const req = requests.find(r => r.requestId === msg.params.requestId);
        if (req) req.status = msg.params.response.status;
        if (activeTab === 'network') render();
      }
    };

    document.querySelectorAll('.tab').forEach(tab => {
      tab.onclick = () => {
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        activeTab = tab.dataset.tab;
        render();
      };
    });

    function esc(s) {
      return String(s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
    }

    function render() {
      const content = document.getElementById('content');
      if (activeTab === 'console') {
        content.innerHTML = logs.map(l =>
          '<div class="log ' + esc(l.level) + '">' + esc(l.text) + '</div>'
        ).join('');
      }
      else if (activeTab === 'network') {
        content.innerHTML = requests.map(r =>
          '<div class="request">' +
          '<div class="request-url">' + esc(r.request.method) + ' ' + esc(r.request.url) + '</div>' +
          '<div class="request-status status-' + esc(String(r.status)) + '">' + esc(String(r.status)) + '</div>' +
          '</div>'
        ).join('');
      }
      else {
        content.innerHTML = '<p>Coming soon...</p>';
      }
      content.scrollTop = content.scrollHeight;
    }

    // Load initial data
    fetch('/api/console').then(r => r.json()).then(data => {
      data.forEach(l => logs.push({ level: l.type, text: l.args.join(' ') }));
      render();
    });
  </script>
</body>
</html>
`
  }
}

function escapeHtml(unsafe: string): string {
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
}

// Create global devtools instance for easy access
let globalDevTools: DevToolsServer | null = null

export function getDevTools(): DevToolsServer {
  if (!globalDevTools) {
    globalDevTools = new DevToolsServer()
  }
  return globalDevTools
}

export default DevToolsServer
