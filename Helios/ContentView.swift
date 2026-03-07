import SwiftUI

struct ContentView: View {
    let state: UsageState
    let engine: UsageEngine?
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Theme.void.ignoresSafeArea()

            if !state.hasSessionConfig && !showSettings {
                setupPrompt
            } else if showSettings {
                SettingsView(state: state, engine: engine)
            } else {
                OrreryView(state: state)
            }

            // Gear button (top-right)
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
