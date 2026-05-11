import Foundation
import Testing
@testable import LimitLens

@Suite("Reset notification events")
struct ResetNotificationServiceTests {
    @Test("Includes only reportable future windows")
    func resetEventsIncludeOnlyReportableFutureWindows() {
        let now = Date(timeIntervalSince1970: 1_770_000_000)
        let snapshot = ProviderSnapshot(
            provider: .codex,
            state: .ready,
            headline: "Test",
            detail: "Test snapshot",
            planType: nil,
            updatedAt: now,
            buckets: [
                LimitBucket(
                    id: "codex",
                    title: "Codex",
                    planType: nil,
                    reachedType: nil,
                    windows: [
                        LimitWindow(
                            label: "5-hour",
                            usedPercent: 88,
                            durationMinutes: 300,
                            resetsAt: now.addingTimeInterval(60)
                        ),
                        LimitWindow(
                            label: "Weekly Sonnet limit (not exposed)",
                            usedPercent: nil,
                            durationMinutes: 10_080,
                            resetsAt: now.addingTimeInterval(60)
                        ),
                        LimitWindow(
                            label: "Expired",
                            usedPercent: 10,
                            durationMinutes: 300,
                            resetsAt: now.addingTimeInterval(-60)
                        )
                    ],
                    creditSummary: nil
                )
            ],
            metrics: []
        )

        let events = ResetNotificationService.resetEvents(from: [snapshot], now: now)

        #expect(events.count == 1)
        #expect(events[0].id.hasPrefix("limit-lens-reset-codex-codex-5-hour"))
        #expect(events[0].title == "Codex reset is ready")
    }
}
