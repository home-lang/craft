# Quick Start

Create your first Craft application in 5 minutes.

## Prerequisites

- [Bun](https://bun.sh) v1.0 or later
- [Zig](https://ziglang.org) 0.13.0 or later (for desktop)
- macOS 12+, Windows 10+, or Linux

## Create a New Project

```bash
# Create a new Craft app
bunx craft init my-app

# Navigate to the project
cd my-app

# Start development server
bun run dev
```

Your app will open automatically. Any changes you make will hot-reload instantly.

## Project Structure

```
my-app/
├── craft.config.ts    # App configuration
├── package.json       # Dependencies
├── index.html         # Entry HTML
├── src/
│   ├── main.ts       # Main application code
│   └── styles.css    # Styles
└── assets/           # Icons, images, etc.
```

## Understanding craft.config.ts

```typescript
import type { CraftAppConfig } from '@stacksjs/ts-craft'

const config: CraftAppConfig = {
  name: 'My App',
  version: '1.0.0',
  identifier: 'com.example.myapp',

  window: {
    title: 'My App',
    width: 1200,
    height: 800,
    minWidth: 400,
    minHeight: 300
  },

  entry: './index.html'
}

export default config
```

## Your First App

Edit `src/main.ts`:

```typescript
import { window, notification, Platform } from '@stacksjs/ts-craft'

// Update window title
window.setTitle('Hello Craft!')

// Create UI
document.getElementById('app')!.innerHTML = `
  <div class="container">
    <h1>Welcome to Craft</h1>
    <p>Running on ${Platform.OS}</p>
    <button id="notify-btn">Send Notification</button>
  </div>
`

// Add interactivity
document.getElementById('notify-btn')!.addEventListener('click', async () => {
  await notification.show({
    title: 'Hello!',
    body: 'This is a native notification'
  })
})
```

## Adding Styles

Edit `src/styles.css`:

```css
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: system-ui, -apple-system, sans-serif;
  background: #f5f5f5;
  color: #333;
}

.container {
  max-width: 600px;
  margin: 0 auto;
  padding: 2rem;
  text-align: center;
}

h1 {
  font-size: 2.5rem;
  margin-bottom: 1rem;
}

button {
  background: #007AFF;
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  font-size: 1rem;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.2s;
}

button:hover {
  background: #0056b3;
}

/* Dark mode support */
@media (prefers-color-scheme: dark) {
  body {
    background: #1a1a1a;
    color: #fff;
  }
}
```

## Using Headwind CSS

Craft includes Headwind for Tailwind-style utilities:

```typescript
import { tw, cx } from '@stacksjs/ts-craft'

const buttonClass = tw`
  px-4 py-2
  bg-blue-500 text-white
  rounded-lg
  hover:bg-blue-600
  transition-colors
`

document.getElementById('app')!.innerHTML = `
  <button class="${buttonClass}">Click me</button>
`
```

## Building for Production

```bash
# Build for current platform
bun run build

# Build for specific platforms
bun run build:macos
bun run build:windows
bun run build:linux

# Build release version
bun run build:release
```

## Next Steps

- [Project Structure](./project-structure.md) - Learn about Craft projects
- [Platform APIs](./platform-apis.md) - Access native features
- [Styling](./styling.md) - Style your application
- [Configuration](./configuration.md) - Configure your app

## Example: Counter App

Here's a complete counter app example:

```typescript
// src/main.ts
import { window, haptics, Platform } from '@stacksjs/ts-craft'
import { tw } from '@stacksjs/ts-craft'

let count = 0

function updateUI() {
  window.setTitle(`Counter: ${count}`)

  document.getElementById('app')!.innerHTML = `
    <div class="${tw`flex flex-col items-center justify-center min-h-screen p-4`}">
      <h1 class="${tw`text-4xl font-bold mb-8`}">Count: ${count}</h1>

      <div class="${tw`flex gap-4`}">
        <button
          id="decrement"
          class="${tw`px-6 py-3 text-xl bg-red-500 text-white rounded-lg`}"
        >
          −
        </button>
        <button
          id="increment"
          class="${tw`px-6 py-3 text-xl bg-green-500 text-white rounded-lg`}"
        >
          +
        </button>
      </div>

      <p class="${tw`mt-4 text-gray-500`}">
        Running on ${Platform.OS}
      </p>
    </div>
  `

  // Re-attach event listeners
  document.getElementById('increment')!.onclick = async () => {
    count++
    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      await haptics.impact('light')
    }
    updateUI()
  }

  document.getElementById('decrement')!.onclick = async () => {
    count--
    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      await haptics.impact('light')
    }
    updateUI()
  }
}

// Initialize
updateUI()
```
