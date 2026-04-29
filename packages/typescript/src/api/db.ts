/**
 * @fileoverview Craft Database API
 * @description Provides SQLite database access through the Craft bridge.
 * Includes transaction support, table management, and a key-value store abstraction.
 * @module @craft-native/api/db
 *
 * @example
 * ```typescript
 * import { openDatabase, KeyValueStore } from '@craft-native/api/db'
 *
 * // Open a database
 * const myDb = await openDatabase('myapp.db')
 *
 * // Create a table
 * await myDb.createTable('users', [
 *   { name: 'id', type: 'INTEGER', primaryKey: true, autoIncrement: true },
 *   { name: 'name', type: 'TEXT', notNull: true },
 *   { name: 'email', type: 'TEXT', unique: true }
 * ])
 *
 * // Insert data
 * await myDb.execute('INSERT INTO users (name, email) VALUES (?, ?)', ['John', 'john@example.com'])
 *
 * // Query data
 * const users = await myDb.query('SELECT * FROM users')
 * ```
 */

import { EventEmitter } from 'events'
import { getBridge } from '../bridge/core'
import type { CraftDatabaseAPI } from '../types'

/**
 * Send a request through the unified `NativeBridge`. Replaces the legacy
 * `window.craft.bridge.call(...)` hook; everything routes through one
 * transport with consistent timeout/retry/error semantics.
 */
async function callBridge<T = unknown>(method: string, params?: unknown): Promise<T> {
  return getBridge().request<unknown, T>(method, params)
}

/**
 * Statements that mutate state. Read-only databases reject anything matching
 * this pattern at the start of a statement (after stripping leading
 * whitespace and `--` comments).
 */
const WRITE_STATEMENT_RE = /^\s*(?:--[^\n]*\n\s*)*(INSERT|UPDATE|DELETE|REPLACE|DROP|CREATE|ALTER|TRUNCATE|ATTACH|DETACH|VACUUM|REINDEX|PRAGMA)\b/i

/**
 * Global emitter for `db:execute` audit events. Subscribe to log every SQL
 * statement that goes through the SDK. The event payload is `{ name, sql,
 * paramsCount, readOnly }` — params themselves are not included by default
 * to avoid leaking secrets to logs.
 *
 * `setMaxListeners(0)` lifts the default 10-listener cap: analytics, the
 * dev overlay, and tests routinely subscribe in parallel and the cap
 * triggered spurious "MaxListenersExceeded" warnings without indicating
 * an actual leak.
 */
export const dbAudit: EventEmitter = new EventEmitter().setMaxListeners(0)

/**
 * Maximum length for SQL identifiers (table/column names). SQLite has no
 * built-in cap but extremely long identifiers cause pathological query plans
 * and bloat sqlite_master rows; 64 is the limit used by MySQL and is plenty
 * for any sensible schema.
 */
const MAX_IDENTIFIER_LEN = 64

/**
 * Validate a SQL identifier (table or column name) to prevent SQL injection
 * and runaway identifiers. Only allows alphanumeric characters and
 * underscores, with a length cap.
 *
 * @param name  The identifier to validate.
 * @param kind  Human-readable label for error messages (`'table'` /
 *              `'column'` / `'index'` …). Defaults to `'identifier'`.
 */
export function validateIdentifier(name: string, kind: string = 'identifier'): void {
  if (typeof name !== 'string' || name.length === 0) {
    throw new Error(`Invalid ${kind} name: must be a non-empty string`)
  }
  if (name.length > MAX_IDENTIFIER_LEN) {
    throw new Error(`Invalid ${kind} name: "${name.slice(0, 16)}…" exceeds ${MAX_IDENTIFIER_LEN} characters`)
  }
  if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(name)) {
    throw new Error(`Invalid ${kind} name: "${name}". ${kind} names must contain only letters, numbers, and underscores.`)
  }
}

/**
 * Back-compat alias for {@link validateIdentifier} when validating a table
 * name. Existing call sites that say `validateTableName(...)` keep working.
 */
export function validateTableName(name: string): void {
  validateIdentifier(name, 'table')
}

/**
 * Encode a SQL literal for safe inclusion in a `DEFAULT` clause. Strings
 * have their single quotes doubled per the SQL standard. Numbers are
 * emitted verbatim (after `Number.isFinite` check). `null`/`undefined`
 * become `NULL`. Booleans become `0`/`1`. Anything else throws — DEFAULT
 * with a JSON object/array would silently misencode.
 */
