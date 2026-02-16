const std = @import("std");
const io_context = @import("io_context.zig");

/// iOS Swift Template Generator
/// Generates complete iOS app templates with Craft integration

pub const IOSTemplate = struct {
    allocator: std.mem.Allocator,
    app_name: []const u8,
    bundle_id: []const u8,
    output_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator, app_name: []const u8, bundle_id: []const u8, output_dir: []const u8) IOSTemplate {
        return .{
            .allocator = allocator,
            .app_name = app_name,
            .bundle_id = bundle_id,
            .output_dir = output_dir,
        };
    }

    pub fn generate(self: *IOSTemplate) !void {
        // Create directory structure
        try self.createDirectoryStructure();

        // Generate Swift files
        try self.generateAppDelegate();
        try self.generateSceneDelegate();
        try self.generateViewController();
        try self.generateCraftBridge();
        try self.generateARKitBridge();
        try self.generateMLKitBridge();
        try self.generateHealthKitBridge();

        // Generate configuration files
        try self.generateInfoPlist();
        try self.generateEntitlements();
        try self.generatePodfile();

        std.debug.print("iOS template generated successfully at: {s}\n", .{self.output_dir});
    }

    fn createDirectoryStructure(self: *IOSTemplate) !void {
        const io = io_context.get();
        const cwd = io_context.cwd();

        const dirs = [_][]const u8{
            self.output_dir,
            try std.fmt.allocPrint(self.allocator, "{s}/Sources", .{self.output_dir}),
            try std.fmt.allocPrint(self.allocator, "{s}/Sources/Bridge", .{self.output_dir}),
            try std.fmt.allocPrint(self.allocator, "{s}/Sources/Features", .{self.output_dir}),
            try std.fmt.allocPrint(self.allocator, "{s}/Resources", .{self.output_dir}),
            try std.fmt.allocPrint(self.allocator, "{s}/Assets.xcassets", .{self.output_dir}),
        };

        for (dirs) |dir| {
            cwd.createDir(io, dir, .default_dir) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };
        }
    }

    fn generateAppDelegate(self: *IOSTemplate) !void {
        const content =
            \\import UIKit
            \\import WebKit
            \\
            \\@main
            \\class AppDelegate: UIResponder, UIApplicationDelegate {
            \\    var window: UIWindow?
            \\    var craftBridge: CraftBridge?
            \\
            \\    func application(
            \\        _ application: UIApplication,
            \\        didFinishLaunchingWith options: [UIApplication.LaunchOptionsKey: Any]?
            \\    ) -> Bool {
            \\        // Initialize Craft Bridge
            \\        craftBridge = CraftBridge.shared
            \\
            \\        // Configure window
            \\        window = UIWindow(frame: UIScreen.main.bounds)
            \\        window?.rootViewController = ViewController()
            \\        window?.makeKeyAndVisible()
            \\
            \\        return true
            \\    }
            \\
            \\    func application(_ application: UIApplication,
            \\                    configurationForConnecting connectingSceneSession: UISceneSession,
            \\                    options: UIScene.ConnectionOptions) -> UISceneConfiguration {
            \\        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
            \\    }
            \\}
            \\
        ;

        try self.writeFile("Sources/AppDelegate.swift", content);
    }

    fn generateSceneDelegate(self: *IOSTemplate) !void {
        const content =
            \\import UIKit
            \\
            \\class SceneDelegate: UIResponder, UIWindowSceneDelegate {
            \\    var window: UIWindow?
            \\
            \\    func scene(_ scene: UIScene,
            \\              willConnectTo session: UISceneSession,
            \\              options connectionOptions: UIScene.ConnectionOptions) {
            \\        guard let windowScene = (scene as? UIWindowScene) else { return }
            \\
            \\        window = UIWindow(windowScene: windowScene)
            \\        window?.rootViewController = ViewController()
            \\        window?.makeKeyAndVisible()
            \\    }
            \\
            \\    func sceneDidDisconnect(_ scene: UIScene) {}
            \\    func sceneDidBecomeActive(_ scene: UIScene) {}
            \\    func sceneWillResignActive(_ scene: UIScene) {}
            \\    func sceneWillEnterForeground(_ scene: UIScene) {}
            \\    func sceneDidEnterBackground(_ scene: UIScene) {}
            \\}
            \\
        ;

        try self.writeFile("Sources/SceneDelegate.swift", content);
    }

    fn generateViewController(self: *IOSTemplate) !void {
        const content =
            \\import UIKit
            \\import WebKit
            \\
            \\class ViewController: UIViewController {
            \\    private var webView: WKWebView!
            \\    private let craftBridge = CraftBridge.shared
            \\
            \\    override func viewDidLoad() {
            \\        super.viewDidLoad()
            \\
            \\        // Configure WKWebView
            \\        let configuration = WKWebViewConfiguration()
            \\        configuration.allowsInlineMediaPlayback = true
            \\        configuration.mediaTypesRequiringUserActionForPlayback = []
            \\
            \\        // Add Craft message handler
            \\        configuration.userContentController.add(craftBridge, name: "craft")
            \\
            \\        // Inject Craft bridge script
            \\        let bridgeScript = WKUserScript(
            \\            source: craftBridge.bridgeScript,
            \\            injectionTime: .atDocumentStart,
            \\            forMainFrameOnly: true
            \\        )
            \\        configuration.userContentController.addUserScript(bridgeScript)
            \\
            \\        webView = WKWebView(frame: view.bounds, configuration: configuration)
            \\        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            \\        webView.navigationDelegate = self
            \\        view.addSubview(webView)
            \\
            \\        // Load initial URL
            \\        if let url = URL(string: "http://localhost:3000") {
            \\            webView.load(URLRequest(url: url))
            \\        }
            \\    }
            \\}
            \\
            \\extension ViewController: WKNavigationDelegate {
            \\    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            \\        print("Page loaded successfully")
            \\    }
            \\
            \\    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            \\        print("Navigation failed: \(error.localizedDescription)")
            \\    }
            \\}
            \\
        ;

        try self.writeFile("Sources/ViewController.swift", content);
    }

    fn generateCraftBridge(self: *IOSTemplate) !void {
        const content =
            \\import Foundation
            \\import WebKit
            \\import UIKit
            \\
            \\class CraftBridge: NSObject, WKScriptMessageHandler {
            \\    static let shared = CraftBridge()
            \\    private weak var webView: WKWebView?
            \\
            \\    private override init() {
            \\        super.init()
            \\    }
            \\
            \\    // Bridge script injected into WebView
            \\    var bridgeScript: String {
            \\        return """
            \\        // This will be replaced with actual JS bridge from js_bridge.zig
            \\        window.craft = window.craft || {};
            \\        window.craft.invoke = function(method, params) {
            \\            return new Promise((resolve, reject) => {
            \\                const messageId = Date.now() + '_' + Math.random();
            \\                window.webkit.messageHandlers.craft.postMessage({
            \\                    id: messageId,
            \\                    method: method,
            \\                    params: params
            \\                });
            \\            });
            \\        };
            \\        """
            \\    }
            \\
            \\    // Handle messages from JavaScript
            \\    func userContentController(_ userContentController: WKUserContentController,
            \\                             didReceive message: WKScriptMessage) {
            \\        guard let body = message.body as? [String: Any],
            \\              let method = body["method"] as? String,
            \\              let messageId = body["id"] as? String else {
            \\            return
            \\        }
            \\
            \\        let params = body["params"] as? [String: Any]
            \\
            \\        // Route to appropriate handler
            \\        handleMessage(method: method, params: params) { result in
            \\            self.sendResponse(messageId: messageId, result: result)
            \\        }
            \\    }
            \\
            \\    private func handleMessage(method: String, params: [String: Any]?, completion: @escaping ([String: Any]) -> Void) {
            \\        switch method {
            \\        case "getPlatform":
            \\            completion(["platform": "ios", "version": UIDevice.current.systemVersion])
            \\
            \\        case "showToast":
            \\            if let message = params?["message"] as? String {
            \\                showToast(message: message)
            \\                completion(["success": true])
            \\            }
            \\
            \\        case "haptic":
            \\            if let type = params?["type"] as? String {
            \\                triggerHaptic(type: type)
            \\                completion(["success": true])
            \\            }
            \\
            \\        case "requestPermission":
            \\            if let permission = params?["permission"] as? String {
            \\                requestPermission(permission: permission, completion: completion)
            \\            }
            \\
            \\        default:
            \\            completion(["error": "Unknown method: \(method)"])
            \\        }
            \\    }
            \\
            \\    private func sendResponse(messageId: String, result: [String: Any]) {
            \\        let response: [String: Any] = [
            \\            "id": messageId,
            \\            "success": result["error"] == nil,
            \\            "result": result
            \\        ]
            \\
            \\        if let jsonData = try? JSONSerialization.data(withJSONObject: response),
            \\           let jsonString = String(data: jsonData, encoding: .utf8) {
            \\            let script = "window.craftHandleResponse('\(jsonString)')"
            \\            webView?.evaluateJavaScript(script)
            \\        }
            \\    }
            \\
            \\    private func showToast(message: String) {
            \\        // Simple alert for toast
            \\        DispatchQueue.main.async {
            \\            if let window = UIApplication.shared.windows.first {
            \\                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            \\                window.rootViewController?.present(alert, animated: true)
            \\                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            \\                    alert.dismiss(animated: true)
            \\                }
            \\            }
            \\        }
            \\    }
            \\
            \\    private func triggerHaptic(type: String) {
            \\        let generator: UIFeedbackGenerator
            \\
            \\        switch type {
            \\        case "selection":
            \\            generator = UISelectionFeedbackGenerator()
            \\        case "impact_light":
            \\            generator = UIImpactFeedbackGenerator(style: .light)
            \\        case "impact_medium":
            \\            generator = UIImpactFeedbackGenerator(style: .medium)
            \\        case "impact_heavy":
            \\            generator = UIImpactFeedbackGenerator(style: .heavy)
            \\        case "notification_success":
            \\            let notificationGenerator = UINotificationFeedbackGenerator()
            \\            notificationGenerator.notificationOccurred(.success)
            \\            return
            \\        case "notification_warning":
            \\            let notificationGenerator = UINotificationFeedbackGenerator()
            \\            notificationGenerator.notificationOccurred(.warning)
            \\            return
            \\        case "notification_error":
            \\            let notificationGenerator = UINotificationFeedbackGenerator()
            \\            notificationGenerator.notificationOccurred(.error)
            \\            return
            \\        default:
            \\            generator = UISelectionFeedbackGenerator()
            \\        }
            \\
            \\        if let impactGenerator = generator as? UIImpactFeedbackGenerator {
            \\            impactGenerator.impactOccurred()
            \\        } else if let selectionGenerator = generator as? UISelectionFeedbackGenerator {
            \\            selectionGenerator.selectionChanged()
            \\        }
            \\    }
            \\
            \\    private func requestPermission(permission: String, completion: @escaping ([String: Any]) -> Void) {
            \\        // Permission handling will be implemented by specific bridge classes
            \\        completion(["granted": false, "message": "Not implemented"])
            \\    }
            \\}
            \\
        ;

        try self.writeFile("Sources/Bridge/CraftBridge.swift", content);
    }

    fn generateARKitBridge(self: *IOSTemplate) !void {
        const content =
            \\import Foundation
            \\import ARKit
            \\
            \\@available(iOS 11.0, *)
            \\class ARKitBridge: NSObject {
            \\    private var arSession: ARSession?
            \\    private var configuration: ARConfiguration?
            \\
            \\    func startARSession(type: String) -> [String: Any] {
            \\        guard ARWorldTrackingConfiguration.isSupported else {
            \\            return ["error": "ARKit not supported"]
            \\        }
            \\
            \\        arSession = ARSession()
            \\
            \\        switch type {
            \\        case "world":
            \\            configuration = ARWorldTrackingConfiguration()
            \\        case "face":
            \\            if ARFaceTrackingConfiguration.isSupported {
            \\                configuration = ARFaceTrackingConfiguration()
            \\            }
            \\        case "image":
            \\            configuration = ARImageTrackingConfiguration()
            \\        default:
            \\            configuration = ARWorldTrackingConfiguration()
            \\        }
            \\
            \\        if let config = configuration {
            \\            arSession?.run(config)
            \\            return ["success": true]
            \\        }
            \\
            \\        return ["error": "Failed to start AR session"]
            \\    }
            \\
            \\    func stopARSession() {
            \\        arSession?.pause()
            \\    }
            \\}
            \\
        ;

        try self.writeFile("Sources/Features/ARKitBridge.swift", content);
    }

    fn generateMLKitBridge(self: *IOSTemplate) !void {
        const content =
            \\import Foundation
            \\import Vision
            \\import CoreML
            \\
            \\class MLKitBridge: NSObject {
            \\    func detectText(in image: UIImage, completion: @escaping ([String: Any]) -> Void) {
            \\        guard let cgImage = image.cgImage else {
            \\            completion(["error": "Invalid image"])
            \\            return
            \\        }
            \\
            \\        let request = VNRecognizeTextRequest { request, error in
            \\            if let error = error {
            \\                completion(["error": error.localizedDescription])
            \\                return
            \\            }
            \\
            \\            guard let observations = request.results as? [VNRecognizedTextObservation] else {
            \\                completion(["results": []])
            \\                return
            \\            }
            \\
            \\            let text = observations.compactMap { observation in
            \\                observation.topCandidates(1).first?.string
            \\            }
            \\
            \\            completion(["results": text])
            \\        }
            \\
            \\        request.recognitionLevel = .accurate
            \\
            \\        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            \\        try? handler.perform([request])
            \\    }
            \\
            \\    func classifyImage(in image: UIImage, completion: @escaping ([String: Any]) -> Void) {
            \\        guard let cgImage = image.cgImage else {
            \\            completion(["error": "Invalid image"])
            \\            return
            \\        }
            \\
            \\        let request = VNClassifyImageRequest { request, error in
            \\            if let error = error {
            \\                completion(["error": error.localizedDescription])
            \\                return
            \\            }
            \\
            \\            guard let observations = request.results as? [VNClassificationObservation] else {
            \\                completion(["results": []])
            \\                return
            \\            }
            \\
            \\            let classifications = observations.prefix(5).map { observation in
            \\                ["label": observation.identifier, "confidence": observation.confidence]
            \\            }
            \\
            \\            completion(["results": classifications])
            \\        }
            \\
            \\        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            \\        try? handler.perform([request])
            \\    }
            \\}
            \\
        ;

        try self.writeFile("Sources/Features/MLKitBridge.swift", content);
    }

    fn generateHealthKitBridge(self: *IOSTemplate) !void {
        const content =
            \\import Foundation
            \\import HealthKit
            \\
            \\class HealthKitBridge: NSObject {
            \\    private let healthStore = HKHealthStore()
            \\
            \\    func requestAuthorization(completion: @escaping ([String: Any]) -> Void) {
            \\        guard HKHealthStore.isHealthDataAvailable() else {
            \\            completion(["error": "HealthKit not available"])
            \\            return
            \\        }
            \\
            \\        let readTypes: Set<HKObjectType> = [
            \\            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            \\            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            \\            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
            \\        ]
            \\
            \\        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            \\            if let error = error {
            \\                completion(["error": error.localizedDescription])
            \\            } else {
            \\                completion(["granted": success])
            \\            }
            \\        }
            \\    }
            \\
            \\    func getStepCount(completion: @escaping ([String: Any]) -> Void) {
            \\        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            \\            completion(["error": "Step count not available"])
            \\            return
            \\        }
            \\
            \\        let now = Date()
            \\        let startOfDay = Calendar.current.startOfDay(for: now)
            \\        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            \\
            \\        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            \\            if let error = error {
            \\                completion(["error": error.localizedDescription])
            \\                return
            \\            }
            \\
            \\            guard let sum = result?.sumQuantity() else {
            \\                completion(["steps": 0])
            \\                return
            \\            }
            \\
            \\            let steps = sum.doubleValue(for: HKUnit.count())
            \\            completion(["steps": Int(steps)])
            \\        }
            \\
            \\        healthStore.execute(query)
            \\    }
            \\}
            \\
        ;

        try self.writeFile("Sources/Features/HealthKitBridge.swift", content);
    }

    fn generateInfoPlist(self: *IOSTemplate) !void {
        const content = try std.fmt.allocPrint(
            self.allocator,
            \\<?xml version="1.0" encoding="UTF-8"?>
            \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            \\<plist version="1.0">
            \\<dict>
            \\    <key>CFBundleDevelopmentRegion</key>
            \\    <string>$(DEVELOPMENT_LANGUAGE)</string>
            \\    <key>CFBundleDisplayName</key>
            \\    <string>{s}</string>
            \\    <key>CFBundleExecutable</key>
            \\    <string>$(EXECUTABLE_NAME)</string>
            \\    <key>CFBundleIdentifier</key>
            \\    <string>{s}</string>
            \\    <key>CFBundleName</key>
            \\    <string>$(PRODUCT_NAME)</string>
            \\    <key>CFBundleVersion</key>
            \\    <string>1</string>
            \\    <key>LSRequiresIPhoneOS</key>
            \\    <true/>
            \\    <key>UIRequiredDeviceCapabilities</key>
            \\    <array>
            \\        <string>armv7</string>
            \\    </array>
            \\    <key>UISupportedInterfaceOrientations</key>
            \\    <array>
            \\        <string>UIInterfaceOrientationPortrait</string>
            \\        <string>UIInterfaceOrientationLandscapeLeft</string>
            \\        <string>UIInterfaceOrientationLandscapeRight</string>
            \\    </array>
            \\    <key>NSCameraUsageDescription</key>
            \\    <string>This app needs camera access</string>
            \\    <key>NSPhotoLibraryUsageDescription</key>
            \\    <string>This app needs photo library access</string>
            \\    <key>NSLocationWhenInUseUsageDescription</key>
            \\    <string>This app needs location access</string>
            \\    <key>NSHealthShareUsageDescription</key>
            \\    <string>This app needs health data access</string>
            \\    <key>NSHealthUpdateUsageDescription</key>
            \\    <string>This app needs to update health data</string>
            \\    <key>NSLocalNetworkUsageDescription</key>
            \\    <string>This app needs local network access for development</string>
            \\</dict>
            \\</plist>
            \\
        ,
            .{ self.app_name, self.bundle_id },
        );
        defer self.allocator.free(content);

        try self.writeFile("Info.plist", content);
    }

    fn generateEntitlements(self: *IOSTemplate) !void {
        const content =
            \\<?xml version="1.0" encoding="UTF-8"?>
            \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            \\<plist version="1.0">
            \\<dict>
            \\    <key>com.apple.developer.healthkit</key>
            \\    <true/>
            \\    <key>com.apple.developer.healthkit.access</key>
            \\    <array/>
            \\</dict>
            \\</plist>
            \\
        ;

        try self.writeFile("Entitlements.plist", content);
    }

    fn generatePodfile(self: *IOSTemplate) !void {
        const content =
            \\# Podfile for Craft iOS App
            \\platform :ios, '14.0'
            \\use_frameworks!
            \\
            \\target 'CraftApp' do
            \\  # Add pods here if needed
            \\end
            \\
        ;

        try self.writeFile("Podfile", content);
    }

    fn writeFile(self: *IOSTemplate, relative_path: []const u8, content: []const u8) !void {
        const full_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.output_dir, relative_path });
        defer self.allocator.free(full_path);

        const io = io_context.get();
        const cwd = io_context.cwd();
        const file = try cwd.createFile(io, full_path, .{});
        defer file.close(io);

        try file.writeStreamingAll(io, content);
    }
};

// Test
test "iOS template generation" {
    const allocator = std.testing.allocator;
    const template = IOSTemplate.init(allocator, "TestApp", "com.test.app", "test_ios_output");

    // Would generate files - skipping in test
    _ = template;
}
