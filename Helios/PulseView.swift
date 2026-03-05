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

                TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate

                    Canvas { ctx, size in
                        drawBaseline(ctx: &ctx, size: size)
                        if hasData {
                            drawShimmerColumns(ctx: &ctx, size: size, time: t)
                            drawWaves(ctx: &ctx, size: size, time: t)
                        } else {
                            drawIdleAurora(ctx: &ctx, size: size, time: t)
                        }
                    }
                }

                // Stat card overlays
                VStack {
                    Spacer()

                    if hasData {
                        HStack(spacing: 10) {
                            PulseStatCard(
                                label: "5h",
                                value: "\(Int(state.fiveHourPct))%",
                                detail: state.hasAdminConfig ? "\(state.totalTokensToday.formatted()) tokens today" : state.fiveHourResetString.isEmpty ? nil : "resets in \(state.fiveHourResetString)",
                                color: Theme.pulseSession
                            )
                            PulseStatCard(
                                label: "7d",
                                value: "\(Int(state.sevenDayPct))%",
                                detail: state.sevenDayResetString.isEmpty ? nil : "resets in \(state.sevenDayResetString)",
                                color: Theme.pulseWeekly
                            )
                            PulseStatCard(
                                label: "S",
                                value: "\(Int(state.sonnetPct))%",
                                detail: state.hasAdminConfig ? "$\(String(format: "%.2f", state.totalCostToday)) today" : nil,
                                color: Theme.pulseSonnet
                            )
                        }
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

    // MARK: - Shimmer Columns

    private func drawShimmerColumns(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let columnCount = 7
        let dominantColor = strongestWaveColor()

        for i in 0..<columnCount {
            let speed = 12.0 + Double(i) * 3.0
            let width = 15.0 + Double(i % 3) * 5.0

            let offset = time * speed
            let baseX = (Double(i) + 0.5) / Double(columnCount) * size.width
            let xCenter = (baseX + offset).truncatingRemainder(dividingBy: size.width)

            var opacity = 0.035

            if let mouse = mousePos {
                let dist = abs(mouse.x - xCenter)
                if dist < width { opacity *= 2.0 }
            }

            let rect = CGRect(x: xCenter - width / 2, y: 0, width: width, height: size.height)
            var shimmerCtx = ctx
            shimmerCtx.blendMode = .screen
            shimmerCtx.fill(
                Rectangle().path(in: rect),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: dominantColor.opacity(opacity * 0.5), location: 0.3),
                        .init(color: dominantColor.opacity(opacity), location: 0.5),
                        .init(color: dominantColor.opacity(opacity * 0.5), location: 0.7),
                        .init(color: .clear, location: 1.0),
                    ]),
                    startPoint: CGPoint(x: xCenter, y: 0),
                    endPoint: CGPoint(x: xCenter, y: size.height)
                )
            )
        }
    }

    // MARK: - Idle Aurora (ambient, no data)

    private func drawIdleAurora(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let midY = size.height * 0.5
        let steps = Int(size.width / 2)
        let breathe = 6.0 + sin(time * 0.15) * 3.0
        let phase = time * 0.2

        let ghostWaves: [(color: Color, freqMul: Double, phaseMul: Double)] = [
            (Theme.pulseSession, 1.0, 1.0),
            (Theme.pulseWeekly, 1.3, 0.7),
        ]

        for ghost in ghostWaves {
            var edgePath = Path()
            var points: [CGPoint] = []

            for x in 0...steps {
                let xFrac = Double(x) / Double(steps)
                let xPos = size.width * xFrac
                let y = sin(xFrac * 3 * .pi * 2 * ghost.freqMul + phase * ghost.phaseMul) * breathe
                let pt = CGPoint(x: xPos, y: midY + y)
                points.append(pt)
                if x == 0 { edgePath.move(to: pt) }
                else { edgePath.addLine(to: pt) }
            }

            // Downward curtain
            var curtainDown = edgePath
            curtainDown.addLine(to: CGPoint(x: size.width, y: size.height))
            curtainDown.addLine(to: CGPoint(x: 0, y: size.height))
            curtainDown.closeSubpath()

            ctx.drawLayer { layerCtx in
                layerCtx.blendMode = .plusLighter
                layerCtx.clip(to: curtainDown)
                layerCtx.fill(
                    Rectangle().path(in: CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [ghost.color.opacity(0.06), ghost.color.opacity(0.02), .clear]),
                        startPoint: CGPoint(x: size.width / 2, y: midY),
                        endPoint: CGPoint(x: size.width / 2, y: midY + size.height * 0.35)
                    )
                )
            }

            // Bloom pass
            var bloomCtx = ctx
            bloomCtx.blendMode = .screen
            bloomCtx.stroke(edgePath, with: .color(ghost.color.opacity(0.06)), lineWidth: 6)

            // Core pass
            var coreCtx = ctx
            coreCtx.blendMode = .screen
            coreCtx.stroke(edgePath, with: .color(ghost.color.opacity(0.12)), lineWidth: 1.5)
        }

        // Minimal shimmer — 3 faint columns
        for i in 0..<3 {
            let speed = 10.0 + Double(i) * 4.0
            let width = 20.0
            let offset = time * speed
            let baseX = (Double(i) + 0.5) / 3.0 * size.width
            let xCenter = (baseX + offset).truncatingRemainder(dividingBy: size.width)
            let opacity = 0.015 + sin(time * 0.3 + Double(i) * 2.3) * 0.005
            let color = ghostWaves[i % 2].color

            let rect = CGRect(x: xCenter - width / 2, y: 0, width: width, height: size.height)
            var shimmerCtx = ctx
            shimmerCtx.blendMode = .screen
            shimmerCtx.fill(
                Rectangle().path(in: rect),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: color.opacity(opacity * 0.5), location: 0.35),
                        .init(color: color.opacity(opacity), location: 0.5),
                        .init(color: color.opacity(opacity * 0.5), location: 0.65),
                        .init(color: .clear, location: 1.0),
                    ]),
                    startPoint: CGPoint(x: xCenter, y: 0),
                    endPoint: CGPoint(x: xCenter, y: size.height)
                )
            )
        }
    }

    // MARK: - Wave Point

    private struct WavePoint {
        let x: Double
        let y: Double
    }

    // MARK: - Wave Point Computation

    private func computeWavePoints(size: CGSize, pct: Double, waveIndex: Int, time: Double) -> [WavePoint] {
        let frac = Double(waveIndex) / 4.0
        let baseAmplitude = (pct / 100.0) * size.height * 0.15
        let frequency = 2.0 + frac * 0.5
        let phase = time * (0.3 + frac * 0.15)
        let midY = size.height * 0.5
        let steps = Int(size.width / 2)

        var points: [WavePoint] = []
        points.reserveCapacity(steps + 1)

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

            points.append(WavePoint(x: xPos, y: yPos))
        }

        return points
    }

    // MARK: - Wave Rendering (all layers)

    private func drawWaves(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let buckets: [Double] = [
            state.fiveHourPct,
            state.sevenDayPct,
            state.sonnetPct,
            state.opusPct,
        ]
        let midY = size.height * 0.5

        // Pre-compute all wave points
        var allWaves: [(index: Int, color: Color, points: [WavePoint])] = []
        for (i, pct) in buckets.enumerated() {
            guard pct > 0 else { continue }
            let points = computeWavePoints(size: size, pct: pct, waveIndex: i, time: time)
            allWaves.append((i, waveColors[i], points))
        }

        // Layer 1: Aurora curtain fills
        for wave in allWaves {
            drawAuroraCurtain(ctx: &ctx, size: size, points: wave.points, color: wave.color, waveIndex: wave.index)
        }

        // Layer 2: Bloom passes (wide soft glow)
        for wave in allWaves {
            let edgePath = buildEdgePath(from: wave.points)
            var bloomCtx = ctx
            bloomCtx.blendMode = .screen
            bloomCtx.stroke(edgePath, with: .color(wave.color.opacity(0.08)), lineWidth: 6)
        }

        // Layer 3: Core edge passes with thickness variation
        for wave in allWaves {
            drawVariableEdge(ctx: &ctx, points: wave.points, color: wave.color)
        }

        // Layer 4: Baseline reflections
        for wave in allWaves {
            drawReflection(ctx: &ctx, size: size, points: wave.points, color: wave.color, midY: midY)
        }

        // Layer 5: Particle drift
        for wave in allWaves {
            drawParticles(ctx: &ctx, size: size, points: wave.points, color: wave.color, waveIndex: wave.index, time: time)
        }
    }

    // MARK: - Aurora Curtain Fills

    private func drawAuroraCurtain(ctx: inout GraphicsContext, size: CGSize, points: [WavePoint], color: Color, waveIndex: Int) {
        guard !points.isEmpty else { return }
        let midY = size.height * 0.5
        let frac = Double(waveIndex) / 4.0
        let baseOpacity = 0.08 + frac * 0.04
        let fadeDistance = size.height * 0.4

        // Build edge path
        let edgePath = buildEdgePath(from: points)

        // Downward curtain: wave edge → bottom of screen
        var downPath = edgePath
        downPath.addLine(to: CGPoint(x: size.width, y: size.height))
        downPath.addLine(to: CGPoint(x: 0, y: size.height))
        downPath.closeSubpath()

        ctx.drawLayer { layerCtx in
            layerCtx.blendMode = .plusLighter
            layerCtx.clip(to: downPath)
            layerCtx.fill(
                Rectangle().path(in: CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [color.opacity(baseOpacity), color.opacity(baseOpacity * 0.3), .clear]),
                    startPoint: CGPoint(x: size.width / 2, y: midY),
                    endPoint: CGPoint(x: size.width / 2, y: midY + fadeDistance)
                )
            )
        }

        // Upward curtain: top of screen → wave edge (reversed)
        var upPath = Path()
        upPath.move(to: CGPoint(x: 0, y: 0))
        upPath.addLine(to: CGPoint(x: size.width, y: 0))
        for i in stride(from: points.count - 1, through: 0, by: -1) {
            upPath.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
        }
        upPath.closeSubpath()

        ctx.drawLayer { layerCtx in
            layerCtx.blendMode = .plusLighter
            layerCtx.clip(to: upPath)
            layerCtx.fill(
                Rectangle().path(in: CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [color.opacity(baseOpacity), color.opacity(baseOpacity * 0.3), .clear]),
                    startPoint: CGPoint(x: size.width / 2, y: midY),
                    endPoint: CGPoint(x: size.width / 2, y: midY - fadeDistance)
                )
            )
        }
    }

    // MARK: - Edge Path Helper

    private func buildEdgePath(from points: [WavePoint]) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }
        path.move(to: CGPoint(x: points[0].x, y: points[0].y))
        for i in 1..<points.count {
            path.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
        }
        return path
    }

    // MARK: - Variable Thickness Edge

    private func drawVariableEdge(ctx: inout GraphicsContext, points: [WavePoint], color: Color) {
        guard points.count > 1 else { return }
        var edgeCtx = ctx
        edgeCtx.blendMode = .screen

        let step = 4
        var i = 0
        while i < points.count - 1 {
            let end = min(i + step, points.count - 1)
            var seg = Path()
            seg.move(to: CGPoint(x: points[i].x, y: points[i].y))
            for j in (i + 1)...end {
                seg.addLine(to: CGPoint(x: points[j].x, y: points[j].y))
            }

            // Thickness: thicker at peaks (low slope), thinner at steep crossings
            let dy = abs(points[end].y - points[i].y)
            let dx = abs(points[end].x - points[i].x)
            let slope = dy / max(dx, 0.01)
            let slopeFactor = 1.0 / (1.0 + slope * 0.5)
            let width = 1.0 + slopeFactor * 1.5 // 1.0 to 2.5

            edgeCtx.stroke(seg, with: .color(color.opacity(0.35)), lineWidth: width)
            i += step
        }
    }

    // MARK: - Baseline Reflection

    private func drawReflection(ctx: inout GraphicsContext, size: CGSize, points: [WavePoint], color: Color, midY: Double) {
        guard !points.isEmpty else { return }
        let compression = 0.6

        // Mirror wave around midY with compressed amplitude
        var reflPath = Path()
        let firstY = midY + (midY - points[0].y) * compression
        reflPath.move(to: CGPoint(x: points[0].x, y: firstY))
        for i in 1..<points.count {
            let reflY = midY + (midY - points[i].y) * compression
            reflPath.addLine(to: CGPoint(x: points[i].x, y: reflY))
        }

        // Bloom at 30% of normal
        var bloomCtx = ctx
        bloomCtx.blendMode = .screen
        bloomCtx.stroke(reflPath, with: .color(color.opacity(0.024)), lineWidth: 6)

        // Core at 30% of normal
        var coreCtx = ctx
        coreCtx.blendMode = .screen
        coreCtx.stroke(reflPath, with: .color(color.opacity(0.105)), lineWidth: 1.5)
    }

    // MARK: - Particle Drift

    private func drawParticles(ctx: inout GraphicsContext, size: CGSize, points: [WavePoint], color: Color, waveIndex: Int, time: Double) {
        let particleCount = 10
        let steps = points.count - 1
        guard steps > 0 else { return }

        for p in 0..<particleCount {
            let seed = Double(waveIndex * 100 + p)
            let speed = 0.03 + sin(seed * 1.7) * 0.01

            // Position along wave (deterministic from time + seed)
            let rawFrac = (seed * 0.137 + time * speed).truncatingRemainder(dividingBy: 1.0)
            let frac = rawFrac < 0 ? rawFrac + 1.0 : rawFrac
            let idx = min(Int(frac * Double(steps)), steps)

            let baseX = points[idx].x
            let baseY = points[idx].y

            // Small perpendicular scatter
            let scatter = sin(time * 1.5 + seed * 2.3) * 3.0
            var px = baseX
            var py = baseY + scatter

            // Mouse repulsion — particles scatter outward within 80px
            if let mouse = mousePos {
                let dx = px - mouse.x
                let dy = py - mouse.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist < 80 && dist > 0 {
                    let repulsion = (1.0 - dist / 80.0) * 15.0
                    px += (dx / dist) * repulsion
                    py += (dy / dist) * repulsion
                }
            }

            // Radial glow
            let glowSize = 4.0
            ctx.fill(
                Circle().path(in: CGRect(x: px - glowSize, y: py - glowSize, width: glowSize * 2, height: glowSize * 2)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.4), color.opacity(0.1), .clear]),
                    center: CGPoint(x: px, y: py),
                    startRadius: 0,
                    endRadius: glowSize
                )
            )

            // Core dot
            let coreSize = 1.5
            ctx.fill(
                Circle().path(in: CGRect(x: px - coreSize, y: py - coreSize, width: coreSize * 2, height: coreSize * 2)),
                with: .color(color.opacity(0.7))
            )
        }
    }

    // MARK: - Helpers

    private func strongestWaveColor() -> Color {
        let buckets: [Double] = [
            state.fiveHourPct,
            state.sevenDayPct,
            state.sonnetPct,
            state.opusPct,
        ]
        var maxPct = 0.0
        var bestColor = Theme.stardust
        for (i, pct) in buckets.enumerated() {
            if pct > maxPct {
                maxPct = pct
                bestColor = waveColors[i]
            }
        }
        return bestColor
    }
}
