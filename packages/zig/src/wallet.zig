//! Cross-platform digital wallet and payment abstraction
//! Supports Apple Pay, Google Pay, Samsung Pay, and other payment providers

const std = @import("std");

/// Get current timestamp in seconds
fn getCurrentTimestamp() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        return ts.sec;
    }
    return 0;
}

/// Payment provider/wallet type
pub const WalletProvider = enum {
    apple_pay,
    google_pay,
    samsung_pay,
    paypal,
    stripe,
    square,
    venmo,
    cash_app,
    alipay,
    wechat_pay,

    pub fn displayName(self: WalletProvider) []const u8 {
        return switch (self) {
            .apple_pay => "Apple Pay",
            .google_pay => "Google Pay",
            .samsung_pay => "Samsung Pay",
            .paypal => "PayPal",
            .stripe => "Stripe",
            .square => "Square",
            .venmo => "Venmo",
            .cash_app => "Cash App",
            .alipay => "Alipay",
            .wechat_pay => "WeChat Pay",
        };
    }

    pub fn supportsRecurring(self: WalletProvider) bool {
        return switch (self) {
            .apple_pay, .google_pay, .stripe, .paypal => true,
            .samsung_pay, .square, .venmo, .cash_app, .alipay, .wechat_pay => false,
        };
    }

    pub fn supportedRegions(self: WalletProvider) []const []const u8 {
        return switch (self) {
            .apple_pay => &[_][]const u8{ "US", "UK", "CA", "AU", "JP", "DE", "FR", "CN" },
            .google_pay => &[_][]const u8{ "US", "UK", "CA", "AU", "JP", "DE", "FR", "IN" },
            .alipay, .wechat_pay => &[_][]const u8{"CN"},
            else => &[_][]const u8{ "US", "UK", "CA" },
        };
    }
};

/// Payment method type
pub const PaymentMethodType = enum {
    credit_card,
    debit_card,
    bank_account,
    digital_wallet,
    gift_card,
    store_credit,
    crypto,
    bnpl, // Buy now pay later

    pub fn requiresVerification(self: PaymentMethodType) bool {
        return switch (self) {
            .bank_account, .crypto => true,
            else => false,
        };
    }
};

/// Card network/brand
pub const CardNetwork = enum {
    visa,
    mastercard,
    amex,
    discover,
    jcb,
    unionpay,
    diners,
    maestro,
    unknown,

    pub fn prefixLength(self: CardNetwork) u8 {
        return switch (self) {
            .visa => 1, // 4
            .mastercard => 2, // 51-55, 2221-2720
            .amex => 2, // 34, 37
            .discover => 4, // 6011
            .jcb => 4, // 3528-3589
            .unionpay => 2, // 62
            .diners => 3, // 300-305, 36, 38
            .maestro => 2, // 50, 56-69
            .unknown => 0,
        };
    }

    pub fn cardNumberLength(self: CardNetwork) u8 {
        return switch (self) {
            .amex => 15,
            .diners => 14,
            else => 16,
        };
    }

    pub fn cvvLength(self: CardNetwork) u8 {
        return switch (self) {
            .amex => 4,
            else => 3,
        };
    }
};

/// Currency code
pub const CurrencyCode = enum {
    usd,
    eur,
    gbp,
    jpy,
    cny,
    cad,
    aud,
    inr,
    krw,
    mxn,

    pub fn symbol(self: CurrencyCode) []const u8 {
        return switch (self) {
            .usd, .cad, .aud, .mxn => "$",
            .eur => "€",
            .gbp => "£",
            .jpy, .cny => "¥",
            .inr => "₹",
            .krw => "₩",
        };
    }

    pub fn code(self: CurrencyCode) []const u8 {
        return switch (self) {
            .usd => "USD",
            .eur => "EUR",
            .gbp => "GBP",
            .jpy => "JPY",
            .cny => "CNY",
            .cad => "CAD",
            .aud => "AUD",
            .inr => "INR",
            .krw => "KRW",
            .mxn => "MXN",
        };
    }

    pub fn minorUnits(self: CurrencyCode) u8 {
        return switch (self) {
            .jpy, .krw => 0, // No decimal places
            else => 2,
        };
    }
};

