import Foundation

// MARK: - Usage Engine (API Fetching + Timer + Cache + Config)

@MainActor
final class UsageEngine {
    let state: UsageState
    private var timer: Timer?
    private let cacheURL: URL

    init(state: UsageState) {
        self.state = state
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Helios")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.cacheURL = appSupport.appendingPathComponent("cache.json")

        loadConfig()
        #if os(macOS)
        migrateOldTokenEaterConfig()
        #endif
        loadCache()
        startTimer()
        Task { await refresh() }
    }

    // MARK: - Public

    func refresh() async {
        guard state.hasSessionConfig else { return }
        state.isLoading = true
        state.error = nil
        defer { state.isLoading = false }

        // Session cookie fetch
        do {
            let usage = try await fetchSessionUsage()
            state.usage = usage
            state.lastFetch = Date()
        } catch {
            state.error = error.localizedDescription
        }

        // Admin API fetch (if configured)
        if state.hasAdminConfig {
            do {
                let (tokens, costs) = try await fetchAdminData()
                state.adminTokens = tokens
                state.adminCosts = costs
                state.lastAdminFetch = Date()
            } catch {
                // Admin errors are non-fatal — session data still works
            }
        }

        saveCache()
    }

    func testSessionConnection(sessionKey: String, orgID: String) async -> (success: Bool, message: String) {
        guard let url = URL(string: "https://claude.ai/api/organizations/\(orgID)/usage") else {
            return (false, "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (false, "Invalid response")
            }
            if http.statusCode == 200 {
                guard let usage = try? JSONDecoder().decode(UsageResponse.self, from: data) else {
                    return (false, "Unsupported plan or unexpected response")
                }
                let pct = Int(usage.fiveHour?.utilization ?? 0)
                return (true, "Connected — session at \(pct)%")
            } else if http.statusCode == 401 || http.statusCode == 403 {
                return (false, "Session expired (HTTP \(http.statusCode))")
            } else {
                return (false, "HTTP \(http.statusCode)")
            }
        } catch {
            return (false, "Network error: \(error.localizedDescription)")
        }
    }

    func testAdminKey(_ key: String) async -> (success: Bool, message: String) {
        guard let url = URL(string: "https://api.anthropic.com/v1/organizations/me") else {
            return (false, "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (false, "Invalid response")
            }
            if http.statusCode == 200 {
                if let org = try? JSONDecoder().decode(AdminOrgInfo.self, from: data) {
                    state.adminOrgName = org.name
                    return (true, "Connected — org: \(org.name)")
                }
                return (true, "Connected")
            } else {
                return (false, "HTTP \(http.statusCode)")
            }
        } catch {
            return (false, "Network error: \(error.localizedDescription)")
        }
    }

    func updateConfig(sessionKey: String, orgID: String, adminKey: String, interval: RefreshInterval) {
        state.sessionKey = sessionKey
        state.organizationID = orgID
        state.adminAPIKey = adminKey
        state.refreshInterval = interval
        saveConfig()
        restartTimer()
        Task { await refresh() }
    }

    // MARK: - Session Cookie API

