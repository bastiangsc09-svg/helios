import SwiftUI

struct PulseStatCard: View {
    let label: String
    let value: String
    let detail: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color.opacity(0.7))

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            if let detail {
                Text(detail)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Theme.stardust.opacity(0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(color.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
