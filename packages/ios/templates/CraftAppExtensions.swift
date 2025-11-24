import SwiftUI
import ActivityKit
import AppIntents
import TipKit

// MARK: - iOS 16+ Advanced Features

/// Live Activities (Dynamic Island) Support
@available(iOS 16.1, *)
struct CraftLiveActivity: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String
        var progress: Double
    }

    var name: String
}

@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<CraftLiveActivity>?

    func startActivity(name: String, status: String, progress: Double) async throws {
        let attributes = CraftLiveActivity(name: name)
        let contentState = CraftLiveActivity.ContentState(status: status, progress: progress)

        currentActivity = try Activity.request(
            attributes: attributes,
            content: .init(state: contentState, staleDate: nil)
        )
    }

    func updateActivity(status: String, progress: Double) async {
        guard let activity = currentActivity else { return }

        let contentState = CraftLiveActivity.ContentState(status: status, progress: progress)
        await activity.update(.init(state: contentState, staleDate: nil))
    }

    func endActivity() async {
        guard let activity = currentActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }
}

// MARK: - App Intents (iOS 16+)

@available(iOS 16.0, *)
struct OpenCraftIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Craft App"
    static var description = IntentDescription("Opens the Craft application")

    func perform() async throws -> some IntentResult {
        // Open app logic
        return .result()
    }
}

@available(iOS 16.0, *)
struct CraftShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenCraftIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Launch \(.applicationName)"
            ],
            shortTitle: "Open App",
            systemImageName: "app.fill"
        )
    }
}

// MARK: - TipKit Integration (iOS 17+)

@available(iOS 17.0, *)
struct CraftWelcomeTip: Tip {
    var title: Text {
        Text("Welcome to Craft")
    }

    var message: Text? {
        Text("Get started by exploring the features")
    }

    var image: Image? {
        Image(systemName: "star.fill")
    }
}

@available(iOS 17.0, *)
class TipKitManager {
    static let shared = TipKitManager()

    func configure() {
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }
}

// MARK: - SharePlay Integration

@available(iOS 15.0, *)
class SharePlayManager: ObservableObject {
    static let shared = SharePlayManager()

    @Published var isActive = false

    func startSharePlay() async throws {
        // SharePlay session logic
        isActive = true
    }

    func endSharePlay() {
        isActive = false
    }
}

// MARK: - App Clips Support

class AppClipManager {
    static let shared = AppClipManager()

    var isRunningInAppClip: Bool {
        #if APPCLIP
        return true
        #else
        return false
        #endif
    }

    func configureAppClip() {
        // App Clip specific configuration
    }
}

// MARK: - Focus Filters (iOS 16+)

@available(iOS 16.0, *)
class FocusFilterManager {
    static let shared = FocusFilterManager()

    func getCurrentFocus() -> String? {
        // Return current Focus mode if available
        return nil
    }

    func registerFocusFilter() {
        // Register app-specific Focus filter
    }
}

// MARK: - StoreKit 2 Full Implementation

@available(iOS 15.0, *)
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []

    private var updateListenerTask: Task<Void, Error>?

    func loadProducts(productIDs: [String]) async throws {
        products = try await Product.products(for: productIDs)
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return transaction

        case .userCancelled, .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    func restorePurchases() async throws {
        for await result in Transaction.currentEntitlements {
            let transaction = try checkVerified(result)
            await updatePurchasedProducts()
        }
    }

    func startObservingTransactions() {
        updateListenerTask = Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    func stopObservingTransactions() {
        updateListenerTask?.cancel()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    @MainActor
    private func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            if transaction.revocationDate == nil {
                purchasedProductIDs.insert(transaction.productID)
            } else {
                purchasedProductIDs.remove(transaction.productID)
            }
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}

// MARK: - CarPlay Support

#if canImport(CarPlay)
import CarPlay

@available(iOS 12.0, *)
class CarPlayManager: NSObject, CPApplicationDelegate {
    static let shared = CarPlayManager()

    private var interfaceController: CPInterfaceController?

    func application(_ application: UIApplication, didConnectCarInterfaceController interfaceController: CPInterfaceController, to window: CPWindow) {
        self.interfaceController = interfaceController

        let template = CPListTemplate(title: "Craft", sections: [
            CPListSection(items: [
                CPListItem(text: "Home", detailText: "Go to home screen")
            ])
        ])

        interfaceController.setRootTemplate(template, animated: true)
    }

    func application(_ application: UIApplication, didDisconnectCarInterfaceController interfaceController: CPInterfaceController, from window: CPWindow) {
        self.interfaceController = nil
    }
}
#endif

// MARK: - Bridge Integration Extensions

extension CraftWebView.Coordinator {

    @available(iOS 16.1, *)
    func startLiveActivity(name: String, status: String, progress: Double, callbackId: String?) {
        Task {
            do {
                try await LiveActivityManager.shared.startActivity(name: name, status: status, progress: progress)
                resolveCallback(callbackId, result: ["started": true])
            } catch {
                rejectCallback(callbackId, error: error.localizedDescription)
            }
        }
    }

    @available(iOS 16.1, *)
    func updateLiveActivity(status: String, progress: Double, callbackId: String?) {
        Task {
            await LiveActivityManager.shared.updateActivity(status: status, progress: progress)
            resolveCallback(callbackId, result: ["updated": true])
        }
    }

    @available(iOS 16.1, *)
    func endLiveActivity(callbackId: String?) {
        Task {
            await LiveActivityManager.shared.endActivity()
            resolveCallback(callbackId, result: ["ended": true])
        }
    }

    @available(iOS 15.0, *)
    func loadStoreProducts(productIDs: [String], callbackId: String?) {
        Task {
            do {
                try await StoreKitManager.shared.loadProducts(productIDs: productIDs)
                let products = StoreKitManager.shared.products.map { product in
                    [
                        "id": product.id,
                        "displayName": product.displayName,
                        "description": product.description,
                        "price": product.displayPrice
                    ]
                }
                resolveCallback(callbackId, result: products)
            } catch {
                rejectCallback(callbackId, error: error.localizedDescription)
            }
        }
    }

    @available(iOS 15.0, *)
    func purchaseProduct(productId: String, callbackId: String?) {
        Task {
            do {
                guard let product = StoreKitManager.shared.products.first(where: { $0.id == productId }) else {
                    rejectCallback(callbackId, error: "Product not found")
                    return
                }

                if let transaction = try await StoreKitManager.shared.purchase(product) {
                    resolveCallback(callbackId, result: [
                        "transactionId": transaction.id,
                        "productId": transaction.productID,
                        "purchased": true
                    ])
                } else {
                    resolveCallback(callbackId, result: ["purchased": false])
                }
            } catch {
                rejectCallback(callbackId, error: error.localizedDescription)
            }
        }
    }

    @available(iOS 15.0, *)
    func restorePurchases(callbackId: String?) {
        Task {
            do {
                try await StoreKitManager.shared.restorePurchases()
                resolveCallback(callbackId, result: ["restored": true])
            } catch {
                rejectCallback(callbackId, error: error.localizedDescription)
            }
        }
    }
}
