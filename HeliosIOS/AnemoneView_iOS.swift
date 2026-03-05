import SwiftUI

// MARK: - Hit Cache (class to avoid @State re-renders each frame)

private final class HitCache {
    struct Target {
        let label: String
        let pct: Double
        let reset: String
        let position: CGPoint
        let id: String
        let radius: Double
    }
    var tips: [Target] = []
    var midpoints: [Target] = []
}

// MARK: - Tentacle Descriptor

private struct TentacleDesc {
    let label: String
    let id: String
    let angle: Double       // radians, -pi/2 = up
    let pct: Double
    let reset: String
    let tipColor: Color
    let midColor: Color
    let baseColor: Color
}

// MARK: - Spore (floating light orb)

private struct Spore {
    let baseX: Double
    let seed: Double
    let cycleSpeed: Double
}

// MARK: - Anemone View

struct AnemoneView_iOS: View {
    let state: UsageState
    @State private var tapped: HitCache.Target?
    @State private var expanded = false
    @State private var showStats = false
    @State private var spores: [Spore] = (0..<25).map { i in
        let seed = Double(i) * 137.508
        return Spore(
            baseX: fmod(seed * 23.1, 1.0),
            seed: seed,
            cycleSpeed: 0.012 + fmod(seed, 0.02)
        )
    }

    private let hitCache = HitCache()

