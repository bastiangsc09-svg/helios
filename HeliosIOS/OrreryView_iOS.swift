import SwiftUI

struct OrreryView_iOS: View {
    let state: UsageState
    @State private var tappedPlanet: TappedPlanet?
    @State private var expanded = false
    @State private var showStats = false

    private struct TappedPlanet: Equatable {
        let label: String
        let pct: Double
        let reset: String
        let position: CGPoint
        let id: String
    }

    var body: some View {
        GeometryReader { geo in
            // Orrery fills most of the screen; readout overlaid at bottom
            let readoutSpace: CGFloat = 100
            let orreryHeight = geo.size.height - readoutSpace
            let maxR = min(geo.size.width, orreryHeight) * 0.34

            ZStack {
                // Usage-responsive starfield (reduced for battery)
                StarfieldCanvas(
                    starCount: 200,
                    brightnessMultiplier: 0.4 + (state.overallUtilization / 100.0) * 0.6
                )
                .allowsHitTesting(false)

                // Orrery centered in the available space
                ZStack {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let center = CGPoint(x: geo.size.width / 2, y: orreryHeight / 2)

                        Canvas { ctx, size in
                            drawOrbits(ctx: &ctx, center: center, maxR: maxR, time: t)
                        }
                        .frame(height: orreryHeight)
                    }
                    .allowsHitTesting(false)

                    // Nucleus at center
                    NucleusView(utilization: state.overallUtilization)
                        .position(x: geo.size.width / 2, y: orreryHeight / 2)
                        .allowsHitTesting(false)

                    // Tap detection overlay
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(height: orreryHeight)
                        .onTapGesture { location in
                            handleTap(in: CGSize(width: geo.size.width, height: orreryHeight), at: location)
                        }

                    // Tapped planet tooltip
                    if let planet = tappedPlanet {
                        tooltipView(for: planet)
                            .position(planet.position)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: orreryHeight)
                .frame(maxHeight: .infinity, alignment: .top)

                // Readout bar pinned to bottom
                VStack {
                    Spacer()
                    readoutBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                // Error / loading overlays
                if state.isLoading && state.usage == nil {
                    ProgressView()
                        .tint(.white)
                }

                if let error = state.error, state.usage == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.tierCritical)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.stardust.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showStats) {
            StatsView_iOS(state: state)
        }
    }

    // MARK: - Readout Bar

    private var readoutBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: expanded ? 24 : 16) {
                readoutItem(label: "5h", pct: state.fiveHourPct, tint: Theme.sessionOrbit, reset: expanded ? state.fiveHourResetString : nil)
                readoutItem(label: "7d", pct: state.sevenDayPct, tint: Theme.weeklyOrbit, reset: expanded ? state.sevenDayResetString : nil)
                readoutItem(label: "S", pct: state.sonnetPct, tint: Theme.outerOrbit, reset: nil)
                if state.opusPct > 0 {
                    readoutItem(label: "O", pct: state.opusPct, tint: Theme.tierCritical, reset: nil)
                }
            }

