//! The owned, copy-only persistent JavaScript host contract.
pub const Error = error{
    OutOfMemory,
    Unavailable,
    Throw,
    Parse,
    Engine,
    Closed,
    InvalidHandle,
    WrongThread,
    UnsupportedHostMode,
    InvalidString,
    InvalidBuffer,
    OutOfBounds,
    Terminated,
    LimitExceeded,
    WrongType,
};

pub const TypedArrayKind = enum { i8, u8, u8_clamped, i16, u16, i32, u32, f16, f32, f64, bigint64, biguint64 };
pub const Kind = enum { undefined, null, boolean, number, string, object };
pub const Value = union(enum) {
    undefined,
    null,
    boolean: bool,
    number: f64,
    string: []const u8,
    typed_array: struct { kind: TypedArrayKind, bytes: []const u8 },
};

/// Handles are checked for runtime identity and slot generation on every use.
/// They own no host pointer and become invalid on release or runtime disposal.
pub const Handle = struct { runtime: u64, slot: u32, generation: u64 };

pub const Options = struct {
    max_handles: u32 = 1024,
    max_arguments: u32 = 64,
    max_input_bytes: usize = 16 * 1024 * 1024,
    max_output_bytes: usize = 16 * 1024 * 1024,
    heap_limit_bytes: usize = 64 * 1024 * 1024,
};
