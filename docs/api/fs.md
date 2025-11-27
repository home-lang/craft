# File System API

The File System API provides methods for reading, writing, and managing files and directories.

## Import

```typescript
import { fs } from 'ts-craft'
```

## Methods

### fs.readFile(path, options?)

Read the contents of a file.

```typescript
const content = await fs.readFile('/path/to/file.txt')
// Returns: string

const binary = await fs.readFile('/path/to/image.png', { encoding: 'binary' })
// Returns: Uint8Array
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| path | `string` | Absolute path to the file |
| options.encoding | `'utf8' \| 'binary'` | File encoding (default: 'utf8') |

**Returns:** `Promise<string | Uint8Array>`

---

### fs.writeFile(path, content, options?)

Write content to a file.

```typescript
await fs.writeFile('/path/to/file.txt', 'Hello, World!')

await fs.writeFile('/path/to/data.bin', new Uint8Array([1, 2, 3]), {
  encoding: 'binary'
})
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| path | `string` | Absolute path to the file |
| content | `string \| Uint8Array` | Content to write |
| options.encoding | `'utf8' \| 'binary'` | File encoding (default: 'utf8') |
| options.append | `boolean` | Append to file instead of overwrite |

**Returns:** `Promise<void>`

---

### fs.readDir(path, options?)

Read the contents of a directory.

```typescript
const entries = await fs.readDir('/path/to/dir')
// Returns: Array<{ name: string, isFile: boolean, isDirectory: boolean }>

const recursive = await fs.readDir('/path/to/dir', { recursive: true })
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| path | `string` | Absolute path to the directory |
| options.recursive | `boolean` | Include subdirectories (default: false) |

**Returns:** `Promise<DirEntry[]>`

---

### fs.mkdir(path, options?)

Create a directory.

```typescript
await fs.mkdir('/path/to/new-dir')

await fs.mkdir('/path/to/nested/dirs', { recursive: true })
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| path | `string` | Path to create |
| options.recursive | `boolean` | Create parent directories (default: false) |

**Returns:** `Promise<void>`

---

### fs.remove(path, options?)

Remove a file or directory.

```typescript
await fs.remove('/path/to/file.txt')

await fs.remove('/path/to/dir', { recursive: true })
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| path | `string` | Path to remove |
| options.recursive | `boolean` | Remove directories recursively (default: false) |

**Returns:** `Promise<void>`

---

### fs.exists(path)

Check if a file or directory exists.

```typescript
const exists = await fs.exists('/path/to/file.txt')
// Returns: boolean
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| path | `string` | Path to check |

**Returns:** `Promise<boolean>`

---

### fs.stat(path)

Get file or directory information.

```typescript
const info = await fs.stat('/path/to/file.txt')
// Returns: { size: number, isFile: boolean, isDirectory: boolean,
//            created: Date, modified: Date, accessed: Date }
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| path | `string` | Path to stat |

**Returns:** `Promise<FileStat>`

---

### fs.copy(src, dest, options?)

Copy a file or directory.

```typescript
await fs.copy('/path/to/source.txt', '/path/to/dest.txt')

await fs.copy('/path/to/dir', '/path/to/dest-dir', { recursive: true })
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| src | `string` | Source path |
| dest | `string` | Destination path |
| options.recursive | `boolean` | Copy directories recursively |
| options.overwrite | `boolean` | Overwrite existing files |

**Returns:** `Promise<void>`

---

### fs.move(src, dest)

Move or rename a file or directory.

```typescript
await fs.move('/path/to/old.txt', '/path/to/new.txt')
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| src | `string` | Source path |
| dest | `string` | Destination path |

**Returns:** `Promise<void>`

---

### fs.watch(path, callback)

Watch a file or directory for changes.

```typescript
const unwatch = fs.watch('/path/to/file.txt', (event) => {
  console.log(event.type) // 'create' | 'modify' | 'delete' | 'rename'
  console.log(event.path)
})

// Stop watching
unwatch()
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| path | `string` | Path to watch |
| callback | `(event: WatchEvent) => void` | Callback for changes |

**Returns:** `() => void` - Unwatch function

## Types

```typescript
interface DirEntry {
  name: string
  isFile: boolean
  isDirectory: boolean
}

interface FileStat {
  size: number
  isFile: boolean
  isDirectory: boolean
  created: Date
  modified: Date
  accessed: Date
}

interface WatchEvent {
  type: 'create' | 'modify' | 'delete' | 'rename'
  path: string
}

interface ReadOptions {
  encoding?: 'utf8' | 'binary'
}

interface WriteOptions {
  encoding?: 'utf8' | 'binary'
  append?: boolean
}

interface DirOptions {
  recursive?: boolean
}
```
