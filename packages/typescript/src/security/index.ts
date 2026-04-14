/**
 * Craft Security Enhancements
 * CSP, CORS, certificate pinning, secure storage, and input validation
 */

import { createCipheriv, createDecipheriv, createHash, pbkdf2Sync, randomBytes } from 'crypto'

// Types
export interface CSPDirectives {
  'default-src'?: string[]
  'script-src'?: string[]
  'style-src'?: string[]
  'img-src'?: string[]
  'font-src'?: string[]
  'connect-src'?: string[]
  'media-src'?: string[]
  'object-src'?: string[]
  'frame-src'?: string[]
  'worker-src'?: string[]
  'child-src'?: string[]
  'form-action'?: string[]
  'frame-ancestors'?: string[]
  'base-uri'?: string[]
  'report-uri'?: string[]
  'report-to'?: string[]
  'upgrade-insecure-requests'?: boolean
  'block-all-mixed-content'?: boolean
}

export interface CORSConfig {
  origin?: string | string[] | boolean | ((_origin: string) => boolean)
  methods?: string[]
  allowedHeaders?: string[]
  exposedHeaders?: string[]
  credentials?: boolean
  maxAge?: number
  preflightContinue?: boolean
  optionsSuccessStatus?: number
}

export interface CertificatePinConfig {
  hostname: string
  pins: string[] // SHA256 hashes of public keys
  includeSubdomains?: boolean
  maxAge?: number
  reportUri?: string
}

export interface SecureStorageConfig {
  algorithm?: string
  keyLength?: number
  ivLength?: number
  saltLength?: number
  iterations?: number
}

// Content Security Policy
export class ContentSecurityPolicy {
  private directives: CSPDirectives

  constructor(directives: CSPDirectives = {}) {
    this.directives = {
      'default-src': ['\'self\''],
      ...directives,
    }
  }

  /**
   * Add source to directive
   */
  addSource(directive: keyof CSPDirectives, source: string): this {
    const current = this.directives[directive] as string[] | undefined
    if (Array.isArray(current)) {
      if (!current.includes(source)) {
        current.push(source)
      }
    }
else {
      (this.directives[directive] as string[]) = [source]
    }
    return this
  }

  /**
   * Remove source from directive
   */
  removeSource(directive: keyof CSPDirectives, source: string): this {
    const current = this.directives[directive] as string[] | undefined
    if (Array.isArray(current)) {
      const index = current.indexOf(source)
      if (index > -1) {
        current.splice(index, 1)
      }
    }
    return this
  }

  /**
   * Generate CSP header string
   */
  toString(): string {
    const parts: string[] = []

    for (const [directive, value] of Object.entries(this.directives)) {
      if (value === true) {
        parts.push(directive)
      }
else if (Array.isArray(value) && value.length > 0) {
        parts.push(`${directive} ${value.join(' ')}`)
      }
    }

    return parts.join('; ')
  }

  /**
   * Generate nonce for inline scripts
   */
  static generateNonce(): string {
    return randomBytes(16).toString('base64')
  }

  /**
   * Create strict CSP for production
   */
  static strict(): ContentSecurityPolicy {
    return new ContentSecurityPolicy({
      'default-src': ['\'self\''],
      'script-src': ['\'self\''],
      'style-src': ['\'self\'', '\'unsafe-inline\''],
      'img-src': ['\'self\'', 'data:', 'https:'],
      'font-src': ['\'self\''],
      'connect-src': ['\'self\''],
      'object-src': ['\'none\''],
      'frame-ancestors': ['\'none\''],
      'base-uri': ['\'self\''],
      'form-action': ['\'self\''],
      'upgrade-insecure-requests': true,
      'block-all-mixed-content': true,
    })
  }

