/**
 * Craft Crypto API
 * Provides cryptographic operations through the Craft bridge
 */

import type { CraftCryptoAPI } from '../types'

/**
 * Error type for cryptographic failures (malformed input, decode errors, etc.).
 *
 * Pre-ES2022 runtimes don't support the `Error(message, { cause })`
 * overload — `super(message, options)` ignores `options.cause` and the
 * `.cause` property never gets attached. We assign it manually after
 * super() so callers can rely on `error.cause` regardless of the host.
 */
export class CraftCryptoError extends Error {
  override readonly name: string = 'CraftCryptoError'
  override cause?: unknown
  constructor(message: string, options?: { cause?: unknown }) {
    super(message, options)
    if (options && 'cause' in options) {
      this.cause = options.cause
    }
  }
}

/**
 * Thrown when {@link crypto.decrypt} is given a ciphertext produced by the
 * pre-versioning format (no salt prefix). Apps that persisted secrets with
 * older Craft versions should catch this and re-encrypt the cleartext with
 * the current API.
 */
export class LegacyCiphertextError extends CraftCryptoError {
  override readonly name: string = 'LegacyCiphertextError'
  constructor() {
    super(
      'Ciphertext was produced by a pre-versioning Craft crypto release. '
      + 'Re-encrypt the value with the current API to migrate to the v1 wire format.',
    )
  }
}

// Wire format (post-migration):
//
//   [version(1) | salt(16) | iv(12) | ciphertext + auth-tag(16)]
//
// The leading version byte lets us detect older payloads and refuse them
// loudly instead of silently failing AES-GCM decryption deep in the crypto
// stack. v1 is the salt-prefixed layout from late 2025; legacy payloads
// have no version byte and aren't decryptable with the same code path.
//
// The KDF is PBKDF2-SHA256 in BOTH the WebCrypto and Node fallbacks so
// ciphertext is portable across runtimes — the previous implementation
// used scrypt in Node and PBKDF2 in the browser, which produced different
// keys for the same password and made the ciphertext non-portable.
const FORMAT_VERSION = 0x01
const SALT_LEN = 16
const IV_LEN = 12
const TAG_LEN = 16
/**
 * PBKDF2-SHA256 iteration count for the AES-256-GCM data-encryption key.
 * Bumped from 100k → 600k to align with OWASP's 2023+ guidance for
 * password-stretching with PBKDF2-SHA256.
 */
const PBKDF2_ITERATIONS = 600_000

/**
 * Crypto API implementation
 * Uses native crypto through the Craft bridge
 */
