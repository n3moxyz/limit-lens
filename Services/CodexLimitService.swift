import Foundation

struct CodexLimitService {
    func fetchSnapshot() async -> ProviderSnapshot {
        do {
            let result = try await ShellRunner.run(codexProbeCommand, timeout: 12)
            let parsed = try parseProbeOutput(result.stdout)

            guard !parsed.buckets.isEmpty else {
                return ProviderSnapshot(
                    provider: .codex,
                    state: .unavailable("No rate-limit buckets returned"),
                    headline: "No Codex limits",
                    detail: "Codex is installed, but app-server did not return a usable rate-limit bucket.",
                    planType: parsed.accountPlan,
                    updatedAt: Date(),
                    buckets: [],
                    metrics: []
                )
            }

            let primaryBucket = parsed.buckets.first(where: { $0.id == "codex" }) ?? parsed.buckets[0]
            let primaryWindow = primaryBucket.windows.first
            let plan = primaryBucket.planType ?? parsed.accountPlan

            return ProviderSnapshot(
                provider: .codex,
                state: .ready,
                headline: "\(LimitFormatters.percentString(primaryWindow?.usedPercent)) used",
                detail: primaryWindow.map { LimitFormatters.resetText($0.resetsAt) } ?? "Live Codex rate limits",
                planType: plan,
                updatedAt: Date(),
                buckets: parsed.buckets,
                metrics: [
                    UsageMetric(
                        id: "source",
                        title: "Source",
                        value: "Codex app-server",
                        detail: "account/rateLimits/read"
                    )
                ]
            )
        } catch {
            return ProviderSnapshot(
                provider: .codex,
                state: .failed(error.localizedDescription),
                headline: "Codex unavailable",
                detail: "Could not read live Codex rate limits. Make sure `codex` is installed and signed in.",
                planType: nil,
                updatedAt: Date(),
                buckets: [],
                metrics: []
            )
        }
    }

    private var codexProbeCommand: String {
        let initialize = #"{"method":"initialize","id":0,"params":{"clientInfo":{"name":"limit_lens","title":"Limit Lens","version":"0.1.0"}}}"#
        let initialized = #"{"method":"initialized","params":{}}"#
        let account = #"{"method":"account/read","id":1,"params":{"refreshToken":false}}"#
        let limits = #"{"method":"account/rateLimits/read","id":2}"#

        return """
        { printf '%s\\n' '\(initialize)'; sleep 0.15; printf '%s\\n' '\(initialized)'; sleep 0.15; printf '%s\\n' '\(account)'; sleep 0.15; printf '%s\\n' '\(limits)'; sleep 1; } | codex app-server 2>/dev/null
        """
    }

    private func parseProbeOutput(_ output: String) throws -> (accountPlan: String?, buckets: [LimitBucket]) {
        var accountPlan: String?
        var buckets: [LimitBucket] = []

        for line in output.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = object["id"] as? Int,
                  let result = object["result"] as? [String: Any] else {
                continue
            }

            if id == 1 {
                let account = result["account"] as? [String: Any]
                accountPlan = account?["planType"] as? String
            }

            if id == 2 {
                let responseData = try JSONSerialization.data(withJSONObject: result)
                let response = try JSONDecoder().decode(CodexRateLimitResponse.self, from: responseData)

                if let byId = response.rateLimitsByLimitId, !byId.isEmpty {
                    buckets = byId.values.map(\.model).sorted { left, right in
                        if left.id == "codex" { return true }
                        if right.id == "codex" { return false }
                        return left.title < right.title
                    }
                } else if let single = response.rateLimits {
                    buckets = [single.model]
                }
            }
        }

        return (accountPlan, buckets)
    }
}

private struct CodexRateLimitResponse: Decodable {
    var rateLimits: CodexBucketDTO?
    var rateLimitsByLimitId: [String: CodexBucketDTO]?
}

private struct CodexBucketDTO: Decodable {
    var limitId: String
    var limitName: String?
    var primary: CodexWindowDTO?
    var secondary: CodexWindowDTO?
    var credits: CodexCreditsDTO?
    var planType: String?
    var rateLimitReachedType: String?

    var model: LimitBucket {
        var windows: [LimitWindow] = []

        if let primary {
            windows.append(primary.model(label: LimitFormatters.windowLabel(minutes: primary.windowDurationMins)))
        }

        if let secondary {
            windows.append(secondary.model(label: LimitFormatters.windowLabel(minutes: secondary.windowDurationMins)))
        }

        return LimitBucket(
            id: limitId,
            title: limitName ?? readableLimitId(limitId),
            planType: planType,
            reachedType: rateLimitReachedType,
            windows: windows,
            creditSummary: credits?.summary
        )
    }

    private func readableLimitId(_ id: String) -> String {
        id.split(separator: "_")
            .map { part in
                part.prefix(1).uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }
}

private struct CodexWindowDTO: Decodable {
    var usedPercent: Double?
    var windowDurationMins: Int?
    var resetsAt: TimeInterval?

    func model(label: String) -> LimitWindow {
        LimitWindow(
            label: label,
            usedPercent: usedPercent,
            durationMinutes: windowDurationMins,
            resetsAt: resetsAt.map { Date(timeIntervalSince1970: $0) }
        )
    }
}

private struct CodexCreditsDTO: Decodable {
    var hasCredits: Bool?
    var unlimited: Bool?
    var balance: String?

    var summary: String? {
        if unlimited == true {
            return "Unlimited credits"
        }

        if hasCredits == true, let balance {
            return "Credits: \(balance)"
        }

        return nil
    }
}
