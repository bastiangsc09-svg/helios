import SwiftUI

// MARK: - Corona Ray Shape

struct CoronaRay: Shape {
    var rayCount: Int
    var innerRadius: Double
    var outerRadius: Double
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        for i in 0..<rayCount {
            let baseAngle = (Double(i) / Double(rayCount)) * .pi * 2 + phase
            let halfWidth = (.pi / Double(rayCount)) * 0.3

            let innerLeft = CGPoint(
                x: center.x + cos(baseAngle - halfWidth) * innerRadius,
                y: center.y + sin(baseAngle - halfWidth) * innerRadius
            )
            let tip = CGPoint(
                x: center.x + cos(baseAngle) * outerRadius,
                y: center.y + sin(baseAngle) * outerRadius
            )
            let innerRight = CGPoint(
                x: center.x + cos(baseAngle + halfWidth) * innerRadius,
                y: center.y + sin(baseAngle + halfWidth) * innerRadius
            )

            path.move(to: innerLeft)
            path.addLine(to: tip)
            path.addLine(to: innerRight)
            path.closeSubpath()
        }

        return path
    }
}

// MARK: - Nucleus View (Usage-Driven Pulsing Core)

struct NucleusView: View {
    let utilization: Double // 0-100

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            // Pulse rate: 0.5Hz (low) → 3Hz (critical)
            let pulseHz = 0.5 + (utilization / 100.0) * 2.5
            let pulseScale = 1.0 + sin(t * pulseHz * .pi * 2) * 0.05
            let rot = t * 0.1

            ZStack {
                // Outer corona glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [nucleusColor.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale)
                    .blendMode(.plusLighter)

                // Corona rays — outer ring
                CoronaRay(rayCount: 12, innerRadius: 22, outerRadius: 45, phase: rot)
                    .fill(nucleusColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blendMode(.screen)

                // Corona rays — inner counter-rotating
                CoronaRay(rayCount: 8, innerRadius: 20, outerRadius: 38, phase: -rot * 0.7)
                    .fill(coreColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .blendMode(.screen)

                // Core body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [coreColor, nucleusColor, nucleusColor.opacity(0.3)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .scaleEffect(pulseScale)
            }
        }
    }

    // Color shifts: cool indigo (low) → amber (moderate) → red (critical)
    private var nucleusColor: Color {
        let t = utilization / 100.0
        if t < 0.6 {
            return Color.lerp(Theme.nucleusCool, Theme.nucleusWarm, t: t / 0.6)
        } else {
            return Color.lerp(Theme.nucleusWarm, Theme.nucleusHot, t: (t - 0.6) / 0.4)
        }
    }

    private var coreColor: Color {
        Color.lerp(Theme.nucleusCorona, nucleusColor, t: 0.3)
    }
}
