import SwiftUI

struct OrreryView: View {
    let state: UsageState
    @State private var hoverText: String?
    @State private var tooltipPos: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Usage-responsive starfield
                StarfieldCanvas(
                    starCount: 300,
                    brightnessMultiplier: 0.4 + (state.overallUtilization / 100.0) * 0.6
                )

                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    let maxR = Swift.min(geo.size.width, geo.size.height) * 0.38

                    Canvas { ctx, size in
                        drawOrbits(ctx: &ctx, center: center, maxR: maxR, time: t)
                    }
                }

                // Nucleus at center
                NucleusView(utilization: state.overallUtilization)

                // Hover tooltip
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

                // Adaptive readout: below when there's room, right side when not
                let maxR = Swift.min(geo.size.width, geo.size.height) * 0.38
                let bottomSpace = geo.size.height / 2 - maxR
                let useBottom = bottomSpace > 70

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
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let loc):
                    checkPlanetHover(in: geo.size, mouse: loc)
                case .ended:
                    hoverText = nil
                }
            }
        }
    }

    // MARK: - Digital Readout

    private var readoutBar: some View {
        HStack(spacing: 16) {
            readoutItem(label: "5h", pct: state.fiveHourPct)
            readoutItem(label: "7d", pct: state.sevenDayPct)
            readoutItem(label: "S", pct: state.sonnetPct)
            if state.opusPct > 0 {
                readoutItem(label: "O", pct: state.opusPct)
            }
        }
        .font(Theme.readoutFont)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(0.5)
        )
    }

    private func readoutItem(label: String, pct: Double) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(Theme.stardust.opacity(0.5))
            Text("\(Int(pct))%")
                .foregroundStyle(Color.forUtilization(pct))
        }
    }

    // MARK: - Vertical Readout (right side, when window is short)

    private var readoutColumn: some View {
        VStack(spacing: 12) {
            readoutColumnItem(label: "5h", pct: state.fiveHourPct)
            readoutColumnItem(label: "7d", pct: state.sevenDayPct)
            readoutColumnItem(label: "S", pct: state.sonnetPct)
            if state.opusPct > 0 {
                readoutColumnItem(label: "O", pct: state.opusPct)
            }
        }
        .font(Theme.readoutFont)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .opacity(0.5)
        )
    }

    private func readoutColumnItem(label: String, pct: Double) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .foregroundStyle(Theme.stardust.opacity(0.5))
            Text("\(Int(pct))%")
                .foregroundStyle(Color.forUtilization(pct))
        }
    }

    // MARK: - Canvas Rendering

    private func drawOrbits(ctx: inout GraphicsContext, center: CGPoint, maxR: Double, time: Double) {
        let orbits: [(radius: Double, pct: Double, color: Color, drift: Double, pSize: Double, label: String)] = [
            (maxR * 0.45, state.fiveHourPct, Theme.sessionOrbit, 0.05, 6, "Session"),
            (maxR * 0.70, state.sevenDayPct, Theme.weeklyOrbit, 0.03, 9, "Weekly"),
            (maxR * 1.00, state.outerOrbitPct, Theme.outerOrbit, 0.02, 12, state.outerOrbitLabel),
        ]

        // Orbital rings
        for orbit in orbits {
            let ringRect = CGRect(
                x: center.x - orbit.radius,
                y: center.y - orbit.radius,
                width: orbit.radius * 2,
                height: orbit.radius * 2
            )
            ctx.stroke(
                Circle().path(in: ringRect),
                with: .color(orbit.color.opacity(0.12)),
                lineWidth: 1
            )
        }

        // Trails and planets
        for orbit in orbits {
            let angle = (orbit.pct / 100.0) * .pi * 2 + time * orbit.drift - .pi / 2

            // Trail
            let trailLen = 0.8
            let segments = 20
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
                ctx.stroke(
                    trail,
                    with: .color(orbit.color.opacity(frac * 0.4)),
                    lineWidth: orbit.pSize * 0.5
                )
            }

            // Planet glow
            let px = center.x + cos(angle) * orbit.radius
            let py = center.y + sin(angle) * orbit.radius
            let ps = orbit.pSize

            ctx.fill(
                Circle().path(in: CGRect(x: px - ps * 2, y: py - ps * 2, width: ps * 4, height: ps * 4)),
                with: .radialGradient(
                    Gradient(colors: [orbit.color.opacity(0.3), .clear]),
                    center: CGPoint(x: px, y: py),
                    startRadius: 0,
                    endRadius: ps * 2
                )
            )

            // Planet core
            ctx.fill(
                Circle().path(in: CGRect(x: px - ps, y: py - ps, width: ps * 2, height: ps * 2)),
                with: .color(orbit.color)
            )
        }
    }

    // MARK: - Hover Hit Testing

    private func checkPlanetHover(in size: CGSize, mouse: CGPoint) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxR = Swift.min(size.width, size.height) * 0.38
        let t = Date.timeIntervalSinceReferenceDate

        let planets: [(pct: Double, radius: Double, drift: Double, hitR: Double, label: String, reset: String)] = [
            (state.fiveHourPct, maxR * 0.45, 0.05, 20, "Session", state.fiveHourResetString),
            (state.sevenDayPct, maxR * 0.70, 0.03, 24, "Weekly", state.sevenDayResetString),
            (state.outerOrbitPct, maxR * 1.00, 0.02, 28, state.outerOrbitLabel, ""),
        ]

        for planet in planets {
            let angle = (planet.pct / 100.0) * .pi * 2 + t * planet.drift - .pi / 2
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
