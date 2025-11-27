/**
 * Craft Native Bridge Core
 * Bidirectional async communication, message queue, and type-safe protocols
 */

import { EventEmitter } from 'events'

// Types
export interface BridgeMessage<T = unknown> {
  id: string
  type: 'request' | 'response' | 'event' | 'stream'
  method?: string
  params?: T
  result?: unknown
  error?: { code: number; message: string; data?: unknown }
  streamId?: string
  streamEvent?: 'data' | 'end' | 'error'
}

export interface BridgeConfig {
  timeout?: number
  retries?: number
  retryDelay?: number
  queueSize?: number
  batchSize?: number
  batchDelay?: number
  enableOfflineQueue?: boolean
  enableBinaryTransfer?: boolean
}

export interface StreamController<T> {
  onData(callback: (data: T) => void): void
  onEnd(callback: () => void): void
  onError(callback: (error: Error) => void): void
  cancel(): void
}

// Message ID generator
let messageIdCounter = 0
function generateMessageId(): string {
  return `msg_${Date.now()}_${++messageIdCounter}`
}

// Native Bridge Core
export class NativeBridge extends EventEmitter {
  private config: Required<BridgeConfig>
  private pendingRequests = new Map<string, { resolve: (value: unknown) => void; reject: (error: Error) => void; timeout: NodeJS.Timeout }>()
  private offlineQueue: BridgeMessage[] = []
  private connected = false
  private streams = new Map<string, { onData: (data: unknown) => void; onEnd: () => void; onError: (error: Error) => void }>()
  private batchBuffer: BridgeMessage[] = []
  private batchTimer: NodeJS.Timeout | null = null

  constructor(config: BridgeConfig = {}) {
    super()
    this.config = {
      timeout: 30000,
      retries: 3,
      retryDelay: 1000,
      queueSize: 1000,
      batchSize: 10,
      batchDelay: 50,
      enableOfflineQueue: true,
      enableBinaryTransfer: true,
      ...config,
    }
    this.setupBridge()
  }

  private setupBridge(): void {
    // Listen for messages from native
    if (typeof window !== 'undefined') {
      window.addEventListener('message', this.handleMessage.bind(this))
      // Custom event for native bridge
      window.addEventListener('craft-bridge-message' as any, this.handleMessage.bind(this))
    }
  }

  private handleMessage(event: MessageEvent | CustomEvent): void {
    let data: BridgeMessage
    try {
      data = 'detail' in event ? event.detail : typeof event.data === 'string' ? JSON.parse(event.data) : event.data
    } catch {
      return
    }

    if (!data || !data.id) return

    switch (data.type) {
      case 'response':
        this.handleResponse(data)
        break
      case 'event':
        this.handleEvent(data)
        break
      case 'stream':
        this.handleStream(data)
        break
    }
  }

  private handleResponse(message: BridgeMessage): void {
    const pending = this.pendingRequests.get(message.id)
    if (!pending) return

    clearTimeout(pending.timeout)
    this.pendingRequests.delete(message.id)

    if (message.error) {
      pending.reject(new BridgeError(message.error.message, message.error.code, message.error.data))
    } else {
      pending.resolve(message.result)
    }
  }

  private handleEvent(message: BridgeMessage): void {
    if (message.method) {
      this.emit(message.method, message.params)
    }
  }

  private handleStream(message: BridgeMessage): void {
    if (!message.streamId) return
    const stream = this.streams.get(message.streamId)
    if (!stream) return

    switch (message.streamEvent) {
      case 'data':
        stream.onData(message.result)
        break
      case 'end':
        stream.onEnd()
        this.streams.delete(message.streamId)
        break
      case 'error':
        stream.onError(new Error(message.error?.message || 'Stream error'))
        this.streams.delete(message.streamId)
        break
    }
  }

  /**
   * Send a request to native and wait for response
   */
  async request<T = unknown, R = unknown>(method: string, params?: T): Promise<R> {
    return this.requestWithRetry(method, params, this.config.retries)
  }

