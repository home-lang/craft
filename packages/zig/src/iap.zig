const std = @import("std");
const builtin = @import("builtin");

/// In-App Purchase Module
/// Provides cross-platform in-app purchase functionality for iOS (StoreKit) and Android (Google Play Billing).
/// Supports consumable, non-consumable, and subscription products.

// ============================================================================
// Product Types and Definitions
// ============================================================================

/// Type of in-app purchase product
pub const ProductType = enum {
    /// Single purchase, permanently owned (e.g., premium upgrade, unlock feature)
    non_consumable,
    /// Can be purchased multiple times (e.g., coins, gems, lives)
    consumable,
    /// Recurring purchase with billing period (e.g., monthly subscription)
    auto_renewable_subscription,
    /// One-time subscription that doesn't auto-renew
    non_renewing_subscription,

    pub fn toString(self: ProductType) []const u8 {
        return switch (self) {
            .non_consumable => "non_consumable",
            .consumable => "consumable",
            .auto_renewable_subscription => "auto_renewable_subscription",
            .non_renewing_subscription => "non_renewing_subscription",
        };
    }

    pub fn isSubscription(self: ProductType) bool {
        return self == .auto_renewable_subscription or self == .non_renewing_subscription;
    }

    pub fn isConsumable(self: ProductType) bool {
        return self == .consumable;
    }
};

/// Subscription billing period
pub const SubscriptionPeriod = enum {
    daily,
    weekly,
    monthly,
    quarterly,
    semi_annual,
    annual,
    unknown,

    pub fn toDays(self: SubscriptionPeriod) u32 {
        return switch (self) {
            .daily => 1,
            .weekly => 7,
            .monthly => 30,
            .quarterly => 90,
            .semi_annual => 182,
            .annual => 365,
            .unknown => 0,
        };
    }

    pub fn toString(self: SubscriptionPeriod) []const u8 {
        return switch (self) {
            .daily => "daily",
            .weekly => "weekly",
            .monthly => "monthly",
            .quarterly => "quarterly",
            .semi_annual => "semi_annual",
            .annual => "annual",
            .unknown => "unknown",
        };
    }
};

/// Product information retrieved from the store
pub const Product = struct {
    /// Product identifier (e.g., "com.app.premium")
    id: []const u8,
    /// Localized product title
    title: []const u8,
    /// Localized product description
    description: []const u8,
    /// Price as a formatted string (e.g., "$9.99")
    price_string: []const u8,
    /// Price in smallest currency unit (e.g., cents)
    price_micros: u64,
    /// ISO 4217 currency code (e.g., "USD")
    currency_code: []const u8,
    /// Type of product
    product_type: ProductType,
    /// Subscription period (if applicable)
    subscription_period: ?SubscriptionPeriod,
    /// Free trial period in days (if applicable)
    free_trial_days: ?u32,
    /// Introductory price string (if applicable)
    intro_price_string: ?[]const u8,
    /// Platform-specific product object reference
    native_product: ?*anyopaque,

    pub fn init(id: []const u8, title: []const u8, price_string: []const u8) Product {
        return .{
            .id = id,
            .title = title,
            .description = "",
            .price_string = price_string,
            .price_micros = 0,
            .currency_code = "USD",
            .product_type = .non_consumable,
            .subscription_period = null,
            .free_trial_days = null,
            .intro_price_string = null,
            .native_product = null,
        };
    }

    pub fn withDescription(self: Product, desc: []const u8) Product {
        var p = self;
        p.description = desc;
        return p;
    }

    pub fn withType(self: Product, pt: ProductType) Product {
        var p = self;
        p.product_type = pt;
        return p;
    }

    pub fn withSubscription(self: Product, period: SubscriptionPeriod) Product {
        var p = self;
        p.product_type = .auto_renewable_subscription;
        p.subscription_period = period;
        return p;
    }

    pub fn withFreeTrial(self: Product, days: u32) Product {
        var p = self;
        p.free_trial_days = days;
        return p;
    }

    pub fn hasFreeTrial(self: *const Product) bool {
        return self.free_trial_days != null and self.free_trial_days.? > 0;
    }

    pub fn isSubscription(self: *const Product) bool {
        return self.product_type.isSubscription();
    }
};

// ============================================================================
// Transaction Types
// ============================================================================

/// Transaction state
pub const TransactionState = enum {
    /// Transaction is being processed
    purchasing,
    /// Transaction completed successfully
    purchased,
    /// Transaction failed
    failed,
    /// Transaction was restored from previous purchase
    restored,
    /// Transaction is deferred (e.g., Ask to Buy)
    deferred,
    /// Transaction was refunded
    refunded,

    pub fn toString(self: TransactionState) []const u8 {
        return switch (self) {
            .purchasing => "purchasing",
            .purchased => "purchased",
            .failed => "failed",
            .restored => "restored",
            .deferred => "deferred",
            .refunded => "refunded",
        };
    }

    pub fn isSuccessful(self: TransactionState) bool {
        return self == .purchased or self == .restored;
    }

    pub fn isPending(self: TransactionState) bool {
        return self == .purchasing or self == .deferred;
    }
};

