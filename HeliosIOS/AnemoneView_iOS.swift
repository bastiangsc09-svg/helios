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

// MARK: - Touch State (class — no @State re-renders, read by Canvas each frame)

private final class TouchState {
    var location: CGPoint = .zero
    var isActive: Bool = false
    var intensity: Double = 0       // 0-1, ramps up on touch, decays on release
    private var lastTime: Double = 0

    func update(time: Double) {
        let dt = lastTime == 0 ? 1.0 / 30.0 : min(time - lastTime, 0.1)
        lastTime = time
        if isActive {
            intensity = min(intensity + dt * 5.0, 1.0)     // fast ramp up
        } else {
            intensity = max(intensity - dt * 2.0, 0.0)     // smooth decay
        }
    }
}

// MARK: - Drag State (spring physics for draggable anemone)

private final class DragState {
    var offset: CGPoint = .zero         // current displacement from home
    var velocity: CGPoint = .zero       // px/s
    var isDragging: Bool = false
    var grabOffset: CGPoint = .zero     // finger offset from center at grab start
    var smoothVelocity: CGPoint = .zero // smoothed velocity for tentacle trailing
    private var lastTime: Double = 0
    private var prevOffset: CGPoint = .zero

    // Spring parameters — extremely sticky, rubber band snap-back
    private let stiffness: Double = 35.0    // very high = instant snap-back
    private let damping: Double = 0.75      // slight bounce for organic feel

    func update(time: Double) {
        let dt = lastTime == 0 ? 1.0 / 30.0 : min(time - lastTime, 0.1)
        lastTime = time

        // Compute instantaneous velocity from offset change (works during drag AND spring-back)
        let instantVx = (offset.x - prevOffset.x) / max(dt, 0.001)
        let instantVy = (offset.y - prevOffset.y) / max(dt, 0.001)
        prevOffset = offset

        // Smooth the velocity (exponential moving average) for organic tentacle trailing
        let smoothing = 0.15  // lower = smoother/laggier
        smoothVelocity.x += (instantVx - smoothVelocity.x) * smoothing
        smoothVelocity.y += (instantVy - smoothVelocity.y) * smoothing

        // Decay smooth velocity when nearly stopped
        let smoothSpeed = hypot(smoothVelocity.x, smoothVelocity.y)
        if smoothSpeed < 2.0 {
            smoothVelocity.x *= 0.9
            smoothVelocity.y *= 0.9
        }

        guard !isDragging else { return }

        // Spring force toward origin
        let fx = -offset.x * stiffness
        let fy = -offset.y * stiffness
        velocity.x += fx * dt
        velocity.y += fy * dt

        // Damping (friction)
        velocity.x *= pow(damping, dt * 60)
        velocity.y *= pow(damping, dt * 60)

        // Integrate
        offset.x += velocity.x * dt
        offset.y += velocity.y * dt

        // Snap to zero when close + slow
        let dist = hypot(offset.x, offset.y)
        let speed = hypot(velocity.x, velocity.y)
        if dist < 0.3 && speed < 0.5 {
            offset = .zero
            velocity = .zero
        }
    }
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
    @AppStorage("irisScale") private var irisScale: Double = 1.0
    @AppStorage("tentacleScale") private var tentacleScale: Double = 1.0
    @State private var spores: [Spore] = (0..<25).map { i in
        let seed = Double(i) * 137.508
        return Spore(
            baseX: fmod(seed * 23.1, 1.0),
            seed: seed,
            cycleSpeed: 0.012 + fmod(seed, 0.02)
        )
    }

    private let hitCache = HitCache()
    private let touchState = TouchState()
    private let dragState = DragState()

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
                        let defaultCenter = CGPoint(x: geo.size.width / 2, y: orreryHeight / 2)
                        let center = CGPoint(
                            x: defaultCenter.x + dragState.offset.x,
                            y: defaultCenter.y + dragState.offset.y
                        )

