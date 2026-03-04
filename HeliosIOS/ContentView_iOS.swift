import SwiftUI

struct ContentView_iOS: View {
    let state: UsageState
    let engine: UsageEngine?
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Theme.void.ignoresSafeArea()

            if state.hasSessionConfig {
                AnemoneView_iOS(state: state)

                // Settings gear — top trailing
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.white.opacity(0.1))
                                        .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
                                )
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }
                    Spacer()
                }
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
                            .background(Theme.sessionOrbit.opacity(0.3), in: Capsule())
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                    }

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView_iOS(state: state, engine: engine)
        }
    }
}