  private async requestWithRetry<T, R>(method: string, params: T | undefined, retriesLeft: number): Promise<R> {
    try {
      return await this.sendRequest<T, R>(method, params)
    } catch (error) {
      if (retriesLeft > 0 && this.isRetryableError(error)) {
        await this.delay(this.config.retryDelay)
        return this.requestWithRetry(method, params, retriesLeft - 1)
      }
      throw error
    }
  }

  private isRetryableError(error: unknown): boolean {
    if (error instanceof BridgeError) {
      // Network errors, timeouts are retryable
      return error.code === -1 || error.code === -2
    }
    return false
  }

  private async sendRequest<T, R>(method: string, params?: T): Promise<R> {
    const message: BridgeMessage<T> = {
      id: generateMessageId(),
      type: 'request',
      method,
      params,
    }

    if (!this.connected && this.config.enableOfflineQueue) {
      if (this.offlineQueue.length >= this.config.queueSize) {
        throw new BridgeError('Offline queue full', -3)
      }
      this.offlineQueue.push(message)
      // Return a promise that will be resolved when connected
      return new Promise((resolve, reject) => {
        this.pendingRequests.set(message.id, {
          resolve: resolve as (value: unknown) => void,
          reject,
          timeout: setTimeout(() => {
            this.pendingRequests.delete(message.id)
            reject(new BridgeError('Request timeout', -1))
          }, this.config.timeout),
        })
      })
    }

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(message.id)
        reject(new BridgeError('Request timeout', -1))
      }, this.config.timeout)

      this.pendingRequests.set(message.id, {
        resolve: resolve as (value: unknown) => void,
        reject,
        timeout,
      })

      this.send(message)
    })
  }

  /**
   * Send a fire-and-forget message (no response expected)
   */
  notify<T = unknown>(method: string, params?: T): void {
    const message: BridgeMessage<T> = {
      id: generateMessageId(),
      type: 'request',
      method,
      params,
    }
    this.send(message)
  }

  /**
   * Create a stream for receiving multiple responses
   */
  stream<T = unknown>(method: string, params?: unknown): StreamController<T> {
    const streamId = generateMessageId()
    const message: BridgeMessage = {
      id: generateMessageId(),
      type: 'request',
      method,
      params,
      streamId,
    }

    let dataCallback: (data: T) => void = () => {}
    let endCallback: () => void = () => {}
    let errorCallback: (error: Error) => void = () => {}

    const controller: StreamController<T> = {
      onData: (cb) => {
        dataCallback = cb
      },
      onEnd: (cb) => {
        endCallback = cb
      },
      onError: (cb) => {
        errorCallback = cb
      },
      cancel: () => {
        this.streams.delete(streamId)
        this.send({
          id: generateMessageId(),
          type: 'request',
          method: '_cancelStream',
          params: { streamId },
        })
      },
    }

    this.streams.set(streamId, {
      onData: (data) => dataCallback(data as T),
      onEnd: endCallback,
      onError: errorCallback,
    })

    this.send(message)
    return controller
  }

  /**
   * Send binary data to native
   */
  async sendBinary(method: string, data: ArrayBuffer | Uint8Array): Promise<void> {
    if (!this.config.enableBinaryTransfer) {
      throw new BridgeError('Binary transfer not enabled', -4)
    }

    const base64 = this.arrayBufferToBase64(data instanceof ArrayBuffer ? new Uint8Array(data) : data)
    await this.request(method, { _binary: true, data: base64 })
  }

  /**
   * Receive binary data from native
   */
  async receiveBinary(method: string, params?: unknown): Promise<ArrayBuffer> {
    if (!this.config.enableBinaryTransfer) {
      throw new BridgeError('Binary transfer not enabled', -4)
    }

    const result = await this.request<unknown, { _binary: boolean; data: string }>(method, params)
    if (result._binary) {
      return this.base64ToArrayBuffer(result.data)
    }
    throw new BridgeError('Expected binary response', -5)
  }

  /**
   * Batch multiple requests
   */
  async batch<T extends Array<{ method: string; params?: unknown }>>(
    requests: T
  ): Promise<Array<{ result?: unknown; error?: { code: number; message: string } }>> {
    return this.request('_batch', { requests })
  }

  /**
   * Add request to batch buffer (auto-flushed)
   */
  addToBatch<T = unknown>(method: string, params?: T): void {
    this.batchBuffer.push({
      id: generateMessageId(),
      type: 'request',
      method,
      params,
    })

    if (this.batchBuffer.length >= this.config.batchSize) {
      this.flushBatch()
    } else if (!this.batchTimer) {
      this.batchTimer = setTimeout(() => this.flushBatch(), this.config.batchDelay)
    }
  }

  private flushBatch(): void {
    if (this.batchTimer) {
      clearTimeout(this.batchTimer)
      this.batchTimer = null
    }

    if (this.batchBuffer.length === 0) return

    const batch = this.batchBuffer
    this.batchBuffer = []

    this.send({
      id: generateMessageId(),
      type: 'request',
      method: '_batch',
      params: { messages: batch },
    })
  }

  /**
   * Set connection status
   */
  setConnected(connected: boolean): void {
    const wasConnected = this.connected
    this.connected = connected

    if (connected && !wasConnected) {
      this.emit('connected')
      this.flushOfflineQueue()
    } else if (!connected && wasConnected) {
      this.emit('disconnected')
    }
  }

  private flushOfflineQueue(): void {
    const queue = this.offlineQueue
    this.offlineQueue = []
    for (const message of queue) {
      this.send(message)
    }
  }

  private send(message: BridgeMessage): void {
    const json = JSON.stringify(message)

    // Try different native bridges
    if (typeof window !== 'undefined') {
      // iOS WKWebView
      if ((window as any).webkit?.messageHandlers?.craft) {
        ;(window as any).webkit.messageHandlers.craft.postMessage(message)
        return
      }

      // Android WebView
      if ((window as any).CraftBridge) {
        ;(window as any).CraftBridge.postMessage(json)
        return
      }

      // Electron IPC
      if ((window as any).craftIPC) {
        ;(window as any).craftIPC.send('bridge-message', message)
        return
      }

      // Generic postMessage
      if (window.parent !== window) {
        window.parent.postMessage(message, '*')
        return
      }
    }

    // Node.js (for testing)
    if (typeof process !== 'undefined' && (process as any).send) {
      ;(process as any).send(message)
    }
  }

  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms))
  }

  private arrayBufferToBase64(buffer: Uint8Array): string {
    let binary = ''
    for (let i = 0; i < buffer.byteLength; i++) {
      binary += String.fromCharCode(buffer[i])
    }
    return btoa(binary)
  }

  private base64ToArrayBuffer(base64: string): ArrayBuffer {
    const binary = atob(base64)
    const buffer = new ArrayBuffer(binary.length)
    const bytes = new Uint8Array(buffer)
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i)
    }
    return buffer
  }

  /**
   * Destroy the bridge
   */
  destroy(): void {
    // Clear all pending requests
    for (const [id, pending] of this.pendingRequests) {
      clearTimeout(pending.timeout)
      pending.reject(new BridgeError('Bridge destroyed', -6))
    }
    this.pendingRequests.clear()
    this.streams.clear()
    this.offlineQueue = []
    if (this.batchTimer) {
      clearTimeout(this.batchTimer)
    }
    this.removeAllListeners()
  }
}

