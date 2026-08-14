import ActivityKit

@available(iOS 16.1, *)
struct CraftActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let status: String
        let distanceMeters: Double
        let durationSeconds: Double
        let progress: Double
    }

    let activityId: String
    let title: String
}
