import SwiftUI

struct GlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: radius)
            .shadow(color: color.opacity(opacity * 0.5), radius: radius * 2)
    }
}

extension View {
    func glow(color: Color, radius: CGFloat = 10, opacity: Double = 0.6) -> some View {
        modifier(GlowModifier(color: color, radius: radius, opacity: opacity))
    }
}
