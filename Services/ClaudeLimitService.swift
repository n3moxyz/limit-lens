import Foundation

struct ClaudeLimitService {
    func fetchSnapshot() async -> ProviderSnapshot {
        let auth = await readAuthStatus()
        let usage = await scanLocalUsage()

        let authMetrics = [
            UsageMetric(id: "account", title: "Account", value: auth.accountLabel, detail: auth.providerLabel),
            UsageMetric(id: "liveQuota", title: "Live quota", value: "Not exposed", detail: "Use Claude Code /status or Settings > Usage"),
            UsageMetric(id: "prompts5h", title: "Prompts", value: "\(usage.promptsFiveHours)", detail: "Last 5 hours, local history"),
            UsageMetric(id: "tokens5h", title: "Tokens", value: LimitFormatters.number(usage.tokensFiveHours), detail: "Last 5 hours, local history"),
            UsageMetric(id: "tokens7d", title: "7-day tokens", value: LimitFormatters.number(usage.tokensSevenDays), detail: "Local Claude Code history only")
        ]

        if auth.loggedIn {
            return ProviderSnapshot(
                provider: .claude,
                state: .ready,
                headline: auth.accountLabel,
                detail: "Claude does not expose live remaining subscription capacity through `claude auth status`. Exact remaining capacity is shown in interactive Claude Code `/status` and Claude Settings > Usage.",
                planType: auth.subscriptionDisplayName,
                updatedAt: Date(),
                buckets: planBuckets(for: auth, usage: usage),
                metrics: authMetrics
            )
        }

        return ProviderSnapshot(
            provider: .claude,
            state: .unavailable("Claude Code is signed out"),
            headline: "Signed out",
            detail: "Run `claude auth login` or `/login` in Claude Code to connect a subscription.",
            planType: nil,
            updatedAt: Date(),
            buckets: localBuckets(from: usage),
            metrics: authMetrics
        )
    }

    private func readAuthStatus() async -> ClaudeAuthSummary {
        do {
            let result = try await ShellRunner.run("claude auth status --json 2>/dev/null", timeout: 6)
            guard let data = result.stdout.data(using: .utf8), !data.isEmpty else {
                return ClaudeAuthSummary(loggedIn: false, authMethod: "none", apiProvider: nil)
            }

            let status = try JSONDecoder().decode(ClaudeAuthStatusDTO.self, from: data)
            return ClaudeAuthSummary(
                loggedIn: status.loggedIn,
                authMethod: status.authMethod ?? "unknown",
                apiProvider: status.apiProvider,
                subscriptionType: status.subscriptionType
            )
        } catch {
            return ClaudeAuthSummary(loggedIn: false, authMethod: "unknown", apiProvider: nil)
        }
    }

    private func scanLocalUsage() async -> ClaudeLocalUsage {
        await Task.detached(priority: .utility) {
            ClaudeUsageScanner().scan()
        }.value
    }

    private func planBuckets(for auth: ClaudeAuthSummary, usage: ClaudeLocalUsage) -> [LimitBucket] {
        guard auth.loggedIn else {
            return localBuckets(from: usage)
        }

        var planWindows = [
            LimitWindow(
                label: "5-hour included usage",
                usedPercent: nil,
                durationMinutes: 300,
                resetsAt: nil
            )
        ]

        if auth.subscriptionType?.lowercased() == "max" {
            planWindows.append(
                LimitWindow(
                    label: "Weekly all-model limit",
                    usedPercent: nil,
                    durationMinutes: 10_080,
                    resetsAt: nil
                )
            )
            planWindows.append(
                LimitWindow(
                    label: "Weekly Sonnet limit",
                    usedPercent: nil,
                    durationMinutes: 10_080,
                    resetsAt: nil
                )
            )
        }

        return [
            LimitBucket(
                id: "claude-plan",
                title: "Included subscription usage",
                planType: auth.subscriptionDisplayName,
                reachedType: nil,
                windows: planWindows,
                creditSummary: "Remaining capacity is not available through the CLI"
            ),
            localUsageBucket(from: usage)
        ]
    }

    private func localBuckets(from usage: ClaudeLocalUsage) -> [LimitBucket] {
        [localUsageBucket(from: usage)]
    }

    private func localUsageBucket(from usage: ClaudeLocalUsage) -> LimitBucket {
        let resetWindow = LimitWindow(
            label: "Local 5-hour estimate",
            usedPercent: nil,
            durationMinutes: 300,
            resetsAt: usage.estimatedReset
        )

        return LimitBucket(
            id: "claude-local",
            title: "Local Claude Code activity",
            planType: nil,
            reachedType: nil,
            windows: [resetWindow],
            creditSummary: localUsageSummary(usage)
        )
    }

