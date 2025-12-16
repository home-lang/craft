const std = @import("std");
const crypto = std.crypto;

/// Cryptography utilities for plugin signing, verification, and general crypto operations
/// Uses Ed25519 for digital signatures plus AES, ChaCha20, hashing, etc.
pub const Crypto = struct {
    pub const Ed25519 = std.crypto.sign.Ed25519;
    pub const KeyPair = Ed25519.KeyPair;
    pub const PublicKey = Ed25519.PublicKey;
    pub const SecretKey = Ed25519.SecretKey;
    pub const Signature = Ed25519.Signature;

    /// Generate a new Ed25519 keypair
    pub fn generateKeyPair() !KeyPair {
        var seed: [32]u8 = undefined; // Ed25519 seed is 32 bytes
        std.crypto.random.bytes(&seed);
        return try Ed25519.KeyPair.create(seed);
    }

    /// Sign data with a secret key
    pub fn sign(data: []const u8, secret_key: SecretKey) !Signature {
        return try Ed25519.sign(data, Ed25519.KeyPair{
            .secret_key = secret_key,
            .public_key = try secret_key.publicKey(),
        }, null);
    }

    /// Verify a signature with a public key
    pub fn verify(signature: Signature, data: []const u8, public_key: PublicKey) !void {
        try Ed25519.verify(signature, data, public_key);
    }

    /// Encode public key to hex string
    pub fn publicKeyToHex(public_key: PublicKey, allocator: std.mem.Allocator) ![]u8 {
        return try std.fmt.allocPrint(allocator, "{}", .{std.fmt.fmtSliceHexLower(&public_key.bytes)});
    }

    /// Decode public key from hex string
    pub fn publicKeyFromHex(hex: []const u8) !PublicKey {
        if (hex.len != Ed25519.PublicKey.encoded_length * 2) {
            return error.InvalidPublicKeyLength;
        }
        var bytes: [Ed25519.PublicKey.encoded_length]u8 = undefined;
        _ = try std.fmt.hexToBytes(&bytes, hex);
        return PublicKey.fromBytes(bytes);
    }

    /// Encode signature to hex string
    pub fn signatureToHex(signature: Signature, allocator: std.mem.Allocator) ![]u8 {
        return try std.fmt.allocPrint(allocator, "{}", .{std.fmt.fmtSliceHexLower(&signature.toBytes())});
    }

    /// Decode signature from hex string
    pub fn signatureFromHex(hex: []const u8) !Signature {
        if (hex.len != Ed25519.Signature.encoded_length * 2) {
            return error.InvalidSignatureLength;
        }
        var bytes: [Ed25519.Signature.encoded_length]u8 = undefined;
        _ = try std.fmt.hexToBytes(&bytes, hex);
        return Signature.fromBytes(bytes);
    }

    /// Hash data using Blake3
    pub fn hash(data: []const u8, out: []u8) void {
        std.crypto.hash.Blake3.hash(data, out, .{});
    }

    /// Compute SHA256 hash
    pub fn sha256(data: []const u8, out: *[32]u8) void {
        std.crypto.hash.sha2.Sha256.hash(data, out, .{});
    }

    /// Generate random bytes
    pub fn randomBytes(allocator: std.mem.Allocator, length: usize) ![]u8 {
        const bytes = try allocator.alloc(u8, length);
        crypto.random.bytes(bytes);
        return bytes;
    }

    /// Encrypt data using AES-256-GCM
    pub fn encryptAES256GCM(allocator: std.mem.Allocator, plaintext: []const u8, key: [32]u8) ![]u8 {
        // Generate random nonce
        var nonce: [12]u8 = undefined;
        crypto.random.bytes(&nonce);

        // Allocate buffer for nonce + ciphertext + tag
        const result = try allocator.alloc(u8, 12 + plaintext.len + 16);
        @memcpy(result[0..12], &nonce);

        // Encrypt
        var tag: [16]u8 = undefined;
        crypto.aead.aes_gcm.Aes256Gcm.encrypt(
            result[12 .. 12 + plaintext.len],
            &tag,
            plaintext,
            &[_]u8{},
            nonce,
            key,
        );

        @memcpy(result[12 + plaintext.len ..], &tag);
        return result;
    }

    /// Decrypt data using AES-256-GCM
    pub fn decryptAES256GCM(allocator: std.mem.Allocator, ciphertext: []const u8, key: [32]u8) ![]u8 {
        if (ciphertext.len < 28) return error.InvalidInput; // 12 + 16 minimum

        const nonce = ciphertext[0..12];
        const tag_offset = ciphertext.len - 16;
        var tag: [16]u8 = undefined;
        @memcpy(&tag, ciphertext[tag_offset..]);

        const plaintext = try allocator.alloc(u8, ciphertext.len - 28);
        crypto.aead.aes_gcm.Aes256Gcm.decrypt(
            plaintext,
            ciphertext[12..tag_offset],
            tag,
            &[_]u8{},
            nonce.*,
            key,
        ) catch {
            allocator.free(plaintext);
            return error.DecryptionFailed;
        };

        return plaintext;
    }

    /// Encrypt data using ChaCha20-Poly1305
    pub fn encryptChaCha20(allocator: std.mem.Allocator, plaintext: []const u8, key: [32]u8) ![]u8 {
        var nonce: [12]u8 = undefined;
        crypto.random.bytes(&nonce);

        const result = try allocator.alloc(u8, 12 + plaintext.len + 16);
        @memcpy(result[0..12], &nonce);

        var tag: [16]u8 = undefined;
        crypto.aead.chacha_poly.ChaCha20Poly1305.encrypt(
            result[12 .. 12 + plaintext.len],
            &tag,
            plaintext,
            &[_]u8{},
            nonce,
            key,
        );

        @memcpy(result[12 + plaintext.len ..], &tag);
        return result;
    }

    /// Decrypt data using ChaCha20-Poly1305
    pub fn decryptChaCha20(allocator: std.mem.Allocator, ciphertext: []const u8, key: [32]u8) ![]u8 {
        if (ciphertext.len < 28) return error.InvalidInput;

        const nonce = ciphertext[0..12];
        const tag_offset = ciphertext.len - 16;
        var tag: [16]u8 = undefined;
        @memcpy(&tag, ciphertext[tag_offset..]);

        const plaintext = try allocator.alloc(u8, ciphertext.len - 28);
        crypto.aead.chacha_poly.ChaCha20Poly1305.decrypt(
            plaintext,
            ciphertext[12..tag_offset],
            tag,
            &[_]u8{},
            nonce.*,
            key,
        ) catch {
            allocator.free(plaintext);
            return error.DecryptionFailed;
        };

        return plaintext;
    }

    /// Derive key from password using Argon2
    pub fn deriveKey(allocator: std.mem.Allocator, password: []const u8, salt: []const u8) ![32]u8 {
        var key: [32]u8 = undefined;
        try crypto.pwhash.argon2.kdf(
            allocator,
            &key,
            password,
            salt,
            .{ .t = 3, .m = 65536, .p = 1 },
            .argon2id,
        );
        return key;
    }

    /// Generate HMAC-SHA256
    pub fn hmacSHA256(key: []const u8, message: []const u8, out: *[32]u8) void {
        var hmac_impl = crypto.auth.hmac.sha2.HmacSha256.init(key);
        hmac_impl.update(message);
        hmac_impl.final(out);
    }

    /// Convert bytes to hex string
    pub fn toHex(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
        return try std.fmt.allocPrint(allocator, "{}", .{std.fmt.fmtSliceHexLower(bytes)});
    }

    /// Convert hex string to bytes
    pub fn fromHex(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
        if (hex.len % 2 != 0) return error.InvalidInput;
        const bytes = try allocator.alloc(u8, hex.len / 2);
        _ = try std.fmt.hexToBytes(bytes, hex);
        return bytes;
    }
};