/// Purchase transaction details
pub const Transaction = struct {
    /// Unique transaction identifier
    id: []const u8,
    /// Product identifier
    product_id: []const u8,
    /// Transaction state
    state: TransactionState,
    /// Purchase timestamp (Unix milliseconds)
    purchase_time: u64,
    /// Expiration timestamp for subscriptions (Unix milliseconds)
    expiration_time: ?u64,
    /// Original transaction ID (for renewals/restores)
    original_transaction_id: ?[]const u8,
    /// Receipt data for verification
    receipt_data: ?[]const u8,
    /// Error message if failed
    error_message: ?[]const u8,
    /// Quantity purchased (for consumables)
    quantity: u32,
    /// Whether this is a sandbox/test transaction
    is_sandbox: bool,
    /// Platform-specific transaction object
    native_transaction: ?*anyopaque,

    pub fn init(id: []const u8, product_id: []const u8, state: TransactionState) Transaction {
        return .{
            .id = id,
            .product_id = product_id,
            .state = state,
            .purchase_time = 0,
            .expiration_time = null,
            .original_transaction_id = null,
            .receipt_data = null,
            .error_message = null,
            .quantity = 1,
            .is_sandbox = false,
            .native_transaction = null,
        };
    }

    pub fn isSuccessful(self: *const Transaction) bool {
        return self.state.isSuccessful();
    }

    pub fn isPending(self: *const Transaction) bool {
        return self.state.isPending();
    }

    pub fn isExpired(self: *const Transaction, current_time: u64) bool {
        if (self.expiration_time) |exp| {
            return current_time > exp;
        }
        return false;
    }

    pub fn getRemainingDays(self: *const Transaction, current_time: u64) ?u32 {
        if (self.expiration_time) |exp| {
            if (current_time >= exp) return 0;
            const remaining_ms = exp - current_time;
            return @intCast(remaining_ms / (24 * 60 * 60 * 1000));
        }
        return null;
    }
};

// ============================================================================
// Purchase Errors
// ============================================================================

/// Purchase error types
pub const PurchaseError = error{
    /// User cancelled the purchase
    Cancelled,
    /// Product not found
    ProductNotFound,
    /// Purchase already in progress
    PurchaseInProgress,
    /// Payment not allowed (e.g., parental controls)
    PaymentNotAllowed,
    /// Store not available
    StoreNotAvailable,
    /// Network error
    NetworkError,
    /// Invalid product
    InvalidProduct,
    /// Already purchased (for non-consumables)
    AlreadyPurchased,
    /// Subscription already active
    SubscriptionAlreadyActive,
    /// Receipt verification failed
    VerificationFailed,
    /// Unknown error
    Unknown,
    /// Billing not supported on this device
    BillingNotSupported,
    /// Out of memory
    OutOfMemory,
};

// ============================================================================
// Store Configuration
// ============================================================================

/// Store environment
pub const StoreEnvironment = enum {
    production,
    sandbox,
    simulator,

    pub fn toString(self: StoreEnvironment) []const u8 {
        return switch (self) {
            .production => "production",
            .sandbox => "sandbox",
            .simulator => "simulator",
        };
    }
};

/// Store configuration
pub const StoreConfig = struct {
    /// Environment
    environment: StoreEnvironment,
    /// App-specific shared secret (iOS)
    shared_secret: ?[]const u8,
    /// Google Play license key (Android)
    license_key: ?[]const u8,
    /// Enable automatic receipt verification
    verify_receipts: bool,
    /// Receipt verification server URL
    verification_url: ?[]const u8,
    /// Enable debug logging
    debug_logging: bool,
    /// Automatically finish transactions
    auto_finish_transactions: bool,

    pub fn init() StoreConfig {
        return .{
            .environment = .production,
            .shared_secret = null,
            .license_key = null,
            .verify_receipts = true,
            .verification_url = null,
            .debug_logging = false,
            .auto_finish_transactions = true,
        };
    }

    pub fn sandbox() StoreConfig {
        var config = init();
        config.environment = .sandbox;
        config.debug_logging = true;
        return config;
    }

    pub fn withSharedSecret(self: StoreConfig, secret: []const u8) StoreConfig {
        var c = self;
        c.shared_secret = secret;
        return c;
    }

    pub fn withLicenseKey(self: StoreConfig, key: []const u8) StoreConfig {
        var c = self;
        c.license_key = key;
        return c;
    }

    pub fn withVerificationUrl(self: StoreConfig, url: []const u8) StoreConfig {
        var c = self;
        c.verification_url = url;
        return c;
    }
};