                        Canvas { ctx, size in
                            drawSpores(ctx: &ctx, size: size, time: t)
                            drawAnemone(
                                ctx: &ctx, center: center, maxR: maxR,
                                time: t
                            )
                        }
                    }
                    .allowsHitTesting(false)

                    // Touch detection (drag for move + reactive effects + tooltips)
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let defaultCenter = CGPoint(x: geo.size.width / 2, y: orreryHeight / 2)
                                    let currentCenter = CGPoint(
                                        x: defaultCenter.x + dragState.offset.x,
                                        y: defaultCenter.y + dragState.offset.y
                                    )
                                    let bodyRadius = maxR * 0.5

                                    // On first touch, decide if we're grabbing the body
                                    if !dragState.isDragging && !touchState.isActive {
                                        let dx = value.startLocation.x - currentCenter.x
                                        let dy = value.startLocation.y - currentCenter.y
                                        let dist = hypot(dx, dy)
                                        if dist < bodyRadius {
                                            dragState.isDragging = true
                                            dragState.velocity = .zero
                                            dragState.grabOffset = CGPoint(
                                                x: value.startLocation.x - currentCenter.x,
                                                y: value.startLocation.y - currentCenter.y
                                            )
                                        }
                                    }

                                    // Move mode: update anemone position
                                    if dragState.isDragging {
                                        dragState.offset = CGPoint(
                                            x: value.location.x - defaultCenter.x - dragState.grabOffset.x,
                                            y: value.location.y - defaultCenter.y - dragState.grabOffset.y
                                        )
                                    }

                                    // Always update touch state for reactive effects
                                    touchState.location = value.location
                                    touchState.isActive = true
                                }
                                .onEnded { value in
                                    touchState.isActive = false

                                    if dragState.isDragging {
                                        // Transfer gesture velocity to spring physics
                                        dragState.velocity = CGPoint(
                                            x: value.predictedEndLocation.x - value.location.x,
                                            y: value.predictedEndLocation.y - value.location.y
                                        )
                                        dragState.isDragging = false
                                    }

                                    // Short drags = taps → show tooltip (only if not moving)
                                    let dragDist = hypot(
                                        value.location.x - value.startLocation.x,
                                        value.location.y - value.startLocation.y
                                    )
                                    if dragDist < 15 {
                                        handleTap(at: value.location)
                                    }
                                }
                        )

                    // Tooltip
                    if let t = tapped {
                        tooltipView(for: t)
                            .position(t.position)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            .allowsHitTesting(false)
                    }
                }

                // Readout bar
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
                    // Full error — no data yet
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.sessionOrbit)
                        Text("Connection Error")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.stardust)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.stardust.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Theme.sessionOrbit.opacity(0.15),
                                        Theme.weeklyOrbit.opacity(0.1),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                            .blur(radius: 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Theme.sessionOrbit.opacity(0.4),
                                        Theme.weeklyOrbit.opacity(0.25),
                                        Theme.sessionOrbit.opacity(0.3),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.75
                            )
                    )
                    .shadow(color: Theme.sessionOrbit.opacity(0.15), radius: 8)
                    .shadow(color: Theme.weeklyOrbit.opacity(0.08), radius: 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                if state.error != nil, state.usage != nil {
                    // Stale data banner — small pill at top
                    VStack {
                        HStack(spacing: 6) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.sessionOrbit)
                            Text("Offline — showing cached data")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.stardust.opacity(0.6))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.3), in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    Theme.sessionOrbit.opacity(0.3),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(color: Theme.sessionOrbit.opacity(0.1), radius: 6)
                        .padding(.top, 60)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea()
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

        // Update touch intensity (smooth ramp/decay)
        touchState.update(time: time)
        // Update drag spring physics (spring-back when released)
        dragState.update(time: time)

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
        let touchBoost = touchState.intensity * 0.08
        let haloR = maxR * 3.0
        let intensity = 0.06 + activity * 0.10 + touchBoost
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

        // Touch proximity glow — bright spot near finger
        if touchState.intensity > 0.01 {
            let tI = touchState.intensity
            let glowR = maxR * 0.8
            ctx.drawLayer { tCtx in
                tCtx.blendMode = .plusLighter
                tCtx.fill(
                    Circle().path(in: CGRect(
                        x: touchState.location.x - glowR,
                        y: touchState.location.y - glowR,
                        width: glowR * 2, height: glowR * 2
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            irisColor.opacity(0.12 * tI),
                            irisColor.opacity(0.04 * tI),
                            .clear
                        ]),
                        center: touchState.location,
                        startRadius: 0, endRadius: glowR
                    )
                )
            }
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

    // MARK: - Pass 5: Iris (Alien)

    private func drawIris(
        ctx: inout GraphicsContext, center: CGPoint,
        maxR: Double, activity: Double, time: Double
    ) {
        let tI = touchState.intensity
        let irisR = maxR * 0.34 * irisScale
        // Pupil dilates with usage AND touch
        let pupilR = irisR * (0.28 + activity * 0.12 + tI * 0.08)
        let collaretteR = irisR * 0.48
        let limbalR = irisR * 0.96
        let fiberCount = 80
        let pulse = (sin(time * (0.8 + activity * 0.6)) + 1) / 2

        // Slow alien rotation of the entire fiber field
        let irisRotation = time * 0.03

        // Usage-driven colors
        let innerColor = Theme.outerOrbit        // gold/amber (inner stroma)
        let outerColor = Theme.sessionOrbit       // cyan/teal (outer stroma)
        let accentColor = Theme.weeklyOrbit       // lavender (crypts + nerve lines)

        // Touch-reactive opacity boost
        let touchBright = tI * 0.06

        let irisRect = CGRect(
            x: center.x - irisR, y: center.y - irisR,
            width: irisR * 2, height: irisR * 2
        )

        // ── Layer 1: Dark base fill (semi-transparent for alien look) ──
        ctx.fill(
            Circle().path(in: irisRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(hex: "040608").opacity(0.85),
                    Color(hex: "040608").opacity(0.95),
                    Color(hex: "030406")
                ]),
                center: center, startRadius: 0, endRadius: irisR
            )
        )

        // ── Layer 2: Limbal ring (darker outer border, slightly translucent) ──
        ctx.drawLayer { lCtx in
            lCtx.fill(
                Circle().path(in: irisRect),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.82),
                        .init(color: Color(hex: "0A1520").opacity(0.7), location: 0.90),
                        .init(color: Color(hex: "060D14").opacity(0.85), location: 1.0),
                    ]),
                    center: center, startRadius: 0, endRadius: irisR
                )
            )
        }

        // ── Layer 3: Base stroma (two-zone, more transparent) ──
        ctx.drawLayer { sCtx in
            sCtx.blendMode = .screen
            sCtx.fill(
                Circle().path(in: irisRect),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: pupilR / irisR),
                        .init(color: innerColor.opacity(0.18 + touchBright), location: pupilR / irisR + 0.03),
                        .init(color: innerColor.opacity(0.32 + touchBright), location: collaretteR / irisR - 0.05),
                        .init(color: innerColor.opacity(0.22 + touchBright), location: collaretteR / irisR),
                        .init(color: outerColor.opacity(0.20 + touchBright), location: collaretteR / irisR + 0.05),
                        .init(color: outerColor.opacity(0.35 + touchBright), location: 0.75),
                        .init(color: outerColor.opacity(0.18 + touchBright), location: limbalR / irisR),
                        .init(color: .clear, location: 1.0),
                    ]),
                    center: center, startRadius: 0, endRadius: irisR
                )
            )
        }

        // ── Layer 4: Radial muscle fibers (rotated, more transparent) ──
        ctx.drawLayer { fCtx in
            fCtx.blendMode = .screen

            for i in 0..<fiberCount {
                let fi = Double(i)
                let seed = fi * 137.508
                let baseAngle = fi * .pi * 2.0 / Double(fiberCount) + irisRotation

                let wobble = sin(seed * 3.7 + time * 0.08) * 0.05
                    + sin(seed * 7.1) * 0.025
                    + sin(seed * 11.3 + time * 0.12) * 0.015  // extra organic harmonic
                let angle = baseAngle + wobble

                let startR = pupilR + irisR * 0.02
                let endR = limbalR - irisR * 0.01 + sin(seed * 2.3) * irisR * 0.03
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

                let brightVar = 0.7 + sin(seed * 1.9) * 0.3
                let fiberPulse = (sin(time * 0.5 + seed * 0.3) + 1) / 2

                // Occasional lavender flicker in some fibers (alien)
                let useLavender = sin(seed * 13.7 + time * 0.2) > 0.85
                let fiberColor = useLavender ? accentColor : innerColor

                let width = 1.0 + sin(seed * 4.3) * 0.4
                let opacity = (0.10 + fiberPulse * 0.06 + touchBright) * brightVar

                fCtx.stroke(fiber, with: .color(fiberColor.opacity(opacity)), lineWidth: width)
            }
        }

        // ── Layer 5: Outer fiber overlay (teal, rotated) ──
        ctx.drawLayer { oCtx in
            oCtx.blendMode = .screen

            for i in 0..<fiberCount {
                let fi = Double(i)
                let seed = fi * 137.508
                let baseAngle = fi * .pi * 2.0 / Double(fiberCount) + irisRotation
                let wobble = sin(seed * 3.7 + time * 0.08) * 0.05
                    + sin(seed * 7.1) * 0.025
                let angle = baseAngle + wobble

                let startR = collaretteR - irisR * 0.02
                let endR = limbalR - irisR * 0.02 + sin(seed * 2.3) * irisR * 0.02
                let midR = (startR + endR) / 2
                let curveBias = sin(seed * 5.1 + time * 0.05) * irisR * 0.06
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
                let width = 0.8 + sin(seed * 3.1) * 0.3
                let opacity = (0.08 + fiberPulse * 0.05 + touchBright) * brightVar

                oCtx.stroke(fiber, with: .color(outerColor.opacity(opacity)), lineWidth: width)
            }
        }

        // ── Layer 6: Bioluminescent nerve threads (alien organic pattern) ──
        ctx.drawLayer { nCtx in
            nCtx.blendMode = .screen
            let nerveCount = 12
            for i in 0..<nerveCount {
                let seed = Double(i) * 47.3 + 100
                let startAngle = seed * 0.618 * .pi * 2 + irisRotation * 0.5
                let arcLen = 0.3 + sin(seed * 2.1) * 0.15   // how far around the iris
                let rBand = pupilR + (limbalR - pupilR) * (0.3 + fmod(seed * 0.23, 0.5))
                let segments = 8

                var nervePath = Path()
                for s in 0...segments {
                    let t = Double(s) / Double(segments)
                    let a = startAngle + arcLen * t
                    let rWobble = sin(t * 6 + time * 0.3 + seed) * irisR * 0.03
                    let r = rBand + rWobble
                    let pt = CGPoint(
                        x: center.x + cos(a) * r,
                        y: center.y + sin(a) * r
                    )
                    if s == 0 { nervePath.move(to: pt) }
                    else { nervePath.addLine(to: pt) }
                }

                let nervePulse = (sin(time * 0.6 + seed * 1.3) + 1) / 2
                let nerveOp = (0.06 + nervePulse * 0.04 + tI * 0.04)
                nCtx.stroke(nervePath, with: .color(accentColor.opacity(nerveOp)), lineWidth: 0.8)
                // Soft glow
                nCtx.stroke(nervePath, with: .color(accentColor.opacity(nerveOp * 0.4)), lineWidth: 3.0)
            }
        }

        // ── Layer 7: Collarette ring (jagged boundary) ──
        ctx.drawLayer { cCtx in
            cCtx.blendMode = .screen
            let segments = 48
            var collarPath = Path()
            for i in 0...segments {
                let t = Double(i) / Double(segments)
                let angle = t * .pi * 2 + irisRotation * 0.3
                let jag = sin(angle * 12 + time * 0.1) * irisR * 0.018
                    + sin(angle * 7 + 1.5) * irisR * 0.012
                    + sin(angle * 19 + 0.7) * irisR * 0.008
                    + sin(angle * 31 + time * 0.07) * irisR * 0.004  // extra alien irregularity
                let r = collaretteR + jag
                let pt = CGPoint(
                    x: center.x + cos(angle) * r,
                    y: center.y + sin(angle) * r
                )
                if i == 0 { collarPath.move(to: pt) }
                else { collarPath.addLine(to: pt) }
            }
            collarPath.closeSubpath()
            cCtx.stroke(collarPath, with: .color(innerColor.opacity(0.30 + touchBright)), lineWidth: 1.5)
            cCtx.stroke(collarPath, with: .color(innerColor.opacity(0.08 + touchBright * 0.5)), lineWidth: 5.0)
        }

        // ── Layer 8: Glowing crypts (bioluminescent spots — alien) ──
        ctx.drawLayer { crCtx in
            crCtx.blendMode = .screen
            let cryptCount = 20
            for i in 0..<cryptCount {
                let seed = Double(i) * 97.3
                let angle = seed * 0.618 * .pi * 2 + irisRotation * 0.2
                let rNorm = 0.35 + fmod(seed * 0.37, 0.45)
                let r = irisR * rNorm
                let cx = center.x + cos(angle) * r
                let cy = center.y + sin(angle) * r
                let cryptR = irisR * (0.018 + sin(seed * 3.1) * 0.008)
                let cryptPulse = (sin(time * 0.7 + seed * 2.7) + 1) / 2

                // Glow color alternates between accent and outer
                let glowColor = i % 3 == 0 ? accentColor : outerColor
                let glowOp = (0.08 + cryptPulse * 0.06 + tI * 0.05)

                crCtx.fill(
                    Circle().path(in: CGRect(
                        x: cx - cryptR * 2, y: cy - cryptR * 2,
                        width: cryptR * 4, height: cryptR * 4
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            glowColor.opacity(glowOp),
                            glowColor.opacity(glowOp * 0.3),
                            .clear
                        ]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0, endRadius: cryptR * 2
                    )
                )
            }
        }

        // ── Layer 9: Pupil (deep dark with organic irregular edge + inner glow) ──
        ctx.drawLayer { pCtx in
            let pupilSegs = 36
            var pupilPath = Path()
            for i in 0...pupilSegs {
                let t = Double(i) / Double(pupilSegs)
                let angle = t * .pi * 2
                let irregularity = sin(angle * 8 + time * 0.15) * pupilR * 0.04
                    + sin(angle * 13 + time * 0.08) * pupilR * 0.025
                    + sin(angle * 21) * pupilR * 0.015     // more alien irregularity
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

            // Inner bioluminescent glow from pupil (alien light within)
            pCtx.drawLayer { peCtx in
                peCtx.blendMode = .screen
                let innerGlowR = pupilR * 1.4
                let glowIntensity = 0.12 + pulse * 0.06 + tI * 0.08
                peCtx.fill(
                    Circle().path(in: CGRect(
                        x: center.x - innerGlowR, y: center.y - innerGlowR,
                        width: innerGlowR * 2, height: innerGlowR * 2
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            outerColor.opacity(glowIntensity * 0.4),
                            innerColor.opacity(glowIntensity),
                            innerColor.opacity(glowIntensity * 0.5),
                            .clear
                        ]),
                        center: center, startRadius: pupilR * 0.6, endRadius: innerGlowR
                    )
                )
            }
        }

        // ── Layer 10: Ambient glow (extends beyond iris) ──
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
                        outerColor.opacity((0.08 + tI * 0.04) * (0.6 + pulse * 0.4)),
                        outerColor.opacity(0.02),
                        .clear
                    ]),
                    center: center, startRadius: irisR * 0.5, endRadius: glowR
                )
            )
        }

        // ── Layer 11: Touch pulse ring (expanding ring on touch) ──
        if tI > 0.01 {
            let ringR = irisR * (1.1 + tI * 0.3)
            ctx.drawLayer { rCtx in
                rCtx.blendMode = .screen
                let ringRect = CGRect(
                    x: center.x - ringR, y: center.y - ringR,
                    width: ringR * 2, height: ringR * 2
                )
                rCtx.stroke(
                    Circle().path(in: ringRect),
                    with: .color(outerColor.opacity(0.15 * tI)),
                    lineWidth: 1.5
                )
            }
        }

        // ── Layer 12: High-usage pulse ──
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

        // ── Layer 13: Specular highlights (softer, organic wet sheen) ──
        let specX = center.x - irisR * 0.22
        let specY = center.y - irisR * 0.22
        let specR = irisR * 0.12
        ctx.fill(
            Circle().path(in: CGRect(
                x: specX - specR, y: specY - specR,
                width: specR * 2, height: specR * 2
            )),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.30), .white.opacity(0.05), .clear]),
                center: CGPoint(x: specX, y: specY), startRadius: 0, endRadius: specR
            )
        )
        let spec2X = center.x + irisR * 0.15
        let spec2Y = center.y + irisR * 0.10
        let spec2R = irisR * 0.06
        ctx.fill(
            Circle().path(in: CGRect(
                x: spec2X - spec2R, y: spec2Y - spec2R,
                width: spec2R * 2, height: spec2R * 2
            )),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.15), .clear]),
                center: CGPoint(x: spec2X, y: spec2Y), startRadius: 0, endRadius: spec2R
            )
        )
    }

    // MARK: - Pass 2: Collar Ring

    private func drawCollar(
        ctx: inout GraphicsContext, center: CGPoint,
        maxR: Double, time: Double
    ) {
        let collarR = maxR * 0.37 * irisScale
        let pulse = (sin(time * 1.2) + 1) / 2
        let activity = state.overallUtilization / 100.0
        let collarColor = irisBaseColor(activity: activity)
        let tI = touchState.intensity

        ctx.drawLayer { cCtx in
            cCtx.blendMode = .screen

            let ringRect = CGRect(
                x: center.x - collarR, y: center.y - collarR,
                width: collarR * 2, height: collarR * 2
            )
            cCtx.stroke(
                Circle().path(in: ringRect),
                with: .color(collarColor.opacity(0.15 + pulse * 0.08 + tI * 0.06)),
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
                        collarColor.opacity(0.06 + tI * 0.03),
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
        let collarR = maxR * 0.37 * irisScale
        let tentacleLen = maxR * (0.15 + norm * 0.85)
        let thk = tentacleScale  // thickness multiplier from settings
        let waveSpeed = 0.5 + norm * 1.5
        let angle = desc.angle
        let segments = 20
        let perp = angle + .pi / 2
        let perpX = cos(perp)
        let perpY = sin(perp)
        let seed = Double(desc.id.hashValue & 0xFFFF) * 0.001
        let tI = touchState.intensity

        // 4a: Compute 20 spine points with 3-harmonic wave sway + touch attraction
        var points: [CGPoint] = []
        for s in 0...segments {
            let t = Double(s) / Double(segments)
            let wave = sin(time * waveSpeed + seed + t * 6) * t * maxR * 0.12
                + sin(time * waveSpeed * 1.7 + seed + t * 4) * t * maxR * 0.04
                + sin(time * waveSpeed * 0.6 + seed * 2.3 + t * 9) * t * maxR * 0.02
            var px = center.x + cos(angle) * (collarR + tentacleLen * t) + perpX * wave
            var py = center.y + sin(angle) * (collarR + tentacleLen * t) + perpY * wave

            // Drag inertia: whole tentacle trails behind movement (like dragging through water)
            let trailFactor = t * 0.12  // linear, strong — entire tentacle visibly trails
            px -= dragState.smoothVelocity.x * trailFactor
            py -= dragState.smoothVelocity.y * trailFactor

            // Touch attraction: tentacles lean toward finger
            if tI > 0.01 {
                let dx = touchState.location.x - px
                let dy = touchState.location.y - py
                let dist = sqrt(dx * dx + dy * dy)
                let maxInfluence = maxR * 2.0
                if dist > 1 && dist < maxInfluence {
                    let falloff = 1.0 - dist / maxInfluence
                    let force = falloff * falloff * tI * t * 18  // stronger on tips
                    px += (dx / dist) * force
                    py += (dy / dist) * force
                }
            }

            points.append(CGPoint(x: px, y: py))
        }

        // Pre-compute double-helix positions
        let helixFreq = 8.0
        var strandA: [CGPoint] = []
        var strandB: [CGPoint] = []
        for s in 0...segments {
            let t = Double(s) / Double(segments)
            let helixPhase = sin(t * helixFreq + time * waveSpeed * 0.5 + seed)
            let amp = (3.0 - t * 2.0) * (1.0 + norm * 0.5) * thk
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
            gCtx.stroke(glowPath, with: .color(desc.tipColor.opacity(0.08 + tI * 0.04)), lineWidth: 14 * (0.6 + thk * 0.4))
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
            let strandWidth = taper * undulation * thk

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
            iCtx.stroke(innerPath, with: .color(desc.tipColor.opacity(0.08 + tI * 0.04)), lineWidth: 2.5 * (0.6 + thk * 0.4))
            iCtx.stroke(innerPath, with: .color(.white.opacity(0.10 + tI * 0.05)), lineWidth: 0.8 * (0.6 + thk * 0.4))
        }

        // 4e: Photophore nodes at segments 4, 8, 12, 16
        let nodeInterval = 4
        for s in stride(from: nodeInterval, through: segments - 2, by: nodeInterval) {
            let t = Double(s) / Double(segments)
            let nodePulse = (sin(time * (2.0 + Double(s) * 0.3) + seed * Double(s)) + 1) / 2
            let nodeR = (2.0 + nodePulse * 1.5 + norm * 1.0) * thk
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
            ctx.stroke(filPath, with: .color(desc.tipColor.opacity(0.2)), lineWidth: 1 * thk)

            let ftR = (2.0 + sin(time * 2 + Double(f) * 1.5) * 0.5) * thk
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
        let tipR = (3.0 + norm * 8.0) * thk
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
        let tI = touchState.intensity

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
                wCtx.fill(webPath, with: .color(Theme.nucleusCool.opacity(0.012 + breathe * 0.008 + tI * 0.006)))
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
        let tI = touchState.intensity

        for spore in spores {
            let color = sporeColors[Int(abs(spore.seed)) % sporeColors.count]
            let rawY = fmod(time * spore.cycleSpeed + spore.seed * 0.1, 1.0)
            var y = size.height - rawY * size.height * 0.9
            let wander = sin(time * 0.4 + spore.seed) * 20
            var x = spore.baseX * size.width + wander

            // Touch scatter: spores flee from finger
            if tI > 0.01 {
                let dx = x - touchState.location.x
                let dy = y - touchState.location.y
                let dist = sqrt(dx * dx + dy * dy)
                let scatterR: Double = 120
                if dist > 1 && dist < scatterR {
                    let push = (1.0 - dist / scatterR) * tI * 35
                    x += (dx / dist) * push
                    y += (dy / dist) * push
                }
            }

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
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
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
        // Layer 1: Subtle dark glass fill for depth
        .background(Color.black.opacity(0.25), in: Capsule())
        // Layer 2: Diffuse outer plasma glow (wide, faint)
        .background(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Theme.sessionOrbit.opacity(0.15),
                            Theme.weeklyOrbit.opacity(0.1),
                            Theme.outerOrbit.opacity(0.15),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .blur(radius: 6)
        )
        // Layer 3: Mid plasma band (medium width, more visible)
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Theme.sessionOrbit.opacity(0.35),
                            Theme.weeklyOrbit.opacity(0.2),
                            Theme.outerOrbit.opacity(0.35),
                            Theme.sessionOrbit.opacity(0.2),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .blur(radius: 1.5)
        )
        // Layer 4: Sharp bright core border (the plasma wire)
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Theme.sessionOrbit.opacity(0.6),
                            Theme.weeklyOrbit.opacity(0.35),
                            Theme.outerOrbit.opacity(0.6),
                            Theme.sessionOrbit.opacity(0.35),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        )
        // Layer 5: Top-edge specular highlight (light catching the surface)
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        )
        // Layer 6: Inner edge glow (plasma glow inside the capsule)
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Theme.sessionOrbit.opacity(0.08),
                            Theme.outerOrbit.opacity(0.05),
                            Theme.weeklyOrbit.opacity(0.08),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 8
                )
                .blur(radius: 8)
                .clipShape(Capsule())
        )
        // Emission glow — multi-layer plasma bloom
        .shadow(color: Theme.sessionOrbit.opacity(0.2), radius: 6)
        .shadow(color: Theme.weeklyOrbit.opacity(0.12), radius: 14)
        .shadow(color: Theme.outerOrbit.opacity(0.08), radius: 24)
        .contentShape(Capsule())
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
