import ActivityKit

@available(iOS 16.1, *)
struct CraftActivityAttributes: ActivityAttributes {
    struct Transition: Codable, Hashable {
        let at: Double
        let detail: String
        let duration: Double?
    }
    struct ContentState: Codable, Hashable {
        var status: String
        let distanceMeters: Double
        let durationSeconds: Double
        var progress: Double
        var staleStatus: String?
        var detail: String?
        /// Epoch milliseconds. SwiftUI advances these timers without app updates.
        var sessionStartedAt: Double?
        var timerStartedAt: Double?
        var timerEndsAt: Double?
        var paused: Bool?
        var remainingSeconds: Double?
        var heartRate: Double?
        var showsDistance: Bool?
        var transitions: [Transition]?

        /// Catch up missed boundaries in one update, preserving their clock anchors.
        mutating func advance(to milliseconds: Double) {
            while let next = transitions?.first, next.at <= milliseconds {
                transitions = Array((transitions ?? []).dropFirst())
                detail = next.detail
                timerStartedAt = next.duration == nil ? sessionStartedAt : next.at
                timerEndsAt = next.duration.map { next.at + $0 * 1000 }
                remainingSeconds = next.duration.map { max(0, $0 - (milliseconds - next.at) / 1000) }
                progress = 0
                if next.duration == 0 { status = next.detail; paused = true; progress = 1 }
            }
        }
    }

    let activityId: String
    let title: String
    var symbol: String?
    var deepLink: String?
    var tint: String?
}