/// Monetary amount with currency
pub const Money = struct {
    /// Amount in minor units (cents for USD)
    amount: i64,
    currency: CurrencyCode,

    pub fn fromMajor(major: f64, currency: CurrencyCode) Money {
        const multiplier = std.math.pow(f64, 10, @floatFromInt(currency.minorUnits()));
        return .{
            .amount = @intFromFloat(@round(major * multiplier)),
            .currency = currency,
        };
    }

    pub fn toMajor(self: Money) f64 {
        const divisor = std.math.pow(f64, 10, @floatFromInt(self.currency.minorUnits()));
        return @as(f64, @floatFromInt(self.amount)) / divisor;
    }

    pub fn add(self: Money, other: Money) ?Money {
        if (self.currency != other.currency) return null;
        return .{
            .amount = self.amount + other.amount,
            .currency = self.currency,
        };
    }

    pub fn subtract(self: Money, other: Money) ?Money {
        if (self.currency != other.currency) return null;
        return .{
            .amount = self.amount - other.amount,
            .currency = self.currency,
        };
    }

    pub fn multiply(self: Money, factor: f64) Money {
        return .{
            .amount = @intFromFloat(@as(f64, @floatFromInt(self.amount)) * factor),
            .currency = self.currency,
        };
    }

    pub fn isPositive(self: Money) bool {
        return self.amount > 0;
    }

    pub fn isZero(self: Money) bool {
        return self.amount == 0;
    }
};

/// Payment card information (tokenized)
pub const PaymentCard = struct {
    /// Token representing the card (not the actual number)
    token: [64]u8,
    token_len: u8,
    network: CardNetwork,
    last_four: [4]u8,
    expiry_month: u8,
    expiry_year: u16,
    cardholder_name: [64]u8,
    name_len: u8,
    billing_address_id: ?[32]u8,

    pub fn init() PaymentCard {
        return .{
            .token = [_]u8{0} ** 64,
            .token_len = 0,
            .network = .unknown,
            .last_four = [_]u8{'0'} ** 4,
            .expiry_month = 1,
            .expiry_year = 2025,
            .cardholder_name = [_]u8{0} ** 64,
            .name_len = 0,
            .billing_address_id = null,
        };
    }

    pub fn isExpired(self: PaymentCard) bool {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) != 0) return false;
        const epoch_seconds: u64 = @intCast(ts.sec);
        // Approximate: seconds since 1970 / seconds per year + 1970
        const current_year: u16 = @intCast(1970 + epoch_seconds / 31536000);
        const current_month: u8 = @intCast(1 + (epoch_seconds % 31536000) / 2628000);

        if (self.expiry_year < current_year) return true;
        if (self.expiry_year == current_year and self.expiry_month < current_month) return true;
        return false;
    }

    pub fn maskedDisplay(self: PaymentCard) [19]u8 {
        var display: [19]u8 = [_]u8{' '} ** 19;
        // •••• •••• •••• 1234
        display[0] = 0xE2; // UTF-8 bullet point start (won't render correctly, use *)
        @memcpy(display[0..4], "****");
        @memcpy(display[5..9], "****");
        @memcpy(display[10..14], "****");
        @memcpy(display[15..19], &self.last_four);
        return display;
    }

    pub fn withToken(self: PaymentCard, token: []const u8) PaymentCard {
        var card = self;
        const len = @min(token.len, 64);
        @memcpy(card.token[0..len], token[0..len]);
        card.token_len = @intCast(len);
        return card;
    }

    pub fn withLastFour(self: PaymentCard, digits: []const u8) PaymentCard {
        var card = self;
        if (digits.len == 4) {
            @memcpy(&card.last_four, digits[0..4]);
        }
        return card;
    }

    pub fn withExpiry(self: PaymentCard, month: u8, year: u16) PaymentCard {
        var card = self;
        card.expiry_month = month;
        card.expiry_year = year;
        return card;
    }

    pub fn withNetwork(self: PaymentCard, network: CardNetwork) PaymentCard {
        var card = self;
        card.network = network;
        return card;
    }
};

