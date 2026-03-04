import SwiftUI

struct SettingsView_iOS: View {
    let state: UsageState
    let engine: UsageEngine?
    @Environment(\.dismiss) private var dismiss

    @State private var sessionKey: String = ""
    @State private var orgID: String = ""
    @State private var refreshInterval: RefreshInterval = .twoMinutes
    @State private var showScanner = false
    @State private var testResult: (success: Bool, message: String)?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.void.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // QR Scan card
                        qrScanCard

                        // Manual entry card
                        manualEntryCard

                        // Refresh interval card
                        refreshCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.sessionOrbit)
                }
            }
            .onAppear { loadFromState() }
            .sheet(isPresented: $showScanner) {
                QRScannerView { payload in
                    handleQRPayload(payload)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - QR Scan Card

    private var qrScanCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 40))
                .foregroundStyle(Theme.sessionOrbit)

            Text("Scan QR from Mac")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.stardust)

            Text("Open Helios on your Mac → Settings\n→ Share to iOS → scan the QR code")
                .font(.system(size: 13))
                .foregroundStyle(Theme.stardust.opacity(0.6))
                .multilineTextAlignment(.center)

            Button {
                showScanner = true
            } label: {
                Label("Scan QR Code", systemImage: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.sessionOrbit.opacity(0.3), in: Capsule())
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
    }

    // MARK: - Manual Entry Card

    private var manualEntryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Manual Entry")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.stardust)

            VStack(alignment: .leading, spacing: 6) {
                Text("Session Key")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.stardust.opacity(0.6))
                SecureField("sk-ant-sid01-...", text: $sessionKey)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Organization ID")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.stardust.opacity(0.6))
                TextField("org ID from cookie", text: $orgID)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            HStack {
                Button {
                    Task { await testConnection() }
                } label: {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView().scaleEffect(0.7)
                        }
                        Text("Test")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                }
                .disabled(sessionKey.isEmpty || orgID.isEmpty || isTesting)

                if let result = testResult {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.success ? .green : .red)
                    Text(result.message)
                        .font(.system(size: 11))
                        .foregroundStyle(result.success ? .green : .red)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    save()
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    .background(Theme.sessionOrbit.opacity(0.3), in: Capsule())
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                }
                .disabled(sessionKey.isEmpty || orgID.isEmpty)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
    }

    // MARK: - Refresh Card

    private var refreshCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Refresh Interval")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.stardust)

            Picker("Interval", selection: $refreshInterval) {
                ForEach(RefreshInterval.allCases) { interval in
                    Text(interval.label).tag(interval)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: refreshInterval) {
                save()
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
    }

    // MARK: - Actions

    private func loadFromState() {
        sessionKey = state.sessionKey
        orgID = state.organizationID
        refreshInterval = state.refreshInterval
    }

    private func save() {
        engine?.updateConfig(sessionKey: sessionKey, orgID: orgID, adminKey: "", interval: refreshInterval)
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil
        if let engine {
            testResult = await engine.testSessionConnection(sessionKey: sessionKey, orgID: orgID)
        }
        isTesting = false
    }

    private func handleQRPayload(_ payload: [String: Any]) {
        guard let key = payload["sessionKey"] as? String,
              let org = payload["organizationID"] as? String else { return }
        sessionKey = key
        orgID = org
        save()
        dismiss()
    }
}
