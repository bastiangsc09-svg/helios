import SwiftUI

enum Theme {
    // Core
    static let void = Color(hex: "08080C")
    static let nebulaDark = Color(hex: "0D0D1A")
    static let stardust = Color(hex: "E8E8F0")

    // Usage tier colors (space-themed)
    static let tierLow = Color(hex: "21C45D")       // solid green — calm
    static let tierModerate = Color(hex: "FFD54F")   // gold — warming
    static let tierCritical = Color(hex: "FF4081")   // hot pink — urgent

    // Orbital identity colors
    static let sessionOrbit = Color(hex: "00E5FF")   // cyan — 5h session
    static let weeklyOrbit = Color(hex: "B388FF")    // lavender — 7d all-models
    static let outerOrbit = Color(hex: "FFD54F")     // gold — Sonnet/Opus outer

    // Tentacle gradients (base → mid → tip)
    static let tentacleCyanMid = Color(hex: "0080A0")
    static let tentacleCyanBase = Color(hex: "003040")
    static let tentacleLavenderMid = Color(hex: "7B5EBF")
    static let tentacleLavenderBase = Color(hex: "2D1854")
    static let tentacleGoldMid = Color(hex: "CC9A20")
    static let tentacleGoldBase = Color(hex: "4D3800")

    // Nucleus gradient
    static let nucleusCool = Color(hex: "6366F1")    // indigo (low usage)
    static let nucleusWarm = Color(hex: "FF8F00")    // amber (moderate)
    static let nucleusHot = Color(hex: "EF4444")     // red (critical)
    static let nucleusCorona = Color(hex: "FFF9C4")  // pale yellow core

    // Pulse waveform colors
    static let pulseSession = Color(hex: "00E5FF")
    static let pulseWeekly = Color(hex: "B388FF")
    static let pulseSonnet = Color(hex: "FFD54F")
    static let pulseOpus = Color(hex: "FF4081")

    // Typography
    static let displayFont = Font.system(size: 48, weight: .ultraLight, design: .default)
    static let captionFont = Font.system(size: 12, weight: .light, design: .monospaced)
    static let labelFont = Font.system(size: 14, weight: .regular, design: .rounded)
    static let readoutFont = Font.system(size: 13, weight: .bold, design: .monospaced)
}
