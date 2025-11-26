/**
 * Craft HTTP Client API
 * Provides native HTTP client through the Craft bridge
 * Bypasses CORS restrictions when running in Craft
 */

import type { CraftHttpAPI } from '../types'

/**
 * HTTP API implementation
 * Uses native HTTP client through the Craft bridge
 */
export const http: CraftHttpAPI = {
  /**
   * Fetch resource (CORS-free in Craft environment)
   */
  async fetch(url: string, options?: RequestInit): Promise<Response> {
    if (typeof window !== 'undefined' && window.craft?.http) {
      return window.craft.http.fetch(url, options)
    }
    // Browser/Node fallback
    return globalThis.fetch(url, options)
  },

  /**
   * Download file with progress tracking
   */
  async download(
    url: string,
    destination: string,
    onProgress?: (progress: { loaded: number; total: number }) => void
  ): Promise<void> {
    if (typeof window !== 'undefined' && window.craft?.http) {
      return window.craft.http.download(url, destination, onProgress)
    }
    throw new Error('Download API requires Craft environment')
  },

  /**
   * Upload file with progress tracking
   */
  async upload(
    url: string,
    filePath: string,
    onProgress?: (progress: { loaded: number; total: number }) => void
  ): Promise<Response> {
    if (typeof window !== 'undefined' && window.craft?.http) {
      return window.craft.http.upload(url, filePath, onProgress)
    }
    throw new Error('Upload API requires Craft environment')
  }
}

/**
 * Extended HTTP client with additional features
 */
export class HttpClient {
  private baseUrl: string
  private defaultHeaders: Record<string, string>
  private timeout: number

  constructor(options: HttpClientOptions = {}) {
    this.baseUrl = options.baseUrl || ''
    this.defaultHeaders = options.headers || {}
    this.timeout = options.timeout || 30000
  }

  /**
   * Make GET request
   */
  async get<T = unknown>(path: string, options?: RequestOptions): Promise<HttpResponse<T>> {
    return this.request<T>('GET', path, options)
  }

  /**
   * Make POST request
   */
  async post<T = unknown>(path: string, body?: unknown, options?: RequestOptions): Promise<HttpResponse<T>> {
    return this.request<T>('POST', path, { ...options, body })
  }

  /**
   * Make PUT request
   */
  async put<T = unknown>(path: string, body?: unknown, options?: RequestOptions): Promise<HttpResponse<T>> {
    return this.request<T>('PUT', path, { ...options, body })
  }

  /**
   * Make PATCH request
   */
  async patch<T = unknown>(path: string, body?: unknown, options?: RequestOptions): Promise<HttpResponse<T>> {
    return this.request<T>('PATCH', path, { ...options, body })
  }

  /**
   * Make DELETE request
   */
  async delete<T = unknown>(path: string, options?: RequestOptions): Promise<HttpResponse<T>> {
    return this.request<T>('DELETE', path, options)
  }

  /**
   * Make HEAD request
   */
  async head(path: string, options?: RequestOptions): Promise<HttpResponse<void>> {
    return this.request<void>('HEAD', path, options)
  }

  /**
   * General request method
   */
  private async request<T>(
    method: string,
    path: string,
    options: RequestOptions = {}
  ): Promise<HttpResponse<T>> {
    const url = this.buildUrl(path, options.params)
    const headers = { ...this.defaultHeaders, ...options.headers }

    // Set content-type for JSON body
    if (options.body && typeof options.body === 'object') {
      headers['Content-Type'] = 'Content-Type' in headers
        ? headers['Content-Type']
        : 'application/json'
    }

    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), options.timeout || this.timeout)

    try {
      const response = await http.fetch(url, {
        method,
        headers,
        body: options.body
          ? typeof options.body === 'string'
            ? options.body
            : JSON.stringify(options.body)
          : undefined,
        signal: controller.signal
      })

      clearTimeout(timeoutId)

      // Parse response
      let data: T | undefined
      const contentType = response.headers.get('content-type')

      if (contentType?.includes('application/json')) {
        data = await response.json()
      } else if (contentType?.includes('text/')) {
        data = await response.text() as unknown as T
      }

      return {
        data: data as T,
        status: response.status,
        statusText: response.statusText,
        headers: Object.fromEntries(response.headers.entries()),
        ok: response.ok
      }
    } catch (error) {
      clearTimeout(timeoutId)
      if (error instanceof Error && error.name === 'AbortError') {
        throw new HttpError('Request timeout', 0, 'TIMEOUT')
      }
      throw error
    }
  }

  /**
   * Build URL with query parameters
   */
  private buildUrl(path: string, params?: Record<string, string | number | boolean>): string {
    let url = path.startsWith('http') ? path : `${this.baseUrl}${path}`

    if (params) {
      const searchParams = new URLSearchParams()
      for (const [key, value] of Object.entries(params)) {
        searchParams.append(key, String(value))
      }
      const query = searchParams.toString()
      if (query) {
        url += (url.includes('?') ? '&' : '?') + query
      }
    }

    return url
  }

  /**
   * Set default header
   */
  setHeader(key: string, value: string): void {
    this.defaultHeaders[key] = value
  }

  /**
   * Remove default header
   */
  removeHeader(key: string): void {
    delete this.defaultHeaders[key]
  }

  /**
   * Set bearer token
   */
  setBearerToken(token: string): void {
    this.setHeader('Authorization', `Bearer ${token}`)
  }
}