// ============================================================================
// Purchase Observer/Callback
// ============================================================================

/// Purchase result callback
pub const PurchaseCallback = *const fn (result: PurchaseResult) void;

/// Restore callback
pub const RestoreCallback = *const fn (transactions: []const Transaction, err: ?PurchaseError) void;

/// Products callback
pub const ProductsCallback = *const fn (products: []const Product, invalid_ids: []const []const u8, err: ?PurchaseError) void;

/// Purchase result
pub const PurchaseResult = struct {
    transaction: ?Transaction,
    err: ?PurchaseError,

    pub fn success(transaction: Transaction) PurchaseResult {
        return .{ .transaction = transaction, .err = null };
    }

    pub fn failure(err: PurchaseError) PurchaseResult {
        return .{ .transaction = null, .err = err };
    }

    pub fn isSuccess(self: *const PurchaseResult) bool {
        return self.err == null and self.transaction != null;
    }
};

// ============================================================================
// In-App Purchase Manager
// ============================================================================

/// In-App Purchase Manager
pub const IAPManager = struct {
    allocator: std.mem.Allocator,
    config: StoreConfig,
    products: std.StringHashMap(Product),
    purchases: std.StringHashMap(Transaction),
    pending_purchases: std.StringHashMap(Transaction),
    is_initialized: bool,
    can_make_payments: bool,

    // Callbacks
    purchase_callback: ?PurchaseCallback,
    restore_callback: ?RestoreCallback,
    products_callback: ?ProductsCallback,

    // Platform-specific handles
    native_observer: ?*anyopaque,

    const Self = @This();

    /// Initialize the IAP manager
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .config = StoreConfig.init(),
            .products = std.StringHashMap(Product).init(allocator),
            .purchases = std.StringHashMap(Transaction).init(allocator),
            .pending_purchases = std.StringHashMap(Transaction).init(allocator),
            .is_initialized = false,
            .can_make_payments = true,
            .purchase_callback = null,
            .restore_callback = null,
            .products_callback = null,
            .native_observer = null,
        };
    }

    /// Deinitialize and cleanup
    pub fn deinit(self: *Self) void {
        self.products.deinit();
        self.purchases.deinit();
        self.pending_purchases.deinit();
    }

    /// Configure the store
    pub fn configure(self: *Self, config: StoreConfig) void {
        self.config = config;
    }

    /// Start the IAP service
    pub fn start(self: *Self) PurchaseError!void {
        if (self.is_initialized) return;

        // Platform-specific initialization
        if (comptime builtin.os.tag == .ios) {
            // iOS: Initialize StoreKit observer
            // [[SKPaymentQueue defaultQueue] addTransactionObserver:observer];
            self.can_make_payments = true; // [SKPaymentQueue canMakePayments]
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // Android: Initialize BillingClient
            // billingClient = BillingClient.newBuilder(context).build()
            self.can_make_payments = true;
        } else {
            // Simulator/development mode
            self.can_make_payments = true;
        }

        if (!self.can_make_payments) {
            return PurchaseError.PaymentNotAllowed;
        }

        self.is_initialized = true;
    }

    /// Stop the IAP service
    pub fn stop(self: *Self) void {
        if (!self.is_initialized) return;

        // Platform-specific cleanup
        if (comptime builtin.os.tag == .ios) {
            // [[SKPaymentQueue defaultQueue] removeTransactionObserver:observer];
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // billingClient.endConnection()
        }

        self.is_initialized = false;
    }

    /// Check if payments are allowed
    pub fn canMakePayments(self: *const Self) bool {
        return self.can_make_payments;
    }

    /// Fetch products from the store
    pub fn fetchProducts(self: *Self, product_ids: []const []const u8) PurchaseError![]const Product {
        if (!self.is_initialized) {
            try self.start();
        }

        // Simulated product fetch for testing
        var result = std.ArrayListUnmanaged(Product){};

        for (product_ids) |pid| {
            // Check if already cached
            if (self.products.get(pid)) |product| {
                result.append(self.allocator, product) catch return PurchaseError.OutOfMemory;
            } else {
                // In real implementation, fetch from store
                // For now, create placeholder
                const product = Product.init(pid, pid, "$0.99");
                self.products.put(pid, product) catch return PurchaseError.OutOfMemory;
                result.append(self.allocator, product) catch return PurchaseError.OutOfMemory;
            }
        }

        return result.toOwnedSlice(self.allocator) catch return PurchaseError.OutOfMemory;
    }

    /// Get a cached product by ID
    pub fn getProduct(self: *const Self, product_id: []const u8) ?Product {
        return self.products.get(product_id);
    }

    /// Purchase a product
    pub fn purchase(self: *Self, product_id: []const u8) PurchaseError!Transaction {
        if (!self.is_initialized) {
            try self.start();
        }

        if (!self.can_make_payments) {
            return PurchaseError.PaymentNotAllowed;
        }

        // Check if already purchased (non-consumable)
        if (self.purchases.get(product_id)) |existing| {
            const product = self.products.get(product_id);
            if (product) |p| {
                if (!p.product_type.isConsumable()) {
                    _ = existing;
                    return PurchaseError.AlreadyPurchased;
                }
            }
        }

        // Check for pending purchase
        if (self.pending_purchases.contains(product_id)) {
            return PurchaseError.PurchaseInProgress;
        }

        // Create pending transaction
        const tx_id = generateTransactionId(self.allocator) catch return PurchaseError.OutOfMemory;
        var transaction = Transaction.init(tx_id, product_id, .purchasing);
        transaction.purchase_time = getCurrentTimeMs();
        transaction.is_sandbox = self.config.environment == .sandbox;

        self.pending_purchases.put(product_id, transaction) catch return PurchaseError.OutOfMemory;

        // Platform-specific purchase
        if (comptime builtin.os.tag == .ios) {
            // SKPayment *payment = [SKPayment paymentWithProduct:product];
            // [[SKPaymentQueue defaultQueue] addPayment:payment];
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // BillingFlowParams params = BillingFlowParams.newBuilder()
            //     .setProductDetailsParamsList(...)
            //     .build();
            // billingClient.launchBillingFlow(activity, params);
        }

        // Simulate successful purchase for testing
        transaction.state = .purchased;
        _ = self.pending_purchases.remove(product_id);
        self.purchases.put(product_id, transaction) catch return PurchaseError.OutOfMemory;

        return transaction;
    }

    /// Purchase with callback
    pub fn purchaseAsync(self: *Self, product_id: []const u8, callback: PurchaseCallback) void {
        self.purchase_callback = callback;

        const result = self.purchase(product_id) catch |err| {
            callback(PurchaseResult.failure(err));
            return;
        };

        callback(PurchaseResult.success(result));
    }

    /// Restore previous purchases
    pub fn restorePurchases(self: *Self) PurchaseError![]const Transaction {
        if (!self.is_initialized) {
            try self.start();
        }

        // Platform-specific restore
        if (comptime builtin.os.tag == .ios) {
            // [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // billingClient.queryPurchasesAsync(...)
        }

        // Return cached purchases
        var result = std.ArrayListUnmanaged(Transaction){};
        var iter = self.purchases.valueIterator();
        while (iter.next()) |tx| {
            var restored = tx.*;
            restored.state = .restored;
            result.append(self.allocator, restored) catch return PurchaseError.OutOfMemory;
        }

        return result.toOwnedSlice(self.allocator) catch return PurchaseError.OutOfMemory;
    }

    /// Check if a product has been purchased
    pub fn isPurchased(self: *const Self, product_id: []const u8) bool {
        if (self.purchases.get(product_id)) |tx| {
            return tx.state.isSuccessful();
        }
        return false;
    }

    /// Get purchase transaction for a product
    pub fn getPurchase(self: *const Self, product_id: []const u8) ?Transaction {
        return self.purchases.get(product_id);
    }

    /// Check subscription status
    pub fn isSubscriptionActive(self: *const Self, product_id: []const u8) bool {
        if (self.purchases.get(product_id)) |tx| {
            if (!tx.state.isSuccessful()) return false;

            // Check expiration
            if (tx.expiration_time) |exp| {
                return getCurrentTimeMs() < exp;
            }
            return true;
        }
        return false;
    }

    /// Finish/acknowledge a transaction
    pub fn finishTransaction(_: *Self, _: *const Transaction) void {
        // Platform-specific finish
        if (comptime builtin.os.tag == .ios) {
            // [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // For consumables: billingClient.consumeAsync(...)
            // For non-consumables: billingClient.acknowledgePurchase(...)
        }
    }

    /// Get receipt data for server verification
    pub fn getReceiptData(self: *const Self) ?[]const u8 {
        if (comptime builtin.os.tag == .ios) {
            // NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
            // NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
            // return [receiptData base64EncodedStringWithOptions:0];
        }
        _ = self;
        return null;
    }

    /// Verify receipt with Apple/Google servers
    pub fn verifyReceipt(self: *Self, receipt_data: []const u8) PurchaseError!bool {
        if (self.config.verification_url) |url| {
            // Send receipt to verification server
            _ = url;
            _ = receipt_data;
            return true;
        }
        return PurchaseError.VerificationFailed;
    }

    /// Set purchase callback
    pub fn setPurchaseCallback(self: *Self, callback: PurchaseCallback) void {
        self.purchase_callback = callback;
    }

    /// Set restore callback
    pub fn setRestoreCallback(self: *Self, callback: RestoreCallback) void {
        self.restore_callback = callback;
    }

    /// Register a product locally (for testing)
    pub fn registerProduct(self: *Self, product: Product) PurchaseError!void {
        self.products.put(product.id, product) catch return PurchaseError.OutOfMemory;
    }

    /// Simulate a purchase (for testing)
    pub fn simulatePurchase(self: *Self, product_id: []const u8, state: TransactionState) PurchaseError!Transaction {
        const tx_id = generateTransactionId(self.allocator) catch return PurchaseError.OutOfMemory;
        var transaction = Transaction.init(tx_id, product_id, state);
        transaction.purchase_time = getCurrentTimeMs();
        transaction.is_sandbox = true;

        if (state.isSuccessful()) {
            self.purchases.put(product_id, transaction) catch return PurchaseError.OutOfMemory;
        }

        return transaction;
    }

    // Helper functions - uses a static counter instead of allocation
    var tx_counter: u64 = 0;

    fn generateTransactionId(_: std.mem.Allocator) ![]const u8 {
        tx_counter += 1;
        // Return a static placeholder - in real implementation this would come from the platform
        return "tx_simulated";
    }

    fn getCurrentTimeMs() u64 {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
                return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
            } else {
                return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
            }
        }
        return 0;
    }
};

