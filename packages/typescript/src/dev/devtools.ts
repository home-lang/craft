/**
 * Craft DevTools
 * Chrome DevTools Protocol integration and custom debugging tools
 */

import { createServer, IncomingMessage, ServerResponse } from 'http'
import { WebSocketServer, WebSocket } from 'ws'
import { EventEmitter } from 'events'

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
  private server: ReturnType<typeof createServer> | null = null
  private wss: WebSocketServer | null = null
  private clients: Set<WebSocket> = new Set()

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
    this.server = createServer((req, res) => this.handleHttp(req, res))
    this.wss = new WebSocketServer({ server: this.server })

    this.wss.on('connection', (ws) => {
      this.clients.add(ws)
      console.log('[DevTools] Client connected')

      // Send current state
      this.sendInitialState(ws)

      ws.on('message', (data) => {
        try {
          const message = JSON.parse(data.toString())
          this.handleMessage(ws, message)
        } catch (e) {
          console.error('[DevTools] Failed to parse message:', e)
        }
      })

      ws.on('close', () => {
        this.clients.delete(ws)
        console.log('[DevTools] Client disconnected')
      })
    })

    this.server.listen(this.config.port, () => {
      console.log(`[DevTools] Server running on http://localhost:${this.config.port}`)
      console.log(`[DevTools] Open chrome://inspect or devtools://devtools/bundled/inspector.html?ws=localhost:${this.config.port}`)
    })
  }

  /**
   * Stop the DevTools server
   */
  stop(): void {
    this.wss?.close()
    this.server?.close()
    this.clients.clear()
  }

  /**
   * Handle HTTP request (DevTools JSON API)
   */
  private handleHttp(req: IncomingMessage, res: ServerResponse): void {
    const url = req.url || '/'

    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*')
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type')

    if (req.method === 'OPTIONS') {
      res.writeHead(204)
      res.end()
      return
    }

    if (url === '/json' || url === '/json/list') {
      // Chrome DevTools discovery endpoint
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(
        JSON.stringify([
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
      )
    } else if (url === '/json/version') {
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(
        JSON.stringify({
          Browser: 'Craft DevTools/1.0',
          'Protocol-Version': '1.3',
          'User-Agent': 'Craft',
          'V8-Version': process.versions.v8,
          'WebKit-Version': 'N/A',
        })
      )
    } else if (url === '/') {
      // Dashboard
      res.writeHead(200, { 'Content-Type': 'text/html' })
      res.end(this.getDashboardHtml())
    } else if (url === '/api/console') {
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify(this.consoleLogs))
    } else if (url === '/api/network') {
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify(Array.from(this.networkRequests.values())))
    } else if (url === '/api/performance') {
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify(this.performanceEntries))
    } else if (url === '/api/memory') {
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify(this.memorySnapshots))
    } else {
      res.writeHead(404)
      res.end('Not found')
    }
  }

  /**
   * Handle WebSocket message (CDP protocol)
   */
  private handleMessage(ws: WebSocket, message: any): void {
    const { id, method, params } = message

    // Chrome DevTools Protocol handlers
    switch (method) {
      case 'Runtime.enable':
        this.send(ws, { id, result: {} })
        break

      case 'Runtime.evaluate':
        try {
          const result = eval(params.expression)
          this.send(ws, {
            id,
            result: {
              result: {
                type: typeof result,
                value: result,
                description: String(result),
              },
            },
          })
        } catch (e: any) {
          this.send(ws, {
            id,
            result: {
              exceptionDetails: {
                text: e.message,
                exception: { type: 'object', className: 'Error', description: e.stack },
              },
            },
          })
        }
        break

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
  private send(ws: WebSocket, message: object): void {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(message))
    }
  }

  /**
   * Broadcast to all clients
   */
  private broadcast(message: object): void {
    const data = JSON.stringify(message)
    for (const client of this.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(data)
      }
    }
  }

  /**
   * Send initial state to new client
   */
  private sendInitialState(ws: WebSocket): void {
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
            lineNumber: parseInt(match[3]),
            columnNumber: parseInt(match[4]),
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
    const memUsage = process.memoryUsage()

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
    <div class="tab active" data-tab="console">Console</div>
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
      } else if (msg.method === 'Network.requestWillBeSent') {
        requests.push({ ...msg.params, status: 'pending' });
        if (activeTab === 'network') render();
      } else if (msg.method === 'Network.responseReceived') {
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

    function render() {
      const content = document.getElementById('content');
      if (activeTab === 'console') {
        content.innerHTML = logs.map(l =>
          '<div class="log ' + l.level + '">' + l.text + '</div>'
        ).join('');
      } else if (activeTab === 'network') {
        content.innerHTML = requests.map(r =>
          '<div class="request">' +
          '<div class="request-url">' + r.request.method + ' ' + r.request.url + '</div>' +
          '<div class="request-status status-' + r.status + '">' + r.status + '</div>' +
          '</div>'
        ).join('');
      } else {
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

// Create global devtools instance for easy access
let globalDevTools: DevToolsServer | null = null

export function getDevTools(): DevToolsServer {
  if (!globalDevTools) {
    globalDevTools = new DevToolsServer()
  }
  return globalDevTools
}

export default DevToolsServer
