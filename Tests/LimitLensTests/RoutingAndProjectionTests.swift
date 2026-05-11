import Foundation
import Testing
@testable import LimitLens

@Suite("Routing and projection")
struct RoutingAndProjectionTests {
    @Test("Projection marks fast burn as over pace")
    func projectionMarksFastBurnAsOverPace() throws {
        let now = Date(timeIntervalSince1970: 1_770_000_000)
        let window = LimitWindow(
            label: "5-hour",
            usedPercent: 80,
            durationMinutes: 300,
            resetsAt: now.addingTimeInterval(3 * 60 * 60)
        )

        let projection = try #require(LimitProjector.project(window: window, now: now))

        #expect(abs(projection.paceRatio - 2) < 0.001)
        if case let .overPace(deadTime) = projection.outcome {
            #expect(abs(deadTime - 2.5 * 60 * 60) < 1)
        } else {
            Issue.record("Expected overPace")
        }
    }

    @Test("Route uses pace even when raw usage looks low")
    func routeUsesPaceEvenWhenRawUsageLooksLow() {
        let now = Date()
        let codex = snapshot(
            provider: .codex,
            windows: [
                LimitWindow(
                    label: "5-hour",
                    usedPercent: 20,
                    durationMinutes: 300,
                    resetsAt: now.addingTimeInterval(4.5 * 60 * 60)
                )
            ]
        )
        let claude = snapshot(
            provider: .claude,
            windows: [
                LimitWindow(
                    label: "Weekly all-model limit",
                    usedPercent: 20,
                    durationMinutes: 10_080,
                    resetsAt: now.addingTimeInterval(5 * 24 * 60 * 60)
                )
            ]
        )

        let route = SuggestedRouteEvaluator().evaluate(codex: codex, claude: claude)

        #expect(route.title == "Use Claude next")
        #expect(route.rationale.contains("on pace to hit its limit early"))
    }

    @Test("Stale snapshots remain usable for routing")
    func staleSnapshotsRemainUsableForRouting() {
        let now = Date()
        let codex = snapshot(
            provider: .codex,
            state: .stale("Network failed"),
            windows: [
                LimitWindow(
                    label: "5-hour",
                    usedPercent: 90,
                    durationMinutes: 300,
                    resetsAt: now.addingTimeInterval(60 * 60)
                )
            ]
        )
        let claude = snapshot(
            provider: .claude,
            windows: [
                LimitWindow(
                    label: "Weekly all-model limit",
                    usedPercent: 30,
                    durationMinutes: 10_080,
                    resetsAt: now.addingTimeInterval(4 * 24 * 60 * 60)
                )
            ]
        )

        let route = SuggestedRouteEvaluator().evaluate(codex: codex, claude: claude)

        #expect(route.title == "Use Claude next")
    }

    private func snapshot(
        provider: ProviderKind,
        state: SnapshotState = .ready,
        windows: [LimitWindow]
    ) -> ProviderSnapshot {
        ProviderSnapshot(
            provider: provider,
            state: state,
            headline: "Test",
            detail: "Test snapshot",
            planType: nil,
            updatedAt: Date(),
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
