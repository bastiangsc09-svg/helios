import SwiftUI

// MARK: - Flower Test Harness
// Shows 3 anemone variants side-by-side: Deep Sea, Crown, Spiral.
// Each maps to a bucket: Session → Deep Sea, Weekly → Crown, Sonnet → Spiral.

struct FlowerTestView: View {
    @State private var utilization: Double = 70

    var body: some View {
        ZStack {
            Theme.void.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Anemone Variants")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.stardust.opacity(0.8))

                    HStack(spacing: 16) {
                        Text("Utilization")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.stardust.opacity(0.5))
                        Slider(value: $utilization, in: 0...100)
                            .frame(width: 220)
                            .tint(Theme.pulseSession)
                        Text("\(Int(utilization))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.forUtilization(utilization))
                            .frame(width: 40, alignment: .trailing)
                    }

                    TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate

                        Text("Detail View")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.stardust.opacity(0.35))

                        HStack(spacing: 24) {
                            flowerPanel("Deep Sea — Session", size: 220) { ctx, ctr, r in
                                FlowerRenderer.drawDeepSea(
                                    ctx: &ctx, center: ctr, radius: r,
                                    utilization: utilization, color: Theme.pulseSession, time: t)
                            }
                            flowerPanel("Crown — Weekly", size: 220) { ctx, ctr, r in
                                FlowerRenderer.drawCrown(
                                    ctx: &ctx, center: ctr, radius: r,
                                    utilization: utilization, color: Theme.pulseWeekly, time: t)
                            }
                            flowerPanel("Spiral — Sonnet", size: 220) { ctx, ctr, r in
                                FlowerRenderer.drawSpiral(
                                    ctx: &ctx, center: ctr, radius: r,
                                    utilization: utilization, color: Theme.pulseSonnet, time: t)
                            }
                        }

                        Text("Garden Scale (actual bloom size)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.stardust.opacity(0.35))
                            .padding(.top, 8)

                        HStack(spacing: 50) {
                            gardenScalePanel("Deep Sea") { ctx, ctr, r in
                                FlowerRenderer.drawDeepSea(
                                    ctx: &ctx, center: ctr, radius: r,
                                    utilization: utilization, color: Theme.pulseSession, time: t)
                            }
                            gardenScalePanel("Crown") { ctx, ctr, r in
                                FlowerRenderer.drawCrown(
                                    ctx: &ctx, center: ctr, radius: r,
                                    utilization: utilization, color: Theme.pulseWeekly, time: t)
                            }
                            gardenScalePanel("Spiral") { ctx, ctr, r in
                                FlowerRenderer.drawSpiral(
                                    ctx: &ctx, center: ctr, radius: r,
                                    utilization: utilization, color: Theme.pulseSonnet, time: t)
                            }
                        }
                    }
                }
                .padding(30)
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 760, minHeight: 420)
    }

    @ViewBuilder
    private func flowerPanel(
        _ title: String, size: Double,
        draw: @escaping (inout GraphicsContext, CGPoint, Double) -> Void
    ) -> some View {
        VStack(spacing: 8) {
            Canvas { ctx, sz in
                let ctr = CGPoint(x: sz.width / 2, y: sz.height / 2)
                draw(&ctx, ctr, min(sz.width, sz.height) * 0.3)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.stardust.opacity(0.06)))

            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.stardust.opacity(0.6))
        }
    }

    @ViewBuilder
    private func gardenScalePanel(
        _ title: String,
        draw: @escaping (inout GraphicsContext, CGPoint, Double) -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Canvas { ctx, sz in
                let ctr = CGPoint(x: sz.width / 2, y: sz.height / 2)
                draw(&ctx, ctr, 12.0 + 20.0 * utilization / 100.0)
            }
            .frame(width: 90, height: 90)

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.stardust.opacity(0.5))
        }
    }
}

// MARK: - Flower Renderer
// 3 anemone variants + shared eye. Called from BreakdownView garden.

enum FlowerRenderer {

