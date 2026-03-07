import AppKit
import SwiftUI

extension Notification.Name {
    static let heliosLiteModeChanged = Notification.Name("heliosLiteModeChanged")
}

final class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var renderTimer: Timer?
    private var state: UsageState?
    private var engine: UsageEngine?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        startRenderTimer()

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleModeChange),
            name: .heliosLiteModeChanged, object: nil
        )
    }

    func configure(state: UsageState, engine: UsageEngine) {
        self.state = state
        self.engine = engine
        updateStatusItemImage()

        if state.liteMode {
            DispatchQueue.main.async { self.closeDashboard() }
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(statusItemClicked(_:))
        statusItem?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusItemImage()
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        showMenu()
    }

    private func showMenu() {
        let menu = NSMenu()
        let isLite = state?.liteMode ?? false

        if isLite {
            let item = NSMenuItem(title: "Open Dashboard", action: #selector(switchToOrrery), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        } else {
            let showItem = NSMenuItem(title: "Show Dashboard", action: #selector(openDashboard), keyEquivalent: "")
            showItem.target = self
            menu.addItem(showItem)

            let liteItem = NSMenuItem(title: "Switch to Lite Mode", action: #selector(switchToLite), keyEquivalent: "")
            liteItem.target = self
            menu.addItem(liteItem)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Helios", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        DispatchQueue.main.async { self.statusItem?.menu = nil }
    }

    // MARK: - Actions

    @objc private func switchToOrrery() {
        state?.liteMode = false
        updateStatusItemImage()
        openDashboard()
    }

    @objc private func switchToLite() {
        state?.liteMode = true
        updateStatusItemImage()
        closeDashboard()
    }

    @objc func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "Helios" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func closeDashboard() {
        for window in NSApp.windows where window.title == "Helios" {
            window.close()
        }
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func refresh() {
        guard let engine else { return }
        Task { await engine.refresh() }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func handleModeChange() {
        updateStatusItemImage()
        if state?.liteMode == true {
            closeDashboard()
        }
    }

    // MARK: - Render Timer

    private func startRenderTimer() {
        renderTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateStatusItemImage()
        }
    }

    // MARK: - Status Item Rendering

    private func updateStatusItemImage() {
        guard let state, state.hasSessionConfig, state.error == nil else {
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
        let resetAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        let metrics: [(label: String, pct: Int, reset: String)] = [
            ("5h", Int(state.fiveHourPct), state.fiveHourResetString),
            ("7d", Int(state.sevenDayPct), state.sevenDayResetString),
        ]

        for (i, metric) in metrics.enumerated() {
            if i > 0 {
                str.append(NSAttributedString(string: "  ", attributes: sepAttrs))
            }
            str.append(NSAttributedString(string: "\(metric.label) ", attributes: labelAttrs))
            str.append(NSAttributedString(string: "\(metric.pct)%", attributes: pctAttrs(metric.pct)))

            if state.liteMode && !metric.reset.isEmpty {
                str.append(NSAttributedString(string: " \(metric.reset)", attributes: resetAttrs))
            }
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
}