// Bridge Error
export class BridgeError extends Error {
  code: number
  data?: unknown

  constructor(message: string, code: number, data?: unknown) {
    super(message)
    this.name = 'BridgeError'
    this.code = code
    this.data = data
  }
}

// Type-safe Bridge Protocol Generator
export interface BridgeMethod<P = void, R = void> {
  method: string
  params: P
  result: R
}

export type InferParams<T> = T extends BridgeMethod<infer P, unknown> ? P : never
export type InferResult<T> = T extends BridgeMethod<unknown, infer R> ? R : never

export function createTypedBridge<T extends Record<string, BridgeMethod<any, any>>>(bridge: NativeBridge) {
  return new Proxy(
    {},
    {
      get(_, method: string) {
        return (params?: unknown) => bridge.request(method, params)
      },
    }
  ) as {
    [K in keyof T]: (params: InferParams<T[K]>) => Promise<InferResult<T[K]>>
  }
}

// Native Menu System
export interface MenuItem {
  id: string
  label: string
  accelerator?: string
  type?: 'normal' | 'separator' | 'checkbox' | 'radio'
  checked?: boolean
  enabled?: boolean
  visible?: boolean
  icon?: string
  submenu?: MenuItem[]
}

export class NativeMenus {
  constructor(private bridge: NativeBridge) {}

