import Foundation
import LocalAuthentication
import SQLite3
import Security
import UIKit
import UserNotifications

let craftNativeCapabilityProtocolVersion = 1
/// URLSession's own request timeout, matching the bridge's 30-second deadline.
let craftNativeFetchTimeoutSeconds: TimeInterval = 30
/// A response body larger than this rejects with RESPONSE_TOO_LARGE rather
/// than being copied into JavaScriptCore as one string.
let craftNativeFetchMaxResponseBytes = 8 * 1024 * 1024

struct CraftNativeActionError: Error {
    let code: String
    let message: String
}

/// Process-wide capability services used by every retained native route.
/// Database work is serialized so transactions cannot be interleaved by two
/// JavaScript contexts, while completions return to JavaScriptCore on main.
enum CraftNativeActions {
    private static let storagePrefix = "craft.native.storage."
    private static let databaseQueue = DispatchQueue(label: "dev.craft.native.database")
    private static let cancellationLock = NSLock()
    private static var cancelledRequests = Set<String>()
    private static var biometricContexts = [String: LAContext]()
    private static var fetchTasks = [String: URLSessionTask]()
    private static let fetchSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = craftNativeFetchTimeoutSeconds
        configuration.timeoutIntervalForResource = craftNativeFetchTimeoutSeconds
        return URLSession(configuration: configuration)
    }()
    private static var initialDeepLinkClaimed = false
    private static var database: OpaquePointer?
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    static func capabilities(config: CraftConfig) -> [String] {
        // `speech`, `audio` (background sound) and `eventStream` (a fetch read
        // as it arrives) need nothing the app has to declare.
        var values = ["device", "clipboard", "haptics", "storage", "lifecycle", "fetch", "dialog", "speech", "audio", "eventStream", "linking"]
        if config.enableBiometric { values.append("biometric") }
        if config.enableSecureStorage { values.append("secureStorage") }
        if config.enableLocalDatabase { values.append("database") }
        if config.enableDeepLinks { values.append("deepLinks") }
        if config.enableLocalNotifications { values.append("notifications") }
        if config.enableHealthKit { values.append("health") }
        // The in-app browser and the system's web sign-in sheet (CraftBrowser).
        values.append("browser")
        if config.enableSocialAuth { values.append("appleSignIn") }
        if config.enablePushNotifications { values.append("push") }
        if config.enableShare { values.append("share") }
        // The screen's brightness and the status bar's style need nothing
        // declared; keeping the screen awake is the app's choice.
        values.append(contentsOf: ["brightness", "statusBar"])
        if config.enableKeepAwake { values.append("keepAwake") }
        // GPS and the route recording are the web view's coordinator's
        // (CraftWebServices); an app with no web view has the coordinator
        // all the same (CraftHybrid.configure).
        if config.enableGeolocation { values.append("geolocation") }
        // The Music app's song and transport are the coordinator's too.
        if config.enableAppleMusic { values.append("music") }
        // `craft.background.complete(ok, id)`: the answer to a silent push or
        // a background refresh, which the app script (`nativeApp`) hears.
        if config.backgroundRefresh?.enabled == true || config.enablePushNotifications { values.append("background") }
        // A heart-rate strap is the app's own service (CraftHeartRate.swift),
        // so it needs no web view.
        if config.enableHeartRate { values.append("heartRate") }
        // Workouts on the paired Apple Watch (CraftScheduledWorkouts.swift),
        // also the app's own service.
        if config.enableScheduledWorkouts { values.append("scheduledWorkouts") }
        // Photos picked from the library, files downloaded for the share
        // sheet and sent in a form (CraftNativeFiles.swift): the photo picker
        // runs out of process and asks no permission. Taking a photo needs
        // the camera, which the app declares.
        values.append("files")
        if config.enableCamera { values.append("camera") }
        return values
    }

    /// Nil means this small shared router does not own the action.
    static func perform(action: String, body: [String: Any], config: CraftConfig) -> Result<Any, CraftNativeActionError>? {
        switch action {
        case "getDeviceInfo":
            return .success(deviceInfo())
        case "haptic":
            guard config.enableHaptics else { return failure("CAPABILITY_DISABLED", "Haptics is disabled") }
            triggerHaptic(style: body["style"] as? String ?? "medium")
            return .success(true)
        case "hapticPrepare":
            guard config.enableHaptics else { return failure("CAPABILITY_DISABLED", "Haptics is disabled") }
            CraftHaptics.prepare(body["kind"] as? String)
            return .success(true)
        case "clipboardWrite":
            guard config.enableClipboard else { return failure("CAPABILITY_DISABLED", "Clipboard is disabled") }
            guard let text = body["text"] as? String else {
                return failure("INVALID_ARGUMENT", "clipboardWrite was called without the values it needs")
            }
            UIPasteboard.general.string = text
            return .success(true)
        case "clipboardRead":
            guard config.enableClipboard else { return failure("CAPABILITY_DISABLED", "Clipboard is disabled") }
            return .success(UIPasteboard.general.string ?? "")
        default:
            return nil
        }
    }

    static func perform(
        requestToken: String,
        version: Int,
        module: String,
        method: String,
        args: [Any],
        config: CraftConfig,
        completion: @escaping (Result<Any, CraftNativeActionError>) -> Void
    ) {
        cancellationLock.lock()
        cancelledRequests.remove(requestToken)
        cancellationLock.unlock()
        guard version == craftNativeCapabilityProtocolVersion else {
            complete(requestToken, failure("UNSUPPORTED_VERSION", "Unsupported native capability protocol version"), completion)
            return
        }

        let sync: Result<Any, CraftNativeActionError>?
        switch (module, method) {
        case ("Device", "getInfo"):
            sync = perform(action: "getDeviceInfo", body: [:], config: config)
        case ("Haptics", "impact"):
            sync = perform(action: "haptic", body: ["style": args.first ?? NSNull()], config: config)
        case ("Haptics", "notification"):
            sync = perform(action: "haptic", body: ["style": (args.first as? String) ?? "success"], config: config)
        case ("Haptics", "selection"):
            sync = perform(action: "haptic", body: ["style": "selection"], config: config)
        case ("Haptics", "prepare"):
            sync = perform(action: "hapticPrepare", body: ["kind": args.first ?? NSNull()], config: config)
        case ("Clipboard", "write"):
            sync = perform(action: "clipboardWrite", body: ["text": args.first ?? NSNull()], config: config)
        case ("Clipboard", "read"):
            sync = perform(action: "clipboardRead", body: [:], config: config)
        case ("Storage", _):
            sync = storage(method: method, args: args)
        case ("SecureStorage", _):
            guard config.enableSecureStorage else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "Secure storage is disabled"), completion)
                return
            }
            sync = secureStorage(method: method, args: args)
            // A key the web page shares (`shareStorage`): the page gets it too,
            // so a sign-in on a native screen signs the page in.
            if case .success = sync, ["set", "remove", "delete"].contains(method), let key = args.first as? String {
                CraftHybrid.shared.nativeWroteShared(nativeKey: key, value: method == "set" ? args.count > 1 ? args[1] as? String : nil : nil)
            }
        case ("Biometrics", "isAvailable"):
            sync = config.enableBiometric ? .success(biometricContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)) : failure("CAPABILITY_DISABLED", "Biometric authentication is disabled")
        case ("Biometrics", "getBiometricType"):
            sync = config.enableBiometric ? .success(biometricType()) : failure("CAPABILITY_DISABLED", "Biometric authentication is disabled")
        case ("Biometrics", "authenticate"):
            guard config.enableBiometric else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "Biometric authentication is disabled"), completion)
                return
            }
            authenticate(requestToken: requestToken, args: args, completion: completion)
            return
        case ("Network", "fetch"):
            fetch(requestToken: requestToken, args: args, completion: completion)
            return
        case ("Files", "pickImage"):
            // A person picks, so the bridge never times it out.
            let options = args.first as? [String: Any] ?? [:]
            DispatchQueue.main.async {
                CraftNativeFiles.pickImage(options, cameraEnabled: config.enableCamera) { complete(requestToken, $0, completion) }
            }
            return
        case ("Files", "download"):
            download(requestToken: requestToken, args: args, completion: completion)
            return
        case ("Files", "write"):
            // Something the screen made (a CSV export) as a file for the
            // share sheet; the disk work is off the main thread.
            let name = args.first as? String ?? ""
            let data = args.count > 1 ? args[1] : nil
            let options = args.count > 2 ? args[2] as? [String: Any] ?? [:] : [:]
            DispatchQueue.global(qos: .userInitiated).async {
                complete(requestToken, CraftNativeFiles.write(name: name, data: data, options: options), completion)
            }
            return
        case ("Files", "remove"):
            sync = .success(CraftNativeFiles.remove(args.first as? String ?? ""))
        case ("Lifecycle", "getState"):
            sync = .success(currentAppState())
        case ("DeepLinks", "getInitialURL"):
            if config.enableDeepLinks {
                sync = .success(claimInitialDeepLink().map(deepLinkData) ?? NSNull())
            } else {
                sync = failure("CAPABILITY_DISABLED", "Deep links are disabled")
            }
        case ("Database", _):
            guard config.enableLocalDatabase else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "Local database is disabled"), completion)
                return
            }
            databaseQueue.async { complete(requestToken, database(method: method, args: args), completion) }
            return
        case ("Browser", "open"):
            // SFSafariViewController, or for `mode: 'auth'` the system's web
            // sign-in sheet, the same as a page's `craft.browser.open`.
            guard let address = args.first as? String, let url = URL(string: address) else {
                complete(requestToken, failure("INVALID_ARGUMENT", "Browser.open needs a URL it can parse"), completion)
                return
            }
            let options = args.count > 1 ? args[1] as? [String: Any] ?? [:] : [:]
            DispatchQueue.main.async {
                CraftBrowser.shared.open(url, mode: options["mode"] as? String ?? "safari", callbackScheme: options["callbackScheme"] as? String, from: nil) { answer in
                    complete(requestToken, .success(answer), completion)
                }
            }
            return
        case ("Auth", "signInWithApple"):
            guard config.enableSocialAuth else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "Social sign-in is disabled"), completion)
                return
            }
            let options = args.first as? [String: Any] ?? [:]
            DispatchQueue.main.async {
                CraftSignInWithApple.shared.signIn(nonce: options["nonce"] as? String) { result in
                    complete(requestToken, result.mapError { CraftNativeActionError(code: $0.code, message: $0.message) }.map { $0 as Any }, completion)
                }
            }
            return
        case ("Dialog", _):
            // The system's own alert, confirmation and action sheet, the same
            // ones a page gets (CraftNativeUI.swift), over the native screen.
            let body = args.first as? [String: Any] ?? [:]
            DispatchQueue.main.async {
                switch method {
                case "alert":
                    CraftDialogs.alert(body, from: nil) { complete(requestToken, .success(NSNull()), completion) }
                case "confirm":
                    CraftDialogs.confirm(body, from: nil) { complete(requestToken, .success($0), completion) }
                case "actionSheet":
                    CraftDialogs.actionSheet(body, from: nil) { complete(requestToken, .success($0 ?? NSNull()), completion) }
                default:
                    complete(requestToken, failure("UNKNOWN_ACTION", "Unsupported Dialog method"), completion)
                }
            }
            return
        case ("Health", _):
            // Apple Health, the same as a page's `craft.health` (CraftHealth.swift).
            guard config.enableHealthKit else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "HealthKit is disabled"), completion)
                return
            }
            CraftHealth.shared.perform(method: method, args: args) { result in
                complete(requestToken, result.mapError { CraftNativeActionError(code: $0.code, message: $0.message) }, completion)
            }
            return
        case ("KeepAwake", "set"):
            guard config.enableKeepAwake else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "Keep awake is disabled"), completion)
                return
            }
            let enabled = args.first as? Bool ?? true
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = enabled
                complete(requestToken, .success(enabled), completion)
            }
            return
        case ("Brightness", "get"):
            DispatchQueue.main.async { complete(requestToken, .success(Double(UIScreen.main.brightness)), completion) }
            return
        case ("Brightness", "set"):
            // The device's backlight, system-wide: a screen that dims it reads
            // it first and puts it back, as @stacksjs/mobile's brightness does.
            guard let level = (args.first as? NSNumber)?.doubleValue, level.isFinite else {
                complete(requestToken, failure("INVALID_ARGUMENT", "Brightness.set needs a level from 0 to 1"), completion)
                return
            }
            DispatchQueue.main.async {
                UIScreen.main.brightness = CGFloat(min(max(level, 0), 1))
                complete(requestToken, .success(Double(UIScreen.main.brightness)), completion)
            }
            return
        case ("StatusBar", "setStyle"):
            let style = args.first as? String ?? "default"
            DispatchQueue.main.async {
                complete(requestToken, .success(CraftStatusBar.setStyle(style == "light" || style == "dark" ? style : "default")), completion)
            }
            return
        case ("Location", _):
            // The page's own GPS and route recorder, in the web view's
            // coordinator: one recorder, which keeps recording in the
            // background and survives a relaunch, whichever side started it.
            guard config.enableGeolocation else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "Geolocation is disabled"), completion)
                return
            }
            let actions = [
                "getCurrentPosition": "getCurrentPosition", "watchPosition": "watchPosition", "clearWatch": "clearWatch",
                "startRecording": "startLocationRecording", "pauseRecording": "pauseLocationRecording",
                "resumeRecording": "resumeLocationRecording", "stopRecording": "stopLocationRecording",
                "getRecordingState": "getLocationRecordingState", "readRecording": "readLocationRecording",
            ]
            guard let action = actions[method] else {
                complete(requestToken, failure("UNKNOWN_ACTION", "Unsupported Location method"), completion)
                return
            }
            CraftWebServices.perform(action: action, body: args.first as? [String: Any] ?? [:]) { complete(requestToken, $0, completion) }
            return
        case ("Music", _):
            // The page's own Music app bridge (CraftMusic.swift), in the web
            // view's coordinator: one observer, whose changes reach the page
            // and every native screen as `craftMusicChange`.
            guard config.enableAppleMusic else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "Apple Music is disabled"), completion)
                return
            }
            let actions = [
                "getAuthorizationStatus": "musicGetAuthorization", "requestAuthorization": "musicRequestAuthorization",
                "getNowPlaying": "musicGetNowPlaying", "control": "musicControl", "observe": "musicObserve",
            ]
            guard let action = actions[method] else {
                complete(requestToken, failure("UNKNOWN_ACTION", "Unsupported Music method"), completion)
                return
            }
            CraftWebServices.perform(action: action, body: args.first as? [String: Any] ?? [:]) { complete(requestToken, $0, completion) }
            return
        case ("HeartRate", _):
            // A Bluetooth heart-rate strap, the same service as a page's
            // `craft.heartRate`: one connection and one recording, whichever
            // side started them. Its events reach every screen as
            // `craftHeartRate`.
            guard config.enableHeartRate else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "Heart rate is disabled"), completion)
                return
            }
            CraftHeartRate.shared.perform(method: method, args: args) { result in
                complete(requestToken, result.mapError { CraftNativeActionError(code: $0.code, message: $0.message) }, completion)
            }
            return
        case ("ScheduledWorkouts", _):
            // Workouts on the paired Apple Watch, the same service as a
            // page's `craft.scheduledWorkouts` (WorkoutKit's scheduler).
            guard config.enableScheduledWorkouts else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "Scheduled workouts are disabled"), completion)
                return
            }
            CraftScheduledWorkouts.shared.perform(method: method, args: args) { result in
                complete(requestToken, result.mapError { CraftNativeActionError(code: $0.code, message: $0.message) }, completion)
            }
            return
        case ("Linking", "openURL"), ("Linking", "canOpenURL"):
            // Another app or the system: `webcal:` subscriptions, `mailto:`,
            // `tel:`, the App Store, this app's page in Settings
            // (`UIApplication.openSettingsURLString`, which is `app-settings:`).
            guard let address = args.first as? String, let url = URL(string: address), url.scheme != nil else {
                complete(requestToken, failure("INVALID_ARGUMENT", "Linking.\(method) needs a URL it can parse"), completion)
                return
            }
            DispatchQueue.main.async {
                if method == "canOpenURL" {
                    complete(requestToken, .success(UIApplication.shared.canOpenURL(url)), completion)
                } else {
                    UIApplication.shared.open(url) { complete(requestToken, .success($0), completion) }
                }
            }
            return
        case ("Share", "share"):
            guard config.enableShare else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "Sharing is disabled"), completion)
                return
            }
            let options = args.first as? [String: Any] ?? [:]
            DispatchQueue.main.async {
                CraftNativeShare.share(options) { complete(requestToken, $0, completion) }
            }
            return
        case ("Speech", "speak"):
            // Settles when the words have been said (true) or were cut off
            // (false), as the page's `craft.speech.speak` does.
            guard let text = args.first as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                complete(requestToken, failure("INVALID_ARGUMENT", "speech.speak needs some text to say"), completion)
                return
            }
            let options = args.count > 1 ? args[1] as? [String: Any] ?? [:] : [:]
            DispatchQueue.main.async {
                CraftNativeSpeech.shared.speak(
                    text,
                    language: options["language"] as? String,
                    rate: (options["rate"] as? NSNumber)?.doubleValue,
                    interrupt: options["interrupt"] as? Bool ?? true
                ) { spoken in complete(requestToken, .success(spoken), completion) }
            }
            return
        case ("Speech", "stop"):
            DispatchQueue.main.async {
                CraftNativeSpeech.shared.stop()
                complete(requestToken, .success(true), completion)
            }
            return
        case ("Push", _):
            guard config.enablePushNotifications else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "Push notifications are disabled"), completion)
                return
            }
            switch method {
            case "getPermissionStatus":
                CraftNativePush.status { complete(requestToken, .success($0), completion) }
            case "requestPermission":
                CraftNativePush.requestPermission { complete(requestToken, .success($0), completion) }
            case "register":
                CraftNativePush.register { complete(requestToken, $0, completion) }
            case "openSettings":
                DispatchQueue.main.async {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else {
                        complete(requestToken, .success(false), completion)
                        return
                    }
                    UIApplication.shared.open(url) { complete(requestToken, .success($0), completion) }
                }
            default:
                complete(requestToken, failure("UNKNOWN_ACTION", "Unsupported Push method"), completion)
            }
            return
        case ("Background", "complete"):
            // The app script's answer to `craftSilentPush` or
            // `craftBackgroundRefresh`: args `[ok, id?]`, with no id for
            // everything still pending, as a page's `craft.background.complete`.
            guard config.backgroundRefresh?.enabled == true || config.enablePushNotifications else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "Background work is disabled"), completion)
                return
            }
            let ok = args.first as? Bool ?? true
            let id = args.count > 1 ? args[1] as? String : nil
            DispatchQueue.main.async {
                CraftBackgroundWork.shared.complete(id: id, ok: ok)
                complete(requestToken, .success(true), completion)
            }
            return
        case ("Notifications", _):
            guard config.enableLocalNotifications else {
                complete(requestToken, failure("CAPABILITY_DISABLED", "Local notifications are disabled"), completion)
                return
            }
            notifications(requestToken: requestToken, method: method, args: args, completion: completion)
            return
        default:
            sync = failure("UNKNOWN_ACTION", "Unsupported native API")
        }
        complete(requestToken, sync ?? failure("UNKNOWN_ACTION", "Unsupported native API"), completion)
    }

    static func cancel(requestToken: String) {
        cancellationLock.lock()
        cancelledRequests.insert(requestToken)
        let context = biometricContexts.removeValue(forKey: requestToken)
        let task = fetchTasks.removeValue(forKey: requestToken)
        cancellationLock.unlock()
        context?.invalidate()
        task?.cancel()
    }

    /// `fetch` for native screens: one URLSession data task per request, keyed
    /// by the request token so the bridge deadline, `API_CANCEL` and route
    /// teardown all cancel the transfer. Bodies are UTF-8 text both ways.
    private static func fetch(
        requestToken: String,
        args: [Any],
        completion: @escaping (Result<Any, CraftNativeActionError>) -> Void
    ) {
        guard let options = args.first as? [String: Any],
              let address = options["url"] as? String,
              let url = URL(string: address),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              url.host?.isEmpty == false else {
            complete(requestToken, failure("INVALID_ARGUMENT", "fetch needs an absolute http or https URL"), completion)
            return
        }
        let method = ((options["method"] as? String) ?? "GET").uppercased()
        guard !method.isEmpty, method.allSatisfy({ $0.isLetter && $0.isASCII }) else {
            complete(requestToken, failure("INVALID_ARGUMENT", "fetch method must be an HTTP token"), completion)
            return
        }
        var request = URLRequest(url: url, timeoutInterval: craftNativeFetchTimeoutSeconds)
        request.httpMethod = method
        if let headers = options["headers"] as? [String: Any] {
            for (name, value) in headers {
                guard let value = value as? String else {
                    complete(requestToken, failure("INVALID_ARGUMENT", "fetch header values must be strings"), completion)
                    return
                }
                request.setValue(value, forHTTPHeaderField: name)
            }
        }
        if let form = options["form"] as? [Any] {
            // A screen's FormData: text fields, and files craft.files made.
            guard method != "GET", method != "HEAD" else {
                complete(requestToken, failure("INVALID_ARGUMENT", "A GET or HEAD request cannot have a body"), completion)
                return
            }
            switch CraftNativeFiles.multipart(form) {
            case .failure(let error):
                complete(requestToken, .failure(error), completion)
                return
            case .success(let (data, boundary)):
                request.httpBody = data
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            }
        } else if let body = options["body"] as? String {
            guard method != "GET", method != "HEAD" else {
                complete(requestToken, failure("INVALID_ARGUMENT", "A GET or HEAD request cannot have a body"), completion)
                return
            }
            request.httpBody = Data(body.utf8)
        } else if let body = options["body"], !(body is NSNull) {
            complete(requestToken, failure("INVALID_ARGUMENT", "fetch body must be a string"), completion)
            return
        }

        let task = fetchSession.dataTask(with: request) { data, response, error in
            cancellationLock.lock()
            fetchTasks.removeValue(forKey: requestToken)
            cancellationLock.unlock()
            if let error = error {
                let code = (error as? URLError)?.code == .timedOut ? "TIMEOUT" : "NETWORK_ERROR"
                complete(requestToken, failure(code, error.localizedDescription), completion)
                return
            }
            guard let http = response as? HTTPURLResponse else {
                complete(requestToken, failure("NETWORK_ERROR", "fetch received a response that is not HTTP"), completion)
                return
            }
            let body = data ?? Data()
            guard body.count <= craftNativeFetchMaxResponseBytes else {
                complete(requestToken, failure("RESPONSE_TOO_LARGE", "fetch responses are limited to \(craftNativeFetchMaxResponseBytes) bytes"), completion)
                return
            }
            var headers: [String: String] = [:]
            for (name, value) in http.allHeaderFields {
                headers[String(describing: name).lowercased()] = String(describing: value)
            }
            complete(requestToken, .success([
                "url": http.url?.absoluteString ?? address,
                "status": http.statusCode,
                "statusText": HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                "headers": headers,
                "redirected": http.url.map { $0 != url } ?? false,
                "body": String(decoding: body, as: UTF8.self),
            ]), completion)
        }
        cancellationLock.lock()
        let alreadyCancelled = cancelledRequests.contains(requestToken)
        if !alreadyCancelled { fetchTasks[requestToken] = task }
        cancellationLock.unlock()
        if !alreadyCancelled { task.resume() }
    }

    /// `craft.files.download`: a GET straight to a file made here (for the
    /// share sheet), with the screen's headers, so a large file never passes
    /// through JavaScriptCore. A refused answer (not 2xx) keeps no file and
    /// hands back its status and the start of its body. Cancelled like fetch.
    private static func download(
        requestToken: String,
        args: [Any],
        completion: @escaping (Result<Any, CraftNativeActionError>) -> Void
    ) {
        guard let address = args.first as? String,
              let url = URL(string: address),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              url.host?.isEmpty == false else {
            complete(requestToken, failure("INVALID_ARGUMENT", "files.download needs an absolute http or https URL"), completion)
            return
        }
        let options = args.count > 1 ? args[1] as? [String: Any] ?? [:] : [:]
        var request = URLRequest(url: url, timeoutInterval: craftNativeFetchTimeoutSeconds)
        request.httpMethod = "GET"
        if let headers = options["headers"] as? [String: Any] {
            for (name, value) in headers {
                guard let value = value as? String else {
                    complete(requestToken, failure("INVALID_ARGUMENT", "files.download header values must be strings"), completion)
                    return
                }
                request.setValue(value, forHTTPHeaderField: name)
            }
        }
        let name = options["name"] as? String
        let task = fetchSession.downloadTask(with: request) { location, response, error in
            cancellationLock.lock()
            fetchTasks.removeValue(forKey: requestToken)
            cancellationLock.unlock()
            if let error = error {
                let code = (error as? URLError)?.code == .timedOut ? "TIMEOUT" : "NETWORK_ERROR"
                complete(requestToken, failure(code, error.localizedDescription), completion)
                return
            }
            guard let http = response as? HTTPURLResponse else {
                complete(requestToken, failure("NETWORK_ERROR", "files.download received a response that is not HTTP"), completion)
                return
            }
            // The system deletes `location` once this returns: keep or read it now.
            guard (200..<300).contains(http.statusCode), let location else {
                complete(requestToken, .success(CraftNativeFiles.refusedDownload(at: location, response: http)), completion)
                return
            }
            complete(requestToken, CraftNativeFiles.keepDownload(at: location, response: http, name: name), completion)
        }
        cancellationLock.lock()
        let alreadyCancelled = cancelledRequests.contains(requestToken)
        if !alreadyCancelled { fetchTasks[requestToken] = task }
        cancellationLock.unlock()
        if !alreadyCancelled { task.resume() }
    }

    private static func claimInitialDeepLink() -> URL? {
        cancellationLock.lock()
        defer { cancellationLock.unlock() }
        guard !initialDeepLinkClaimed else { return nil }
        initialDeepLinkClaimed = true
        return DeepLinkManager.shared.getInitialURL()
    }

    private static func complete(
        _ requestToken: String,
        _ result: Result<Any, CraftNativeActionError>,
        _ completion: @escaping (Result<Any, CraftNativeActionError>) -> Void
    ) {
        DispatchQueue.main.async {
            cancellationLock.lock()
            let cancelled = cancelledRequests.remove(requestToken) != nil
            cancellationLock.unlock()
            if !cancelled { completion(result) }
        }
    }

    private static func storage(method: String, args: [Any]) -> Result<Any, CraftNativeActionError> {
        if method == "clear" {
            for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(storagePrefix) {
                UserDefaults.standard.removeObject(forKey: key)
            }
            return .success(true)
        }
        if method == "keys" {
            let keys = UserDefaults.standard.dictionaryRepresentation().keys
                .filter { $0.hasPrefix(storagePrefix) }
                .map { String($0.dropFirst(storagePrefix.count)) }
                .sorted()
            return .success(keys)
        }
        guard let key = validKey(args.first) else { return failure("INVALID_ARGUMENT", "Storage needs a non-empty key") }
        let defaultsKey = storagePrefix + key
        switch method {
        case "get":
            guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return .success(NSNull()) }
            do {
                return .success(try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]))
            } catch {
                return failure("STORAGE_CORRUPT", "Stored value is not valid JSON")
            }
        case "set":
            guard args.count == 2 else { return failure("INVALID_ARGUMENT", "Storage.set needs a key and value") }
            do {
                let data = try JSONSerialization.data(withJSONObject: args[1], options: [.fragmentsAllowed])
                UserDefaults.standard.set(data, forKey: defaultsKey)
                return .success(true)
            } catch {
                return failure("INVALID_ARGUMENT", "Storage values must be JSON serializable")
            }
        case "remove":
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            return .success(true)
        default:
            return failure("UNKNOWN_ACTION", "Unsupported Storage method")
        }
    }

    private static func secureStorage(method: String, args: [Any]) -> Result<Any, CraftNativeActionError> {
        let service = "dev.craft.native.secure"
        if method == "clear" {
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                return failure("SECURE_STORAGE_ERROR", "Secure storage could not be cleared")
            }
            return .success(true)
        }
        guard let key = validKey(args.first) else { return failure("INVALID_ARGUMENT", "Secure storage needs a non-empty key") }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        switch method {
        case "set":
            guard args.count == 2, let value = args[1] as? String else {
                return failure("INVALID_ARGUMENT", "SecureStorage.set needs a key and string value")
            }
            var query = base
            query[kSecValueData as String] = Data(value.utf8)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let removed = SecItemDelete(base as CFDictionary)
            guard removed == errSecSuccess || removed == errSecItemNotFound else {
                return failure("SECURE_STORAGE_ERROR", "Secure storage could not be replaced (\(removed))")
            }
            let status = SecItemAdd(query as CFDictionary, nil)
            return status == errSecSuccess ? .success(true) : failure("SECURE_STORAGE_ERROR", "Secure storage could not be written (\(status))")
        case "get":
            var query = base
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound { return .success(NSNull()) }
            guard status == errSecSuccess, let data = result as? Data else {
                return failure("SECURE_STORAGE_ERROR", "Secure storage could not be read")
            }
            return .success(String(decoding: data, as: UTF8.self))
        case "remove":
            let status = SecItemDelete(base as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound ? .success(true) : failure("SECURE_STORAGE_ERROR", "Secure storage could not be removed")
        default:
            return failure("UNKNOWN_ACTION", "Unsupported SecureStorage method")
        }
    }

    private static func biometricContext() -> LAContext {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        return context
    }

    private static func biometricType() -> String {
        let context = biometricContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "faceId"
        case .touchID: return "touchId"
        default: return "none"
        }
    }

    private static func authenticate(
        requestToken: String,
        args: [Any],
        completion: @escaping (Result<Any, CraftNativeActionError>) -> Void
    ) {
        let reason = (args.first as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Authenticate to continue"
        let context = biometricContext()
        cancellationLock.lock()
        biometricContexts[requestToken] = context
        cancellationLock.unlock()
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { result, error in
            cancellationLock.lock()
            biometricContexts.removeValue(forKey: requestToken)
            cancellationLock.unlock()
            if result { complete(requestToken, .success(true), completion) }
            else { complete(requestToken, failure("AUTHENTICATION_FAILED", error?.localizedDescription ?? "Biometric authentication failed"), completion) }
        }
    }

    private static func database(method: String, args: [Any]) -> Result<Any, CraftNativeActionError> {
        guard openDatabase() else { return failure("DATABASE_ERROR", "Could not open the local database") }
        switch method {
        case "execute":
            guard let sql = args.first as? String, !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return failure("INVALID_ARGUMENT", "Database.execute needs a SQL statement")
            }
            return execute(sql: sql, params: args.count > 1 ? args[1] as? [Any] ?? [] : [])
        case "query":
            guard let sql = args.first as? String, !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return failure("INVALID_ARGUMENT", "Database.query needs a SQL statement")
            }
            return query(sql: sql, params: args.count > 1 ? args[1] as? [Any] ?? [] : [])
        case "beginTransaction": return transaction(sql: "BEGIN TRANSACTION")
        case "commit": return transaction(sql: "COMMIT")
        case "rollback": return transaction(sql: "ROLLBACK")
        default: return failure("UNKNOWN_ACTION", "Unsupported Database method")
        }
    }

    private static func transaction(sql: String) -> Result<Any, CraftNativeActionError> {
        switch execute(sql: sql, params: []) {
        case .success: return .success(true)
        case .failure(let error): return .failure(error)
        }
    }

    private static func openDatabase() -> Bool {
        if database != nil { return true }
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return false }
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) } catch { return false }
        let path = directory.appendingPathComponent("craft-native.sqlite").path
        if sqlite3_open(path, &database) != SQLITE_OK {
            if database != nil { sqlite3_close(database) }
            database = nil
            return false
        }
        sqlite3_busy_timeout(database, 5_000)
        return true
    }

    private static func bind(_ params: [Any], to statement: OpaquePointer?) -> Bool {
        for (offset, value) in params.enumerated() {
            let index = Int32(offset + 1)
            let code: Int32
            switch value {
            case is NSNull: code = sqlite3_bind_null(statement, index)
            case let string as String: code = sqlite3_bind_text(statement, index, string, -1, sqliteTransient)
            case let number as NSNumber:
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    code = sqlite3_bind_int64(statement, index, number.boolValue ? 1 : 0)
                } else if number.doubleValue.rounded() == number.doubleValue {
                    code = sqlite3_bind_int64(statement, index, number.int64Value)
                } else {
                    code = sqlite3_bind_double(statement, index, number.doubleValue)
                }
            default: return false
            }
            if code != SQLITE_OK { return false }
        }
        return true
    }

    private static func execute(sql: String, params: [Any]) -> Result<Any, CraftNativeActionError> {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return databaseFailure() }
        defer { sqlite3_finalize(statement) }
        guard bind(params, to: statement) else { return failure("INVALID_ARGUMENT", "Database parameters must be strings, numbers, booleans, or null") }
        guard sqlite3_step(statement) == SQLITE_DONE else { return databaseFailure() }
        return .success(["rowsAffected": Int(sqlite3_changes(database)), "lastInsertId": Int(sqlite3_last_insert_rowid(database))])
    }

    private static func query(sql: String, params: [Any]) -> Result<Any, CraftNativeActionError> {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return databaseFailure() }
        defer { sqlite3_finalize(statement) }
        guard bind(params, to: statement) else { return failure("INVALID_ARGUMENT", "Database parameters must be strings, numbers, booleans, or null") }
        var rows: [[String: Any]] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { return .success(rows) }
            guard step == SQLITE_ROW else { return databaseFailure() }
            var row: [String: Any] = [:]
            for column in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, column))
                switch sqlite3_column_type(statement, column) {
                case SQLITE_INTEGER: row[name] = Int(sqlite3_column_int64(statement, column))
                case SQLITE_FLOAT: row[name] = sqlite3_column_double(statement, column)
                case SQLITE_TEXT: row[name] = sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
                case SQLITE_BLOB:
                    let length = Int(sqlite3_column_bytes(statement, column))
                    row[name] = sqlite3_column_blob(statement, column).map { Data(bytes: $0, count: length).base64EncodedString() } ?? ""
                default: row[name] = NSNull()
                }
            }
            rows.append(row)
        }
    }

    private static func databaseFailure() -> Result<Any, CraftNativeActionError> {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Database unavailable"
        return failure("DATABASE_ERROR", message)
    }

    private static func notifications(
        requestToken: String,
        method: String,
        args: [Any],
        completion: @escaping (Result<Any, CraftNativeActionError>) -> Void
    ) {
        let center = UNUserNotificationCenter.current()
        switch method {
        case "cancel":
            guard let id = validKey(args.first) else {
                complete(requestToken, failure("INVALID_ARGUMENT", "Notifications.cancel needs an id"), completion)
                return
            }
            center.removePendingNotificationRequests(withIdentifiers: [id])
            complete(requestToken, .success(true), completion)
        case "cancelAll":
            center.removeAllPendingNotificationRequests()
            complete(requestToken, .success(true), completion)
        case "pending":
            center.getPendingNotificationRequests { requests in
                complete(requestToken, .success(requests.map { request in
                    ["id": request.identifier, "title": request.content.title, "body": request.content.body]
                }), completion)
            }
        case "schedule":
            guard let value = args.first as? [String: Any], let title = value["title"] as? String, !title.isEmpty else {
                complete(requestToken, failure("INVALID_ARGUMENT", "Notifications.schedule needs a title"), completion)
                return
            }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, authorizationError in
                guard authorizationError == nil, granted else {
                    complete(requestToken, failure("PERMISSION_DENIED", authorizationError?.localizedDescription ?? "Notification permission denied"), completion)
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = value["body"] as? String ?? ""
                content.sound = .default
                if let data = value["data"] as? [String: Any] { content.userInfo = data }
                if let badge = value["badge"] as? NSNumber { content.badge = badge }
                let id = (value["id"] as? String).flatMap { validKey($0) } ?? UUID().uuidString
                let delay = (value["delay"] as? NSNumber)?.doubleValue
                let trigger = delay.map { UNTimeIntervalNotificationTrigger(timeInterval: max($0 / 1_000, 1), repeats: false) }
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { addError in
                    if let addError = addError {
                        complete(requestToken, failure("NOTIFICATION_ERROR", addError.localizedDescription), completion)
                    } else {
                        complete(requestToken, .success(id), completion)
                    }
                }
            }
        default:
            complete(requestToken, failure("UNKNOWN_ACTION", "Unsupported Notifications method"), completion)
        }
    }

    static func deepLinkData(_ url: URL) -> [String: Any] {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return [
            "url": url.absoluteString,
            "scheme": url.scheme ?? "",
            "host": url.host ?? "",
            "path": url.path,
            "query": url.query ?? "",
            "queryParams": Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") }),
        ]
    }

    static func triggerHaptic(style: String) {
        CraftHaptics.play(style)
    }

    static func currentAppState() -> String {
        switch UIApplication.shared.applicationState {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "inactive"
        }
    }

    private static func validKey(_ value: Any?) -> String? {
        guard let key = value as? String, !key.isEmpty, key.count <= 512, !key.contains("\0") else { return nil }
        return key
    }

    private static func error(_ code: String, _ message: String) -> CraftNativeActionError {
        CraftNativeActionError(code: code, message: message)
    }

    private static func failure(_ code: String, _ message: String) -> Result<Any, CraftNativeActionError> {
        .failure(error(code, message))
    }

    private static func deviceInfo() -> [String: Any] {
        let device = UIDevice.current
        let screen = UIScreen.main
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        let batteryState: String
        switch device.batteryState {
        case .charging: batteryState = "charging"
        case .full: batteryState = "full"
        case .unplugged: batteryState = "unplugged"
        default: batteryState = "unknown"
        }
        return [
            "platform": "ios",
            "osVersion": device.systemVersion,
            "model": device.model,
            "manufacturer": "Apple",
            "deviceId": device.identifierForVendor?.uuidString ?? "",
            "isTablet": device.userInterfaceIdiom == .pad,
            "screen": ["width": screen.bounds.width, "height": screen.bounds.height, "scale": screen.scale],
            "battery": ["level": device.batteryLevel, "isCharging": device.batteryState == .charging || device.batteryState == .full],
            "locale": Locale.current.identifier,
            "timezone": TimeZone.current.identifier,
            "isSimulator": isSimulator,
            "name": device.name,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "identifierForVendor": device.identifierForVendor?.uuidString ?? "",
            "screenWidth": screen.bounds.width,
            "screenHeight": screen.bounds.height,
            "screenScale": screen.scale,
            "batteryLevel": device.batteryLevel,
            "batteryState": batteryState,
        ]
    }
}