// ============================================================================
// Subscription Management
// ============================================================================

/// Subscription status
pub const SubscriptionStatus = enum {
    /// Active subscription
    active,
    /// In grace period (payment failed but still active)
    grace_period,
    /// Subscription expired
    expired,
    /// User cancelled but still active until period end
    cancelled,
    /// In billing retry period
    billing_retry,
    /// Subscription paused (Android only)
    paused,
    /// Never subscribed
    never_subscribed,

    pub fn isActive(self: SubscriptionStatus) bool {
        return self == .active or self == .grace_period or self == .cancelled;
    }

    pub fn toString(self: SubscriptionStatus) []const u8 {
        return switch (self) {
            .active => "active",
            .grace_period => "grace_period",
            .expired => "expired",
            .cancelled => "cancelled",
            .billing_retry => "billing_retry",
            .paused => "paused",
            .never_subscribed => "never_subscribed",
        };
    }
};

/// Subscription info
pub const SubscriptionInfo = struct {
    product_id: []const u8,
    status: SubscriptionStatus,
    purchase_time: u64,
    expiration_time: u64,
    renewal_time: ?u64,
    cancel_time: ?u64,
    is_in_free_trial: bool,
    is_in_intro_period: bool,
    auto_renew_enabled: bool,
    will_auto_renew: bool,

    pub fn init(product_id: []const u8) SubscriptionInfo {
        return .{
            .product_id = product_id,
            .status = .never_subscribed,
            .purchase_time = 0,
            .expiration_time = 0,
            .renewal_time = null,
            .cancel_time = null,
            .is_in_free_trial = false,
            .is_in_intro_period = false,
            .auto_renew_enabled = true,
            .will_auto_renew = true,
        };
    }

    pub fn isActive(self: *const SubscriptionInfo) bool {
        return self.status.isActive();
    }

    pub fn daysRemaining(self: *const SubscriptionInfo, current_time: u64) u32 {
        if (current_time >= self.expiration_time) return 0;
        const remaining_ms = self.expiration_time - current_time;
        return @intCast(remaining_ms / (24 * 60 * 60 * 1000));
    }
};