/**
 * HTTP client options
 */
export interface HttpClientOptions {
  baseUrl?: string
  headers?: Record<string, string>
  timeout?: number
}

/**
 * Request options
 */
export interface RequestOptions {
  headers?: Record<string, string>
  params?: Record<string, string | number | boolean>
  body?: unknown
  timeout?: number
}

/**
 * HTTP response
 */
export interface HttpResponse<T> {
  data: T
  status: number
  statusText: string
  headers: Record<string, string>
  ok: boolean
}

/**
 * HTTP error class
 */
export class HttpError extends Error {
  status: number
  code: string

  constructor(message: string, status: number, code: string = 'HTTP_ERROR') {
    super(message)
    this.name = 'HttpError'
    this.status = status
    this.code = code
  }
}

/**
 * WebSocket client wrapper
 */
export class WebSocketClient {
  private ws: WebSocket | null = null
  private url: string
  private reconnectAttempts: number = 0
  private maxReconnectAttempts: number
  private reconnectDelay: number
  private handlers: Map<string, Set<(data: unknown) => void>> = new Map()
  private messageHandler: ((event: MessageEvent) => void) | null = null

  constructor(url: string, options: WebSocketOptions = {}) {
    this.url = url
    this.maxReconnectAttempts = options.maxReconnectAttempts || 5
    this.reconnectDelay = options.reconnectDelay || 1000
  }

  /**
   * Connect to WebSocket server
   */
  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.url)

      this.ws.onopen = () => {
        this.reconnectAttempts = 0
        resolve()
      }

      this.ws.onerror = (event) => {
        reject(new Error('WebSocket connection failed'))
      }

      this.ws.onclose = () => {
        this.attemptReconnect()
      }

      this.messageHandler = (event: MessageEvent) => {
        try {
          const data = JSON.parse(event.data)
          const type = data.type || 'message'
          const handlers = this.handlers.get(type)
          if (handlers) {
            handlers.forEach(handler => handler(data.payload || data))
          }
        } catch {
          // Handle non-JSON messages
          const handlers = this.handlers.get('message')
          if (handlers) {
            handlers.forEach(handler => handler(event.data))
          }
        }
      }

      this.ws.onmessage = this.messageHandler
    })
  }

  /**
   * Disconnect from WebSocket server
   */
  disconnect(): void {
    if (this.ws) {
      this.ws.close()
      this.ws = null
    }
  }

  /**
   * Send message
   */
  send(type: string, payload?: unknown): void {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error('WebSocket not connected')
    }
    this.ws.send(JSON.stringify({ type, payload }))
  }

  /**
   * Send raw data
   */
  sendRaw(data: string | ArrayBuffer): void {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error('WebSocket not connected')
    }
    this.ws.send(data)
  }

  /**
   * Subscribe to message type
   */
  on(type: string, handler: (data: unknown) => void): () => void {
    if (!this.handlers.has(type)) {
      this.handlers.set(type, new Set())
    }
    this.handlers.get(type)!.add(handler)

    return () => {
      this.handlers.get(type)?.delete(handler)
    }
  }

  /**
   * Attempt to reconnect
   */
  private attemptReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      return
    }

    this.reconnectAttempts++
    const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1)

    setTimeout(() => {
      this.connect().catch(() => {
        // Reconnection failed, will try again
      })
    }, delay)
  }

  /**
   * Check if connected
   */
  get connected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN
  }
}

/**
 * WebSocket options
 */
export interface WebSocketOptions {
  maxReconnectAttempts?: number
  reconnectDelay?: number
}

/**
 * Create a pre-configured HTTP client
 */
export function createClient(options?: HttpClientOptions): HttpClient {
  return new HttpClient(options)
}

export default http