export const crypto: CraftCryptoAPI = {
  /**
   * Generate cryptographically secure random bytes
   */
  async randomBytes(size: number): Promise<Uint8Array> {
    if (typeof window !== 'undefined' && window.craft?.crypto) {
      return window.craft.crypto.randomBytes(size)
    }
    // Web Crypto API fallback. WebCrypto caps `getRandomValues` at 64KiB
    // per call, so chunk for large requests.
    if (typeof globalThis.crypto !== 'undefined' && typeof globalThis.crypto.getRandomValues === 'function') {
      const out = new Uint8Array(size)
      const chunk = 65_536
      for (let i = 0; i < size; i += chunk) {
        const view = out.subarray(i, Math.min(i + chunk, size))
        globalThis.crypto.getRandomValues(view)
      }
      return out
    }
    // Node.js fallback
    const { randomBytes } = await import('node:crypto')
    return new Uint8Array(randomBytes(size))
  },

  /**
   * Hash data using specified algorithm.
   *
   * MD5 is supported only in Node — WebCrypto does not implement it. In a
   * browser-like context (`globalThis.crypto.subtle` available, no
   * `process` global) we throw a clear error rather than letting the
   * caller fall through to a `node:crypto` import that crashes the page.
   */
  async hash(algorithm: 'sha256' | 'sha512' | 'md5', data: string): Promise<string> {
    if (typeof window !== 'undefined' && window.craft?.crypto) {
      return window.craft.crypto.hash(algorithm, data)
    }
    if (algorithm === 'md5') {
      // MD5 is reachable only through Node. Detect Node by feature
      // sniffing rather than `typeof process` (Bun and some bundlers
      // expose `process` in browser bundles).
      const hasNodeCrypto = typeof process !== 'undefined' && (process as { versions?: { node?: string } }).versions?.node
      if (!hasNodeCrypto) {
        throw new CraftCryptoError(
          'MD5 is not available in this runtime — WebCrypto does not implement it. '
          + 'Use sha256/sha512, or call this from Node.',
        )
      }
      const { createHash } = await import('node:crypto')
      return createHash('md5').update(data).digest('hex')
    }
    if (typeof globalThis.crypto !== 'undefined' && globalThis.crypto.subtle) {
      const encoder = new TextEncoder()
      const dataBuffer = encoder.encode(data)
      const hashBuffer = await globalThis.crypto.subtle.digest(
        algorithm === 'sha256' ? 'SHA-256' : 'SHA-512',
        dataBuffer,
      )
      return bufferToHex(hashBuffer)
    }
    const { createHash } = await import('node:crypto')
    return createHash(algorithm).update(data).digest('hex')
  },

  /**
   * Encrypt data with AES-256-GCM. Wire format:
   *   `[version(1) | salt(16) | iv(12) | ciphertext+tag]`
   *
   * The KDF is PBKDF2-SHA256 in both runtimes, so ciphertext produced in
   * the browser decrypts in Node and vice versa.
   */
  async encrypt(data: string, key: string): Promise<string> {
    if (typeof window !== 'undefined' && window.craft?.crypto) {
      return window.craft.crypto.encrypt(data, key)
    }
    const salt = await crypto.randomBytes(SALT_LEN)
    const iv = await crypto.randomBytes(IV_LEN)
    const aesKey = await derivePbkdf2Key(key, salt)
    const ciphertext = await aesGcmEncrypt(aesKey, iv, new TextEncoder().encode(data))

    const combined = new Uint8Array(1 + salt.length + iv.length + ciphertext.length)
    combined[0] = FORMAT_VERSION
    combined.set(salt, 1)
    combined.set(iv, 1 + salt.length)
    combined.set(ciphertext, 1 + salt.length + iv.length)
    return bufferToBase64(combined.buffer)
  },

  /**
   * Decrypt data with AES-256-GCM. Mirrors the wire format used by
   * {@link crypto.encrypt}.
   */
  async decrypt(encryptedData: string, key: string): Promise<string> {
    if (typeof window !== 'undefined' && window.craft?.crypto) {
      return window.craft.crypto.decrypt(encryptedData, key)
    }
    const combined = base64ToBuffer(encryptedData)
    if (combined.length < 1 + SALT_LEN + IV_LEN + TAG_LEN) {
      throw new CraftCryptoError('Ciphertext too short to be valid')
    }
    const version = combined[0]
    if (version !== FORMAT_VERSION) {
      throw new LegacyCiphertextError()
    }
    const salt = combined.slice(1, 1 + SALT_LEN)
    const iv = combined.slice(1 + SALT_LEN, 1 + SALT_LEN + IV_LEN)
    const data = combined.slice(1 + SALT_LEN + IV_LEN)

    const aesKey = await derivePbkdf2Key(key, salt)
    try {
      const plaintext = await aesGcmDecrypt(aesKey, iv, data)
      return new TextDecoder().decode(plaintext)
    }
    catch (e) {
      throw new CraftCryptoError('Decryption failed (wrong key or corrupted data)', { cause: e })
    }
  },
}

/**
 * Convert a Uint8Array into a BufferSource that satisfies WebCrypto's
 * stricter `ArrayBufferView<ArrayBuffer>` type. The runtime value is the
 * same; the cast is purely to keep TypeScript happy in projects that
 * pin `lib: ["DOM"]` to the post-resizable-buffers definitions.
 */
function asBufferSource(bytes: Uint8Array): BufferSource {
  return bytes as unknown as BufferSource
}

/**
 * Derive a 32-byte AES key from a password using PBKDF2-SHA256. WebCrypto
 * is preferred when available; Node `pbkdf2Sync` is used as a fallback.
 */
async function derivePbkdf2Key(password: string, salt: Uint8Array): Promise<CryptoKey | Uint8Array> {
  if (typeof globalThis.crypto !== 'undefined' && globalThis.crypto.subtle) {
    const encoder = new TextEncoder()
    const keyMaterial = await globalThis.crypto.subtle.importKey(
      'raw',
      encoder.encode(password),
      'PBKDF2',
      false,
      ['deriveKey'],
    )
    return globalThis.crypto.subtle.deriveKey(
      {
        name: 'PBKDF2',
        salt: asBufferSource(salt),
        iterations: PBKDF2_ITERATIONS,
        hash: 'SHA-256',
      },
      keyMaterial,
      { name: 'AES-GCM', length: 256 },
      false,
      ['encrypt', 'decrypt'],
    )
  }
  const { pbkdf2Sync } = await import('node:crypto')
  return new Uint8Array(pbkdf2Sync(password, salt, PBKDF2_ITERATIONS, 32, 'sha256'))
}

