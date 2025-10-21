const std = @import("std");

/// Cryptography utilities for plugin signing and verification
/// Uses Ed25519 for digital signatures

pub const Crypto = struct {
    pub const Ed25519 = std.crypto.sign.Ed25519;
    pub const KeyPair = Ed25519.KeyPair;
    pub const PublicKey = Ed25519.PublicKey;
    pub const SecretKey = Ed25519.SecretKey;
    pub const Signature = Ed25519.Signature;

    /// Generate a new Ed25519 keypair
    pub fn generateKeyPair() !KeyPair {
        var seed: [Ed25519.seed_length]u8 = undefined;
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
};

test "generate keypair" {
    const keypair = try Crypto.generateKeyPair();
    try std.testing.expect(keypair.public_key.bytes.len == 32);
    try std.testing.expect(keypair.secret_key.bytes.len == 64);
}

test "sign and verify" {
    const keypair = try Crypto.generateKeyPair();
    const data = "Hello, Zyte!";

    const signature = try Crypto.sign(data, keypair.secret_key);
    try Crypto.verify(signature, data, keypair.public_key);
}

test "verify fails with wrong data" {
    const keypair = try Crypto.generateKeyPair();
    const data = "Hello, Zyte!";
    const wrong_data = "Wrong data";

    const signature = try Crypto.sign(data, keypair.secret_key);
    try std.testing.expectError(error.SignatureVerificationFailed, Crypto.verify(signature, wrong_data, keypair.public_key));
}

test "verify fails with wrong public key" {
    const keypair1 = try Crypto.generateKeyPair();
    const keypair2 = try Crypto.generateKeyPair();
    const data = "Hello, Zyte!";

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
