import SwiftUI

struct SettingsView: View {
    let state: UsageState
    let engine: UsageEngine?

    @State private var sessionKey: String = ""
    @State private var orgID: String = ""
    @State private var adminKey: String = ""
    @State private var refreshInterval: RefreshInterval = .twoMinutes
    @State private var testResult: (success: Bool, message: String)?
    @State private var adminTestResult: (success: Bool, message: String)?
    @State private var isTesting = false
    @State private var isTestingAdmin = false
    @State private var detectedBrowsers: [DetectedBrowser] = []
    @State private var importResult: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                sessionSection
                adminSection
                refreshSection
            }
            .formStyle(.grouped)
            .onAppear { loadFromState() }
        }
        .frame(width: 480, height: 520)
    }

    // MARK: - Session Cookie Section

    private var sessionSection: some View {
        Section {
            // Browser auto-import
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Auto-import from browser")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button("Detect Browsers") {
                        detectedBrowsers = BrowserCookieReader.detectBrowsers()
                    }
                    .controlSize(.small)
                }

                if !detectedBrowsers.isEmpty {
                    ForEach(detectedBrowsers) { browser in
                        Button {
                            importFromBrowser(browser)
                        } label: {
                            Label(browser.name, systemImage: browser.icon)
                        }
                        .controlSize(.small)
                    }
                }

                if let result = importResult {
                    Text(result)
                        .font(.system(size: 11))
                        .foregroundStyle(result.contains("Success") ? .green : .red)
                }
            }

            Divider()

            // Manual entry
            LabeledContent("Session Key") {
                SecureField("sk-ant-sid01-...", text: $sessionKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
            }

            LabeledContent("Organization ID") {
                TextField("org ID from cookie", text: $orgID)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
            }

            HStack {
                Button("Test Connection") {
                    Task { await testSession() }
                }
                .disabled(sessionKey.isEmpty || orgID.isEmpty || isTesting)
                .controlSize(.small)

                if isTesting {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                }

                if let result = testResult {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.success ? .green : .red)
                    Text(result.message)
                        .font(.system(size: 11))
                        .foregroundStyle(result.success ? .green : .red)
                }

                Spacer()

                Button("Save") {
                    save()
                }
                .controlSize(.small)
                .disabled(sessionKey.isEmpty || orgID.isEmpty)
            }
        } header: {
            Text("Session Cookie (Required)")
        }
    }

    // MARK: - Admin API Section

    private var adminSection: some View {
        Section {
            LabeledContent("Admin API Key") {
                SecureField("sk-ant-admin-... (optional)", text: $adminKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
            }

            HStack {
                Button("Test Admin Key") {
                    Task { await testAdmin() }
                }
                .disabled(adminKey.isEmpty || isTestingAdmin)
                .controlSize(.small)

                if isTestingAdmin {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                }

                if let result = adminTestResult {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.success ? .green : .red)
                    Text(result.message)
                        .font(.system(size: 11))
                        .foregroundStyle(result.success ? .green : .red)
                }
            }

            Text("Provides actual token counts + costs per model. Get from console.anthropic.com → Settings → Admin API Keys.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        } header: {
            Text("Admin API (Optional, Enhanced)")
        }
    }

    // MARK: - Refresh Section

    private var refreshSection: some View {
        Section {
            Picker("Refresh Interval", selection: $refreshInterval) {
                ForEach(RefreshInterval.allCases) { interval in
                    Text(interval.label).tag(interval)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Refresh")
        }
    }

    // MARK: - Actions

    private func loadFromState() {
        sessionKey = state.sessionKey
        orgID = state.organizationID
        adminKey = state.adminAPIKey
        refreshInterval = state.refreshInterval
    }

    private func save() {
        engine?.updateConfig(sessionKey: sessionKey, orgID: orgID, adminKey: adminKey, interval: refreshInterval)
    }

    private func testSession() async {
        isTesting = true
        testResult = nil
        if let engine {
            testResult = await engine.testSessionConnection(sessionKey: sessionKey, orgID: orgID)
        }
        isTesting = false
    }

    private func testAdmin() async {
        isTestingAdmin = true
        adminTestResult = nil
        if let engine {
            adminTestResult = await engine.testAdminKey(adminKey)
        }
        isTestingAdmin = false
    }

    private func importFromBrowser(_ browser: DetectedBrowser) {
        importResult = nil
        switch BrowserCookieReader.importCookies(from: browser) {
        case .success(let result):
            sessionKey = result.sessionKey
            orgID = result.organizationID
            importResult = "Success — imported from \(result.browser)"
            save()
        case .failure(let error):
            importResult = error.localizedDescription
        }
    }
}
