# Craft Bridge Protocol

This document describes the bridge protocol used for communication between JavaScript/TypeScript and native Zig code in Craft applications.

## Overview

The Craft bridge enables web-based UI to call native functionality through a structured message-passing protocol. Communication is asynchronous and type-safe.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    JavaScript/TypeScript                     │
│                      (Web UI Layer)                          │
└─────────────────────────┬───────────────────────────────────┘
                          │ craft.* API calls
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     Bridge Layer                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Serializer  │  │  Router     │  │ Deserializer│        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────┬───────────────────────────────────┘
                          │ Native function calls
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Native Zig Layer                          │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐  │
│  │  Window   │ │  Dialog   │ │ Clipboard │ │   Tray    │  │
│  └───────────┘ └───────────┘ └───────────┘ └───────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Message Format

### Request (JS → Zig)

```json
{
  "id": "uuid-v4",
  "module": "window",
  "method": "setSize",
  "params": {
    "width": 800,
    "height": 600
  }
}
```

### Response (Zig → JS)

**Success:**
```json
{
  "id": "uuid-v4",
  "success": true,
  "result": { ... }
}
```

**Error:**
```json
{
  "id": "uuid-v4",
  "success": false,
  "error": {
    "code": "PERMISSION_DENIED",
    "message": "File system access not permitted"
  }
}
```

## Type Mapping

| Zig Type | TypeScript Type | JSON Representation |
|----------|-----------------|---------------------|
| `bool` | `boolean` | `true`/`false` |
| `i32`, `u32`, `i64`, `u64` | `number` | `123` |
| `f32`, `f64` | `number` | `3.14` |
| `[]const u8` | `string` | `"text"` |
| `?T` | `T \| null` | `null` or value |
| `struct` | `interface` | `{ field: value }` |
| `enum` | `string` | `"variant_name"` |
| `[]T` | `T[]` | `[value, ...]` |

## Bridge Modules

### Window Module (`craft.window`)

```typescript
interface WindowBridge {
  show(): Promise<void>;
  hide(): Promise<void>;
  minimize(): Promise<void>;
  maximize(): Promise<void>;
  close(): Promise<void>;
  setSize(options: { width: number; height: number }): Promise<void>;
  setPosition(options: { x: number; y: number }): Promise<void>;
  setTitle(options: { title: string }): Promise<void>;
  setFullscreen(options: { fullscreen: boolean }): Promise<void>;
  setResizable(options: { resizable: boolean }): Promise<void>;
  setAlwaysOnTop(options: { alwaysOnTop: boolean }): Promise<void>;
}
```

### Dialog Module (`craft.dialog`)

```typescript
interface DialogBridge {
  showOpenDialog(options: OpenDialogOptions): Promise<OpenDialogResult>;
  showSaveDialog(options: SaveDialogOptions): Promise<SaveDialogResult>;
  showMessageBox(options: MessageBoxOptions): Promise<MessageBoxResult>;
  showColorPicker(options?: ColorPickerOptions): Promise<ColorPickerResult>;
}
```

### Notification Module (`craft.notification`)

```typescript
interface NotificationBridge {
  show(options: NotificationOptions): Promise<void>;
  schedule(options: ScheduledNotificationOptions): Promise<void>;
  cancel(options: { id: string }): Promise<void>;
  setBadge(options: { count: number }): Promise<void>;
  requestPermission(): Promise<{ granted: boolean }>;
}
```

### File System Module (`craft.fs`)

```typescript
interface FSBridge {
  readFile(options: { path: string }): Promise<{ content: string }>;
  writeFile(options: { path: string; content: string }): Promise<void>;
  exists(options: { path: string }): Promise<{ exists: boolean }>;
  stat(options: { path: string }): Promise<FileStats>;
  mkdir(options: { path: string; recursive?: boolean }): Promise<void>;
  readdir(options: { path: string }): Promise<{ entries: DirEntry[] }>;
}
```

## Error Codes

| Code | Description |
|------|-------------|
| `UNKNOWN_METHOD` | Method not found in module |
| `INVALID_PARAMS` | Parameter validation failed |
| `PERMISSION_DENIED` | Operation not permitted |
| `NOT_FOUND` | Resource not found |
| `TIMEOUT` | Operation timed out |
| `INTERNAL_ERROR` | Unexpected internal error |
| `NOT_SUPPORTED` | Feature not supported on platform |

## Async Handling

All bridge calls return Promises. The bridge handles:

1. **Request queueing** - Multiple requests can be in flight
2. **Response matching** - Responses matched to requests by ID
3. **Timeout handling** - Configurable timeout per request
4. **Error propagation** - Errors thrown as rejected promises

## Security Considerations

1. **Input Validation** - All parameters validated before processing
2. **Path Sanitization** - File paths checked for traversal attacks
3. **Permission Checks** - Operations verify required permissions
4. **Resource Limits** - Memory and CPU limits enforced
5. **Sandboxing** - Plugins run in isolated environments

## Adding New Bridge Methods

### 1. Define in Zig

```zig
// bridge_example.zig
pub fn handleMyMethod(params: *const Params) !Response {
    // Validate params
    // Perform operation
    // Return result
}
```

### 2. Register in Router

```zig
// bridge.zig
fn routeRequest(module: []const u8, method: []const u8, params: anytype) !Response {
    if (std.mem.eql(u8, module, "example")) {
        if (std.mem.eql(u8, method, "myMethod")) {
            return bridge_example.handleMyMethod(params);
        }
    }
    return error.UnknownMethod;
}
```

### 3. Add TypeScript Types

```typescript
// craft-bridge.d.ts
interface ExampleBridge {
  myMethod(options: MyMethodOptions): Promise<MyMethodResult>;
}
```

## Performance Tips

1. **Batch Operations** - Combine multiple reads/writes when possible
2. **Use Streaming** - For large data, use streaming APIs
3. **Cache Results** - Cache expensive native calls in JS
4. **Minimize Serialization** - Use typed arrays for binary data
