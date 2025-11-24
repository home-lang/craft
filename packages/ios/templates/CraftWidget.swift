import WidgetKit
import SwiftUI

// MARK: - Widget Entry
struct CraftWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let value: String
    let iconName: String?
    let configuration: ConfigurationIntent?
}

// MARK: - Widget Provider
struct CraftWidgetProvider: IntentTimelineProvider {
    typealias Entry = CraftWidgetEntry
    typealias Intent = ConfigurationIntent

    // Shared UserDefaults for app-to-widget communication
    private let sharedDefaults = UserDefaults(suiteName: "group.{{BUNDLE_ID}}.widget")

    func placeholder(in context: Context) -> CraftWidgetEntry {
        CraftWidgetEntry(
            date: Date(),
            title: "Craft Widget",
            subtitle: "Loading...",
            value: "",
            iconName: nil,
            configuration: nil
        )
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (CraftWidgetEntry) -> Void) {
        let entry = loadWidgetData(configuration: configuration)
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<CraftWidgetEntry>) -> Void) {
        let entry = loadWidgetData(configuration: configuration)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadWidgetData(configuration: ConfigurationIntent?) -> CraftWidgetEntry {
        let title = sharedDefaults?.string(forKey: "widget_title") ?? "Craft Widget"
        let subtitle = sharedDefaults?.string(forKey: "widget_subtitle") ?? ""
        let value = sharedDefaults?.string(forKey: "widget_value") ?? ""
        let iconName = sharedDefaults?.string(forKey: "widget_icon")

        return CraftWidgetEntry(
            date: Date(),
            title: title,
            subtitle: subtitle,
            value: value,
            iconName: iconName,
            configuration: configuration
        )
    }
}

// MARK: - Small Widget View
struct CraftWidgetSmallView: View {
    var entry: CraftWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let iconName = entry.iconName {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }

            Text(entry.title)
                .font(.headline)
                .lineLimit(2)

            if !entry.subtitle.isEmpty {
                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if !entry.value.isEmpty {
                Text(entry.value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .widgetBackground(Color(.systemBackground))
    }
}

// MARK: - Medium Widget View
struct CraftWidgetMediumView: View {
    var entry: CraftWidgetEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let iconName = entry.iconName {
                    Image(systemName: iconName)
                        .font(.title)
                        .foregroundColor(.accentColor)
                }

                Text(entry.title)
                    .font(.headline)

                if !entry.subtitle.isEmpty {
                    Text(entry.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !entry.value.isEmpty {
                Text(entry.value)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .widgetBackground(Color(.systemBackground))
    }
}

// MARK: - Large Widget View
struct CraftWidgetLargeView: View {
    var entry: CraftWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let iconName = entry.iconName {
                    Image(systemName: iconName)
                        .font(.title)
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading) {
                    Text(entry.title)
                        .font(.headline)

                    if !entry.subtitle.isEmpty {
                        Text(entry.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            Divider()

            if !entry.value.isEmpty {
                Text(entry.value)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.accentColor)
            }

            Spacer()

            Text("Updated: \(entry.date, style: .time)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .widgetBackground(Color(.systemBackground))
    }
}

// MARK: - Widget Entry View
struct CraftWidgetEntryView: View {
    var entry: CraftWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            CraftWidgetSmallView(entry: entry)
        case .systemMedium:
            CraftWidgetMediumView(entry: entry)
        case .systemLarge:
            CraftWidgetLargeView(entry: entry)
        default:
            CraftWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration
@main
struct CraftWidget: Widget {
    let kind: String = "CraftWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: CraftWidgetProvider()) { entry in
            CraftWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("{{APP_NAME}} Widget")
        .description("Display information from {{APP_NAME}}")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Background Extension
extension View {
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            return containerBackground(color, for: .widget)
        } else {
            return background(color)
        }
    }
}

// MARK: - Configuration Intent (placeholder)
class ConfigurationIntent: INIntent {
    // Add configuration properties here
}

// MARK: - Preview
struct CraftWidget_Previews: PreviewProvider {
    static var previews: some View {
        CraftWidgetEntryView(entry: CraftWidgetEntry(
            date: Date(),
            title: "My Widget",
            subtitle: "Subtitle text",
            value: "42",
            iconName: "star.fill",
            configuration: nil
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