    // MARK: Deep Sea — Session (cyan)
    // Many thin undulating tentacles, fast wave, small bioluminescent tips.

    static func drawDeepSea(
        ctx: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        utilization: Double,
        color: Color,
        time: Double,
        brightness: Double = 1.0
    ) {
        let u = utilization / 100.0
        let bm = brightness
        let tentacleCount = 14 + Int(u * 4)

        // Halo
        let haloR = radius * 2.5
        ctx.drawLayer { hCtx in
            hCtx.blendMode = .screen
            hCtx.fill(
                Circle().path(in: CGRect(
                    x: center.x - haloR, y: center.y - haloR,
                    width: haloR * 2, height: haloR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.12 * bm), color.opacity(0.03 * bm), .clear]),
                    center: center, startRadius: radius * 0.3, endRadius: haloR
                )
            )
        }

        // Tentacles — thin, fast undulation
        let segments = 20
        for i in 0..<tentacleCount {
            let baseAngle = Double(i) * .pi * 2 / Double(tentacleCount)
            let seed = Double(i) * 2.618
            let len = radius * (0.5 + u * 0.8)

            for s in 0..<segments {
                let t0 = Double(s) / Double(segments)
                let t1 = Double(s + 1) / Double(segments)
                let wave0 = sin(time * 1.2 + seed + t0 * 6) * t0 * radius * 0.15
                let wave1 = sin(time * 1.2 + seed + t1 * 6) * t1 * radius * 0.15
                let perp = baseAngle + .pi / 2

                let pt0 = CGPoint(
                    x: center.x + cos(baseAngle) * len * t0 + cos(perp) * wave0,
                    y: center.y + sin(baseAngle) * len * t0 + sin(perp) * wave0
                )
                let pt1 = CGPoint(
                    x: center.x + cos(baseAngle) * len * t1 + cos(perp) * wave1,
                    y: center.y + sin(baseAngle) * len * t1 + sin(perp) * wave1
                )

                var seg = Path()
                seg.move(to: pt0)
                seg.addLine(to: pt1)
                ctx.stroke(seg, with: .color(color.opacity((0.3 + t1 * 0.3) * bm)),
                           lineWidth: 3.0 - 2.5 * t1)
            }

            // Tip glow
            let tipWave = sin(time * 1.2 + seed + 6) * radius * 0.15
            let perp = baseAngle + .pi / 2
            let tip = CGPoint(
                x: center.x + cos(baseAngle) * len + cos(perp) * tipWave,
                y: center.y + sin(baseAngle) * len + sin(perp) * tipWave
            )
            let tipR = 4.0 + sin(time * 2.5 + seed) * 1.5
            let tipPulse = (sin(time * 3 + seed) + 1) / 2

            ctx.fill(
                Circle().path(in: CGRect(
                    x: tip.x - tipR * 2, y: tip.y - tipR * 2,
                    width: tipR * 4, height: tipR * 4
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.6 * bm * (0.5 + tipPulse * 0.5)), .clear]),
                    center: tip, startRadius: 0, endRadius: tipR * 2
                )
            )
            ctx.fill(
                Circle().path(in: CGRect(
                    x: tip.x - tipR * 0.6, y: tip.y - tipR * 0.6,
                    width: tipR * 1.2, height: tipR * 1.2
                )),
                with: .color(color.opacity(0.8 * bm))
            )
        }

        drawEye(ctx: &ctx, center: center, radius: radius * 0.25,
                utilization: utilization, color: color, time: time, brightness: bm)
    }

    // MARK: Crown — Weekly (lavender)
    // Fewer thick muscular tentacles, large bulbous glowing tips, slow regal sway.

    static func drawCrown(
        ctx: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        utilization: Double,
        color: Color,
        time: Double,
        brightness: Double = 1.0
    ) {
        let u = utilization / 100.0
        let bm = brightness
        let tentacleCount = 8 + Int(u * 2)

        // Wider, more regal halo
        let haloR = radius * 3.0
        ctx.drawLayer { hCtx in
            hCtx.blendMode = .screen
            hCtx.fill(
                Circle().path(in: CGRect(
                    x: center.x - haloR, y: center.y - haloR,
                    width: haloR * 2, height: haloR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.1 * bm), color.opacity(0.04 * bm), .clear]),
                    center: center, startRadius: radius * 0.2, endRadius: haloR
                )
            )
        }

        // Collar ring around center
        let collarR = radius * 0.4
        ctx.drawLayer { cCtx in
            cCtx.blendMode = .screen
            let collarRect = CGRect(
                x: center.x - collarR, y: center.y - collarR,
                width: collarR * 2, height: collarR * 2
            )
            cCtx.stroke(Circle().path(in: collarRect),
                        with: .color(color.opacity(0.2 * bm)), lineWidth: 3)
            cCtx.fill(
                Circle().path(in: CGRect(
                    x: center.x - collarR * 1.3, y: center.y - collarR * 1.3,
                    width: collarR * 2.6, height: collarR * 2.6
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.08 * bm), .clear]),
                    center: center, startRadius: collarR * 0.8, endRadius: collarR * 1.3
                )
            )
        }

        // Thick tentacles — slow powerful sway
        let segments = 15
        for i in 0..<tentacleCount {
            let baseAngle = Double(i) * .pi * 2 / Double(tentacleCount)
            let seed = Double(i) * 3.14
            let len = radius * (0.6 + u * 0.6)

            for s in 0..<segments {
                let t0 = Double(s) / Double(segments)
                let t1 = Double(s + 1) / Double(segments)
                let wave0 = sin(time * 0.6 + seed + t0 * 4) * t0 * radius * 0.1
                let wave1 = sin(time * 0.6 + seed + t1 * 4) * t1 * radius * 0.1
                let perp = baseAngle + .pi / 2

                let pt0 = CGPoint(
                    x: center.x + cos(baseAngle) * len * t0 + cos(perp) * wave0,
                    y: center.y + sin(baseAngle) * len * t0 + sin(perp) * wave0
                )
                let pt1 = CGPoint(
                    x: center.x + cos(baseAngle) * len * t1 + cos(perp) * wave1,
                    y: center.y + sin(baseAngle) * len * t1 + sin(perp) * wave1
                )

                var seg = Path()
                seg.move(to: pt0)
                seg.addLine(to: pt1)
                ctx.stroke(seg, with: .color(color.opacity((0.25 + t1 * 0.15) * bm)),
                           lineWidth: 6.0 - 3.5 * t1)
            }

            // Stalk glow per tentacle
            drawTentacleGlow(ctx: &ctx, center: center, baseAngle: baseAngle,
                             len: len, seed: seed, time: time, radius: radius,
                             color: color, bm: bm)

            // Large bulbous tip
            let tipWave = sin(time * 0.6 + seed + 4) * radius * 0.1
            let perp = baseAngle + .pi / 2
            let tip = CGPoint(
                x: center.x + cos(baseAngle) * len + cos(perp) * tipWave,
                y: center.y + sin(baseAngle) * len + sin(perp) * tipWave
            )
            let tipPulse = (sin(time * 1.5 + seed) + 1) / 2
            let bulbR = 7.0 + tipPulse * 3.0

            // Outer glow
            ctx.fill(
                Circle().path(in: CGRect(
                    x: tip.x - bulbR * 2.5, y: tip.y - bulbR * 2.5,
                    width: bulbR * 5, height: bulbR * 5
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.3 * bm * (0.5 + tipPulse * 0.5)), .clear]),
                    center: tip, startRadius: 0, endRadius: bulbR * 2.5
                )
            )
            // Core bulb
            ctx.fill(
                Circle().path(in: CGRect(
                    x: tip.x - bulbR, y: tip.y - bulbR,
                    width: bulbR * 2, height: bulbR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.9 * bm), color.opacity(0.4 * bm), .clear]),
                    center: tip, startRadius: 0, endRadius: bulbR
                )
            )
        }

        drawEye(ctx: &ctx, center: center, radius: radius * 0.22,
                utilization: utilization, color: color, time: time, brightness: bm)
    }

    // Crown helper — soft glow along tentacle body
    private static func drawTentacleGlow(
        ctx: inout GraphicsContext, center: CGPoint, baseAngle: Double,
        len: Double, seed: Double, time: Double, radius: Double,
        color: Color, bm: Double
    ) {
        ctx.drawLayer { gCtx in
            gCtx.blendMode = .screen
            var glowPath = Path()
            glowPath.move(to: center)
            let perp = baseAngle + .pi / 2
            let midWave = sin(time * 0.6 + seed + 2) * radius * 0.05
            let midPt = CGPoint(
                x: center.x + cos(baseAngle) * len * 0.5 + cos(perp) * midWave,
                y: center.y + sin(baseAngle) * len * 0.5 + sin(perp) * midWave
            )
            let tipWave = sin(time * 0.6 + seed + 4) * radius * 0.1
            let tipPt = CGPoint(
                x: center.x + cos(baseAngle) * len + cos(perp) * tipWave,
                y: center.y + sin(baseAngle) * len + sin(perp) * tipWave
            )
            glowPath.addQuadCurve(to: tipPt, control: midPt)
            gCtx.stroke(glowPath, with: .color(color.opacity(0.06 * bm)), lineWidth: 12)
        }
    }

    // MARK: Spiral — Sonnet (gold)
    // Corkscrewing tentacles with trailing phosphorescent wisps, slow rotation.

    static func drawSpiral(
        ctx: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        utilization: Double,
        color: Color,
        time: Double,
        brightness: Double = 1.0
    ) {
        let u = utilization / 100.0
        let bm = brightness
        let tentacleCount = 12

        // Halo
        let haloR = radius * 2.5
        ctx.drawLayer { hCtx in
            hCtx.blendMode = .screen
            hCtx.fill(
                Circle().path(in: CGRect(
                    x: center.x - haloR, y: center.y - haloR,
                    width: haloR * 2, height: haloR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.1 * bm), color.opacity(0.03 * bm), .clear]),
                    center: center, startRadius: radius * 0.3, endRadius: haloR
                )
            )
        }

        // Spiraling tentacles
        let segments = 25
        let globalRot = time * 0.1

        for i in 0..<tentacleCount {
            let baseAngle = Double(i) * .pi * 2 / Double(tentacleCount) + globalRot
            let seed = Double(i) * 1.618
            let len = radius * (0.5 + u * 0.7)
            let spiralDir: Double = i % 2 == 0 ? 1 : -1
            var tipPt = center

            for s in 0..<segments {
                let t0 = Double(s) / Double(segments)
                let t1 = Double(s + 1) / Double(segments)

                // Quadratic spiral offset — curls tighter at tip
                let sp0 = t0 * t0 * 2.5 * spiralDir
                let sp1 = t1 * t1 * 2.5 * spiralDir
                let wave0 = sin(time * 0.8 + seed + t0 * 5) * t0 * radius * 0.12
                let wave1 = sin(time * 0.8 + seed + t1 * 5) * t1 * radius * 0.12

                let a0 = baseAngle + sp0
                let a1 = baseAngle + sp1
                let perp0 = a0 + .pi / 2
                let perp1 = a1 + .pi / 2

                let pt0 = CGPoint(
                    x: center.x + cos(a0) * len * t0 + cos(perp0) * wave0,
                    y: center.y + sin(a0) * len * t0 + sin(perp0) * wave0
                )
                let pt1 = CGPoint(
                    x: center.x + cos(a1) * len * t1 + cos(perp1) * wave1,
                    y: center.y + sin(a1) * len * t1 + sin(perp1) * wave1
                )

                var seg = Path()
                seg.move(to: pt0)
                seg.addLine(to: pt1)
                ctx.stroke(seg, with: .color(color.opacity((0.25 + t1 * 0.35) * bm)),
                           lineWidth: 3.5 - 2.5 * t1)

                if s == segments - 1 { tipPt = pt1 }
            }

            // Tip glow
            let tipPulse = (sin(time * 2 + seed) + 1) / 2
            let tipR = 3.5 + tipPulse * 2.0
            ctx.fill(
                Circle().path(in: CGRect(
                    x: tipPt.x - tipR * 2, y: tipPt.y - tipR * 2,
                    width: tipR * 4, height: tipR * 4
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.5 * bm * (0.5 + tipPulse * 0.5)), .clear]),
                    center: tipPt, startRadius: 0, endRadius: tipR * 2
                )
            )
            ctx.fill(
                Circle().path(in: CGRect(
                    x: tipPt.x - tipR * 0.5, y: tipPt.y - tipR * 0.5,
                    width: tipR, height: tipR
                )),
                with: .color(color.opacity(0.7 * bm))
            )

            // Trailing wisps — 3 ghost dots behind the tip
            for trail in 1...3 {
                let tT = 1.0 - Double(trail) * 0.08
                let tSp = tT * tT * 2.5 * spiralDir
                let tWave = sin(time * 0.8 + seed + tT * 5) * tT * radius * 0.12
                let tA = baseAngle + tSp
                let tPerp = tA + .pi / 2

                let wPt = CGPoint(
                    x: center.x + cos(tA) * len * tT + cos(tPerp) * tWave,
                    y: center.y + sin(tA) * len * tT + sin(tPerp) * tWave
                )
                let wR = 2.0 - Double(trail) * 0.3
                let wOp = (0.3 - Double(trail) * 0.08) * bm
                ctx.fill(
                    Circle().path(in: CGRect(
                        x: wPt.x - wR, y: wPt.y - wR,
                        width: wR * 2, height: wR * 2
                    )),
                    with: .color(color.opacity(wOp))
                )
            }
        }

        drawEye(ctx: &ctx, center: center, radius: radius * 0.22,
                utilization: utilization, color: color, time: time, brightness: bm)
    }

    // MARK: Shared — Eye Orb

    static func drawEye(
        ctx: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        utilization: Double,
        color: Color,
        time: Double,
        brightness: Double = 1.0
    ) {
        let bm = brightness
        let dilation = 0.3 + (utilization / 100.0) * 0.5
        let pulseRate = 1.5 + (utilization / 100.0) * 2.5
        let pulse = (sin(time * pulseRate) + 1) / 2

        // Pulsing glow
        let glowR = radius * (1.5 + pulse * 0.5)
        ctx.fill(
            Circle().path(in: CGRect(
                x: center.x - glowR, y: center.y - glowR,
                width: glowR * 2, height: glowR * 2
            )),
            with: .radialGradient(
                Gradient(colors: [color.opacity(0.25 * bm * (0.5 + pulse * 0.5)), .clear]),
                center: center, startRadius: radius * 0.3, endRadius: glowR
            )
        )

        // Iris
        let irisR = radius * dilation
        ctx.fill(
            Circle().path(in: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    Theme.void,
                    color.opacity(0.8 * bm),
                    color.opacity(0.3 * bm),
                    Theme.void.opacity(0.9),
                ]),
                center: center, startRadius: irisR * 0.3, endRadius: radius
            )
        )

        // Specular highlight
        let specX = center.x - radius * 0.25
        let specY = center.y - radius * 0.25
        let specR = radius * 0.2
        ctx.fill(
            Circle().path(in: CGRect(
                x: specX - specR, y: specY - specR,
                width: specR * 2, height: specR * 2
            )),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.7 * bm), .clear]),
                center: CGPoint(x: specX, y: specY), startRadius: 0, endRadius: specR
            )
        )

        // Percentage text removed — rendered below label in BreakdownView instead
    }
}

#Preview {
    FlowerTestView()
        .frame(width: 800, height: 480)
}
