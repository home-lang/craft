//! Form Validation Module
//!
//! Provides comprehensive validation functionality for form inputs:
//! - Built-in validators (email, URL, phone, credit card, etc.)
//! - Custom regex validators
//! - Required/min/max/range rules
//! - Async validation support
//! - Error message formatting and localization
//! - Field-level and form-level validation
//!
//! Example usage:
//! ```zig
//! var validator = FormValidator.init(allocator);
//! defer validator.deinit();
//!
//! try validator.addField("email", &[_]Rule{
//!     Rules.required("Email is required"),
//!     Rules.email("Invalid email format"),
//! });
//!
//! const result = try validator.validate(.{ .email = "test@example.com" });
//! if (!result.is_valid) {
//!     for (result.errors) |err| {
//!         std.debug.print("{s}: {s}\n", .{err.field, err.message});
//!     }
//! }
//! ```

const std = @import("std");
const builtin = @import("builtin");

/// Validation error types
pub const ValidationError = error{
    InvalidField,
    RuleNotFound,
    RegexError,
    AsyncTimeout,
    OutOfMemory,
};

/// Single validation error for a field
pub const FieldError = struct {
    field: []const u8,
    message: []const u8,
    rule: []const u8,
    value: ?[]const u8 = null,
};

/// Result of validation
pub const ValidationResult = struct {
    is_valid: bool,
    errors: []const FieldError,
    field_errors: std.StringHashMapUnmanaged([]const FieldError),

    pub fn getFieldErrors(self: *const ValidationResult, field: []const u8) ?[]const FieldError {
        return self.field_errors.get(field);
    }

    pub fn hasFieldError(self: *const ValidationResult, field: []const u8) bool {
        return self.field_errors.contains(field);
    }

    pub fn getFirstError(self: *const ValidationResult) ?FieldError {
        if (self.errors.len > 0) {
            return self.errors[0];
        }
        return null;
    }
};

/// Validation rule function type
pub const RuleFn = *const fn (value: ?[]const u8, params: ?*const anyopaque) RuleResult;

/// Result from a single rule check
pub const RuleResult = struct {
    is_valid: bool,
    message: ?[]const u8 = null,
};

/// Validation rule.
///
/// `inline_usize` / `inline_f64` / `inline_bytes` live directly inside the
/// struct so rules like `minLength`/`exactLength`/`min`/`max` no longer need
/// to take the address of a stack-local param struct (the previous approach
/// was use-after-return: the caller returned a `Rule` whose `.params`
/// pointed into the dead stack frame). The `params` opaque pointer is kept
/// for backwards compatibility with external rules that already manage
/// their own stable storage.
pub const Rule = struct {
    name: []const u8,
    validate: RuleFn,
    message: []const u8,
    params: ?*const anyopaque = null,
    inline_usize: usize = 0,
    inline_f64: f64 = 0,
    inline_f64_b: f64 = 0,
    /// Inline string used by `equals`, `contains`, etc. so they don't need
    /// a separate heap allocation or external params pointer.
    inline_bytes: []const u8 = "",
    /// Inline list of strings used by `inList` and `notInList`. These borrow
    /// whatever backing store the caller provided — the slice header is
    /// copied into the Rule, the underlying array must outlive the Rule.
    inline_list: []const []const u8 = &.{},
    /// Bitflags used by validators with several boolean options (e.g.
    /// `password`). Definition of each bit is up to the validator.
    inline_flags: u32 = 0,

    pub fn check(self: *const Rule, value: ?[]const u8) RuleResult {
        const result = self.validate(value, @as(?*const anyopaque, @ptrCast(self)));
        return .{
            .is_valid = result.is_valid,
            .message = result.message orelse self.message,
        };
    }
};

