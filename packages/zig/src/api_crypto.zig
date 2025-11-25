const std = @import("std");

/// Crypto API
/// Cryptographic operations

pub const Crypto = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Crypto {
        return .{ .allocator = allocator };
    }

    /// Generate random bytes
    pub fn randomBytes(self: *Crypto, len: usize) ![]u8 {
        const bytes = try self.allocator.alloc(u8, len);
        std.crypto.random.bytes(bytes);
        return bytes;
    }

    /// Hash data using SHA-256
    pub fn sha256(self: *Crypto, data: []const u8) ![32]u8 {
        _ = self;
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
        return hash;
    }

    /// Hash data using SHA-512
    pub fn sha512(self: *Crypto, data: []const u8) ![64]u8 {
        _ = self;
        var hash: [64]u8 = undefined;
        std.crypto.hash.sha2.Sha512.hash(data, &hash, .{});
        return hash;
    }

    /// Hash data using Blake3
    pub fn blake3(self: *Crypto, data: []const u8) ![32]u8 {
        _ = self;
        var hash: [32]u8 = undefined;
        std.crypto.hash.Blake3.hash(data, &hash, .{});
        return hash;
    }

    /// HMAC-SHA256
    pub fn hmacSha256(self: *Crypto, key: []const u8, data: []const u8) ![32]u8 {
        _ = self;
        var mac: [32]u8 = undefined;
        std.crypto.auth.hmac.sha2.HmacSha256.create(&mac, data, key);
        return mac;
    }

    /// Encrypt data using AES-256-GCM
    pub fn encryptAesGcm(self: *Crypto, key: [32]u8, nonce: [12]u8, data: []const u8, ad: []const u8) ![]u8 {
        const ciphertext = try self.allocator.alloc(u8, data.len + 16); // +16 for tag
        errdefer self.allocator.free(ciphertext);

        std.crypto.aead.aes_gcm.Aes256Gcm.encrypt(
            ciphertext[0..data.len],
            ciphertext[data.len..][0..16],
            data,
            ad,
            nonce,
            key,
        );

        return ciphertext;
    }

    /// Decrypt data using AES-256-GCM
    pub fn decryptAesGcm(self: *Crypto, key: [32]u8, nonce: [12]u8, ciphertext: []const u8, ad: []const u8) ![]u8 {
        if (ciphertext.len < 16) return error.InvalidCiphertext;

        const data_len = ciphertext.len - 16;
        const plaintext = try self.allocator.alloc(u8, data_len);
        errdefer self.allocator.free(plaintext);

        try std.crypto.aead.aes_gcm.Aes256Gcm.decrypt(
            plaintext,
            ciphertext[0..data_len],
            ciphertext[data_len..][0..16].*,
            ad,
            nonce,
            key,
        );

        return plaintext;
    }

    /// Generate key pair for X25519 key exchange
    pub fn generateX25519KeyPair(self: *Crypto) !KeyPair {
        _ = self;
        const seed = std.crypto.random.bytes([32]u8{});
        const kp = try std.crypto.dh.X25519.KeyPair.create(seed);

        return KeyPair{
            .public_key = kp.public_key,
            .secret_key = kp.secret_key,
        };
    }

    /// Perform X25519 key exchange
    pub fn x25519(self: *Crypto, secret_key: [32]u8, public_key: [32]u8) ![32]u8 {
        _ = self;
        return try std.crypto.dh.X25519.scalarmult(secret_key, public_key);
    }

    /// Sign data using Ed25519
    pub fn signEd25519(self: *Crypto, secret_key: [64]u8, data: []const u8) ![64]u8 {
        _ = self;
        const kp = std.crypto.sign.Ed25519.KeyPair{ .secret_key = secret_key, .public_key = secret_key[32..64].* };
        return try kp.sign(data, null);
    }

    /// Verify Ed25519 signature
    pub fn verifyEd25519(self: *Crypto, public_key: [32]u8, data: []const u8, signature: [64]u8) !bool {
        _ = self;
        std.crypto.sign.Ed25519.verify(signature, data, public_key) catch return false;
        return true;
    }

    /// Password hashing using Argon2
    pub fn hashPassword(self: *Crypto, password: []const u8, salt: [16]u8) ![32]u8 {
        var hash: [32]u8 = undefined;
        try std.crypto.pwhash.argon2.kdf(
            self.allocator,
            &hash,
            password,
            &salt,
            .{ .t = 3, .m = 4096, .p = 1 },
            .argon2id,
        );
        return hash;
    }

    /// Verify password against hash
    pub fn verifyPassword(self: *Crypto, password: []const u8, salt: [16]u8, expected_hash: [32]u8) !bool {
        const computed_hash = try self.hashPassword(password, salt);
        return std.mem.eql(u8, &computed_hash, &expected_hash);
    }
};

pub const KeyPair = struct {
    public_key: [32]u8,
    secret_key: [32]u8,
};

// Tests
test "Crypto init" {
    const allocator = std.testing.allocator;
    const crypto = Crypto.init(allocator);
    _ = crypto;
}

test "Random bytes generation" {
    const allocator = std.testing.allocator;
    var crypto = Crypto.init(allocator);

    const bytes = try crypto.randomBytes(32);
    defer allocator.free(bytes);

    try std.testing.expect(bytes.len == 32);
}

test "SHA-256 hashing" {
    const allocator = std.testing.allocator;
    var crypto = Crypto.init(allocator);

    const hash = try crypto.sha256("Hello, World!");

    // Verify it's not all zeros
    var all_zeros = true;
    for (hash) |byte| {
        if (byte != 0) {
            all_zeros = false;
            break;
        }
    }
    try std.testing.expect(!all_zeros);
}
