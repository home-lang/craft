# IPC Communication

Craft provides a powerful Inter-Process Communication (IPC) system for seamless communication between your native code and web content.

## Overview

IPC in Craft supports:

- **Message Passing**: Send events between native and web
- **Invoke/Handle**: Request-response pattern
- **Channels**: Bidirectional communication channels
- **Shared State**: Synchronized state between contexts

## Message Passing

### Send from Web to Native

```html
<!-- In your HTML/JavaScript -->
<script>
  // Send a message to native
  window.craft.send('user-action', {
    type: 'click',
    target: 'button',
  })
</script>
```

```typescript
// In your TypeScript/native code
import { createWindow } from 'ts-craft'

const window = await createWindow(html, options)

window.on('user-action', (data) => {
  console.log(`User ${data.type} on ${data.target}`)
})
```

### Send from Native to Web

```typescript
// In your TypeScript
window.emit('update-data', {
  users: ['Alice', 'Bob'],
  count: 2,
})
```

```html
<!-- In your HTML -->
<script>
  window.craft.on('update-data', (data) => {
    console.log(`Received ${data.count} users`)
    updateUserList(data.users)
  })
</script>
```

## Invoke/Handle Pattern

### Define Handler (Native)

```typescript
// Register a handler
window.handle('get-user', async (userId) => {
  const user = await fetchUser(userId)
  return user
})

window.handle('save-file', async (content, filename) => {
  await Bun.write(filename, content)
  return { success: true }
})
```

### Invoke from Web

```html
<script>
  // Invoke and await response
  async function loadUser() {
    const user = await window.craft.invoke('get-user', 123)
    console.log(user.name)
  }

  async function saveDocument() {
    const result = await window.craft.invoke('save-file', content, 'doc.txt')
    if (result.success) {
      showNotification('Saved!')
    }
  }
</script>
```

### Invoke from Native

```typescript
// Define handler in web
// (in your HTML/JavaScript)
window.craft.handle('get-selection', () => {
  return window.getSelection().toString()
})

// Invoke from native
const selection = await window.invoke('get-selection')
console.log('Selected text:', selection)
```

## Type-Safe IPC

### Define Types

```typescript
// types.ts
interface IpcEvents {
  // Native -> Web
  'update-user': { id: number; name: string }
  'notification': { title: string; message: string }

  // Web -> Native
  'save-data': { content: string; path: string }
  'user-action': { type: string; target: string }
}

interface IpcHandlers {
  'get-user': (id: number) => Promise<User>
  'save-file': (content: string, path: string) => Promise<boolean>
}
```

### Use Types

```typescript
import type { IpcEvents, IpcHandlers } from './types'
import { createTypedWindow } from 'ts-craft'

const window = await createTypedWindow<IpcEvents, IpcHandlers>(html, options)

// Type-safe event handling
window.on('save-data', (data) => {
  // data is typed as { content: string; path: string }
  Bun.write(data.path, data.content)
})

// Type-safe handler
window.handle('get-user', async (id) => {
  // id is typed as number
  // Return type must match User
  return { id, name: 'John' }
})
```

## Channels

### Create Channel

```typescript
// Create a bidirectional channel
const channel = window.createChannel('data-stream')

// Send data through channel
channel.send({ type: 'update', value: 42 })

// Receive data from channel
channel.on('message', (data) => {
  console.log('Received:', data)
})

// Close channel when done
channel.close()
```

### Use Channel in Web

```html
<script>
  const channel = window.craft.connectChannel('data-stream')

  // Send to native
  channel.send({ type: 'request', query: 'users' })

  // Receive from native
  channel.on('message', (data) => {
    console.log('Received:', data)
  })
</script>
```

### Streaming Data

```typescript
// Native side
const channel = window.createChannel('log-stream')

// Stream log data
const logFile = Bun.file('./app.log')
const reader = logFile.stream().getReader()

while (true) {
  const { done, value } = await reader.read()
  if (done) break
  channel.send({ chunk: value.toString() })
}
channel.send({ done: true })
```

## Shared State

### Define Shared State

