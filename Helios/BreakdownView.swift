import SwiftUI

// MARK: - Plant Geometry

private struct PlantGeometry {
    let index: Int
    let baseX: Double
    let groundY: Double
    let stalkHeight: Double
    let bloomCenter: CGPoint
    let bloomRadius: Double
    let utilization: Double
    let color: Color
    let shortLabel: String
    let label: String
    let resetDate: Date?
    let sway: Double
}

// MARK: - Bezier Helpers

private func bezierPoint(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
    let mt = 1 - t
    let mt2 = mt * mt
    let mt3 = mt2 * mt
    let t2 = t * t
    let t3 = t2 * t
    return CGPoint(
        x: mt3 * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t3 * p3.x,
        y: mt3 * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t3 * p3.y
    )
}

private func quadBezierPoint(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
    let mt = 1 - t
    return CGPoint(
        x: mt * mt * p0.x + 2 * mt * t * p1.x + t * t * p2.x,
        y: mt * mt * p0.y + 2 * mt * t * p1.y + t * t * p2.y
    )
}

// MARK: - BreakdownView

struct BreakdownView: View {
    let state: UsageState

    @State private var mousePos: CGPoint?

    private static let plantColors: [Color] = [
        Theme.pulseSession, Theme.pulseWeekly, Theme.pulseSonnet,
    ]

