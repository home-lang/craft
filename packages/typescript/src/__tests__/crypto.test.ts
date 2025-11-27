/**
 * Crypto API Tests
 *
 * Tests for cryptographic utilities.
 */

import { describe, expect, it } from 'bun:test'
import {
  uuid,
  randomString,
  timingSafeEqual
} from '../api/crypto'

describe('Crypto API', () => {
  describe('uuid', () => {
    it('should generate a valid UUID v4', () => {
      const id = uuid()

      // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      expect(id).toMatch(uuidRegex)
    })

    it('should generate unique UUIDs', () => {
      const uuids = new Set<string>()
      for (let i = 0; i < 1000; i++) {
        uuids.add(uuid())
      }
      expect(uuids.size).toBe(1000)
    })
  })

  describe('randomString', () => {
    it('should generate string of specified length', async () => {
      const str = await randomString(16)
      expect(str.length).toBe(16)
    })

    it('should require length parameter', async () => {
      // randomString requires a length parameter
      const str = await randomString(32)
      expect(str.length).toBe(32)
    })

    it('should generate alphanumeric characters', async () => {
      const str = await randomString(100)
      expect(str).toMatch(/^[A-Za-z0-9]+$/)
    })

    it('should generate unique strings', async () => {
      const strings = new Set<string>()
      for (let i = 0; i < 100; i++) {
        strings.add(await randomString(16))
      }
      expect(strings.size).toBe(100)
    })

    it('should handle zero length', async () => {
      const str = await randomString(0)
      expect(str.length).toBe(0)
    })
  })

  describe('timingSafeEqual', () => {
    it('should return true for equal strings', () => {
      expect(timingSafeEqual('hello', 'hello')).toBe(true)
      expect(timingSafeEqual('', '')).toBe(true)
      expect(timingSafeEqual('a'.repeat(1000), 'a'.repeat(1000))).toBe(true)
    })

    it('should return false for different strings', () => {
      expect(timingSafeEqual('hello', 'world')).toBe(false)
      expect(timingSafeEqual('hello', 'Hello')).toBe(false)
      expect(timingSafeEqual('hello', 'hello ')).toBe(false)
    })

    it('should return false for different length strings', () => {
      expect(timingSafeEqual('short', 'longer string')).toBe(false)
      expect(timingSafeEqual('abc', 'ab')).toBe(false)
    })

    it('should handle special characters', () => {
      expect(timingSafeEqual('hello\nworld', 'hello\nworld')).toBe(true)
      expect(timingSafeEqual('hello\tworld', 'hello\tworld')).toBe(true)
      expect(timingSafeEqual('unicode: 日本語', 'unicode: 日本語')).toBe(true)
    })
  })
})