```typescript
import { createSharedState } from 'ts-craft'

const state = createSharedState({
  user: null,
  theme: 'dark',
  settings: {
    notifications: true,
    autoSave: true,
  },
})

// Changes are synced to web
state.user = { id: 1, name: 'John' }
state.theme = 'light'
```

### Access in Web

```html
<script>
  // Access shared state
  console.log(window.craft.state.user) // { id: 1, name: 'John' }
  console.log(window.craft.state.theme) // 'light'

  // Watch for changes
  window.craft.watchState('theme', (newValue, oldValue) => {
    console.log(`Theme changed from ${oldValue} to ${newValue}`)
    applyTheme(newValue)
  })

  // Update from web (syncs to native)
  window.craft.state.settings.notifications = false
</script>
```

## Error Handling

### Handle Errors in Invoke

```typescript
// Native handler with error
window.handle('risky-operation', async (data) => {
  if (!data.valid) {
    throw new Error('Invalid data')
  }
  return processData(data)
})
```

```html
<script>
  try {
    const result = await window.craft.invoke('risky-operation', { valid: false })
  } catch (error) {
    console.error('Operation failed:', error.message)
    // "Invalid data"
  }
</script>
```

### Global Error Handler

```typescript
window.onIpcError((error) => {
  console.error('IPC Error:', error)
  // Log to analytics, show notification, etc.
})
```

## Security

### Validate Messages

```typescript
import { z } from 'zod'

const SaveDataSchema = z.object({
  content: z.string().max(1000000),
  path: z.string().regex(/^[a-zA-Z0-9\-_./]+$/),
})

window.handle('save-data', async (data) => {
  // Validate input
  const validated = SaveDataSchema.parse(data)

  // Safe to use
  await Bun.write(validated.path, validated.content)
})
```

### Restrict Handlers

```typescript
// Only expose safe handlers
const allowedHandlers = ['get-user', 'get-settings', 'save-preferences']

window.on('invoke', (name, data, respond) => {
  if (!allowedHandlers.includes(name)) {
    respond({ error: 'Handler not allowed' })
    return
  }
  // Process normally
})
```

## Performance

### Batch Messages

```typescript
// Instead of many small messages
users.forEach((user) => window.emit('user', user))

// Send one batch message
window.emit('users', users)
```

### Debounce High-Frequency Events

```html
<script>
  let pending = null

  document.addEventListener('mousemove', (e) => {
    // Debounce to avoid flooding IPC
    if (pending) return
    pending = setTimeout(() => {
      window.craft.send('mouse-position', { x: e.clientX, y: e.clientY })
      pending = null
    }, 16) // ~60fps
  })
</script>
```

### Use Channels for Streams

For high-frequency data, use channels instead of events:

```typescript
const channel = window.createChannel('telemetry')

// Efficient for real-time data
setInterval(() => {
  channel.send({
    cpu: getCpuUsage(),
    memory: getMemoryUsage(),
    timestamp: Date.now(),
  })
}, 100)
```

## Common Patterns

### Menu Actions

```typescript
// Set up menu handlers
window.handle('menu:new-file', () => newFile())
window.handle('menu:open-file', () => openFile())
window.handle('menu:save-file', () => saveFile())

// Trigger from menu
menu.on('click', (item) => {
  window.invoke(`menu:${item.id}`)
})
```

### Drag and Drop

```html
<script>
  document.addEventListener('drop', (e) => {
    e.preventDefault()
    const files = Array.from(e.dataTransfer.files).map((f) => f.path)
    window.craft.send('files-dropped', { files })
  })
</script>
```

```typescript
window.on('files-dropped', async ({ files }) => {
  for (const file of files) {
    await processFile(file)
  }
})
```

### Progress Updates

```typescript
async function processFiles(files) {
  const total = files.length

  for (let i = 0; i < total; i++) {
    await processFile(files[i])

    // Update progress in UI
    window.emit('progress', {
      current: i + 1,
      total,
      percent: ((i + 1) / total) * 100,
    })
  }

  window.emit('progress-complete')
}
```

## Next Steps

- [Native APIs](/features/native-apis) - System integration
- [Window Management](/features/window-management) - Window control
- [Advanced Configuration](/advanced/configuration) - IPC configuration
