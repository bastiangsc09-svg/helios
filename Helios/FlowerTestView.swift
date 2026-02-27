import SwiftUI

// MARK: - Flower Test Harness
// Temporary view for comparing 3 eldritch flower designs side-by-side.
// Shows large (detail) and garden-scale (actual size) versions.
// Pick a winner, then FlowerRenderer integrates directly into BreakdownView.

struct FlowerTestView: View {
    @State private var utilization: Double = 70

    private let colors: [Color] = [
        Theme.pulseSession, Theme.pulseWeekly, Theme.pulseSonnet,
        Theme.pulseOpus, Theme.tierLow, Theme.sessionOrbit,
    ]

    var body: some View {
        ZStack {
            Theme.void.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Eldritch Flower Designs")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.stardust.opacity(0.8))

                    // Utilization slider
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

                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let c = Theme.pulseSession

                        // MARK: Large detail view
                        Text("Detail View")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.stardust.opacity(0.35))

                        HStack(spacing: 24) {
                            flowerPanel("A — Anemone", size: 220) { ctx, center, r in
                                FlowerRenderer.drawAnemone(ctx: &ctx, center: center, radius: r,
                                    utilization: utilization, color: c, time: t)
                            }
                            flowerPanel("B — Void Lotus", size: 220) { ctx, center, r in
                                FlowerRenderer.drawVoidLotus(ctx: &ctx, center: center, radius: r,
                                    utilization: utilization, color: c, time: t)
                            }
                            flowerPanel("C — Nebula Bloom", size: 220) { ctx, center, r in
                                FlowerRenderer.drawNebulaBloom(ctx: &ctx, center: center, radius: r,
                                    utilization: utilization, color: c, time: t)
                            }
                        }

                        // MARK: Garden scale
                        Text("Garden Scale (actual bloom size)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.stardust.opacity(0.35))
                            .padding(.top, 8)

                        HStack(spacing: 50) {
                            gardenScalePanel("A", time: t) { ctx, center, r in
                                FlowerRenderer.drawAnemone(ctx: &ctx, center: center, radius: r,
                                    utilization: utilization, color: c, time: t)
                            }
                            gardenScalePanel("B", time: t) { ctx, center, r in
                                FlowerRenderer.drawVoidLotus(ctx: &ctx, center: center, radius: r,
                                    utilization: utilization, color: c, time: t)
                            }
                            gardenScalePanel("C", time: t) { ctx, center, r in
                                FlowerRenderer.drawNebulaBloom(ctx: &ctx, center: center, radius: r,
                                    utilization: utilization, color: c, time: t)
                            }
                        }

                        // MARK: Color palette row
                        Text("Color Palette (at 75%)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.stardust.opacity(0.35))
                            .padding(.top, 8)

                        HStack(spacing: 16) {
                            ForEach(Array(colors.enumerated()), id: \.offset) { _, clr in
                                Canvas { ctx, size in
                                    let ctr = CGPoint(x: size.width / 2, y: size.height / 2)
                                    FlowerRenderer.drawAnemone(ctx: &ctx, center: ctr, radius: 22,
                                        utilization: 75, color: clr, time: t)
                                }
                                .frame(width: 70, height: 70)
                            }
                        }
                    }
                }
                .padding(30)
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 760, minHeight: 500)
    }

    // MARK: - Panel Builders

    @ViewBuilder
    private func flowerPanel(
        _ title: String,
        size: Double,
        draw: @escaping (inout GraphicsContext, CGPoint, Double) -> Void
    ) -> some View {
        VStack(spacing: 8) {
            Canvas { ctx, sz in
                let ctr = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let r = min(sz.width, sz.height) * 0.3
                draw(&ctx, ctr, r)
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
        time: Double,
        draw: @escaping (inout GraphicsContext, CGPoint, Double) -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Canvas { ctx, sz in
                let ctr = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let r = 12.0 + 20.0 * utilization / 100.0 // matches BreakdownView bloom radius
                draw(&ctx, ctr, r)
            }
            .frame(width: 90, height: 90)

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.stardust.opacity(0.5))
        }
    }
}

// MARK: - Flower Renderer
// Static draw methods — pick a winner and call from BreakdownView.

enum FlowerRenderer {

    // MARK: A — Anemone
    // Sea-anemone: many thin undulating tentacle-petals radiating from a central eye.
    // Tentacles wave with sine displacement, tips glow with bioluminescent dots.

