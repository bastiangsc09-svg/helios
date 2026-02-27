import SwiftUI

enum DashboardTab: String, CaseIterable {
    case orrery = "Orrery"
    case pulse = "Pulse"
    case breakdown = "Breakdown"
}

struct ContentView: View {
    let state: UsageState
    let engine: UsageEngine?
    @State private var selectedTab: DashboardTab = .orrery
    @State private var showSettings = false
    @Namespace private var navNamespace
    @State private var navHovered = false

    var body: some View {
        ZStack {
            Theme.void.ignoresSafeArea()

            if !state.hasSessionConfig && !showSettings {
                // First-launch: no config yet — prompt to set up
                setupPrompt
            } else if showSettings {
                SettingsView(state: state, engine: engine)
            } else {
                // All views stay alive — just toggle visibility
                OrreryView(state: state)
                    .opacity(selectedTab == .orrery ? 1 : 0)
                    .allowsHitTesting(selectedTab == .orrery)
                PulseView(state: state)
                    .opacity(selectedTab == .pulse ? 1 : 0)
                    .allowsHitTesting(selectedTab == .pulse)
                BreakdownView(state: state)
                    .opacity(selectedTab == .breakdown ? 1 : 0)
                    .allowsHitTesting(selectedTab == .breakdown)

                // NavDots overlay at bottom — visible on hover
                VStack {
                    Spacer()
                    NavDots(selectedTab: $selectedTab, namespace: navNamespace)
                        .padding(.bottom, 20)
                        .opacity(navHovered ? 1 : 0)
                        .animation(.easeInOut(duration: 0.25), value: navHovered)
                }
                .onHover { hovering in
                    navHovered = hovering
                }
            }

            // Gear button (top-right) — always visible except during setup prompt
            if state.hasSessionConfig || showSettings {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSettings.toggle()
                            }
                        } label: {
                            Image(systemName: showSettings ? "xmark.circle.fill" : "gearshape.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.stardust.opacity(0.4))
                                .padding(10)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - First-Launch Setup Prompt

    private var setupPrompt: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Helios")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(Theme.stardust)

            Text("Ambient Claude usage dashboard")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.stardust.opacity(0.5))

            VStack(spacing: 8) {
                Text("To get started, connect your Claude account.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.stardust.opacity(0.4))
                Text("You can import cookies from your browser or enter them manually.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.stardust.opacity(0.4))
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings = true
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Theme.sessionOrbit.opacity(0.3))
                            .overlay(Capsule().strokeBorder(Theme.sessionOrbit.opacity(0.5), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}
