import Foundation

enum ProviderKind: String, CaseIterable, Identifiable {
    case codex = "Codex"
    case claude = "Claude"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .codex: "terminal"
        case .claude: "sparkles"
        }
    }
}

enum SnapshotState: Equatable {
    case loading
    case ready
    case stale(String)
    case unavailable(String)
    case failed(String)

    var label: String {
        switch self {
        case .loading: "Loading"
        case .ready: "Live"
        case .stale: "Stale"
        case .unavailable: "Unavailable"
        case .failed: "Error"
        }
    }

    var isUsable: Bool {
        switch self {
        case .ready, .stale:
            return true
        case .loading, .unavailable, .failed:
            return false
        }
    }

    var message: String? {
        switch self {
        case .loading, .ready:
            return nil
        case let .stale(message), let .unavailable(message), let .failed(message):
            return message
        }
    }
}

struct ProviderSnapshot: Equatable {
    var provider: ProviderKind
    var state: SnapshotState
    var headline: String
    var detail: String
    var planType: String?
    var updatedAt: Date?
    var buckets: [LimitBucket]
    var metrics: [UsageMetric]

    var hasUsableLimitData: Bool {
        buckets.flatMap(\.windows).contains { $0.usedPercent != nil }
    }

    static func loading(_ provider: ProviderKind) -> ProviderSnapshot {
        ProviderSnapshot(
            provider: provider,
            state: .loading,
            headline: "Checking...",
            detail: "Waiting for the first refresh.",
            planType: nil,
            updatedAt: nil,
            buckets: [],
            metrics: []
        )
    }
}

struct LimitBucket: Identifiable, Equatable {
    var id: String
    var title: String
    var planType: String?
    var reachedType: String?
    var windows: [LimitWindow]
    var creditSummary: String?
}

struct LimitWindow: Identifiable, Equatable {
    var id: String { label }
    var label: String
    var usedPercent: Double?
    var durationMinutes: Int?
    var resetsAt: Date?
}

struct UsageMetric: Identifiable, Equatable {
    var id: String
    var title: String
    var value: String
    var detail: String?
}

struct SuggestedRoute: Equatable {
    var title: String
    var recommendation: String
    var rationale: String
    var systemImage: String
    var tintName: String
}

enum DemoLimitScenario {
    case scarce
    case limited
    case available
}

enum NotificationDeliveryResult: Equatable {
    case scheduled
    case denied
    case failed(String)

    var statusMessage: String {
        switch self {
        case .scheduled:
            return "Demo notification queued"
        case .denied:
            return "Notifications are blocked in macOS Settings"
        case let .failed(message):
            return "Notification failed: \(message)"
        }
    }

    var needsSettingsAction: Bool {
        if case .denied = self {
            return true
        }

        return false
    }
}

struct LimitNotificationPreferences: Equatable {
    private enum DefaultsKey {
        static let enabled = "LimitLensResetNotificationsEnabled"
        static let usageThresholdEnabled = "LimitLensUsageThresholdNotificationsEnabled"
        static let usageThresholdPercent = "LimitLensUsageThresholdPercent"
        static let resetWarningEnabled = "LimitLensResetWarningNotificationsEnabled"
        static let resetWarningLeadHours = "LimitLensResetWarningLeadHours"
        static let resetWarningWindows = "LimitLensResetWarningWindows"
    }

    static let usageThresholdRange = 1...100
    static let resetWarningLeadHoursRange = 1...168

    var isEnabled: Bool
    var usageThresholdEnabled: Bool
    var usageThresholdPercent: Int
    var resetWarningEnabled: Bool
    var resetWarningLeadHours: Int
    var resetWarningWindows: Set<ResetWarningWindow> = Set(ResetWarningWindow.allCases)

    static func load(from defaults: UserDefaults = .standard) -> LimitNotificationPreferences {
        let resetWarningWindows: Set<ResetWarningWindow>
        if let rawValues = defaults.stringArray(forKey: DefaultsKey.resetWarningWindows) {
            resetWarningWindows = Set(rawValues.compactMap(ResetWarningWindow.init(rawValue:)))
        } else {
            resetWarningWindows = Set(ResetWarningWindow.allCases)
        }

        return LimitNotificationPreferences(
            isEnabled: defaults.object(forKey: DefaultsKey.enabled) as? Bool ?? true,
            usageThresholdEnabled: defaults.object(forKey: DefaultsKey.usageThresholdEnabled) as? Bool ?? true,
            usageThresholdPercent: defaults.object(forKey: DefaultsKey.usageThresholdPercent) as? Int ?? 80,
            resetWarningEnabled: defaults.object(forKey: DefaultsKey.resetWarningEnabled) as? Bool ?? true,
            resetWarningLeadHours: defaults.object(forKey: DefaultsKey.resetWarningLeadHours) as? Int ?? 6,
            resetWarningWindows: resetWarningWindows
        ).normalized()
    }

