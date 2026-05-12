import Testing
@testable import LimitLens

@Suite("Menu-bar meter")
struct MenuBarMeterTests {
    @Test("Fill width is proportional for normal percentages")
    func fillWidthIsProportionalForNormalPercentages() {
        #expect(MenuBarMeterSizing.fillWidth(for: 8, meterWidth: 40) == 3.2)
        #expect(MenuBarMeterSizing.fillWidth(for: 50, meterWidth: 40) == 20)
        #expect(MenuBarMeterSizing.fillWidth(for: 80, meterWidth: 40) == 32)
    }

    @Test("Only tiny nonzero percentages get a visibility floor")
    func tinyPercentagesGetVisibilityFloor() {
        #expect(MenuBarMeterSizing.fillWidth(for: 0, meterWidth: 40) == 0)
        #expect(MenuBarMeterSizing.fillWidth(for: 1, meterWidth: 40) == 1)
        #expect(MenuBarMeterSizing.fillWidth(for: 2, meterWidth: 40) == 1)
    }

    @Test("Weekly percentage drives the menu-bar meter")
    func weeklyPercentageDrivesMenuBarMeter() {
        let snapshot = providerSnapshot(
            windows: [
                LimitWindow(
                    label: "5-hour",
                    usedPercent: 1,
                    durationMinutes: 300,
                    resetsAt: nil
                ),
                LimitWindow(
                    label: "Weekly",
                    usedPercent: 8,
                    durationMinutes: 10_080,
                    resetsAt: nil
                )
            ]
        )

        #expect(MenuBarMeterPresentation.usedPercent(for: snapshot) == 8)
        #expect(MenuBarMeterPresentation.accessibilitySummary(for: snapshot) == "Codex Live, weekly 8% used")
    }

    private func providerSnapshot(windows: [LimitWindow]) -> ProviderSnapshot {
        ProviderSnapshot(
            provider: .codex,
            state: .ready,
            headline: "Live usage",
            detail: "Test snapshot",
            planType: nil,
            updatedAt: nil,
            buckets: [
                LimitBucket(
                    id: "codex",
                    title: "Codex",
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
