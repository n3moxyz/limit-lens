import Foundation

struct DemoLimitService {
    func codexSnapshot(now: Date = Date()) -> ProviderSnapshot {
        let fiveHourReset = now.addingTimeInterval(74 * 60)
        let weeklyReset = now.addingTimeInterval((2 * 24 * 60 * 60) + (7 * 60 * 60))

        let buckets = [
            LimitBucket(
                id: "codex",
                title: "Codex",
                planType: "ChatGPT Pro",
                reachedType: nil,
                windows: [
                    LimitWindow(
                        label: "5-hour",
                        usedPercent: 42,
                        durationMinutes: 300,
                        resetsAt: fiveHourReset
                    ),
                    LimitWindow(
                        label: "Weekly",
                        usedPercent: 58,
                        durationMinutes: 10_080,
                        resetsAt: weeklyReset
                    )
                ],
                creditSummary: "Demo account"
            )
        ]

        return ProviderSnapshot(
            provider: .codex,
            state: .ready,
            headline: "42% used",
            detail: "Demo data from a sample Codex app-server rate-limit response.",
            planType: "ChatGPT Pro",
            updatedAt: now,
            buckets: buckets,
            metrics: [
                UsageMetric(
                    id: "demo-mode",
                    title: "Mode",
                    value: "Demo",
                    detail: "Deterministic sample data"
                ),
                UsageMetric(
                    id: "probe",
                    title: "Last probe",
                    value: "Succeeded",
                    detail: "Sample app-server response"
                ),
                UsageMetric(
                    id: "signed-in",
                    title: "Signed in",
                    value: "Yes",
                    detail: "ChatGPT Pro"
                ),
                UsageMetric(
                    id: "bucket-count",
                    title: "Buckets",
                    value: "\(buckets.count)",
                    detail: "Parsed from account/rateLimits/read"
                ),
                UsageMetric(
                    id: "endpoint",
                    title: "Endpoint",
                    value: "rateLimits",
                    detail: "account/rateLimits/read"
                )
            ]
        )
    }

    func claudeSnapshot(now: Date = Date()) -> ProviderSnapshot {
        ProviderSnapshot(
            provider: .claude,
            state: .ready,
            headline: "Weekly all-model 31% used",
            detail: "Demo data matching the Claude statusline cache shape.",
            planType: "Max",
            updatedAt: now,
            buckets: [
                LimitBucket(
                    id: "claude-plan",
                    title: "Included subscription usage",
                    planType: "Max",
                    reachedType: nil,
                    windows: [
                        LimitWindow(
                            label: "Current session / 5-hour included usage",
                            usedPercent: 24,
                            durationMinutes: 300,
                            resetsAt: now.addingTimeInterval(53 * 60)
                        ),
                        LimitWindow(
                            label: "Weekly all-model limit",
                            usedPercent: 31,
                            durationMinutes: 10_080,
                            resetsAt: now.addingTimeInterval((4 * 24 * 60 * 60) + (3 * 60 * 60))
                        ),
                        LimitWindow(
                            label: "Weekly Sonnet limit (not exposed)",
                            usedPercent: nil,
                            durationMinutes: 10_080,
                            resetsAt: nil
                        )
                    ],
                    creditSummary: "Demo statusline cache"
                ),
                LimitBucket(
                    id: "claude-local",
                    title: "Local Claude Code activity",
                    planType: nil,
                    reachedType: nil,
                    windows: [
                        LimitWindow(
                            label: "Local 5-hour estimate",
                            usedPercent: nil,
                            durationMinutes: 300,
                            resetsAt: now.addingTimeInterval(64 * 60)
                        )
                    ],
                    creditSummary: "Recent model: Claude Sonnet 4.5 · 8 recent files scanned"
                )
            ],
            metrics: [
                UsageMetric(
                    id: "account",
                    title: "Account",
                    value: "Claude Max account",
                    detail: "Demo auth status"
                ),
                UsageMetric(
                    id: "liveQuota",
                    title: "Live quota",
                    value: "31% weekly",
                    detail: "Demo statusline cache"
                ),
                UsageMetric(
                    id: "prompts5h",
                    title: "Prompts",
                    value: "12",
                    detail: "Last 5 hours, demo history"
                ),
                UsageMetric(
                    id: "tokens5h",
                    title: "Tokens",
                    value: "128,400",
                    detail: "Last 5 hours, demo history"
                ),
                UsageMetric(
                    id: "tokens7d",
                    title: "7-day tokens",
                    value: "842,100",
                    detail: "Demo Claude Code history"
                )
            ]
        )
    }
}
