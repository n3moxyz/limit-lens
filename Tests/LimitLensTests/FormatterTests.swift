import Foundation
import Testing
@testable import LimitLens

@Suite("Formatters")
struct FormatterTests {
    @Test("Fresh update timestamps read as just now")
    func freshUpdateTimestampsReadAsJustNow() {
        let now = Date(timeIntervalSince1970: 1_770_000_000)

        #expect(LimitFormatters.updatedText(now, relativeTo: now) == "Updated just now")
        #expect(LimitFormatters.updatedText(now.addingTimeInterval(-4), relativeTo: now) == "Updated just now")
    }

    @Test("Refresh interval copy follows poller default")
    func refreshIntervalCopyFollowsPollerDefault() {
        #expect(LimitFormatters.coarseDuration(UsagePoller.defaultNormalInterval) == "1 minute")
    }
}