/// Billing/shipping address
pub const Address = struct {
    line1: [128]u8,
    line1_len: u8,
    line2: [128]u8,
    line2_len: u8,
    city: [64]u8,
    city_len: u8,
    state: [64]u8,
    state_len: u8,
    postal_code: [16]u8,
    postal_len: u8,
    country_code: [2]u8,

    pub fn init() Address {
        return .{
            .line1 = [_]u8{0} ** 128,
            .line1_len = 0,
            .line2 = [_]u8{0} ** 128,
            .line2_len = 0,
            .city = [_]u8{0} ** 64,
            .city_len = 0,
            .state = [_]u8{0} ** 64,
            .state_len = 0,
            .postal_code = [_]u8{0} ** 16,
            .postal_len = 0,
            .country_code = [_]u8{ 'U', 'S' },
        };
    }

    pub fn withLine1(self: Address, line: []const u8) Address {
        var addr = self;
        const len = @min(line.len, 128);
        @memcpy(addr.line1[0..len], line[0..len]);
        addr.line1_len = @intCast(len);
        return addr;
    }

    pub fn withCity(self: Address, city: []const u8) Address {
        var addr = self;
        const len = @min(city.len, 64);
        @memcpy(addr.city[0..len], city[0..len]);
        addr.city_len = @intCast(len);
        return addr;
    }

    pub fn withState(self: Address, state: []const u8) Address {
        var addr = self;
        const len = @min(state.len, 64);
        @memcpy(addr.state[0..len], state[0..len]);
        addr.state_len = @intCast(len);
        return addr;
    }

    pub fn withPostalCode(self: Address, postal: []const u8) Address {
        var addr = self;
        const len = @min(postal.len, 16);
        @memcpy(addr.postal_code[0..len], postal[0..len]);
        addr.postal_len = @intCast(len);
        return addr;
    }

    pub fn withCountry(self: Address, code: []const u8) Address {
        var addr = self;
        if (code.len >= 2) {
            addr.country_code[0] = code[0];
            addr.country_code[1] = code[1];
        }
        return addr;
    }

    pub fn isComplete(self: Address) bool {
        return self.line1_len > 0 and
            self.city_len > 0 and
            self.postal_len > 0;
    }
};

/// Transaction status
pub const TransactionStatus = enum {
    pending,
    processing,
    authorized,
    captured,
    completed,
    failed,
    cancelled,
    refunded,
    partially_refunded,
    disputed,

    pub fn isFinal(self: TransactionStatus) bool {
        return switch (self) {
            .completed, .failed, .cancelled, .refunded => true,
            else => false,
        };
    }

    pub fn canRefund(self: TransactionStatus) bool {
        return switch (self) {
            .captured, .completed => true,
            else => false,
        };
    }

    pub fn canCapture(self: TransactionStatus) bool {
        return self == .authorized;
    }
};

/// Payment request
pub const PaymentRequest = struct {
    amount: Money,
    merchant_id: [64]u8,
    merchant_id_len: u8,
    merchant_name: [64]u8,
    merchant_name_len: u8,
    order_id: [64]u8,
    order_id_len: u8,
    description: [256]u8,
    description_len: u16,
    require_billing_address: bool,
    require_shipping_address: bool,
    allowed_networks: u16, // Bitmask of CardNetwork
    supported_providers: u16, // Bitmask of WalletProvider

    pub fn init(amount: Money) PaymentRequest {
        return .{
            .amount = amount,
            .merchant_id = [_]u8{0} ** 64,
            .merchant_id_len = 0,
            .merchant_name = [_]u8{0} ** 64,
            .merchant_name_len = 0,
            .order_id = [_]u8{0} ** 64,
            .order_id_len = 0,
            .description = [_]u8{0} ** 256,
            .description_len = 0,
            .require_billing_address = true,
            .require_shipping_address = false,
            .allowed_networks = 0xFFFF, // All networks
            .supported_providers = 0xFFFF, // All providers
        };
    }

    pub fn withMerchant(self: PaymentRequest, id: []const u8, name: []const u8) PaymentRequest {
        var req = self;
        const id_len = @min(id.len, 64);
        const name_len = @min(name.len, 64);
        @memcpy(req.merchant_id[0..id_len], id[0..id_len]);
        req.merchant_id_len = @intCast(id_len);
        @memcpy(req.merchant_name[0..name_len], name[0..name_len]);
        req.merchant_name_len = @intCast(name_len);
        return req;
    }

    pub fn withOrderId(self: PaymentRequest, order_id: []const u8) PaymentRequest {
        var req = self;
        const len = @min(order_id.len, 64);
        @memcpy(req.order_id[0..len], order_id[0..len]);
        req.order_id_len = @intCast(len);
        return req;
    }

    pub fn withDescription(self: PaymentRequest, desc: []const u8) PaymentRequest {
        var req = self;
        const len = @min(desc.len, 256);
        @memcpy(req.description[0..len], desc[0..len]);
        req.description_len = @intCast(len);
        return req;
    }

    pub fn withShippingRequired(self: PaymentRequest, required: bool) PaymentRequest {
        var req = self;
        req.require_shipping_address = required;
        return req;
    }

    pub fn allowNetwork(self: PaymentRequest, network: CardNetwork) PaymentRequest {
        var req = self;
        req.allowed_networks |= @as(u16, 1) << @intFromEnum(network);
        return req;
    }

    pub fn isNetworkAllowed(self: PaymentRequest, network: CardNetwork) bool {
        return (self.allowed_networks & (@as(u16, 1) << @intFromEnum(network))) != 0;
    }
};