    private func fetchSessionUsage() async throws -> UsageResponse {
        guard let url = URL(string: "https://claude.ai/api/organizations/\(state.organizationID)/usage") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sessionKey=\(state.sessionKey)", forHTTPHeaderField: "Cookie")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(UsageResponse.self, from: data)
        case 401, 403:
            throw NSError(domain: "Helios", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Session expired — re-import browser cookies"])
        default:
            throw NSError(domain: "Helios", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
    }

    // MARK: - Admin API

    private func fetchAdminData() async throws -> ([AdminUsageBucket], [AdminCostBucket]) {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        let start = fmt.string(from: startOfDay)
        let end = fmt.string(from: now)

        async let tokens = fetchAdminUsage(start: start, end: end)
        async let costs = fetchAdminCosts(start: start, end: end)
        return try await (tokens, costs)
    }

    private func fetchAdminUsage(start: String, end: String) async throws -> [AdminUsageBucket] {
        let urlStr = "https://api.anthropic.com/v1/organizations/usage_report/messages?starting_at=\(start)&ending_at=\(end)&bucket_width=1h&group_by[]=model"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue(state.adminAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, _) = try await URLSession.shared.data(for: request)
        let report = try JSONDecoder().decode(AdminUsageReport.self, from: data)
        return report.data
    }

    private func fetchAdminCosts(start: String, end: String) async throws -> [AdminCostBucket] {
        let urlStr = "https://api.anthropic.com/v1/organizations/cost_report?starting_at=\(start)&ending_at=\(end)&bucket_width=1d"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue(state.adminAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, _) = try await URLSession.shared.data(for: request)
        let report = try JSONDecoder().decode(AdminCostReport.self, from: data)
        return report.data
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(state.refreshInterval.rawValue), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    private func restartTimer() {
        timer?.invalidate()
        startTimer()
    }

    // MARK: - Config Persistence (UserDefaults)

    private func saveConfig() {
        let ud = UserDefaults.standard
        ud.set(state.sessionKey, forKey: "sessionKey")
        ud.set(state.organizationID, forKey: "organizationID")
        ud.set(state.adminAPIKey, forKey: "adminAPIKey")
        ud.set(state.refreshInterval.rawValue, forKey: "refreshInterval")
    }

    private func loadConfig() {
        let ud = UserDefaults.standard
        state.sessionKey = ud.string(forKey: "sessionKey") ?? ""
        state.organizationID = ud.string(forKey: "organizationID") ?? ""
        state.adminAPIKey = ud.string(forKey: "adminAPIKey") ?? ""
        if let raw = ud.object(forKey: "refreshInterval") as? Int,
           let interval = RefreshInterval(rawValue: raw) {
            state.refreshInterval = interval
        }
    }

    // MARK: - Migrate from old token-eater

    #if os(macOS)
    private func migrateOldTokenEaterConfig() {
        guard !state.hasSessionConfig else { return } // Already configured, skip

        // Old token-eater stored config at this path
        let oldConfigPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.claudeusagewidget.app.widget/Data/Library/Application Support/claude-usage-config.json")

        guard let data = try? Data(contentsOf: oldConfigPath),
              let oldConfig = try? JSONDecoder().decode(OldSharedConfig.self, from: data),
              !oldConfig.sessionKey.isEmpty, !oldConfig.organizationID.isEmpty else { return }

        state.sessionKey = oldConfig.sessionKey
        state.organizationID = oldConfig.organizationID
        saveConfig()

        // Also try to migrate cached usage
        let oldCachePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.claudeusagewidget.app.widget/Data/Library/Application Support/claude-usage-cache.json")
        if let cacheData = try? Data(contentsOf: oldCachePath),
           let oldCache = try? JSONDecoder().decode(OldCachedUsage.self, from: cacheData) {
            state.usage = oldCache.usage
            state.lastFetch = oldCache.fetchDate
        }
    }
    #endif

    // MARK: - Cache Persistence

    private func saveCache() {
        guard let usage = state.usage else { return }
        let cached = CachedUsage(
            usage: usage,
            adminTokens: state.adminTokens.isEmpty ? nil : state.adminTokens,
            adminCosts: state.adminCosts.isEmpty ? nil : state.adminCosts,
            fetchDate: Date()
        )
        try? JSONEncoder().encode(cached).write(to: cacheURL)
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cached = try? JSONDecoder().decode(CachedUsage.self, from: data) else { return }
        state.usage = cached.usage
        state.adminTokens = cached.adminTokens ?? []
        state.adminCosts = cached.adminCosts ?? []
        state.lastFetch = cached.fetchDate
    }
}

// MARK: - Old token-eater config format (for migration)

#if os(macOS)
private struct OldSharedConfig: Codable {
    var sessionKey: String
    var organizationID: String
}

private struct OldCachedUsage: Codable {
    let usage: UsageResponse
    let fetchDate: Date
}
#endif
