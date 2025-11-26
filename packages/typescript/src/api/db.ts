/**
 * Craft Database API
 * Provides SQLite database access through the Craft bridge
 */

import type { CraftDatabaseAPI } from '../types'

/**
 * Database API implementation
 * Uses native SQLite through the Craft bridge
 */
export const db: CraftDatabaseAPI = {
  /**
   * Execute SQL statement (INSERT, UPDATE, DELETE, CREATE, etc.)
   */
  async execute(sql: string, params?: unknown[]): Promise<void> {
    if (typeof window !== 'undefined' && window.craft?.db) {
      return window.craft.db.execute(sql, params)
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  },

  /**
   * Query database (SELECT)
   */
  async query(sql: string, params?: unknown[]): Promise<unknown[]> {
    if (typeof window !== 'undefined' && window.craft?.db) {
      return window.craft.db.query(sql, params)
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  },

  /**
   * Begin a transaction
   */
  async beginTransaction(): Promise<void> {
    if (typeof window !== 'undefined' && window.craft?.db) {
      return window.craft.db.beginTransaction()
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  },

  /**
   * Commit current transaction
   */
  async commit(): Promise<void> {
    if (typeof window !== 'undefined' && window.craft?.db) {
      return window.craft.db.commit()
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  },

  /**
   * Rollback current transaction
   */
  async rollback(): Promise<void> {
    if (typeof window !== 'undefined' && window.craft?.db) {
      return window.craft.db.rollback()
    }
    throw new Error('Database API not available. Must run in Craft environment.')
  }
}

/**
 * Create or open a database
 */
export async function openDatabase(name: string): Promise<Database> {
  return new Database(name)
}

/**
 * Database class with extended functionality
 */
export class Database {
  private name: string
  private isOpen: boolean = false

  constructor(name: string) {
    this.name = name
  }

  /**
   * Open the database connection
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
   * Close the database connection
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
   * Execute SQL statement
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
   * Query database
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
   * Get single row
   */
  async get<T = unknown>(sql: string, params?: unknown[]): Promise<T | null> {
    const rows = await this.query<T>(sql, params)
    return rows.length > 0 ? rows[0] : null
  }

  /**
   * Run in transaction
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
   * Create table helper
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
   * Drop table
   */
  async dropTable(tableName: string): Promise<void> {
    await this.execute(`DROP TABLE IF EXISTS ${tableName}`)
  }

  /**
   * Check if table exists
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
 * Execute result
 */
export interface ExecuteResult {
  rowsAffected: number
  lastInsertId: number
}

/**
 * Table column definition
 */
export interface TableColumn {
  name: string
  type: 'TEXT' | 'INTEGER' | 'REAL' | 'BLOB' | 'NULL'
  primaryKey?: boolean
  autoIncrement?: boolean
  notNull?: boolean
  unique?: boolean
  default?: unknown
}

/**
 * Key-Value store backed by SQLite
 */
export class KeyValueStore {
  private db: Database
  private tableName: string

  constructor(db: Database, tableName: string = 'kv_store') {
    this.db = db
    this.tableName = tableName
  }

  /**
   * Initialize the KV store table
   */
  async init(): Promise<void> {
    await this.db.createTable(this.tableName, [
      { name: 'key', type: 'TEXT', primaryKey: true },
      { name: 'value', type: 'TEXT' },
      { name: 'updated_at', type: 'INTEGER' }
    ])
  }

  /**
   * Get value by key
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
   * Set value for key
   */
  async set(key: string, value: unknown): Promise<void> {
    const serialized = JSON.stringify(value)
    await this.db.execute(
      `INSERT OR REPLACE INTO ${this.tableName} (key, value, updated_at) VALUES (?, ?, ?)`,
      [key, serialized, Date.now()]
    )
  }

  /**
   * Delete key
   */
  async delete(key: string): Promise<void> {
    await this.db.execute(`DELETE FROM ${this.tableName} WHERE key = ?`, [key])
  }

  /**
   * Check if key exists
   */
  async has(key: string): Promise<boolean> {
    const row = await this.db.get<{ key: string }>(
      `SELECT key FROM ${this.tableName} WHERE key = ?`,
      [key]
    )
    return row !== null
  }

  /**
   * Get all keys
   */
  async keys(): Promise<string[]> {
    const rows = await this.db.query<{ key: string }>(
      `SELECT key FROM ${this.tableName}`
    )
    return rows.map(r => r.key)
  }

  /**
   * Clear all entries
   */
  async clear(): Promise<void> {
    await this.db.execute(`DELETE FROM ${this.tableName}`)
  }
}

export default db