/// Transaction result
pub const Transaction = struct {
    id: [64]u8,
    id_len: u8,
    status: TransactionStatus,
    amount: Money,
    provider: WalletProvider,
    payment_method: PaymentMethodType,
    card_network: ?CardNetwork,
    created_at: i64,
    updated_at: i64,
    error_code: ?[32]u8,
    error_message: ?[128]u8,

    pub fn init(amount: Money, provider: WalletProvider) Transaction {
        const now = getCurrentTimestamp();
        return .{
            .id = [_]u8{0} ** 64,
            .id_len = 0,
            .status = .pending,
            .amount = amount,
            .provider = provider,
            .payment_method = .digital_wallet,
            .card_network = null,
            .created_at = now,
            .updated_at = now,
            .error_code = null,
            .error_message = null,
        };
    }

    pub fn withId(self: Transaction, id: []const u8) Transaction {
        var txn = self;
        const len = @min(id.len, 64);
        @memcpy(txn.id[0..len], id[0..len]);
        txn.id_len = @intCast(len);
        return txn;
    }

    pub fn withStatus(self: Transaction, status: TransactionStatus) Transaction {
        var txn = self;
        txn.status = status;
        txn.updated_at = getCurrentTimestamp();
        return txn;
    }

    pub fn withError(self: Transaction, code: []const u8, message: []const u8) Transaction {
        var txn = self;
        var err_code: [32]u8 = [_]u8{0} ** 32;
        var err_msg: [128]u8 = [_]u8{0} ** 128;
        const code_len = @min(code.len, 32);
        const msg_len = @min(message.len, 128);
        @memcpy(err_code[0..code_len], code[0..code_len]);
        @memcpy(err_msg[0..msg_len], message[0..msg_len]);
        txn.error_code = err_code;
        txn.error_message = err_msg;
        txn.status = .failed;
        return txn;
    }

    pub fn isSuccessful(self: Transaction) bool {
        return self.status == .completed or self.status == .captured;
    }

    pub fn canRetry(self: Transaction) bool {
        return self.status == .failed and self.error_code != null;
    }
};

/// Subscription/recurring payment
pub const Subscription = struct {
    id: [64]u8,
    id_len: u8,
    plan_id: [64]u8,
    plan_id_len: u8,
    amount: Money,
    interval: BillingInterval,
    interval_count: u8,
    status: SubscriptionStatus,
    current_period_start: i64,
    current_period_end: i64,
    trial_end: ?i64,
    cancel_at_period_end: bool,

    pub const BillingInterval = enum {
        day,
        week,
        month,
        year,

        pub fn toDays(self: BillingInterval) u16 {
            return switch (self) {
                .day => 1,
                .week => 7,
                .month => 30,
                .year => 365,
            };
        }
    };

    pub const SubscriptionStatus = enum {
        trialing,
        active,
        past_due,
        paused,
        cancelled,
        expired,

        pub fn isActive(self: SubscriptionStatus) bool {
            return self == .trialing or self == .active;
        }
    };

    pub fn init(amount: Money, interval: BillingInterval) Subscription {
        const now = getCurrentTimestamp();
        const period_days: i64 = interval.toDays();
        return .{
            .id = [_]u8{0} ** 64,
            .id_len = 0,
            .plan_id = [_]u8{0} ** 64,
            .plan_id_len = 0,
            .amount = amount,
            .interval = interval,
            .interval_count = 1,
            .status = .active,
            .current_period_start = now,
            .current_period_end = now + (period_days * 86400),
            .trial_end = null,
            .cancel_at_period_end = false,
        };
    }

    pub fn withTrial(self: Subscription, days: u16) Subscription {
        var sub = self;
        sub.status = .trialing;
        sub.trial_end = self.current_period_start + (@as(i64, days) * 86400);
        return sub;
    }

    pub fn isInTrial(self: Subscription) bool {
        if (self.trial_end) |trial_end| {
            var ts: std.c.timespec = undefined;
            if (std.c.clock_gettime(.REALTIME, &ts) != 0) return false;
            return ts.sec < trial_end;
        }
        return false;
    }

    pub fn daysUntilRenewal(self: Subscription) i64 {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) != 0) return 0;
        const diff = self.current_period_end - ts.sec;
        return @divFloor(diff, 86400);
    }
};

