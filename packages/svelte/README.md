# @craft-native/svelte

Svelte stores for [Craft Native](https://github.com/stacksjs/craft) - Build native mobile and desktop apps with JavaScript.

## Installation

```bash
npm install @craft-native/svelte
# or
pnpm add @craft-native/svelte
# or
bun add @craft-native/svelte
```

## Usage

### Basic Example

```svelte
<script lang="ts">
  import { craft, createWindowStore, createNotificationStore } from '@craft-native/svelte'

  const windowStore = createWindowStore()
  const notificationStore = createNotificationStore()

  function handleNotify() {
    $notificationStore.notify({
      title: 'Hello from Craft!',
      body: 'This is a native notification'
    })
  }

  function minimizeWindow() {
    $windowStore.minimize()
  }
</script>

<main>
  <h1>Craft Native + Svelte</h1>
  <button on:click={handleNotify}>Send Notification</button>
  <button on:click={minimizeWindow}>Minimize Window</button>
</main>
```

### Available Stores

#### Core Store

- **`craft`** - The main Craft bridge writable store

#### Desktop Stores

- **`createWindowStore()`** - Window management (show, hide, toggle, minimize, close)
- **`createTrayStore()`** - System tray management
- **`createNotificationStore()`** - System notifications

#### Mobile Stores

- **`createDeviceInfoStore()`** - Get device information (readable store)
- **`createPermissionStore(permission)`** - Request and check permissions (store with `request()` and `check()` methods)
- **`createHapticStore()`** - Haptic feedback
- **`createVibrateStore()`** - Device vibration
- **`createToastStore()`** - Toast messages
- **`createCameraStore()`** - Camera access
- **`createPhotoPickerStore()`** - Photo picker
- **`createShareStore()`** - Share functionality
- **`createBiometricStore()`** - Biometric authentication (store with `authenticate()` method)
- **`createSecureStorageStore()`** - Secure key-value storage

#### File System & Database Stores

- **`createFileSystemStore()`** - File system operations
- **`createDatabaseStore()`** - SQLite database operations

### Examples

#### Camera Access

```svelte
<script lang="ts">
  import { createCameraStore } from '@craft-native/svelte'

  const camera = createCameraStore()

  async function takePicture() {
    const result = await $camera.open({ type: 'back', mediaType: 'photo' })
    console.log('Photo:', result)
  }
</script>

<button on:click={takePicture}>Take Picture</button>
```

#### Biometric Authentication

```svelte
<script lang="ts">
  import { createBiometricStore } from '@craft-native/svelte'

  const biometric = createBiometricStore()

  async function handleAuth() {
    if (!$biometric) {
      alert('Biometric not available')
      return
    }

    try {
      const result = await biometric.authenticate('Please authenticate to continue')
      console.log('Authenticated:', result)
    } catch (error) {
      console.error('Auth failed:', error)
    }
  }
</script>

<button on:click={handleAuth} disabled={!$biometric}>
  Authenticate with Biometric
</button>
```

#### Device Info

```svelte
<script lang="ts">
  import { createDeviceInfoStore } from '@craft-native/svelte'

  const deviceInfo = createDeviceInfoStore()
</script>

{#if $deviceInfo}
  <div>
    <p>Model: {$deviceInfo.model}</p>
    <p>OS: {$deviceInfo.osVersion}</p>
    <p>Platform: {$deviceInfo.platform}</p>
  </div>
{/if}
```

#### Database Operations

```svelte
<script lang="ts">
  import { writable } from 'svelte/store'
  import { createDatabaseStore } from '@craft-native/svelte'

  const db = createDatabaseStore()
  const users = writable([])

  async function createTable() {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)',
      []
    )
  }

  async function insertUser(name: string) {
    await db.execute('INSERT INTO users (name) VALUES (?)', [name])
    await loadUsers()
  }

  async function loadUsers() {
    const rows = await db.query('SELECT * FROM users', [])
    users.set(rows)
  }
</script>

<button on:click={createTable}>Create Table</button>
<button on:click={() => insertUser('John')}>Add User</button>
<button on:click={loadUsers}>Refresh Users</button>

<ul>
  {#each $users as user (user.id)}
    <li>{user.name}</li>
  {/each}
</ul>
```

#### Permissions

```svelte
<script lang="ts">
  import { createPermissionStore } from '@craft-native/svelte'

  const cameraPermission = createPermissionStore('camera')

  async function requestCamera() {
    const newStatus = await cameraPermission.request()
    console.log('Permission status:', newStatus)
  }
</script>

<p>Camera permission: {$cameraPermission}</p>
<button on:click={requestCamera}>Request Camera Permission</button>
```

### Using the Craft Action

```svelte
<script lang="ts">
  import { craft_action } from '@craft-native/svelte'
</script>

<div use:craft_action>
  <!-- Your content -->
</div>
```

## Store Architecture

All stores in `@craft-native/svelte` use Svelte's native store contracts:

- **Readable stores**: Subscribe-only stores for read-only data (e.g., device info)
- **Writable stores**: Full read/write access (e.g., the main craft store)
- **Derived stores**: Computed stores that react to changes in the craft bridge

Stores automatically handle the Craft bridge initialization and update reactively when the bridge becomes available.

## License

MIT