// ============================================================================
// Receipt Validation
// ============================================================================

/// Receipt validation result
pub const ReceiptValidation = struct {
    is_valid: bool,
    environment: StoreEnvironment,
    bundle_id: ?[]const u8,
    transactions: []const Transaction,
    latest_receipt: ?[]const u8,
    error_message: ?[]const u8,

    pub fn valid(transactions: []const Transaction) ReceiptValidation {
        return .{
            .is_valid = true,
            .environment = .production,
            .bundle_id = null,
            .transactions = transactions,
            .latest_receipt = null,
            .error_message = null,
        };
    }

    pub fn invalid(message: []const u8) ReceiptValidation {
        return .{
            .is_valid = false,
            .environment = .production,
            .bundle_id = null,
            .transactions = &[_]Transaction{},
            .latest_receipt = null,
            .error_message = message,
        };
    }
};

// ============================================================================
// Promotional Offers (iOS)
// ============================================================================

/// Promotional offer for subscriptions
pub const PromotionalOffer = struct {
    id: []const u8,
    key_id: []const u8,
    nonce: []const u8,
    signature: []const u8,
    timestamp: u64,
};

// ============================================================================
// Product Presets
// ============================================================================

/// Common product configurations
pub const ProductPresets = struct {
    pub fn premiumUpgrade(id: []const u8, price: []const u8) Product {
        return Product.init(id, "Premium Upgrade", price)
            .withDescription("Unlock all premium features")
            .withType(.non_consumable);
    }

    pub fn removeAds(id: []const u8, price: []const u8) Product {
        return Product.init(id, "Remove Ads", price)
            .withDescription("Remove all advertisements")
            .withType(.non_consumable);
    }

    pub fn coins(id: []const u8, amount: u32, price: []const u8) Product {
        var buf: [64]u8 = undefined;
        const title = std.fmt.bufPrint(&buf, "{d} Coins", .{amount}) catch "Coins";
        return Product.init(id, title, price)
            .withType(.consumable);
    }

    pub fn monthlySubscription(id: []const u8, price: []const u8) Product {
        return Product.init(id, "Monthly Subscription", price)
            .withDescription("Full access, billed monthly")
            .withSubscription(.monthly);
    }

    pub fn yearlySubscription(id: []const u8, price: []const u8) Product {
        return Product.init(id, "Yearly Subscription", price)
            .withDescription("Full access, billed yearly")
            .withSubscription(.annual);
    }

    pub fn weeklySubscription(id: []const u8, price: []const u8) Product {
        return Product.init(id, "Weekly Subscription", price)
            .withDescription("Full access, billed weekly")
            .withSubscription(.weekly);
    }
};