  /**
   * Create relaxed CSP for development
   */
  static development(): ContentSecurityPolicy {
    return new ContentSecurityPolicy({
      'default-src': ['\'self\'', '\'unsafe-inline\'', '\'unsafe-eval\''],
      'script-src': ['\'self\'', '\'unsafe-inline\'', '\'unsafe-eval\''],
      'style-src': ['\'self\'', '\'unsafe-inline\''],
      'img-src': ['\'self\'', 'data:', 'blob:', '*'],
      'connect-src': ['\'self\'', 'ws:', 'wss:', '*'],
    })
  }
}

// CORS Handler
export class CORSHandler {
  private config: CORSConfig

  constructor(config: CORSConfig = {}) {
    this.config = {
      origin: true,
      methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE'],
      allowedHeaders: ['Content-Type', 'Authorization'],
      credentials: false,
      maxAge: 86400,
      optionsSuccessStatus: 204,
      ...config,
    }
  }

  /**
   * Get CORS headers for a request
   */
  getHeaders(requestOrigin?: string): Record<string, string> {
    const headers: Record<string, string> = {}

    // Origin
    const origin = this.getAllowedOrigin(requestOrigin)
    if (origin) {
      headers['Access-Control-Allow-Origin'] = origin
    }

    // Credentials
    if (this.config.credentials) {
      headers['Access-Control-Allow-Credentials'] = 'true'
    }

    // Exposed headers
    if (this.config.exposedHeaders?.length) {
      headers['Access-Control-Expose-Headers'] = this.config.exposedHeaders.join(', ')
    }

    return headers
  }

  /**
   * Get preflight headers
   */
  getPreflightHeaders(requestOrigin?: string): Record<string, string> {
    const headers = this.getHeaders(requestOrigin)

    // Methods
    if (this.config.methods?.length) {
      headers['Access-Control-Allow-Methods'] = this.config.methods.join(', ')
    }

    // Allowed headers
    if (this.config.allowedHeaders?.length) {
      headers['Access-Control-Allow-Headers'] = this.config.allowedHeaders.join(', ')
    }

    // Max age
    if (this.config.maxAge) {
      headers['Access-Control-Max-Age'] = String(this.config.maxAge)
    }

    return headers
  }

  private getAllowedOrigin(requestOrigin?: string): string | null {
    const { origin } = this.config

    if (origin === true) {
      return requestOrigin || '*'
    }

    if (origin === false) {
      return null
    }

    if (typeof origin === 'string') {
      return origin
    }

    if (Array.isArray(origin)) {
      if (requestOrigin && origin.includes(requestOrigin)) {
        return requestOrigin
      }
      return null
    }

    if (typeof origin === 'function') {
      return origin(requestOrigin || '') ? requestOrigin || '*' : null
    }

    return null
  }
}

// Certificate Pinning
export class CertificatePinner {
  private pins: Map<string, CertificatePinConfig> = new Map()

  /**
   * Add certificate pin
   */
  addPin(config: CertificatePinConfig): void {
    this.pins.set(config.hostname, config)
  }

  /**
   * Remove certificate pin
   */
  removePin(hostname: string): void {
    this.pins.delete(hostname)
  }

  /**
   * Verify certificate
   */
  verify(hostname: string, publicKey: Buffer): boolean {
    const config = this.pins.get(hostname)
    if (!config) return true // No pin configured

    const hash = createHash('sha256').update(publicKey).digest('base64')
    return config.pins.includes(hash)
  }

  /**
   * Generate HTTP Public Key Pinning header
   */
  getHPKPHeader(hostname: string): string | null {
    const config = this.pins.get(hostname)
    if (!config) return null

    const pinDirectives = config.pins.map((pin) => `pin-sha256='${pin}'`).join('; ')
    const maxAge = `max-age=${config.maxAge || 5184000}` // Default 60 days

    let header = `${pinDirectives}; ${maxAge}`

    if (config.includeSubdomains) {
      header += '; includeSubDomains'
    }

    if (config.reportUri) {
      header += `; report-uri='${config.reportUri}'`
    }

    return header
  }

