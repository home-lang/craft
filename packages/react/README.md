# @craft-native/react

React hooks for [Craft Native](https://github.com/stacksjs/craft) - Build native mobile and desktop apps with JavaScript.

## Installation

```bash
npm install @craft-native/react
# or
pnpm add @craft-native/react
# or
bun add @craft-native/react
```

## Usage

### Basic Example

```tsx
import { useCraft, useWindow, useNotification } from '@craft-native/react'

function App() {
  const craft = useCraft()
  const { show, hide, minimize } = useWindow()
  const { notify } = useNotification()

  const handleNotify = () => {
    notify({
      title: 'Hello from Craft!',
      body: 'This is a native notification'
    })
  }

  return (
    <div>
      <h1>Craft Native + React</h1>
      <button onClick={handleNotify}>Send Notification</button>
      <button onClick={minimize}>Minimize Window</button>
    </div>
  )
}
```

### Available Hooks

#### Desktop Hooks

- **`useCraft()`** - Access the main Craft bridge
- **`useWindow()`** - Window management (show, hide, toggle, minimize, close)
- **`useTray()`** - System tray management
- **`useNotification()`** - System notifications

#### Mobile Hooks

- **`useDeviceInfo()`** - Get device information
- **`usePermission(permission)`** - Request and check permissions
- **`useHaptic()`** - Haptic feedback
- **`useVibrate()`** - Device vibration
- **`useToast()`** - Toast messages
- **`useCamera()`** - Camera access
- **`usePhotoPicker()`** - Photo picker
- **`useShare()`** - Share functionality
- **`useBiometric()`** - Biometric authentication
- **`useSecureStorage()`** - Secure key-value storage

#### File System & Database Hooks

- **`useFileSystem()`** - File system operations
- **`useDatabase()`** - SQLite database operations

### Provider Component

Wrap your app with `CraftProvider` to ensure the Craft bridge is ready:

```tsx
import { CraftProvider } from '@craft-native/react'

function Root() {
  return (
    <CraftProvider>
      <App />
    </CraftProvider>
  )
}
```

### Examples

#### Camera Access

```tsx
import { useCamera } from '@craft-native/react'

function CameraExample() {
  const { open } = useCamera()

  const takePicture = async () => {
    const result = await open({ type: 'back', mediaType: 'photo' })
    console.log('Photo:', result)
  }

  return <button onClick={takePicture}>Take Picture</button>
}
```

#### Biometric Authentication

```tsx
import { useBiometric } from '@craft-native/react'

function BiometricExample() {
  const { available, authenticate } = useBiometric()

  const handleAuth = async () => {
    if (!available) {
      alert('Biometric not available')
      return
    }

    try {
      const result = await authenticate('Please authenticate to continue')
      console.log('Authenticated:', result)
    } catch (error) {
      console.error('Auth failed:', error)
    }
  }

  return (
    <button onClick={handleAuth} disabled={!available}>
      Authenticate with Biometric
    </button>
  )
}
```

#### Database Operations

```tsx
import { useDatabase } from '@craft-native/react'

function DatabaseExample() {
  const { execute, query, transaction } = useDatabase()

  const createTable = async () => {
    await execute(
      'CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)',
      []
    )
  }

  const insertUser = async (name: string) => {
    await execute('INSERT INTO users (name) VALUES (?)', [name])
  }

  const getUsers = async () => {
    const rows = await query('SELECT * FROM users', [])
    return rows
  }

  return (
    <div>
      <button onClick={createTable}>Create Table</button>
      <button onClick={() => insertUser('John')}>Add User</button>
      <button onClick={async () => console.log(await getUsers())}>
        Get Users
      </button>
    </div>
  )
}
```

## License

MIT
