import Foundation
import Testing
@testable import LimitLens

@Suite("Claude statusline parsing")
struct ClaudeStatuslineParserTests {
    @Test("Parses fresh statusline windows")
    func parsesFreshStatuslineWindows() throws {
        let json = """
        {
          "captured_at": 1770000000,
          "model": { "display_name": "Claude Sonnet 4.5" },
          "rate_limits": {
            "five_hour": { "used_percentage": 22.5, "resets_at": 1770003600 },
            "seven_day": { "used_percentage": 71, "resets_at": 1770600000 }
          }
        }
        """

        let usage = try #require(
            ClaudeStatuslineParser.usage(
                from: Data(json.utf8),
                now: Date(timeIntervalSince1970: 1770000001)
            )
        )

        #expect(usage.modelDisplayName == "Claude Sonnet 4.5")
        #expect(usage.fiveHour?.usedPercentage == 22.5)
        #expect(usage.sevenDay?.usedPercentage == 71)
        #expect(usage.hasLiveLimits)
    }

    @Test("Drops expired statusline windows")
    func dropsExpiredStatuslineWindows() throws {
        let json = """
        {
          "rate_limits": {
            "five_hour": { "used_percentage": 99, "resets_at": 1770000000 },
            "seven_day": { "used_percentage": 12, "resets_at": 1770600000 }
          }
        }
        """

        let usage = try #require(
            ClaudeStatuslineParser.usage(
                from: Data(json.utf8),
                now: Date(timeIntervalSince1970: 1770000001)
            )
        )

        #expect(usage.fiveHour == nil)
        #expect(usage.sevenDay?.usedPercentage == 12)
    }
}
