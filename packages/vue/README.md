# @craft-native/vue

Vue 3 composables for [Craft Native](https://github.com/stacksjs/craft) - Build native mobile and desktop apps with JavaScript.

## Installation

```bash
npm install @craft-native/vue
# or
pnpm add @craft-native/vue
# or
bun add @craft-native/vue
```

## Usage

### Basic Example

```vue
<script setup lang="ts">
import { useCraft, useWindow, useNotification } from '@craft-native/vue'

const craft = useCraft()
const { show, hide, minimize } = useWindow()
const { notify } = useNotification()

const handleNotify = () => {
  notify({
    title: 'Hello from Craft!',
    body: 'This is a native notification'
  })
}
</script>

<template>
  <div>
    <h1>Craft Native + Vue</h1>
    <button @click="handleNotify">Send Notification</button>
    <button @click="minimize">Minimize Window</button>
  </div>
</template>
```

### Available Composables

#### Desktop Composables

- **`useCraft()`** - Access the main Craft bridge
- **`useWindow()`** - Window management (show, hide, toggle, minimize, close)
- **`useTray()`** - System tray management
- **`useNotification()`** - System notifications

#### Mobile Composables

- **`useDeviceInfo()`** - Get device information (returns reactive `deviceInfo`)
- **`usePermission(permission)`** - Request and check permissions (returns `{ status, request, check }`)
- **`useHaptic()`** - Haptic feedback
- **`useVibrate()`** - Device vibration
- **`useToast()`** - Toast messages
- **`useCamera()`** - Camera access
- **`usePhotoPicker()`** - Photo picker
- **`useShare()`** - Share functionality
- **`useBiometric()`** - Biometric authentication (returns `{ available, authenticate }`)
- **`useSecureStorage()`** - Secure key-value storage

#### File System & Database Composables

- **`useFileSystem()`** - File system operations
- **`useDatabase()`** - SQLite database operations

### Global Plugin

Register Craft globally (optional):

```ts
import { createApp } from 'vue'
import CraftPlugin from '@craft-native/vue'
import App from './App.vue'

const app = createApp(App)
app.use(CraftPlugin)
app.mount('#app')
```

Then access via `$craft`:

```vue
<script setup lang="ts">
import { getCurrentInstance } from 'vue'

const instance = getCurrentInstance()
const craft = instance?.appContext.config.globalProperties.$craft
</script>
```

### Examples

#### Camera Access

```vue
<script setup lang="ts">
import { useCamera } from '@craft-native/vue'

const { open } = useCamera()

const takePicture = async () => {
  const result = await open({ type: 'back', mediaType: 'photo' })
  console.log('Photo:', result)
}
</script>

<template>
  <button @click="takePicture">Take Picture</button>
</template>
```

#### Biometric Authentication

```vue
<script setup lang="ts">
import { useBiometric } from '@craft-native/vue'

const { available, authenticate } = useBiometric()

const handleAuth = async () => {
  if (!available.value) {
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
</script>

<template>
  <button @click="handleAuth" :disabled="!available">
    Authenticate with Biometric
  </button>
</template>
```

#### Device Info

```vue
<script setup lang="ts">
import { useDeviceInfo } from '@craft-native/vue'

const { deviceInfo } = useDeviceInfo()
</script>

<template>
  <div v-if="deviceInfo">
    <p>Model: {{ deviceInfo.model }}</p>
    <p>OS: {{ deviceInfo.osVersion }}</p>
    <p>Platform: {{ deviceInfo.platform }}</p>
  </div>
</template>
```

#### Database Operations

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { useDatabase } from '@craft-native/vue'

const { execute, query } = useDatabase()
const users = ref([])

const createTable = async () => {
  await execute(
    'CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)',
    []
  )
}

const insertUser = async (name: string) => {
  await execute('INSERT INTO users (name) VALUES (?)', [name])
  await loadUsers()
}

const loadUsers = async () => {
  users.value = await query('SELECT * FROM users', [])
}
</script>

<template>
  <div>
    <button @click="createTable">Create Table</button>
    <button @click="insertUser('John')">Add User</button>
    <button @click="loadUsers">Refresh Users</button>
    <ul>
      <li v-for="user in users" :key="user.id">{{ user.name }}</li>
    </ul>
  </div>
</template>
```

## License

MIT
