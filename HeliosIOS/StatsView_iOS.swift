import SwiftUI

struct StatsView_iOS: View {
    let state: UsageState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.void.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Overall status header
                        overallHeader

                        // Usage buckets
                        ForEach(buckets, id: \.label) { bucket in
                            usageTile(
                                label: bucket.label,
                                shortLabel: bucket.shortLabel,
                                pct: bucket.pct,
                                color: bucket.color,
                                reset: bucket.reset
                            )
                        }

                        // Last updated
                        if let lastFetch = state.lastFetch {
                            HStack {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                Text("Updated \(lastFetch.formatted(.relative(presentation: .named)))")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Usage Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.sessionOrbit)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Overall Header

    private var overallHeader: some View {
        VStack(spacing: 12) {
            // Large overall percentage ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: state.overallUtilization / 100)
                    .stroke(
                        AngularGradient(
                            colors: [overallColor.opacity(0.3), overallColor],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(state.overallUtilization))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(overallColor)
                    Text("overall")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 120, height: 120)

            Text(overallStatusText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(overallColor.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Usage Tile

    private func usageTile(label: String, shortLabel: String, pct: Double, color: Color, reset: Date?) -> some View {
        HStack(spacing: 14) {
            // Left: colored indicator + label
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.stardust)
                }

                if let reset {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9))
                        Text("Resets in \(reset.countdownString)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            // Right: percentage
            Text("\(Int(pct))%")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.forUtilization(pct))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background {
            // Progress bar background
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.08))
                    .frame(width: geo.size.width * min(pct / 100, 1))
            }
        }
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Data

    private struct BucketInfo {
        let label: String
        let shortLabel: String
        let pct: Double
        let color: Color
        let reset: Date?
    }

    private var buckets: [BucketInfo] {
        var result: [BucketInfo] = []
        result.append(BucketInfo(label: "Session (5h)", shortLabel: "5h", pct: state.fiveHourPct, color: Theme.sessionOrbit, reset: state.usage?.fiveHour?.resetsAtDate))
        result.append(BucketInfo(label: "Weekly (7d)", shortLabel: "7d", pct: state.sevenDayPct, color: Theme.weeklyOrbit, reset: state.usage?.sevenDay?.resetsAtDate))
        if state.sonnetPct > 0 {
            result.append(BucketInfo(label: "Sonnet", shortLabel: "S", pct: state.sonnetPct, color: Theme.outerOrbit, reset: nil))
        }
        if state.opusPct > 0 {
            result.append(BucketInfo(label: "Opus", shortLabel: "O", pct: state.opusPct, color: Theme.tierCritical, reset: nil))
        }
        if state.oauthPct > 0 {
            result.append(BucketInfo(label: "OAuth Apps", shortLabel: "OA", pct: state.oauthPct, color: Color(hex: "78909C"), reset: nil))
        }
        if state.coworkPct > 0 {
            result.append(BucketInfo(label: "Cowork", shortLabel: "CW", pct: state.coworkPct, color: Color(hex: "4DB6AC"), reset: nil))
        }
        return result
    }

    private var overallColor: Color {
        Color.forUtilization(state.overallUtilization)
    }

    private var overallStatusText: String {
        let pct = state.overallUtilization
        if pct < 30 { return "Usage is low — plenty of capacity" }
        if pct < 60 { return "Moderate usage — looking good" }
        if pct < 85 { return "Getting warm — consider pacing" }
        return "Rate limited — resets soon"
    }
}