/// Built-in validation rules
pub const Rules = struct {
    /// Required field - must not be empty
    pub fn required(message: []const u8) Rule {
        return .{
            .name = "required",
            .validate = requiredFn,
            .message = message,
        };
    }

    fn requiredFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        if (value) |v| {
            const trimmed = std.mem.trim(u8, v, " \t\n\r");
            return .{ .is_valid = trimmed.len > 0 };
        }
        return .{ .is_valid = false };
    }

    /// Email validation
    pub fn email(message: []const u8) Rule {
        return .{
            .name = "email",
            .validate = emailFn,
            .message = message,
        };
    }

    fn emailFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true }; // Empty is valid (use required for mandatory)
        if (v.len == 0) return .{ .is_valid = true };

        // Basic email validation: contains @ and at least one . after @
        const at_pos = std.mem.indexOf(u8, v, "@") orelse return .{ .is_valid = false };
        if (at_pos == 0) return .{ .is_valid = false }; // @ can't be first
        if (at_pos >= v.len - 1) return .{ .is_valid = false }; // @ can't be last

        // Reject multiple `@` (each half of the address must have exactly one).
        if (std.mem.indexOfScalarPos(u8, v, at_pos + 1, '@') != null) return .{ .is_valid = false };

        const after_at = v[at_pos + 1 ..];
        const dot_pos = std.mem.indexOf(u8, after_at, ".") orelse return .{ .is_valid = false };
        if (dot_pos == 0) return .{ .is_valid = false }; // . can't be right after @
        if (dot_pos >= after_at.len - 1) return .{ .is_valid = false }; // . can't be last

        // TLD must be at least 2 chars (RFC-compliant TLDs are 2+), and no
        // consecutive dots are allowed anywhere. The previous version
        // accepted `a@b..c` and `a@b.c` where `c` was a single character.
        if (std.mem.indexOf(u8, v, "..") != null) return .{ .is_valid = false };
        const last_dot = std.mem.lastIndexOfScalar(u8, after_at, '.').?;
        if (after_at.len - last_dot - 1 < 2) return .{ .is_valid = false };

        // Check for invalid characters
        for (v) |c| {
            if (c == ' ' or c == '\t' or c == '\n') return .{ .is_valid = false };
        }

        return .{ .is_valid = true };
    }

    /// URL validation
    pub fn url(message: []const u8) Rule {
        return .{
            .name = "url",
            .validate = urlFn,
            .message = message,
        };
    }

    fn urlFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        // Check for valid URL schemes
        const valid_schemes = [_][]const u8{ "http://", "https://", "ftp://", "ftps://" };
        var has_valid_scheme = false;
        for (valid_schemes) |scheme| {
            if (std.mem.startsWith(u8, v, scheme)) {
                has_valid_scheme = true;
                break;
            }
        }

        if (!has_valid_scheme) return .{ .is_valid = false };

        // Check for at least one . in the domain
        const scheme_end = std.mem.indexOf(u8, v, "://").? + 3;
        if (scheme_end >= v.len) return .{ .is_valid = false };

        const rest = v[scheme_end..];
        if (std.mem.indexOf(u8, rest, ".") == null) return .{ .is_valid = false };

        return .{ .is_valid = true };
    }

    /// Minimum length validation
    pub fn minLength(min_len: usize, message: []const u8) Rule {
        return .{
            .name = "minLength",
            .validate = minLengthFn,
            .message = message,
            .inline_usize = min_len,
        };
    }

    fn minLengthFn(value: ?[]const u8, params: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        if (params) |p| {
            const rule: *const Rule = @ptrCast(@alignCast(p));
            return .{ .is_valid = v.len >= rule.inline_usize };
        }
        return .{ .is_valid = true };
    }

    /// Maximum length validation
    pub fn maxLength(max_len: usize, message: []const u8) Rule {
        return .{
            .name = "maxLength",
            .validate = maxLengthFn,
            .message = message,
            .inline_usize = max_len,
        };
    }

    fn maxLengthFn(value: ?[]const u8, params: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };

        if (params) |p| {
            const rule: *const Rule = @ptrCast(@alignCast(p));
            return .{ .is_valid = v.len <= rule.inline_usize };
        }
        return .{ .is_valid = true };
    }

    /// Exact length validation
    pub fn exactLength(length: usize, message: []const u8) Rule {
        return .{
            .name = "exactLength",
            .validate = exactLengthFn,
            .message = message,
            .inline_usize = length,
        };
    }

    fn exactLengthFn(value: ?[]const u8, params: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        if (params) |p| {
            const rule: *const Rule = @ptrCast(@alignCast(p));
            return .{ .is_valid = v.len == rule.inline_usize };
        }
        return .{ .is_valid = true };
    }

    /// Numeric validation (integer or float)
    pub fn numeric(message: []const u8) Rule {
        return .{
            .name = "numeric",
            .validate = numericFn,
            .message = message,
        };
    }

    fn numericFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        _ = std.fmt.parseFloat(f64, v) catch {
            return .{ .is_valid = false };
        };
        return .{ .is_valid = true };
    }

    /// Integer validation
    pub fn integer(message: []const u8) Rule {
        return .{
            .name = "integer",
            .validate = integerFn,
            .message = message,
        };
    }

    fn integerFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        _ = std.fmt.parseInt(i64, v, 10) catch {
            return .{ .is_valid = false };
        };
        return .{ .is_valid = true };
    }

    /// Minimum value validation (for numbers). Previously discarded its
    /// parameter and accepted every parseable number as valid.
    pub fn min(min_val: f64, message: []const u8) Rule {
        return .{
            .name = "min",
            .validate = minFn,
            .message = message,
            .inline_f64 = min_val,
        };
    }

    fn minFn(value: ?[]const u8, params: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        const n = std.fmt.parseFloat(f64, v) catch return .{ .is_valid = false };
        if (params) |p| {
            const rule: *const Rule = @ptrCast(@alignCast(p));
            return .{ .is_valid = n >= rule.inline_f64 };
        }
        return .{ .is_valid = true };
    }

    /// Maximum value validation (for numbers). Previously accepted every
    /// parseable number regardless of `max_val`.
    pub fn max(max_val: f64, message: []const u8) Rule {
        return .{
            .name = "max",
            .validate = maxFn,
            .message = message,
            .inline_f64 = max_val,
        };
    }

    fn maxFn(value: ?[]const u8, params: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        const n = std.fmt.parseFloat(f64, v) catch return .{ .is_valid = false };
        if (params) |p| {
            const rule: *const Rule = @ptrCast(@alignCast(p));
            return .{ .is_valid = n <= rule.inline_f64 };
        }
        return .{ .is_valid = true };
    }

    /// Range validation (for numbers). `inline_f64` holds `min_val`;
    /// `inline_f64_b` holds `max_val`. Values are checked `min <= n <= max`.
    pub fn range(min_val: f64, max_val: f64, message: []const u8) Rule {
        return .{
            .name = "range",
            .validate = rangeFn,
            .message = message,
            .inline_f64 = min_val,
            .inline_f64_b = max_val,
        };
    }

    fn rangeFn(value: ?[]const u8, params: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        const n = std.fmt.parseFloat(f64, v) catch return .{ .is_valid = false };
        if (params) |p| {
            const rule: *const Rule = @ptrCast(@alignCast(p));
            return .{ .is_valid = n >= rule.inline_f64 and n <= rule.inline_f64_b };
        }
        return .{ .is_valid = true };
    }

    /// Alphanumeric validation
    pub fn alphanumeric(message: []const u8) Rule {
        return .{
            .name = "alphanumeric",
            .validate = alphanumericFn,
            .message = message,
        };
    }

    fn alphanumericFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        for (v) |c| {
            if (!std.ascii.isAlphanumeric(c)) {
                return .{ .is_valid = false };
            }
        }
        return .{ .is_valid = true };
    }

    /// Alpha only validation
    pub fn alpha(message: []const u8) Rule {
        return .{
            .name = "alpha",
            .validate = alphaFn,
            .message = message,
        };
    }

    fn alphaFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        for (v) |c| {
            if (!std.ascii.isAlphabetic(c)) {
                return .{ .is_valid = false };
            }
        }
        return .{ .is_valid = true };
    }

    /// Phone number validation (basic)
    pub fn phone(message: []const u8) Rule {
        return .{
            .name = "phone",
            .validate = phoneFn,
            .message = message,
        };
    }

    fn phoneFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        // Count digits (ignore common phone formatting characters).
        // `+` is only allowed as the first character (E.164 country prefix).
        var digit_count: usize = 0;
        for (v, 0..) |c, i| {
            if (std.ascii.isDigit(c)) {
                digit_count += 1;
            } else if (c == '+') {
                if (i != 0) return .{ .is_valid = false };
            } else if (c != '-' and c != '(' and c != ')' and c != ' ' and c != '.') {
                return .{ .is_valid = false };
            }
        }

        // Most phone numbers are 7-15 digits
        return .{ .is_valid = digit_count >= 7 and digit_count <= 15 };
    }

    /// Credit card validation (Luhn algorithm)
    pub fn creditCard(message: []const u8) Rule {
        return .{
            .name = "creditCard",
            .validate = creditCardFn,
            .message = message,
        };
    }

    fn creditCardFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        // Extract digits only
        var digits: [20]u8 = undefined;
        var digit_count: usize = 0;
        for (v) |c| {
            if (std.ascii.isDigit(c)) {
                if (digit_count >= 20) return .{ .is_valid = false };
                digits[digit_count] = c - '0';
                digit_count += 1;
            } else if (c != ' ' and c != '-') {
                return .{ .is_valid = false };
            }
        }

        // Credit cards are typically 13-19 digits
        if (digit_count < 13 or digit_count > 19) return .{ .is_valid = false };

        // Luhn algorithm
        var sum: u32 = 0;
        var is_even = false;
        var i: usize = digit_count;
        while (i > 0) {
            i -= 1;
            var digit: u32 = digits[i];
            if (is_even) {
                digit *= 2;
                if (digit > 9) digit -= 9;
            }
            sum += digit;
            is_even = !is_even;
        }

        return .{ .is_valid = sum % 10 == 0 };
    }

    /// Date validation (YYYY-MM-DD format)
    pub fn date(message: []const u8) Rule {
        return .{
            .name = "date",
            .validate = dateFn,
            .message = message,
        };
    }

    fn dateFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        // Expected format: YYYY-MM-DD (10 characters)
        if (v.len != 10) return .{ .is_valid = false };
        if (v[4] != '-' or v[7] != '-') return .{ .is_valid = false };

        const year = std.fmt.parseInt(u16, v[0..4], 10) catch return .{ .is_valid = false };
        const month = std.fmt.parseInt(u8, v[5..7], 10) catch return .{ .is_valid = false };
        const day = std.fmt.parseInt(u8, v[8..10], 10) catch return .{ .is_valid = false };

        if (year < 1900 or year > 2100) return .{ .is_valid = false };
        if (month < 1 or month > 12) return .{ .is_valid = false };
        if (day < 1 or day > 31) return .{ .is_valid = false };

        // Gregorian leap-year: divisible by 4, except centuries that aren't
        // divisible by 400. Previously February always accepted 29 days, so
        // non-leap dates like 1900-02-29 or 2023-02-29 validated as OK.
        const is_leap = (@mod(year, 4) == 0 and @mod(year, 100) != 0) or @mod(year, 400) == 0;
        const days_in_month = [_]u8{ 31, if (is_leap) @as(u8, 29) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
        if (day > days_in_month[month - 1]) return .{ .is_valid = false };

        return .{ .is_valid = true };
    }

    /// Time validation (HH:MM or HH:MM:SS format)
    pub fn time(message: []const u8) Rule {
        return .{
            .name = "time",
            .validate = timeFn,
            .message = message,
        };
    }

    fn timeFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        // Expected format: HH:MM or HH:MM:SS
        if (v.len != 5 and v.len != 8) return .{ .is_valid = false };
        if (v[2] != ':') return .{ .is_valid = false };
        if (v.len == 8 and v[5] != ':') return .{ .is_valid = false };

        const hour = std.fmt.parseInt(u8, v[0..2], 10) catch return .{ .is_valid = false };
        const minute = std.fmt.parseInt(u8, v[3..5], 10) catch return .{ .is_valid = false };

        if (hour > 23) return .{ .is_valid = false };
        if (minute > 59) return .{ .is_valid = false };

        if (v.len == 8) {
            const second = std.fmt.parseInt(u8, v[6..8], 10) catch return .{ .is_valid = false };
            if (second > 59) return .{ .is_valid = false };
        }

        return .{ .is_valid = true };
    }

    /// IPv4 address validation
    pub fn ipv4(message: []const u8) Rule {
        return .{
            .name = "ipv4",
            .validate = ipv4Fn,
            .message = message,
        };
    }

    fn ipv4Fn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        var parts: usize = 0;
        var current_num: u32 = 0;
        var digit_count: usize = 0;
        // Reject leading zeros per-octet (`192.168.001.001` is ambiguous as
        // octal on some parsers and confusing to humans). `leading_zero`
        // tracks whether the octet started with a `0`.
        var leading_zero = false;

        for (v) |c| {
            if (c == '.') {
                if (digit_count == 0 or current_num > 255) return .{ .is_valid = false };
                parts += 1;
                current_num = 0;
                digit_count = 0;
                leading_zero = false;
            } else if (std.ascii.isDigit(c)) {
                if (digit_count == 0 and c == '0') leading_zero = true;
                if (leading_zero and digit_count >= 1) return .{ .is_valid = false };
                current_num = current_num * 10 + (c - '0');
                digit_count += 1;
                if (digit_count > 3 or current_num > 255) return .{ .is_valid = false };
            } else {
                return .{ .is_valid = false };
            }
        }

        // Check last octet
        if (digit_count == 0 or current_num > 255) return .{ .is_valid = false };
        parts += 1;

        return .{ .is_valid = parts == 4 };
    }

    /// Hex color validation (#RGB or #RRGGBB)
    pub fn hexColor(message: []const u8) Rule {
        return .{
            .name = "hexColor",
            .validate = hexColorFn,
            .message = message,
        };
    }

    fn hexColorFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        if (v[0] != '#') return .{ .is_valid = false };
        if (v.len != 4 and v.len != 7) return .{ .is_valid = false };

        for (v[1..]) |c| {
            if (!std.ascii.isHex(c)) return .{ .is_valid = false };
        }

        return .{ .is_valid = true };
    }

    /// Slug validation (lowercase alphanumeric with hyphens)
    pub fn slug(message: []const u8) Rule {
        return .{
            .name = "slug",
            .validate = slugFn,
            .message = message,
        };
    }

    fn slugFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        // Can't start or end with hyphen
        if (v[0] == '-' or v[v.len - 1] == '-') return .{ .is_valid = false };

        var prev_hyphen = false;
        for (v) |c| {
            if (c == '-') {
                // No consecutive hyphens
                if (prev_hyphen) return .{ .is_valid = false };
                prev_hyphen = true;
            } else if (std.ascii.isLower(c) or std.ascii.isDigit(c)) {
                prev_hyphen = false;
            } else {
                return .{ .is_valid = false };
            }
        }

        return .{ .is_valid = true };
    }

    /// UUID validation
    pub fn uuid(message: []const u8) Rule {
        return .{
            .name = "uuid",
            .validate = uuidFn,
            .message = message,
        };
    }

    fn uuidFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        // UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (36 chars)
        if (v.len != 36) return .{ .is_valid = false };
        if (v[8] != '-' or v[13] != '-' or v[18] != '-' or v[23] != '-') return .{ .is_valid = false };

        for (v, 0..) |c, i| {
            if (i == 8 or i == 13 or i == 18 or i == 23) continue;
            if (!std.ascii.isHex(c)) return .{ .is_valid = false };
        }

        return .{ .is_valid = true };
    }

    /// JSON validation
    pub fn json(message: []const u8) Rule {
        return .{
            .name = "json",
            .validate = jsonFn,
            .message = message,
        };
    }

    fn jsonFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        // Basic JSON structure check (starts with { or [)
        const trimmed = std.mem.trim(u8, v, " \t\n\r");
        if (trimmed.len == 0) return .{ .is_valid = false };

        const first = trimmed[0];
        const last = trimmed[trimmed.len - 1];

        if ((first == '{' and last == '}') or (first == '[' and last == ']')) {
            return .{ .is_valid = true };
        }

        return .{ .is_valid = false };
    }

    /// Equals validation (must match another value). Previously discarded
    /// the expected value, so every non-empty input passed.
    pub fn equals(expected: []const u8, message: []const u8) Rule {
        return .{
            .name = "equals",
            .validate = equalsFn,
            .message = message,
            .inline_bytes = expected,
        };
    }

    fn equalsFn(value: ?[]const u8, params: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };
        if (params) |p| {
            const rule: *const Rule = @ptrCast(@alignCast(p));
            return .{ .is_valid = std.mem.eql(u8, v, rule.inline_bytes) };
        }
        return .{ .is_valid = true };
    }

    /// Contains substring validation. Previously always returned valid.
    pub fn contains(substring: []const u8, message: []const u8) Rule {
        return .{
            .name = "contains",
            .validate = containsFn,
            .message = message,
            .inline_bytes = substring,
        };
    }

    fn containsFn(value: ?[]const u8, params: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };
        if (params) |p| {
            const rule: *const Rule = @ptrCast(@alignCast(p));
            if (rule.inline_bytes.len == 0) return .{ .is_valid = true };
            return .{ .is_valid = std.mem.indexOf(u8, v, rule.inline_bytes) != null };
        }
        return .{ .is_valid = true };
    }

    /// In list validation (value must be one of allowed values). The caller
    /// owns the list storage; the slice is borrowed, not copied.
    pub fn inList(allowed: []const []const u8, message: []const u8) Rule {
        return .{
            .name = "inList",
            .validate = inListFn,
            .message = message,
            .inline_list = allowed,
        };
    }

    fn inListFn(value: ?[]const u8, params: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };
        if (params) |p| {
            const rule: *const Rule = @ptrCast(@alignCast(p));
            for (rule.inline_list) |allowed_val| {
                if (std.mem.eql(u8, v, allowed_val)) return .{ .is_valid = true };
            }
            return .{ .is_valid = false };
        }
        return .{ .is_valid = true };
    }

    /// Not in list validation (value must NOT be one of disallowed values).
    pub fn notInList(disallowed: []const []const u8, message: []const u8) Rule {
        return .{
            .name = "notInList",
            .validate = notInListFn,
            .message = message,
            .inline_list = disallowed,
        };
    }

    fn notInListFn(value: ?[]const u8, params: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };
        if (params) |p| {
            const rule: *const Rule = @ptrCast(@alignCast(p));
            for (rule.inline_list) |disallowed_val| {
                if (std.mem.eql(u8, v, disallowed_val)) return .{ .is_valid = false };
            }
        }
        return .{ .is_valid = true };
    }

    /// Password strength validation. Previously discarded the `options`
    /// argument and always enforced a hardcoded policy (8+, upper+lower+digit,
    /// no special chars). Now encodes each option as a bit in `inline_flags`.
    pub fn password(options: PasswordOptions, message: []const u8) Rule {
        var flags: u32 = 0;
        if (options.require_uppercase) flags |= password_flag_upper;
        if (options.require_lowercase) flags |= password_flag_lower;
        if (options.require_digit) flags |= password_flag_digit;
        if (options.require_special) flags |= password_flag_special;
        return .{
            .name = "password",
            .validate = passwordFn,
            .message = message,
            .inline_usize = options.min_length,
            .inline_flags = flags,
        };
    }

    pub const PasswordOptions = struct {
        min_length: usize = 8,
        require_uppercase: bool = true,
        require_lowercase: bool = true,
        require_digit: bool = true,
        require_special: bool = false,
    };

    const password_flag_upper: u32 = 1 << 0;
    const password_flag_lower: u32 = 1 << 1;
    const password_flag_digit: u32 = 1 << 2;
    const password_flag_special: u32 = 1 << 3;

    fn passwordFn(value: ?[]const u8, params: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        const rule_opt: ?*const Rule = if (params) |p| @ptrCast(@alignCast(p)) else null;
        const min_len: usize = if (rule_opt) |r| (if (r.inline_usize == 0) 8 else r.inline_usize) else 8;
        const flags: u32 = if (rule_opt) |r| r.inline_flags else (password_flag_upper | password_flag_lower | password_flag_digit);

        if (v.len < min_len) return .{ .is_valid = false, .message = "Password is too short" };

        var has_upper = false;
        var has_lower = false;
        var has_digit = false;
        var has_special = false;

        for (v) |c| {
            if (std.ascii.isUpper(c)) has_upper = true
            else if (std.ascii.isLower(c)) has_lower = true
            else if (std.ascii.isDigit(c)) has_digit = true
            else has_special = true;
        }

        if ((flags & password_flag_upper) != 0 and !has_upper)
            return .{ .is_valid = false, .message = "Password must contain an uppercase letter" };
        if ((flags & password_flag_lower) != 0 and !has_lower)
            return .{ .is_valid = false, .message = "Password must contain a lowercase letter" };
        if ((flags & password_flag_digit) != 0 and !has_digit)
            return .{ .is_valid = false, .message = "Password must contain a digit" };
        if ((flags & password_flag_special) != 0 and !has_special)
            return .{ .is_valid = false, .message = "Password must contain a special character" };

        return .{ .is_valid = true };
    }

    /// Postal code validation (US ZIP code)
    pub fn postalCode(message: []const u8) Rule {
        return .{
            .name = "postalCode",
            .validate = postalCodeFn,
            .message = message,
        };
    }

    fn postalCodeFn(value: ?[]const u8, _: ?*const anyopaque) RuleResult {
        const v = value orelse return .{ .is_valid = true };
        if (v.len == 0) return .{ .is_valid = true };

        // US ZIP code: 5 digits or 5+4 format (12345 or 12345-6789)
        if (v.len == 5) {
            for (v) |c| {
                if (!std.ascii.isDigit(c)) return .{ .is_valid = false };
            }
            return .{ .is_valid = true };
        }

        if (v.len == 10 and v[5] == '-') {
            for (v[0..5]) |c| {
                if (!std.ascii.isDigit(c)) return .{ .is_valid = false };
            }
            for (v[6..10]) |c| {
                if (!std.ascii.isDigit(c)) return .{ .is_valid = false };
            }
            return .{ .is_valid = true };
        }

        return .{ .is_valid = false };
    }
};

