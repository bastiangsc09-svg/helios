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
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            // Pulse rate: 0.15Hz (low) → 0.8Hz (critical)
            let pulseHz = 0.15 + (utilization / 100.0) * 0.65
            let pulseScale = 1.0 + sin(t * pulseHz * .pi * 2) * 0.04
            let rot = t * 0.03

            ZStack {
                // Expanding pulse rings — sonar-like energy waves
                let ringSpeed = 0.1 + (utilization / 100.0) * 0.25
                ForEach(0..<3, id: \.self) { i in
                    let phase = fmod(t * ringSpeed + Double(i) / 3.0, 1.0)
                    Circle()
                        .stroke(nucleusColor.opacity((1 - phase) * 0.2), lineWidth: 1.5 * (1 - phase))
                        .frame(width: 40 + phase * 160, height: 40 + phase * 160)
                        .blendMode(.screen)
                }

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

                // Core body with solar texture
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [coreColor, nucleusColor, nucleusColor.opacity(0.3)],
                                center: .center,
                                startRadius: 2,
                                endRadius: 20
                            )
                        )

                    // Solar granulation texture overlay
                    Image("nucleus_texture")
                        .resizable()
                        .clipShape(Circle())
                        .blendMode(.overlay)
                        .opacity(0.5)
                        .rotationEffect(.radians(t * 0.02))
                }
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
