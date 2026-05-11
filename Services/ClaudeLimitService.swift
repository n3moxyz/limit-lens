import Foundation

struct ClaudeLimitService {
    func fetchSetupStatus() async -> ClaudeSetupStatus {
        let auth = await readAuthStatus()
        let bridgeInstalled = ClaudeStatuslineBridgeInstaller().isInstalled
        let cacheSummary = await Task.detached(priority: .utility) {
            ClaudeStatuslineCacheReader().readSummary()
        }.value

        return ClaudeSetupStatus(
            isSignedIn: auth.loggedIn,
            accountLabel: auth.accountLabel,
            authDetail: auth.providerLabel,
            bridgeInstalled: bridgeInstalled,
            cacheExists: cacheSummary.exists,
            cacheCapturedAt: cacheSummary.capturedAt,
            cacheHasFreshLimits: cacheSummary.hasFreshLimits
        )
    }

    func installStatuslineBridge() async throws {
        try await Task.detached(priority: .utility) {
            try ClaudeStatuslineBridgeInstaller().install()
        }.value
    }

    func fetchSnapshot() async -> ProviderSnapshot {
        let auth = await readAuthStatus()
        let liveUsage = await readStatuslineUsage()
        let usage = await scanLocalUsage()

        let authMetrics = [
            UsageMetric(id: "account", title: "Account", value: auth.accountLabel, detail: auth.providerLabel),
            UsageMetric(id: "liveQuota", title: "Live quota", value: liveUsage.liveQuotaLabel, detail: liveUsage.liveQuotaDetail),
            UsageMetric(id: "prompts5h", title: "Prompts", value: "\(usage.promptsFiveHours)", detail: "Last 5 hours, local history"),
            UsageMetric(id: "tokens5h", title: "Tokens", value: LimitFormatters.number(usage.tokensFiveHours), detail: "Last 5 hours, local history"),
            UsageMetric(id: "tokens7d", title: "7-day tokens", value: LimitFormatters.number(usage.tokensSevenDays), detail: "Local Claude Code history only")
        ]

        if auth.loggedIn {
            return ProviderSnapshot(
                provider: .claude,
                state: .ready,
                headline: liveUsage.headline(fallback: auth.accountLabel),
                detail: liveUsage.detail,
                planType: auth.subscriptionDisplayName,
                updatedAt: Date(),
                buckets: planBuckets(for: auth, liveUsage: liveUsage, usage: usage),
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

    private func readStatuslineUsage() async -> ClaudeStatuslineUsage {
        await Task.detached(priority: .utility) {
            ClaudeStatuslineCacheReader().read()
        }.value
    }

    private func planBuckets(for auth: ClaudeAuthSummary, liveUsage: ClaudeStatuslineUsage, usage: ClaudeLocalUsage) -> [LimitBucket] {
        guard auth.loggedIn else {
            return localBuckets(from: usage)
        }

        var planWindows = [
            LimitWindow(
                label: "Current session / 5-hour included usage",
                usedPercent: liveUsage.fiveHour?.usedPercentage,
                durationMinutes: 300,
                resetsAt: liveUsage.fiveHour?.resetsAt
            )
        ]

        if auth.subscriptionType?.lowercased() == "max" {
            planWindows.append(
                LimitWindow(
                    label: "Weekly all-model limit",
                    usedPercent: liveUsage.sevenDay?.usedPercentage,
                    durationMinutes: 10_080,
                    resetsAt: liveUsage.sevenDay?.resetsAt
                )
            )
            planWindows.append(
                LimitWindow(
                    label: "Weekly Sonnet limit (not exposed)",
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
                creditSummary: liveUsage.planSummary
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

private struct ClaudeStatuslineUsage: Equatable {
    var capturedAt: Date?
    var modelDisplayName: String?
    var fiveHour: ClaudeStatuslineWindow?
    var sevenDay: ClaudeStatuslineWindow?

    var hasLiveLimits: Bool {
        fiveHour?.usedPercentage != nil || sevenDay?.usedPercentage != nil
    }

    var planSummary: String {
        guard hasLiveLimits else {
            return "Waiting for Claude Code statusline data"
        }

        return "From Claude Code statusline"
    }

    var liveQuotaLabel: String {
        guard hasLiveLimits else {
            return "Waiting"
        }

        if let sevenDay = sevenDay?.usedPercentage {
            return "\(LimitFormatters.percentString(sevenDay)) weekly"
        }

        return "\(LimitFormatters.percentString(fiveHour?.usedPercentage)) 5-hour"
    }

    var liveQuotaDetail: String? {
        guard let capturedAt else {
            return "Install the statusline bridge, then send one Claude Code message"
        }

        let age = LimitFormatters.relative.localizedString(for: capturedAt, relativeTo: Date())
        let model = modelDisplayName.map { " · \($0)" } ?? ""
        return "Captured \(age)\(model)"
    }

    var detail: String {
        guard hasLiveLimits else {
            return "Claude Code exposes subscription usage through its documented statusline JSON after a Claude.ai response. Enable the Limit Lens statusline bridge, then send one Claude Code message to populate this view."
        }

        let age = capturedAt.map { LimitFormatters.relative.localizedString(for: $0, relativeTo: Date()) } ?? "recently"
        return "Read from Claude Code statusline cache captured \(age). Claude exposes 5-hour and weekly all-model usage here; the separate Settings-only Sonnet weekly bar is not present in the documented statusline payload."
    }

    func headline(fallback: String) -> String {
        if let sevenDay = sevenDay?.usedPercentage {
            return "Weekly all-model \(LimitFormatters.percentString(sevenDay)) used"
        }

        if let fiveHour = fiveHour?.usedPercentage {
            return "5-hour \(LimitFormatters.percentString(fiveHour)) used"
        }

        return fallback
    }
}

private struct ClaudeStatuslineWindow: Equatable {
    var usedPercentage: Double?
    var resetsAt: Date?
}

private struct ClaudeStatuslineCacheReader {
    func read() -> ClaudeStatuslineUsage {
        guard let cacheData = readCacheData() else {
            return ClaudeStatuslineUsage(capturedAt: nil, modelDisplayName: nil, fiveHour: nil, sevenDay: nil)
        }

        let now = Date()

        return ClaudeStatuslineUsage(
            capturedAt: cacheData.capturedAt,
            modelDisplayName: cacheData.cache.model?.displayName,
            fiveHour: freshWindow(cacheData.cache.rateLimits?.fiveHour?.model, now: now),
            sevenDay: freshWindow(cacheData.cache.rateLimits?.sevenDay?.model, now: now)
        )
    }

    func readSummary() -> ClaudeStatuslineCacheSummary {
        guard let cacheData = readCacheData() else {
            return ClaudeStatuslineCacheSummary(exists: false, capturedAt: nil, hasFreshLimits: false)
        }

        let now = Date()
        let fiveHour = freshWindow(cacheData.cache.rateLimits?.fiveHour?.model, now: now)
        let sevenDay = freshWindow(cacheData.cache.rateLimits?.sevenDay?.model, now: now)

        return ClaudeStatuslineCacheSummary(
            exists: true,
            capturedAt: cacheData.capturedAt,
            hasFreshLimits: fiveHour?.usedPercentage != nil || sevenDay?.usedPercentage != nil
        )
    }

    private func readCacheData() -> ClaudeStatuslineCacheData? {
        let cacheURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/LimitLens/claude-rate-limits.json")

        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(ClaudeStatuslineCacheDTO.self, from: data) else {
            return nil
        }

        let capturedAt = cache.capturedAt.map { Date(timeIntervalSince1970: $0) }
            ?? (try? FileManager.default.attributesOfItem(atPath: cacheURL.path)[.modificationDate] as? Date)

        return ClaudeStatuslineCacheData(
            cache: cache,
            capturedAt: capturedAt,
            url: cacheURL
        )
    }

    private func freshWindow(_ window: ClaudeStatuslineWindow?, now: Date) -> ClaudeStatuslineWindow? {
        guard let window else { return nil }

        if let resetsAt = window.resetsAt, resetsAt <= now {
            return nil
        }

        return window
    }
}

private struct ClaudeStatuslineCacheData {
    var cache: ClaudeStatuslineCacheDTO
    var capturedAt: Date?
    var url: URL
}

private struct ClaudeStatuslineCacheSummary {
    var exists: Bool
    var capturedAt: Date?
    var hasFreshLimits: Bool
}

private struct ClaudeStatuslineCacheDTO: Decodable {
    var capturedAt: TimeInterval?
    var model: ClaudeStatuslineModelDTO?
    var rateLimits: ClaudeStatuslineRateLimitsDTO?

    private enum CodingKeys: String, CodingKey {
        case capturedAt = "captured_at"
        case model
        case rateLimits = "rate_limits"
    }
}

private struct ClaudeStatuslineModelDTO: Decodable {
    var displayName: String?

    private enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

private struct ClaudeStatuslineRateLimitsDTO: Decodable {
    var fiveHour: ClaudeStatuslineWindowDTO?
    var sevenDay: ClaudeStatuslineWindowDTO?

    private enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

private struct ClaudeStatuslineWindowDTO: Decodable {
    var usedPercentage: Double?
    var resetsAt: TimeInterval?

    var model: ClaudeStatuslineWindow {
        ClaudeStatuslineWindow(
            usedPercentage: usedPercentage,
            resetsAt: resetsAt.map { Date(timeIntervalSince1970: $0) }
        )
    }

    private enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
        case resetsAt = "resets_at"
    }
}

private struct ClaudeStatuslineBridgeInstaller {
    private var fileManager: FileManager { .default }

    var isInstalled: Bool {
        guard fileManager.fileExists(atPath: bridgeFile.path),
              let settings = settingsDictionary(),
              let statusLine = settings["statusLine"] as? [String: Any],
              let command = statusLine["command"] as? String else {
            return false
        }

        return command.contains("limit-lens-statusline-bridge.sh")
    }

    func install() throws {
        try fileManager.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: settingsFile.path) {
            try "{}\n".write(to: settingsFile, atomically: true, encoding: .utf8)
        }

        var settings = settingsDictionary() ?? [:]
        let existingCommand = ((settings["statusLine"] as? [String: Any])?["command"] as? String) ?? ""

        if !existingCommand.isEmpty, !existingCommand.contains("limit-lens-statusline-bridge.sh") {
            try existingCommand
                .appending("\n")
                .write(to: originalCommandFile, atomically: true, encoding: .utf8)
        }

        try bridgeScript.write(to: bridgeFile, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: bridgeFile.path)

        let backupURL = backupDirectory
            .appendingPathComponent("settings.limit-lens.\(Self.timestamp.string(from: Date())).json")
        try fileManager.copyItem(at: settingsFile, to: backupURL)

        settings["statusLine"] = [
            "type": "command",
            "command": #"/bin/sh "$HOME/.claude/limit-lens-statusline-bridge.sh""#
        ]

        let output = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        var outputText = String(data: output, encoding: .utf8) ?? "{}"
        outputText.append("\n")
        try outputText.write(to: settingsFile, atomically: true, encoding: .utf8)
    }

    private var claudeDirectory: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    private var backupDirectory: URL {
        claudeDirectory.appendingPathComponent("backups")
    }

    private var settingsFile: URL {
        claudeDirectory.appendingPathComponent("settings.json")
    }

    private var bridgeFile: URL {
        claudeDirectory.appendingPathComponent("limit-lens-statusline-bridge.sh")
    }

    private var originalCommandFile: URL {
        claudeDirectory.appendingPathComponent("limit-lens-statusline-original-command")
    }

    private func settingsDictionary() -> [String: Any]? {
        guard let data = try? Data(contentsOf: settingsFile),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return object
    }

    private static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private var bridgeScript: String {
        #"""
#!/bin/sh

input=$(cat)
cache_dir="${HOME}/Library/Application Support/LimitLens"
cache_file="${cache_dir}/claude-rate-limits.json"
original_command_file="${HOME}/.claude/limit-lens-statusline-original-command"

mkdir -p "$cache_dir"

printf '%s' "$input" | /usr/bin/ruby -rjson -e '
cache_file = ARGV.fetch(0)
payload = JSON.parse(STDIN.read)
cache = {
  "source" => "claude-code-statusline",
  "captured_at" => Time.now.to_i,
  "model" => {
    "id" => payload.dig("model", "id"),
    "display_name" => payload.dig("model", "display_name")
  },
  "rate_limits" => payload["rate_limits"]
}
tmp = "#{cache_file}.#{$$}"
File.write(tmp, JSON.generate(cache) + "\n")
File.rename(tmp, cache_file)
' "$cache_file" 2>/dev/null

if [ -r "$original_command_file" ]; then
  original_command=$(cat "$original_command_file")
  case "$original_command" in
    ""|*limit-lens-statusline-bridge.sh*)
      ;;
    *)
      printf '%s' "$input" | /bin/sh -c "$original_command"
      exit 0
      ;;
  esac
fi

printf '%s' "$input" | /usr/bin/ruby -rjson -e '
payload = JSON.parse(STDIN.read)
puts payload.dig("model", "display_name") || "Claude"
' 2>/dev/null || printf 'Claude\n'
"""#
    }
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
