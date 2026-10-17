import SwiftUI

/// Independent native input receiver: callbacks only run for real button input.
@main
struct HostApp: App {
    @State private var taps: [String] = []
    private let names = ["One", "Two", "Three", "Four"]

    var body: some Scene {
        WindowGroup {
            VStack {
                Text(taps.isEmpty ? "none" : taps.joined(separator: ","))
                    .lineLimit(1)
                    .accessibilityIdentifier("received-taps")
                Spacer()
                HStack {
                    ForEach(names, id: \.self) { name in
                        Button(name) { taps.append(name) }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .buttonStyle(.borderedProminent)
                            .accessibilityAddTraits(taps.last == name ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
    }
}