    var body: some View {
        ZStack {
            Theme.void.ignoresSafeArea()

            if let usage = state.usage, !usage.allBuckets.isEmpty {
                gardenView(buckets: Array(usage.allBuckets.prefix(3)))
            } else {
                emptyState
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        StarfieldCanvas(starCount: 80, brightnessMultiplier: 0.2)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundStyle(Theme.stardust.opacity(0.2))

                    Text("No usage data yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.stardust.opacity(0.4))

                    if state.hasSessionConfig {
                        Text(state.isLoading ? "Fetching..." : "Waiting for data")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.stardust.opacity(0.25))
                    } else {
                        Text("Configure session key in Settings")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.sessionOrbit.opacity(0.5))
                    }
                }
            }
    }

    // MARK: - Garden View

    @ViewBuilder
    private func gardenView(buckets: [(label: String, shortLabel: String, bucket: UsageBucket)]) -> some View {
        let items = Array(buckets.prefix(3))
        let n = items.count
        let colors: [Color] = [Theme.pulseSession, Theme.pulseWeekly, Theme.pulseSonnet]

        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let r = min(w / Double(max(n, 1)) * 0.35, h * 0.3)

            ZStack {
                StarfieldCanvas(starCount: 60, brightnessMultiplier: 0.15)
                    .allowsHitTesting(false)

                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate

                    Canvas { ctx, size in
                        drawGroundFog(ctx: &ctx, size: size, time: t)

                        for (i, item) in items.enumerated() {
                            let cx = w * (Double(i) + 0.5) / Double(n)
                            let cy = h * 0.45
                            let center = CGPoint(x: cx, y: cy)
                            let color = colors[i % colors.count]
                            let util = item.bucket.utilization

                            switch i % 3 {
                            case 0:
                                FlowerRenderer.drawDeepSea(
                                    ctx: &ctx, center: center, radius: r,
                                    utilization: util, color: color, time: t)
                            case 1:
                                FlowerRenderer.drawCrown(
                                    ctx: &ctx, center: center, radius: r,
                                    utilization: util, color: color, time: t)
                            default:
                                FlowerRenderer.drawSpiral(
                                    ctx: &ctx, center: center, radius: r,
                                    utilization: util, color: color, time: t)
                            }
                        }
                    }
                }
                .allowsHitTesting(false)

                // Labels as native SwiftUI text (more reliable than Canvas text)
                ForEach(0..<n, id: \.self) { i in
                    flowerLabel(item: items[i], index: i, count: n,
                                width: w, height: h, radius: r,
                                color: colors[i % colors.count])
                }
                .allowsHitTesting(false)

                // Hover interaction layer
                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc): mousePos = loc
                        case .ended: mousePos = nil
                        }
                    }

                // Admin overlay at bottom
                if state.hasAdminConfig && !state.tokensByModel.isEmpty {
                    VStack {
                        Spacer()
                        adminOverlay
                    }
                    .allowsHitTesting(false)
                }
            }
        }
    }

    @ViewBuilder
    private func flowerLabel(
        item: (label: String, shortLabel: String, bucket: UsageBucket),
        index: Int, count: Int,
        width: Double, height: Double, radius: Double,
        color: Color
    ) -> some View {
        let cx = width * (Double(index) + 0.5) / Double(count)
        let belowFlower = height * 0.45 + radius

        VStack(spacing: 3) {
            Text(item.shortLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(color.opacity(0.8))
            Text("\(Int(item.bucket.utilization))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.forUtilization(item.bucket.utilization).opacity(0.7))
            if let rd = item.bucket.resetsAtDate, rd > Date() {
                Text(rd.countdownString)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(Theme.stardust.opacity(0.35))
            }
        }
        .position(x: cx, y: belowFlower + 30)
    }

    // MARK: - Compute Plants

    private func computePlants(
        buckets: [(label: String, shortLabel: String, bucket: UsageBucket)],
        size: CGSize,
        time: Double
    ) -> [PlantGeometry] {
        let n = buckets.count
        let groundY = size.height * 0.82

        return buckets.enumerated().map { i, item in
            let baseX = size.width * (Double(i) + 0.5) / Double(n)
            let util = item.bucket.utilization
            let stalkH = size.height * (0.25 + 0.25 * util / 100.0)
            let sway = sin(time * 0.5 + baseX * 0.01) * 8
            let bloomR = 12.0 + 20.0 * util / 100.0
            let color = Self.plantColors[i % Self.plantColors.count]

            return PlantGeometry(
                index: i,
                baseX: baseX,
                groundY: groundY,
                stalkHeight: stalkH,
                bloomCenter: CGPoint(x: baseX + sway, y: groundY - stalkH),
                bloomRadius: bloomR,
                utilization: util,
                color: color,
                shortLabel: item.shortLabel,
                label: item.label,
                resetDate: item.bucket.resetsAtDate,
                sway: sway
            )
        }
    }

    private func hoveredPlantIndex(plants: [PlantGeometry]) -> Int? {
        guard let mp = mousePos else { return nil }
        for plant in plants {
            let dx = mp.x - plant.bloomCenter.x
            let dy = mp.y - plant.bloomCenter.y
            if dx * dx + dy * dy < 80 * 80 { return plant.index }
        }
        return nil
    }

    // MARK: - Draw Ground Fog

    private func drawGroundFog(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let groundY = size.height * 0.82
        let fogBands: [(Color, Double)] = [
            (Color(hex: "004D40"), 0.05),
            (Color(hex: "1A0033"), 0.04),
            (Color(hex: "003300"), 0.03),
        ]

        for (i, (color, opacity)) in fogBands.enumerated() {
            let yOff = groundY + Double(i) * size.height * 0.06
            let drift = sin(time * 0.3 + Double(i) * 1.5) * size.width * 0.05

            let rect = CGRect(
                x: drift - size.width * 0.1,
                y: yOff,
                width: size.width * 1.2,
                height: size.height * 0.08
            )

            ctx.drawLayer { fogCtx in
                fogCtx.blendMode = .screen
                fogCtx.fill(
                    Path(rect),
                    with: .linearGradient(
                        Gradient(colors: [.clear, color.opacity(opacity), .clear]),
                        startPoint: CGPoint(x: rect.minX, y: rect.midY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.midY)
                    )
                )
            }
        }
    }

    // MARK: - Draw Mycelium Network

    private func drawMycelium(
        ctx: inout GraphicsContext,
        plants: [PlantGeometry],
        size: CGSize,
        time: Double,
        hoveredIndex: Int?
    ) {
        guard plants.count > 1 else { return }
        let underY = plants[0].groundY + 15

        for i in 0..<(plants.count - 1) {
            let p0 = CGPoint(x: plants[i].baseX, y: underY)
            let p3 = CGPoint(x: plants[i + 1].baseX, y: underY)
            let midX = (p0.x + p3.x) / 2
            let dip = 20.0 + Double(i) * 8
            let cp1 = CGPoint(x: midX - (p3.x - p0.x) * 0.15, y: underY + dip)
            let cp2 = CGPoint(x: midX + (p3.x - p0.x) * 0.15, y: underY + dip)

            let isHovConn = hoveredIndex == i || hoveredIndex == i + 1
            let baseOpacity = isHovConn ? 0.15 : 0.06

            // Dim base stroke
            var basePath = Path()
            basePath.move(to: p0)
            basePath.addCurve(to: p3, control1: cp1, control2: cp2)
            ctx.stroke(basePath, with: .color(Theme.tierLow.opacity(baseOpacity)), lineWidth: 1)

            // Animated pulse traveling along path
            let pulseT = fmod(time * 0.15 + Double(i) * 0.3, 1.0)
            let pulsePos = bezierPoint(t: pulseT, p0: p0, p1: cp1, p2: cp2, p3: p3)
            let pulseR: Double = isHovConn ? 6 : 3
            let pulseOp: Double = isHovConn ? 0.35 : 0.15

            ctx.fill(
                Circle().path(in: CGRect(
                    x: pulsePos.x - pulseR, y: pulsePos.y - pulseR,
                    width: pulseR * 2, height: pulseR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [Theme.tierLow.opacity(pulseOp), .clear]),
                    center: pulsePos,
                    startRadius: 0,
                    endRadius: pulseR
                )
            )
        }
    }

    // MARK: - Draw Stalk

    private func drawStalk(
        ctx: inout GraphicsContext,
        plant: PlantGeometry,
        time: Double,
        isHovered: Bool
    ) {
        let p0 = CGPoint(x: plant.baseX, y: plant.groundY)
        let p3 = plant.bloomCenter
        let cp1 = CGPoint(
            x: plant.baseX + plant.sway * 0.3,
            y: plant.groundY - plant.stalkHeight * 0.35
        )
        let cp2 = CGPoint(
            x: p3.x - plant.sway * 0.2,
            y: p3.y + plant.stalkHeight * 0.25
        )

        let bm = isHovered ? 1.5 : 1.0
        let segments = 25

        // Tapered segments
        for s in 0..<segments {
            let t0 = Double(s) / Double(segments)
            let t1 = Double(s + 1) / Double(segments)
            let pt0 = bezierPoint(t: t0, p0: p0, p1: cp1, p2: cp2, p3: p3)
            let pt1 = bezierPoint(t: t1, p0: p0, p1: cp1, p2: cp2, p3: p3)
            let width = 5.0 - 3.5 * t1

            var seg = Path()
            seg.move(to: pt0)
            seg.addLine(to: pt1)
            ctx.stroke(seg, with: .color(plant.color.opacity(0.5 * bm)), lineWidth: width)
        }

        // Soft glow pass
        ctx.drawLayer { glowCtx in
            glowCtx.blendMode = .screen
            var glowPath = Path()
            glowPath.move(to: p0)
            glowPath.addCurve(to: p3, control1: cp1, control2: cp2)
            glowCtx.stroke(glowPath, with: .color(plant.color.opacity(0.08 * bm)), lineWidth: 10)
        }

        // Branches (2-3)
        let branchCount = 2 + (plant.utilization > 60 ? 1 : 0)
        for b in 0..<branchCount {
            let branchT = 0.3 + Double(b) * 0.2
            let branchBase = bezierPoint(t: branchT, p0: p0, p1: cp1, p2: cp2, p3: p3)
            let side: Double = b % 2 == 0 ? 1 : -1
            let branchLen = plant.stalkHeight * 0.12 + sin(time * 0.7 + Double(b) * 2) * 4
            let angle = -Double.pi / 2 + side * (0.4 + sin(time * 0.3 + Double(b)) * 0.15)
            let branchEnd = CGPoint(
                x: branchBase.x + cos(angle) * branchLen * side,
                y: branchBase.y + sin(angle) * branchLen
            )
            let branchCP = CGPoint(
                x: (branchBase.x + branchEnd.x) / 2 + side * 8,
                y: (branchBase.y + branchEnd.y) / 2 - 5
            )

            var branchPath = Path()
            branchPath.move(to: branchBase)
            branchPath.addQuadCurve(to: branchEnd, control: branchCP)
            ctx.stroke(branchPath, with: .color(plant.color.opacity(0.3 * bm)), lineWidth: 1.5)

            // Glowing tip
            let tipR = 3.0 + sin(time * 2 + Double(b) * 1.5) * 1
            ctx.fill(
                Circle().path(in: CGRect(
                    x: branchEnd.x - tipR, y: branchEnd.y - tipR,
                    width: tipR * 2, height: tipR * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [plant.color.opacity(0.4 * bm), .clear]),
                    center: branchEnd,
                    startRadius: 0,
                    endRadius: tipR
                )
            )
        }
    }

    // MARK: - Draw Tendrils

    private func drawTendrils(
        ctx: inout GraphicsContext,
        plant: PlantGeometry,
        time: Double,
        isHovered: Bool
    ) {
        let count = 2 + Int(plant.utilization / 100.0 * 4)
        let bm = isHovered ? 1.5 : 1.0

        // Stalk control points (same as drawStalk)
        let sP0 = CGPoint(x: plant.baseX, y: plant.groundY)
        let sP3 = plant.bloomCenter
        let sCP1 = CGPoint(
            x: plant.baseX + plant.sway * 0.3,
            y: plant.groundY - plant.stalkHeight * 0.35
        )
        let sCP2 = CGPoint(
            x: sP3.x - plant.sway * 0.2,
            y: sP3.y + plant.stalkHeight * 0.25
        )

        for i in 0..<count {
            let t = 0.15 + Double(i) * 0.7 / Double(max(count, 1))
            let attachPt = bezierPoint(t: t, p0: sP0, p1: sCP1, p2: sCP2, p3: sP3)
            let side: Double = i % 2 == 0 ? 1 : -1
            var tendrilLen = 20.0 + plant.utilization * 0.3 + sin(time * 0.8 + Double(i) * 1.2) * 6

            if isHovered { tendrilLen *= 1.3 }

            // Base outward angle, with gentle animation
            var endAngle = side * (0.6 + sin(time * 0.4 + Double(i)) * 0.3)

            // Bias toward cursor when hovered
            if isHovered, let mp = mousePos {
                let toMouse = atan2(mp.y - attachPt.y, mp.x - attachPt.x)
                endAngle = endAngle * 0.5 + toMouse * 0.5
            }

            let endPt = CGPoint(
                x: attachPt.x + cos(endAngle) * tendrilLen,
                y: attachPt.y + sin(endAngle) * tendrilLen
            )
            let ctrlPt = CGPoint(
                x: (attachPt.x + endPt.x) / 2 + side * 12,
                y: (attachPt.y + endPt.y) / 2 - 8
            )

            var path = Path()
            path.move(to: attachPt)
            path.addQuadCurve(to: endPt, control: ctrlPt)
            ctx.stroke(path, with: .color(plant.color.opacity(0.25 * bm)), lineWidth: 1)

            // Bioluminescent tip — glow
            let tipR = 4.0 + sin(time * 1.5 + Double(i) * 2) * 1.5
            ctx.fill(
                Circle().path(in: CGRect(
                    x: endPt.x - tipR * 1.5, y: endPt.y - tipR * 1.5,
                    width: tipR * 3, height: tipR * 3
                )),
                with: .radialGradient(
                    Gradient(colors: [plant.color.opacity(0.5 * bm), .clear]),
                    center: endPt,
                    startRadius: 0,
                    endRadius: tipR * 1.5
                )
            )

            // Bioluminescent tip — core dot
            ctx.fill(
                Circle().path(in: CGRect(
                    x: endPt.x - tipR * 0.5, y: endPt.y - tipR * 0.5,
                    width: tipR, height: tipR
                )),
                with: .color(plant.color.opacity(0.7 * bm))
            )
        }
    }

    // MARK: - Draw Spores

    private func drawSpores(
        ctx: inout GraphicsContext,
        plants: [PlantGeometry],
        size: CGSize,
        time: Double,
        hoveredIndex: Int?
    ) {
        guard !plants.isEmpty else { return }
        let groundY = size.height * 0.82
        let sporeCount = 40

        for i in 0..<sporeCount {
            let seed = Double(i) * 137.508

            // Deterministic vertical cycling
            let cycleSpeed = 0.02 + fmod(seed, 0.03)
            let rawY = fmod(time * cycleSpeed + seed * 0.1, 1.0)
            let y = groundY - rawY * groundY * 0.9
            let baseX = fmod(seed * 23.1, 1.0) * size.width
            let wander = sin(time * 0.5 + seed) * 15
            var x = baseX + wander

            // Color-match to nearest plant
            var nearestIdx = 0
            var nearestDist = Double.infinity
            for p in plants {
                let d = abs(baseX - p.baseX)
                if d < nearestDist { nearestDist = d; nearestIdx = p.index }
            }
            let color = plants[nearestIdx].color

            // Hover repulsion
            if let mp = mousePos {
                let dx = x - mp.x
                let dy = y - mp.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist < 60 {
                    let push = (60 - dist) / 60.0 * 20
                    x += (dx / max(dist, 1)) * push
                }
            }

            // Fade in/out at edges
            let fade = min(rawY / 0.1, (1 - rawY) / 0.1, 1.0)
            let sporeR = 2.0 + sin(seed + time * 0.8) * 0.8

            // Radial glow
            ctx.fill(
                Circle().path(in: CGRect(
                    x: x - sporeR * 2, y: y - sporeR * 2,
                    width: sporeR * 4, height: sporeR * 4
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.2 * fade), .clear]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: sporeR * 2
                )
            )

            // Core dot
            ctx.fill(
                Circle().path(in: CGRect(
                    x: x - sporeR * 0.5, y: y - sporeR * 0.5,
                    width: sporeR, height: sporeR
                )),
                with: .color(color.opacity(0.5 * fade))
            )
        }
    }

    // MARK: - Draw Labels

    private func drawLabels(ctx: inout GraphicsContext, plants: [PlantGeometry]) {
        for plant in plants {
            let labelY = plant.groundY + 22

            // Short label
            let label = ctx.resolve(
                Text(plant.shortLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(plant.color.opacity(0.7))
            )
            ctx.draw(label, at: CGPoint(x: plant.baseX, y: labelY), anchor: .top)

            // Reset timer
            if let resetDate = plant.resetDate, resetDate > Date() {
                let timer = ctx.resolve(
                    Text(resetDate.countdownString)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(Theme.stardust.opacity(0.35))
                )
                ctx.draw(timer, at: CGPoint(x: plant.baseX, y: labelY + 18), anchor: .top)
            }
        }
    }

    // MARK: - Admin Overlay

    @ViewBuilder
    private var adminOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Token Breakdown")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.stardust.opacity(0.7))

            ForEach(state.tokensByModel, id: \.model) { entry in
                HStack {
                    Text(entry.model)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.stardust.opacity(0.6))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(entry.total.formatted()) tokens")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.stardust)
                        Text("in: \(entry.input.formatted())  out: \(entry.output.formatted())")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.stardust.opacity(0.4))
                    }
                }
            }

            if state.totalCostToday > 0 {
                HStack {
                    Text("Cost today")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.stardust.opacity(0.5))
                    Spacer()
                    Text("$\(String(format: "%.2f", state.totalCostToday))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.outerOrbit)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.stardust.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}
