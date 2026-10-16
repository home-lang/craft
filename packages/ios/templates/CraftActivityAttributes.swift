import ActivityKit

@available(iOS 16.1, *)
struct CraftActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let status: String
        let distanceMeters: Double
        let durationSeconds: Double
        let progress: Double
        var staleStatus: String?
        var detail: String?
        /// Epoch milliseconds. SwiftUI advances these timers without app updates.
        var timerStartedAt: Double?
        var timerEndsAt: Double?
        var paused: Bool?
        var remainingSeconds: Double?
        var heartRate: Double?
        var showsDistance: Bool?
    }

    let activityId: String
    let title: String
    var symbol: String?
    var deepLink: String?
    var tint: String?
}
