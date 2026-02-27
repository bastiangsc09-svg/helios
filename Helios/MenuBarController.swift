import AppKit
import SwiftUI

// MARK: - Menu Bar Controller (AppDelegate)

final class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var renderTimer: Timer?
    private var state: UsageState?
    private var engine: UsageEngine?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        startRenderTimer()
    }

    func configure(state: UsageState, engine: UsageEngine) {
        self.state = state
        self.engine = engine
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.action = #selector(togglePopover)
        statusItem?.button?.target = self
        updateStatusItemImage()
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.contentSize = NSSize(width: 280, height: 320)
        popover?.animates = true
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let state, let engine {
                popover.contentViewController = NSHostingController(
                    rootView: MenuBarPopoverContent(state: state, engine: engine)
                        .frame(width: 280)
                )
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Render Timer

    private func startRenderTimer() {
        renderTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateStatusItemImage()
        }
    }

    private func updateStatusItemImage() {
        guard let state else {
            statusItem?.button?.image = renderText("--", color: .tertiaryLabelColor)
            return
        }

        guard state.hasSessionConfig, state.error == nil else {
            statusItem?.button?.image = renderText("--", color: .tertiaryLabelColor)
            return
        }

        let str = NSMutableAttributedString()
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        let sepAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]

        let metrics: [(label: String, pct: Int)] = [
            ("5h", Int(state.fiveHourPct)),
            ("7d", Int(state.sevenDayPct)),
        ]

        for (i, metric) in metrics.enumerated() {
            if i > 0 {
                str.append(NSAttributedString(string: "  ", attributes: sepAttrs))
            }
            str.append(NSAttributedString(string: "\(metric.label) ", attributes: labelAttrs))
            str.append(NSAttributedString(string: "\(metric.pct)%", attributes: pctAttrs(metric.pct)))
        }

        let size = str.size()
        let imgSize = NSSize(width: ceil(size.width) + 2, height: 22)
        let img = NSImage(size: imgSize)
        img.lockFocus()
        str.draw(at: NSPoint(x: 1, y: (22 - size.height) / 2))
        img.unlockFocus()
        img.isTemplate = false
        statusItem?.button?.image = img
    }

    private func pctAttrs(_ pct: Int) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: nsColorForPct(pct),
        ]
    }

    private func nsColorForPct(_ pct: Int) -> NSColor {
        if pct < 60 { return NSColor(red: 0.13, green: 0.77, blue: 0.29, alpha: 1) }
        if pct < 85 { return NSColor(red: 0.98, green: 0.60, blue: 0.09, alpha: 1) }
        return NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)
    }

    private func renderText(_ text: String, color: NSColor) -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: color,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        let img = NSImage(size: NSSize(width: ceil(size.width) + 2, height: 22))
        img.lockFocus()
        str.draw(at: NSPoint(x: 1, y: (22 - size.height) / 2))
        img.unlockFocus()
        img.isTemplate = false
        return img
    }

    func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "Helios" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - Popover Content

struct MenuBarPopoverContent: View {
    let state: UsageState
    let engine: UsageEngine

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Helios")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if state.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Metrics
            VStack(spacing: 8) {
                popoverMetricRow(label: "Session (5h)", pct: Int(state.fiveHourPct), reset: state.fiveHourResetString)
                popoverMetricRow(label: "Weekly (7d)", pct: Int(state.sevenDayPct), reset: state.sevenDayResetString)
                popoverMetricRow(label: "Sonnet", pct: Int(state.sonnetPct), reset: nil)
                if state.opusPct > 0 {
                    popoverMetricRow(label: "Opus", pct: Int(state.opusPct), reset: nil)
                }
            }
            .padding(.horizontal, 16)

            // Last update
            if let date = state.lastFetch {
                Text("Updated \(date.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 10)
            }

            Divider()
                .overlay(Color.white.opacity(0.08))
                .padding(.top, 10)

            // Actions
            HStack(spacing: 0) {
                popoverAction(icon: "arrow.clockwise", label: "Refresh") {
                    Task { await engine.refresh() }
                }
                popoverAction(icon: "macwindow", label: "Dashboard") {
                    (NSApp.delegate as? MenuBarController)?.openDashboard()
                }
                popoverAction(icon: "power", label: "Quit") {
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)))
    }

    private func popoverMetricRow(label: String, pct: Int, reset: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if let reset, !reset.isEmpty {
                    Text("resets in \(reset)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                }
                Text("\(pct)%")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(colorForPct(pct))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForPct(pct))
                        .frame(width: max(0, geo.size.width * CGFloat(pct) / 100), height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private func popoverAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.5))
    }

    private func colorForPct(_ pct: Int) -> Color {
        if pct < 60 { return Color(red: 0.13, green: 0.77, blue: 0.29) }
        if pct < 85 { return Color(red: 0.98, green: 0.60, blue: 0.09) }
        return Color(red: 0.94, green: 0.27, blue: 0.27)
    }
}