            // Detail button when expanded
            if expanded {
                Button {
                    showStats = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 10))
                        Text("Details")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 8)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
            }
        }
        .padding(.horizontal, expanded ? 24 : 16)
        .padding(.vertical, expanded ? 14 : 10)
        .background(
            RoundedRectangle(cornerRadius: expanded ? 20 : 28)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: expanded ? 20 : 28)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: expanded ? 20 : 28))
        .onTapGesture {
            withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                expanded.toggle()
            }
        }
    }

    private func readoutItem(label: String, pct: Double, tint: Color, reset: String?) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.8))
            Text("\(Int(pct))%")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.forUtilization(pct))
                .scaleEffect(expanded ? 1.0 : 0.85)
            if let reset, !reset.isEmpty {
                Text(reset)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
            }
        }
        .frame(minWidth: expanded ? 54 : 40)
    }

    // MARK: - Tooltip

    private func tooltipView(for planet: TappedPlanet) -> some View {
        let reset = planet.reset.isEmpty ? "" : " — resets in \(planet.reset)"
        return Text("\(planet.label): \(Int(planet.pct))%\(reset)")
            .font(Theme.captionFont)
            .foregroundStyle(Theme.stardust)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
            .offset(y: -36)
    }

    // MARK: - Canvas Rendering

    private func drawOrbits(ctx: inout GraphicsContext, center: CGPoint, maxR: Double, time: Double) {
        let sessionTex = ctx.resolve(Image("planet_session"))
        let weeklyTex = ctx.resolve(Image("planet_weekly"))
        let outerTex = ctx.resolve(Image("planet_outer"))

        // 1.5x larger planet sizes for touch targets
        let orbits: [(radius: Double, pct: Double, color: Color, baseDrift: Double, pSize: Double, label: String, texture: GraphicsContext.ResolvedImage)] = [
            (maxR * 0.45, state.fiveHourPct, Theme.sessionOrbit, 0.05, 9, "Session", sessionTex),
            (maxR * 0.70, state.sevenDayPct, Theme.weeklyOrbit, 0.03, 13.5, "Weekly", weeklyTex),
            (maxR * 1.00, state.outerOrbitPct, Theme.outerOrbit, 0.02, 18, state.outerOrbitLabel, outerTex),
        ]

        // Orbital rings
        for orbit in orbits {
            let ringRect = CGRect(
                x: center.x - orbit.radius,
                y: center.y - orbit.radius,
                width: orbit.radius * 2,
                height: orbit.radius * 2
            )
            let ringPath = Circle().path(in: ringRect)
            ctx.stroke(ringPath, with: .color(orbit.color.opacity(0.06)), lineWidth: 3)
            ctx.stroke(
                ringPath,
                with: .conicGradient(
                    Gradient(colors: [
                        orbit.color.opacity(0.25),
                        orbit.color.opacity(0.06),
                        orbit.color.opacity(0.03),
                        orbit.color.opacity(0.06),
                        orbit.color.opacity(0.25),
                    ]),
                    center: center,
                    angle: .radians(-0.8)
                ),
                lineWidth: 0.8
            )
        }

        // Trails and planets
        for orbit in orbits {
            let urgency = pow(orbit.pct / 100.0, 2.0)
            let drift = orbit.baseDrift + urgency * 0.15
            let angle = (orbit.pct / 100.0) * .pi * 2 + time * drift - .pi / 2

            // Comet trail
            let trailLen = 1.0
            let segments = 30
            for seg in 0..<segments {
                let frac = Double(seg) / Double(segments)
                let a1 = angle - trailLen * (1 - frac)
                let a2 = angle - trailLen * (1 - Double(seg + 1) / Double(segments))
                var trail = Path()
                trail.move(to: CGPoint(x: center.x + cos(a1) * orbit.radius, y: center.y + sin(a1) * orbit.radius))
                trail.addLine(to: CGPoint(x: center.x + cos(a2) * orbit.radius, y: center.y + sin(a2) * orbit.radius))
                let trailOpacity = frac * frac * 0.5
                let trailWidth = orbit.pSize * (0.8 - frac * 0.55)
                ctx.stroke(trail, with: .color(orbit.color.opacity(trailOpacity)), lineWidth: trailWidth)
            }

            let px = center.x + cos(angle) * orbit.radius
            let py = center.y + sin(angle) * orbit.radius
            let ps = orbit.pSize

            // Ember sparks — reduced from 15 to 8 for battery
            let sparkCount = 8
            for i in 0..<sparkCount {
                let sparkPhase = Double(i) / Double(sparkCount)
                let sparkAngle = angle - sparkPhase * 0.6
                let scatter = sin(time * 2.5 + Double(i) * 2.4) * ps * 1.8
                let sparkR = orbit.radius + scatter
                let sx = center.x + cos(sparkAngle) * sparkR
                let sy = center.y + sin(sparkAngle) * sparkR
                let life = max(0, 1.0 - sparkPhase)
                let sparkSize = ps * 0.2 * life
                if sparkSize > 0.3 {
                    ctx.fill(
                        Circle().path(in: CGRect(x: sx - sparkSize, y: sy - sparkSize, width: sparkSize * 2, height: sparkSize * 2)),
                        with: .color(orbit.color.opacity(life * 0.5))
                    )
                }
            }

            // Outer corona
            let glowOpacity = 0.3 + urgency * 0.4
            let glowRadius = ps * (2 + urgency * 2)
            ctx.fill(
                Circle().path(in: CGRect(x: px - glowRadius, y: py - glowRadius, width: glowRadius * 2, height: glowRadius * 2)),
                with: .radialGradient(
                    Gradient(colors: [orbit.color.opacity(glowOpacity), orbit.color.opacity(glowOpacity * 0.3), .clear]),
                    center: CGPoint(x: px, y: py),
                    startRadius: 0,
                    endRadius: glowRadius
                )
            )

            // Planet sphere — 3D radial gradient
            let lightX = px - ps * 0.3
            let lightY = py - ps * 0.3
            ctx.fill(
                Circle().path(in: CGRect(x: px - ps, y: py - ps, width: ps * 2, height: ps * 2)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .white.opacity(0.9), location: 0.0),
                        .init(color: orbit.color, location: 0.35),
                        .init(color: orbit.color.opacity(0.3), location: 0.75),
                        .init(color: orbit.color.opacity(0.05), location: 1.0),
                    ]),
                    center: CGPoint(x: lightX, y: lightY),
                    startRadius: 0,
                    endRadius: ps * 1.4
                )
            )

            // Planet texture overlay
            let planetRect = CGRect(x: px - ps, y: py - ps, width: ps * 2, height: ps * 2)
            ctx.drawLayer { texCtx in
                texCtx.clip(to: Circle().path(in: planetRect))
                texCtx.blendMode = .overlay
                texCtx.opacity = 0.4
                texCtx.draw(orbit.texture, in: planetRect)
            }

            // Specular highlight
            let specX = px - ps * 0.35
            let specY = py - ps * 0.35
            let specR = ps * 0.35
            ctx.fill(
                Circle().path(in: CGRect(x: specX - specR, y: specY - specR, width: specR * 2, height: specR * 2)),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.7), .clear]),
                    center: CGPoint(x: specX, y: specY),
                    startRadius: 0,
                    endRadius: specR
                )
            )

            // Atmosphere rim light
            var rimPath = Path()
            rimPath.addArc(
                center: CGPoint(x: px, y: py),
                radius: ps - 0.5,
                startAngle: .radians(-.pi * 0.85),
                endAngle: .radians(-.pi * 0.15),
                clockwise: false
            )
            ctx.stroke(
                rimPath,
                with: .linearGradient(
                    Gradient(colors: [.clear, orbit.color.opacity(0.8), .white.opacity(0.6), orbit.color.opacity(0.8), .clear]),
                    startPoint: CGPoint(x: px - ps, y: py - ps),
                    endPoint: CGPoint(x: px + ps, y: py)
                ),
                lineWidth: 1.0
            )
        }
    }

    // MARK: - Tap Hit Testing

    private func handleTap(in size: CGSize, at point: CGPoint) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxR = min(size.width, size.height) * 0.38
        let t = Date.timeIntervalSinceReferenceDate

        let planets: [(pct: Double, radius: Double, baseDrift: Double, hitR: Double, label: String, reset: String, id: String)] = [
            (state.fiveHourPct, maxR * 0.45, 0.05, 48, "Session", state.fiveHourResetString, "session"),
            (state.sevenDayPct, maxR * 0.70, 0.03, 48, "Weekly", state.sevenDayResetString, "weekly"),
            (state.outerOrbitPct, maxR * 1.00, 0.02, 48, state.outerOrbitLabel, "", "outer"),
        ]

        for planet in planets {
            let urgency = pow(planet.pct / 100.0, 2.0)
            let drift = planet.baseDrift + urgency * 0.15
            let angle = (planet.pct / 100.0) * .pi * 2 + t * drift - .pi / 2
            let px = center.x + cos(angle) * planet.radius
            let py = center.y + sin(angle) * planet.radius
            let dx = point.x - px
            let dy = point.y - py
            if dx * dx + dy * dy < planet.hitR * planet.hitR {
                withAnimation(.easeOut(duration: 0.2)) {
                    tappedPlanet = TappedPlanet(
                        label: planet.label,
                        pct: planet.pct,
                        reset: planet.reset,
                        position: CGPoint(x: px, y: py),
                        id: planet.id
                    )
                }
                // Auto-dismiss after 3 seconds
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.3)) {
                            if tappedPlanet?.id == planet.id {
                                tappedPlanet = nil
                            }
                        }
                    }
                }
                return
            }
        }
        // Tapped empty space — dismiss tooltip
        withAnimation(.easeOut(duration: 0.2)) {
            tappedPlanet = nil
        }
    }
}
