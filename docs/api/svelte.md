# Svelte Stores

Svelte stores and actions for integrating Craft APIs.

## Import

```typescript
import {
  craft,
  craftWindow,
  craftTray,
  craftNotification,
  craftTheme,
  craftMobile,
  shortcut
} from 'ts-craft/svelte'
```

## Stores

### craft

Core Craft store with initialization state.

```svelte
<script>
  import { craft } from 'ts-craft/svelte'
</script>

{#if $craft.error}
  <p>Error: {$craft.error.message}</p>
{:else if !$craft.isReady}
  <p>Loading...</p>
{:else}
  <MainApp />
{/if}
```

**Store value:**
| Property | Type | Description |
|----------|------|-------------|
| instance | `Craft` | Craft instance |
| isReady | `boolean` | True when initialized |
| error | `Error \| null` | Initialization error |

---

### craftWindow

Window control store.

```svelte
<script>
  import { craftWindow } from 'ts-craft/svelte'

  function toggleFullscreen() {
    craftWindow.setFullscreen(!$craftWindow.isFullscreen)
  }
</script>

<div class="title-bar">
  <span>{$craftWindow.title}</span>

  <div class="controls">
    <button on:click={() => craftWindow.minimize()}>−</button>
    <button on:click={toggleFullscreen}>⤢</button>
    <button on:click={() => craftWindow.close()}>×</button>
  </div>
</div>

<input
  bind:value={$craftWindow.title}
  on:change={() => craftWindow.setTitle($craftWindow.title)}
/>
```

**Store value:**
| Property | Type | Description |
|----------|------|-------------|
| title | `string` | Window title |
| isFullscreen | `boolean` | Fullscreen state |
| isMaximized | `boolean` | Maximized state |
| isVisible | `boolean` | Window visibility |

**Store methods:**
| Method | Description |
|--------|-------------|
| setTitle(title) | Set window title |
| setFullscreen(bool) | Toggle fullscreen |
| minimize() | Minimize window |
| maximize() | Maximize/restore |
| close() | Close window |
| show() | Show window |
| hide() | Hide window |

---

### craftTray

System tray store.

```svelte
<script>
  import { craftTray } from 'ts-craft/svelte'
  import { onMount } from 'svelte'

  onMount(() => {
    craftTray.setup({
      icon: '/assets/tray-icon.png',
      tooltip: 'My App',
      menu: [
        { label: 'Show', action: 'show' },
        { label: 'Quit', action: 'quit' }
      ],
      onAction: (action) => {
        if (action === 'quit') {
          craftWindow.close()
        }
      }
    })
  })

  function updateTooltip(status) {
    craftTray.setTooltip(`My App - ${status}`)
  }
</script>
```

---

### craftNotification

Notification store.

```svelte
<script>
  import { craftNotification } from 'ts-craft/svelte'

  async function notify() {
    if (!$craftNotification.hasPermission) {
      await craftNotification.requestPermission()
    }

    await craftNotification.show({
      title: 'Hello',
      body: 'This is a notification',
      onClick: () => console.log('Clicked!')
    })
  }
</script>

<button on:click={notify}>
  Send Notification
</button>
```

**Store value:**
| Property | Type | Description |
|----------|------|-------------|
| hasPermission | `boolean` | Permission granted |

**Store methods:**
| Method | Description |
|--------|-------------|
| show(options) | Show notification |
| requestPermission() | Request permission |

---

### craftTheme

Theme store.

```svelte
<script>
  import { craftTheme } from 'ts-craft/svelte'
</script>

<div class:dark={$craftTheme.isDark}>
  <select
    bind:value={$craftTheme.theme}
    on:change={() => craftTheme.setTheme($craftTheme.theme)}
  >
    <option value="system">System ({$craftTheme.systemTheme})</option>
    <option value="light">Light</option>
    <option value="dark">Dark</option>
  </select>
</div>

<style>
  div.dark {
    background: #1a1a1a;
    color: white;
  }
</style>
```