/// Form field configuration
pub const FieldConfig = struct {
    name: []const u8,
    rules: []const Rule,
    label: ?[]const u8 = null,
    default_value: ?[]const u8 = null,
};

/// Form validator
pub const FormValidator = struct {
    allocator: std.mem.Allocator,
    fields: std.StringHashMapUnmanaged(FieldConfig),
    errors: std.ArrayListUnmanaged(FieldError),
    field_errors: std.StringHashMapUnmanaged(std.ArrayListUnmanaged(FieldError)),

    const Self = @This();

    /// Initialize form validator
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .fields = .{},
            .errors = .{},
            .field_errors = .{},
        };
    }

    /// Add a field with validation rules
    pub fn addField(self: *Self, name: []const u8, rules: []const Rule) !void {
        try self.fields.put(self.allocator, name, .{
            .name = name,
            .rules = rules,
        });
    }

    /// Add a field with full configuration
    pub fn addFieldConfig(self: *Self, config: FieldConfig) !void {
        try self.fields.put(self.allocator, config.name, config);
    }

    /// Validate a single field value
    pub fn validateField(self: *Self, name: []const u8, value: ?[]const u8) ![]const FieldError {
        self.clearFieldErrors(name);

        const config = self.fields.get(name) orelse return ValidationError.InvalidField;

        var field_errors_list = std.ArrayListUnmanaged(FieldError){};

        for (config.rules) |rule| {
            const result = rule.check(value);
            if (!result.is_valid) {
                const err = FieldError{
                    .field = name,
                    .message = result.message orelse rule.message,
                    .rule = rule.name,
                    .value = value,
                };
                try field_errors_list.append(self.allocator, err);
                try self.errors.append(self.allocator, err);
            }
        }

        if (field_errors_list.items.len > 0) {
            try self.field_errors.put(self.allocator, name, field_errors_list);
        }

        return field_errors_list.items;
    }

    /// Validate all fields with provided values
    pub fn validateAll(self: *Self, values: std.StringHashMapUnmanaged([]const u8)) !ValidationResult {
        self.clearErrors();

        var it = self.fields.iterator();
        while (it.next()) |entry| {
            const value = values.get(entry.key_ptr.*);
            _ = try self.validateField(entry.key_ptr.*, value);
        }

        return ValidationResult{
            .is_valid = self.errors.items.len == 0,
            .errors = self.errors.items,
            .field_errors = self.field_errors,
        };
    }

    /// Clear all errors
    pub fn clearErrors(self: *Self) void {
        self.errors.clearRetainingCapacity();
        var it = self.field_errors.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.clearRetainingCapacity();
        }
    }

    /// Clear errors for a specific field
    pub fn clearFieldErrors(self: *Self, name: []const u8) void {
        if (self.field_errors.getPtr(name)) |list| {
            list.clearRetainingCapacity();
        }
    }

    /// Get all current errors
    pub fn getErrors(self: *Self) []const FieldError {
        return self.errors.items;
    }

    /// Check if form is currently valid
    pub fn isValid(self: *Self) bool {
        return self.errors.items.len == 0;
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.fields.deinit(self.allocator);
        self.errors.deinit(self.allocator);

        var it = self.field_errors.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.field_errors.deinit(self.allocator);
    }
};