  /**
   * Set application menu
   */
  async setApplicationMenu(menu: MenuItem[]): Promise<void> {
    await this.bridge.request('menu.setApplicationMenu', { menu })
  }

  /**
   * Show context menu
   */
  async showContextMenu(menu: MenuItem[], position?: { x: number; y: number }): Promise<string | null> {
    return this.bridge.request('menu.showContextMenu', { menu, position })
  }

  /**
   * Update menu item
   */
  async updateMenuItem(id: string, updates: Partial<MenuItem>): Promise<void> {
    await this.bridge.request('menu.updateMenuItem', { id, updates })
  }

  /**
   * Listen for menu item clicks
   */
  onMenuClick(callback: (id: string) => void): () => void {
    this.bridge.on('menu.click', callback)
    return () => this.bridge.off('menu.click', callback)
  }
}

// Native Dialogs
export interface OpenDialogOptions {
  title?: string
  defaultPath?: string
  buttonLabel?: string
  filters?: Array<{ name: string; extensions: string[] }>
  properties?: Array<'openFile' | 'openDirectory' | 'multiSelections' | 'showHiddenFiles' | 'createDirectory' | 'promptToCreate' | 'noResolveAliases' | 'treatPackageAsDirectory' | 'dontAddToRecent'>
  message?: string
}

export interface SaveDialogOptions {
  title?: string
  defaultPath?: string
  buttonLabel?: string
  filters?: Array<{ name: string; extensions: string[] }>
  properties?: Array<'showHiddenFiles' | 'createDirectory' | 'showOverwriteConfirmation' | 'dontAddToRecent'>
  message?: string
  nameFieldLabel?: string
  showsTagField?: boolean
}

export interface MessageBoxOptions {
  type?: 'none' | 'info' | 'error' | 'question' | 'warning'
  buttons?: string[]
  defaultId?: number
  cancelId?: number
  title?: string
  message: string
  detail?: string
  checkboxLabel?: string
  checkboxChecked?: boolean
  icon?: string
}

export class NativeDialogs {
  constructor(private bridge: NativeBridge) {}

  /**
   * Show open file dialog
   */
  async showOpenDialog(options: OpenDialogOptions = {}): Promise<{ canceled: boolean; filePaths: string[] }> {
    return this.bridge.request('dialog.showOpenDialog', options)
  }

  /**
   * Show save file dialog
   */
  async showSaveDialog(options: SaveDialogOptions = {}): Promise<{ canceled: boolean; filePath?: string }> {
    return this.bridge.request('dialog.showSaveDialog', options)
  }

  /**
   * Show message box
   */
  async showMessageBox(options: MessageBoxOptions): Promise<{ response: number; checkboxChecked?: boolean }> {
    return this.bridge.request('dialog.showMessageBox', options)
  }

  /**
   * Show error box
   */
  async showErrorBox(title: string, content: string): Promise<void> {
    await this.bridge.request('dialog.showErrorBox', { title, content })
  }

  /**
   * Show color picker
   */
  async showColorPicker(options?: { defaultColor?: string; title?: string }): Promise<string | null> {
    return this.bridge.request('dialog.showColorPicker', options || {})
  }

