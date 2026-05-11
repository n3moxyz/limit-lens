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
    case unavailable(String)
    case failed(String)

    var label: String {
        switch self {
        case .loading: "Loading"
        case .ready: "Live"
        case .unavailable: "Unavailable"
        case .failed: "Error"
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