  /**
   * Calculate pin from public key
   */
  static calculatePin(publicKey: Buffer): string {
    return createHash('sha256').update(publicKey).digest('base64')
  }
}

// Secure Storage
export class SecureStorage {
  private config: Required<Omit<SecureStorageConfig, 'salt'>> & { salt: Buffer }
  private key: Buffer

  constructor(masterPassword: string, config: SecureStorageConfig & { salt?: Buffer } = {}) {
    // Salt must be provided by the caller and stored persistently alongside the
    // ciphertext. Using a hardcoded salt defeats the purpose of PBKDF2.
    const salt = config.salt ?? randomBytes(32)
    this.config = {
      algorithm: 'aes-256-gcm',
      keyLength: 32,
      ivLength: 16,
      saltLength: salt.length,
      iterations: 100000,
      salt,
      ...config,
    }

    // Derive key from password using the provided (or freshly-generated) salt
    this.key = pbkdf2Sync(
      masterPassword,
      this.config.salt,
      this.config.iterations,
      this.config.keyLength,
      'sha512'
    )
  }

  /**
   * Encrypt data
   */
  encrypt(data: string): string {
    const iv = randomBytes(this.config.ivLength)
    const cipher = createCipheriv(this.config.algorithm, this.key, iv)

    let encrypted = cipher.update(data, 'utf8', 'hex')
    encrypted += cipher.final('hex')

    const authTag = 'getAuthTag' in cipher ? (cipher as { getAuthTag(): Buffer }).getAuthTag() : Buffer.alloc(0)

    return JSON.stringify({
      iv: iv.toString('hex'),
      data: encrypted,
      tag: authTag.toString('hex'),
    })
  }

  /**
   * Decrypt data
   */
  decrypt(encrypted: string): string {
    const { iv, data, tag } = JSON.parse(encrypted)

    const decipher = createDecipheriv(
      this.config.algorithm,
      this.key,
      Buffer.from(iv, 'hex')
    )

    if ('setAuthTag' in decipher) {
      (decipher as { setAuthTag(tag: Buffer): void }).setAuthTag(Buffer.from(tag, 'hex'))
    }

    let decrypted = decipher.update(data, 'hex', 'utf8')
    decrypted += decipher.final('utf8')

    return decrypted
  }

  /**
   * Hash data (one-way)
   */
  hash(data: string): string {
    return createHash('sha256').update(data + this.key.toString('hex')).digest('hex')
  }

  /**
   * Get the salt used for key derivation.
   * Callers MUST persist this salt alongside ciphertext so that the same key
   * can be re-derived on the next run.
   */
  getSalt(): Buffer {
    return Buffer.from(this.config.salt)
  }
}

