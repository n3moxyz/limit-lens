import Testing
@testable import LimitLens

@Suite("Codex app-server parsing")
struct CodexParsingTests {
    @Test("Parses rateLimitsByLimitId")
    func parsesAppServerRateLimitsByLimitId() {
        let output = """
        {"id":1,"result":{"account":{"type":"chatgpt","email":"user@example.com","planType":"pro"}}}
        {"id":2,"result":{"rateLimitsByLimitId":{"codex_other":{"limitId":"codex_other","limitName":"Other","primary":{"usedPercent":42,"windowDurationMins":60,"resetsAt":1770950800},"secondary":null},"codex":{"limitId":"codex","limitName":null,"primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1770947200},"secondary":{"usedPercent":60,"windowDurationMins":10080,"resetsAt":1771552000},"rateLimitReachedType":null,"planType":"pro"}}}}
        """

        let parsed = CodexLimitService().parseProbeOutput(output)

        #expect(parsed.accountReceived)
        #expect(parsed.accountPlan == "pro")
        #expect(parsed.buckets.count == 1)
        #expect(parsed.buckets.first?.id == "codex")
        #expect(parsed.buckets.first?.windows.first?.label == "5-hour")
        #expect(parsed.buckets.first?.windows.first?.usedPercent == 25)
        #expect(parsed.buckets.first?.windows.last?.label == "Weekly")
    }

    @Test("Captures app-server errors")
    func parserCapturesAppServerErrors() {
        let output = #"{"id":2,"error":{"message":"not signed in"}}"#

        let parsed = CodexLimitService().parseProbeOutput(output)

        #expect(parsed.errorMessages == ["not signed in"])
        #expect(parsed.buckets.isEmpty)
    }
}
