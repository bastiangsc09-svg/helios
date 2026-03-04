import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct HeliosEntry: TimelineEntry {
    let date: Date
    let fiveHourPct: Double
    let sevenDayPct: Double
    let sonnetPct: Double
    let opusPct: Double
    let fiveHourReset: Date?
    let sevenDayReset: Date?
    let isPlaceholder: Bool

    static let placeholder = HeliosEntry(
        date: .now,
        fiveHourPct: 42,
        sevenDayPct: 67,
        sonnetPct: 35,
        opusPct: 0,
        fiveHourReset: Date().addingTimeInterval(3600 * 2),
        sevenDayReset: Date().addingTimeInterval(3600 * 48),
        isPlaceholder: true
    )
}

// MARK: - Timeline Provider

struct HeliosTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HeliosEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (HeliosEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HeliosEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 15 minutes (WidgetKit minimum)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> HeliosEntry {
        if let snapshot = WidgetDataBridge.read() {
            return HeliosEntry(
                date: snapshot.fetchDate,
                fiveHourPct: snapshot.fiveHourPct,
                sevenDayPct: snapshot.sevenDayPct,
                sonnetPct: snapshot.sonnetPct,
                opusPct: snapshot.opusPct,
                fiveHourReset: snapshot.fiveHourReset,
                sevenDayReset: snapshot.sevenDayReset,
                isPlaceholder: false
            )
        }
        return .placeholder
    }
}

// MARK: - Widget Definition

struct HeliosUsageWidget: Widget {
    let kind = "HeliosUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeliosTimelineProvider()) { entry in
            HeliosWidgetEntryView(entry: entry)
                .containerBackground(Theme.void, for: .widget)
        }
        .configurationDisplayName("Helios Usage")
        .description("Claude API usage at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