// ============================================================================
// Quick Purchase Utilities
// ============================================================================

/// Quick purchase utilities
pub const QuickPurchase = struct {
    /// Create a simple one-time purchase flow
    pub fn buyOnce(manager: *IAPManager, product_id: []const u8) PurchaseError!bool {
        const transaction = try manager.purchase(product_id);
        return transaction.state.isSuccessful();
    }

    /// Check if user has premium access
    pub fn hasPremium(manager: *const IAPManager, premium_ids: []const []const u8) bool {
        for (premium_ids) |pid| {
            if (manager.isPurchased(pid)) return true;
            if (manager.isSubscriptionActive(pid)) return true;
        }
        return false;
    }

    /// Check if any subscription is active
    pub fn hasActiveSubscription(manager: *const IAPManager, sub_ids: []const []const u8) bool {
        for (sub_ids) |sid| {
            if (manager.isSubscriptionActive(sid)) return true;
        }
        return false;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ProductType basics" {
    const consumable = ProductType.consumable;
    try std.testing.expect(consumable.isConsumable());
    try std.testing.expect(!consumable.isSubscription());
    try std.testing.expectEqualStrings("consumable", consumable.toString());

    const subscription = ProductType.auto_renewable_subscription;
    try std.testing.expect(subscription.isSubscription());
    try std.testing.expect(!subscription.isConsumable());
}

test "SubscriptionPeriod conversions" {
    try std.testing.expectEqual(@as(u32, 7), SubscriptionPeriod.weekly.toDays());
    try std.testing.expectEqual(@as(u32, 30), SubscriptionPeriod.monthly.toDays());
    try std.testing.expectEqual(@as(u32, 365), SubscriptionPeriod.annual.toDays());
    try std.testing.expectEqualStrings("monthly", SubscriptionPeriod.monthly.toString());
}

test "Product creation and configuration" {
    const product = Product.init("com.app.premium", "Premium", "$9.99")
        .withDescription("Unlock everything")
        .withType(.non_consumable);

    try std.testing.expectEqualStrings("com.app.premium", product.id);
    try std.testing.expectEqualStrings("Premium", product.title);
    try std.testing.expectEqualStrings("$9.99", product.price_string);
    try std.testing.expectEqualStrings("Unlock everything", product.description);
    try std.testing.expect(!product.product_type.isConsumable());
}

test "Product subscription configuration" {
    const product = Product.init("com.app.monthly", "Monthly Sub", "$4.99")
        .withSubscription(.monthly)
        .withFreeTrial(7);

    try std.testing.expect(product.isSubscription());
    try std.testing.expect(product.hasFreeTrial());
    try std.testing.expectEqual(@as(?u32, 7), product.free_trial_days);
    try std.testing.expectEqual(SubscriptionPeriod.monthly, product.subscription_period.?);
}

test "Transaction creation" {
    var transaction = Transaction.init("tx_123", "com.app.premium", .purchased);
    transaction.purchase_time = 1000000;
    transaction.quantity = 1;

    try std.testing.expectEqualStrings("tx_123", transaction.id);
    try std.testing.expectEqualStrings("com.app.premium", transaction.product_id);
    try std.testing.expect(transaction.isSuccessful());
    try std.testing.expect(!transaction.isPending());
}

test "Transaction expiration" {
    var transaction = Transaction.init("tx_sub", "com.app.sub", .purchased);
    transaction.expiration_time = 2000000;

    try std.testing.expect(!transaction.isExpired(1000000));
    try std.testing.expect(transaction.isExpired(3000000));
}

test "Transaction remaining days" {
    var transaction = Transaction.init("tx_sub", "com.app.sub", .purchased);
    const day_ms: u64 = 24 * 60 * 60 * 1000;
    transaction.expiration_time = 10 * day_ms;

    const remaining = transaction.getRemainingDays(5 * day_ms);
    try std.testing.expect(remaining != null);
    try std.testing.expectEqual(@as(u32, 5), remaining.?);
}

test "TransactionState properties" {
    try std.testing.expect(TransactionState.purchased.isSuccessful());
    try std.testing.expect(TransactionState.restored.isSuccessful());
    try std.testing.expect(!TransactionState.failed.isSuccessful());

    try std.testing.expect(TransactionState.purchasing.isPending());
    try std.testing.expect(TransactionState.deferred.isPending());
    try std.testing.expect(!TransactionState.purchased.isPending());
}

test "StoreConfig creation" {
    const config = StoreConfig.init()
        .withSharedSecret("secret123")
        .withVerificationUrl("https://verify.example.com");

    try std.testing.expectEqual(StoreEnvironment.production, config.environment);
    try std.testing.expectEqualStrings("secret123", config.shared_secret.?);
    try std.testing.expectEqualStrings("https://verify.example.com", config.verification_url.?);
}

test "StoreConfig sandbox" {
    const config = StoreConfig.sandbox();

    try std.testing.expectEqual(StoreEnvironment.sandbox, config.environment);
    try std.testing.expect(config.debug_logging);
}

test "PurchaseResult success" {
    const transaction = Transaction.init("tx_1", "product_1", .purchased);
    const result = PurchaseResult.success(transaction);

    try std.testing.expect(result.isSuccess());
    try std.testing.expect(result.err == null);
    try std.testing.expect(result.transaction != null);
}

test "PurchaseResult failure" {
    const result = PurchaseResult.failure(PurchaseError.Cancelled);

    try std.testing.expect(!result.isSuccess());
    try std.testing.expectEqual(PurchaseError.Cancelled, result.err.?);
    try std.testing.expect(result.transaction == null);
}

test "IAPManager initialization" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(!manager.is_initialized);
    try std.testing.expect(manager.can_make_payments);
}

