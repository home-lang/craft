/**
 * Chat App - Real-time chat application built with Craft
 * Features: WebSocket messaging, rooms, typing indicators, read receipts, push notifications
 */

import { db, window, Platform, haptics, notifications } from 'ts-craft'

// Types
interface User {
  id: string
  username: string
  avatar?: string
  status: 'online' | 'away' | 'offline'
  lastSeen?: string
}

interface Message {
  id: string
  roomId: string
  userId: string
  content: string
  type: 'text' | 'image' | 'file' | 'system'
  timestamp: string
  readBy: string[]
  replyTo?: string
}

interface Room {
  id: string
  name: string
  type: 'direct' | 'group'
  members: string[]
  lastMessage?: Message
  unreadCount: number
  createdAt: string
}

interface TypingIndicator {
  roomId: string
  userId: string
  timestamp: number
}

// WebSocket connection manager
class ChatConnection {
  private ws: WebSocket | null = null
  private reconnectAttempts = 0
  private maxReconnectAttempts = 5
  private reconnectDelay = 1000
  private messageHandlers: Map<string, (data: any) => void> = new Map()
  private pendingMessages: any[] = []

  constructor(private serverUrl: string) {}

  connect(token: string): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(`${this.serverUrl}?token=${token}`)

      this.ws.onopen = () => {
        console.log('Connected to chat server')
        this.reconnectAttempts = 0
        this.flushPendingMessages()
        resolve()
      }

      this.ws.onclose = () => {
        console.log('Disconnected from chat server')
        this.attemptReconnect(token)
      }

      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error)
        reject(error)
      }

      this.ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data)
          this.handleMessage(data)
        } catch (e) {
          console.error('Failed to parse message:', e)
        }
      }
    })
  }

  private attemptReconnect(token: string): void {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++
      const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1)
      console.log(`Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`)
      setTimeout(() => this.connect(token), delay)
    }
  }

  private flushPendingMessages(): void {
    while (this.pendingMessages.length > 0) {
      const message = this.pendingMessages.shift()
      this.send(message)
    }
  }

  send(data: any): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(data))
    } else {
      this.pendingMessages.push(data)
    }
  }

  on(event: string, handler: (data: any) => void): void {
    this.messageHandlers.set(event, handler)
  }

  off(event: string): void {
    this.messageHandlers.delete(event)
  }

  private handleMessage(data: { type: string; payload: any }): void {
    const handler = this.messageHandlers.get(data.type)
    if (handler) {
      handler(data.payload)
    }
  }

  disconnect(): void {
    this.ws?.close()
    this.ws = null
  }
}

// Chat store for state management
class ChatStore {
  private currentUser: User | null = null
  private rooms: Map<string, Room> = new Map()
  private messages: Map<string, Message[]> = new Map()
  private users: Map<string, User> = new Map()
  private typingUsers: Map<string, TypingIndicator[]> = new Map()
  private activeRoomId: string | null = null
  private listeners: Set<() => void> = new Set()

  setCurrentUser(user: User): void {
    this.currentUser = user
    this.notify()
  }

  getCurrentUser(): User | null {
    return this.currentUser
  }

  addRoom(room: Room): void {
    this.rooms.set(room.id, room)
    this.notify()
  }

  getRoom(id: string): Room | undefined {
    return this.rooms.get(id)
  }

  getRooms(): Room[] {
    return Array.from(this.rooms.values()).sort((a, b) => {
      const aTime = a.lastMessage?.timestamp || a.createdAt
      const bTime = b.lastMessage?.timestamp || b.createdAt
      return new Date(bTime).getTime() - new Date(aTime).getTime()
    })
  }

  setActiveRoom(roomId: string | null): void {
    this.activeRoomId = roomId
    if (roomId) {
      const room = this.rooms.get(roomId)
      if (room) {
        room.unreadCount = 0
        this.rooms.set(roomId, room)
      }
    }
    this.notify()
  }

  getActiveRoomId(): string | null {
    return this.activeRoomId
  }

  addMessage(message: Message): void {
    const roomMessages = this.messages.get(message.roomId) || []
    roomMessages.push(message)
    this.messages.set(message.roomId, roomMessages)

    // Update room's last message
    const room = this.rooms.get(message.roomId)
    if (room) {
      room.lastMessage = message
      if (message.roomId !== this.activeRoomId && message.userId !== this.currentUser?.id) {
        room.unreadCount++
      }
      this.rooms.set(message.roomId, room)
    }

    this.notify()
  }

