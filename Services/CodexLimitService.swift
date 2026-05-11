import Foundation

struct CodexLimitService {
    func fetchSnapshot() async -> ProviderSnapshot {
        do {
            let result = try await ShellRunner.run(codexProbeCommand, timeout: 12)
            let parsed = parseProbeOutput(result.stdout)

            if isMissingCodex(result) {
                return ProviderSnapshot(
                    provider: .codex,
                    state: .failed("Codex CLI not found"),
                    headline: "Codex CLI not found",
                    detail: "Install Codex or make sure `codex` is on PATH, then refresh.",
                    planType: nil,
                    updatedAt: Date(),
                    buckets: [],
                    metrics: diagnosticMetrics(
                        result: result,
                        parsed: parsed,
                        outcome: "Failed",
                        detail: "`codex` command was not found",
                        nextStep: "Install Codex or fix PATH"
                    )
                )
            }

            guard !parsed.buckets.isEmpty else {
                let message = parsed.errorMessages.first ?? trimmed(result.stderr)
                let commandDetail = message ?? "No usable bucket data was returned."
                let headline = result.status == 0 ? "No Codex buckets" : "Codex probe failed"
                let detail = result.status == 0
                    ? "Codex app-server responded, but account/rateLimits/read did not return a usable rate-limit bucket."
                    : "Codex app-server exited with status \(result.status). Run `codex login`, then refresh."

                return ProviderSnapshot(
                    provider: .codex,
                    state: result.status == 0 ? .unavailable("No rate-limit buckets returned") : .failed(commandDetail),
                    headline: headline,
                    detail: detail,
                    planType: parsed.accountPlan,
                    updatedAt: Date(),
                    buckets: [],
                    metrics: diagnosticMetrics(
                        result: result,
                        parsed: parsed,
                        outcome: result.status == 0 ? "No buckets" : "Failed",
                        detail: commandDetail,
                        nextStep: result.status == 0 ? "Refresh or inspect app-server output" : "Run `codex login`"
                    )
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
                metrics: diagnosticMetrics(
                    result: result,
                    parsed: parsed,
                    outcome: "Succeeded",
                    detail: "Live app-server response",
                    nextStep: nil
                )
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
                metrics: [
                    UsageMetric(
                        id: "probe",
                        title: "Last probe",
                        value: "Failed",
                        detail: error.localizedDescription
                    ),
                    UsageMetric(
                        id: "command",
                        title: "Command",
                        value: "app-server",
                        detail: "codex app-server"
                    ),
                    UsageMetric(
                        id: "next-step",
                        title: "Next step",
                        value: "Check Codex",
                        detail: "Install/sign in, then refresh"
                    )
                ]
            )
        }
    }

    private var codexProbeCommand: String {
        let initialize = #"{"method":"initialize","id":0,"params":{"clientInfo":{"name":"limit_lens","title":"Limit Lens","version":"0.1.0"}}}"#
        let initialized = #"{"method":"initialized","params":{}}"#
        let account = #"{"method":"account/read","id":1,"params":{"refreshToken":false}}"#
        let limits = #"{"method":"account/rateLimits/read","id":2}"#

        return """
        { printf '%s\\n' '\(initialize)'; sleep 0.15; printf '%s\\n' '\(initialized)'; sleep 0.15; printf '%s\\n' '\(account)'; sleep 0.15; printf '%s\\n' '\(limits)'; sleep 1; } | codex app-server
        """
    }

    private func parseProbeOutput(_ output: String) -> CodexProbeParseResult {
        var accountPlan: String?
        var accountReceived = false
        var limitsReceived = false
        var buckets: [LimitBucket] = []
        var errorMessages: [String] = []

        for line in output.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = object["id"] as? Int else {
                continue
            }

            if let error = object["error"] as? [String: Any] {
                if let message = error["message"] as? String {
                    errorMessages.append(message)
                } else {
                    errorMessages.append("Codex app-server returned an error for request \(id).")
                }

                continue
            }

            guard let result = object["result"] as? [String: Any] else {
                continue
            }

            if id == 1 {
                accountReceived = true
                let account = result["account"] as? [String: Any]
                accountPlan = account?["planType"] as? String
            }

            if id == 2 {
                limitsReceived = true

                do {
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
                } catch {
                    errorMessages.append("Could not decode rate-limit response: \(error.localizedDescription)")
                }
            }
        }

        return CodexProbeParseResult(
            accountPlan: accountPlan,
            accountReceived: accountReceived,
            limitsReceived: limitsReceived,
            buckets: buckets,
            errorMessages: errorMessages
        )
    }

    private func diagnosticMetrics(
        result: ShellResult,
        parsed: CodexProbeParseResult,
        outcome: String,
        detail: String?,
        nextStep: String?
    ) -> [UsageMetric] {
        var metrics = [
            UsageMetric(
                id: "probe",
                title: "Last probe",
                value: outcome,
                detail: detail ?? "codex app-server exit \(result.status)"
            ),
            UsageMetric(
                id: "signed-in",
                title: "Signed in",
                value: parsed.accountReceived ? "Yes" : "Unknown",
                detail: parsed.accountPlan ?? (parsed.accountReceived ? "account/read responded" : "No account/read response")
            ),
            UsageMetric(
                id: "bucket-count",
                title: "Buckets",
                value: "\(parsed.buckets.count)",
                detail: parsed.limitsReceived ? "Parsed from account/rateLimits/read" : "No rate-limit response"
            ),
            UsageMetric(
                id: "command",
                title: "Command",
                value: "app-server",
                detail: "codex app-server"
            ),
            UsageMetric(
                id: "endpoint",
                title: "Endpoint",
                value: "rateLimits",
                detail: "account/rateLimits/read"
            )
        ]

        if let nextStep {
            metrics.append(
                UsageMetric(
                    id: "next-step",
                    title: "Next step",
                    value: nextStep,
                    detail: "Then use Refresh limits"
                )
            )
        }

        return metrics
    }

    private func isMissingCodex(_ result: ShellResult) -> Bool {
        result.status == 127
            || result.stderr.localizedCaseInsensitiveContains("command not found: codex")
            || result.stderr.localizedCaseInsensitiveContains("codex: command not found")
    }

    private func trimmed(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

private struct CodexProbeParseResult {
    var accountPlan: String?
    var accountReceived: Bool
    var limitsReceived: Bool
    var buckets: [LimitBucket]
    var errorMessages: [String]
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
