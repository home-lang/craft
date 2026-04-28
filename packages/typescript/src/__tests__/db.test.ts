/**
 * Database API Tests
 *
 * Focused on the input-validation surface (table/column names, traversal in
 * `openDatabase`). Actual SQL execution requires the native bridge and is
 * exercised by integration tests.
 */

import { describe, expect, it } from 'bun:test'
import { Database, dbAudit, openDatabase, openDatabaseReadOnly, validateTableName } from '../api/db'

describe('Database API — identifier validation', () => {
  it('accepts simple alphanumeric names', () => {
    expect(() => validateTableName('users')).not.toThrow()
    expect(() => validateTableName('user_profiles')).not.toThrow()
    expect(() => validateTableName('_internal')).not.toThrow()
    expect(() => validateTableName('a1')).not.toThrow()
  })

  it('rejects names that start with a digit', () => {
    expect(() => validateTableName('1users')).toThrow(/Invalid table name/)
  })

  it('rejects names with invalid characters', () => {
    expect(() => validateTableName('users; DROP TABLE foo')).toThrow()
    expect(() => validateTableName('users--')).toThrow()
    expect(() => validateTableName('"users"')).toThrow()
    expect(() => validateTableName('users.x')).toThrow()
    expect(() => validateTableName(' users')).toThrow()
  })

  it('rejects empty / non-string names', () => {
    expect(() => validateTableName('')).toThrow(/non-empty/)
    expect(() => validateTableName(null as unknown as string)).toThrow()
  })

  it('caps identifier length at 64 chars', () => {
    const sixtyFour = 'a'.repeat(64)
    const sixtyFive = 'a'.repeat(65)
    expect(() => validateTableName(sixtyFour)).not.toThrow()
    expect(() => validateTableName(sixtyFive)).toThrow(/64 characters/)
  })
})

describe('Database API — openDatabase path checks', () => {
  it('rejects names containing path traversal', async () => {
    await expect(openDatabase('../escape')).rejects.toThrow(/Invalid database name/)
    await expect(openDatabase('a/../b')).rejects.toThrow(/Invalid database name/)
    await expect(openDatabase('..')).rejects.toThrow(/Invalid database name/)
  })

  it('rejects names containing null bytes', async () => {
    await expect(openDatabase('foo\0bar')).rejects.toThrow(/Invalid database name/)
  })

  it('returns a Database for benign names', async () => {
    const db = await openDatabase('myapp')
    expect(db).toBeDefined()
  })
})

describe('Database — read-only mode', () => {
  it('flags read-only via openDatabaseReadOnly', async () => {
    const db = await openDatabaseReadOnly('analytics')
    expect(db.isReadOnly()).toBe(true)
  })

  it('rejects mutating statements in read-only mode', async () => {
    const db = new Database('test', { readOnly: true })
    // Mark as open so execute() doesn't try to dispatch open() to a missing bridge
    ;(db as unknown as { isOpen: boolean }).isOpen = true
    await expect(db.execute('DROP TABLE users')).rejects.toThrow(/read-only/)
    await expect(db.execute('INSERT INTO users VALUES (1)')).rejects.toThrow(/read-only/)
    await expect(db.execute('  -- comment\n   UPDATE users SET x=1')).rejects.toThrow(/read-only/)
  })

  it('emits db:execute audit events', async () => {
    const events: Array<{ name: string; sql: string; paramsCount: number }> = []
    const handler = (e: { name: string; sql: string; paramsCount: number }) => events.push(e)
    dbAudit.on('db:execute', handler)
    try {
      const db = new Database('audit', { readOnly: true })
      ;(db as unknown as { isOpen: boolean }).isOpen = true
      await db.execute('UPDATE x SET y=1', [1, 2]).catch(() => {/* expected */})
      expect(events.length).toBe(1)
      expect(events[0].name).toBe('audit')
      expect(events[0].paramsCount).toBe(2)
    }
    finally {
      dbAudit.off('db:execute', handler)
    }
  })
})
