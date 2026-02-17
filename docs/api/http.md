# HTTP API

The HTTP API provides methods for making network requests with progress tracking and download/upload support.

## Import

```typescript
import { http } from '@stacksjs/ts-craft'
```

## Methods

### http.fetch(url, options?)

Make an HTTP request. Similar to the web Fetch API.

```typescript
// GET request
const response = await http.fetch('https://api.example.com/data')
const data = await response.json()

// POST request with JSON
const response = await http.fetch('https://api.example.com/users', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ name: 'John' })
})
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| url | `string` | Request URL |
| options.method | `string` | HTTP method (default: 'GET') |
| options.headers | `Record<string, string>` | Request headers |
| options.body | `string \| Uint8Array` | Request body |
| options.timeout | `number` | Timeout in milliseconds |

**Returns:** `Promise<Response>`

---

### http.get(url, options?)

Shorthand for GET requests.

```typescript
const response = await http.get('https://api.example.com/users')
const users = await response.json()
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| url | `string` | Request URL |
| options.headers | `Record<string, string>` | Request headers |
| options.timeout | `number` | Timeout in milliseconds |

**Returns:** `Promise<Response>`

---

### http.post(url, body, options?)

Shorthand for POST requests.

```typescript
const response = await http.post(
  'https://api.example.com/users',
  { name: 'John', email: 'john@example.com' }
)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| url | `string` | Request URL |
| body | `any` | Request body (auto-serialized to JSON) |
| options.headers | `Record<string, string>` | Request headers |
| options.timeout | `number` | Timeout in milliseconds |

**Returns:** `Promise<Response>`

---

### http.download(url, path, options?)

Download a file with progress tracking.

```typescript
await http.download(
  'https://example.com/file.zip',
  '/path/to/save/file.zip',
  {
    onProgress: (progress) => {
      console.log(`Downloaded: ${progress.percent}%`)
      console.log(`${progress.loaded} / ${progress.total} bytes`)
    }
  }
)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| url | `string` | URL to download |
| path | `string` | Local path to save file |
| options.onProgress | `(progress: Progress) => void` | Progress callback |
| options.headers | `Record<string, string>` | Request headers |

**Returns:** `Promise<void>`

---

### http.upload(url, file, options?)

Upload a file with progress tracking.

```typescript
await http.upload(
  'https://api.example.com/upload',
  '/path/to/file.pdf',
  {
    fieldName: 'document',
    onProgress: (progress) => {
      console.log(`Uploaded: ${progress.percent}%`)
    }
  }
)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| url | `string` | Upload URL |
| file | `string` | Local file path |
| options.fieldName | `string` | Form field name (default: 'file') |
| options.onProgress | `(progress: Progress) => void` | Progress callback |
| options.headers | `Record<string, string>` | Request headers |
| options.additionalFields | `Record<string, string>` | Additional form fields |

**Returns:** `Promise<Response>`

## Example Usage

```typescript
import { http } from '@stacksjs/ts-craft'

// REST API example
async function fetchUsers() {
  const response = await http.get('https://api.example.com/users')

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`)
  }

  return response.json()
}

// POST with error handling
async function createUser(user: { name: string; email: string }) {
  try {
    const response = await http.post('https://api.example.com/users', user)

    if (response.status === 201) {
      return response.json()
    } else if (response.status === 409) {
      throw new Error('User already exists')
    } else {
      throw new Error('Failed to create user')
    }
  } catch (error) {
    console.error('Network error:', error)
    throw error
  }
}

// Download with progress
async function downloadUpdate(url: string) {
  const downloadPath = '/tmp/update.zip'

  await http.download(url, downloadPath, {
    onProgress: ({ percent, loaded, total }) => {
      updateProgressBar(percent)
      updateStatus(`${formatBytes(loaded)} / ${formatBytes(total)}`)
    }
  })

  return downloadPath
}

// Upload with additional fields
async function uploadAvatar(imagePath: string, userId: string) {
  const response = await http.upload(
    'https://api.example.com/avatar',
    imagePath,
    {
      fieldName: 'avatar',
      additionalFields: {
        userId,
        resize: 'true'
      },
      onProgress: ({ percent }) => {
        console.log(`Uploading: ${percent}%`)
      }
    }
  )

  return response.json()
}

// Custom headers and timeout
async function fetchWithAuth(url: string, token: string) {
  const response = await http.fetch(url, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/json'
    },
    timeout: 30000 // 30 seconds
  })

  return response.json()
}
```

## Types

```typescript
interface FetchOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE' | 'HEAD' | 'OPTIONS'
  headers?: Record<string, string>
  body?: string | Uint8Array
  timeout?: number
}

interface Response {
  ok: boolean
  status: number
  statusText: string
  headers: Record<string, string>
  json<T>(): Promise<T>
  text(): Promise<string>
  arrayBuffer(): Promise<ArrayBuffer>
}

interface Progress {
  loaded: number
  total: number
  percent: number
}

interface DownloadOptions {
  onProgress?: (progress: Progress) => void
  headers?: Record<string, string>
}

interface UploadOptions {
  fieldName?: string
  onProgress?: (progress: Progress) => void
  headers?: Record<string, string>
  additionalFields?: Record<string, string>
}
```