/// Wallet controller for managing payments
pub const WalletController = struct {
    available_providers: u16,
    default_provider: ?WalletProvider,
    saved_cards_count: u8,
    saved_cards: [8]PaymentCard,
    region: [2]u8,

    pub fn init() WalletController {
        return .{
            .available_providers = 0,
            .default_provider = null,
            .saved_cards_count = 0,
            .saved_cards = [_]PaymentCard{PaymentCard.init()} ** 8,
            .region = [_]u8{ 'U', 'S' },
        };
    }

    pub fn checkAvailability(self: *WalletController) void {
        // In real implementation, would check platform capabilities
        self.available_providers = 0;

        // Simulate checking availability
        self.available_providers |= @as(u16, 1) << @intFromEnum(WalletProvider.apple_pay);
        self.available_providers |= @as(u16, 1) << @intFromEnum(WalletProvider.google_pay);
        self.available_providers |= @as(u16, 1) << @intFromEnum(WalletProvider.stripe);
        self.available_providers |= @as(u16, 1) << @intFromEnum(WalletProvider.paypal);
    }

    pub fn isProviderAvailable(self: WalletController, provider: WalletProvider) bool {
        return (self.available_providers & (@as(u16, 1) << @intFromEnum(provider))) != 0;
    }

    pub fn setDefaultProvider(self: *WalletController, provider: WalletProvider) bool {
        if (self.isProviderAvailable(provider)) {
            self.default_provider = provider;
            return true;
        }
        return false;
    }

    pub fn addCard(self: *WalletController, card: PaymentCard) bool {
        if (self.saved_cards_count >= 8) return false;
        self.saved_cards[self.saved_cards_count] = card;
        self.saved_cards_count += 1;
        return true;
    }

    pub fn removeCard(self: *WalletController, index: u8) bool {
        if (index >= self.saved_cards_count) return false;

        // Shift remaining cards
        var i: u8 = index;
        while (i < self.saved_cards_count - 1) : (i += 1) {
            self.saved_cards[i] = self.saved_cards[i + 1];
        }
        self.saved_cards_count -= 1;
        return true;
    }

    pub fn getValidCards(self: WalletController) []const PaymentCard {
        // Return slice of non-expired cards
        var valid_count: u8 = 0;
        for (self.saved_cards[0..self.saved_cards_count]) |card| {
            if (!card.isExpired()) {
                valid_count += 1;
            }
        }
        return self.saved_cards[0..valid_count];
    }

    pub fn createPaymentRequest(self: WalletController, amount: Money) PaymentRequest {
        var req = PaymentRequest.init(amount);
        req.supported_providers = self.available_providers;
        return req;
    }

    pub fn processPayment(self: WalletController, request: PaymentRequest, provider: WalletProvider) Transaction {
        _ = self;
        var txn = Transaction.init(request.amount, provider);

        // Simulate payment processing
        if (request.amount.isPositive()) {
            txn = txn.withStatus(.processing);
            // In real implementation, would call native payment APIs
            txn = txn.withStatus(.completed);
            txn = txn.withId("txn_simulated_12345");
        } else {
            txn = txn.withError("INVALID_AMOUNT", "Amount must be positive");
        }

        return txn;
    }
};

