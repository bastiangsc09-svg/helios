import SwiftUI

struct PulseStatCard: View {
    let label: String
    let value: String
    let detail: String?
    let color: Color

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.6), radius: 3)

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(color.opacity(0.85))

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.stardust)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Capsule()
                        .strokeBorder(color.opacity(isHovered ? 0.25 : 0.1), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(isHovered ? 0.35 : 0.15), radius: isHovered ? 10 : 4)
        .overlay(alignment: .top) {
            if isHovered, let detail {
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.stardust.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                    )
                    .offset(y: -28)
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .bottom)))
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