**Store value:**
| Property | Type | Description |
|----------|------|-------------|
| theme | `'light' \| 'dark' \| 'system'` | Current setting |
| systemTheme | `'light' \| 'dark'` | System preference |
| isDark | `boolean` | Dark mode active |

---

### craftMobile

Mobile-specific store.

```svelte
<script>
  import { craftMobile } from 'ts-craft/svelte'

  async function handleTap() {
    await $craftMobile.haptics.impact('light')
  }

  async function authenticate() {
    const { biometrics } = $craftMobile

    if (await biometrics.isAvailable()) {
      const result = await biometrics.authenticate({
        reason: 'Sign in'
      })

      if (result.success) {
        // Handle success
      }
    }
  }
</script>

<div
  style:padding-top="{$craftMobile.safeAreaInsets.top}px"
  style:padding-bottom="{$craftMobile.safeAreaInsets.bottom}px"
>
  <button on:click={handleTap}>Tap me</button>
  <button on:click={authenticate}>Login</button>
</div>
```

## Actions

### shortcut

Action for keyboard shortcuts.

```svelte
<script>
  import { shortcut } from 'ts-craft/svelte'

  let count = 0

  function increment() {
    count++
  }

  function decrement() {
    count--
  }

  async function save() {
    await saveDocument()
  }
</script>

<svelte:window
  use:shortcut={{ key: 'mod+up', handler: increment }}
  use:shortcut={{ key: 'mod+down', handler: decrement }}
  use:shortcut={{ key: 'mod+s', handler: save, preventDefault: true }}
/>

<p>Count: {count}</p>
<p>Use ⌘↑/⌘↓ to change, ⌘S to save</p>
```

**Options:**
| Property | Type | Description |
|----------|------|-------------|
| key | `string` | Key combination |
| handler | `(e: KeyboardEvent) => void` | Callback |
| preventDefault | `boolean` | Prevent default action |

## Example App

```svelte
<script>
  import {
    craft,
    craftWindow,
    craftTheme,
    craftNotification,
    shortcut
  } from 'ts-craft/svelte'

  let count = 0

  $: craftWindow.setTitle(`Counter: ${count}`)

  function increment() {
    count++
  }

  function decrement() {
    count--
  }

  function reset() {
    count = 0
  }

  function toggleTheme() {
    craftTheme.setTheme($craftTheme.isDark ? 'light' : 'dark')
  }

  async function notify() {
    await craftNotification.show({
      title: 'Counter Update',
      body: `Count is now ${count}`
    })
  }
</script>

<svelte:window
  use:shortcut={{ key: 'mod+up', handler: increment }}
  use:shortcut={{ key: 'mod+down', handler: decrement }}
  use:shortcut={{ key: 'mod+r', handler: reset }}
  use:shortcut={{ key: 'mod+t', handler: toggleTheme }}
/>

{#if !$craft.isReady}
  <div class="loading">Loading...</div>
{:else}
  <div class="app" class:dark={$craftTheme.isDark}>
    <h1>Count: {count}</h1>

    <div class="buttons">
      <button on:click={decrement}>-</button>
      <button on:click={increment}>+</button>
    </div>

    <button on:click={notify}>Notify</button>

    <p class="hint">
      Use ⌘↑/⌘↓ to increment/decrement, ⌘R to reset, ⌘T to toggle theme
    </p>
  </div>
{/if}

<style>
  .app {
    padding: 2rem;
    text-align: center;
    transition: background-color 0.3s, color 0.3s;
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

  .dark .hint {
    color: #999;
  }
</style>
```

## SvelteKit Integration

For SvelteKit apps, initialize Craft in the root layout:

```svelte
<!-- +layout.svelte -->
<script>
  import { craft } from 'ts-craft/svelte'
  import { browser } from '$app/environment'
  import { onMount } from 'svelte'

  onMount(() => {
    if (browser) {
      // Craft auto-initializes, but you can check status
      console.log('Craft ready:', $craft.isReady)
    }
  })
</script>

{#if $craft.isReady}
  <slot />
{:else}
  <div class="loading">Loading...</div>
{/if}
```