// MARK: - Synchronous reads for a screen's first frame

extension CraftNativeActions {
    /// The JSON text `craft.storage` keeps under `key`, or nil. The same store
    /// as the asynchronous Storage module, read without a bridge round trip.
    static func storageJSON(forKey key: String) -> String? {
        guard let key = validKey(key), let data = UserDefaults.standard.data(forKey: storagePrefix + key) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// Stores JSON text under `key` (nil removes it). False for an invalid key
    /// or text that is not JSON, which the asynchronous `get` could not read.
    @discardableResult
    static func setStorageJSON(_ json: String?, forKey key: String) -> Bool {
        guard let key = validKey(key) else { return false }
        guard let json else {
            UserDefaults.standard.removeObject(forKey: storagePrefix + key)
            return true
        }
        let data = Data(json.utf8)
        guard (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil else { return false }
        UserDefaults.standard.set(data, forKey: storagePrefix + key)
        return true
    }

    /// The Keychain item the web page's `craft.secureStorage` wrote under
    /// `key`: a generic password whose account is the key, as CraftApp's
    /// `secureStore` writes it. Nil when there is none.
    static func webSecureValue(forKey key: String) -> String? {
        guard let key = validKey(key) else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// Last-known data for a screen's first frame: one JSON file per name in
/// `Application Support/craft-snapshots/<name>.json`. A web page writes them
/// (`snapshots.set` in the mobile API) and a native screen reads them
/// synchronously before its first render, or writes its own.
enum CraftSnapshots {
    static let changed = Notification.Name("craftSnapshotChanged")
    private static let queue = DispatchQueue(label: "dev.craft.snapshots", qos: .utility)
    private static let lock = NSLock()
    /// Writes not on disk yet, so a read right after a write sees it.
    private static var pending: [String: String?] = [:]

    static var directory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("craft-snapshots", isDirectory: true)
    }

    /// Letters, digits, `-`, `_` and `.`, not starting with a dot: a file
    /// name, never a path.
    static func isValidName(_ name: String) -> Bool {
        !name.isEmpty && name.count <= 128 && !name.hasPrefix(".")
            && name.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || "-_.".unicodeScalars.contains($0)) }
    }

    static func url(for name: String) -> URL? {
        guard isValidName(name) else { return nil }
        return directory?.appendingPathComponent("\(name).json", isDirectory: false)
    }

    /// The snapshot's JSON text, or nil.
    static func read(_ name: String) -> String? {
        guard let url = url(for: name) else { return nil }
        lock.lock()
        let waiting = pending[name]
        lock.unlock()
        if let waiting { return waiting }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// Replaces the snapshot with JSON text (nil deletes it) off the main
    /// thread, atomically. `completion` runs on the main queue.
    static func write(_ name: String, json: String?, completion: ((Bool) -> Void)? = nil) {
        guard let url = url(for: name), let directory else {
            DispatchQueue.main.async { completion?(false) }
            return
        }
        if let json, (try? JSONSerialization.jsonObject(with: Data(json.utf8), options: [.fragmentsAllowed])) == nil {
            DispatchQueue.main.async { completion?(false) }
            return
        }
        lock.lock()
        pending[name] = .some(json)
        lock.unlock()
        queue.async {
            var ok = true
            do {
                if let json {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try Data(json.utf8).write(to: url, options: [.atomic])
                } else if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            } catch {
                ok = false
            }
            lock.lock()
            if let current = pending[name], current == json { pending.removeValue(forKey: name) }
            lock.unlock()
            DispatchQueue.main.async {
                if ok { NotificationCenter.default.post(name: changed, object: nil, userInfo: ["name": name]) }
                completion?(ok)
            }
        }
    }

    /// Every snapshot there is: on disk, and written but not on disk yet.
    static func names() -> [String] {
        var names = Set(directory
            .flatMap { try? FileManager.default.contentsOfDirectory(atPath: $0.path) }?
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(5)) } ?? [])
        lock.lock()
        for (name, json) in pending {
            if json == nil { names.remove(name) } else { names.insert(name) }
        }
        lock.unlock()
        return names.filter(isValidName).sorted()
    }

