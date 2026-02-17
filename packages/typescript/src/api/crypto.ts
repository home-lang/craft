/**
 * Craft Crypto API
 * Provides cryptographic operations through the Craft bridge
 */

import type { CraftCryptoAPI } from '../types'

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
      const iv = globalThis.crypto.getRandomValues(new Uint8Array(12))
      const keyBuffer = await deriveKey(key)

      const encrypted = await globalThis.crypto.subtle.encrypt(
        { name: 'AES-GCM', iv },
        keyBuffer,
        encoder.encode(data)
      )

      // Combine IV and encrypted data
      const combined = new Uint8Array(iv.length + new Uint8Array(encrypted).length)
      combined.set(iv)
      combined.set(new Uint8Array(encrypted), iv.length)

      return bufferToBase64(combined.buffer)
    }
    // Node.js fallback
    const nodeCrypto = await import('node:crypto')
    const iv = nodeCrypto.randomBytes(12)
    const derivedKey = nodeCrypto.scryptSync(key, 'craft-salt', 32)
    const cipher = nodeCrypto.createCipheriv('aes-256-gcm', derivedKey, iv)

    let encrypted = cipher.update(data, 'utf8', 'base64')
    encrypted += cipher.final('base64')
    const tag = cipher.getAuthTag()

    // Combine IV, tag, and encrypted data
    return Buffer.concat([iv, tag, Buffer.from(encrypted, 'base64')]).toString('base64')
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
      const iv = combined.slice(0, 12)
      const data = combined.slice(12)

      const keyBuffer = await deriveKey(key)

      const decrypted = await globalThis.crypto.subtle.decrypt(
        { name: 'AES-GCM', iv },
        keyBuffer,
        data
      )

      return new TextDecoder().decode(decrypted)
    }
    // Node.js fallback
    const nodeCrypto = await import('node:crypto')
    const buffer = Buffer.from(encryptedData, 'base64')
    const iv = buffer.subarray(0, 12)
    const tag = buffer.subarray(12, 28)
    const encrypted = buffer.subarray(28)

    const derivedKey = nodeCrypto.scryptSync(key, 'craft-salt', 32)
    const decipher = nodeCrypto.createDecipheriv('aes-256-gcm', derivedKey, iv)
    decipher.setAuthTag(tag)

    let decrypted = decipher.update(encrypted)
    decrypted = Buffer.concat([decrypted, decipher.final()])

    return decrypted.toString('utf8')
  }
}

/**
 * Derive encryption key from password using PBKDF2
 */
async function deriveKey(password: string): Promise<CryptoKey> {
  const encoder = new TextEncoder()
  const salt = encoder.encode('craft-salt')

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
      iterations: 100000,
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
  let binary = ''
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary)
}

/**
 * Convert base64 string to Uint8Array
 */
function base64ToBuffer(base64: string): Uint8Array {
  const binary = atob(base64)
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
  // Fallback implementation
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0
    const v = c === 'x' ? r : (r & 0x3) | 0x8
    return v.toString(16)
  })
}

/**
 * Generate a random string of specified length
 */
export async function randomString(length: number, charset?: string): Promise<string> {
  const chars = charset || 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  const bytes = await crypto.randomBytes(length)
  let result = ''
  for (let i = 0; i < length; i++) {
    result += chars[bytes[i] % chars.length]
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
  if (a.length !== b.length) {
    return false
  }

  let result = 0
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }
  return result === 0
}

/**
 * Generate password hash (using PBKDF2)
 */
export async function hashPassword(password: string, salt?: string): Promise<{ hash: string; salt: string }> {
  const actualSalt = salt || bufferToBase64((await crypto.randomBytes(16)).buffer as ArrayBuffer)

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
        salt: base64ToBuffer(actualSalt),
        iterations: 100000,
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
    nodeCrypto.pbkdf2(password, actualSalt, 100000, 32, 'sha256', (err, derivedKey) => {
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
