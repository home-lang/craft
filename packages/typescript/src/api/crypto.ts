/**
 * Craft Crypto API
 * Provides cryptographic operations through the Craft bridge
 */

import type { CraftCryptoAPI } from '../types'

/**
 * Error type for cryptographic failures (malformed input, decode errors, etc.).
 */
export class CraftCryptoError extends Error {
  override readonly name = 'CraftCryptoError'
  constructor(message: string, options?: { cause?: unknown }) {
    super(message, options)
  }
}

// Format used by the Web Crypto / Node.js fallback paths:
//
//   [salt(16) | iv(12) | ciphertext + auth-tag(16)]
//
// The salt is generated per encryption and stored alongside the ciphertext so
// the same key string produces a different derived key every time. The Web
// Crypto API natively appends the GCM tag to the ciphertext; we mirror that on
// the Node side to keep a single wire format.
const SALT_LEN = 16
const IV_LEN = 12
const TAG_LEN = 16
const PBKDF2_ITERATIONS = 100_000

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
    // Web Crypto API fallback
    if (typeof globalThis.crypto !== 'undefined') {
      const bytes = new Uint8Array(size)
      globalThis.crypto.getRandomValues(bytes)
      return bytes
    }
    // Node.js fallback
    const { randomBytes } = await import('node:crypto')
    return randomBytes(size)
  },

  /**
   * Hash data using specified algorithm
   */
  async hash(algorithm: 'sha256' | 'sha512' | 'md5', data: string): Promise<string> {
    if (typeof window !== 'undefined' && window.craft?.crypto) {
      return window.craft.crypto.hash(algorithm, data)
    }
    // Web Crypto API fallback
    if (typeof globalThis.crypto !== 'undefined' && algorithm !== 'md5') {
      const encoder = new TextEncoder()
      const dataBuffer = encoder.encode(data)
      const hashBuffer = await globalThis.crypto.subtle.digest(
        algorithm === 'sha256' ? 'SHA-256' : 'SHA-512',
        dataBuffer
      )
      return bufferToHex(hashBuffer)
    }
    // Node.js fallback
    const { createHash } = await import('node:crypto')
    return createHash(algorithm).update(data).digest('hex')
  },

  /**
   * Encrypt data with AES-256-GCM
   */
  async encrypt(data: string, key: string): Promise<string> {
    if (typeof window !== 'undefined' && window.craft?.crypto) {
      return window.craft.crypto.encrypt(data, key)
    }
    // Web Crypto API fallback
    if (typeof globalThis.crypto !== 'undefined') {
      const encoder = new TextEncoder()
      const salt = globalThis.crypto.getRandomValues(new Uint8Array(SALT_LEN))
      const iv = globalThis.crypto.getRandomValues(new Uint8Array(IV_LEN))
      const keyBuffer = await deriveKey(key, salt)

      const encrypted = new Uint8Array(
        await globalThis.crypto.subtle.encrypt(
          { name: 'AES-GCM', iv },
          keyBuffer,
          encoder.encode(data)
        )
      )

      // Combine salt + IV + ciphertext (which already has the GCM tag appended)
      const combined = new Uint8Array(salt.length + iv.length + encrypted.length)
      combined.set(salt, 0)
      combined.set(iv, salt.length)
      combined.set(encrypted, salt.length + iv.length)

      return bufferToBase64(combined.buffer)
    }
    // Node.js fallback
    const nodeCrypto = await import('node:crypto')
    const salt = nodeCrypto.randomBytes(SALT_LEN)
    const iv = nodeCrypto.randomBytes(IV_LEN)
    const derivedKey = nodeCrypto.scryptSync(key, salt, 32)
    const cipher = nodeCrypto.createCipheriv('aes-256-gcm', derivedKey, iv)

    const ciphertext = Buffer.concat([cipher.update(data, 'utf8'), cipher.final()])
    const tag = cipher.getAuthTag()

    // Wire format: salt | iv | ciphertext | tag (tag at end matches Web Crypto)
    return Buffer.concat([salt, iv, ciphertext, tag]).toString('base64')
  },

  /**
   * Decrypt data with AES-256-GCM
   */
  async decrypt(encryptedData: string, key: string): Promise<string> {
    if (typeof window !== 'undefined' && window.craft?.crypto) {
      return window.craft.crypto.decrypt(encryptedData, key)
    }
    // Web Crypto API fallback
    if (typeof globalThis.crypto !== 'undefined') {
      const combined = base64ToBuffer(encryptedData)
      if (combined.length <= SALT_LEN + IV_LEN + TAG_LEN) {
        throw new CraftCryptoError('Ciphertext too short to be valid')
      }
      const salt = combined.slice(0, SALT_LEN)
      const iv = combined.slice(SALT_LEN, SALT_LEN + IV_LEN)
      const data = combined.slice(SALT_LEN + IV_LEN)

      const keyBuffer = await deriveKey(key, salt)

      try {
        const decrypted = await globalThis.crypto.subtle.decrypt(
          { name: 'AES-GCM', iv },
          keyBuffer,
          data
        )
        return new TextDecoder().decode(decrypted)
      }
      catch (e) {
        throw new CraftCryptoError('Decryption failed (wrong key or corrupted data)', { cause: e })
      }
    }
    // Node.js fallback
    const nodeCrypto = await import('node:crypto')
    const buffer = Buffer.from(encryptedData, 'base64')
    if (buffer.length <= SALT_LEN + IV_LEN + TAG_LEN) {
      throw new CraftCryptoError('Ciphertext too short to be valid')
    }
    const salt = buffer.subarray(0, SALT_LEN)
    const iv = buffer.subarray(SALT_LEN, SALT_LEN + IV_LEN)
    const tag = buffer.subarray(buffer.length - TAG_LEN)
    const ciphertext = buffer.subarray(SALT_LEN + IV_LEN, buffer.length - TAG_LEN)

    const derivedKey = nodeCrypto.scryptSync(key, salt, 32)
    const decipher = nodeCrypto.createDecipheriv('aes-256-gcm', derivedKey, iv)
    decipher.setAuthTag(tag)

    try {
      const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()])
      return decrypted.toString('utf8')
    }
    catch (e) {
      throw new CraftCryptoError('Decryption failed (wrong key or corrupted data)', { cause: e })
    }
  }
}