async function aesGcmEncrypt(
  key: CryptoKey | Uint8Array,
  iv: Uint8Array,
  plaintext: Uint8Array,
): Promise<Uint8Array> {
  if (key instanceof Uint8Array) {
    const { createCipheriv } = await import('node:crypto')
    const cipher = createCipheriv('aes-256-gcm', key, iv)
    const ct1 = cipher.update(plaintext)
    const ct2 = cipher.final()
    const tag = cipher.getAuthTag()
    const out = new Uint8Array(ct1.length + ct2.length + tag.length)
    out.set(ct1, 0)
    out.set(ct2, ct1.length)
    out.set(tag, ct1.length + ct2.length)
    return out
  }
  const out = await globalThis.crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: asBufferSource(iv) },
    key,
    asBufferSource(plaintext),
  )
  return new Uint8Array(out)
}

async function aesGcmDecrypt(
  key: CryptoKey | Uint8Array,
  iv: Uint8Array,
  ciphertextWithTag: Uint8Array,
): Promise<Uint8Array> {
  if (key instanceof Uint8Array) {
    const { createDecipheriv } = await import('node:crypto')
    const tag = ciphertextWithTag.subarray(ciphertextWithTag.length - TAG_LEN)
    const ct = ciphertextWithTag.subarray(0, ciphertextWithTag.length - TAG_LEN)
    const decipher = createDecipheriv('aes-256-gcm', key, iv)
    decipher.setAuthTag(tag)
    const pt1 = decipher.update(ct)
    const pt2 = decipher.final()
    const out = new Uint8Array(pt1.length + pt2.length)
    out.set(pt1, 0)
    out.set(pt2, pt1.length)
    return out
  }
  const out = await globalThis.crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: asBufferSource(iv) },
    key,
    asBufferSource(ciphertextWithTag),
  )
  return new Uint8Array(out)
}

/**
 * Convert ArrayBuffer to hex string
 */
function bufferToHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}

/**
 * Convert ArrayBuffer to base64 string
 */
function bufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  const chunks: string[] = []
  const chunkSize = 8192
  for (let i = 0; i < bytes.byteLength; i += chunkSize) {
    chunks.push(String.fromCharCode(...bytes.subarray(i, i + chunkSize)))
  }
  if (typeof btoa !== 'undefined') return btoa(chunks.join(''))
  return Buffer.from(bytes).toString('base64')
}

/**
 * Convert base64 string to Uint8Array.
 * Throws CraftCryptoError on malformed input rather than DOMException.
 */
function base64ToBuffer(base64: string): Uint8Array {
  if (typeof atob !== 'undefined') {
    let binary: string
    try {
      binary = atob(base64)
    }
    catch (e) {
      throw new CraftCryptoError('Invalid base64 input', { cause: e })
    }
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i)
    }
    return bytes
  }
  return new Uint8Array(Buffer.from(base64, 'base64'))
}

/**
 * Generate a random UUID v4
 */
