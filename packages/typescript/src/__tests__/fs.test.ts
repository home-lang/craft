/**
 * File System API Tests
 *
 * Focused on `validatePath` traversal protection. Actual file I/O is left to
 * integration tests.
 */

import { describe, expect, it } from 'bun:test'
import { validatePath } from '../api/fs'

describe('fs.validatePath', () => {
  it('accepts ordinary absolute and relative paths', () => {
    expect(() => validatePath('/tmp/foo')).not.toThrow()
    expect(() => validatePath('foo/bar')).not.toThrow()
    expect(() => validatePath('./foo')).not.toThrow()
  })

  it('rejects empty / non-string input', () => {
    expect(() => validatePath('')).toThrow(/non-empty/)
    // @ts-expect-error - intentional bad input
    expect(() => validatePath(undefined)).toThrow()
  })

  it('rejects null bytes', () => {
    expect(() => validatePath('foo\0bar')).toThrow(/null byte/)
  })

  it('rejects raw .. segments anywhere in the path', () => {
    expect(() => validatePath('../etc/passwd')).toThrow(/traversal/)
    expect(() => validatePath('foo/../bar')).toThrow(/traversal/)
    expect(() => validatePath('foo/..')).toThrow(/traversal/)
    expect(() => validatePath('..')).toThrow(/traversal/)
  })

  it('rejects backslash-separated traversal on Windows-style paths', () => {
    expect(() => validatePath('foo\\..\\bar')).toThrow(/traversal/)
  })

  it('rejects URL-encoded traversal', () => {
    expect(() => validatePath('%2e%2e/etc/passwd')).toThrow(/traversal/)
    expect(() => validatePath('foo/%2e%2e/bar')).toThrow(/traversal/)
  })

  it('rejects malformed percent-encoding rather than failing open', () => {
    expect(() => validatePath('foo/%ZZ/bar')).toThrow(/percent-encoding/)
  })

  it('does not flag legitimate names that merely contain ".."', () => {
    expect(() => validatePath('a..b/file')).not.toThrow()
    expect(() => validatePath('..hidden')).not.toThrow()
  })

  it('enforces root containment when a root is supplied', () => {
    const root = '/var/app'
    expect(() => validatePath('/var/app/foo', root)).not.toThrow()
    expect(() => validatePath('/etc/passwd', root)).toThrow(/escapes root/)
  })
})
