import Foundation

struct SuggestedRouteEvaluator {
    func evaluate(codex: ProviderSnapshot, claude: ProviderSnapshot) -> SuggestedRoute {
        let codexUsage = usagePercent(for: codex, preferredLabels: ["5-hour"])
        let claudeUsage = usagePercent(for: claude, preferredLabels: ["Weekly all-model", "5-hour"])
        let codexReset = resetDate(for: codex, preferredLabels: ["5-hour"])
        let claudeReset = resetDate(for: claude, preferredLabels: ["Weekly all-model", "5-hour"])

        let codexAvailable = codex.state == .ready
        let claudeAvailable = claude.state == .ready
        let codexConstrained = codexUsage.map { $0 >= 80 } ?? !codexAvailable
        let claudeConstrained = claudeUsage.map { $0 >= 85 } ?? !claudeAvailable

        if codexConstrained, claudeAvailable, !claudeConstrained {
            return SuggestedRoute(
                title: "Use Claude next",
                recommendation: "Save Codex for computer-use work.",
                rationale: routeRationale(
                    lead: "Codex is the scarcer bucket right now, while Claude still has room for planning, review, and text-heavy coding.",
                    reset: codexReset
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
                    lead: "Codex is available for the next task, especially if it needs desktop, browser, or file-system control.",
                    reset: claudeReset
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
                    reset: earliestFutureDate([codexReset, claudeReset])
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

    private func usagePercent(for snapshot: ProviderSnapshot, preferredLabels: [String]) -> Double? {
        let windows = snapshot.buckets.flatMap(\.windows)

        for label in preferredLabels {
            if let value = windows.first(where: { $0.label.localizedCaseInsensitiveContains(label) })?.usedPercent {
                return value
            }
        }

        return windows.first(where: { $0.usedPercent != nil })?.usedPercent
    }

    private func resetDate(for snapshot: ProviderSnapshot, preferredLabels: [String]) -> Date? {
        let windows = snapshot.buckets.flatMap(\.windows)

        for label in preferredLabels {
            if let date = windows.first(where: { $0.label.localizedCaseInsensitiveContains(label) })?.resetsAt {
                return date
            }
        }

        return windows.first(where: { $0.resetsAt != nil })?.resetsAt
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
