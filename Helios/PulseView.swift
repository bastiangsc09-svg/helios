import SwiftUI

struct PulseView: View {
    let state: UsageState
    @State private var mousePos: CGPoint?

    private let waveColors: [Color] = [
        Theme.pulseSession,
        Theme.pulseWeekly,
        Theme.pulseSonnet,
        Theme.pulseOpus,
    ]

    private var hasData: Bool {
        state.fiveHourPct > 0 || state.sevenDayPct > 0 || state.sonnetPct > 0 || state.opusPct > 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                StarfieldCanvas(starCount: 150, brightnessMultiplier: 0.3)

                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate

                    Canvas { ctx, size in
                        drawBaseline(ctx: &ctx, size: size)
                        if hasData {
                            drawWaves(ctx: &ctx, size: size, time: t)
                        } else {
                            // Ambient idle wave when no data
                            drawIdleWave(ctx: &ctx, size: size, time: t)
                        }
                    }
                }

                // Stat card overlays
                VStack {
                    Spacer()

                    if hasData {
                        HStack(spacing: 12) {
                            PulseStatCard(
                                label: "Session (5h)",
                                value: "\(Int(state.fiveHourPct))%",
                                detail: state.hasAdminConfig ? "\(state.totalTokensToday.formatted()) tokens today" : state.fiveHourResetString.isEmpty ? nil : "resets in \(state.fiveHourResetString)",
                                color: Theme.pulseSession
                            )
                            PulseStatCard(
                                label: "Weekly (7d)",
                                value: "\(Int(state.sevenDayPct))%",
                                detail: state.sevenDayResetString.isEmpty ? nil : "resets in \(state.sevenDayResetString)",
                                color: Theme.pulseWeekly
                            )
                            PulseStatCard(
                                label: "Sonnet",
                                value: "\(Int(state.sonnetPct))%",
                                detail: state.hasAdminConfig ? "$\(String(format: "%.2f", state.totalCostToday)) today" : nil,
                                color: Theme.pulseSonnet
                            )
                        }
                        .padding(.horizontal, 24)
                    } else {
                        // Empty state hint
                        Text(state.hasSessionConfig ? (state.isLoading ? "Fetching data..." : "Waiting for usage data") : "Configure session key to see waveforms")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.stardust.opacity(0.3))
                    }

                    Spacer().frame(height: 70)
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let loc): mousePos = loc
                case .ended: mousePos = nil
                }
            }
        }
    }

    // MARK: - Baseline

    private func drawBaseline(ctx: inout GraphicsContext, size: CGSize) {
        let midY = size.height * 0.5
        var line = Path()
        line.move(to: CGPoint(x: 0, y: midY))
        line.addLine(to: CGPoint(x: size.width, y: midY))
        ctx.stroke(line, with: .color(Theme.stardust.opacity(0.06)), lineWidth: 1)
    }

    // MARK: - Idle Wave (ambient, no data)

    private func drawIdleWave(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let midY = size.height * 0.5
        let steps = Int(size.width / 2)
        let amp = 8.0
        let phase = time * 0.2

        var path = Path()
        for x in 0...steps {
            let xFrac = Double(x) / Double(steps)
            let xPos = size.width * xFrac
            let y = sin(xFrac * 3 * .pi * 2 + phase) * amp
            let yPos = midY + y
            if x == 0 { path.move(to: CGPoint(x: xPos, y: yPos)) }
            else { path.addLine(to: CGPoint(x: xPos, y: yPos)) }
        }

        var edgeCtx = ctx
        edgeCtx.blendMode = .screen
        edgeCtx.stroke(path, with: .color(Theme.stardust.opacity(0.08)), lineWidth: 1)
    }

    // MARK: - Wave Rendering

    private func drawWaves(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let buckets: [Double] = [
            state.fiveHourPct,
            state.sevenDayPct,
            state.sonnetPct,
            state.opusPct,
        ]

        for (i, pct) in buckets.enumerated() {
            guard pct > 0 else { continue }

            let color = waveColors[i]
            let frac = Double(i) / Double(buckets.count)
            let baseAmplitude = (pct / 100.0) * size.height * 0.15
            let frequency = 2.0 + frac * 0.5
            let phase = time * (0.3 + frac * 0.15)
            let midY = size.height * 0.5

            let steps = Int(size.width / 2)
            var fillPath = Path()
            var edgePath = Path()

            for x in 0...steps {
                let xFrac = Double(x) / Double(steps)
                let xPos = size.width * xFrac

                var amp = baseAmplitude
                if let mouse = mousePos {
                    let dist = abs(xPos - mouse.x)
                    if dist < 120 {
                        amp *= 0.4 + (dist / 120.0) * 0.6
                    }
                }

                let y1 = sin(xFrac * frequency * .pi * 2 + phase) * amp
                let y2 = sin(xFrac * frequency * 1.5 * .pi * 2 + phase * 0.7) * amp * 0.5
                let y3 = sin(xFrac * frequency * 0.5 * .pi * 2 + phase * 1.3) * amp * 0.3
                let yPos = midY + y1 + y2 + y3

                if x == 0 {
                    fillPath.move(to: CGPoint(x: xPos, y: yPos))
                    edgePath.move(to: CGPoint(x: xPos, y: yPos))
                } else {
                    fillPath.addLine(to: CGPoint(x: xPos, y: yPos))
                    edgePath.addLine(to: CGPoint(x: xPos, y: yPos))
                }
            }

            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()

            var fillCtx = ctx
            fillCtx.blendMode = .plusLighter
            fillCtx.fill(fillPath, with: .color(color.opacity(0.06 + frac * 0.02)))

            var edgeCtx = ctx
            edgeCtx.blendMode = .screen
            edgeCtx.stroke(edgePath, with: .color(color.opacity(0.25)), lineWidth: 2)
        }
    }
}
