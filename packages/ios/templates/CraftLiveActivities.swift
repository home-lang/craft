import ActivityKit
import Foundation

/// ActivityKit belongs to the process, not a web view or a retained STX screen.
/// A stable application activityId reattaches after a screen or app restart.
enum CraftLiveActivities {
    static func perform(method: String, args: [Any], enabled: Bool, appName: String, completion: @escaping (Result<Any, CraftNativeActionError>) -> Void) {
        guard enabled else {
            if method == "isAvailable" { completion(.success(false)); return }
            completion(.failure(CraftNativeActionError(code: "CAPABILITY_DISABLED", message: "Live Activities are disabled")))
            return
        }
        guard #available(iOS 16.2, *) else {
            if method == "isAvailable" { completion(.success(false)) }
            else { completion(.failure(CraftNativeActionError(code: "UNSUPPORTED", message: "Live Activities require iOS 16.2"))) }
            return
        }
        Task { @MainActor in
            do {
                let activities = Activity<CraftActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
                switch method {
                case "isAvailable": completion(.success(ActivityAuthorizationInfo().areActivitiesEnabled))
                case "list": completion(.success(activities.map { ["id": $0.id, "activityId": $0.attributes.activityId, "title": $0.attributes.title] }))
                case "start":
                    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                        throw CraftNativeActionError(code: "NOT_ALLOWED", message: "Live Activities are turned off in Settings")
                    }
                    let body = args.first as? [String: Any] ?? [:]
                    guard let key = body["activityId"] as? String, !key.isEmpty,
                          let title = body["title"] as? String, !title.isEmpty else {
                        throw CraftNativeActionError(code: "INVALID_ARGUMENT", message: "A Live Activity needs activityId and title")
                    }
                    let state = content(body)
                    if let existing = activities.first(where: { $0.attributes.activityId == key }) {
                        await existing.update(ActivityContent(state: state, staleDate: staleDate(body)))
                        completion(.success(["id": existing.id]))
                        return
                    }
                    let attributes = CraftActivityAttributes(activityId: key, title: String(title.prefix(160)), symbol: body["symbol"] as? String, deepLink: safeURL(body["deepLink"] as? String), tint: body["tint"] as? String)
                    let activity = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: staleDate(body)), pushType: nil)
                    completion(.success(["id": activity.id]))
                case "update", "end":
                    let id = args.first as? String
                    let activity = id == nil ? activities.first : activities.first(where: { $0.id == id })
                    guard let activity else {
                        if method == "end" { completion(.success(["ended": false])); return }
                        throw CraftNativeActionError(code: "NOT_FOUND", message: "No matching Live Activity is running")
                    }
                    let body = args.count > 1 ? args[1] as? [String: Any] ?? [:] : [:]
                    let state = content(body, previous: activity.content.state)
                    if method == "end" {
                        await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
                        completion(.success(["ended": true]))
                    } else {
                        await activity.update(ActivityContent(state: state, staleDate: staleDate(body)))
                        completion(.success(["updated": true]))
                    }
                default: throw CraftNativeActionError(code: "UNKNOWN_ACTION", message: "Unsupported Live Activities method")
                }
            } catch let error as CraftNativeActionError { completion(.failure(error)) }
            catch { completion(.failure(CraftNativeActionError(code: "ACTIVITY_ERROR", message: error.localizedDescription))) }
        }
    }

    private static func safeURL(_ value: String?) -> String? {
        guard let value, let url = URL(string: value), let scheme = url.scheme?.lowercased(),
              !["javascript", "data", "file"].contains(scheme) else { return nil }
        return value
    }

    private static func finite(_ body: [String: Any], _ key: String, _ fallback: Double? = nil) -> Double? {
        guard body.keys.contains(key) else { return fallback }
        guard let number = craftNativeNumber(body[key]), number.doubleValue.isFinite else { return nil }
        return max(0, number.doubleValue)
    }

    private static func staleDate(_ body: [String: Any]) -> Date? {
        finite(body, "staleAt").map { Date(timeIntervalSince1970: $0 / 1000) }
    }

    @available(iOS 16.2, *)
    private static func content(_ body: [String: Any], previous: CraftActivityAttributes.ContentState? = nil) -> CraftActivityAttributes.ContentState {
        CraftActivityAttributes.ContentState(
            status: String((body["status"] as? String ?? previous?.status ?? "").prefix(120)),
            distanceMeters: finite(body, "distanceMeters", previous?.distanceMeters) ?? 0,
            durationSeconds: finite(body, "durationSeconds", previous?.durationSeconds) ?? 0,
            progress: min(finite(body, "progress", previous?.progress) ?? 0, 1),
            staleStatus: body["staleStatus"] as? String ?? previous?.staleStatus,
            detail: body["detail"] as? String ?? previous?.detail,
            timerStartedAt: finite(body, "timerStartedAt", previous?.timerStartedAt),
            timerEndsAt: finite(body, "timerEndsAt", previous?.timerEndsAt),
            paused: body["paused"] as? Bool ?? previous?.paused,
            remainingSeconds: finite(body, "remainingSeconds", previous?.remainingSeconds),
            heartRate: finite(body, "heartRate", previous?.heartRate),
            showsDistance: body["showsDistance"] as? Bool ?? previous?.showsDistance
        )
    }
}