    var body: some View {
        GeometryReader { geo in
            let readoutSpace: CGFloat = 100
            let orreryHeight = geo.size.height - readoutSpace
            let maxR = min(geo.size.width, orreryHeight) * 0.34

            ZStack {
                // 1. Anemone canvas (spores + organism)
                ZStack {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let center = CGPoint(x: geo.size.width / 2, y: orreryHeight / 2)

                        Canvas { ctx, size in
                            drawSpores(ctx: &ctx, size: size, time: t)
                            drawAnemone(
                                ctx: &ctx, center: center, maxR: maxR,
                                time: t
                            )
                        }
                        .frame(height: orreryHeight)
                    }
                    .allowsHitTesting(false)

                    // 3. Tap detection
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(height: orreryHeight)
                        .onTapGesture { location in
                            handleTap(at: location)
                        }

                    // 5. Tooltip
                    if let t = tapped {
                        tooltipView(for: t)
                            .position(t.position)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: orreryHeight)
                .frame(maxHeight: .infinity, alignment: .top)

                // 6. Readout bar
                VStack {
                    Spacer()
                    readoutBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                // Loading / error overlays
                if state.isLoading && state.usage == nil {
                    ProgressView().tint(.white)
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

    // MARK: - Tentacle Descriptors

    private var tentacles: [TentacleDesc] {
        [
            TentacleDesc(
                label: "Hourly (5h)", id: "hourly",
                angle: -.pi / 2,            // up
                pct: state.fiveHourPct,
                reset: state.fiveHourResetString,
                tipColor: Theme.sessionOrbit,
                midColor: Theme.tentacleCyanMid,
                baseColor: Theme.tentacleCyanBase
            ),
            TentacleDesc(
                label: "Sonnet", id: "sonnet",
                angle: -.pi / 2 + 2 * .pi / 3,   // +120° → lower-right
                pct: state.sonnetPct,
                reset: "",
                tipColor: Theme.outerOrbit,
                midColor: Theme.tentacleGoldMid,
                baseColor: Theme.tentacleGoldBase
            ),
            TentacleDesc(
                label: "Weekly (7d)", id: "weekly",
                angle: -.pi / 2 + 4 * .pi / 3,   // +240° → lower-left
                pct: state.sevenDayPct,
                reset: state.sevenDayResetString,
                tipColor: Theme.weeklyOrbit,
                midColor: Theme.tentacleLavenderMid,
                baseColor: Theme.tentacleLavenderBase
            ),
        ]
    }

    // MARK: - Canvas Drawing

    private func drawAnemone(
        ctx: inout GraphicsContext, center: CGPoint, maxR: Double, time: Double
    ) {
        let activity = state.overallUtilization / 100.0

        // Pass 1: Ambient halo
        drawHalo(ctx: &ctx, center: center, maxR: maxR, activity: activity, time: time)

        // Pass 2: Collar ring
        drawCollar(ctx: &ctx, center: center, maxR: maxR, time: time)

        // Accumulate spine arrays for webbing
        var allSpines: [[CGPoint]] = []

        // Clear hit cache for this frame
        hitCache.tips.removeAll()
        hitCache.midpoints.removeAll()

        // Pass 3: Tentacles
        for desc in tentacles {
            let spine = drawTentacle(
                ctx: &ctx, center: center, maxR: maxR,
                desc: desc, time: time
            )
            allSpines.append(spine)
        }

        // Pass 4: Membrane webbing
        drawWebbing(ctx: &ctx, spines: allSpines, time: time)

        // Pass 5: Iris (on top)
        drawIris(ctx: &ctx, center: center, maxR: maxR, activity: activity, time: time)
    }

    // MARK: - Pass 1: Ambient Halo

    private func drawHalo(
        ctx: inout GraphicsContext, center: CGPoint,
        maxR: Double, activity: Double, time: Double
    ) {
        let haloR = maxR * 3.0
        let intensity = 0.06 + activity * 0.10
        let irisColor = irisBaseColor(activity: activity)
        ctx.drawLayer { hCtx in
            hCtx.blendMode = .screen
            hCtx.fill(
                Circle().path(in: CGRect(
                    x: center.x - haloR, y: center.y - haloR,
                    width: haloR * 2, height: haloR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        irisColor.opacity(intensity),
                        Theme.nucleusCool.opacity(intensity * 0.5),
                        Theme.nucleusCool.opacity(intensity * 0.2),
                        .clear
                    ]),
                    center: center, startRadius: maxR * 0.1, endRadius: haloR
                )
            )
        }
    }

    // MARK: - Iris Base Color

    /// Lerp from white (calm) → teal (moderate) → gold (critical) based on utilization
    private func irisBaseColor(activity: Double) -> Color {
        if activity < 0.5 {
            return Color.lerp(Theme.stardust, Theme.sessionOrbit, t: activity * 2)
        } else {
            return Color.lerp(Theme.sessionOrbit, Theme.outerOrbit, t: (activity - 0.5) * 2)
        }
    }

    // MARK: - Pass 5: Iris

    private func drawIris(
        ctx: inout GraphicsContext, center: CGPoint,
        maxR: Double, activity: Double, time: Double
    ) {
        let irisR = maxR * 0.34
        let pupilR = irisR * (0.28 + activity * 0.12)  // dilates with usage
        let collaretteR = irisR * 0.48                  // jagged boundary ~1/3 out
        let limbalR = irisR * 0.96                      // dark outer ring
        let fiberCount = 80                              // radial muscle fibers
        let pulse = (sin(time * (0.8 + activity * 0.6)) + 1) / 2

        // Usage-driven colors: inner zone warm, outer zone cool
        // Map the 3 tentacle colors into iris zones
        let innerColor = Theme.outerOrbit        // gold/amber (inner stroma)
        let outerColor = Theme.sessionOrbit       // cyan/teal (outer stroma)
        let accentColor = Theme.weeklyOrbit       // lavender (crypts)

        let irisRect = CGRect(
            x: center.x - irisR, y: center.y - irisR,
            width: irisR * 2, height: irisR * 2
        )

        // ── Layer 1: Dark base fill (the "sclera" behind the iris) ──
        ctx.fill(
            Circle().path(in: irisRect),
            with: .color(Color(hex: "040608"))
        )

        // ── Layer 2: Limbal ring (dark outer border) ──
        ctx.drawLayer { lCtx in
            lCtx.fill(
                Circle().path(in: irisRect),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.85),
                        .init(color: Color(hex: "0A1520").opacity(0.9), location: 0.92),
                        .init(color: Color(hex: "060D14"), location: 1.0),
                    ]),
                    center: center, startRadius: 0, endRadius: irisR
                )
            )
        }

        // ── Layer 3: Base stroma color (two-zone radial: gold inner, teal outer) ──
        ctx.drawLayer { sCtx in
            sCtx.blendMode = .screen
            sCtx.fill(
                Circle().path(in: irisRect),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: pupilR / irisR),
                        .init(color: innerColor.opacity(0.25), location: pupilR / irisR + 0.03),
                        .init(color: innerColor.opacity(0.45), location: collaretteR / irisR - 0.05),
                        .init(color: innerColor.opacity(0.35), location: collaretteR / irisR),
                        .init(color: outerColor.opacity(0.30), location: collaretteR / irisR + 0.05),
                        .init(color: outerColor.opacity(0.45), location: 0.75),
                        .init(color: outerColor.opacity(0.25), location: limbalR / irisR),
                        .init(color: .clear, location: 1.0),
                    ]),
                    center: center, startRadius: 0, endRadius: irisR
                )
            )
        }

        // ── Layer 4: Radial muscle fibers (the defining texture of an iris) ──
        ctx.drawLayer { fCtx in
            fCtx.blendMode = .screen

            for i in 0..<fiberCount {
                let fi = Double(i)
                let seed = fi * 137.508  // golden angle distribution
                let baseAngle = fi * .pi * 2.0 / Double(fiberCount)

                // Gentle organic wobble per fiber
                let wobble = sin(seed * 3.7 + time * 0.08) * 0.04
                    + sin(seed * 7.1) * 0.02
                let angle = baseAngle + wobble

                // Fiber starts just outside pupil, ends near limbus
                let startR = pupilR + irisR * 0.02
                let endR = limbalR - irisR * 0.01 + sin(seed * 2.3) * irisR * 0.03

                // Control point for slight curve (fibers aren't perfectly straight)
                let midR = (startR + endR) / 2
                let curveBias = sin(seed * 5.1 + time * 0.05) * irisR * 0.04
                let perpAngle = angle + .pi / 2

                let startPt = CGPoint(
                    x: center.x + cos(angle) * startR,
                    y: center.y + sin(angle) * startR
                )
                let endPt = CGPoint(
                    x: center.x + cos(angle) * endR,
                    y: center.y + sin(angle) * endR
                )
                let ctrlPt = CGPoint(
                    x: center.x + cos(angle) * midR + cos(perpAngle) * curveBias,
                    y: center.y + sin(angle) * midR + sin(perpAngle) * curveBias
                )

                var fiber = Path()
                fiber.move(to: startPt)
                fiber.addQuadCurve(to: endPt, control: ctrlPt)

                // Fiber color: gold near pupil, transitions to teal past collarette
                // Each fiber has slight unique brightness variation
                let brightVar = 0.7 + sin(seed * 1.9) * 0.3
                let fiberPulse = (sin(time * 0.5 + seed * 0.3) + 1) / 2

                // Width tapers: thicker near pupil, thinner at edge
                let width = 1.2 + sin(seed * 4.3) * 0.4

                // Inner fibers (pupil → collarette): warm gold
                // Outer fibers drawn on top with teal
                let opacity = (0.15 + fiberPulse * 0.08) * brightVar

                // Draw inner portion (gold)
                fCtx.stroke(fiber, with: .color(innerColor.opacity(opacity)), lineWidth: width)
            }
        }

        // ── Layer 5: Outer fiber overlay (teal fibers from collarette outward) ──
        ctx.drawLayer { oCtx in
            oCtx.blendMode = .screen

            for i in 0..<fiberCount {
                let fi = Double(i)
                let seed = fi * 137.508
                let baseAngle = fi * .pi * 2.0 / Double(fiberCount)
                let wobble = sin(seed * 3.7 + time * 0.08) * 0.04 + sin(seed * 7.1) * 0.02
                let angle = baseAngle + wobble

                let startR = collaretteR - irisR * 0.02
                let endR = limbalR - irisR * 0.02 + sin(seed * 2.3) * irisR * 0.02
                let midR = (startR + endR) / 2
                let curveBias = sin(seed * 5.1 + time * 0.05) * irisR * 0.05
                let perpAngle = angle + .pi / 2

                let startPt = CGPoint(
                    x: center.x + cos(angle) * startR,
                    y: center.y + sin(angle) * startR
                )
                let endPt = CGPoint(
                    x: center.x + cos(angle) * endR,
                    y: center.y + sin(angle) * endR
                )
                let ctrlPt = CGPoint(
                    x: center.x + cos(angle) * midR + cos(perpAngle) * curveBias,
                    y: center.y + sin(angle) * midR + sin(perpAngle) * curveBias
                )

                var fiber = Path()
                fiber.move(to: startPt)
                fiber.addQuadCurve(to: endPt, control: ctrlPt)

                let brightVar = 0.6 + sin(seed * 2.7) * 0.4
                let fiberPulse = (sin(time * 0.4 + seed * 0.5) + 1) / 2
                let width = 1.0 + sin(seed * 3.1) * 0.3
                let opacity = (0.12 + fiberPulse * 0.06) * brightVar

                oCtx.stroke(fiber, with: .color(outerColor.opacity(opacity)), lineWidth: width)
            }
        }

        // ── Layer 6: Collarette ring (the jagged boundary between inner/outer stroma) ──
        ctx.drawLayer { cCtx in
            cCtx.blendMode = .screen
            let segments = 48
            var collarPath = Path()
            for i in 0...segments {
                let t = Double(i) / Double(segments)
                let angle = t * .pi * 2
                // Jagged edge — crypts and furrows
                let jag = sin(angle * 12 + time * 0.1) * irisR * 0.015
                    + sin(angle * 7 + 1.5) * irisR * 0.01
                    + sin(angle * 19 + 0.7) * irisR * 0.006
                let r = collaretteR + jag
                let pt = CGPoint(
                    x: center.x + cos(angle) * r,
                    y: center.y + sin(angle) * r
                )
                if i == 0 { collarPath.move(to: pt) }
                else { collarPath.addLine(to: pt) }
            }
            collarPath.closeSubpath()
            cCtx.stroke(collarPath, with: .color(innerColor.opacity(0.35)), lineWidth: 1.8)
            // Soft glow around collarette
            cCtx.stroke(collarPath, with: .color(innerColor.opacity(0.10)), lineWidth: 5.0)
        }

        // ── Layer 7: Crypts (darker spots scattered through stroma) ──
        ctx.drawLayer { crCtx in
            crCtx.blendMode = .multiply
            let cryptCount = 20
            for i in 0..<cryptCount {
                let seed = Double(i) * 97.3
                let angle = seed * 0.618 * .pi * 2
                let rNorm = 0.35 + fmod(seed * 0.37, 0.45)
                let r = irisR * rNorm
                let cx = center.x + cos(angle) * r
                let cy = center.y + sin(angle) * r
                let cryptR = irisR * (0.015 + sin(seed * 3.1) * 0.008)
                let cryptOp = 0.3 + sin(seed * 2.7) * 0.15

                crCtx.fill(
                    Circle().path(in: CGRect(
                        x: cx - cryptR, y: cy - cryptR,
                        width: cryptR * 2, height: cryptR * 2
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            accentColor.opacity(cryptOp * 0.2),
                            Color(hex: "0A0E14").opacity(cryptOp),
                            .clear
                        ]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0, endRadius: cryptR
                    )
                )
            }
        }

        // ── Layer 8: Pupil (deep black with soft irregular edge) ──
        ctx.drawLayer { pCtx in
            // Irregular pupil border via polygon
            let pupilSegs = 36
            var pupilPath = Path()
            for i in 0...pupilSegs {
                let t = Double(i) / Double(pupilSegs)
                let angle = t * .pi * 2
                let irregularity = sin(angle * 8 + time * 0.15) * pupilR * 0.03
                    + sin(angle * 13) * pupilR * 0.02
                let r = pupilR + irregularity
                let pt = CGPoint(
                    x: center.x + cos(angle) * r,
                    y: center.y + sin(angle) * r
                )
                if i == 0 { pupilPath.move(to: pt) }
                else { pupilPath.addLine(to: pt) }
            }
            pupilPath.closeSubpath()

            pCtx.fill(pupilPath, with: .color(Color(hex: "010102")))

            // Soft pupil edge glow (fibers meeting the pupil)
            pCtx.drawLayer { peCtx in
                peCtx.blendMode = .screen
                peCtx.fill(
                    Circle().path(in: CGRect(
                        x: center.x - pupilR * 1.15, y: center.y - pupilR * 1.15,
                        width: pupilR * 2.3, height: pupilR * 2.3
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            .clear,
                            innerColor.opacity(0.15),
                            innerColor.opacity(0.08),
                            .clear
                        ]),
                        center: center, startRadius: pupilR * 0.85, endRadius: pupilR * 1.2
                    )
                )
            }
        }

        // ── Layer 9: Ambient glow (extends beyond iris) ──
        let glowR = irisR * 1.6
        ctx.drawLayer { gCtx in
            gCtx.blendMode = .screen
            gCtx.fill(
                Circle().path(in: CGRect(
                    x: center.x - glowR, y: center.y - glowR,
                    width: glowR * 2, height: glowR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        outerColor.opacity(0.10 * (0.6 + pulse * 0.4)),
                        outerColor.opacity(0.03),
                        .clear
                    ]),
                    center: center, startRadius: irisR * 0.5, endRadius: glowR
                )
            )
        }

        // ── Layer 10: High-usage pulse ──
        let maxPct = max(state.fiveHourPct, state.sonnetPct, state.sevenDayPct)
        if maxPct > 80 {
            let urgency = (maxPct - 80) / 20.0
            let errPulse = (sin(time * 3.5) + 1) / 2
            ctx.drawLayer { eCtx in
                eCtx.blendMode = .plusLighter
                eCtx.fill(
                    Circle().path(in: irisRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Theme.nucleusHot.opacity(0.12 * errPulse * urgency),
                            .clear
                        ]),
                        center: center, startRadius: 0, endRadius: pupilR * 1.5
                    )
                )
            }
        }

        // ── Layer 11: Specular highlights ──
        let specX = center.x - irisR * 0.22
        let specY = center.y - irisR * 0.22
        let specR = irisR * 0.10
        ctx.fill(
            Circle().path(in: CGRect(
                x: specX - specR, y: specY - specR,
                width: specR * 2, height: specR * 2
            )),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.5), .white.opacity(0.08), .clear]),
                center: CGPoint(x: specX, y: specY), startRadius: 0, endRadius: specR
            )
        )
        let spec2X = center.x + irisR * 0.15
        let spec2Y = center.y + irisR * 0.10
        let spec2R = irisR * 0.05
        ctx.fill(
            Circle().path(in: CGRect(
                x: spec2X - spec2R, y: spec2Y - spec2R,
                width: spec2R * 2, height: spec2R * 2
            )),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.25), .clear]),
                center: CGPoint(x: spec2X, y: spec2Y), startRadius: 0, endRadius: spec2R
            )
        )
    }

    // MARK: - Pass 2: Collar Ring

    private func drawCollar(
        ctx: inout GraphicsContext, center: CGPoint,
        maxR: Double, time: Double
    ) {
        let collarR = maxR * 0.37
        let pulse = (sin(time * 1.2) + 1) / 2
        let activity = state.overallUtilization / 100.0
        let collarColor = irisBaseColor(activity: activity)

        ctx.drawLayer { cCtx in
            cCtx.blendMode = .screen

            let ringRect = CGRect(
                x: center.x - collarR, y: center.y - collarR,
                width: collarR * 2, height: collarR * 2
            )
            cCtx.stroke(
                Circle().path(in: ringRect),
                with: .color(collarColor.opacity(0.15 + pulse * 0.08)),
                lineWidth: 2.5
            )

            let bloomR = collarR * 1.3
            cCtx.fill(
                Circle().path(in: CGRect(
                    x: center.x - bloomR, y: center.y - bloomR,
                    width: bloomR * 2, height: bloomR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        .clear,
                        collarColor.opacity(0.06),
                        collarColor.opacity(0.03),
                        .clear
                    ]),
                    center: center,
                    startRadius: collarR * 0.85,
                    endRadius: bloomR
                )
            )
        }
    }

    // MARK: - Tentacle

    private func drawTentacle(
        ctx: inout GraphicsContext, center: CGPoint, maxR: Double,
        desc: TentacleDesc, time: Double
    ) -> [CGPoint] {
        let pct = desc.pct
        let norm = pct / 100.0
        let collarR = maxR * 0.37
        let tentacleLen = maxR * (0.15 + norm * 0.85)
        let waveSpeed = 0.5 + norm * 1.5
        let angle = desc.angle
        let segments = 20
        let perp = angle + .pi / 2
        let perpX = cos(perp)
        let perpY = sin(perp)
        let seed = Double(desc.id.hashValue & 0xFFFF) * 0.001

        // 4a: Compute 20 spine points with 3-harmonic wave sway
        var points: [CGPoint] = []
        for s in 0...segments {
            let t = Double(s) / Double(segments)
            let wave = sin(time * waveSpeed + seed + t * 6) * t * maxR * 0.12
                + sin(time * waveSpeed * 1.7 + seed + t * 4) * t * maxR * 0.04
                + sin(time * waveSpeed * 0.6 + seed * 2.3 + t * 9) * t * maxR * 0.02
            let px = center.x + cos(angle) * (collarR + tentacleLen * t) + perpX * wave
            let py = center.y + sin(angle) * (collarR + tentacleLen * t) + perpY * wave
            points.append(CGPoint(x: px, y: py))
        }

        // Pre-compute double-helix positions
        let helixFreq = 8.0
        var strandA: [CGPoint] = []
        var strandB: [CGPoint] = []
        for s in 0...segments {
            let t = Double(s) / Double(segments)
            let helixPhase = sin(t * helixFreq + time * waveSpeed * 0.5 + seed)
            let amp = (3.0 - t * 2.0) * (1.0 + norm * 0.5)
            strandA.append(CGPoint(
                x: points[s].x + perpX * amp * helixPhase,
                y: points[s].y + perpY * amp * helixPhase
            ))
            strandB.append(CGPoint(
                x: points[s].x - perpX * amp * helixPhase,
                y: points[s].y - perpY * amp * helixPhase
            ))
        }

        // 4b: Soft glow bloom along spine
        ctx.drawLayer { gCtx in
            gCtx.blendMode = .screen
            var glowPath = Path()
            glowPath.move(to: points[0])
            for s in 1...segments { glowPath.addLine(to: points[s]) }
            gCtx.stroke(glowPath, with: .color(desc.tipColor.opacity(0.08)), lineWidth: 14)
        }

        // 4c: Double-helix DNA strands with 3-zone color gradient
        for s in 0..<segments {
            let t1 = Double(s + 1) / Double(segments)
            let tMid = (Double(s) + 0.5) / Double(segments)

            let strandColor: Color
            let strandOp: Double
            if tMid < 0.3 {
                strandColor = desc.baseColor
                strandOp = 0.25 + tMid * 1.5
            } else if tMid < 0.7 {
                strandColor = desc.midColor
                strandOp = 0.4 + tMid * 0.4
            } else {
                strandColor = desc.tipColor
                strandOp = 0.5 + tMid * 0.3
            }

            let taper = 2.5 - 2.0 * t1
            let undulation = 1.0 + sin(time * 1.5 + seed + tMid * 12) * 0.15
            let strandWidth = taper * undulation

            // Strand A
            var segA = Path()
            segA.move(to: strandA[s])
            segA.addQuadCurve(
                to: strandA[s + 1],
                control: CGPoint(
                    x: (strandA[s].x + strandA[s + 1].x) / 2 + sin(seed + tMid * 8) * 1.0,
                    y: (strandA[s].y + strandA[s + 1].y) / 2 + cos(seed + tMid * 8) * 1.0
                )
            )
            ctx.stroke(segA, with: .color(strandColor.opacity(strandOp)), lineWidth: strandWidth)

            // Strand B (dimmer/thinner)
            var segB = Path()
            segB.move(to: strandB[s])
            segB.addQuadCurve(
                to: strandB[s + 1],
                control: CGPoint(
                    x: (strandB[s].x + strandB[s + 1].x) / 2 + sin(seed + tMid * 8 + 2) * 1.0,
                    y: (strandB[s].y + strandB[s + 1].y) / 2 + cos(seed + tMid * 8 + 2) * 1.0
                )
            )
            ctx.stroke(segB, with: .color(strandColor.opacity(strandOp * 0.7)), lineWidth: strandWidth * 0.8)
        }

        // 4d: Inner glow channel
        ctx.drawLayer { iCtx in
            iCtx.blendMode = .plusLighter
            var innerPath = Path()
            innerPath.move(to: points[0])
            for s in 1...segments { innerPath.addLine(to: points[s]) }
            iCtx.stroke(innerPath, with: .color(desc.tipColor.opacity(0.08)), lineWidth: 2.5)
            iCtx.stroke(innerPath, with: .color(.white.opacity(0.10)), lineWidth: 0.8)
        }

        // 4e: Photophore nodes at segments 4, 8, 12, 16
        let nodeInterval = 4
        for s in stride(from: nodeInterval, through: segments - 2, by: nodeInterval) {
            let t = Double(s) / Double(segments)
            let nodePulse = (sin(time * (2.0 + Double(s) * 0.3) + seed * Double(s)) + 1) / 2
            let nodeR = 2.0 + nodePulse * 1.5 + norm * 1.0
            let nColor: Color = t < 0.5 ? desc.midColor : desc.tipColor

            ctx.fill(
                Circle().path(in: CGRect(
                    x: points[s].x - nodeR * 2.5, y: points[s].y - nodeR * 2.5,
                    width: nodeR * 5, height: nodeR * 5
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        nColor.opacity(0.3 * (0.5 + nodePulse * 0.5)),
                        nColor.opacity(0.05),
                        .clear
                    ]),
                    center: points[s], startRadius: 0, endRadius: nodeR * 2.5
                )
            )
            ctx.fill(
                Circle().path(in: CGRect(
                    x: points[s].x - nodeR, y: points[s].y - nodeR,
                    width: nodeR * 2, height: nodeR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        .white.opacity(0.5 * nodePulse),
                        nColor.opacity(0.4),
                        .clear
                    ]),
                    center: points[s], startRadius: 0, endRadius: nodeR
                )
            )

            // Store mid-point hit targets
            hitCache.midpoints.append(HitCache.Target(
                label: desc.label, pct: desc.pct, reset: desc.reset,
                position: points[s], id: desc.id, radius: 24
            ))
        }

        // 4f: Branching filaments (2-3 short offshoots)
        let filamentCount = 2 + (norm > 0.5 ? 1 : 0)
        for f in 0..<filamentCount {
            let branchT = 0.15 + Double(f) * 0.2
            let branchIdx = min(Int(branchT * Double(segments)), segments)
            let attachPt = points[branchIdx]
            let side: Double = f % 2 == 0 ? 1 : -1
            let filLen = tentacleLen * 0.12 + sin(time * 0.7 + seed + Double(f)) * 3
            let filAngle = angle + side * (0.4 + sin(time * 0.3 + Double(f)) * 0.15)
            let filEnd = CGPoint(
                x: attachPt.x + cos(filAngle) * filLen,
                y: attachPt.y + sin(filAngle) * filLen
            )
            let filCtrl = CGPoint(
                x: (attachPt.x + filEnd.x) / 2 + side * 5,
                y: (attachPt.y + filEnd.y) / 2 - 3
            )
            var filPath = Path()
            filPath.move(to: attachPt)
            filPath.addQuadCurve(to: filEnd, control: filCtrl)
            ctx.stroke(filPath, with: .color(desc.tipColor.opacity(0.2)), lineWidth: 1)

            let ftR = 2.0 + sin(time * 2 + Double(f) * 1.5) * 0.5
            ctx.fill(
                Circle().path(in: CGRect(
                    x: filEnd.x - ftR, y: filEnd.y - ftR,
                    width: ftR * 2, height: ftR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [desc.tipColor.opacity(0.3), .clear]),
                    center: filEnd, startRadius: 0, endRadius: ftR
                )
            )
        }

        // 4g: Bulbous tip (3-layer)
        let tipPt = points[segments]
        let tipR = 3.0 + norm * 8.0
        let tipPulse = (sin(time * (2.0 + norm * 2.0) + seed) + 1) / 2

        // Layer 1: Wide bloom
        let bloomR = tipR * 3.5
        ctx.fill(
            Circle().path(in: CGRect(
                x: tipPt.x - bloomR, y: tipPt.y - bloomR,
                width: bloomR * 2, height: bloomR * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    desc.tipColor.opacity(0.35 * (0.5 + tipPulse * 0.5)),
                    desc.tipColor.opacity(0.1),
                    .clear
                ]),
                center: tipPt, startRadius: 0, endRadius: bloomR
            )
        )

        // Layer 2: Inner bulb
        let bulbR = tipR * 1.5
        ctx.fill(
            Circle().path(in: CGRect(
                x: tipPt.x - bulbR, y: tipPt.y - bulbR,
                width: bulbR * 2, height: bulbR * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    desc.tipColor.opacity(0.9),
                    desc.tipColor.opacity(0.5),
                    .clear
                ]),
                center: tipPt, startRadius: 0, endRadius: bulbR
            )
        )

        // Layer 3: Core spark (white-hot)
        let sparkR = tipR * 0.5
        ctx.fill(
            Circle().path(in: CGRect(
                x: tipPt.x - sparkR, y: tipPt.y - sparkR,
                width: sparkR * 2, height: sparkR * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    .white.opacity(0.85 * (0.6 + tipPulse * 0.4)),
                    desc.tipColor.opacity(0.7),
                    .clear
                ]),
                center: tipPt, startRadius: 0, endRadius: sparkR
            )
        )

        // 4h: Trailing wisps
        for trail in 1...3 {
            let wispIdx = max(segments - trail, 0)
            let wispPt = points[wispIdx]
            let wR = tipR * (0.5 - Double(trail) * 0.1)
            let wOp = 0.4 - Double(trail) * 0.1
            ctx.fill(
                Circle().path(in: CGRect(
                    x: wispPt.x - wR, y: wispPt.y - wR,
                    width: wR * 2, height: wR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [desc.tipColor.opacity(wOp), .clear]),
                    center: wispPt, startRadius: 0, endRadius: wR
                )
            )
        }

        // Store tip hit target
        hitCache.tips.append(HitCache.Target(
            label: desc.label, pct: desc.pct, reset: desc.reset,
            position: tipPt, id: desc.id, radius: 48
        ))

        return points
    }

    // MARK: - Membrane Webbing

    private func drawWebbing(
        ctx: inout GraphicsContext, spines: [[CGPoint]], time: Double
    ) {
        guard spines.count >= 2 else { return }

        ctx.drawLayer { wCtx in
            wCtx.blendMode = .screen
            for i in 0..<spines.count {
                let spineA = spines[i]
                let spineB = spines[(i + 1) % spines.count]
                let webLen = min(spineA.count, spineB.count, 8)
                guard webLen >= 2 else { continue }

                var webPath = Path()
                webPath.move(to: spineA[0])
                for s in 1..<webLen { webPath.addLine(to: spineA[s]) }
                webPath.addLine(to: spineB[webLen - 1])
                for s in stride(from: webLen - 2, through: 0, by: -1) {
                    webPath.addLine(to: spineB[s])
                }
                webPath.closeSubpath()

                let breathe = (sin(time * 0.8 + Double(i) * 0.5) + 1) / 2
                wCtx.fill(webPath, with: .color(Theme.nucleusCool.opacity(0.012 + breathe * 0.008)))
            }
        }
    }

    // MARK: - Floating Spores

    private func drawSpores(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let sporeColors: [Color] = [
            Theme.sessionOrbit,   // cyan
            Theme.outerOrbit,     // gold
            Theme.weeklyOrbit,    // lavender
        ]

        for spore in spores {
            let color = sporeColors[Int(abs(spore.seed)) % sporeColors.count]
            let rawY = fmod(time * spore.cycleSpeed + spore.seed * 0.1, 1.0)
            let y = size.height - rawY * size.height * 0.9
            let wander = sin(time * 0.4 + spore.seed) * 20
            let x = spore.baseX * size.width + wander

            let fade = min(rawY / 0.1, (1 - rawY) / 0.1, 1.0)
            let sporeR = 2.5 + sin(spore.seed + time * 0.8) * 1.0

            // Outer glow
            ctx.fill(
                Circle().path(in: CGRect(
                    x: x - sporeR * 3, y: y - sporeR * 3,
                    width: sporeR * 6, height: sporeR * 6
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.15 * fade), .clear]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: sporeR * 3
                )
            )

            // Bright core
            ctx.fill(
                Circle().path(in: CGRect(
                    x: x - sporeR * 0.5, y: y - sporeR * 0.5,
                    width: sporeR, height: sporeR
                )),
                with: .color(color.opacity(0.4 * fade))
            )
        }
    }

    // MARK: - Tap Handling

    private func handleTap(at point: CGPoint) {
        // Check tips first (48pt radius)
        for target in hitCache.tips {
            let dx = point.x - target.position.x
            let dy = point.y - target.position.y
            if dx * dx + dy * dy < target.radius * target.radius {
                showTooltip(for: target)
                return
            }
        }
        // Check mid-tentacle nodes (24pt radius)
        for target in hitCache.midpoints {
            let dx = point.x - target.position.x
            let dy = point.y - target.position.y
            if dx * dx + dy * dy < target.radius * target.radius {
                showTooltip(for: target)
                return
            }
        }
        // Tapped empty space
        withAnimation(.easeOut(duration: 0.2)) { tapped = nil }
    }

    private func showTooltip(for target: HitCache.Target) {
        let targetId = target.id
        withAnimation(.easeOut(duration: 0.2)) {
            tapped = target
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    if tapped?.id == targetId { tapped = nil }
                }
            }
        }
    }

    // MARK: - Tooltip

    private func tooltipView(for target: HitCache.Target) -> some View {
        let reset = target.reset.isEmpty ? "" : " — resets in \(target.reset)"
        return Text("\(target.label): \(Int(target.pct))%\(reset)")
            .font(Theme.captionFont)
            .foregroundStyle(Theme.stardust)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
            .offset(y: -36)
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
}