  getMessages(roomId: string): Message[] {
    return this.messages.get(roomId) || []
  }

  setUser(user: User): void {
    this.users.set(user.id, user)
    this.notify()
  }

  getUser(id: string): User | undefined {
    return this.users.get(id)
  }

  setTyping(roomId: string, userId: string, isTyping: boolean): void {
    const indicators = this.typingUsers.get(roomId) || []
    const existingIndex = indicators.findIndex((i) => i.userId === userId)

    if (isTyping) {
      if (existingIndex >= 0) {
        indicators[existingIndex].timestamp = Date.now()
      } else {
        indicators.push({ roomId, userId, timestamp: Date.now() })
      }
    } else {
      if (existingIndex >= 0) {
        indicators.splice(existingIndex, 1)
      }
    }

    this.typingUsers.set(roomId, indicators)
    this.notify()
  }

  getTypingUsers(roomId: string): User[] {
    const indicators = this.typingUsers.get(roomId) || []
    const now = Date.now()
    // Filter out stale typing indicators (> 5 seconds)
    const activeIndicators = indicators.filter((i) => now - i.timestamp < 5000)
    return activeIndicators
      .map((i) => this.users.get(i.userId))
      .filter((u): u is User => u !== undefined && u.id !== this.currentUser?.id)
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  private notify(): void {
    this.listeners.forEach((listener) => listener())
  }
}

// Initialize database for offline storage
async function initDatabase(): Promise<void> {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      roomId TEXT NOT NULL,
      userId TEXT NOT NULL,
      content TEXT NOT NULL,
      type TEXT DEFAULT 'text',
      timestamp TEXT NOT NULL,
      readBy TEXT DEFAULT '[]',
      replyTo TEXT
    )
  `)

  await db.execute(`
    CREATE TABLE IF NOT EXISTS rooms (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT DEFAULT 'direct',
      members TEXT NOT NULL,
      unreadCount INTEGER DEFAULT 0,
      createdAt TEXT NOT NULL
    )
  `)

  await db.execute(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT NOT NULL,
      avatar TEXT,
      status TEXT DEFAULT 'offline',
      lastSeen TEXT
    )
  `)

  await db.execute(`CREATE INDEX IF NOT EXISTS idx_messages_room ON messages(roomId)`)
}

// Main Chat App class
class ChatApp {
  private connection: ChatConnection
  private store: ChatStore
  private typingTimeout: ReturnType<typeof setTimeout> | null = null

  constructor(serverUrl: string) {
    this.connection = new ChatConnection(serverUrl)
    this.store = new ChatStore()
    this.setupConnectionHandlers()
  }

  private setupConnectionHandlers(): void {
    this.connection.on('message', async (message: Message) => {
      this.store.addMessage(message)
      await this.saveMessageLocally(message)

      // Show notification if not in active room
      if (message.roomId !== this.store.getActiveRoomId()) {
        const sender = this.store.getUser(message.userId)
        await this.showNotification(sender?.username || 'New Message', message.content)
      }

      // Haptic feedback on mobile
      if (Platform.OS === 'ios' || Platform.OS === 'android') {
        haptics.notification('success')
      }
    })

    this.connection.on('typing', ({ roomId, userId, isTyping }: { roomId: string; userId: string; isTyping: boolean }) => {
      this.store.setTyping(roomId, userId, isTyping)
    })

    this.connection.on('presence', ({ userId, status }: { userId: string; status: 'online' | 'away' | 'offline' }) => {
      const user = this.store.getUser(userId)
      if (user) {
        this.store.setUser({ ...user, status })
      }
    })

    this.connection.on('read', ({ messageId, userId }: { messageId: string; userId: string }) => {
      // Update read receipts
      const rooms = this.store.getRooms()
      for (const room of rooms) {
        const messages = this.store.getMessages(room.id)
        const message = messages.find((m) => m.id === messageId)
        if (message && !message.readBy.includes(userId)) {
          message.readBy.push(userId)
        }
      }
    })

    this.connection.on('room_created', (room: Room) => {
      this.store.addRoom(room)
    })

    this.connection.on('user_joined', ({ roomId, user }: { roomId: string; user: User }) => {
      this.store.setUser(user)
      const room = this.store.getRoom(roomId)
      if (room && !room.members.includes(user.id)) {
        room.members.push(user.id)
      }
    })
  }

