# Bridge Protocol Architecture

This document details the architecture of Craft's JavaScript-to-Zig bridge system.

## Overview

The bridge enables bidirectional communication between JavaScript running in the WebView and native Zig code. It uses a JSON-RPC-like protocol for message passing.

## Protocol Specification

### Request Format

```mermaid
classDiagram
    class BridgeRequest {
        +string id
        +string method
        +object params
        +number timestamp
    }

    class BridgeResponse {
        +string id
        +boolean success
        +any result
        +BridgeError error
    }

    class BridgeError {
        +number code
        +string message
        +any data
    }

    BridgeResponse --> BridgeError
```

### Message Flow

```mermaid
sequenceDiagram
    autonumber
    participant App as Web App
    participant JS as window.craft
    participant Inject as Injected Script
    participant WV as WebView
    participant Bridge as Bridge Handler
    participant Zig as Native Code

    App->>JS: craft.clipboard.getText()
    JS->>JS: Generate unique ID
    JS->>JS: Create Promise
    JS->>Inject: postMessage(request)
    Inject->>WV: webkit.messageHandlers.craft.postMessage()
    WV->>Bridge: handleMessage(json)
    Bridge->>Bridge: Parse & validate
    Bridge->>Zig: clipboardGetText()
    Zig-->>Bridge: Return text
    Bridge->>WV: evaluateJavaScript(response)
    WV->>Inject: craftHandleResponse(id, result)
    Inject->>JS: Resolve Promise
    JS-->>App: "clipboard text"
```

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| -32700 | ParseError | Invalid JSON received |
| -32600 | InvalidRequest | Request object is invalid |
| -32601 | MethodNotFound | Method does not exist |
| -32602 | InvalidParams | Invalid method parameters |
| -32603 | InternalError | Internal bridge error |
| -32000 | PlatformError | Platform-specific error |
| -32001 | PermissionDenied | Operation not permitted |
| -32002 | NotSupported | Feature not supported on platform |

## Handler Registration

```mermaid
graph TB
    subgraph "Bridge Core"
        ROUTER[Message Router]
        HANDLERS[Handler Map]
    end

    subgraph "Registered Handlers"
        H1[clipboard.*]
        H2[dialog.*]
        H3[window.*]
        H4[tray.*]
        H5[system.*]
        H6[fs.*]
        H7[notification.*]
    end

    ROUTER --> HANDLERS
    HANDLERS --> H1
    HANDLERS --> H2
    HANDLERS --> H3
    HANDLERS --> H4
    HANDLERS --> H5
    HANDLERS --> H6
    HANDLERS --> H7
```

## Platform-Specific Implementation

### macOS

```mermaid
graph LR
    JS[JavaScript] --> WK[WKScriptMessageHandler]
    WK --> ZIG[Zig Handler]
    ZIG --> WK2[WKWebView.evaluateJavaScript]
    WK2 --> JS
```

### Linux

```mermaid
graph LR
    JS[JavaScript] --> WK[webkit_web_view_run_javascript]
    WK --> ZIG[Zig Handler via GTK signal]
    ZIG --> WK2[webkit_web_view_run_javascript]
    WK2 --> JS
```

### Windows

```mermaid
graph LR
    JS[JavaScript] --> WV2[WebView2 WebMessageReceived]
    WV2 --> ZIG[Zig Handler]
    ZIG --> WV2B[ICoreWebView2.ExecuteScript]
    WV2B --> JS
```

## Injected JavaScript API

The bridge injects a `window.craft` object into every WebView:

```javascript
window.craft = {
    // Core
    invoke: (method, params) => Promise,
    getPlatform: () => string,
    getVersion: () => string,

    // Namespaced APIs
    clipboard: {
        getText: () => Promise<string>,
        setText: (text) => Promise<void>,
        getImage: () => Promise<Blob>,
        setImage: (blob) => Promise<void>
    },

    dialog: {
        open: (options) => Promise<string[]>,
        save: (options) => Promise<string>,
        message: (options) => Promise<string>
    },

    window: {
        setTitle: (title) => Promise<void>,
        setSize: (width, height) => Promise<void>,
        setPosition: (x, y) => Promise<void>,
        minimize: () => Promise<void>,
        maximize: () => Promise<void>,
        close: () => Promise<void>
    },

    notification: {
        show: (options) => Promise<string>,
        requestPermission: () => Promise<string>
    },

    tray: {
        create: (options) => Promise<string>,
        setIcon: (id, icon) => Promise<void>,
        setMenu: (id, menu) => Promise<void>,
        destroy: (id) => Promise<void>
    },

    // Events
    on: (event, callback) => void,
    off: (event, callback) => void,
    once: (event, callback) => void
};
```

## Event System

```mermaid
graph TB
    subgraph "Native Events"
        NE1[Window Resize]
        NE2[Tray Click]
        NE3[Menu Selection]
        NE4[Notification Action]
    end

    subgraph "Bridge"
        EB[Event Bridge]
        EQ[Event Queue]
    end

    subgraph "JavaScript"
        EL[Event Listeners]
        CB[Callbacks]
    end

    NE1 --> EB
    NE2 --> EB
    NE3 --> EB
    NE4 --> EB

    EB --> EQ
    EQ --> EL
    EL --> CB
```

### Event Message Format

```json
{
    "type": "event",
    "event": "tray:click",
    "data": {
        "id": "tray-1",
        "button": "left",
        "x": 100,
        "y": 200
    }
}
```

## Security Considerations

```mermaid
graph TB
    subgraph "Security Layers"
        SL1[Input Validation]
        SL2[Permission Checks]
        SL3[Sandbox Boundaries]
        SL4[Resource Limits]
    end

    subgraph "Threat Mitigation"
        TM1[JSON Injection Prevention]
        TM2[Path Traversal Prevention]
        TM3[Memory Safety via Zig]
        TM4[Privilege Escalation Prevention]
    end

    SL1 --> TM1
    SL2 --> TM4
    SL3 --> TM2
    SL4 --> TM3
```

## Performance Optimization

### Message Batching

```mermaid
sequenceDiagram
    participant App
    participant Bridge
    participant Native

    Note over App,Native: Without batching
    App->>Bridge: Request 1
    Bridge->>Native: Call 1
    Native-->>Bridge: Response 1
    Bridge-->>App: Result 1
    App->>Bridge: Request 2
    Bridge->>Native: Call 2
    Native-->>Bridge: Response 2
    Bridge-->>App: Result 2

    Note over App,Native: With batching
    App->>Bridge: [Request 1, Request 2]
    Bridge->>Native: Batch call
    Native-->>Bridge: [Response 1, Response 2]
    Bridge-->>App: [Result 1, Result 2]
```

### Caching

- Method resolution is cached after first lookup
- Frequently used handlers maintain pre-allocated response buffers
- Platform-specific optimizations for string conversion

## Testing the Bridge

```zig
test "bridge handles clipboard getText" {
    const allocator = std.testing.allocator;

    const request = try Bridge.parseRequest(
        \\{"id":"1","method":"clipboard.getText","params":{}}
    );
    defer request.deinit();

    const response = try Bridge.handleRequest(allocator, request);
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "\"success\":true") != null);
}
```

## Further Reading

- [BRIDGE_API.md](../BRIDGE_API.md) - Full API reference
- [QUICK_REFERENCE.md](../QUICK_REFERENCE.md) - Quick reference guide
- [js_bridge.zig](../../packages/zig/src/js_bridge.zig) - Implementation
