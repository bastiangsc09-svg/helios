import SwiftUI

struct BreakdownView: View {
    let state: UsageState

    var body: some View {
        ZStack {
            Theme.void.ignoresSafeArea()

            if let usage = state.usage, !usage.allBuckets.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        // Usage bucket cards
                        let buckets = usage.allBuckets
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(Array(buckets.enumerated()), id: \.offset) { _, item in
                                BucketCard(label: item.label, shortLabel: item.shortLabel, bucket: item.bucket)
                            }
                        }

                        // Admin API section
                        if state.hasAdminConfig && !state.tokensByModel.isEmpty {
                            adminSection
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 50)
                }
            } else {
                // Empty state
                VStack(spacing: 16) {
                    StarfieldCanvas(starCount: 80, brightnessMultiplier: 0.2)
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 36, weight: .ultraLight))
                                    .foregroundStyle(Theme.stardust.opacity(0.2))

                                Text("No usage data yet")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.stardust.opacity(0.4))

                                if state.hasSessionConfig {
                                    Text(state.isLoading ? "Fetching..." : "Waiting for data")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.stardust.opacity(0.25))
                                } else {
                                    Text("Configure session key in Settings")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.sessionOrbit.opacity(0.5))
                                }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Admin Section

    @ViewBuilder
    private var adminSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Token Breakdown")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.stardust.opacity(0.7))

            ForEach(state.tokensByModel, id: \.model) { entry in
                HStack {
                    Text(entry.model)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.stardust.opacity(0.6))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(entry.total.formatted()) tokens")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.stardust)
                        Text("in: \(entry.input.formatted())  out: \(entry.output.formatted())")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.stardust.opacity(0.4))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.stardust.opacity(0.04))
                )
            }

            if state.totalCostToday > 0 {
                HStack {
                    Text("Cost today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.stardust.opacity(0.5))
                    Spacer()
                    Text("$\(String(format: "%.2f", state.totalCostToday))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.outerOrbit)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.outerOrbit.opacity(0.06))
                )
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Bucket Card

private struct BucketCard: View {
    let label: String
    let shortLabel: String
    let bucket: UsageBucket

    var body: some View {
        VStack(spacing: 12) {
            // Progress ring
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    drawProgressRing(ctx: &ctx, size: size, time: t)
                }
                .frame(width: 70, height: 70)
            }

            // Label + percentage
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.stardust.opacity(0.6))

            Text("\(Int(bucket.utilization))%")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.forUtilization(bucket.utilization))

            // Reset countdown
            if let resetDate = bucket.resetsAtDate, resetDate > Date() {
                Text("resets in \(resetDate.countdownString)")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Theme.stardust.opacity(0.35))
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.stardust.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.forUtilization(bucket.utilization).opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Progress Ring Canvas

    private func drawProgressRing(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 4
        let lineWidth: Double = 5
        let color = Color.forUtilization(bucket.utilization)
        let progress = bucket.utilization / 100.0
        let startAngle = -Double.pi / 2
        let endAngle = startAngle + progress * .pi * 2

        // Background ring
        let bgRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.stroke(
            Circle().path(in: bgRect),
            with: .color(.white.opacity(0.06)),
            lineWidth: lineWidth
        )

        // Progress arc
        if progress > 0 {
            var arc = Path()
            arc.addArc(center: center, radius: radius, startAngle: .radians(startAngle), endAngle: .radians(endAngle), clockwise: false)
            ctx.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Pulsing endpoint dot
            let pulse = (sin(time * 3) + 1) / 2
            let dotX = center.x + cos(endAngle) * radius
            let dotY = center.y + sin(endAngle) * radius
            let dotR = 3.0 + pulse * 2.0

            ctx.fill(
                Circle().path(in: CGRect(x: dotX - dotR * 2, y: dotY - dotR * 2, width: dotR * 4, height: dotR * 4)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.4), .clear]),
                    center: CGPoint(x: dotX, y: dotY),
                    startRadius: 0,
                    endRadius: dotR * 2
                )
            )

            ctx.fill(
                Circle().path(in: CGRect(x: dotX - dotR, y: dotY - dotR, width: dotR * 2, height: dotR * 2)),
                with: .color(color)
            )
        }
    }
}