    /// Deletes every snapshot but the ones named in `keep` (a sign-out), each
    /// as `write(name, json: nil)` does, so each posts `changed`.
    /// `completion` runs on the main queue: true when every one went.
    static func clear(keeping keep: Set<String> = [], completion: ((Bool) -> Void)? = nil) {
        let doomed = names().filter { !keep.contains($0) }
        guard !doomed.isEmpty else {
            DispatchQueue.main.async { completion?(true) }
            return
        }
        let group = DispatchGroup()
        var allRemoved = true
        for name in doomed {
            group.enter()
            write(name, json: nil) { ok in
                if !ok { allRemoved = false }
                group.leave()
            }
        }
        group.notify(queue: .main) { completion?(allRemoved) }
    }
}

/// The Taptic Engine's generators, held for the life of the process.
///
/// Each haptic used to make a fresh generator at the moment of the tap. A new
/// generator has to wake the engine before it can play, which is the tens of
/// milliseconds between a finger landing and the feel that makes web haptics
/// read as late. These are made once, prepared again after every use, and
/// `prepare` lets a page warm one before a gesture it knows is coming (the
/// start of a drag, a long press about to complete).
///
/// The three kinds are the three UIKit has, and they are not interchangeable:
/// a notification is the success, warning or error pattern, a selection is the
/// detent a picker plays, and an impact is a single tap at one of five weights.
/// The page used to get impacts for all of them.
///
/// Main thread only, like every UIFeedbackGenerator. Every caller is.
enum CraftHaptics {
    private static var impacts: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    private static var notifier: UINotificationFeedbackGenerator?
    private static var selector: UISelectionFeedbackGenerator?

