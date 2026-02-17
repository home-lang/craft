# Performance

This guide covers performance optimization strategies for Craft applications.

## Performance Characteristics

Craft is designed for high performance:

| Metric | Craft | Electron | Tauri |
|--------|-------|----------|-------|
| Binary Size | **1.4MB** | ~150MB | ~2MB |
| Memory (idle) | **~92MB** | ~200MB | ~80MB |
| Startup Time | **<100ms** | ~1000ms | ~100ms |
| CPU (idle) | **<1%** | ~4% | <1% |

## Startup Optimization

### Lazy Loading

```typescript
// Don't load everything at startup
const heavyModule = await import('./heavy-module')

// Or use dynamic imports in handlers
app.handle('heavy-operation', async (data) => {
  const { process } = await import('./heavy-processor')
  return process(data)
})
```

### Preload Critical Resources

```typescript
// Preload essential modules during startup
await Promise.all([
  import('./core-module'),
  import('./ui-components'),
])

// Then show the window
window.show()
```

### Defer Non-Critical Work

```typescript
// Show window immediately
const window = await createWindow(html, {
  show: true,
})

// Then load additional features
setTimeout(async () => {
  await loadAnalytics()
  await checkForUpdates()
  await syncUserData()
}, 1000)
```

## Memory Optimization

### Monitor Memory Usage

```typescript
import { getMemoryUsage } from '@stacksjs/ts-craft'

setInterval(() => {
  const memory = getMemoryUsage()
  console.log({
    heapUsed: `${Math.round(memory.heapUsed / 1024 / 1024)}MB`,
    heapTotal: `${Math.round(memory.heapTotal / 1024 / 1024)}MB`,
    external: `${Math.round(memory.external / 1024 / 1024)}MB`,
  })
}, 5000)
```

### Cleanup Resources

```typescript
// Clean up when window is hidden
window.on('hide', () => {
  clearCaches()
  releaseMemory()
})

// Clean up when app is backgrounded
app.on('blur', () => {
  reducedMemoryMode()
})
```

### Efficient Data Structures

```typescript
// Use appropriate data structures
// Bad: Array for frequent lookups
const items = [{ id: 1, name: 'A' }, { id: 2, name: 'B' }]
const item = items.find((i) => i.id === 1) // O(n)

// Good: Map for frequent lookups
const itemMap = new Map([[1, { id: 1, name: 'A' }], [2, { id: 2, name: 'B' }]])
const item = itemMap.get(1) // O(1)
```

### Avoid Memory Leaks

```typescript
// Remove event listeners when done
const handler = () => { /* ... */ }
window.on('event', handler)

// Later...
window.off('event', handler)

// Or use auto-cleanup
const cleanup = window.on('event', handler)
// Later...
cleanup()
```

## Rendering Performance

### Minimize DOM Operations

```html
<script>
  // Bad: Multiple DOM updates
  items.forEach((item) => {
    const el = document.createElement('div')
    el.textContent = item.name
    container.appendChild(el)
  })

  // Good: Batch DOM updates
  const fragment = document.createDocumentFragment()
  items.forEach((item) => {
    const el = document.createElement('div')
    el.textContent = item.name
    fragment.appendChild(el)
  })
  container.appendChild(fragment)
</script>
```

### Virtual Scrolling

For large lists, implement virtual scrolling:

```html
<script>
  // Only render visible items
  function renderVisibleItems(scrollTop, viewportHeight) {
    const startIndex = Math.floor(scrollTop / itemHeight)
    const endIndex = Math.min(
      startIndex + Math.ceil(viewportHeight / itemHeight) + 1,
      items.length,
    )

    const visibleItems = items.slice(startIndex, endIndex)
    // Render only visibleItems
  }
</script>
```

### Hardware Acceleration

```css
/* Enable hardware acceleration for animations */
.animated-element {
  transform: translateZ(0);
  will-change: transform;
}

/* Use transform instead of position */
.moving-element {
  /* Bad */
  left: 100px;

  /* Good */
  transform: translateX(100px);
}
```

## IPC Optimization

### Batch Messages

```typescript
// Bad: Many small messages
items.forEach((item) => {
  window.emit('item-update', item)
})

// Good: Single batch message
window.emit('items-update', items)
```

### Debounce High-Frequency Events

