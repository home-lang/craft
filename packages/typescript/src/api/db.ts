/**
 * @fileoverview Craft Database API
 * @description Provides SQLite database access through the Craft bridge.
 * Includes transaction support, table management, and a key-value store abstraction.
 * @module @craft/api/db
 *
 * @example
 * ```typescript
 * import { openDatabase, KeyValueStore } from '@craft/api/db'
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

import type { CraftDatabaseAPI } from '../types'

/**
 * Low-level database API implementation.
 * Uses native SQLite through the Craft bridge.
 * For most use cases, prefer the {@link Database} class or {@link KeyValueStore}.
 *
 * @example
 * ```typescript
 * import { db } from '@craft/api/db'
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
   * } catch (error) {
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
  return new Database(name)
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

  /**
   * Create a new Database instance.
   *
   * @param name - Database name
   */
  constructor(name: string) {
    this.name = name
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
      await (window.craft as any).bridge?.call('db.open', { name: this.name })
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
      await (window.craft as any).bridge?.call('db.close', { name: this.name })
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
    if (typeof window !== 'undefined' && window.craft) {
      const result = await (window.craft as any).bridge?.call('db.execute', {
        name: this.name,
        sql,
        params: params || []
      })
      return {
        rowsAffected: result.rowsAffected,
        lastInsertId: result.lastInsertId
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
      return (window.craft as any).bridge?.call('db.query', {
        name: this.name,
        sql,
        params: params || []
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
   * } else {
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
    await db.beginTransaction()
    try {
      const result = await fn()
      await db.commit()
      return result
    } catch (error) {
      await db.rollback()
      throw error
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
    const columnDefs = columns.map(col => {
      let def = `${col.name} ${col.type}`
      if (col.primaryKey) def += ' PRIMARY KEY'
      if (col.autoIncrement) def += ' AUTOINCREMENT'
      if (col.notNull) def += ' NOT NULL'
      if (col.unique) def += ' UNIQUE'
      if (col.default !== undefined) {
        const defaultVal = typeof col.default === 'string'
          ? `'${col.default}'`
          : col.default
        def += ` DEFAULT ${defaultVal}`
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
    await this.execute(`DROP TABLE IF EXISTS ${tableName}`)
  }

  /**
   * Check if a table exists in the database.
   *
   * @param tableName - Name of the table to check
   * @returns Promise resolving to true if table exists
   */
  async tableExists(tableName: string): Promise<boolean> {
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
      } catch {
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