test "generate keypair" {
    const keypair = try Crypto.generateKeyPair();
    try std.testing.expect(keypair.public_key.bytes.len == 32);
    try std.testing.expect(keypair.secret_key.bytes.len == 64);
}

test "sign and verify" {
    const keypair = try Crypto.generateKeyPair();
    const data = "Hello, Craft!";

    const signature = try Crypto.sign(data, keypair.secret_key);
    try Crypto.verify(signature, data, keypair.public_key);
}

test "verify fails with wrong data" {
    const keypair = try Crypto.generateKeyPair();
    const data = "Hello, Craft!";
    const wrong_data = "Wrong data";

    const signature = try Crypto.sign(data, keypair.secret_key);
    try std.testing.expectError(error.SignatureVerificationFailed, Crypto.verify(signature, wrong_data, keypair.public_key));
}

test "verify fails with wrong public key" {
    const keypair1 = try Crypto.generateKeyPair();
    const keypair2 = try Crypto.generateKeyPair();
    const data = "Hello, Craft!";

    const signature = try Crypto.sign(data, keypair1.secret_key);
    try std.testing.expectError(error.SignatureVerificationFailed, Crypto.verify(signature, data, keypair2.public_key));
}

test "public key hex encoding" {
    const allocator = std.testing.allocator;
    const keypair = try Crypto.generateKeyPair();

    const hex = try Crypto.publicKeyToHex(keypair.public_key, allocator);
    defer allocator.free(hex);

    try std.testing.expect(hex.len == 64); // 32 bytes * 2 hex chars

    const decoded = try Crypto.publicKeyFromHex(hex);
    try std.testing.expectEqualSlices(u8, &keypair.public_key.bytes, &decoded.bytes);
}

test "signature hex encoding" {
    const allocator = std.testing.allocator;
    const keypair = try Crypto.generateKeyPair();
    const data = "Test data";

    const signature = try Crypto.sign(data, keypair.secret_key);
    const hex = try Crypto.signatureToHex(signature, allocator);
    defer allocator.free(hex);

    try std.testing.expect(hex.len == 128); // 64 bytes * 2 hex chars

    const decoded = try Crypto.signatureFromHex(hex);
    try std.testing.expectEqualSlices(u8, &signature.toBytes(), &decoded.toBytes());
}

test "blake3 hash" {
    const data = "Test data for hashing";
    var hash1: [32]u8 = undefined;
    var hash2: [32]u8 = undefined;

    Crypto.hash(data, &hash1);
    Crypto.hash(data, &hash2);

    try std.testing.expectEqualSlices(u8, &hash1, &hash2);
}

test "sha256 hash" {
    const data = "Test data";
    var hash: [32]u8 = undefined;
    Crypto.sha256(data, &hash);

    try std.testing.expect(hash.len == 32);
}
