import Foundation
import SwiftUI

// MARK: - Usage State (Single Source of Truth)

@Observable
final class UsageState {
    // Session cookie data
    var usage: UsageResponse?
    var lastFetch: Date?

    // Admin API data
    var adminTokens: [AdminUsageBucket] = []
    var adminCosts: [AdminCostBucket] = []
    var adminOrgName: String?

    // Status
    var isLoading = false
    var error: String?
    var lastAdminFetch: Date?

    // Config
    var sessionKey: String = ""
    var organizationID: String = ""
    var adminAPIKey: String = ""
    var refreshInterval: RefreshInterval = .twoMinutes

    // MARK: - Computed — Session Data

    var hasSessionConfig: Bool {
        !sessionKey.isEmpty && !organizationID.isEmpty
    }

    var hasAdminConfig: Bool {
        !adminAPIKey.isEmpty
    }

    var fiveHourPct: Double { usage?.fiveHour?.utilization ?? 0 }
    var sevenDayPct: Double { usage?.sevenDay?.utilization ?? 0 }
    var sonnetPct: Double { usage?.sevenDaySonnet?.utilization ?? 0 }
    var opusPct: Double { usage?.sevenDayOpus?.utilization ?? 0 }
    var oauthPct: Double { usage?.sevenDayOauthApps?.utilization ?? 0 }
    var coworkPct: Double { usage?.sevenDayCowork?.utilization ?? 0 }

    var fiveHourTier: UsageTier { UsageTier(utilization: fiveHourPct) }
    var sevenDayTier: UsageTier { UsageTier(utilization: sevenDayPct) }

    var overallUtilization: Double {
        // Weighted: 5h session matters most
        let buckets = [fiveHourPct, sevenDayPct, sonnetPct, opusPct]
            .filter { $0 > 0 }
        guard !buckets.isEmpty else { return 0 }
        return buckets.max() ?? 0
    }

    var fiveHourResetString: String {
        guard let date = usage?.fiveHour?.resetsAtDate else { return "" }
        return date.countdownString
    }

    var sevenDayResetString: String {
        guard let date = usage?.sevenDay?.resetsAtDate else { return "" }
        return date.countdownString
    }

    // MARK: - Computed — Admin Data

    var totalTokensToday: Int {
        adminTokens.reduce(0) { $0 + $1.totalTokens }
    }

    var totalCostToday: Double {
        adminCosts.reduce(0) { $0 + $1.amountCents } / 100.0
    }

    /// Token counts grouped by model
    var tokensByModel: [(model: String, input: Int, output: Int, total: Int)] {
        var dict: [String: (input: Int, output: Int)] = [:]
        for bucket in adminTokens {
            let model = bucket.model ?? "unknown"
            let existing = dict[model, default: (0, 0)]
            dict[model] = (existing.input + bucket.inputTokens, existing.output + bucket.outputTokens)
        }
        return dict.map { (model: $0.key, input: $0.value.input, output: $0.value.output, total: $0.value.input + $0.value.output) }
            .sorted { $0.total > $1.total }
    }

    // MARK: - Orbital Helpers

    /// Angle for a planet on its orbit: usage% maps to angle, plus slow continuous drift
    func orbitalAngle(utilization: Double, drift: Double, time: Double) -> Double {
        (utilization / 100.0) * .pi * 2 + time * drift - .pi / 2
    }

    /// The outer orbit uses whichever of Sonnet/Opus is higher
    var outerOrbitPct: Double { max(sonnetPct, opusPct) }
    var outerOrbitLabel: String { sonnetPct >= opusPct ? "Sonnet" : "Opus" }
}
