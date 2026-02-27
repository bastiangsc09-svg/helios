import SwiftUI

struct NavDots: View {
    @Binding var selectedTab: DashboardTab
    var namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 16) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                ZStack {
                    if selectedTab == tab {
                        Circle()
                            .fill(Theme.stardust.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .blur(radius: 4)
                            .matchedGeometryEffect(id: "halo", in: namespace)
                    }

                    Circle()
                        .fill(selectedTab == tab ? Theme.stardust : Theme.stardust.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                .frame(width: 24, height: 24)
                .contentShape(Circle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(0.5)
        )
    }
}
