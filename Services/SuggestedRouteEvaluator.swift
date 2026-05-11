import Foundation

struct SuggestedRouteEvaluator {
    func evaluate(codex: ProviderSnapshot, claude: ProviderSnapshot) -> SuggestedRoute {
        let codexPressure = pressure(
            for: codex,
            preferredLabels: ["5-hour"],
            usageThreshold: 80
        )
        let claudePressure = pressure(
            for: claude,
            preferredLabels: ["Weekly all-model", "5-hour"],
            usageThreshold: 85
        )

        let codexAvailable = codexPressure.available
        let claudeAvailable = claudePressure.available
        let codexConstrained = codexPressure.isConstrained
        let claudeConstrained = claudePressure.isConstrained

        if codexConstrained, claudeAvailable, !claudeConstrained {
            return SuggestedRoute(
                title: "Use Claude next",
                recommendation: "Save Codex for computer-use work.",
                rationale: routeRationale(
                    lead: codexPressure.rationaleLead(
                        fallback: "Codex is the scarcer bucket right now, while Claude still has room for planning, review, and text-heavy coding."
                    ),
                    reset: codexPressure.reset
                ),
                systemImage: "arrow.triangle.branch",
                tintName: "orange"
            )
        }

        if codexAvailable, claudeConstrained, !codexConstrained {
            return SuggestedRoute(
                title: "Use Codex next",
                recommendation: "Claude is constrained; Codex has room.",
                rationale: routeRationale(
                    lead: claudePressure.rationaleLead(
                        fallback: "Codex is available for the next task, especially if it needs desktop, browser, or file-system control."
                    ),
                    reset: claudePressure.reset
                ),
                systemImage: "terminal",
                tintName: "green"
            )
        }

        if codexConstrained, claudeConstrained {
            return SuggestedRoute(
                title: "Wait for a reset",
                recommendation: "Both assistants look constrained.",
                rationale: routeRationale(
                    lead: "Queue low-urgency work or switch to local edits until one usage window refreshes.",
                    reset: earliestFutureDate([codexPressure.reset, claudePressure.reset])
                ),
                systemImage: "clock.arrow.circlepath",
                tintName: "red"
            )
        }

        if codexAvailable {
            return SuggestedRoute(
                title: "Use Codex for computer use",
                recommendation: "Spend Codex where desktop control matters.",
                rationale: "Codex has capacity. Use Claude for planning or review if you want to preserve Codex for browser and app-control tasks.",
                systemImage: "cursorarrow.click.2",
                tintName: "blue"
            )
        }

        if claudeAvailable {
            return SuggestedRoute(
                title: "Use Claude next",
                recommendation: "Codex is not available.",
                rationale: "Claude is ready, so route planning, review, and text-heavy coding there until Codex is back.",
                systemImage: "sparkles",
                tintName: "purple"
            )
        }

        return SuggestedRoute(
            title: "Check setup",
            recommendation: "Neither assistant is reporting live capacity.",
            rationale: "Refresh limits, then confirm the Codex and Claude CLIs are installed and signed in.",
            systemImage: "exclamationmark.triangle",
            tintName: "secondary"
        )
    }

    private func pressure(
        for snapshot: ProviderSnapshot,
        preferredLabels: [String],
        usageThreshold: Double
    ) -> ProviderPressure {
        let window = preferredWindow(for: snapshot, preferredLabels: preferredLabels)
        let projection = window.flatMap { LimitProjector.project(window: $0) }
        let usage = window?.usedPercent
        let available = snapshot.state.isUsable && snapshot.hasUsableLimitData
        let overPace = projection.map { $0.paceRatio > 1.10 } ?? false
        let highUsage = usage.map { $0 >= usageThreshold } ?? false

        return ProviderPressure(
            provider: snapshot.provider,
            usage: usage,
            reset: window?.resetsAt,
            projection: projection,
            available: available,
            isConstrained: !available || highUsage || overPace
        )
    }

    private func preferredWindow(for snapshot: ProviderSnapshot, preferredLabels: [String]) -> LimitWindow? {
        let windows = snapshot.buckets.flatMap(\.windows)

        for label in preferredLabels {
            if let window = windows.first(where: { $0.label.localizedCaseInsensitiveContains(label) }) {
                return window
            }
        }

        return windows.first(where: { $0.usedPercent != nil || $0.resetsAt != nil })
    }

    private func routeRationale(lead: String, reset: Date?) -> String {
        guard let reset else { return lead }
        return "\(lead) \(LimitFormatters.resetText(reset))."
    }

    private func earliestFutureDate(_ dates: [Date?]) -> Date? {
        dates.compactMap { $0 }
            .filter { $0.timeIntervalSinceNow > 0 }
            .min()
    }
}

private struct ProviderPressure {
    var provider: ProviderKind
    var usage: Double?
    var reset: Date?
    var projection: LimitProjection?
    var available: Bool
    var isConstrained: Bool

    func rationaleLead(fallback: String) -> String {
        if let projection, case let .overPace(deadTime) = projection.outcome, deadTime > 0 {
            return "\(provider.rawValue) is on pace to hit its limit early, with about \(LimitFormatters.coarseDuration(deadTime)) of dead time before reset."
        }

        if let usage {
            return "\(provider.rawValue) is at \(LimitFormatters.percentString(usage)) used, so it is the tighter bucket right now."
        }

        return fallback
    }
}
