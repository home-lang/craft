# Crypto API

The Crypto API provides cryptographic operations including hashing, encryption, and random number generation.

## Import

```typescript
import { crypto } from 'ts-craft'
```

## Methods

### crypto.randomBytes(length)

Generate cryptographically secure random bytes.

```typescript
const bytes = await crypto.randomBytes(32)
// Returns: Uint8Array of 32 random bytes
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| length | `number` | Number of bytes to generate |

**Returns:** `Promise<Uint8Array>`

---

### crypto.randomUUID()

Generate a cryptographically secure UUID v4.

```typescript
const uuid = await crypto.randomUUID()
// Returns: "550e8400-e29b-41d4-a716-446655440000"
```

**Returns:** `Promise<string>`

---

### crypto.hash(algorithm, data)

Compute a hash digest.

```typescript
const hash = await crypto.hash('sha256', 'Hello, World!')
// Returns: "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f"

const hash = await crypto.hash('sha512', new Uint8Array([1, 2, 3]))
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| algorithm | `'sha256' \| 'sha384' \| 'sha512' \| 'md5'` | Hash algorithm |
| data | `string \| Uint8Array` | Data to hash |

**Returns:** `Promise<string>` - Hex-encoded hash

---

### crypto.encrypt(key, data, options?)

Encrypt data using AES-256-GCM.

```typescript
const key = await crypto.randomBytes(32) // 256-bit key

const encrypted = await crypto.encrypt(key, 'Secret message')
// Returns: { ciphertext: Uint8Array, iv: Uint8Array, tag: Uint8Array }

// Store all three values - needed for decryption
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| key | `Uint8Array` | 32-byte encryption key |
| data | `string \| Uint8Array` | Data to encrypt |
| options.iv | `Uint8Array` | Initialization vector (auto-generated if omitted) |

**Returns:** `Promise<EncryptedData>`

---

### crypto.decrypt(key, encrypted)

Decrypt data encrypted with `crypto.encrypt`.

```typescript
const decrypted = await crypto.decrypt(key, encrypted)
// Returns: Uint8Array

const text = new TextDecoder().decode(decrypted)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| key | `Uint8Array` | 32-byte encryption key |
| encrypted | `EncryptedData` | Encrypted data object |

**Returns:** `Promise<Uint8Array>`

---

### crypto.deriveKey(password, salt, options?)

Derive a key from a password using PBKDF2.

```typescript
const salt = await crypto.randomBytes(16)

const key = await crypto.deriveKey('user-password', salt, {
  iterations: 100000,
  keyLength: 32 // 256-bit key
})
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| password | `string` | Password to derive from |
| salt | `Uint8Array` | Salt value |
| options.iterations | `number` | PBKDF2 iterations (default: 100000) |
| options.keyLength | `number` | Output key length in bytes (default: 32) |

**Returns:** `Promise<Uint8Array>`

---

### crypto.hmac(key, data, algorithm?)

Compute an HMAC.

```typescript
const key = new TextEncoder().encode('secret-key')
const signature = await crypto.hmac(key, 'Message to sign')
// Returns: hex-encoded HMAC
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| key | `Uint8Array` | HMAC key |
| data | `string \| Uint8Array` | Data to sign |
| algorithm | `'sha256' \| 'sha384' \| 'sha512'` | Hash algorithm (default: 'sha256') |

**Returns:** `Promise<string>` - Hex-encoded HMAC

## Example Usage

```typescript
import { crypto, fs } from 'ts-craft'

// Password-based encryption
async function encryptWithPassword(data: string, password: string) {
  // Generate a random salt
  const salt = await crypto.randomBytes(16)

  // Derive a key from the password
  const key = await crypto.deriveKey(password, salt, {
    iterations: 100000,
    keyLength: 32
  })

  // Encrypt the data
  const encrypted = await crypto.encrypt(key, data)

  // Return everything needed for decryption
  return {
    salt,
    iv: encrypted.iv,
    tag: encrypted.tag,
    ciphertext: encrypted.ciphertext
  }
}

async function decryptWithPassword(
  encrypted: { salt: Uint8Array; iv: Uint8Array; tag: Uint8Array; ciphertext: Uint8Array },
  password: string
) {
  // Derive the same key
  const key = await crypto.deriveKey(password, encrypted.salt, {
    iterations: 100000,
    keyLength: 32
  })

  // Decrypt
  const decrypted = await crypto.decrypt(key, {
    ciphertext: encrypted.ciphertext,
    iv: encrypted.iv,
    tag: encrypted.tag
  })

  return new TextDecoder().decode(decrypted)
}

// File integrity verification
async function hashFile(path: string): Promise<string> {
  const content = await fs.readFile(path, { encoding: 'binary' })
  return crypto.hash('sha256', content as Uint8Array)
}

async function verifyFile(path: string, expectedHash: string): Promise<boolean> {
  const actualHash = await hashFile(path)
  return actualHash === expectedHash
}

// API request signing
async function signRequest(apiKey: Uint8Array, method: string, path: string, body: string) {
  const timestamp = Date.now().toString()
  const message = `${method}:${path}:${timestamp}:${body}`

  const signature = await crypto.hmac(apiKey, message)

  return {
    'X-Timestamp': timestamp,
    'X-Signature': signature
  }
}

// Generate secure tokens
async function generateToken(): Promise<string> {
  const bytes = await crypto.randomBytes(32)
  return Array.from(bytes)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}
```

## Types

```typescript
type HashAlgorithm = 'sha256' | 'sha384' | 'sha512' | 'md5'

interface EncryptedData {
  ciphertext: Uint8Array
  iv: Uint8Array
  tag: Uint8Array
}

interface EncryptOptions {
  iv?: Uint8Array
}

interface DeriveKeyOptions {
  iterations?: number
  keyLength?: number
}
```

## Security Notes

- Always use `crypto.randomBytes()` for generating keys, IVs, and salts
- Never reuse an IV with the same key
- Use at least 100,000 iterations for PBKDF2
- Store salts alongside encrypted data (they don't need to be secret)
- Use constant-time comparison for signature verification
- Consider using `secureStorage` for storing encryption keys
