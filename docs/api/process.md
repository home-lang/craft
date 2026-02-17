# Process API

The Process API provides methods for spawning processes, executing commands, and accessing environment information.

## Import

```typescript
import { process } from '@stacksjs/ts-craft'
```

## Methods

### process.spawn(command, args?, options?)

Spawn a new process with streaming output.

```typescript
const child = await process.spawn('node', ['script.js'])

child.stdout.on('data', (data) => {
  console.log('Output:', data)
})

child.stderr.on('data', (data) => {
  console.error('Error:', data)
})

child.on('exit', (code) => {
  console.log('Exited with code:', code)
})
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| command | `string` | Command to execute |
| args | `string[]` | Command arguments |
| options.cwd | `string` | Working directory |
| options.env | `Record<string, string>` | Environment variables |
| options.stdin | `'pipe' \| 'inherit' \| 'ignore'` | stdin handling |
| options.stdout | `'pipe' \| 'inherit' \| 'ignore'` | stdout handling |
| options.stderr | `'pipe' \| 'inherit' \| 'ignore'` | stderr handling |

**Returns:** `Promise<ChildProcess>`

---

### process.exec(command, options?)

Execute a command and return the output.

```typescript
const result = await process.exec('ls -la')
console.log(result.stdout)
console.log(result.stderr)
console.log(result.exitCode)

// With options
const result = await process.exec('npm install', {
  cwd: '/path/to/project',
  timeout: 60000
})
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| command | `string` | Command to execute (shell command) |
| options.cwd | `string` | Working directory |
| options.env | `Record<string, string>` | Environment variables |
| options.timeout | `number` | Timeout in milliseconds |

**Returns:** `Promise<ExecResult>`

---

### process.env

Access environment variables.

```typescript
const home = process.env.HOME
const path = process.env.PATH
const customVar = process.env.MY_APP_CONFIG

// All environment variables
console.log(process.env)
```

**Returns:** `Record<string, string | undefined>`

---

### process.cwd()

Get the current working directory.

```typescript
const currentDir = process.cwd()
// Returns: "/Users/username/project"
```

**Returns:** `string`

---

### process.exit(code?)

Exit the application with an optional exit code.

```typescript
process.exit(0)  // Success
process.exit(1)  // Error
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| code | `number` | Exit code (default: 0) |

**Returns:** `never`

---

### process.platform

Get the current platform.

```typescript
const platform = process.platform
// Returns: 'darwin' | 'win32' | 'linux' | 'ios' | 'android'
```

**Returns:** `string`

---

### process.arch

Get the CPU architecture.

```typescript
const arch = process.arch
// Returns: 'x64' | 'arm64' | 'arm'
```

**Returns:** `string`

---

### child.kill(signal?)

Kill a spawned process.

```typescript
const child = await process.spawn('long-running-task')

// Kill after 10 seconds
setTimeout(() => {
  child.kill('SIGTERM')
}, 10000)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| signal | `string` | Signal to send (default: 'SIGTERM') |

**Returns:** `void`

---

### child.write(data)

Write to a process's stdin.

```typescript
const child = await process.spawn('cat', [], {
  stdin: 'pipe'
})

child.write('Hello, World!\n')
child.stdin.end()
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| data | `string \| Uint8Array` | Data to write |

**Returns:** `void`

## Example Usage

```typescript
import { process } from '@stacksjs/ts-craft'

// Run a build script
async function runBuild() {
  const result = await process.exec('npm run build', {
    cwd: '/path/to/project'
  })

  if (result.exitCode !== 0) {
    console.error('Build failed:', result.stderr)
    throw new Error('Build failed')
  }

  console.log('Build output:', result.stdout)
}

// Long-running process with output streaming
async function runDevServer() {
  const server = await process.spawn('npm', ['run', 'dev'], {
    cwd: '/path/to/project',
    env: {
      ...process.env,
      NODE_ENV: 'development',
      PORT: '3000'
    }
  })

  server.stdout.on('data', (line) => {
    console.log('[Server]', line)
  })

  server.stderr.on('data', (line) => {
    console.error('[Server Error]', line)
  })

  server.on('exit', (code) => {
    console.log('Server exited with code:', code)
  })

  return server
}

// Interactive process
async function runInteractiveCommand() {
  const child = await process.spawn('python', ['-i'], {
    stdin: 'pipe',
    stdout: 'pipe',
    stderr: 'pipe'
  })

  child.write('print("Hello from Python")\n')
  child.write('exit()\n')

  return new Promise((resolve) => {
    child.on('exit', resolve)
  })
}

// Check if a command exists
async function commandExists(cmd: string): Promise<boolean> {
  try {
    const which = process.platform === 'win32' ? 'where' : 'which'
    const result = await process.exec(`${which} ${cmd}`)
    return result.exitCode === 0
  } catch {
    return false
  }
}

// Platform-specific behavior
function getShell(): string {
  switch (process.platform) {
    case 'win32':
      return 'cmd.exe'
    case 'darwin':
    case 'linux':
      return process.env.SHELL || '/bin/sh'
    default:
      return '/bin/sh'
  }
}
```

## Types

```typescript
interface SpawnOptions {
  cwd?: string
  env?: Record<string, string>
  stdin?: 'pipe' | 'inherit' | 'ignore'
  stdout?: 'pipe' | 'inherit' | 'ignore'
  stderr?: 'pipe' | 'inherit' | 'ignore'
}

interface ExecOptions {
  cwd?: string
  env?: Record<string, string>
  timeout?: number
}

interface ExecResult {
  stdout: string
  stderr: string
  exitCode: number
}

interface ChildProcess {
  pid: number
  stdin: WritableStream | null
  stdout: ReadableStream | null
  stderr: ReadableStream | null
  kill(signal?: string): void
  write(data: string | Uint8Array): void
  on(event: 'exit', callback: (code: number) => void): void
  on(event: 'error', callback: (error: Error) => void): void
}

interface ReadableStream {
  on(event: 'data', callback: (data: string) => void): void
  on(event: 'end', callback: () => void): void
}

interface WritableStream {
  write(data: string | Uint8Array): void
  end(): void
}
```
