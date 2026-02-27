import SwiftUI

private struct Star {
    let x: Double
    let y: Double
    let size: Double
    let brightness: Double
    let twinkleSpeed: Double
    let twinkleOffset: Double
}

struct StarfieldCanvas: View {
    let starCount: Int
    var brightnessMultiplier: Double = 1.0

    @State private var stars: [Star]

    init(starCount: Int = 200, brightnessMultiplier: Double = 1.0) {
        self.starCount = starCount
        self.brightnessMultiplier = brightnessMultiplier
        // Generate stars at init time so they survive tab switches
        self._stars = State(initialValue: (0..<starCount).map { _ in
            Star(
                x: Double.random(in: 0...1),
                y: Double.random(in: 0...1),
                size: Double.random(in: 0.5...2.0),
                brightness: Double.random(in: 0.2...1.0),
                twinkleSpeed: Double.random(in: 0.5...3.0),
                twinkleOffset: Double.random(in: 0...(.pi * 2))
            )
        })
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let bm = brightnessMultiplier

                for star in stars {
                    let twinkle = (sin(time * star.twinkleSpeed + star.twinkleOffset) + 1) / 2
                    let alpha = star.brightness * (0.3 + 0.7 * twinkle) * bm
                    let px = star.x * size.width
                    let py = star.y * size.height
                    let r = star.size * (0.8 + 0.2 * twinkle)

                    ctx.opacity = alpha
                    ctx.fill(
                        Circle().path(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                        with: .color(.white)
                    )

                    // Glow halo for bright stars
                    if star.brightness > 0.7 {
                        let gr = r * 4
                        ctx.opacity = alpha * 0.15
                        ctx.fill(
                            Circle().path(in: CGRect(x: px - gr, y: py - gr, width: gr * 2, height: gr * 2)),
                            with: .radialGradient(
                                Gradient(colors: [.white.opacity(0.4), .clear]),
                                center: CGPoint(x: px, y: py),
                                startRadius: 0,
                                endRadius: gr
                            )
                        )
                    }
                }
            }
        }
    }
}