/// Receipt information
pub const Receipt = struct {
    transaction_id: [64]u8,
    transaction_id_len: u8,
    merchant_name: [64]u8,
    merchant_name_len: u8,
    items: [16]LineItem,
    item_count: u8,
    subtotal: Money,
    tax: Money,
    total: Money,
    timestamp: i64,

    pub const LineItem = struct {
        name: [64]u8,
        name_len: u8,
        quantity: u16,
        unit_price: Money,

        pub fn init(name: []const u8, quantity: u16, price: Money) LineItem {
            var item: LineItem = .{
                .name = [_]u8{0} ** 64,
                .name_len = 0,
                .quantity = quantity,
                .unit_price = price,
            };
            const len = @min(name.len, 64);
            @memcpy(item.name[0..len], name[0..len]);
            item.name_len = @intCast(len);
            return item;
        }

        pub fn total(self: LineItem) Money {
            return self.unit_price.multiply(@floatFromInt(self.quantity));
        }
    };

    pub fn init(transaction: Transaction) Receipt {
        var receipt: Receipt = .{
            .transaction_id = [_]u8{0} ** 64,
            .transaction_id_len = 0,
            .merchant_name = [_]u8{0} ** 64,
            .merchant_name_len = 0,
            .items = undefined,
            .item_count = 0,
            .subtotal = Money{ .amount = 0, .currency = transaction.amount.currency },
            .tax = Money{ .amount = 0, .currency = transaction.amount.currency },
            .total = transaction.amount,
            .timestamp = getCurrentTimestamp(),
        };
        @memcpy(receipt.transaction_id[0..transaction.id_len], transaction.id[0..transaction.id_len]);
        receipt.transaction_id_len = transaction.id_len;
        return receipt;
    }

    pub fn addItem(self: *Receipt, item: LineItem) bool {
        if (self.item_count >= 16) return false;
        self.items[self.item_count] = item;
        self.item_count += 1;
        return true;
    }

    pub fn calculateSubtotal(self: *Receipt) void {
        var total_amount: i64 = 0;
        for (self.items[0..self.item_count]) |item| {
            total_amount += item.total().amount;
        }
        self.subtotal.amount = total_amount;
    }
};

/// Check if wallet payments are supported on this platform
pub fn isSupported() bool {
    const builtin = @import("builtin");
    return switch (builtin.os.tag) {
        .macos, .ios => true, // Apple Pay
        .linux => true, // Google Pay via web
        .windows => true, // Various providers
        else => false,
    };
}

// Tests
test "WalletProvider properties" {
    const apple = WalletProvider.apple_pay;
    try std.testing.expectEqualStrings("Apple Pay", apple.displayName());
    try std.testing.expect(apple.supportsRecurring());
    try std.testing.expect(apple.supportedRegions().len > 0);
}

test "PaymentMethodType verification" {
    try std.testing.expect(PaymentMethodType.bank_account.requiresVerification());
    try std.testing.expect(PaymentMethodType.crypto.requiresVerification());
    try std.testing.expect(!PaymentMethodType.credit_card.requiresVerification());
}

test "CardNetwork properties" {
    try std.testing.expectEqual(@as(u8, 15), CardNetwork.amex.cardNumberLength());
    try std.testing.expectEqual(@as(u8, 16), CardNetwork.visa.cardNumberLength());
    try std.testing.expectEqual(@as(u8, 4), CardNetwork.amex.cvvLength());
    try std.testing.expectEqual(@as(u8, 3), CardNetwork.visa.cvvLength());
}

test "CurrencyCode properties" {
    try std.testing.expectEqualStrings("$", CurrencyCode.usd.symbol());
    try std.testing.expectEqualStrings("USD", CurrencyCode.usd.code());
    try std.testing.expectEqual(@as(u8, 2), CurrencyCode.usd.minorUnits());
    try std.testing.expectEqual(@as(u8, 0), CurrencyCode.jpy.minorUnits());
}

test "Money from major units" {
    const money = Money.fromMajor(19.99, .usd);
    try std.testing.expectEqual(@as(i64, 1999), money.amount);
    try std.testing.expectEqual(CurrencyCode.usd, money.currency);
}

test "Money to major units" {
    const money = Money{ .amount = 1999, .currency = .usd };
    const major = money.toMajor();
    try std.testing.expectApproxEqAbs(@as(f64, 19.99), major, 0.001);
}