export function uuid(): string {
  if (typeof globalThis.crypto !== 'undefined' && 'randomUUID' in globalThis.crypto) {
    return globalThis.crypto.randomUUID()
  }
  // Fallback using crypto.getRandomValues for security
  const bytes = new Uint8Array(16)
  ;(globalThis.crypto as Crypto).getRandomValues(bytes)
  // Set version (4) and variant (RFC 4122)
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('')
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`
}

/**
 * Generate a random string of specified length.
 *
 * @throws {CraftCryptoError} when `charset` is empty (would otherwise loop
 *   forever with `Math.random` returning a value modulo 0).
 */
export async function randomString(length: number, charset?: string): Promise<string> {
  const chars = charset ?? 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  if (chars.length === 0) {
    throw new CraftCryptoError('randomString: charset cannot be empty')
  }
  if (!Number.isInteger(length) || length < 0) {
    throw new CraftCryptoError('randomString: length must be a non-negative integer')
  }
  if (length === 0) return ''
  // Use rejection sampling to avoid modulo bias
  const maxValid = 256 - (256 % chars.length)
  let bytes = await crypto.randomBytes(length * 2)
  let result = ''
  let i = 0
  while (result.length < length) {
    if (i >= bytes.length) {
      bytes = await crypto.randomBytes(length * 2)
      i = 0
    }
    if (bytes[i] < maxValid) {
      result += chars[bytes[i] % chars.length]
    }
    i++
  }
  return result
}

/**
 * HMAC signature
 */
export async function hmac(
  algorithm: 'sha256' | 'sha512',
  key: string,
  data: string,
): Promise<string> {
  if (typeof globalThis.crypto !== 'undefined' && globalThis.crypto.subtle) {
    const encoder = new TextEncoder()
    const keyBuffer = await globalThis.crypto.subtle.importKey(
      'raw',
      encoder.encode(key),
      { name: 'HMAC', hash: algorithm === 'sha256' ? 'SHA-256' : 'SHA-512' },
      false,
      ['sign'],
    )

    const signature = await globalThis.crypto.subtle.sign('HMAC', keyBuffer, encoder.encode(data))
    return bufferToHex(signature)
  }

  // Node.js fallback
  const nodeCrypto = await import('node:crypto')
  return nodeCrypto.createHmac(algorithm, key).update(data).digest('hex')
}

/**
 * Compare two strings in constant time (timing-safe).
 *
 * Compares the UTF-8 byte representations rather than UTF-16 code units —
 * NFC/NFD-different but visually-identical strings still come out unequal,
 * but at least byte-level comparison is what cryptographic protocols
 * actually expect.
 */
export function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder()
  const aBytes = enc.encode(a)
  const bBytes = enc.encode(b)
  // Always compare full length to avoid leaking length information via timing
  const maxLen = Math.max(aBytes.length, bBytes.length)
  let result = aBytes.length ^ bBytes.length
  for (let i = 0; i < maxLen; i++) {
    result |= (aBytes[i] ?? 0) ^ (bBytes[i] ?? 0)
  }
  return result === 0
}

/**
 * Generate password hash (using PBKDF2-SHA256 with 600k iterations).
 *
 * Salt encoding is unified across runtimes: the salt is always returned
 * as base64, and when supplied it is interpreted as base64 in BOTH the
 * WebCrypto and Node code paths. The previous implementation treated the
 * salt as base64 in WebCrypto and as a raw UTF-8 string in Node, so the
 * same `(password, salt)` pair gave different hashes per environment and
 * cross-environment auth was broken.
 */
export async function hashPassword(password: string, salt?: string): Promise<{ hash: string; salt: string }> {
  let saltBytes: Uint8Array
  if (salt) {
    try {
      saltBytes = base64ToBuffer(salt)
    }
    catch (e) {
      throw new CraftCryptoError('hashPassword: salt must be base64-encoded', { cause: e })
    }
  }
  else {
    saltBytes = await crypto.randomBytes(16)
  }
  const actualSalt = bufferToBase64(saltBytes.buffer.slice(saltBytes.byteOffset, saltBytes.byteOffset + saltBytes.byteLength) as ArrayBuffer)

  if (typeof globalThis.crypto !== 'undefined' && globalThis.crypto.subtle) {
    const encoder = new TextEncoder()
    const keyMaterial = await globalThis.crypto.subtle.importKey(
      'raw',
      encoder.encode(password),
      'PBKDF2',
      false,
      ['deriveBits'],
    )

    const derivedBits = await globalThis.crypto.subtle.deriveBits(
      {
        name: 'PBKDF2',
        salt: asBufferSource(saltBytes),
        iterations: PBKDF2_ITERATIONS,
        hash: 'SHA-256',
      },
      keyMaterial,
      256,
    )

    return {
      hash: bufferToBase64(derivedBits),
      salt: actualSalt,
    }
  }

  const { pbkdf2 } = await import('node:crypto')
  return new Promise((resolve, reject) => {
    pbkdf2(password, saltBytes, PBKDF2_ITERATIONS, 32, 'sha256', (err, derivedKey) => {
      if (err) reject(err)
      else resolve({
        hash: bufferToBase64(derivedKey.buffer.slice(derivedKey.byteOffset, derivedKey.byteOffset + derivedKey.byteLength) as ArrayBuffer),
        salt: actualSalt,
      })
    })
  })
}

/**
 * Verify password against hash
 */
export async function verifyPassword(password: string, hash: string, salt: string): Promise<boolean> {
  const result = await hashPassword(password, salt)
  return timingSafeEqual(result.hash, hash)
}

export default crypto
