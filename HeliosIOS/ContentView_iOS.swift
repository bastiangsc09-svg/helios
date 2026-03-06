import SwiftUI

struct ContentView_iOS: View {
    let state: UsageState
    let engine: UsageEngine?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.void.ignoresSafeArea()

                if state.hasSessionConfig {
                    AnemoneView_iOS(state: state)
                } else {
                    // Setup prompt
                    VStack(spacing: 24) {
                        Spacer()

                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Theme.nucleusCorona, Theme.nucleusWarm],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )

                        Text("Helios")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundStyle(Theme.stardust)

                        Text("Scan a QR code from Helios\non your Mac to connect.")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.stardust.opacity(0.6))
                            .multilineTextAlignment(.center)

                        Button {
                            showSettings = true
                        } label: {
                            Label("Connect", systemImage: "qrcode.viewfinder")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(Theme.sessionOrbit.opacity(0.2), in: Capsule())
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
                        }

                        Spacer()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarVisibility(state.hasSessionConfig ? .visible : .hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView_iOS(state: state, engine: engine)
        }
    }
}