    static func drawAnemone(
        ctx: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        utilization: Double,
        color: Color,
        time: Double
    ) {
        let u = utilization / 100.0
        let tentacleCount = 14 + Int(u * 4)

        // Background halo
        let haloR = radius * 2.5
        ctx.drawLayer { hCtx in
            hCtx.blendMode = .screen
            hCtx.fill(
                Circle().path(in: CGRect(
                    x: center.x - haloR, y: center.y - haloR,
                    width: haloR * 2, height: haloR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.12), color.opacity(0.03), .clear]),
                    center: center, startRadius: radius * 0.3, endRadius: haloR
                )
            )
        }

        // Tentacles
        let segments = 20
        for i in 0..<tentacleCount {
            let baseAngle = Double(i) * .pi * 2 / Double(tentacleCount)
            let seed = Double(i) * 2.618
            let tentacleLen = radius * (0.5 + u * 0.8)

            // Draw segment-by-segment with wave displacement
            for s in 0..<segments {
                let t0 = Double(s) / Double(segments)
                let t1 = Double(s + 1) / Double(segments)

                // Wave grows stronger toward tip
                let wave0 = sin(time * 1.2 + seed + t0 * 6) * t0 * radius * 0.15
                let wave1 = sin(time * 1.2 + seed + t1 * 6) * t1 * radius * 0.15

                let dist0 = tentacleLen * t0
                let dist1 = tentacleLen * t1
                let perpAngle = baseAngle + .pi / 2

                let pt0 = CGPoint(
                    x: center.x + cos(baseAngle) * dist0 + cos(perpAngle) * wave0,
                    y: center.y + sin(baseAngle) * dist0 + sin(perpAngle) * wave0
                )
                let pt1 = CGPoint(
                    x: center.x + cos(baseAngle) * dist1 + cos(perpAngle) * wave1,
                    y: center.y + sin(baseAngle) * dist1 + sin(perpAngle) * wave1
                )

                let width = 3.0 - 2.5 * t1
                let opacity = 0.3 + t1 * 0.3

                var seg = Path()
                seg.move(to: pt0)
                seg.addLine(to: pt1)
                ctx.stroke(seg, with: .color(color.opacity(opacity)), lineWidth: width)
            }

            // Bioluminescent tip
            let tipWave = sin(time * 1.2 + seed + 6) * radius * 0.15
            let perpAngle = baseAngle + .pi / 2
            let tipPt = CGPoint(
                x: center.x + cos(baseAngle) * tentacleLen + cos(perpAngle) * tipWave,
                y: center.y + sin(baseAngle) * tentacleLen + sin(perpAngle) * tipWave
            )
            let tipR = 4.0 + sin(time * 2.5 + seed) * 1.5
            let tipPulse = (sin(time * 3 + seed) + 1) / 2

            ctx.fill(
                Circle().path(in: CGRect(
                    x: tipPt.x - tipR * 2, y: tipPt.y - tipR * 2,
                    width: tipR * 4, height: tipR * 4
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.6 * (0.5 + tipPulse * 0.5)), .clear]),
                    center: tipPt, startRadius: 0, endRadius: tipR * 2
                )
            )
            ctx.fill(
                Circle().path(in: CGRect(
                    x: tipPt.x - tipR * 0.6, y: tipPt.y - tipR * 0.6,
                    width: tipR * 1.2, height: tipR * 1.2
                )),
                with: .color(color.opacity(0.8))
            )
        }

        drawEye(ctx: &ctx, center: center, radius: radius * 0.25,
                utilization: utilization, color: color, time: time)
    }

    // MARK: B — Void Lotus
    // 3 concentric petal layers with internal vein lines, conic gradient ring,
    // orbiting spore dots. Structured and geometric but alien.

    static func drawVoidLotus(
        ctx: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        utilization: Double,
        color: Color,
        time: Double
    ) {
        let u = utilization / 100.0
        let openness = 0.2 + u * 0.8

        // Background glow
        let haloR = radius * 2.2
        ctx.drawLayer { hCtx in
            hCtx.blendMode = .screen
            hCtx.fill(
                Circle().path(in: CGRect(
                    x: center.x - haloR, y: center.y - haloR,
                    width: haloR * 2, height: haloR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.1), color.opacity(0.02), .clear]),
                    center: center, startRadius: radius * 0.2, endRadius: haloR
                )
            )
        }

        // Spinning conic gradient ring
        let ringR = radius * (1.1 + openness * 0.3)
        ctx.drawLayer { ringCtx in
            ringCtx.blendMode = .screen
            let ringRect = CGRect(
                x: center.x - ringR, y: center.y - ringR,
                width: ringR * 2, height: ringR * 2
            )
            ringCtx.stroke(
                Circle().path(in: ringRect),
                with: .conicGradient(
                    Gradient(colors: [
                        color.opacity(0.3), .clear,
                        color.opacity(0.15), .clear,
                        color.opacity(0.25), .clear,
                    ]),
                    center: center,
                    angle: .radians(time * 0.2)
                ),
                lineWidth: 2
            )
        }

        // 3 petal layers (outer → inner)
        let layers: [(count: Int, lenMul: Double, widMul: Double, angOff: Double, op: Double)] = [
            (8, 1.0,  0.32, 0,          0.15),
            (6, 0.78, 0.35, .pi / 12,   0.22),
            (4, 0.55, 0.40, .pi / 8,    0.30),
        ]

        for (li, layer) in layers.enumerated() {
            ctx.drawLayer { pCtx in
                pCtx.blendMode = .screen
                drawLotusPetals(
                    ctx: &pCtx, center: center, radius: radius,
                    count: layer.count, lenMul: layer.lenMul, widMul: layer.widMul,
                    angOff: layer.angOff, op: layer.op, openness: openness,
                    layerIndex: li, color: color, time: time
                )
            }
        }

        // Orbiting spore dots
        for i in 0..<6 {
            let orbitAngle = Double(i) * .pi * 2 / 6.0 + time * 0.4
            let orbitR = ringR + 6 + sin(time * 0.8 + Double(i) * 1.5) * 4
            let sx = center.x + cos(orbitAngle) * orbitR
            let sy = center.y + sin(orbitAngle) * orbitR
            let sr = 2.0 + sin(time * 2 + Double(i)) * 0.5

            ctx.fill(
                Circle().path(in: CGRect(x: sx - sr, y: sy - sr, width: sr * 2, height: sr * 2)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.5), .clear]),
                    center: CGPoint(x: sx, y: sy), startRadius: 0, endRadius: sr
                )
            )
        }

        drawEye(ctx: &ctx, center: center, radius: radius * 0.2,
                utilization: utilization, color: color, time: time)
    }

    // MARK: C — Nebula Bloom
    // Fibonacci spiral of translucent cloud-ellipses. Ethereal and gaseous,
    // with connecting filaments and sparkle dots. Dreamlike.

    static func drawNebulaBloom(
        ctx: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        utilization: Double,
        color: Color,
        time: Double
    ) {
        let u = utilization / 100.0
        let petalCount = 13 + Int(u * 8)
        let goldenAngle = 137.508 * .pi / 180

        // Background halo
        let haloR = radius * 2.8
        ctx.drawLayer { hCtx in
            hCtx.blendMode = .screen
            hCtx.fill(
                Circle().path(in: CGRect(
                    x: center.x - haloR, y: center.y - haloR,
                    width: haloR * 2, height: haloR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.08), color.opacity(0.02), .clear]),
                    center: center, startRadius: radius * 0.2, endRadius: haloR
                )
            )
        }

        // Fibonacci spiral cloud-petals
        ctx.drawLayer { pCtx in
            pCtx.blendMode = .screen

            for i in 0..<petalCount {
                let angle = Double(i) * goldenAngle + time * 0.05
                let distFrac = Double(i) / Double(petalCount)
                let dist = radius * 0.15 + distFrac * radius * 0.85
                let px = center.x + cos(angle) * dist
                let py = center.y + sin(angle) * dist

                let breathe = sin(time * 0.6 + Double(i) * 0.8) * 0.1
                let baseSize = radius * (0.15 + distFrac * 0.2) * (0.7 + u * 0.3)
                let petalW = baseSize * (1 + breathe)
                let petalH = baseSize * (0.7 + breathe * 0.5)

                pCtx.drawLayer { eCtx in
                    let rotation = angle + sin(time * 0.3 + Double(i)) * 0.3
                    let ellipseRect = CGRect(
                        x: -petalW, y: -petalH,
                        width: petalW * 2, height: petalH * 2
                    )

                    eCtx.translateBy(x: px, y: py)
                    eCtx.rotate(by: .radians(rotation))

                    let opacity = (1.0 - distFrac * 0.6) * (0.15 + u * 0.1)
                    eCtx.fill(
                        Ellipse().path(in: ellipseRect),
                        with: .radialGradient(
                            Gradient(colors: [
                                color.opacity(opacity),
                                color.opacity(opacity * 0.3),
                                .clear,
                            ]),
                            center: .zero, startRadius: 0, endRadius: petalW
                        )
                    )
                }
            }
        }

        // Connecting filaments
        ctx.drawLayer { fCtx in
            fCtx.blendMode = .screen
            for i in 1..<min(petalCount, 10) {
                let a0 = Double(i - 1) * goldenAngle + time * 0.05
                let a1 = Double(i) * goldenAngle + time * 0.05
                let d0 = radius * 0.15 + Double(i - 1) / Double(petalCount) * radius * 0.85
                let d1 = radius * 0.15 + Double(i) / Double(petalCount) * radius * 0.85

                let p0 = CGPoint(x: center.x + cos(a0) * d0, y: center.y + sin(a0) * d0)
                let p1 = CGPoint(x: center.x + cos(a1) * d1, y: center.y + sin(a1) * d1)

                var fil = Path()
                fil.move(to: p0)
                fil.addLine(to: p1)
                fCtx.stroke(fil, with: .color(color.opacity(0.08)), lineWidth: 0.5)
            }
        }

        // Sparkle dots
        for i in stride(from: 0, to: petalCount, by: 3) {
            let angle = Double(i) * goldenAngle + time * 0.05
            let dist = radius * 0.15 + Double(i) / Double(petalCount) * radius * 0.85
            let sx = center.x + cos(angle) * dist
            let sy = center.y + sin(angle) * dist
            let sparkle = (sin(time * 2 + Double(i) * 1.3) + 1) / 2
            let sr = 1.5 + sparkle * 1.5

            ctx.fill(
                Circle().path(in: CGRect(
                    x: sx - sr * 2, y: sy - sr * 2,
                    width: sr * 4, height: sr * 4
                )),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.4 * sparkle), .clear]),
                    center: CGPoint(x: sx, y: sy), startRadius: 0, endRadius: sr * 2
                )
            )
        }

        // Bright core
        let coreR = radius * 0.2
        ctx.drawLayer { cCtx in
            cCtx.blendMode = .plusLighter
            cCtx.fill(
                Circle().path(in: CGRect(
                    x: center.x - coreR, y: center.y - coreR,
                    width: coreR * 2, height: coreR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.4), color.opacity(0.1), .clear]),
                    center: center, startRadius: 0, endRadius: coreR
                )
            )
        }

        drawEye(ctx: &ctx, center: center, radius: radius * 0.18,
                utilization: utilization, color: color, time: time)
    }

    // MARK: Helper — Lotus Petals (extracted for type-checker)

    private static func drawLotusPetals(
        ctx: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        count: Int,
        lenMul: Double,
        widMul: Double,
        angOff: Double,
        op: Double,
        openness: Double,
        layerIndex: Int,
        color: Color,
        time: Double
    ) {
        for i in 0..<count {
            let baseAngle = Double(i) * .pi * 2 / Double(count) + angOff
            let breathe = sin(time * 0.3 + Double(layerIndex) * 0.8 + Double(i) * 0.4) * 0.04
            let angle = baseAngle + breathe
            let length = radius * lenMul * (0.4 + openness * 0.6)
            let width = radius * widMul * openness

            let tip = CGPoint(
                x: center.x + cos(angle) * length,
                y: center.y + sin(angle) * length
            )
            let perp = angle + .pi / 2
            let cpL = CGPoint(
                x: center.x + cos(angle) * length * 0.5 + cos(perp) * width,
                y: center.y + sin(angle) * length * 0.5 + sin(perp) * width
            )
            let cpR = CGPoint(
                x: center.x + cos(angle) * length * 0.5 - cos(perp) * width,
                y: center.y + sin(angle) * length * 0.5 - sin(perp) * width
            )

            var petal = Path()
            petal.move(to: center)
            petal.addQuadCurve(to: tip, control: cpL)
            petal.addQuadCurve(to: center, control: cpR)
            petal.closeSubpath()

            let grad = Gradient(colors: [
                color.opacity(op * 0.5),
                color.opacity(op),
                color.opacity(op * 0.2),
            ])
            ctx.fill(petal, with: .radialGradient(grad, center: center, startRadius: 0, endRadius: length))

            // Vein lines
            for v in 0..<2 {
                let vOff = (Double(v) - 0.5) * width * 0.4
                let vEnd = CGPoint(
                    x: center.x + cos(angle) * length * 0.85 + cos(perp) * vOff,
                    y: center.y + sin(angle) * length * 0.85 + sin(perp) * vOff
                )
                let vCtrl = CGPoint(
                    x: center.x + cos(angle) * length * 0.4 + cos(perp) * vOff * 1.5,
                    y: center.y + sin(angle) * length * 0.4 + sin(perp) * vOff * 1.5
                )
                var vein = Path()
                vein.move(to: center)
                vein.addQuadCurve(to: vEnd, control: vCtrl)
                ctx.stroke(vein, with: .color(color.opacity(op * 0.6)), lineWidth: 0.5)
            }
        }
    }

    // MARK: Shared — Eye Orb

    static func drawEye(
        ctx: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        utilization: Double,
        color: Color,
        time: Double
    ) {
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
                Gradient(colors: [color.opacity(0.25 * (0.5 + pulse * 0.5)), .clear]),
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
                    color.opacity(0.8),
                    color.opacity(0.3),
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
                Gradient(colors: [.white.opacity(0.7), .clear]),
                center: CGPoint(x: specX, y: specY), startRadius: 0, endRadius: specR
            )
        )

        // Percentage text
        let pctText = ctx.resolve(
            Text("\(Int(utilization))%")
                .font(.system(size: max(8, radius * 0.7), weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        )
        ctx.draw(pctText, at: center, anchor: .center)
    }
}

#Preview {
    FlowerTestView()
        .frame(width: 800, height: 550)
}