  /**
   * Show font picker
   */
  async showFontPicker(options?: { defaultFont?: { family: string; size: number }; title?: string }): Promise<{ family: string; size: number } | null> {
    return this.bridge.request('dialog.showFontPicker', options || {})
  }
}

// Native Component Bridge
export interface NativeComponent {
  id: string
  type: string
  props: Record<string, unknown>
}

export class NativeComponentBridge {
  private components = new Map<string, NativeComponent>()

  constructor(private bridge: NativeBridge) {
    this.bridge.on('component.event', this.handleComponentEvent.bind(this))
  }

  private handleComponentEvent(event: { componentId: string; eventType: string; data: unknown }): void {
    const component = this.components.get(event.componentId)
    if (component) {
      this.bridge.emit(`component:${event.componentId}:${event.eventType}`, event.data)
    }
  }

  /**
   * Create a native sidebar
   */
  async createSidebar(config: {
    width?: number
    minWidth?: number
    maxWidth?: number
    position?: 'left' | 'right'
    collapsible?: boolean
    collapsed?: boolean
  }): Promise<string> {
    const id = await this.bridge.request<typeof config, string>('component.createSidebar', config)
    this.components.set(id, { id, type: 'sidebar', props: config })
    return id
  }

  /**
   * Create a native file browser
   */
  async createFileBrowser(config: {
    rootPath?: string
    showHidden?: boolean
    selectionMode?: 'single' | 'multiple'
    fileFilter?: Array<{ name: string; extensions: string[] }>
  }): Promise<string> {
    const id = await this.bridge.request<typeof config, string>('component.createFileBrowser', config)
    this.components.set(id, { id, type: 'fileBrowser', props: config })
    return id
  }

  /**
   * Create a native split view
   */
  async createSplitView(config: {
    orientation?: 'horizontal' | 'vertical'
    dividerStyle?: 'thin' | 'thick' | 'paneSplitter'
    initialPosition?: number
    minPositions?: [number, number]
  }): Promise<string> {
    const id = await this.bridge.request<typeof config, string>('component.createSplitView', config)
    this.components.set(id, { id, type: 'splitView', props: config })
    return id
  }

  /**
   * Update component props
   */
  async updateComponent(componentId: string, props: Record<string, unknown>): Promise<void> {
    const component = this.components.get(componentId)
    if (component) {
      component.props = { ...component.props, ...props }
    }
    await this.bridge.request('component.update', { componentId, props })
  }

  /**
   * Destroy component
   */
  async destroyComponent(componentId: string): Promise<void> {
    this.components.delete(componentId)
    await this.bridge.request('component.destroy', { componentId })
  }

  /**
   * Listen for component events
   */
  onComponentEvent(componentId: string, eventType: string, callback: (data: unknown) => void): () => void {
    const eventName = `component:${componentId}:${eventType}`
    this.bridge.on(eventName, callback)
    return () => this.bridge.off(eventName, callback)
  }

  /**
   * Get selection from file browser
   */
  async getFileBrowserSelection(componentId: string): Promise<string[]> {
    return this.bridge.request('component.getFileBrowserSelection', { componentId })
  }
}

// Global bridge instance
let globalBridge: NativeBridge | null = null

export function getBridge(config?: BridgeConfig): NativeBridge {
  if (!globalBridge) {
    globalBridge = new NativeBridge(config)
  }
  return globalBridge
}

export function createBridge(config?: BridgeConfig): NativeBridge {
  return new NativeBridge(config)
}

// Export convenience instances
export function getMenus(): NativeMenus {
  return new NativeMenus(getBridge())
}

export function getDialogs(): NativeDialogs {
  return new NativeDialogs(getBridge())
}

export function getComponents(): NativeComponentBridge {
  return new NativeComponentBridge(getBridge())
}

export default {
  NativeBridge,
  BridgeError,
  createTypedBridge,
  NativeMenus,
  NativeDialogs,
  NativeComponentBridge,
  getBridge,
  createBridge,
  getMenus,
  getDialogs,
  getComponents,
}
