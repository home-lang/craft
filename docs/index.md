---
layout: home
hero:
  name: Craft
  text: Build Native Apps with Web Technologies
  tagline: A lightweight, high-performance desktop framework powered by Zig. 1.4MB binary, <100ms startup.
  actions:
    - theme: brand
      text: Get Started
      link: /intro
    - theme: alt
      text: View on GitHub
      link: https://github.com/stacksjs/craft
features:
  - icon: "🚀"
    title: Blazing Fast
    details: Sub-100ms startup time with a tiny 1.4MB binary. Your apps launch instantly.
  - icon: "💾"
    title: Lightweight
    details: ~92MB memory footprint vs Electron's ~200MB. Perfect for menubar apps and utilities.
  - icon: "🌍"
    title: Cross-Platform
    details: Build once, run on macOS, Linux, Windows, iOS, and Android with native performance.
  - icon: "🔧"
    title: Native APIs
    details: Access file system, notifications, clipboard, system info, and 35+ native UI components.
  - icon: "🎨"
    title: Use Any Framework
    details: Works with React, Vue, Svelte, or vanilla HTML/CSS/JS. Bring your favorite tools.
  - icon: "⚡"
    title: Powered by Zig
    details: Built on Zig for maximum efficiency, minimal dependencies, and rock-solid stability.
---

<div class="custom-block tip" style="margin: 2rem auto; max-width: 800px; padding: 1.5rem;">
<h2 style="margin-top: 0;">Why Craft?</h2>

| Metric | Craft | Electron | Tauri |
|--------|-------|----------|-------|
| **Binary Size** | **1.4MB** | ~150MB | ~2MB |
| **Memory (idle)** | **~92MB** | ~200MB | ~80MB |
| **Startup Time** | **<100ms** | ~1000ms | ~100ms |
| **CPU (idle)** | **<1%** | ~4% | <1% |

</div>

## Quick Start

```bash
# Install the TypeScript SDK
bun add ts-craft

# Or scaffold a new project
bun create craft my-app
```

```typescript
import { show } from '@stacksjs/ts-craft'

await show(`
  <h1>Hello from Craft!</h1>
  <p>Building native apps has never been easier.</p>
`, {
  title: 'My App',
  width: 800,
  height: 600,
})
```

<div style="text-align: center; margin: 2rem 0;">
  <a href="/intro" style="display: inline-block; padding: 0.75rem 1.5rem; background: var(--bp-c-brand-1, #5c6bc0); color: white; text-decoration: none; border-radius: 8px; font-weight: 600;">Read the Documentation →</a>
</div>
