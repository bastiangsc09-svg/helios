import SwiftUI

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: Double
        switch hex.count {
        case 6:
            (r, g, b, a) = (
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255,
                1
            )
        case 8:
            (r, g, b, a) = (
                Double((int >> 24) & 0xFF) / 255,
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255
            )
        default:
            (r, g, b, a) = (0, 0, 0, 1)
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }

    /// Linear interpolation between two colors
    static func lerp(_ a: Color, _ b: Color, t: Double) -> Color {
        let t = max(0, min(1, t))
        let ca = NSColor(a).usingColorSpace(.deviceRGB) ?? NSColor.white
        let cb = NSColor(b).usingColorSpace(.deviceRGB) ?? NSColor.white
        return Color(
            red: ca.redComponent + (cb.redComponent - ca.redComponent) * t,
            green: ca.greenComponent + (cb.greenComponent - ca.greenComponent) * t,
            blue: ca.blueComponent + (cb.blueComponent - ca.blueComponent) * t,
            opacity: ca.alphaComponent + (cb.alphaComponent - ca.alphaComponent) * t
        )
    }

    /// Returns tier-appropriate color for a utilization percentage
    static func forUtilization(_ pct: Double) -> Color {
        if pct < 60 { return Theme.tierLow }
        if pct < 85 { return Theme.tierModerate }
        return Theme.tierCritical
    }

}

// MARK: - Date Countdown

extension Date {
    /// Human-readable countdown from now to this date (e.g. "2h 15m")
    var countdownString: String {
        let diff = self.timeIntervalSinceNow
        guard diff > 0 else { return "now" }
        let h = Int(diff) / 3600
        let m = (Int(diff) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
