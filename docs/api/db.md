# Database API

The Database API provides SQLite database operations with a simple, Promise-based interface.

## Import

```typescript
import { db } from 'ts-craft'
```

## Methods

### db.open(path)

Open or create a SQLite database.

```typescript
const database = await db.open('/path/to/database.db')
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| path | `string` | Path to the database file |

**Returns:** `Promise<Database>`

---

### database.execute(sql, params?)

Execute a SQL statement (INSERT, UPDATE, DELETE, CREATE, etc.).

```typescript
await database.execute(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE
  )
`)

await database.execute(
  'INSERT INTO users (name, email) VALUES (?, ?)',
  ['John Doe', 'john@example.com']
)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| sql | `string` | SQL statement to execute |
| params | `any[]` | Bind parameters |

**Returns:** `Promise<ExecuteResult>`

```typescript
interface ExecuteResult {
  lastInsertId: number
  rowsAffected: number
}
```

---

### database.query(sql, params?)

Query the database and return rows.

```typescript
const users = await database.query<User>('SELECT * FROM users')

const user = await database.query<User>(
  'SELECT * FROM users WHERE id = ?',
  [1]
)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| sql | `string` | SQL query |
| params | `any[]` | Bind parameters |

**Returns:** `Promise<T[]>`

---

### database.queryOne(sql, params?)

Query for a single row.

```typescript
const user = await database.queryOne<User>(
  'SELECT * FROM users WHERE id = ?',
  [1]
)

if (user) {
  console.log(user.name)
}
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| sql | `string` | SQL query |
| params | `any[]` | Bind parameters |

**Returns:** `Promise<T | null>`

---

### database.transaction(callback)

Execute multiple operations in a transaction.

```typescript
await database.transaction(async (tx) => {
  await tx.execute(
    'INSERT INTO users (name, email) VALUES (?, ?)',
    ['Alice', 'alice@example.com']
  )

  await tx.execute(
    'INSERT INTO profiles (user_id, bio) VALUES (?, ?)',
    [1, 'Hello, world!']
  )
})
// Transaction is automatically committed on success
// or rolled back on error
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| callback | `(tx: Transaction) => Promise<void>` | Transaction operations |

**Returns:** `Promise<void>`

---

### database.close()

Close the database connection.

```typescript
await database.close()
```

**Returns:** `Promise<void>`

## Example Usage

```typescript
import { db } from 'ts-craft'

interface Todo {
  id: number
  title: string
  completed: boolean
  createdAt: string
}

// Initialize database
const database = await db.open('app.db')

// Create table
await database.execute(`
  CREATE TABLE IF NOT EXISTS todos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    completed INTEGER DEFAULT 0,
    createdAt TEXT DEFAULT CURRENT_TIMESTAMP
  )
`)

// Add a todo
const result = await database.execute(
  'INSERT INTO todos (title) VALUES (?)',
  ['Learn Craft']
)
console.log('Created todo with ID:', result.lastInsertId)

// Get all todos
const todos = await database.query<Todo>('SELECT * FROM todos ORDER BY createdAt DESC')

// Get incomplete todos
const incomplete = await database.query<Todo>(
  'SELECT * FROM todos WHERE completed = ?',
  [0]
)

// Mark todo as complete
await database.execute(
  'UPDATE todos SET completed = 1 WHERE id = ?',
  [1]
)

// Delete todo
await database.execute('DELETE FROM todos WHERE id = ?', [1])

// Batch operations in transaction
await database.transaction(async (tx) => {
  await tx.execute('INSERT INTO todos (title) VALUES (?)', ['Task 1'])
  await tx.execute('INSERT INTO todos (title) VALUES (?)', ['Task 2'])
  await tx.execute('INSERT INTO todos (title) VALUES (?)', ['Task 3'])
})

// Close when done
await database.close()
```

## Types

```typescript
interface Database {
  execute(sql: string, params?: any[]): Promise<ExecuteResult>
  query<T>(sql: string, params?: any[]): Promise<T[]>
  queryOne<T>(sql: string, params?: any[]): Promise<T | null>
  transaction(callback: (tx: Transaction) => Promise<void>): Promise<void>
  close(): Promise<void>
}

interface Transaction {
  execute(sql: string, params?: any[]): Promise<ExecuteResult>
  query<T>(sql: string, params?: any[]): Promise<T[]>
}

interface ExecuteResult {
  lastInsertId: number
  rowsAffected: number
}
```