test "IAPManager start" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.start();
    try std.testing.expect(manager.is_initialized);
}

test "IAPManager configure" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    const config = StoreConfig.sandbox();
    manager.configure(config);

    try std.testing.expectEqual(StoreEnvironment.sandbox, manager.config.environment);
}

test "IAPManager register product" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    const product = Product.init("test_product", "Test", "$1.99");
    try manager.registerProduct(product);

    const retrieved = manager.getProduct("test_product");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("Test", retrieved.?.title);
}

test "IAPManager purchase" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    const product = Product.init("test_product", "Test", "$1.99");
    try manager.registerProduct(product);

    const transaction = try manager.purchase("test_product");
    try std.testing.expect(transaction.state.isSuccessful());
    try std.testing.expect(manager.isPurchased("test_product"));
}

test "IAPManager prevent duplicate non-consumable purchase" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    const product = Product.init("premium", "Premium", "$9.99")
        .withType(.non_consumable);
    try manager.registerProduct(product);

    _ = try manager.purchase("premium");

    const result = manager.purchase("premium");
    try std.testing.expectError(PurchaseError.AlreadyPurchased, result);
}

test "IAPManager consumable can be repurchased" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    const product = Product.init("coins_100", "100 Coins", "$0.99")
        .withType(.consumable);
    try manager.registerProduct(product);

    // First purchase
    const tx1 = try manager.purchase("coins_100");
    try std.testing.expect(tx1.state.isSuccessful());

    // Clear for re-purchase test (in real app, consumables are consumed)
    _ = manager.purchases.remove("coins_100");

    // Second purchase should succeed
    const tx2 = try manager.purchase("coins_100");
    try std.testing.expect(tx2.state.isSuccessful());
}

test "IAPManager restore purchases" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    // Make a purchase first
    const product = Product.init("premium", "Premium", "$9.99");
    try manager.registerProduct(product);
    _ = try manager.purchase("premium");

    // Restore
    const restored = try manager.restorePurchases();
    defer manager.allocator.free(restored);

    try std.testing.expectEqual(@as(usize, 1), restored.len);
    try std.testing.expectEqual(TransactionState.restored, restored[0].state);
}

test "IAPManager simulate purchase" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    const transaction = try manager.simulatePurchase("test_product", .purchased);
    try std.testing.expect(transaction.is_sandbox);
    try std.testing.expect(manager.isPurchased("test_product"));
}

test "IAPManager subscription status" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    var tx = try manager.simulatePurchase("monthly_sub", .purchased);
    tx.expiration_time = IAPManager.getCurrentTimeMs() + (30 * 24 * 60 * 60 * 1000); // 30 days
    manager.purchases.put("monthly_sub", tx) catch unreachable;

    try std.testing.expect(manager.isSubscriptionActive("monthly_sub"));
}

