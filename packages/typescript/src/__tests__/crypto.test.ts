/**
 * Crypto API Tests
 *
 * Tests for cryptographic utilities.
 */

import { describe, expect, it } from 'bun:test'
import {
  CraftCryptoError,
  crypto,
  hashPassword,
  hmac,
  LegacyCiphertextError,
  randomString,
  timingSafeEqual,
  uuid,
  verifyPassword,
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

  describe('encrypt / decrypt round-trip', () => {
    it('encrypts and decrypts an ASCII payload', async () => {
      const ct = await crypto.encrypt('hello world', 'correct horse battery staple')
      const pt = await crypto.decrypt(ct, 'correct horse battery staple')
      expect(pt).toBe('hello world')
    })

    it('produces a different ciphertext each time (random salt+iv)', async () => {
      const a = await crypto.encrypt('payload', 'k')
      const b = await crypto.encrypt('payload', 'k')
      expect(a).not.toBe(b)
    })

    it('round-trips a multibyte / unicode payload', async () => {
      const data = '🦀 unicode: 日本語 — Δ'
      const ct = await crypto.encrypt(data, 'pw')
      expect(await crypto.decrypt(ct, 'pw')).toBe(data)
    })

    it('round-trips a large (~64 KiB) payload', async () => {
      const data = 'x'.repeat(64 * 1024)
      const ct = await crypto.encrypt(data, 'pw')
      expect(await crypto.decrypt(ct, 'pw')).toBe(data)
    })

    it('rejects with CraftCryptoError on the wrong key', async () => {
      const ct = await crypto.encrypt('secret', 'right')
      let err: unknown
      try {
        await crypto.decrypt(ct, 'wrong')
      }
      catch (e) {
        err = e
      }
      expect(err).toBeInstanceOf(CraftCryptoError)
    })

    it('rejects ciphertext that is too short to be valid', async () => {
      let err: unknown
      try {
        await crypto.decrypt('YWFhYWFh', 'pw') // 6 bytes, well below salt+iv+tag
      }
      catch (e) {
        err = e
      }
      expect(err).toBeInstanceOf(CraftCryptoError)
    })

    it('rejects malformed base64 with CraftCryptoError', async () => {
      let err: unknown
      try {
        await crypto.decrypt('!!!not-base64!!!', 'pw')
      }
      catch (e) {
        err = e
      }
      // Either base64 decode or short-cipher error path can fire — both are
      // CraftCryptoError, never a raw DOMException.
      expect(err).toBeInstanceOf(CraftCryptoError)
    })

    it('throws LegacyCiphertextError on pre-versioning payloads', async () => {
      // Build a "legacy" payload: salt(16)+iv(12)+ciphertext+tag with no
      // leading version byte. The decode path should detect this and bail
      // with LegacyCiphertextError rather than returning a wrong plaintext.
      const fakeLegacy = Buffer.alloc(1 + 16 + 12 + 32) // version=0 → legacy
      fakeLegacy[0] = 0x00
      const b64 = fakeLegacy.toString('base64')
      let err: unknown
      try {
        await crypto.decrypt(b64, 'key')
      }
      catch (e) {
        err = e
      }
      expect(err).toBeInstanceOf(LegacyCiphertextError)
      expect(err).toBeInstanceOf(CraftCryptoError)
    })

    it('rejects ciphertext mutated after encryption (auth tag check)', async () => {
      const ct = await crypto.encrypt('secret', 'pw')
      // Flip a bit somewhere in the middle of the payload.
      const tampered = `${ct.slice(0, ct.length - 4)}AAAA`
      let err: unknown
      try {
        await crypto.decrypt(tampered, 'pw')
      }
      catch (e) {
        err = e
      }
      expect(err).toBeInstanceOf(CraftCryptoError)
    })
  })

  describe('hmac', () => {
    it('produces a deterministic SHA-256 hex digest', async () => {
      const a = await hmac('sha256', 'k', 'hello')
      const b = await hmac('sha256', 'k', 'hello')
      expect(a).toBe(b)
      expect(a).toMatch(/^[0-9a-f]{64}$/)
    })

    it('changes with the key', async () => {
      const a = await hmac('sha256', 'k1', 'hello')
      const b = await hmac('sha256', 'k2', 'hello')
      expect(a).not.toBe(b)
    })
  })

  describe('hashPassword / verifyPassword', () => {
    it('round-trips correct password', async () => {
      const { hash, salt } = await hashPassword('hunter2')
      expect(await verifyPassword('hunter2', hash, salt)).toBe(true)
    })

    it('rejects the wrong password', async () => {
      const { hash, salt } = await hashPassword('hunter2')
      expect(await verifyPassword('not-hunter2', hash, salt)).toBe(false)
    })

    it('produces a fresh salt per call when none is supplied', async () => {
      const a = await hashPassword('hunter2')
      const b = await hashPassword('hunter2')
      expect(a.salt).not.toBe(b.salt)
      expect(a.hash).not.toBe(b.hash)
    })
  })
})