    func save(to defaults: UserDefaults = .standard) {
        let preferences = normalized()
        defaults.set(preferences.isEnabled, forKey: DefaultsKey.enabled)
        defaults.set(preferences.usageThresholdEnabled, forKey: DefaultsKey.usageThresholdEnabled)
        defaults.set(preferences.usageThresholdPercent, forKey: DefaultsKey.usageThresholdPercent)
        defaults.set(preferences.resetWarningEnabled, forKey: DefaultsKey.resetWarningEnabled)
        defaults.set(preferences.resetWarningLeadHours, forKey: DefaultsKey.resetWarningLeadHours)
        defaults.set(
            preferences.resetWarningWindows.map(\.rawValue).sorted(),
            forKey: DefaultsKey.resetWarningWindows
        )
    }

    func normalized() -> LimitNotificationPreferences {
        var preferences = self
        preferences.usageThresholdPercent = Self.clamp(
            usageThresholdPercent,
            to: Self.usageThresholdRange
        )
        preferences.resetWarningLeadHours = Self.clamp(
            resetWarningLeadHours,
            to: Self.resetWarningLeadHoursRange
        )
        return preferences
    }

    var resetWarningLeadTime: TimeInterval {
        TimeInterval(resetWarningLeadHours * 60 * 60)
    }

    func includesResetWarning(for provider: ProviderKind, window: LimitWindow) -> Bool {
        guard let resetWarningWindow = ResetWarningWindow.matching(
            provider: provider,
            window: window
        ) else {
            return false
        }

        return resetWarningWindows.contains(resetWarningWindow)
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

enum ResetWarningWindow: String, CaseIterable, Identifiable {
    case codexFiveHour
    case codexWeekly
    case claudeFiveHour
    case claudeWeekly

    var id: String { rawValue }

    var provider: ProviderKind {
        switch self {
        case .codexFiveHour, .codexWeekly:
            return .codex
        case .claudeFiveHour, .claudeWeekly:
            return .claude
        }
    }

    var title: String {
        switch self {
        case .codexFiveHour, .claudeFiveHour:
            return "5-hour"
        case .codexWeekly, .claudeWeekly:
            return "Weekly"
        }
    }

    static func matching(provider: ProviderKind, window: LimitWindow) -> ResetWarningWindow? {
        let isFiveHour = window.durationMinutes == 300
            || window.label.localizedCaseInsensitiveContains("5-hour")
        let isWeekly = window.durationMinutes == 10_080
            || window.label.localizedCaseInsensitiveContains("weekly")

        switch (provider, isFiveHour, isWeekly) {
        case (.codex, true, _):
            return .codexFiveHour
        case (.codex, false, true):
            return .codexWeekly
        case (.claude, true, _):
            return .claudeFiveHour
        case (.claude, false, true):
            return .claudeWeekly
        default:
            return nil
        }
    }
}

struct ClaudeSetupStatus: Equatable {
    var isSignedIn: Bool
    var accountLabel: String
    var authDetail: String?
    var bridgeInstalled: Bool
    var cacheExists: Bool
    var cacheCapturedAt: Date?
    var cacheHasFreshLimits: Bool

    static let checking = ClaudeSetupStatus(
        isSignedIn: false,
        accountLabel: "Checking...",
        authDetail: nil,
        bridgeInstalled: false,
        cacheExists: false,
        cacheCapturedAt: nil,
        cacheHasFreshLimits: false
    )

    var bridgeLabel: String {
        bridgeInstalled ? "Installed" : "Not installed"
    }

    var cacheLabel: String {
        guard cacheExists else { return "No cache yet" }
        guard let cacheCapturedAt else { return "Cache found" }
        return "Captured \(LimitFormatters.relative.localizedString(for: cacheCapturedAt, relativeTo: Date()))"
    }

    var nextStep: String {
        if !isSignedIn {
            return "Sign in with Claude Code, then refresh."
        }

        if !bridgeInstalled {
            return "Install the statusline bridge."
        }

        if !cacheHasFreshLimits {
            return "Send one Claude Code message, then refresh."
        }

        return "Claude live limits are ready."
    }
}

struct CodexSetupStatus: Equatable {
    var cliInstalled: Bool
    var signedIn: Bool
    var planType: String?
    var bucketCount: Int
    var detail: String?

    static let checking = CodexSetupStatus(
        cliInstalled: false,
        signedIn: false,
        planType: nil,
        bucketCount: 0,
        detail: nil
    )

    var cliLabel: String {
        cliInstalled ? "Installed" : "Not found"
    }

    var accountLabel: String {
        signedIn ? "Connected" : "Not connected"
    }

    var limitsLabel: String {
        bucketCount > 0 ? "\(bucketCount) buckets" : "No buckets"
    }

    var nextStep: String {
        if !cliInstalled {
            return "Install Codex CLI, then refresh."
        }

        if !signedIn {
            return "Sign in with Codex, then refresh."
        }

        if bucketCount == 0 {
            return detail ?? "Codex did not return usage buckets yet."
        }

        return "Codex live limits are ready."
    }
}

struct ClaudeLocalUsage: Equatable {
    var promptsFiveHours: Int
    var assistantResponsesFiveHours: Int
    var tokensFiveHours: Int
    var tokensSevenDays: Int
    var lastActivity: Date?
    var estimatedReset: Date?
    var dominantModel: String?
    var scannedFiles: Int
}