test "Money arithmetic" {
    const a = Money{ .amount = 1000, .currency = .usd };
    const b = Money{ .amount = 500, .currency = .usd };

    const sum = a.add(b).?;
    try std.testing.expectEqual(@as(i64, 1500), sum.amount);

    const diff = a.subtract(b).?;
    try std.testing.expectEqual(@as(i64, 500), diff.amount);

    const doubled = a.multiply(2.0);
    try std.testing.expectEqual(@as(i64, 2000), doubled.amount);
}

test "Money different currencies" {
    const usd = Money{ .amount = 1000, .currency = .usd };
    const eur = Money{ .amount = 1000, .currency = .eur };
    try std.testing.expect(usd.add(eur) == null);
}

test "PaymentCard initialization" {
    const card = PaymentCard.init();
    try std.testing.expectEqual(CardNetwork.unknown, card.network);
    try std.testing.expectEqual(@as(u8, 0), card.token_len);
}

test "PaymentCard builder" {
    const card = PaymentCard.init()
        .withToken("tok_test_123")
        .withLastFour("4242")
        .withExpiry(12, 2030)
        .withNetwork(.visa);

    try std.testing.expectEqual(CardNetwork.visa, card.network);
    try std.testing.expectEqual(@as(u8, 12), card.expiry_month);
    try std.testing.expectEqual(@as(u16, 2030), card.expiry_year);
    try std.testing.expectEqualStrings("4242", &card.last_four);
}

test "PaymentCard expiry check" {
    const expired_card = PaymentCard.init().withExpiry(1, 2020);
    try std.testing.expect(expired_card.isExpired());

    const valid_card = PaymentCard.init().withExpiry(12, 2030);
    try std.testing.expect(!valid_card.isExpired());
}

test "PaymentCard masked display" {
    const card = PaymentCard.init().withLastFour("4242");
    const display = card.maskedDisplay();
    try std.testing.expectEqualStrings("4242", display[15..19]);
}

test "Address builder" {
    const addr = Address.init()
        .withLine1("123 Main St")
        .withCity("San Francisco")
        .withState("CA")
        .withPostalCode("94102")
        .withCountry("US");

    try std.testing.expect(addr.isComplete());
    try std.testing.expectEqualStrings("US", &addr.country_code);
}

test "Address incomplete" {
    const addr = Address.init().withLine1("123 Main St");
    try std.testing.expect(!addr.isComplete());
}

test "TransactionStatus properties" {
    try std.testing.expect(TransactionStatus.completed.isFinal());
    try std.testing.expect(!TransactionStatus.pending.isFinal());
    try std.testing.expect(TransactionStatus.completed.canRefund());
    try std.testing.expect(TransactionStatus.authorized.canCapture());
}

test "PaymentRequest initialization" {
    const amount = Money.fromMajor(99.99, .usd);
    const req = PaymentRequest.init(amount);

    try std.testing.expectEqual(@as(i64, 9999), req.amount.amount);
    try std.testing.expect(req.require_billing_address);
    try std.testing.expect(!req.require_shipping_address);
}

test "PaymentRequest builder" {
    const amount = Money.fromMajor(49.99, .usd);
    const req = PaymentRequest.init(amount)
        .withMerchant("merch_123", "Test Store")
        .withOrderId("order_456")
        .withDescription("Test purchase")
        .withShippingRequired(true);

    try std.testing.expect(req.require_shipping_address);
    try std.testing.expect(req.order_id_len > 0);
}

test "PaymentRequest network filtering" {
    const amount = Money.fromMajor(10.0, .usd);
    var req = PaymentRequest.init(amount);
    req.allowed_networks = 0; // Clear all

    req = req.allowNetwork(.visa).allowNetwork(.mastercard);
    try std.testing.expect(req.isNetworkAllowed(.visa));
    try std.testing.expect(req.isNetworkAllowed(.mastercard));
    try std.testing.expect(!req.isNetworkAllowed(.amex));
}

test "Transaction initialization" {
    const amount = Money.fromMajor(25.0, .usd);
    const txn = Transaction.init(amount, .apple_pay);

    try std.testing.expectEqual(TransactionStatus.pending, txn.status);
    try std.testing.expectEqual(WalletProvider.apple_pay, txn.provider);
}

