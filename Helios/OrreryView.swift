import SwiftUI

struct OrreryView: View {
    let state: UsageState
    @State private var hoverText: String?
    @State private var tooltipPos: CGPoint = .zero
    @State private var expanded = false

    var body: some View {
        GeometryReader { geo in
            let maxR = Swift.min(geo.size.width, geo.size.height) * 0.38
            let bottomSpace = geo.size.height / 2 - maxR
            let useBottom = bottomSpace > 70

            ZStack {
                // Usage-responsive starfield
                StarfieldCanvas(
                    starCount: 300,
                    brightnessMultiplier: 0.4 + (state.overallUtilization / 100.0) * 0.6
                )
                .allowsHitTesting(false)

                TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                    Canvas { ctx, size in
                        drawOrbits(ctx: &ctx, center: center, maxR: maxR, time: t)
                    }
                }
                .allowsHitTesting(false)

                // Nucleus at center
                NucleusView(utilization: state.overallUtilization)
                    .allowsHitTesting(false)

                // Hover detection layer
                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc):
                            checkPlanetHover(in: geo.size, mouse: loc)
                        case .ended:
                            hoverText = nil
                        }
                    }

                // Adaptive readout — clickable, above hover layer
                if useBottom {
                    VStack {
                        Spacer()
                        readoutBar
                            .padding(.bottom, 20)
                    }
                } else {
                    HStack {
                        Spacer()
                        readoutColumn
                            .padding(.trailing, 16)
                    }
                }

                // Hover tooltip — above everything
                if let text = hoverText {
                    Text(text)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.stardust)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .position(tooltipPos)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Digital Readout (fat capsule with reset timers)

    private var readoutBar: some View {
        HStack(spacing: expanded ? 24 : 16) {
            readoutItem(label: "5h", pct: state.fiveHourPct, tint: Theme.sessionOrbit, reset: expanded ? state.fiveHourResetString : nil)
            readoutItem(label: "7d", pct: state.sevenDayPct, tint: Theme.weeklyOrbit, reset: expanded ? state.sevenDayResetString : nil)
            readoutItem(label: "S", pct: state.sonnetPct, tint: Theme.outerOrbit, reset: nil)
            if state.opusPct > 0 {
                readoutItem(label: "O", pct: state.opusPct, tint: Theme.tierCritical, reset: nil)
            }
        }
        .padding(.horizontal, expanded ? 24 : 16)
        .padding(.vertical, expanded ? 12 : 8)
        .background(
            RoundedRectangle(cornerRadius: expanded ? 20 : 28)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: expanded ? 20 : 28).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
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
                .shadow(color: Color.white.opacity(0.6), radius: 4)
            Text("\(Int(pct))%")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.forUtilization(pct))
                .shadow(color: Color.forUtilization(pct).opacity(0.6), radius: 6)
                .scaleEffect(expanded ? 1.0 : 0.82)
            if let reset, !reset.isEmpty {
                Text(reset)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .shadow(color: Color.white.opacity(0.4), radius: 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
            }
        }
        .frame(minWidth: expanded ? 50 : 36)
    }

    // MARK: - Vertical Readout (right side, when window is short)

    private var readoutColumn: some View {
        VStack(spacing: expanded ? 14 : 10) {
            readoutColumnItem(label: "5h", pct: state.fiveHourPct, tint: Theme.sessionOrbit, reset: expanded ? state.fiveHourResetString : nil)
            readoutColumnItem(label: "7d", pct: state.sevenDayPct, tint: Theme.weeklyOrbit, reset: expanded ? state.sevenDayResetString : nil)
            readoutColumnItem(label: "S", pct: state.sonnetPct, tint: Theme.outerOrbit, reset: nil)
            if state.opusPct > 0 {
                readoutColumnItem(label: "O", pct: state.opusPct, tint: Theme.tierCritical, reset: nil)
            }
        }
        .padding(.horizontal, expanded ? 12 : 10)
        .padding(.vertical, expanded ? 14 : 10)
        .background(
            RoundedRectangle(cornerRadius: expanded ? 16 : 20)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: expanded ? 16 : 20).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        )
        .contentShape(RoundedRectangle(cornerRadius: expanded ? 16 : 20))
        .onTapGesture {
            withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                expanded.toggle()
            }
        }
    }

    private func readoutColumnItem(label: String, pct: Double, tint: Color, reset: String?) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.8))
                .shadow(color: Color.white.opacity(0.6), radius: 4)
            Text("\(Int(pct))%")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.forUtilization(pct))
                .shadow(color: Color.forUtilization(pct).opacity(0.6), radius: 6)
                .scaleEffect(expanded ? 1.0 : 0.85)
            if let reset, !reset.isEmpty {
                Text(reset)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .shadow(color: Color.white.opacity(0.4), radius: 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
            }
        }
    }

    // MARK: - Canvas Rendering

    private func drawOrbits(ctx: inout GraphicsContext, center: CGPoint, maxR: Double, time: Double) {
        // Resolve planet textures once per frame
        let sessionTex = ctx.resolve(Image("planet_session"))
        let weeklyTex = ctx.resolve(Image("planet_weekly"))
        let outerTex = ctx.resolve(Image("planet_outer"))

        let orbits: [(radius: Double, pct: Double, color: Color, baseDrift: Double, pSize: Double, label: String, texture: GraphicsContext.ResolvedImage)] = [
            (maxR * 0.45, state.fiveHourPct, Theme.sessionOrbit, 0.05, 6, "Session", sessionTex),
            (maxR * 0.70, state.sevenDayPct, Theme.weeklyOrbit, 0.03, 9, "Weekly", weeklyTex),
            (maxR * 1.00, state.outerOrbitPct, Theme.outerOrbit, 0.02, 12, state.outerOrbitLabel, outerTex),
        ]

        // Orbital rings — conic gradient for directional light + soft glow
        for orbit in orbits {
            let ringRect = CGRect(
                x: center.x - orbit.radius,
                y: center.y - orbit.radius,
                width: orbit.radius * 2,
                height: orbit.radius * 2
            )
            let ringPath = Circle().path(in: ringRect)
            // Wide faint outer glow
            ctx.stroke(
                ringPath,
                with: .color(orbit.color.opacity(0.06)),
                lineWidth: 3
            )
            // Conic gradient core — light catches from upper-left
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

            // Enhanced comet trail — tapering width, quadratic fade
            let trailLen = 1.0
            let segments = 30
            for seg in 0..<segments {
                let frac = Double(seg) / Double(segments)
                let a1 = angle - trailLen * (1 - frac)
                let a2 = angle - trailLen * (1 - Double(seg + 1) / Double(segments))

                var trail = Path()
                trail.move(to: CGPoint(
                    x: center.x + cos(a1) * orbit.radius,
                    y: center.y + sin(a1) * orbit.radius
                ))
                trail.addLine(to: CGPoint(
                    x: center.x + cos(a2) * orbit.radius,
                    y: center.y + sin(a2) * orbit.radius
                ))
                let trailOpacity = frac * frac * 0.5
                let trailWidth = orbit.pSize * (0.8 - frac * 0.55)
                ctx.stroke(
                    trail,
                    with: .color(orbit.color.opacity(trailOpacity)),
                    lineWidth: trailWidth
                )
            }

            let px = center.x + cos(angle) * orbit.radius
            let py = center.y + sin(angle) * orbit.radius
            let ps = orbit.pSize

            // Ember sparks — scattered particles drifting off the trail
            let sparkCount = 15
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

            // Outer corona — wide, soft, urgency-reactive
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

            // Planet sphere — 3D radial gradient with light offset
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

            // Planet texture overlay — clipped to planet circle, blended on top of 3D gradient
            let planetRect = CGRect(x: px - ps, y: py - ps, width: ps * 2, height: ps * 2)
            ctx.drawLayer { texCtx in
                texCtx.clip(to: Circle().path(in: planetRect))
                texCtx.blendMode = .overlay
                texCtx.opacity = 0.4
                texCtx.draw(orbit.texture, in: planetRect)
            }

            // Specular highlight — bright spot near light source
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

            // Atmosphere rim light — bright arc on the sunlit edge
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

    // MARK: - Hover Hit Testing

    private func checkPlanetHover(in size: CGSize, mouse: CGPoint) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxR = Swift.min(size.width, size.height) * 0.38
        let t = Date.timeIntervalSinceReferenceDate

        let planets: [(pct: Double, radius: Double, baseDrift: Double, hitR: Double, label: String, reset: String)] = [
            (state.fiveHourPct, maxR * 0.45, 0.05, 32, "Session", state.fiveHourResetString),
            (state.sevenDayPct, maxR * 0.70, 0.03, 32, "Weekly", state.sevenDayResetString),
            (state.outerOrbitPct, maxR * 1.00, 0.02, 34, state.outerOrbitLabel, ""),
        ]

        for planet in planets {
            let urgency = pow(planet.pct / 100.0, 2.0)
            let drift = planet.baseDrift + urgency * 0.15
            let angle = (planet.pct / 100.0) * .pi * 2 + t * drift - .pi / 2
            let px = center.x + cos(angle) * planet.radius
            let py = center.y + sin(angle) * planet.radius
            let dx = mouse.x - px
            let dy = mouse.y - py
            if dx * dx + dy * dy < planet.hitR * planet.hitR {
                let reset = planet.reset.isEmpty ? "" : " — resets in \(planet.reset)"
                hoverText = "\(planet.label): \(Int(planet.pct))%\(reset)"
                tooltipPos = CGPoint(x: px, y: py - 24)
                return
            }
        }
        hoverText = nil
    }
}
