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
}
