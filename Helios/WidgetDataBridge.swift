import Foundation

/// Lightweight struct shared between the main app and widget extension.
/// The app writes it after each fetch; the widget reads it for timeline entries.
struct WidgetUsageSnapshot: Codable {
    let fiveHourPct: Double
    let sevenDayPct: Double
    let sonnetPct: Double
    let opusPct: Double
    let fiveHourReset: Date?
    let sevenDayReset: Date?
    let fetchDate: Date
}

enum WidgetDataBridge {
    /// App Group identifier shared between main app and widget.
    static let appGroupID = "group.com.helios.shared"

    /// File URL inside the shared container.
    static var sharedFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("widget-snapshot.json")
    }

    /// Called by the main app after each successful fetch.
    static func write(_ snapshot: WidgetUsageSnapshot) {
        guard let url = sharedFileURL else { return }
        try? JSONEncoder().encode(snapshot).write(to: url)
    }

    /// Called by the widget to read the latest data.
    static func read() -> WidgetUsageSnapshot? {
        guard let url = sharedFileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetUsageSnapshot.self, from: data)
    }
}