test "Transaction status updates" {
    const amount = Money.fromMajor(25.0, .usd);
    var txn = Transaction.init(amount, .google_pay);
    txn = txn.withStatus(.processing);

    try std.testing.expectEqual(TransactionStatus.processing, txn.status);

    txn = txn.withStatus(.completed);
    try std.testing.expect(txn.isSuccessful());
}

test "Transaction error handling" {
    const amount = Money.fromMajor(25.0, .usd);
    var txn = Transaction.init(amount, .stripe);
    txn = txn.withError("CARD_DECLINED", "Insufficient funds");

    try std.testing.expectEqual(TransactionStatus.failed, txn.status);
    try std.testing.expect(txn.error_code != null);
    try std.testing.expect(txn.canRetry());
}

test "Subscription initialization" {
    const amount = Money.fromMajor(9.99, .usd);
    const sub = Subscription.init(amount, .month);

    try std.testing.expectEqual(Subscription.SubscriptionStatus.active, sub.status);
    try std.testing.expectEqual(Subscription.BillingInterval.month, sub.interval);
}

test "Subscription with trial" {
    const amount = Money.fromMajor(9.99, .usd);
    const sub = Subscription.init(amount, .month).withTrial(14);

    try std.testing.expectEqual(Subscription.SubscriptionStatus.trialing, sub.status);
    try std.testing.expect(sub.trial_end != null);
}

test "BillingInterval to days" {
    try std.testing.expectEqual(@as(u16, 1), Subscription.BillingInterval.day.toDays());
    try std.testing.expectEqual(@as(u16, 7), Subscription.BillingInterval.week.toDays());
    try std.testing.expectEqual(@as(u16, 30), Subscription.BillingInterval.month.toDays());
    try std.testing.expectEqual(@as(u16, 365), Subscription.BillingInterval.year.toDays());
}

test "WalletController initialization" {
    const controller = WalletController.init();
    try std.testing.expectEqual(@as(u8, 0), controller.saved_cards_count);
    try std.testing.expect(controller.default_provider == null);
}

test "WalletController availability check" {
    var controller = WalletController.init();
    controller.checkAvailability();

    try std.testing.expect(controller.isProviderAvailable(.apple_pay));
    try std.testing.expect(controller.isProviderAvailable(.stripe));
}

test "WalletController add/remove cards" {
    var controller = WalletController.init();
    const card = PaymentCard.init().withLastFour("1234").withNetwork(.visa);

    try std.testing.expect(controller.addCard(card));
    try std.testing.expectEqual(@as(u8, 1), controller.saved_cards_count);

    try std.testing.expect(controller.removeCard(0));
    try std.testing.expectEqual(@as(u8, 0), controller.saved_cards_count);
}

test "WalletController set default provider" {
    var controller = WalletController.init();
    controller.checkAvailability();

    try std.testing.expect(controller.setDefaultProvider(.apple_pay));
    try std.testing.expectEqual(WalletProvider.apple_pay, controller.default_provider.?);
}

test "WalletController process payment" {
    var controller = WalletController.init();
    controller.checkAvailability();

    const amount = Money.fromMajor(50.0, .usd);
    const request = controller.createPaymentRequest(amount);
    const txn = controller.processPayment(request, .stripe);

    try std.testing.expectEqual(TransactionStatus.completed, txn.status);
    try std.testing.expect(txn.isSuccessful());
}

test "Receipt creation" {
    const amount = Money.fromMajor(100.0, .usd);
    const txn = Transaction.init(amount, .apple_pay).withId("txn_123");
    const receipt = Receipt.init(txn);

    try std.testing.expectEqual(@as(i64, 10000), receipt.total.amount);
}

test "Receipt line items" {
    const amount = Money.fromMajor(100.0, .usd);
    const txn = Transaction.init(amount, .apple_pay);
    var receipt = Receipt.init(txn);

    const item = Receipt.LineItem.init("Widget", 2, Money.fromMajor(25.0, .usd));
    try std.testing.expect(receipt.addItem(item));

    receipt.calculateSubtotal();
    try std.testing.expectEqual(@as(i64, 5000), receipt.subtotal.amount); // 2 * 25.00
}

test "isSupported" {
    // Should return true on common platforms
    const supported = isSupported();
    try std.testing.expect(supported);
}