    /// An impact weight by name, or nil for a name that is not one.
    static func impactStyle(_ name: String) -> UIImpactFeedbackGenerator.FeedbackStyle? {
        switch name {
        case "light": return .light
        case "medium": return .medium
        case "heavy": return .heavy
        case "soft": return .soft
        case "rigid": return .rigid
        default: return nil
        }
    }

    /// Play one haptic: an impact weight, a notification type, or `selection`.
    /// Anything else plays a medium impact, as an unknown style always has.
    static func play(_ style: String) {
        switch style {
        case "success": notification().notificationOccurred(.success); notification().prepare()
        case "warning": notification().notificationOccurred(.warning); notification().prepare()
        case "error": notification().notificationOccurred(.error); notification().prepare()
        case "selection": selection().selectionChanged(); selection().prepare()
        default:
            let generator = impact(impactStyle(style) ?? .medium)
            generator.impactOccurred()
            generator.prepare()
        }
    }

    /// Warm a generator so the next haptic plays without the engine's wake-up
    /// delay. `impact`, `notification` or `selection` for one kind, an impact
    /// weight or notification type for that one, nothing for all of them.
    /// UIKit keeps a prepared engine awake for a few seconds only.
    static func prepare(_ kind: String?) {
        switch kind {
        case "impact": impact(.medium).prepare()
        case "notification", "success", "warning", "error": notification().prepare()
        case "selection": selection().prepare()
        case let name? where impactStyle(name) != nil: impact(impactStyle(name)!).prepare()
        default:
            impact(.medium).prepare()
            notification().prepare()
            selection().prepare()
        }
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if let generator = impacts[style] { return generator }
        let generator = UIImpactFeedbackGenerator(style: style)
        impacts[style] = generator
        return generator
    }

    private static func notification() -> UINotificationFeedbackGenerator {
        if let notifier { return notifier }
        let generator = UINotificationFeedbackGenerator()
        notifier = generator
        return generator
    }

    private static func selection() -> UISelectionFeedbackGenerator {
        if let selector { return selector }
        let generator = UISelectionFeedbackGenerator()
        selector = generator
        return generator
    }
}