```typescript
import { debounce } from 'ts-craft/utils'

// Debounce search input
const debouncedSearch = debounce((query) => {
  window.emit('search', query)
}, 300)

input.addEventListener('input', (e) => {
  debouncedSearch(e.target.value)
})
```

### Use Channels for Streams

```typescript
// For continuous data streams, use channels
const channel = window.createChannel('telemetry')

// Efficient batch sends
setInterval(() => {
  channel.send(collectTelemetry())
}, 100)
```

## Build Optimization

### Tree Shaking

```typescript
// Import only what you need
import { show } from '@stacksjs/ts-craft' // Good
import * as craft from '@stacksjs/ts-craft' // Bad - imports everything
```

### Code Splitting

```typescript
// Split code by route/feature
const routes = {
  '/': () => import('./pages/home'),
  '/settings': () => import('./pages/settings'),
  '/editor': () => import('./pages/editor'),
}

// Load on demand
async function loadRoute(path) {
  const module = await routes[path]()
  return module.default
}
```

### Asset Optimization

```typescript
// craft.config.ts
export default {
  build: {
    // Minify output
    minify: true,

    // Compress assets
    compress: true,

    // Optimize images
    imageOptimization: {
      quality: 80,
      format: 'webp',
    },

    // Bundle size analysis
    analyze: true,
  },
}
```

## Native Code Optimization

### Use Native Code for Hot Paths

```typescript
// Identify performance-critical code
import { benchmark } from 'ts-craft/perf'

benchmark('computation', () => {
  // If this is slow, consider native implementation
  heavyComputation()
})

// Move to native
import { nativeHeavyComputation } from './native'
```

### Parallel Processing

```zig
// Use Zig's parallel processing
const std = @import("std");

pub fn processParallel(items: []Item) void {
    var threads = std.ArrayList(std.Thread).init(allocator);
    defer threads.deinit();

    for (items) |item| {
        const thread = std.Thread.spawn(.{}, processItem, .{item});
        threads.append(thread);
    }

    for (threads.items) |thread| {
        thread.join();
    }
}
```

## Profiling

### Built-in Profiler

```typescript
import { profiler } from 'ts-craft/perf'

// Start profiling
profiler.start()

// Run your code
await heavyOperation()

// Get results
const report = profiler.stop()
console.log(report)
// {
//   duration: 1234,
//   memory: { start: 50000000, end: 52000000, peak: 55000000 },
//   events: [...]
// }
```

### Chrome DevTools

```typescript
// Enable DevTools profiling
const window = await createWindow(html, {
  webview: {
    devTools: true,
  },
})

// Use Chrome DevTools Performance tab
```

### Native Profiling

```bash
# Profile with Instruments (macOS)
instruments -t "Time Profiler" ./my-app

# Profile with perf (Linux)
perf record -g ./my-app
perf report
```

## Benchmarking

### Micro-benchmarks

```typescript
import { bench } from 'ts-craft/perf'

bench('string concatenation', () => {
  const str = 'hello' + ' ' + 'world'
})

bench('template literal', () => {
  const str = `hello world`
})

// Output:
// string concatenation: 1,234,567 ops/sec
// template literal: 2,345,678 ops/sec
```

### Application Benchmarks

```typescript
import { benchmark } from 'ts-craft/perf'

const results = await benchmark({
  'startup time': async () => {
    const app = await createApp()
    await app.ready()
    app.quit()
  },

  'window creation': async () => {
    const window = await createWindow(html)
    window.close()
  },
})

console.log(results)
```

## Best Practices

### General Guidelines

1. **Measure first**: Don't optimize without profiling
2. **Focus on hot paths**: Optimize frequently executed code
3. **Avoid premature optimization**: Write clear code first
4. **Test on target platforms**: Performance varies by platform

### Checklist

- [ ] Profile startup time
- [ ] Check memory usage over time
- [ ] Measure IPC latency
- [ ] Test with large datasets
- [ ] Verify smooth animations (60fps)
- [ ] Test on minimum spec hardware

### Performance Budget

```typescript
// craft.config.ts
export default {
  build: {
    performanceBudget: {
      maxBundleSize: '5MB',
      maxStartupTime: '500ms',
      maxMemory: '150MB',
    },
  },
}
```

## Next Steps

- [Cross-Platform](/advanced/cross-platform) - Platform-specific optimization
- [Configuration](/advanced/configuration) - Build configuration
- [Custom Bindings](/advanced/custom-bindings) - Native performance code
