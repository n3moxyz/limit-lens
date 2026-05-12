import Foundation
import Testing
@testable import LimitLens

@Suite("Reset notification events")
struct ResetNotificationServiceTests {
    @Test("Builds usage threshold and reset warning events")
    func notificationEventsIncludeConfiguredRules() {
        let now = Date(timeIntervalSince1970: 1_770_000_000)
        let resetDate = now.addingTimeInterval(10 * 60 * 60)
        let preferences = LimitNotificationPreferences(
            isEnabled: true,
            usageThresholdEnabled: true,
            usageThresholdPercent: 80,
            resetWarningEnabled: true,
            resetWarningLeadHours: 6
        )
        let snapshot = Self.snapshot(
            now: now,
            windows: [
                LimitWindow(
                    label: "5-hour",
                    usedPercent: 88,
                    durationMinutes: 300,
                    resetsAt: resetDate
                )
            ]
        )

        let events = ResetNotificationService.notificationEvents(
            from: [snapshot],
            preferences: preferences,
            now: now
        )

        #expect(events.count == 2)
        #expect(events[0].kind == .usageThreshold)
        #expect(events[0].id.hasPrefix("limit-lens-usage-codex-codex-5-hour"))
        #expect(events[0].title == "Codex usage is near limit")
        #expect(events[0].body.contains("88%"))

        #expect(events[1].kind == .resetWarning)
        #expect(events[1].id.hasPrefix("limit-lens-reset-warning-codex-codex-5-hour"))
        #expect(events[1].title == "Codex resets soon")
        #expect(events[1].date == resetDate.addingTimeInterval(-6 * 60 * 60))
    }

    @Test("Filters disabled rules and non-reportable windows")
    func notificationEventsFilterDisabledRulesAndNonReportableWindows() {
        let now = Date(timeIntervalSince1970: 1_770_000_000)
        let preferences = LimitNotificationPreferences(
            isEnabled: true,
            usageThresholdEnabled: true,
            usageThresholdPercent: 90,
            resetWarningEnabled: false,
            resetWarningLeadHours: 6
        )
        let snapshot = Self.snapshot(
            now: now,
            windows: [
                LimitWindow(
                    label: "Below threshold",
                    usedPercent: 88,
                    durationMinutes: 300,
                    resetsAt: now.addingTimeInterval(60)
                ),
                LimitWindow(
                    label: "Unreported",
                    usedPercent: nil,
                    durationMinutes: 10_080,
                    resetsAt: now.addingTimeInterval(60)
                ),
                LimitWindow(
                    label: "Expired",
                    usedPercent: 97,
                    durationMinutes: 300,
                    resetsAt: now.addingTimeInterval(-60)
                )
            ]
        )

        let events = ResetNotificationService.notificationEvents(
            from: [snapshot],
            preferences: preferences,
            now: now
        )

        #expect(events.isEmpty)
    }

    @Test("Disables all notification events from master switch")
    func notificationEventsRespectMasterSwitch() {
        let now = Date(timeIntervalSince1970: 1_770_000_000)
        let preferences = LimitNotificationPreferences(
            isEnabled: false,
            usageThresholdEnabled: true,
            usageThresholdPercent: 80,
            resetWarningEnabled: true,
            resetWarningLeadHours: 6
        )
        let snapshot = Self.snapshot(
            now: now,
            windows: [
                LimitWindow(
                    label: "5-hour",
                    usedPercent: 99,
                    durationMinutes: 300,
                    resetsAt: now.addingTimeInterval(60)
                )
            ]
        )

        let events = ResetNotificationService.notificationEvents(
            from: [snapshot],
            preferences: preferences,
            now: now
        )

        #expect(events.isEmpty)
    }

    @Test("Reset warnings honor selected provider windows")
    func resetWarningsHonorSelectedProviderWindows() {
        let now = Date(timeIntervalSince1970: 1_770_000_000)
        let preferences = LimitNotificationPreferences(
            isEnabled: true,
            usageThresholdEnabled: false,
            usageThresholdPercent: 80,
            resetWarningEnabled: true,
            resetWarningLeadHours: 6,
            resetWarningWindows: [.codexWeekly, .claudeFiveHour]
        )
        let codex = Self.snapshot(
            provider: .codex,
            now: now,
            windows: [
                LimitWindow(
                    label: "5-hour",
                    usedPercent: 40,
                    durationMinutes: 300,
                    resetsAt: now.addingTimeInterval(5 * 60 * 60)
                ),
                LimitWindow(
                    label: "Weekly",
                    usedPercent: 40,
                    durationMinutes: 10_080,
                    resetsAt: now.addingTimeInterval(2 * 24 * 60 * 60)
                )
            ]
        )
        let claude = Self.snapshot(
            provider: .claude,
            now: now,
            windows: [
                LimitWindow(
                    label: "Current session / 5-hour included usage",
                    usedPercent: 40,
                    durationMinutes: 300,
                    resetsAt: now.addingTimeInterval(4 * 60 * 60)
                ),
                LimitWindow(
                    label: "Weekly all-model limit",
                    usedPercent: 40,
                    durationMinutes: 10_080,
                    resetsAt: now.addingTimeInterval(3 * 24 * 60 * 60)
                )
            ]
        )

        let events = ResetNotificationService.notificationEvents(
            from: [codex, claude],
            preferences: preferences,
            now: now
        )

        #expect(events.count == 2)
        #expect(events.allSatisfy { $0.kind == .resetWarning })
        #expect(events[0].id.contains("codex-codex-weekly"))
        #expect(events[1].id.contains("claude-claude-current-session-5-hour-included-usage"))
    }

    private static func snapshot(
        provider: ProviderKind = .codex,
        now: Date,
        windows: [LimitWindow]
    ) -> ProviderSnapshot {
        ProviderSnapshot(
            provider: provider,
            state: .ready,
            headline: "Test",
            detail: "Test snapshot",
            planType: nil,
            updatedAt: now,
            buckets: [
                LimitBucket(
                    id: provider.rawValue.lowercased(),
                    title: provider.rawValue,
                    planType: nil,
                    reachedType: nil,
                    windows: windows,
                    creditSummary: nil
                )
            ],
            metrics: []
        )
    }
}