  async connect(token: string, user: User): Promise<void> {
    this.store.setCurrentUser(user)
    await this.connection.connect(token)
    await this.loadLocalData()
  }

  private async loadLocalData(): Promise<void> {
    // Load rooms from local storage
    const rooms = await db.query<any>('SELECT * FROM rooms')
    for (const room of rooms) {
      this.store.addRoom({
        ...room,
        members: JSON.parse(room.members),
      })
    }

    // Load users
    const users = await db.query<User>('SELECT * FROM users')
    for (const user of users) {
      this.store.setUser(user)
    }

    // Load messages for each room
    for (const room of rooms) {
      const messages = await db.query<any>('SELECT * FROM messages WHERE roomId = ? ORDER BY timestamp', [room.id])
      for (const message of messages) {
        this.store.addMessage({
          ...message,
          readBy: JSON.parse(message.readBy),
        })
      }
    }
  }

  private async saveMessageLocally(message: Message): Promise<void> {
    await db.execute(
      `INSERT OR REPLACE INTO messages (id, roomId, userId, content, type, timestamp, readBy, replyTo)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        message.id,
        message.roomId,
        message.userId,
        message.content,
        message.type,
        message.timestamp,
        JSON.stringify(message.readBy),
        message.replyTo || null,
      ]
    )
  }

  private async showNotification(title: string, body: string): Promise<void> {
    await notifications.show({
      title,
      body,
      sound: true,
    })
  }

  sendMessage(content: string, type: 'text' | 'image' | 'file' = 'text', replyTo?: string): void {
    const roomId = this.store.getActiveRoomId()
    const user = this.store.getCurrentUser()
    if (!roomId || !user) return

    const message: Message = {
      id: generateId(),
      roomId,
      userId: user.id,
      content,
      type,
      timestamp: new Date().toISOString(),
      readBy: [user.id],
      replyTo,
    }

    this.connection.send({ type: 'message', payload: message })
    this.store.addMessage(message)
    this.saveMessageLocally(message)
    this.stopTyping()
  }

  startTyping(): void {
    const roomId = this.store.getActiveRoomId()
    if (!roomId) return

    this.connection.send({ type: 'typing', payload: { roomId, isTyping: true } })

    // Auto-stop typing after 3 seconds
    if (this.typingTimeout) {
      clearTimeout(this.typingTimeout)
    }
    this.typingTimeout = setTimeout(() => this.stopTyping(), 3000)
  }

  stopTyping(): void {
    const roomId = this.store.getActiveRoomId()
    if (!roomId) return

    this.connection.send({ type: 'typing', payload: { roomId, isTyping: false } })

    if (this.typingTimeout) {
      clearTimeout(this.typingTimeout)
      this.typingTimeout = null
    }
  }

  markAsRead(messageId: string): void {
    this.connection.send({ type: 'read', payload: { messageId } })
  }

  createRoom(name: string, members: string[], type: 'direct' | 'group' = 'group'): void {
    const room: Room = {
      id: generateId(),
      name,
      type,
      members,
      unreadCount: 0,
      createdAt: new Date().toISOString(),
    }

    this.connection.send({ type: 'create_room', payload: room })
  }

  selectRoom(roomId: string): void {
    this.store.setActiveRoom(roomId)
  }

  getStore(): ChatStore {
    return this.store
  }

  disconnect(): void {
    this.connection.disconnect()
  }
}

// Utility functions
function generateId(): string {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
}

function formatTimestamp(timestamp: string): string {
  const date = new Date(timestamp)
  const now = new Date()
  const diff = now.getTime() - date.getTime()

  if (diff < 60000) return 'Just now'
  if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`
  if (diff < 86400000) return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  if (diff < 604800000) return date.toLocaleDateString([], { weekday: 'short' })
  return date.toLocaleDateString([], { month: 'short', day: 'numeric' })
}

function formatMessageTime(timestamp: string): string {
  return new Date(timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}

// UI Rendering
function renderApp(app: ChatApp): void {
  const store = app.getStore()
  const appEl = document.getElementById('app')
  if (!appEl) return

  appEl.innerHTML = `
    <div class="chat-app">
      <aside class="rooms-sidebar">
        <header class="sidebar-header">
          <h1>Chat</h1>
          <button id="new-room-btn" class="icon-btn">+</button>
        </header>
        <div class="rooms-list" id="rooms-list">
          ${renderRoomsList(store)}
        </div>
      </aside>

      <main class="chat-main">
        ${store.getActiveRoomId() ? renderChatRoom(app) : renderEmptyState()}
      </main>
    </div>
  `

  setupEventListeners(app)
}

function renderRoomsList(store: ChatStore): string {
  const rooms = store.getRooms()
  const activeRoomId = store.getActiveRoomId()

  return rooms
    .map(
      (room) => `
    <div class="room-item ${room.id === activeRoomId ? 'active' : ''}" data-room-id="${room.id}">
      <div class="room-avatar">${room.name.charAt(0).toUpperCase()}</div>
      <div class="room-info">
        <div class="room-name">${room.name}</div>
        <div class="room-preview">${room.lastMessage?.content || 'No messages yet'}</div>
      </div>
      ${room.unreadCount > 0 ? `<span class="unread-badge">${room.unreadCount}</span>` : ''}
      <span class="room-time">${room.lastMessage ? formatTimestamp(room.lastMessage.timestamp) : ''}</span>
    </div>
  `
    )
    .join('')
}

function renderChatRoom(app: ChatApp): string {
  const store = app.getStore()
  const roomId = store.getActiveRoomId()
  if (!roomId) return ''

  const room = store.getRoom(roomId)
  const messages = store.getMessages(roomId)
  const typingUsers = store.getTypingUsers(roomId)

  return `
    <header class="chat-header">
      <button id="back-btn" class="icon-btn mobile-only">←</button>
      <div class="chat-header-info">
        <h2>${room?.name || 'Chat'}</h2>
        <span class="member-count">${room?.members.length || 0} members</span>
      </div>
      <button id="room-settings-btn" class="icon-btn">⚙</button>
    </header>

    <div class="messages-container" id="messages-container">
      ${renderMessages(messages, store)}
      ${typingUsers.length > 0 ? renderTypingIndicator(typingUsers) : ''}
    </div>

    <footer class="message-input-container">
      <button id="attach-btn" class="icon-btn">📎</button>
      <input type="text" id="message-input" placeholder="Type a message..." class="message-input" />
      <button id="send-btn" class="icon-btn send-btn">→</button>
    </footer>
  `
}

function renderMessages(messages: Message[], store: ChatStore): string {
  const currentUser = store.getCurrentUser()
  let lastDate = ''

  return messages
    .map((message) => {
      const user = store.getUser(message.userId)
      const isOwn = message.userId === currentUser?.id
      const messageDate = new Date(message.timestamp).toDateString()
      let dateDivider = ''

      if (messageDate !== lastDate) {
        lastDate = messageDate
        dateDivider = `<div class="date-divider">${formatDateDivider(message.timestamp)}</div>`
      }

      if (message.type === 'system') {
        return `
          ${dateDivider}
          <div class="message system-message">${message.content}</div>
        `
      }

      return `
        ${dateDivider}
        <div class="message ${isOwn ? 'own' : ''}" data-message-id="${message.id}">
          ${!isOwn ? `<div class="message-avatar">${user?.username?.charAt(0) || '?'}</div>` : ''}
          <div class="message-content">
            ${!isOwn ? `<div class="message-sender">${user?.username || 'Unknown'}</div>` : ''}
            <div class="message-bubble">
              ${message.type === 'image' ? `<img src="${message.content}" class="message-image" />` : message.content}
            </div>
            <div class="message-meta">
              <span class="message-time">${formatMessageTime(message.timestamp)}</span>
              ${isOwn ? `<span class="read-status">${message.readBy.length > 1 ? '✓✓' : '✓'}</span>` : ''}
            </div>
          </div>
        </div>
      `
    })
    .join('')
}

function renderTypingIndicator(users: User[]): string {
  const names = users.map((u) => u.username).join(', ')
  return `
    <div class="typing-indicator">
      <span class="typing-dots"><span>.</span><span>.</span><span>.</span></span>
      ${names} ${users.length === 1 ? 'is' : 'are'} typing
    </div>
  `
}

function renderEmptyState(): string {
  return `
    <div class="empty-state">
      <div class="empty-icon">💬</div>
      <h2>Welcome to Chat</h2>
      <p>Select a conversation or start a new one</p>
    </div>
  `
}

function formatDateDivider(timestamp: string): string {
  const date = new Date(timestamp)
  const today = new Date()
  const yesterday = new Date(today)
  yesterday.setDate(yesterday.getDate() - 1)

  if (date.toDateString() === today.toDateString()) return 'Today'
  if (date.toDateString() === yesterday.toDateString()) return 'Yesterday'
  return date.toLocaleDateString([], { month: 'long', day: 'numeric', year: 'numeric' })
}

function setupEventListeners(app: ChatApp): void {
  // Room selection
  document.querySelectorAll('.room-item').forEach((item) => {
    item.addEventListener('click', () => {
      const roomId = item.getAttribute('data-room-id')
      if (roomId) {
        app.selectRoom(roomId)
        renderApp(app)
        scrollToBottom()
      }
    })
  })

  // Message input
  const messageInput = document.getElementById('message-input') as HTMLInputElement
  const sendBtn = document.getElementById('send-btn')

  if (messageInput) {
    messageInput.addEventListener('input', () => {
      app.startTyping()
    })

    messageInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault()
        sendMessage(app, messageInput)
      }
    })
  }