/**
 * Derive encryption key from password using PBKDF2 with the supplied salt.
 */
async function deriveKey(password: string, salt: BufferSource): Promise<CryptoKey> {
  const encoder = new TextEncoder()

  const keyMaterial = await globalThis.crypto.subtle.importKey(
    'raw',
    encoder.encode(password),
    'PBKDF2',
    false,
    ['deriveKey']
  )

  return globalThis.crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt,
      iterations: PBKDF2_ITERATIONS,
      hash: 'SHA-256'
    },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  )
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
  return btoa(chunks.join(''))
}

/**
 * Convert base64 string to Uint8Array.
 * Throws CraftCryptoError on malformed input rather than DOMException.
 */
function base64ToBuffer(base64: string): Uint8Array {
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
 * Generate a random string of specified length
 */
export async function randomString(length: number, charset?: string): Promise<string> {
  const chars = charset || 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
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
  data: string
): Promise<string> {
  // Web Crypto API
  if (typeof globalThis.crypto !== 'undefined') {
    const encoder = new TextEncoder()
    const keyBuffer = await globalThis.crypto.subtle.importKey(
      'raw',
      encoder.encode(key),
      { name: 'HMAC', hash: algorithm === 'sha256' ? 'SHA-256' : 'SHA-512' },
      false,
      ['sign']
    )

    const signature = await globalThis.crypto.subtle.sign(
      'HMAC',
      keyBuffer,
      encoder.encode(data)
    )

    return bufferToHex(signature)
  }

  // Node.js fallback
  const nodeCrypto = await import('node:crypto')
  return nodeCrypto.createHmac(algorithm, key).update(data).digest('hex')
}

/**
 * Compare two strings in constant time (timing-safe)
 */
export function timingSafeEqual(a: string, b: string): boolean {
  // Always compare full length to avoid leaking length information via timing
  const maxLen = Math.max(a.length, b.length)
  let result = a.length ^ b.length
  for (let i = 0; i < maxLen; i++) {
    result |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0)
  }
  return result === 0
}

/**
 * Generate password hash (using PBKDF2). When `salt` is omitted a random
 * 16-byte salt is generated and returned alongside the hash.
 */
export async function hashPassword(password: string, salt?: string): Promise<{ hash: string; salt: string }> {
  let actualSalt: string
  if (salt) {
    actualSalt = salt
  }
  else {
    const saltBytes = await crypto.randomBytes(16)
    actualSalt = bufferToBase64(new Uint8Array(saltBytes).buffer as ArrayBuffer)
  }

  if (typeof globalThis.crypto !== 'undefined') {
    const encoder = new TextEncoder()
    const keyMaterial = await globalThis.crypto.subtle.importKey(
      'raw',
      encoder.encode(password),
      'PBKDF2',
      false,
      ['deriveBits']
    )

    const derivedBits = await globalThis.crypto.subtle.deriveBits(
      {
        name: 'PBKDF2',
        salt: new Uint8Array(base64ToBuffer(actualSalt)).buffer as ArrayBuffer,
        iterations: PBKDF2_ITERATIONS,
        hash: 'SHA-256'
      },
      keyMaterial,
      256
    )

    return {
      hash: bufferToBase64(derivedBits),
      salt: actualSalt
    }
  }

  // Node.js fallback
  const nodeCrypto = await import('node:crypto')
  return new Promise((resolve, reject) => {
    nodeCrypto.pbkdf2(password, actualSalt, PBKDF2_ITERATIONS, 32, 'sha256', (err, derivedKey) => {
      if (err) reject(err)
      else resolve({
        hash: derivedKey.toString('base64'),
        salt: actualSalt
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
