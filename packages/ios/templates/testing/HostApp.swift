import SwiftUI
import UIKit

@main
struct HostApp: App {
    @State private var status = "Craft simulator driver"

    var body: some Scene {
        WindowGroup {
            Text(status).accessibilityIdentifier("craft-driver-status")
                .task { await openUniversalLinkIfRequested() }
        }
    }

    @MainActor
    private func openUniversalLinkIfRequested() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--craft-universal-link"),
              arguments.indices.contains(index + 1),
              let url = URL(string: arguments[index + 1]), url.scheme == "https" else { return }
        // Installation returns before iOS finishes downloading the AASA from
        // Apple's CDN. Ask the public API until the OS accepts the association;
        // universalLinksOnly prevents a failed attempt from opening Safari.
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline && !Task.isCancelled {
            let opened = await UIApplication.shared.open(url, options: [.universalLinksOnly: true])
            if opened {
                status = "Universal Link accepted"
                return
            }
            status = "Waiting for Universal Link association"
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        status = "Universal Link was not accepted within 60 seconds"
    }
}
