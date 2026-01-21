# Custom Bindings

Craft allows you to extend its functionality with custom native bindings, enabling access to platform-specific APIs and third-party libraries.

## Overview

Custom bindings enable:

- **Native Library Integration**: Use C/C++/Zig libraries
- **Platform-Specific APIs**: Access OS-specific features
- **Performance-Critical Code**: Implement hot paths in native code
- **Hardware Access**: Interface with devices and sensors

## JavaScript Bridge Extensions

### Register Custom Handler

```typescript
import { createApp } from 'ts-craft'

const app = await createApp(html, options)

// Register a custom handler
app.handle('my-custom-function', async (arg1, arg2) => {
  // Custom implementation
  const result = await doSomething(arg1, arg2)
  return result
})
```

### Use from Web

```html
<script>
  // Call custom function from web
  const result = await window.craft.invoke('my-custom-function', 'arg1', 'arg2')
  console.log(result)
</script>
```

## Creating Native Plugins

### Plugin Structure

```
my-plugin/
├── src/
│   ├── index.ts      # TypeScript bindings
│   └── native/
│       └── lib.zig   # Zig implementation
├── package.json
└── craft.plugin.ts   # Plugin manifest
```

### Plugin Manifest

```typescript
// craft.plugin.ts
import type { CraftPlugin } from 'ts-craft'

export default {
  name: 'my-plugin',
  version: '1.0.0',

  // Lifecycle hooks
  setup(app) {
    // Called when app initializes
  },

  // Register handlers
  handlers: {
    'my-plugin:action': async (data) => {
      return await performAction(data)
    },
  },

  // Register events
  events: ['my-plugin:event'],
} satisfies CraftPlugin
```

### Using Plugins

```typescript
// craft.config.ts
import myPlugin from 'my-plugin'

export default {
  plugins: [
    myPlugin({
      option: 'value',
    }),
  ],
}
```

## Zig Native Extensions

### Basic Zig Binding

```zig
// src/native/lib.zig
const std = @import("std");

// Export function to JavaScript
export fn calculate(a: i32, b: i32) i32 {
    return a + b;
}

// Export async function
export fn fetchData(url_ptr: [*]const u8, url_len: usize) ?[*]u8 {
    const url = url_ptr[0..url_len];
    // Fetch implementation...
    return result;
}
```

### Build Configuration

```zig
// build.zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "my-plugin",
        .root_source_file = .{ .path = "src/native/lib.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);
}
```

### TypeScript Bindings

```typescript
// src/index.ts
import { loadNativeLibrary } from 'ts-craft'

const lib = loadNativeLibrary('./libmy-plugin')

export function calculate(a: number, b: number): number {
  return lib.call('calculate', a, b)
}

export async function fetchData(url: string): Promise<string> {
  return lib.callAsync('fetchData', url)
}
```

## FFI Integration

### Using Node-API (N-API)

```typescript
// For complex native modules
import { createRequire } from 'module'

const require = createRequire(import.meta.url)
const nativeModule = require('./build/Release/native.node')

export const myFunction = nativeModule.myFunction
```

### Using Bun FFI

```typescript
import { dlopen, FFIType, suffix } from 'bun:ffi'

const lib = dlopen(`./libexample.${suffix}`, {
  add: {
    args: [FFIType.i32, FFIType.i32],
    returns: FFIType.i32,
  },
  getString: {
    args: [],
    returns: FFIType.cstring,
  },
})

export const add = lib.symbols.add
export const getString = lib.symbols.getString
```

## Platform-Specific Bindings

### macOS Bindings

```typescript
// src/macos.ts
import { platform } from 'ts-craft'

if (platform === 'darwin') {
  // macOS-specific implementation
  const cocoaLib = loadNativeLibrary('./libcocoa-bridge')

  export function showDockBadge(text: string) {
    cocoaLib.call('showDockBadge', text)
  }

  export function setDockIcon(iconPath: string) {
    cocoaLib.call('setDockIcon', iconPath)
  }
}
```

### Windows Bindings