    private func localUsageSummary(_ usage: ClaudeLocalUsage) -> String {
        let files = "\(usage.scannedFiles) recent files scanned"
        guard let dominantModel = usage.dominantModel else {
            return files
        }

        return "Recent model: \(dominantModel) · \(files)"
    }
}

private struct ClaudeAuthStatusDTO: Decodable {
    var loggedIn: Bool
    var authMethod: String?
    var apiProvider: String?
    var subscriptionType: String?
}

private struct ClaudeAuthSummary {
    var loggedIn: Bool
    var authMethod: String
    var apiProvider: String?
    var subscriptionType: String?

    var accountLabel: String {
        guard loggedIn else { return "Signed out" }
        return subscriptionDisplayName.map { "Claude \($0) account" } ?? authMethod
    }

    var providerLabel: String? {
        guard let apiProvider else { return nil }
        return "Signed in with \(authMethod) · \(apiProvider)"
    }

    var subscriptionDisplayName: String? {
        guard let subscriptionType, !subscriptionType.isEmpty else {
            return nil
        }

        switch subscriptionType.lowercased() {
        case "max":
            return "Max"
        case "pro":
            return "Pro"
        case "team":
            return "Team"
        case "enterprise":
            return "Enterprise"
        default:
            return subscriptionType
                .split(separator: "_")
                .map { part in part.prefix(1).uppercased() + part.dropFirst() }
                .joined(separator: " ")
        }
    }
}

private struct ClaudeUsageScanner {
    private let calendar = Calendar(identifier: .gregorian)

    func scan() -> ClaudeLocalUsage {
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)

        var promptsFiveHours = 0
        var assistantResponsesFiveHours = 0
        var tokensFiveHours = 0
        var tokensSevenDays = 0
        var recentDates: [Date] = []
        var modelCounts: [String: Int] = [:]

        let files = jsonlFiles(modifiedSince: sevenDaysAgo)

        for file in files {
            guard let text = try? String(contentsOf: file.url, encoding: .utf8) else {
                continue
            }

            for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let data = String(rawLine).data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let timestamp = object["timestamp"] as? String,
                      let date = parseDate(timestamp),
                      date >= sevenDaysAgo else {
                    continue
                }

                let type = object["type"] as? String
                let tokenTotal = tokenCount(from: object)

                tokensSevenDays += tokenTotal

                if date >= fiveHoursAgo {
                    recentDates.append(date)

                    if type == "user" {
                        promptsFiveHours += 1
                    }

                    if type == "assistant" {
                        assistantResponsesFiveHours += 1
                        tokensFiveHours += tokenTotal

                        if let message = object["message"] as? [String: Any],
                           let model = message["model"] as? String {
                            modelCounts[model, default: 0] += 1
                        }
                    }
                }
            }
        }

        let firstRecent = recentDates.min()
        let estimatedReset = firstRecent.map { $0.addingTimeInterval(5 * 60 * 60) }
        let dominantModel = modelCounts.max { $0.value < $1.value }?.key

        return ClaudeLocalUsage(
            promptsFiveHours: promptsFiveHours,
            assistantResponsesFiveHours: assistantResponsesFiveHours,
            tokensFiveHours: tokensFiveHours,
            tokensSevenDays: tokensSevenDays,
            lastActivity: recentDates.max(),
            estimatedReset: estimatedReset,
            dominantModel: dominantModel,
            scannedFiles: files.count
        )
    }

    private func jsonlFiles(modifiedSince cutoff: Date) -> [(url: URL, modifiedAt: Date)] {
        let fileManager = FileManager.default
        let roots = [
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude/transcripts")
        ]

        var files: [(URL, Date)] = []

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "jsonl",
                      let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                      values.isRegularFile == true,
                      let modifiedAt = values.contentModificationDate,
                      modifiedAt >= cutoff else {
                    continue
                }

                files.append((fileURL, modifiedAt))
            }
        }

        let sortedFiles = files.sorted(by: { (left: (url: URL, modifiedAt: Date), right: (url: URL, modifiedAt: Date)) -> Bool in
            left.modifiedAt > right.modifiedAt
        })

        return Array(sortedFiles.prefix(250))
    }

    private func tokenCount(from object: [String: Any]) -> Int {
        guard let message = object["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else {
            return 0
        }

        return intValue(usage["input_tokens"])
            + intValue(usage["output_tokens"])
            + intValue(usage["cache_creation_input_tokens"])
            + intValue(usage["cache_read_input_tokens"])
    }

    private func intValue(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? String { return Int(value) ?? 0 }
        return 0
    }

    private func parseDate(_ value: String) -> Date? {
        ISO8601DateFormatter.withFractionalSeconds.date(from: value)
            ?? ISO8601DateFormatter.basic.date(from: value)
    }
}

private extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