/// Validation presets for common forms
pub const ValidationPresets = struct {
    /// Login form validation rules
    pub fn loginForm() [2]FieldConfig {
        return .{
            .{
                .name = "email",
                .rules = &[_]Rule{
                    Rules.required("Email is required"),
                    Rules.email("Invalid email format"),
                },
                .label = "Email Address",
            },
            .{
                .name = "password",
                .rules = &[_]Rule{
                    Rules.required("Password is required"),
                },
                .label = "Password",
            },
        };
    }

    /// Registration form validation rules
    pub fn registrationForm() [4]FieldConfig {
        return .{
            .{
                .name = "email",
                .rules = &[_]Rule{
                    Rules.required("Email is required"),
                    Rules.email("Invalid email format"),
                },
                .label = "Email Address",
            },
            .{
                .name = "password",
                .rules = &[_]Rule{
                    Rules.required("Password is required"),
                    Rules.password(.{}, "Password does not meet requirements"),
                },
                .label = "Password",
            },
            .{
                .name = "username",
                .rules = &[_]Rule{
                    Rules.required("Username is required"),
                    Rules.alphanumeric("Username must be alphanumeric"),
                },
                .label = "Username",
            },
            .{
                .name = "name",
                .rules = &[_]Rule{
                    Rules.required("Name is required"),
                },
                .label = "Full Name",
            },
        };
    }

    /// Contact form validation rules
    pub fn contactForm() [3]FieldConfig {
        return .{
            .{
                .name = "name",
                .rules = &[_]Rule{
                    Rules.required("Name is required"),
                },
                .label = "Your Name",
            },
            .{
                .name = "email",
                .rules = &[_]Rule{
                    Rules.required("Email is required"),
                    Rules.email("Invalid email format"),
                },
                .label = "Email Address",
            },
            .{
                .name = "message",
                .rules = &[_]Rule{
                    Rules.required("Message is required"),
                },
                .label = "Message",
            },
        };
    }

    /// Address form validation rules
    pub fn addressForm() [5]FieldConfig {
        return .{
            .{
                .name = "street",
                .rules = &[_]Rule{
                    Rules.required("Street address is required"),
                },
                .label = "Street Address",
            },
            .{
                .name = "city",
                .rules = &[_]Rule{
                    Rules.required("City is required"),
                },
                .label = "City",
            },
            .{
                .name = "state",
                .rules = &[_]Rule{
                    Rules.required("State is required"),
                },
                .label = "State/Province",
            },
            .{
                .name = "postal_code",
                .rules = &[_]Rule{
                    Rules.required("Postal code is required"),
                    Rules.postalCode("Invalid postal code format"),
                },
                .label = "Postal Code",
            },
            .{
                .name = "country",
                .rules = &[_]Rule{
                    Rules.required("Country is required"),
                },
                .label = "Country",
            },
        };
    }

    /// Payment form validation rules
    pub fn paymentForm() [4]FieldConfig {
        return .{
            .{
                .name = "card_number",
                .rules = &[_]Rule{
                    Rules.required("Card number is required"),
                    Rules.creditCard("Invalid credit card number"),
                },
                .label = "Card Number",
            },
            .{
                .name = "expiry",
                .rules = &[_]Rule{
                    Rules.required("Expiry date is required"),
                },
                .label = "Expiry Date (MM/YY)",
            },
            .{
                .name = "cvv",
                .rules = &[_]Rule{
                    Rules.required("CVV is required"),
                    Rules.numeric("CVV must be numeric"),
                },
                .label = "CVV",
            },
            .{
                .name = "name_on_card",
                .rules = &[_]Rule{
                    Rules.required("Name on card is required"),
                },
                .label = "Name on Card",
            },
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Rules.required" {
    const rule = Rules.required("Field is required");

    // Empty values should fail
    try std.testing.expect(!rule.check(null).is_valid);
    try std.testing.expect(!rule.check("").is_valid);
    try std.testing.expect(!rule.check("   ").is_valid);

    // Non-empty values should pass
    try std.testing.expect(rule.check("hello").is_valid);
    try std.testing.expect(rule.check("  hello  ").is_valid);
}

test "Rules.email" {
    const rule = Rules.email("Invalid email");

    // Valid emails
    try std.testing.expect(rule.check("test@example.com").is_valid);
    try std.testing.expect(rule.check("user.name@domain.org").is_valid);
    try std.testing.expect(rule.check("user+tag@example.co.uk").is_valid);

    // Invalid emails
    try std.testing.expect(!rule.check("invalid").is_valid);
    try std.testing.expect(!rule.check("@example.com").is_valid);
    try std.testing.expect(!rule.check("test@").is_valid);
    try std.testing.expect(!rule.check("test@.com").is_valid);
    try std.testing.expect(!rule.check("test@example.").is_valid);

    // Empty is valid (use required for mandatory)
    try std.testing.expect(rule.check("").is_valid);
    try std.testing.expect(rule.check(null).is_valid);
}

test "Rules.url" {
    const rule = Rules.url("Invalid URL");

    // Valid URLs
    try std.testing.expect(rule.check("http://example.com").is_valid);
    try std.testing.expect(rule.check("https://www.example.com").is_valid);
    try std.testing.expect(rule.check("https://example.com/path").is_valid);

    // Invalid URLs
    try std.testing.expect(!rule.check("example.com").is_valid);
    try std.testing.expect(!rule.check("ftp://").is_valid);
    try std.testing.expect(!rule.check("invalid").is_valid);
}

test "Rules.numeric" {
    const rule = Rules.numeric("Must be numeric");

    // Valid numbers
    try std.testing.expect(rule.check("123").is_valid);
    try std.testing.expect(rule.check("-456").is_valid);
    try std.testing.expect(rule.check("3.14159").is_valid);
    try std.testing.expect(rule.check("-0.5").is_valid);

    // Invalid numbers
    try std.testing.expect(!rule.check("abc").is_valid);
    try std.testing.expect(!rule.check("12.34.56").is_valid);
}

test "Rules.integer" {
    const rule = Rules.integer("Must be integer");

    // Valid integers
    try std.testing.expect(rule.check("123").is_valid);
    try std.testing.expect(rule.check("-456").is_valid);
    try std.testing.expect(rule.check("0").is_valid);

    // Invalid integers
    try std.testing.expect(!rule.check("3.14").is_valid);
    try std.testing.expect(!rule.check("abc").is_valid);
}

test "Rules.alphanumeric" {
    const rule = Rules.alphanumeric("Must be alphanumeric");

    // Valid
    try std.testing.expect(rule.check("abc123").is_valid);
    try std.testing.expect(rule.check("Test123").is_valid);

    // Invalid
    try std.testing.expect(!rule.check("abc-123").is_valid);
    try std.testing.expect(!rule.check("hello world").is_valid);
    try std.testing.expect(!rule.check("test@123").is_valid);
}

test "Rules.phone" {
    const rule = Rules.phone("Invalid phone");

    // Valid phone numbers
    try std.testing.expect(rule.check("1234567890").is_valid);
    try std.testing.expect(rule.check("+1 (555) 123-4567").is_valid);
    try std.testing.expect(rule.check("555-123-4567").is_valid);

    // Invalid phone numbers
    try std.testing.expect(!rule.check("123").is_valid); // Too short
    try std.testing.expect(!rule.check("phone").is_valid);
}

test "Rules.creditCard" {
    const rule = Rules.creditCard("Invalid card");

    // Valid card numbers (test numbers)
    try std.testing.expect(rule.check("4532015112830366").is_valid); // Visa test
    try std.testing.expect(rule.check("4532-0151-1283-0366").is_valid); // With dashes

    // Invalid card numbers
    try std.testing.expect(!rule.check("1234567890123456").is_valid); // Fails Luhn
    try std.testing.expect(!rule.check("123").is_valid); // Too short
}

test "Rules.date" {
    const rule = Rules.date("Invalid date");

    // Valid dates
    try std.testing.expect(rule.check("2024-01-15").is_valid);
    try std.testing.expect(rule.check("2000-12-31").is_valid);

    // Invalid dates
    try std.testing.expect(!rule.check("2024-13-01").is_valid); // Invalid month
    try std.testing.expect(!rule.check("2024-01-32").is_valid); // Invalid day
    try std.testing.expect(!rule.check("24-01-15").is_valid); // Wrong format
}

test "Rules.time" {
    const rule = Rules.time("Invalid time");

    // Valid times
    try std.testing.expect(rule.check("12:30").is_valid);
    try std.testing.expect(rule.check("23:59").is_valid);
    try std.testing.expect(rule.check("00:00:00").is_valid);
    try std.testing.expect(rule.check("12:30:45").is_valid);

    // Invalid times
    try std.testing.expect(!rule.check("24:00").is_valid); // Invalid hour
    try std.testing.expect(!rule.check("12:60").is_valid); // Invalid minute
    try std.testing.expect(!rule.check("12-30").is_valid); // Wrong format
}

test "Rules.ipv4" {
    const rule = Rules.ipv4("Invalid IP");

    // Valid IPs
    try std.testing.expect(rule.check("192.168.1.1").is_valid);
    try std.testing.expect(rule.check("0.0.0.0").is_valid);
    try std.testing.expect(rule.check("255.255.255.255").is_valid);

    // Invalid IPs
    try std.testing.expect(!rule.check("256.1.1.1").is_valid);
    try std.testing.expect(!rule.check("192.168.1").is_valid);
    try std.testing.expect(!rule.check("192.168.1.1.1").is_valid);
}

test "Rules.hexColor" {
    const rule = Rules.hexColor("Invalid color");

    // Valid colors
    try std.testing.expect(rule.check("#FFF").is_valid);
    try std.testing.expect(rule.check("#ffffff").is_valid);
    try std.testing.expect(rule.check("#ABC123").is_valid);

    // Invalid colors
    try std.testing.expect(!rule.check("FFF").is_valid); // Missing #
    try std.testing.expect(!rule.check("#FFFF").is_valid); // Wrong length
    try std.testing.expect(!rule.check("#GGG").is_valid); // Invalid hex
}

test "Rules.slug" {
    const rule = Rules.slug("Invalid slug");

    // Valid slugs
    try std.testing.expect(rule.check("hello-world").is_valid);
    try std.testing.expect(rule.check("post123").is_valid);
    try std.testing.expect(rule.check("my-post-title").is_valid);

    // Invalid slugs
    try std.testing.expect(!rule.check("-hello").is_valid); // Starts with hyphen
    try std.testing.expect(!rule.check("hello-").is_valid); // Ends with hyphen
    try std.testing.expect(!rule.check("hello--world").is_valid); // Consecutive hyphens
    try std.testing.expect(!rule.check("Hello-World").is_valid); // Uppercase
}

test "Rules.uuid" {
    const rule = Rules.uuid("Invalid UUID");

    // Valid UUIDs
    try std.testing.expect(rule.check("550e8400-e29b-41d4-a716-446655440000").is_valid);
    try std.testing.expect(rule.check("00000000-0000-0000-0000-000000000000").is_valid);

    // Invalid UUIDs
    try std.testing.expect(!rule.check("550e8400-e29b-41d4-a716").is_valid); // Too short
    try std.testing.expect(!rule.check("550e8400e29b41d4a716446655440000").is_valid); // Missing dashes
}

test "Rules.password" {
    const rule = Rules.password(.{}, "Invalid password");

    // Valid passwords
    try std.testing.expect(rule.check("Password1").is_valid);
    try std.testing.expect(rule.check("SecurePass123").is_valid);

    // Invalid passwords
    try std.testing.expect(!rule.check("pass").is_valid); // Too short
    try std.testing.expect(!rule.check("password").is_valid); // No uppercase, no digit
    try std.testing.expect(!rule.check("PASSWORD").is_valid); // No lowercase, no digit
}

test "Rules.postalCode" {
    const rule = Rules.postalCode("Invalid postal code");

    // Valid US ZIP codes
    try std.testing.expect(rule.check("12345").is_valid);
    try std.testing.expect(rule.check("12345-6789").is_valid);

    // Invalid postal codes
    try std.testing.expect(!rule.check("1234").is_valid); // Too short
    try std.testing.expect(!rule.check("123456").is_valid); // Wrong length
    try std.testing.expect(!rule.check("ABCDE").is_valid); // Non-numeric
}

// Regression tests for validators that used to silently accept everything.
test "Rules.min/max/range actually reject out-of-range numbers" {
    const min_rule = Rules.min(10.0, "too small");
    try std.testing.expect(min_rule.check("5").is_valid == false);
    try std.testing.expect(min_rule.check("10").is_valid);
    try std.testing.expect(min_rule.check("100").is_valid);

    const max_rule = Rules.max(10.0, "too big");
    try std.testing.expect(max_rule.check("5").is_valid);
    try std.testing.expect(max_rule.check("10").is_valid);
    try std.testing.expect(max_rule.check("100").is_valid == false);

    const range_rule = Rules.range(1.0, 5.0, "out of range");
    try std.testing.expect(range_rule.check("0").is_valid == false);
    try std.testing.expect(range_rule.check("3").is_valid);
    try std.testing.expect(range_rule.check("5").is_valid);
    try std.testing.expect(range_rule.check("5.1").is_valid == false);
}

test "Rules.equals/contains/inList/notInList actually compare" {
    const eq_rule = Rules.equals("hello", "must equal hello");
    try std.testing.expect(eq_rule.check("hello").is_valid);
    try std.testing.expect(eq_rule.check("world").is_valid == false);

    const contains_rule = Rules.contains("cat", "must contain cat");
    try std.testing.expect(contains_rule.check("concatenate").is_valid);
    try std.testing.expect(contains_rule.check("dog").is_valid == false);

    const allowed = [_][]const u8{ "red", "green", "blue" };
    const in_rule = Rules.inList(&allowed, "must be a color");
    try std.testing.expect(in_rule.check("red").is_valid);
    try std.testing.expect(in_rule.check("purple").is_valid == false);

    const blocklist = [_][]const u8{ "admin", "root" };
    const not_in_rule = Rules.notInList(&blocklist, "reserved username");
    try std.testing.expect(not_in_rule.check("alice").is_valid);
    try std.testing.expect(not_in_rule.check("admin").is_valid == false);
}

test "Rules.minLength/maxLength/exactLength use the passed length" {
    const min_len = Rules.minLength(5, "too short");
    try std.testing.expect(min_len.check("hi").is_valid == false);
    try std.testing.expect(min_len.check("hello").is_valid);

    const max_len = Rules.maxLength(5, "too long");
    try std.testing.expect(max_len.check("hello").is_valid);
    try std.testing.expect(max_len.check("hello!").is_valid == false);

    const exact_len = Rules.exactLength(3, "must be 3 chars");
    try std.testing.expect(exact_len.check("abc").is_valid);
    try std.testing.expect(exact_len.check("ab").is_valid == false);
    try std.testing.expect(exact_len.check("abcd").is_valid == false);
}

test "FormValidator basic usage" {
    const allocator = std.testing.allocator;
    var validator = FormValidator.init(allocator);
    defer validator.deinit();

    try validator.addField("email", &[_]Rule{
        Rules.required("Email is required"),
        Rules.email("Invalid email format"),
    });

    // Valid email
    const valid_errors = try validator.validateField("email", "test@example.com");
    try std.testing.expectEqual(@as(usize, 0), valid_errors.len);

    // Clear and test invalid email
    validator.clearErrors();
    const invalid_errors = try validator.validateField("email", "invalid");
    try std.testing.expect(invalid_errors.len > 0);
}

test "ValidationPresets login form" {
    const presets = ValidationPresets.loginForm();
    try std.testing.expectEqual(@as(usize, 2), presets.len);
    try std.testing.expectEqualStrings("email", presets[0].name);
    try std.testing.expectEqualStrings("password", presets[1].name);
}

test "ValidationPresets registration form" {
    const presets = ValidationPresets.registrationForm();
    try std.testing.expectEqual(@as(usize, 4), presets.len);
}

test "ValidationPresets payment form" {
    const presets = ValidationPresets.paymentForm();
    try std.testing.expectEqual(@as(usize, 4), presets.len);
    try std.testing.expectEqualStrings("card_number", presets[0].name);
}