```typescript
// src/windows.ts
import { platform } from 'ts-craft'

if (platform === 'win32') {
  const winLib = loadNativeLibrary('./libwin-bridge')

  export function showJumpList(items: JumpListItem[]) {
    winLib.call('showJumpList', JSON.stringify(items))
  }

  export function setTaskbarProgress(progress: number) {
    winLib.call('setTaskbarProgress', progress)
  }
}
```

### Cross-Platform Wrapper

```typescript
// src/platform-features.ts
import { platform } from 'ts-craft'

export interface PlatformFeatures {
  showBadge(text: string): void
  setProgress(value: number): void
}

async function loadPlatformFeatures(): Promise<PlatformFeatures> {
  switch (platform) {
    case 'darwin':
      return import('./macos')
    case 'win32':
      return import('./windows')
    case 'linux':
      return import('./linux')
    default:
      throw new Error(`Unsupported platform: ${platform}`)
  }
}

export const features = await loadPlatformFeatures()
```

## Event Extensions

### Custom Events from Native

```zig
// In Zig
const craft = @import("craft");

pub fn monitorSomething() void {
    while (true) {
        const value = readSensor();
        craft.emitEvent("sensor:reading", .{
            .value = value,
            .timestamp = std.time.milliTimestamp(),
        });
        std.time.sleep(1000 * std.time.ns_per_ms);
    }
}
```

### Listen in JavaScript

```typescript
// In TypeScript
import { on } from 'ts-craft'

on('sensor:reading', (data) => {
  console.log(`Sensor value: ${data.value} at ${data.timestamp}`)
})
```

## Memory Management

### Handling Native Memory

```typescript
import { NativePointer } from 'ts-craft'

// Allocate native memory
const buffer = NativePointer.allocate(1024)

try {
  // Use the buffer
  nativeLib.call('processData', buffer.ptr, buffer.size)
}
finally {
  // Always free native memory
  buffer.free()
}
```

### Automatic Cleanup

```typescript
import { using } from 'ts-craft'

// Automatically freed when scope exits
await using(NativePointer.allocate(1024), async (buffer) => {
  await nativeLib.callAsync('processData', buffer.ptr, buffer.size)
})
```

## Error Handling

### Native Errors

```zig
// In Zig
export fn riskyOperation() !void {
    const result = try doSomething();
    if (result < 0) {
        return error.OperationFailed;
    }
}
```

```typescript
// In TypeScript
try {
  await nativeLib.callAsync('riskyOperation')
}
catch (error) {
  if (error.code === 'OperationFailed') {
    console.error('Native operation failed')
  }
}
```

## Performance Considerations

### Minimize Bridge Calls

```typescript
// Bad: Many small calls
for (const item of items) {
  nativeLib.call('process', item)
}

// Good: Batch call
nativeLib.call('processBatch', items)
```

### Use Typed Arrays

```typescript
// Efficient data transfer
const data = new Float32Array([1.0, 2.0, 3.0])
nativeLib.call('processFloats', data.buffer)
```

### Async for Heavy Operations

```typescript
// Don't block the main thread
const result = await nativeLib.callAsync('heavyComputation', data)
```

## Testing Bindings

### Unit Tests

```typescript
import { describe, test, expect } from 'bun:test'
import { calculate } from './my-plugin'

describe('Native Bindings', () => {
  test('calculate adds numbers', () => {
    expect(calculate(2, 3)).toBe(5)
  })
})
```

### Integration Tests

```typescript
import { createTestApp } from 'ts-craft/testing'

test('custom handler works', async () => {
  const app = await createTestApp()

  app.handle('test-handler', () => 'success')

  const result = await app.invoke('test-handler')
  expect(result).toBe('success')
})
```

## Publishing Plugins

### Package.json

```json
{
  "name": "craft-plugin-my-feature",
  "version": "1.0.0",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "files": [
    "dist/",
    "native/"
  ],
  "peerDependencies": {
    "ts-craft": "^1.0.0"
  }
}
```

### Distribution

```bash
# Build native libraries for all platforms
npm run build:native

# Package and publish
npm publish
```

## Next Steps

- [Performance](/advanced/performance) - Optimize native bindings
- [Cross-Platform](/advanced/cross-platform) - Platform-specific considerations
- [Configuration](/advanced/configuration) - Plugin configuration
