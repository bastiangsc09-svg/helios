import SwiftUI
import WidgetKit

// MARK: - Entry View (dispatches to size-specific layouts)

struct HeliosWidgetEntryView: View {
    let entry: HeliosEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    // MARK: - Small Widget

    private var smallWidget: some View {
        VStack(spacing: 8) {
            // Nucleus-style ring showing overall usage
            let overall = max(entry.fiveHourPct, entry.sevenDayPct)
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 5)

                // Usage arc
                Circle()
                    .trim(from: 0, to: overall / 100)
                    .stroke(
                        AngularGradient(
                            colors: [tierColor(overall).opacity(0.4), tierColor(overall)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center percentage
                VStack(spacing: 2) {
                    Text("\(Int(entry.fiveHourPct))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(tierColor(entry.fiveHourPct))
                    Text("session")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 72, height: 72)

            // Weekly below
            HStack(spacing: 4) {
                Circle()
                    .fill(Theme.weeklyOrbit)
                    .frame(width: 5, height: 5)
                Text("7d: \(Int(entry.sevenDayPct))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Medium Widget

    private var mediumWidget: some View {
        HStack(spacing: 0) {
            // Left: mini orrery visualization
            ZStack {
                // Orbit rings
                Circle()
                    .stroke(Theme.sessionOrbit.opacity(0.15), lineWidth: 1)
                    .frame(width: 60, height: 60)
                Circle()
                    .stroke(Theme.weeklyOrbit.opacity(0.15), lineWidth: 1)
                    .frame(width: 90, height: 90)

                // Nucleus
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.nucleusCorona, nucleusColor, nucleusColor.opacity(0.3)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 14
                        )
                    )
                    .frame(width: 20, height: 20)

                // Session planet
                Circle()
                    .fill(Theme.sessionOrbit)
                    .frame(width: 8, height: 8)
                    .shadow(color: Theme.sessionOrbit.opacity(0.6), radius: 4)
                    .offset(x: 30 * cos(planetAngle(entry.fiveHourPct)),
                            y: 30 * sin(planetAngle(entry.fiveHourPct)))

                // Weekly planet
                Circle()
                    .fill(Theme.weeklyOrbit)
                    .frame(width: 10, height: 10)
                    .shadow(color: Theme.weeklyOrbit.opacity(0.6), radius: 4)
                    .offset(x: 45 * cos(planetAngle(entry.sevenDayPct)),
                            y: 45 * sin(planetAngle(entry.sevenDayPct)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Right: stats
            VStack(alignment: .leading, spacing: 6) {
                Text("Helios")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))

                usageRow(label: "Session", shortLabel: "5h", pct: entry.fiveHourPct, color: Theme.sessionOrbit, reset: entry.fiveHourReset)
                usageRow(label: "Weekly", shortLabel: "7d", pct: entry.sevenDayPct, color: Theme.weeklyOrbit, reset: entry.sevenDayReset)

                if entry.sonnetPct > 0 {
                    usageRow(label: "Sonnet", shortLabel: "S", pct: entry.sonnetPct, color: Theme.outerOrbit, reset: nil)
                }
                if entry.opusPct > 0 {
                    usageRow(label: "Opus", shortLabel: "O", pct: entry.opusPct, color: Theme.tierCritical, reset: nil)
                }

                Spacer()

                if !entry.isPlaceholder {
                    Text("Updated \(entry.date.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func usageRow(label: String, shortLabel: String, pct: Double, color: Color, reset: Date?) -> some View {
        HStack(spacing: 6) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(shortLabel)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("\(Int(pct))%")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(tierColor(pct))
                }
                if let reset {
                    Text(reset.countdownString)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tierColor(pct).opacity(0.7))
                        .frame(width: geo.size.width * min(pct / 100, 1))
                }
            }
            .frame(width: 40, height: 4)
        }
    }

    private func tierColor(_ pct: Double) -> Color {
        if pct < 60 { return Theme.tierLow }
        if pct < 85 { return Theme.tierModerate }
        return Theme.tierCritical
    }

    private func planetAngle(_ pct: Double) -> Double {
        (pct / 100) * .pi * 2 - .pi / 2
    }

    private var nucleusColor: Color {
        let overall = max(entry.fiveHourPct, entry.sevenDayPct)
        if overall < 60 { return Theme.nucleusCool }
        if overall < 85 { return Theme.nucleusWarm }
        return Theme.nucleusHot
    }
}