export function encodeDefaultLiteral(value: unknown): string {
  if (value === null || value === undefined) return 'NULL'
  if (typeof value === 'boolean') return value ? '1' : '0'
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      throw new Error(`Invalid DEFAULT: ${value} is not a finite number`)
    }
    return String(value)
  }
  if (typeof value === 'string') {
    return `'${value.replace(/'/g, '\'\'')}'`
  }
  throw new Error(`Invalid DEFAULT: ${typeof value} cannot be encoded as a SQL literal`)
}

/**
 * Low-level database API implementation.
 * Uses native SQLite through the Craft bridge.
 * For most use cases, prefer the {@link Database} class or {@link KeyValueStore}.
 *
 * @example
 * ```typescript
 * import { db } from '@craft-native/api/db'
 *
 * // Execute a statement
 * await db.execute('CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)')
 *
 * // Query data
 * const results = await db.query('SELECT * FROM settings WHERE key = ?', ['theme'])
 * ```
 */
export const db: CraftDatabaseAPI = {
  /**
   * Execute a SQL statement that doesn't return data.
   * Use for INSERT, UPDATE, DELETE, CREATE TABLE, etc.
   *
   * @param sql - SQL statement to execute
   * @param params - Optional parameters for prepared statement
   * @returns Promise that resolves when execution is complete
   * @throws {Error} If not running in Craft environment or SQL error occurs
   *
   * @example
   * ```typescript
   * // Create table
   * await db.execute('CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)')
   *
   * // Insert with parameters (prevents SQL injection)
   * await db.execute('INSERT INTO users (name) VALUES (?)', ['John Doe'])
   *
   * // Update
   * await db.execute('UPDATE users SET name = ? WHERE id = ?', ['Jane', 1])
   * ```
   */
  async execute(sql: string, params?: unknown[]): Promise<void> {
    if (typeof window !== 'undefined' && window.craft?.db) {
      return window.craft.db.execute(sql, params)
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  },

  /**
   * Execute a SQL query that returns data.
   * Use for SELECT statements.
   *
   * @param sql - SQL SELECT statement
   * @param params - Optional parameters for prepared statement
   * @returns Promise resolving to array of result rows
   * @throws {Error} If not running in Craft environment or SQL error occurs
   *
   * @example
   * ```typescript
   * // Simple query
   * const allUsers = await db.query('SELECT * FROM users')
   *
   * // Query with parameters
   * const user = await db.query('SELECT * FROM users WHERE id = ?', [1])
   *
   * // Query with multiple conditions
   * const results = await db.query(
   *   'SELECT * FROM products WHERE price > ? AND category = ?',
   *   [10.00, 'electronics']
   * )
   * ```
   */
  async query(sql: string, params?: unknown[]): Promise<unknown[]> {
    if (typeof window !== 'undefined' && window.craft?.db) {
      return window.craft.db.query(sql, params)
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  },

  /**
   * Begin a database transaction.
   * All subsequent operations until commit() or rollback() are part of the transaction.
   *
   * @returns Promise that resolves when transaction begins
   * @throws {Error} If not running in Craft environment
   *
   * @example
   * ```typescript
   * await db.beginTransaction()
   * try {
   *   await db.execute('INSERT INTO orders (user_id, total) VALUES (?, ?)', [1, 99.99])
   *   await db.execute('UPDATE inventory SET quantity = quantity - 1 WHERE product_id = ?', [42])
   *   await db.commit()
   * }
catch (error) {
   *   await db.rollback()
   *   throw error
   * }
   * ```
   */
  async beginTransaction(): Promise<void> {
    if (typeof window !== 'undefined' && window.craft?.db) {
      return window.craft.db.beginTransaction()
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  },

  /**
   * Commit the current transaction.
   * Makes all changes since beginTransaction() permanent.
   *
   * @returns Promise that resolves when transaction is committed
   * @throws {Error} If not running in Craft environment
   */
  async commit(): Promise<void> {
    if (typeof window !== 'undefined' && window.craft?.db) {
      return window.craft.db.commit()
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  },

  /**
   * Rollback the current transaction.
   * Discards all changes since beginTransaction().
   *
   * @returns Promise that resolves when transaction is rolled back
   * @throws {Error} If not running in Craft environment
   */
  async rollback(): Promise<void> {
    if (typeof window !== 'undefined' && window.craft?.db) {
      return window.craft.db.rollback()
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  }
}

/**
 * Create or open a SQLite database.
 *
 * @param name - Database name (will be stored as `{name}.sqlite` in app data directory)
 * @returns Promise resolving to Database instance
 *
 * @example
 * ```typescript
 * const myDb = await openDatabase('myapp')
 *
 * // Database will be created at app data directory as 'myapp.sqlite'
 * await myDb.createTable('notes', [
 *   { name: 'id', type: 'INTEGER', primaryKey: true, autoIncrement: true },
 *   { name: 'title', type: 'TEXT', notNull: true },
 *   { name: 'content', type: 'TEXT' },
 *   { name: 'created_at', type: 'INTEGER', default: Date.now() }
 * ])
 * ```
 */
export async function openDatabase(name: string): Promise<Database> {
  // Block directory traversal in database names
  const normalized = name.replace(/\\/g, '/')
  if (normalized.includes('/../') || normalized.startsWith('../') || normalized.endsWith('/..') || normalized === '..' || name.includes('\0')) {
    throw new Error(`Invalid database name: "${name}" contains path traversal or invalid characters`)
  }
  return new Database(name)
}

/**
 * Open a database in read-only mode. `execute()` on the returned instance
 * rejects DDL/DML statements (`INSERT`, `UPDATE`, `DELETE`, `DROP`, etc.).
 * Use this for analytics / reporting code paths where there is no reason
 * for a SQL bug to be able to mutate state.
 */
export async function openDatabaseReadOnly(name: string): Promise<Database> {
  const normalized = name.replace(/\\/g, '/')
  if (normalized.includes('/../') || normalized.startsWith('../') || normalized.endsWith('/..') || normalized === '..' || name.includes('\0')) {
    throw new Error(`Invalid database name: "${name}" contains path traversal or invalid characters`)
  }
  return new Database(name, { readOnly: true })
}

/**
 * SQLite database wrapper with extended functionality.
 * Provides table management, transactions, and query helpers.
 *
 * @example
 * ```typescript
 * const db = new Database('myapp')
 * await db.open()
 *
 * // Create table with schema
 * await db.createTable('tasks', [
 *   { name: 'id', type: 'INTEGER', primaryKey: true, autoIncrement: true },
 *   { name: 'title', type: 'TEXT', notNull: true },
 *   { name: 'completed', type: 'INTEGER', default: 0 }
 * ])
 *
 * // Insert and get ID
 * const result = await db.execute('INSERT INTO tasks (title) VALUES (?)', ['Buy groceries'])
 * console.log('Created task with ID:', result.lastInsertId)
 *
 * // Query with type safety
 * interface Task { id: number; title: string; completed: number }
 * const tasks = await db.query<Task>('SELECT * FROM tasks')
 *
 * // Get single row
 * const task = await db.get<Task>('SELECT * FROM tasks WHERE id = ?', [1])
 *
 * // Transaction helper
 * await db.transaction(async () => {
 *   await db.execute('UPDATE tasks SET completed = 1 WHERE id = ?', [1])
 *   await db.execute('INSERT INTO activity_log (action) VALUES (?)', ['completed_task'])
 * })
 *
 * await db.close()
 * ```
 */
export class Database {
  private name: string
  private isOpen: boolean = false
  private readOnly: boolean
  /** True while a `db.transaction(...)` callback is on the stack. Set
   * before `BEGIN TRANSACTION` and cleared in the finally arm. Used to
   * make the inevitable mistake of calling `beginTransaction()` inside
   * `transaction()` (or vice versa) fail fast with a clear error. */
  private _inTransactionHelper: boolean = false

  /**
   * Create a new Database instance.
   *
   * @param name - Database name
   * @param options.readOnly - When true, `execute()` rejects DDL/DML
   *   statements (anything that would mutate the schema or data).
   *   `query()` is unaffected. Defaults to false.
   */
  constructor(name: string, options?: { readOnly?: boolean }) {
    this.name = name
    this.readOnly = options?.readOnly === true
  }

  /** Whether this Database refuses mutating statements. */
  isReadOnly(): boolean {
    return this.readOnly
  }

  /**
   * Open the database connection.
   * Called automatically on first query if not explicitly opened.
   *
   * @returns Promise that resolves when connection is established
   * @throws {Error} If not running in Craft environment
   */
  async open(): Promise<void> {
    if (typeof window !== 'undefined' && window.craft) {
      await callBridge('db.open', { name: this.name })
      this.isOpen = true
      return
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  }

  /**
   * Close the database connection.
   * Should be called when done with the database to free resources.
   *
   * @returns Promise that resolves when connection is closed
   */
  async close(): Promise<void> {
    if (typeof window !== 'undefined' && window.craft) {
      await callBridge('db.close', { name: this.name })
      this.isOpen = false
      return
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  }

  /**
   * Execute a SQL statement and get result metadata.
   *
   * @param sql - SQL statement to execute
   * @param params - Optional parameters for prepared statement
   * @returns Promise resolving to ExecuteResult with rowsAffected and lastInsertId
   *
   * @example
   * ```typescript
   * const result = await db.execute(
   *   'INSERT INTO users (name, email) VALUES (?, ?)',
   *   ['John', 'john@example.com']
   * )
   * console.log(`Inserted user with ID: ${result.lastInsertId}`)
   * console.log(`Rows affected: ${result.rowsAffected}`)
   * ```
   */
  async execute(sql: string, params?: unknown[]): Promise<ExecuteResult> {
    if (!this.isOpen) {
      await this.open()
    }
    // Emit audit event before any check so subscribers see attempts even
    // when read-only mode rejects the statement. paramsCount is included
    // instead of params themselves to avoid logging secrets by default.
    dbAudit.emit('db:execute', {
      name: this.name,
      sql,
      paramsCount: params?.length ?? 0,
      readOnly: this.readOnly,
    })
    if (this.readOnly && WRITE_STATEMENT_RE.test(sql)) {
      throw new Error(
        `Database "${this.name}" is read-only; rejected mutating statement: ${sql.slice(0, 64)}`,
      )
    }
    if (typeof window !== 'undefined' && window.craft) {
      const result = await callBridge<{ rowsAffected: number; lastInsertId: number }>(
        'db.execute',
        { name: this.name, sql, params: params || [] },
      )
      return {
        rowsAffected: result.rowsAffected,
        lastInsertId: result.lastInsertId,
      }
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  }

  /**
   * Execute a query and return all matching rows.
   *
   * @typeParam T - Type of result rows
   * @param sql - SQL SELECT statement
   * @param params - Optional parameters for prepared statement
   * @returns Promise resolving to array of typed results
   *
   * @example
   * ```typescript
   * interface User {
   *   id: number
   *   name: string
   *   email: string
   * }
   *
   * const users = await db.query<User>('SELECT * FROM users WHERE active = ?', [1])
   * users.forEach(user => console.log(user.name))
   * ```
   */
  async query<T = unknown>(sql: string, params?: unknown[]): Promise<T[]> {
    if (!this.isOpen) {
      await this.open()
    }
    if (typeof window !== 'undefined' && window.craft) {
      return callBridge<T[]>('db.query', {
        name: this.name,
        sql,
        params: params || [],
      })
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  }

  /**
   * Execute a query and return the first matching row.
   *
   * @typeParam T - Type of result row
   * @param sql - SQL SELECT statement
   * @param params - Optional parameters for prepared statement
   * @returns Promise resolving to first row or null if no matches
   *
   * @example
   * ```typescript
   * const user = await db.get<User>('SELECT * FROM users WHERE id = ?', [1])
   * if (user) {
   *   console.log(`Found user: ${user.name}`)
   * }
else {
   *   console.log('User not found')
   * }
   * ```
   */
  async get<T = unknown>(sql: string, params?: unknown[]): Promise<T | null> {
    const rows = await this.query<T>(sql, params)
    return rows.length > 0 ? rows[0] : null
  }

  /**
   * Execute a function within a transaction.
   * Automatically commits on success, rolls back on error.
   *
   * NOTE: this method drives the transaction by emitting raw SQL
   * (`BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK`). The connection-level
   * helpers `db.beginTransaction()` / `db.commit()` / `db.rollback()` use
   * a separate native handler. Don't mix the two on the same connection —
   * pick one style per code path. See `docs/db-transactions.md`.
   *
   * @typeParam T - Return type of transaction function
   * @param fn - Async function containing database operations
   * @returns Promise resolving to function's return value
   * @throws Re-throws any error after rolling back
   *
   * @example
   * ```typescript
   * const orderId = await db.transaction(async () => {
   *   const orderResult = await db.execute(
   *     'INSERT INTO orders (user_id, total) VALUES (?, ?)',
   *     [userId, total]
   *   )
   *
   *   for (const item of items) {
   *     await db.execute(
   *       'INSERT INTO order_items (order_id, product_id, quantity) VALUES (?, ?, ?)',
   *       [orderResult.lastInsertId, item.productId, item.quantity]
   *     )
   *   }
   *
   *   return orderResult.lastInsertId
   * })
   * ```
   */
  async transaction<T>(fn: () => Promise<T>): Promise<T> {
    if (this._inTransactionHelper) {
      throw new Error(
        '[Craft DB] transaction() is already active on this connection. '
        + 'Nested transactions are not supported — refactor inner code to take '
        + 'an existing handle, or use SAVEPOINT directly.',
      )
    }
    this._inTransactionHelper = true
    try {
      await this.execute('BEGIN TRANSACTION')
      try {
        const result = await fn()
        await this.execute('COMMIT')
        return result
      }
      catch (error) {
        // Try to roll back. If ROLLBACK itself fails (locked DB, native side
        // dead, etc.) we can't surface BOTH errors as the thrown value, but
        // dropping the rollback failure used to mask the real situation: the
        // connection is left in a transactional state and the original error
        // gives no hint why. Attach the rollback error as `.cause` so debug
        // tooling sees both, log the secondary so it shows up in console
        // output even if the consumer doesn't inspect causes.
        try {
          await this.execute('ROLLBACK')
        }
        catch (rollbackError) {
          console.error('[Craft DB] ROLLBACK failed after transaction error:', rollbackError)
          if (error instanceof Error) {
            ;(error as { cause?: unknown }).cause = rollbackError
          }
        }
        throw error
      }
    }
    finally {
      this._inTransactionHelper = false
    }
  }

  /**
   * Create a table with the specified schema.
   * Uses CREATE TABLE IF NOT EXISTS, so safe to call multiple times.
   *
   * @param tableName - Name of the table to create
   * @param columns - Array of column definitions
   *
   * @example
   * ```typescript
   * await db.createTable('products', [
   *   { name: 'id', type: 'INTEGER', primaryKey: true, autoIncrement: true },
   *   { name: 'name', type: 'TEXT', notNull: true },
   *   { name: 'price', type: 'REAL', notNull: true },
   *   { name: 'category', type: 'TEXT' },
   *   { name: 'in_stock', type: 'INTEGER', default: 1 }
   * ])
   * ```
   */
  async createTable(tableName: string, columns: TableColumn[]): Promise<void> {
    validateIdentifier(tableName, 'table')
    const columnDefs = columns.map(col => {
      validateIdentifier(col.name, 'column')
      let def = `${col.name} ${col.type}`
      if (col.primaryKey) def += ' PRIMARY KEY'
      if (col.autoIncrement) def += ' AUTOINCREMENT'
      if (col.notNull) def += ' NOT NULL'
      if (col.unique) def += ' UNIQUE'
      if (col.default !== undefined) {
        // encodeDefaultLiteral doubles `'` for strings, ensures finite
        // numbers, encodes booleans/null safely. Without this a default
        // like `O'Brien` produced malformed and injection-prone SQL.
        def += ` DEFAULT ${encodeDefaultLiteral(col.default)}`
      }
      return def
    })

    const sql = `CREATE TABLE IF NOT EXISTS ${tableName} (${columnDefs.join(', ')})`
    await this.execute(sql)
  }

  /**
   * Drop a table if it exists.
   *
   * @param tableName - Name of the table to drop
   */
  async dropTable(tableName: string): Promise<void> {
    validateIdentifier(tableName, 'table')
    await this.execute(`DROP TABLE IF EXISTS ${tableName}`)
  }

  /**
   * Check if a table exists in the database.
   *
   * @param tableName - Name of the table to check
   * @returns Promise resolving to true if table exists
   */
  async tableExists(tableName: string): Promise<boolean> {
    validateIdentifier(tableName, 'table')
    const result = await this.query<{ name: string }>(
      `SELECT name FROM sqlite_master WHERE type='table' AND name=?`,
      [tableName]
    )
    return result.length > 0
  }
}

/**
 * Result of an execute operation.
 */
export interface ExecuteResult {
  /** Number of rows affected by the operation */
  rowsAffected: number
  /** ID of the last inserted row (for INSERT operations) */
  lastInsertId: number
}

/**
 * Column definition for createTable.
 */
export interface TableColumn {
  /** Column name */
  name: string
  /** SQLite data type */
  type: 'TEXT' | 'INTEGER' | 'REAL' | 'BLOB' | 'NULL'
  /** Mark as primary key */
  primaryKey?: boolean
  /** Enable auto-increment (INTEGER PRIMARY KEY only) */
  autoIncrement?: boolean
  /** Disallow NULL values */
  notNull?: boolean
  /** Require unique values */
  unique?: boolean
  /** Default value for column */
  default?: unknown
}

/**
 * Simple key-value store backed by SQLite.
 * Useful for settings, preferences, and cached data.
 *
 * @example
 * ```typescript
 * const db = await openDatabase('settings')
 * const store = new KeyValueStore(db)
 * await store.init()
 *
 * // Store values (automatically JSON serialized)
 * await store.set('theme', 'dark')
 * await store.set('user', { name: 'John', premium: true })
 * await store.set('recentFiles', ['/doc1.txt', '/doc2.txt'])
 *
 * // Retrieve values
 * const theme = await store.get<string>('theme') // 'dark'
 * const user = await store.get<{ name: string; premium: boolean }>('user')
 *
 * // Check existence
 * if (await store.has('lastSync')) {
 *   const lastSync = await store.get<number>('lastSync')
 * }
 *
 * // List all keys
 * const allKeys = await store.keys()
 *
 * // Delete and clear
 * await store.delete('tempData')
 * await store.clear() // Remove all entries
 * ```
 */
export class KeyValueStore {
  private db: Database
  private tableName: string

  /**
   * Create a new KeyValueStore.
   *
   * @param db - Database instance to use
   * @param tableName - Table name for storage (default: 'kv_store')
   */
  constructor(db: Database, tableName: string = 'kv_store') {
    this.db = db
    this.tableName = tableName
  }

  /**
   * Initialize the key-value store table.
   * Must be called before using other methods.
   */
  async init(): Promise<void> {
    await this.db.createTable(this.tableName, [
      { name: 'key', type: 'TEXT', primaryKey: true },
      { name: 'value', type: 'TEXT' },
      { name: 'updated_at', type: 'INTEGER' }
    ])
  }

  /**
   * Get a value by key.
   * Returns null if key doesn't exist.
   *
   * @typeParam T - Expected type of the value
   * @param key - Key to retrieve
   * @returns Promise resolving to value or null
   */
  async get<T = unknown>(key: string): Promise<T | null> {
    const row = await this.db.get<{ value: string }>(
      `SELECT value FROM ${this.tableName} WHERE key = ?`,
      [key]
    )
    if (row) {
      try {
        return JSON.parse(row.value) as T
      }
catch (err) {
        console.debug('[Craft DB] Failed to parse stored value for key, returning raw:', err)
        return row.value as unknown as T
      }
    }
    return null
  }

  /**
   * Set a value for a key.
   * Creates new entry or updates existing one.
   * Values are automatically JSON serialized.
   *
   * @param key - Key to set
   * @param value - Value to store (will be JSON serialized)
   */
  async set(key: string, value: unknown): Promise<void> {
    const serialized = JSON.stringify(value)
    await this.db.execute(
      `INSERT OR REPLACE INTO ${this.tableName} (key, value, updated_at) VALUES (?, ?, ?)`,
      [key, serialized, Date.now()]
    )
  }

  /**
   * Delete a key from the store.
   *
   * @param key - Key to delete
   */
  async delete(key: string): Promise<void> {
    await this.db.execute(`DELETE FROM ${this.tableName} WHERE key = ?`, [key])
  }

  /**
   * Check if a key exists.
   *
   * @param key - Key to check
   * @returns Promise resolving to true if key exists
   */
  async has(key: string): Promise<boolean> {
    const row = await this.db.get<{ key: string }>(
      `SELECT key FROM ${this.tableName} WHERE key = ?`,
      [key]
    )
    return row !== null
  }

  /**
   * Get all keys in the store.
   *
   * @returns Promise resolving to array of keys
   */
  async keys(): Promise<string[]> {
    const rows = await this.db.query<{ key: string }>(
      `SELECT key FROM ${this.tableName}`
    )
    return rows.map(r => r.key)
  }

  /**
   * Clear all entries from the store.
   */
  async clear(): Promise<void> {
    await this.db.execute(`DELETE FROM ${this.tableName}`)
  }
}

export default db