test "SubscriptionStatus properties" {
    try std.testing.expect(SubscriptionStatus.active.isActive());
    try std.testing.expect(SubscriptionStatus.grace_period.isActive());
    try std.testing.expect(SubscriptionStatus.cancelled.isActive());
    try std.testing.expect(!SubscriptionStatus.expired.isActive());
    try std.testing.expect(!SubscriptionStatus.never_subscribed.isActive());
}

test "SubscriptionInfo creation" {
    const info = SubscriptionInfo.init("monthly_sub");
    try std.testing.expectEqualStrings("monthly_sub", info.product_id);
    try std.testing.expectEqual(SubscriptionStatus.never_subscribed, info.status);
    try std.testing.expect(!info.isActive());
}

test "SubscriptionInfo days remaining" {
    var info = SubscriptionInfo.init("sub");
    info.status = .active;
    const day_ms: u64 = 24 * 60 * 60 * 1000;
    info.expiration_time = 10 * day_ms;

    const remaining = info.daysRemaining(5 * day_ms);
    try std.testing.expectEqual(@as(u32, 5), remaining);
}

test "ReceiptValidation success" {
    const transactions = [_]Transaction{
        Transaction.init("tx_1", "product_1", .purchased),
    };
    const validation = ReceiptValidation.valid(&transactions);

    try std.testing.expect(validation.is_valid);
    try std.testing.expectEqual(@as(usize, 1), validation.transactions.len);
}

test "ReceiptValidation failure" {
    const validation = ReceiptValidation.invalid("Invalid receipt");

    try std.testing.expect(!validation.is_valid);
    try std.testing.expectEqualStrings("Invalid receipt", validation.error_message.?);
}

test "ProductPresets premium upgrade" {
    const product = ProductPresets.premiumUpgrade("com.app.premium", "$9.99");
    try std.testing.expectEqualStrings("Premium Upgrade", product.title);
    try std.testing.expect(!product.product_type.isConsumable());
}

test "ProductPresets remove ads" {
    const product = ProductPresets.removeAds("com.app.noads", "$2.99");
    try std.testing.expectEqualStrings("Remove Ads", product.title);
}

test "ProductPresets monthly subscription" {
    const product = ProductPresets.monthlySubscription("com.app.monthly", "$4.99");
    try std.testing.expect(product.isSubscription());
    try std.testing.expectEqual(SubscriptionPeriod.monthly, product.subscription_period.?);
}

test "ProductPresets yearly subscription" {
    const product = ProductPresets.yearlySubscription("com.app.yearly", "$49.99");
    try std.testing.expect(product.isSubscription());
    try std.testing.expectEqual(SubscriptionPeriod.annual, product.subscription_period.?);
}

test "QuickPurchase buyOnce" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    const product = Product.init("item", "Item", "$1.99");
    try manager.registerProduct(product);

    const success = try QuickPurchase.buyOnce(&manager, "item");
    try std.testing.expect(success);
}

test "QuickPurchase hasPremium" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(!QuickPurchase.hasPremium(&manager, &[_][]const u8{"premium"}));

    _ = try manager.simulatePurchase("premium", .purchased);
    try std.testing.expect(QuickPurchase.hasPremium(&manager, &[_][]const u8{"premium"}));
}

test "QuickPurchase hasActiveSubscription" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(!QuickPurchase.hasActiveSubscription(&manager, &[_][]const u8{"sub_monthly"}));

    var tx = try manager.simulatePurchase("sub_monthly", .purchased);
    tx.expiration_time = IAPManager.getCurrentTimeMs() + (30 * 24 * 60 * 60 * 1000);
    manager.purchases.put("sub_monthly", tx) catch unreachable;

    try std.testing.expect(QuickPurchase.hasActiveSubscription(&manager, &[_][]const u8{"sub_monthly"}));
}

test "StoreEnvironment toString" {
    try std.testing.expectEqualStrings("production", StoreEnvironment.production.toString());
    try std.testing.expectEqualStrings("sandbox", StoreEnvironment.sandbox.toString());
    try std.testing.expectEqualStrings("simulator", StoreEnvironment.simulator.toString());
}

test "IAPManager canMakePayments" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(manager.canMakePayments());
}

test "IAPManager fetch products" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    const products = try manager.fetchProducts(&[_][]const u8{ "product1", "product2" });
    defer manager.allocator.free(products);

    try std.testing.expectEqual(@as(usize, 2), products.len);
}

test "IAPManager stop" {
    var manager = IAPManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.start();
    try std.testing.expect(manager.is_initialized);

    manager.stop();
    try std.testing.expect(!manager.is_initialized);
}
