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

        // Pass 4: Tentacles
        for desc in tentacles {
            let spine = drawTentacle(
                ctx: &ctx, center: center, maxR: maxR,
                desc: desc, time: time
            )
            allSpines.append(spine)
        }

        // Pass 5: Membrane webbing
        drawWebbing(ctx: &ctx, spines: allSpines, time: time)

        // Pass 6: Eye (on top of everything)
        drawEye(ctx: &ctx, center: center, maxR: maxR, activity: activity, time: time)
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

    /// Lerp from indigo (calm) → amber (moderate) → red (critical) based on utilization
    private func irisBaseColor(activity: Double) -> Color {
        if activity < 0.5 {
            return Color.lerp(Theme.nucleusCool, Theme.nucleusWarm, t: activity * 2)
        } else {
            return Color.lerp(Theme.nucleusWarm, Theme.nucleusHot, t: (activity - 0.5) * 2)
        }
    }

    // MARK: - Pass 6: Eye (unified eyeball + iris + pupil)

    private func drawEye(
        ctx: inout GraphicsContext, center: CGPoint,
        maxR: Double, activity: Double, time: Double
    ) {
        let irisColor = irisBaseColor(activity: activity)
        let eyeR = maxR * 0.32          // fills up to the collar
        let pupilR = eyeR * (0.20 + activity * 0.20)  // dilates with usage
        let irisInner = pupilR * 1.3    // iris starts just outside pupil
        let pulseRate = 0.3 + activity * 0.7
        let pulse = (sin(time * pulseRate * .pi * 2) + 1) / 2

        let eyeRect = CGRect(
            x: center.x - eyeR, y: center.y - eyeR,
            width: eyeR * 2, height: eyeR * 2
        )

        // Layer 1: Atmospheric glow (extends beyond eye)
        let glowR = eyeR * 1.6
        ctx.drawLayer { gCtx in
            gCtx.blendMode = .screen
            gCtx.fill(
                Circle().path(in: CGRect(
                    x: center.x - glowR, y: center.y - glowR,
                    width: glowR * 2, height: glowR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        irisColor.opacity(0.20 * (0.6 + pulse * 0.4)),
                        irisColor.opacity(0.08),
                        Theme.nucleusCool.opacity(0.03),
                        .clear
                    ]),
                    center: center, startRadius: eyeR * 0.3, endRadius: glowR
                )
            )
        }

        // Layer 2: Opaque eyeball (dark sclera base)
        let lightOffset = CGPoint(x: center.x - eyeR * 0.12, y: center.y - eyeR * 0.15)
        ctx.fill(
            Circle().path(in: eyeRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.06),
                    Color(red: 0.03, green: 0.06, blue: 0.08),
                    Color(red: 0.04, green: 0.07, blue: 0.09).opacity(0.95),
                    Theme.void,
                ]),
                center: lightOffset, startRadius: 0, endRadius: eyeR
            )
        )

        // Layer 3: Iris — continuous filled color from pupil edge to near outer edge
        // Key: NO void at the outer edge — iris color fills outward and fades gently
        ctx.drawLayer { irCtx in
            irCtx.blendMode = .screen
            irCtx.fill(
                Circle().path(in: eyeRect),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: pupilR / eyeR),
                        .init(color: irisColor.opacity(0.5), location: irisInner / eyeR),
                        .init(color: irisColor.opacity(0.85), location: 0.50),
                        .init(color: irisColor.opacity(0.70), location: 0.70),
                        .init(color: irisColor.opacity(0.30), location: 0.88),
                        .init(color: irisColor.opacity(0.05), location: 1.0),
                    ]),
                    center: center, startRadius: 0, endRadius: eyeR
                )
            )
        }

        // Layer 4: Conic multi-hue overlay (usage colors rotate through iris)
        let cyanOp = state.fiveHourPct / 100.0 * 0.5
        let goldOp = state.sonnetPct / 100.0 * 0.45
        let lavOp = state.sevenDayPct / 100.0 * 0.4
        let irisRotation = Angle(radians: time * 0.15)

        ctx.drawLayer { iCtx in
            iCtx.blendMode = .screen
            iCtx.opacity = 0.3
            iCtx.fill(
                Circle().path(in: eyeRect),
                with: .conicGradient(
                    Gradient(colors: [
                        Theme.sessionOrbit.opacity(cyanOp),
                        Theme.tentacleCyanMid.opacity(cyanOp * 0.5),
                        Theme.outerOrbit.opacity(goldOp),
                        Theme.tentacleGoldMid.opacity(goldOp * 0.5),
                        Theme.weeklyOrbit.opacity(lavOp),
                        Theme.tentacleLavenderMid.opacity(lavOp * 0.5),
                        Theme.sessionOrbit.opacity(cyanOp),
                    ]),
                    center: center,
                    angle: irisRotation
                )
            )
            // Radial mask: only show conic in iris band (not pupil, not outer edge)
            iCtx.fill(
                Circle().path(in: eyeRect),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: pupilR / eyeR),
                        .init(color: .white.opacity(0.3), location: irisInner / eyeR),
                        .init(color: .white.opacity(0.7), location: 0.50),
                        .init(color: .white.opacity(0.5), location: 0.75),
                        .init(color: .clear, location: 0.92),
                    ]),
                    center: center, startRadius: 0, endRadius: eyeR
                )
            )
        }

        // Layer 5: Iris fibrous texture (radial streaks for organic detail)
        ctx.drawLayer { fCtx in
            fCtx.blendMode = .screen
            let streakCount = 24
            for i in 0..<streakCount {
                let angle = Double(i) * .pi * 2 / Double(streakCount) + time * 0.02
                let wobble = sin(time * 0.3 + Double(i) * 1.3) * 0.06
                let innerPt = CGPoint(
                    x: center.x + cos(angle) * irisInner,
                    y: center.y + sin(angle) * irisInner
                )
                let outerPt = CGPoint(
                    x: center.x + cos(angle + wobble) * eyeR * 0.85,
                    y: center.y + sin(angle + wobble) * eyeR * 0.85
                )
                var streak = Path()
                streak.move(to: innerPt)
                streak.addLine(to: outerPt)
                let streakPulse = (sin(time * 0.8 + Double(i) * 0.5) + 1) / 2
                fCtx.stroke(streak, with: .color(irisColor.opacity(0.06 + streakPulse * 0.04)), lineWidth: 1.2)
            }
        }

        // Layer 6: Pupil depth (deep black center with soft edge)
        ctx.fill(
            Circle().path(in: CGRect(
                x: center.x - pupilR, y: center.y - pupilR,
                width: pupilR * 2, height: pupilR * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.01, green: 0.01, blue: 0.02),
                    Color(red: 0.01, green: 0.01, blue: 0.02),
                    Color(red: 0.02, green: 0.03, blue: 0.04).opacity(0.8),
                ]),
                center: center, startRadius: 0, endRadius: pupilR
            )
        )

        // Layer 7: High-usage pulse — red flicker when any metric > 80%
        let maxPct = max(state.fiveHourPct, state.sonnetPct, state.sevenDayPct)
        if maxPct > 80 {
            let urgency = (maxPct - 80) / 20.0
            let errPulse = (sin(time * 3.5) + 1) / 2
            ctx.drawLayer { eCtx in
                eCtx.blendMode = .plusLighter
                eCtx.fill(
                    Circle().path(in: eyeRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Theme.nucleusHot.opacity(0.12 * errPulse * urgency),
                            Theme.nucleusHot.opacity(0.04 * errPulse * urgency),
                            .clear
                        ]),
                        center: center, startRadius: 0, endRadius: eyeR * 0.5
                    )
                )
            }
        }

        // Layer 8: Rim light — upper arc for spherical depth
        ctx.drawLayer { rCtx in
            rCtx.blendMode = .plusLighter
            let rimArc = Path { p in
                p.addArc(center: center, radius: eyeR * 0.92,
                         startAngle: .degrees(-150), endAngle: .degrees(-30),
                         clockwise: false)
            }
            rCtx.stroke(rimArc, with: .color(irisColor.opacity(0.15 + pulse * 0.1)), lineWidth: 2.0)
        }

        // Layer 9: Specular highlights
        let specX = center.x - eyeR * 0.25
        let specY = center.y - eyeR * 0.25
        let specR = eyeR * 0.14
        ctx.fill(
            Circle().path(in: CGRect(
                x: specX - specR, y: specY - specR,
                width: specR * 2, height: specR * 2
            )),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.6), .white.opacity(0.15), .clear]),
                center: CGPoint(x: specX, y: specY), startRadius: 0, endRadius: specR
            )
        )
        let spec2X = center.x + eyeR * 0.18
        let spec2Y = center.y + eyeR * 0.12
        let spec2R = eyeR * 0.07
        ctx.fill(
            Circle().path(in: CGRect(
                x: spec2X - spec2R, y: spec2Y - spec2R,
                width: spec2R * 2, height: spec2R * 2
            )),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.35), .clear]),
                center: CGPoint(x: spec2X, y: spec2Y), startRadius: 0, endRadius: spec2R
            )
        )
    }

    // MARK: - Pass 2: Collar Ring

    private func drawCollar(
        ctx: inout GraphicsContext, center: CGPoint,
        maxR: Double, time: Double
    ) {
        let collarR = maxR * 0.35
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
        let collarR = maxR * 0.35
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
