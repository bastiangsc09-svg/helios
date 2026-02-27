import Foundation

// MARK: - Session Cookie API Response

struct UsageResponse: Codable {
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?
    let sevenDaySonnet: UsageBucket?
    let sevenDayOauthApps: UsageBucket?
    let sevenDayOpus: UsageBucket?
    let sevenDayCowork: UsageBucket?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayOpus = "seven_day_opus"
        case sevenDayCowork = "seven_day_cowork"
    }

    init(fiveHour: UsageBucket? = nil, sevenDay: UsageBucket? = nil, sevenDaySonnet: UsageBucket? = nil,
         sevenDayOauthApps: UsageBucket? = nil, sevenDayOpus: UsageBucket? = nil, sevenDayCowork: UsageBucket? = nil) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.sevenDaySonnet = sevenDaySonnet
        self.sevenDayOauthApps = sevenDayOauthApps
        self.sevenDayOpus = sevenDayOpus
        self.sevenDayCowork = sevenDayCowork
    }

    // Tolerant decoding: broken buckets become nil
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fiveHour = try? container.decode(UsageBucket.self, forKey: .fiveHour)
        sevenDay = try? container.decode(UsageBucket.self, forKey: .sevenDay)
        sevenDaySonnet = try? container.decode(UsageBucket.self, forKey: .sevenDaySonnet)
        sevenDayOauthApps = try? container.decode(UsageBucket.self, forKey: .sevenDayOauthApps)
        sevenDayOpus = try? container.decode(UsageBucket.self, forKey: .sevenDayOpus)
        sevenDayCowork = try? container.decode(UsageBucket.self, forKey: .sevenDayCowork)
    }

    /// All non-nil buckets as labeled pairs
    var allBuckets: [(label: String, shortLabel: String, bucket: UsageBucket)] {
        var result: [(String, String, UsageBucket)] = []
        if let b = fiveHour { result.append(("Session (5h)", "5h", b)) }
        if let b = sevenDay { result.append(("Weekly (7d)", "7d", b)) }
        if let b = sevenDaySonnet { result.append(("Sonnet", "S", b)) }
        if let b = sevenDayOpus { result.append(("Opus", "O", b)) }
        if let b = sevenDayOauthApps { result.append(("OAuth Apps", "OA", b)) }
        if let b = sevenDayCowork { result.append(("Cowork", "CW", b)) }
        return result
    }
}

struct UsageBucket: Codable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetsAtDate: Date? {
        guard let resetsAt else { return nil }
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFrac.date(from: resetsAt) { return d }
        let noFrac = ISO8601DateFormatter()
        noFrac.formatOptions = [.withInternetDateTime]
        return noFrac.date(from: resetsAt)
    }
}

// MARK: - Admin API Models

struct AdminUsageReport: Codable {
    let data: [AdminUsageBucket]
}

struct AdminUsageBucket: Codable {
    let snapshotAt: String
    let model: String?
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case snapshotAt = "snapshot_at"
        case model
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }

    var totalTokens: Int {
        inputTokens + outputTokens + (cacheCreationInputTokens ?? 0) + (cacheReadInputTokens ?? 0)
    }
}

struct AdminCostReport: Codable {
    let data: [AdminCostBucket]
}

struct AdminCostBucket: Codable {
    let snapshotAt: String
    let amountCents: Double

    enum CodingKeys: String, CodingKey {
        case snapshotAt = "snapshot_at"
        case amountCents = "amount_cents"
    }
}

struct AdminOrgInfo: Codable {
    let id: String
    let name: String
    let planType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case planType = "plan_type"
    }
}

// MARK: - Cached Data

struct CachedUsage: Codable {
    let usage: UsageResponse
    let adminTokens: [AdminUsageBucket]?
    let adminCosts: [AdminCostBucket]?
    let fetchDate: Date
}

// MARK: - Usage Tier

enum UsageTier {
    case low      // < 60%
    case moderate // 60-84%
    case critical // >= 85%

    init(utilization: Double) {
        if utilization < 60 { self = .low }
        else if utilization < 85 { self = .moderate }
        else { self = .critical }
    }
}

// MARK: - Refresh Interval

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .oneMinute: "1 min"
        case .twoMinutes: "2 min"
        case .fiveMinutes: "5 min"
        }
    }
}