// Input Validation
export const validators = {
  /**
   * Validate email
   */
  email: (value: string): boolean => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return emailRegex.test(value)
  },

  /**
   * Validate URL
   */
  url: (value: string): boolean => {
    try {
      new URL(value)
      return true
    }
catch {
      return false
    }
  },

  /**
   * Validate UUID
   */
  uuid: (value: string): boolean => {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    return uuidRegex.test(value)
  },

  /**
   * Validate integer
   */
  integer: (value: string | number): boolean => {
    return Number.isInteger(Number(value))
  },

  /**
   * Validate range
   */
  range:
    (min: number, max: number) =>
    (value: number): boolean => {
      return value >= min && value <= max
    },

  /**
   * Validate length
   */
  length:
    (min: number, max?: number) =>
    (value: string): boolean => {
      return value.length >= min && (max === undefined || value.length <= max)
    },

  /**
   * Validate alphanumeric
   */
  alphanumeric: (value: string): boolean => {
    return /^[a-zA-Z0-9]+$/.test(value)
  },

  /**
   * Validate no script tags (basic XSS prevention).
   * Catches full/partial script tags and javascript: URLs. For full XSS
   * protection always prefer contextual escaping (escapeHtml) and a strict CSP.
   */
  noScript: (value: string): boolean => {
    // Any <script, whether complete or partial — attackers don't need a closing tag
    if (/<\s*script\b/i.test(value)) return false
    // javascript:, data:, vbscript: and event handlers are common XSS vectors
    if (/\b(?:javascript|vbscript|data)\s*:/i.test(value)) return false
    if (/\son\w+\s*=/i.test(value)) return false
    return true
  },

  /**
   * Validate no SQL injection patterns
   */
  noSqlInjection: (value: string): boolean => {
    const patterns = [
      /(\%27)|(\')|(\-\-)|(\%23)|(#)/i,
      /((\%3D)|(=))[^\n]*((\%27)|(\')|(\-\-)|(\%3B)|(;))/i,
      /\w*((\%27)|(\'))((\%6F)|o|(\%4F))((\%72)|r|(\%52))/i,
    ]
    return !patterns.some((p) => p.test(value))
  },
}

// Sanitizers
export const sanitizers = {
  /**
   * Escape HTML
   */
  escapeHtml: (value: string): string => {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#x27;')
  },

  /**
   * Strip HTML tags
   */
  stripHtml: (value: string): string => {
    return value.replace(/<[^>]*>/g, '')
  },

  /**
   * Normalize whitespace
   */
  normalizeWhitespace: (value: string): string => {
    return value.replace(/\s+/g, ' ').trim()
  },

  /**
   * Remove non-printable characters
   */
  removeNonPrintable: (value: string): string => {
    return value.replace(/[^\x20-\x7E]/g, '')
  },

  /**
   * Escape SQL (basic - prefer parameterized queries)
   */
  escapeSql: (value: string): string => {
    return value.replace(/'/g, '\'\'').replace(/\\/g, '\\\\')
  },
}

// Rate Limiter
export class RateLimiter {
  private requests: Map<string, number[]> = new Map()

  constructor(
    private windowMs: number = 60000,
    private maxRequests: number = 100
  ) {}

  /**
   * Check if request is allowed
   */
  isAllowed(key: string): boolean {
    const now = Date.now()
    const windowStart = now - this.windowMs

    // Get existing requests
    let timestamps = this.requests.get(key) || []

    // Remove old requests
    timestamps = timestamps.filter((t) => t > windowStart)

    // Check limit
    if (timestamps.length >= this.maxRequests) {
      // Persist pruned list so stale timestamps don't accumulate on rejected
      // keys, but still signal rejection to the caller.
      this.requests.set(key, timestamps)
      return false
    }

    // Add current request
    timestamps.push(now)
    this.requests.set(key, timestamps)

    // Periodically garbage-collect keys whose windows have fully elapsed.
    // Without this, inactive keys would leak memory indefinitely.
    if (this.requests.size > 1024 && Math.random() < 0.01) {
      for (const [k, ts] of this.requests) {
        const pruned = ts.filter((t) => t > windowStart)
        if (pruned.length === 0) this.requests.delete(k)
        else if (pruned.length !== ts.length) this.requests.set(k, pruned)
      }
    }

    return true
  }

  /**
   * Get remaining requests
   */
  getRemaining(key: string): number {
    const now = Date.now()
    const windowStart = now - this.windowMs
    const timestamps = (this.requests.get(key) || []).filter((t) => t > windowStart)
    return Math.max(0, this.maxRequests - timestamps.length)
  }

  /**
   * Reset limit for key
   */
  reset(key: string): void {
    this.requests.delete(key)
  }
}

const _exports: {
  ContentSecurityPolicy: typeof ContentSecurityPolicy;
  CORSHandler: typeof CORSHandler;
  CertificatePinner: typeof CertificatePinner;
  SecureStorage: typeof SecureStorage;
  validators: typeof validators;
  sanitizers: typeof sanitizers;
  RateLimiter: typeof RateLimiter;
} = {
  ContentSecurityPolicy,
  CORSHandler,
  CertificatePinner,
  SecureStorage,
  validators,
  sanitizers,
  RateLimiter,
};
export default _exports;
