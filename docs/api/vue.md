# Vue Composables

Vue 3 Composition API composables for integrating Craft APIs.

## Import

```typescript
import {
  useCraft,
  useWindow,
  useTray,
  useNotification,
  useShortcut,
  useTheme,
  useMobile
} from 'ts-craft/vue'
```

## Composables

### useCraft()

Access the core Craft instance and initialization state.

```vue
<script setup lang="ts">
import { useCraft } from 'ts-craft/vue'

const { craft, isReady, error } = useCraft()
</script>

<template>
  <div v-if="error">Error: {{ error.message }}</div>
  <div v-else-if="!isReady">Loading...</div>
  <MainApp v-else />
</template>
```

**Returns:**
| Property | Type | Description |
|----------|------|-------------|
| craft | `Ref<Craft>` | Craft instance |
| isReady | `Ref<boolean>` | True when Craft is initialized |
| error | `Ref<Error \| null>` | Initialization error, if any |

---

### useWindow()

Control the application window.

```vue
<script setup lang="ts">
import { useWindow } from 'ts-craft/vue'

const {
  title,
  setTitle,
  isFullscreen,
  setFullscreen,
  minimize,
  maximize,
  close
} = useWindow()
</script>

<template>
  <div class="title-bar">
    <input v-model="title" @blur="setTitle(title)" />
    <div class="controls">
      <button @click="minimize">−</button>
      <button @click="setFullscreen(!isFullscreen)">⤢</button>
      <button @click="close">×</button>
    </div>
  </div>
</template>
```

**Returns:**
| Property | Type | Description |
|----------|------|-------------|
| title | `Ref<string>` | Window title (reactive) |
| setTitle | `(title: string) => void` | Set window title |
| isFullscreen | `Ref<boolean>` | Fullscreen state |
| setFullscreen | `(fullscreen: boolean) => void` | Toggle fullscreen |
| isMaximized | `Ref<boolean>` | Maximized state |
| minimize | `() => void` | Minimize window |
| maximize | `() => void` | Maximize/restore window |
| close | `() => void` | Close window |

---

### useTray(config?)

Manage the system tray icon.

```vue
<script setup lang="ts">
import { useTray } from 'ts-craft/vue'

const { setTooltip, setIcon } = useTray({
  icon: '/assets/tray-icon.png',
  tooltip: 'My App',
  menu: [
    { label: 'Open', action: 'open' },
    { type: 'separator' },
    { label: 'Quit', action: 'quit' }
  ],
  onAction: (action) => {
    if (action === 'quit') {
      window.close()
    }
  }
})

function updateStatus(status: string) {
  setTooltip(`My App - ${status}`)
}
</script>
```

---

### useNotification()

Show desktop notifications.

```vue
<script setup lang="ts">
import { useNotification } from 'ts-craft/vue'

const { show, hasPermission, requestPermission } = useNotification()

async function notifyUser() {
  if (!hasPermission.value) {
    await requestPermission()
  }

  await show({
    title: 'Task Complete',
    body: 'Your download has finished',
    onClick: () => openDownloads()
  })
}
</script>

<template>
  <button @click="notifyUser">Notify</button>
</template>
```

---

### useShortcut(shortcut, handler)

Register global keyboard shortcuts.

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { useShortcut } from 'ts-craft/vue'

const searchOpen = ref(false)
const content = ref('')

// Open search modal
useShortcut('mod+k', () => {
  searchOpen.value = true
})

// Save document
useShortcut('mod+s', async (e) => {
  e.preventDefault()
  await saveDocument(content.value)
})

// Escape to close modals
useShortcut('escape', () => {
  searchOpen.value = false
})
</script>
```

---

### useTheme()

Access and control the application theme.

```vue
<script setup lang="ts">
import { useTheme } from 'ts-craft/vue'

const { theme, setTheme, isDark, systemTheme } = useTheme()
</script>

<template>
  <div :class="{ dark: isDark }">
    <select :value="theme" @change="setTheme($event.target.value)">
      <option value="system">System ({{ systemTheme }})</option>
      <option value="light">Light</option>
      <option value="dark">Dark</option>
    </select>
  </div>
</template>
```

---

### useMobile()

Access mobile-specific APIs.

```vue
<script setup lang="ts">
import { useMobile } from 'ts-craft/vue'

const { platform, haptics, biometrics, safeAreaInsets } = useMobile()

async function onButtonTap() {
  await haptics.impact('light')
}

async function authenticateUser() {
  if (await biometrics.isAvailable()) {
    const result = await biometrics.authenticate({
      reason: 'Verify your identity'
    })
    if (result.success) {
      // Handle success
    }
  }
}
</script>

<template>
  <div
    class="app"
    :style="{
      paddingTop: `${safeAreaInsets.top}px`,
      paddingBottom: `${safeAreaInsets.bottom}px`
    }"
  >
    <button @click="onButtonTap">Tap Me</button>
    <button @click="authenticateUser">Login</button>
  </div>
</template>
```

## Example App

```vue
<script setup lang="ts">
import { ref, watch } from 'vue'
import {
  useCraft,
  useWindow,
  useTheme,
  useShortcut,
  useNotification
} from 'ts-craft/vue'

const { isReady } = useCraft()
const { title, setTitle } = useWindow()
const { isDark, setTheme } = useTheme()
const { show: notify } = useNotification()

const count = ref(0)

// Update window title when count changes
watch(count, (newCount) => {
  setTitle(`Counter: ${newCount}`)
})

// Keyboard shortcuts
useShortcut('mod+up', () => count.value++)
useShortcut('mod+down', () => count.value--)
useShortcut('mod+r', () => count.value = 0)
useShortcut('mod+t', () => setTheme(isDark.value ? 'light' : 'dark'))

function sendNotification() {
  notify({
    title: 'Counter Update',
    body: `Count is now ${count.value}`
  })
}
</script>

<template>
  <div v-if="!isReady" class="loading">Loading...</div>

  <div v-else :class="['app', { dark: isDark }]">
    <h1>Count: {{ count }}</h1>

    <div class="buttons">
      <button @click="count--">-</button>
      <button @click="count++">+</button>
    </div>

    <button @click="sendNotification">Notify</button>

    <p class="hint">
      Use ⌘↑/⌘↓ to increment/decrement, ⌘R to reset, ⌘T to toggle theme
    </p>
  </div>
</template>

<style scoped>
.app {
  padding: 2rem;
  text-align: center;
}

.app.dark {
  background: #1a1a1a;
  color: #ffffff;
}

.buttons {
  display: flex;
  gap: 1rem;
  justify-content: center;
  margin: 1rem 0;
}

button {
  padding: 0.5rem 1rem;
  font-size: 1rem;
  cursor: pointer;
}

.hint {
  color: #666;
  font-size: 0.875rem;
}
</style>
```

## Provide/Inject Pattern

For larger applications, you can provide the Craft instance to all components:

```vue
<!-- App.vue -->
<script setup lang="ts">
import { provide } from 'vue'
import { useCraft } from 'ts-craft/vue'

const craft = useCraft()
provide('craft', craft)
</script>

<!-- ChildComponent.vue -->
<script setup lang="ts">
import { inject } from 'vue'

const { isReady, craft } = inject('craft')
</script>
```
