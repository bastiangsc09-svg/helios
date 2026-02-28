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
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { ctx, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let bm = brightnessMultiplier

                // Nebula color wash — slow-drifting colored blobs for depth
                let nebulae: [(hue: Double, xBase: Double, yBase: Double, radius: Double, freq: Double, phase: Double)] = [
                    (0.75, 0.25, 0.35, 0.30, 0.08, 0.0),    // purple, upper-left
                    (0.55, 0.70, 0.60, 0.25, 0.06, 2.0),    // teal, lower-right
                    (0.85, 0.50, 0.25, 0.20, 0.10, 4.5),    // magenta, upper-center
                ]
                for neb in nebulae {
                    let nx = (neb.xBase + sin(time * neb.freq + neb.phase) * 0.05) * size.width
                    let ny = (neb.yBase + cos(time * neb.freq * 0.7 + neb.phase) * 0.04) * size.height
                    let nr = neb.radius * min(size.width, size.height)
                    ctx.fill(
                        Circle().path(in: CGRect(x: nx - nr, y: ny - nr, width: nr * 2, height: nr * 2)),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(hue: neb.hue, saturation: 0.6, brightness: 0.4).opacity(0.06 * bm),
                                Color(hue: neb.hue, saturation: 0.5, brightness: 0.3).opacity(0.02 * bm),
                                .clear
                            ]),
                            center: CGPoint(x: nx, y: ny),
                            startRadius: 0,
                            endRadius: nr
                        )
                    )
                }

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

                    // Diffraction spikes on brightest stars
                    if star.brightness > 0.85 {
                        let spikeLen = r * 6 * (0.8 + 0.2 * twinkle)
                        ctx.opacity = alpha * 0.25
                        var h = Path()
                        h.move(to: CGPoint(x: px - spikeLen, y: py))
                        h.addLine(to: CGPoint(x: px + spikeLen, y: py))
                        ctx.stroke(h, with: .color(.white), lineWidth: 0.5)
                        var v = Path()
                        v.move(to: CGPoint(x: px, y: py - spikeLen))
                        v.addLine(to: CGPoint(x: px, y: py + spikeLen))
                        ctx.stroke(v, with: .color(.white), lineWidth: 0.5)
                    }
                }
            }
        }
    }
}