  sendBtn?.addEventListener('click', () => {
    if (messageInput) sendMessage(app, messageInput)
  })

  // New room button
  document.getElementById('new-room-btn')?.addEventListener('click', () => {
    const name = prompt('Enter room name:')
    if (name) {
      app.createRoom(name, [app.getStore().getCurrentUser()?.id || ''])
    }
  })

  // Back button (mobile)
  document.getElementById('back-btn')?.addEventListener('click', () => {
    app.selectRoom('')
    renderApp(app)
  })

  // Subscribe to store updates
  app.getStore().subscribe(() => {
    renderApp(app)
    scrollToBottom()
  })
}

function sendMessage(app: ChatApp, input: HTMLInputElement): void {
  const content = input.value.trim()
  if (content) {
    app.sendMessage(content)
    input.value = ''

    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      haptics.impact('light')
    }
  }
}

function scrollToBottom(): void {
  const container = document.getElementById('messages-container')
  if (container) {
    container.scrollTop = container.scrollHeight
  }
}

// Main app initialization
async function main(): Promise<void> {
  await initDatabase()

  window.setTitle('Chat')
  window.setSize(900, 700)
  window.setMinSize(400, 500)

  // Initialize chat app with server URL
  const app = new ChatApp('wss://chat.example.com')

  // Mock user for demo
  const mockUser: User = {
    id: 'user-1',
    username: 'You',
    status: 'online',
  }

  // For demo, add some mock rooms
  const store = app.getStore()
  store.setCurrentUser(mockUser)

  store.addRoom({
    id: 'room-1',
    name: 'General',
    type: 'group',
    members: ['user-1', 'user-2', 'user-3'],
    unreadCount: 2,
    createdAt: new Date().toISOString(),
  })

  store.addRoom({
    id: 'room-2',
    name: 'Design Team',
    type: 'group',
    members: ['user-1', 'user-4'],
    unreadCount: 0,
    createdAt: new Date().toISOString(),
  })

  store.setUser({ id: 'user-2', username: 'Alice', status: 'online' })
  store.setUser({ id: 'user-3', username: 'Bob', status: 'away' })
  store.setUser({ id: 'user-4', username: 'Carol', status: 'offline' })

  // Add some mock messages
  store.addMessage({
    id: 'msg-1',
    roomId: 'room-1',
    userId: 'user-2',
    content: 'Hey everyone! 👋',
    type: 'text',
    timestamp: new Date(Date.now() - 3600000).toISOString(),
    readBy: ['user-2', 'user-1'],
  })

  store.addMessage({
    id: 'msg-2',
    roomId: 'room-1',
    userId: 'user-3',
    content: 'Hi Alice! How are you?',
    type: 'text',
    timestamp: new Date(Date.now() - 3000000).toISOString(),
    readBy: ['user-3'],
  })

  // Expose app for debugging
  ;(globalThis as any).chatApp = app

  // Render the app
  renderApp(app)

  // Keyboard shortcuts
  document.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'n') {
      e.preventDefault()
      document.getElementById('new-room-btn')?.click()
    }
  })
}

main().catch(console.error)
