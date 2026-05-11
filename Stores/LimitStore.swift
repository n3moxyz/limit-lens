import AppKit
import Foundation

@MainActor
final class LimitStore: ObservableObject {
    private static let resetNotificationsDefaultsKey = "LimitLensResetNotificationsEnabled"

    @Published var codex = ProviderSnapshot.loading(.codex)
    @Published var claude = ProviderSnapshot.loading(.claude)
    @Published var selectedProvider: ProviderKind = .codex
    @Published var isRefreshing = false
    @Published var isDemoMode: Bool
    @Published var resetNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(resetNotificationsEnabled, forKey: Self.resetNotificationsDefaultsKey)
        }
    }
    @Published var codexSetupStatus = CodexSetupStatus.checking
    @Published var codexSetupMessage: String?
    @Published var claudeSetupStatus = ClaudeSetupStatus.checking
    @Published var isInstallingClaudeBridge = false
    @Published var claudeSetupMessage: String?
    @Published var notificationStatusMessage: String?
    @Published var showsNotificationSettingsAction = false

    private let codexService = CodexLimitService()
    private let claudeService = ClaudeLimitService()
    private let demoService = DemoLimitService()
    private let routeEvaluator = SuggestedRouteEvaluator()
    private let resetNotificationService = ResetNotificationService()
    private var pollingTask: Task<Void, Never>?
    private var demoScenario: DemoLimitScenario = .scarce

    init() {
        let requestedDemoMode = ProcessInfo.processInfo.arguments.contains("--demo")
            || ProcessInfo.processInfo.environment["LIMIT_LENS_DEMO_MODE"] == "1"

        isDemoMode = requestedDemoMode
        resetNotificationsEnabled = UserDefaults.standard.object(forKey: Self.resetNotificationsDefaultsKey) as? Bool ?? true
    }

    var selectedSnapshot: ProviderSnapshot {
        switch selectedProvider {
        case .codex: codex
        case .claude: claude
        }
    }

    var suggestedRoute: SuggestedRoute {
        routeEvaluator.evaluate(codex: codex, claude: claude)
    }

    var menuBarTitle: String {
        let codexPart: String
        if let used = codex.buckets.first(where: { $0.id == "codex" })?.windows.first?.usedPercent {
            codexPart = "Cdx \(Int(used.rounded()))%"
        } else {
            codexPart = "Cdx --"
        }

        let claudeWindows = claude.buckets.flatMap(\.windows)
        let claudeWindow = claudeWindows.first { $0.label.contains("Weekly all-model") }
            ?? claudeWindows.first { $0.label.contains("5-hour") }
        let claudePart: String
        if let used = claudeWindow?.usedPercent {
            claudePart = "Cl \(Int(used.rounded()))%"
        } else {
            claudePart = claude.state == .ready ? "Cl live" : "Cl --"
        }

        return "\(codexPart)  \(claudePart)"
    }

    func start() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            await self?.refreshNow()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await self?.refreshNow()
            }
        }
    }

    func setDemoMode(_ enabled: Bool) {
        guard isDemoMode != enabled else { return }

        isDemoMode = enabled
        demoScenario = .scarce

        Task {
            await refreshNow()
        }
    }

    func setResetNotificationsEnabled(_ enabled: Bool) {
        guard resetNotificationsEnabled != enabled else { return }

        resetNotificationsEnabled = enabled

        Task {
            if enabled {
                await syncResetNotifications()
            } else {
                await resetNotificationService.cancelResetNotifications()
            }
        }
    }

    func simulateDemoLimitPressure() {
        guard isDemoMode else { return }

        demoScenario = .limited
        applyDemoSnapshots(now: Date())
        notificationStatusMessage = "Queuing demo notification..."
        showsNotificationSettingsAction = false

        Task {
            let result = await resetNotificationService.deliverDemoLimitPressure()
            notificationStatusMessage = result.statusMessage
            showsNotificationSettingsAction = result.needsSettingsAction
            await syncResetNotifications()
        }
    }

    func simulateDemoResetAvailable() {
        guard isDemoMode else { return }

        demoScenario = .available
        applyDemoSnapshots(now: Date())
        notificationStatusMessage = "Queuing demo notification..."
        showsNotificationSettingsAction = false

        Task {
            let result = await resetNotificationService.deliverDemoResetAvailable()
            notificationStatusMessage = result.statusMessage
            showsNotificationSettingsAction = result.needsSettingsAction
            await syncResetNotifications()
        }
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func openCodexLoginInTerminal() {
        openTerminalCommand(
            filename: "limit-lens-codex-login.command",
            command: "codex login",
            completionMessage: "Return to Limit Lens and click Refresh Codex Setup."
        )
    }

    func openClaudeLoginInTerminal() {
        openTerminalCommand(
            filename: "limit-lens-claude-login.command",
            command: "claude auth login",
            completionMessage: "Return to Limit Lens and click Refresh Claude Setup."
        )
    }

    func refreshCodexSetupStatus() async {
        if let status = codexSetupStatus(from: codex) {
            codexSetupStatus = status
            return
        }

        codexSetupStatus = await codexService.fetchSetupStatus()
    }

    func refreshClaudeSetupStatus() async {
        claudeSetupStatus = await claudeService.fetchSetupStatus()
    }

    func refreshSetupStatuses() async {
        async let claudeStatus = claudeService.fetchSetupStatus()

        if let status = codexSetupStatus(from: codex) {
            codexSetupStatus = status
        } else {
            codexSetupStatus = await codexService.fetchSetupStatus()
        }

        claudeSetupStatus = await claudeStatus
    }

    func installClaudeStatuslineBridge() async {
        guard !isInstallingClaudeBridge else { return }

        isInstallingClaudeBridge = true
        claudeSetupMessage = "Installing Claude statusline bridge..."
        defer { isInstallingClaudeBridge = false }

        do {
            try await claudeService.installStatuslineBridge()
            claudeSetupMessage = "Bridge installed. Send one Claude Code message, then refresh."
            await refreshClaudeSetupStatus()
            await refreshNow()
        } catch {
            claudeSetupMessage = "Bridge install failed: \(error.localizedDescription)"
            await refreshClaudeSetupStatus()
        }
    }

    private func openTerminalCommand(filename: String, command: String, completionMessage: String) {
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let script = """
        #!/bin/zsh
        \(command)
        echo
        echo "\(completionMessage)"
        """

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            NSWorkspace.shared.open(scriptURL)
        } catch {
            codexSetupMessage = "Could not open login: \(error.localizedDescription)"
            claudeSetupMessage = "Could not open login: \(error.localizedDescription)"
        }
    }

    func refreshNow() async {
        guard !isRefreshing else { return }

        let demoMode = isDemoMode
        isRefreshing = true
        defer { isRefreshing = false }

        if demoMode {
            applyDemoSnapshots(now: Date())
            await syncResetNotifications()
            return
        }

        async let codexSnapshot = codexService.fetchSnapshot()
        async let claudeSnapshot = claudeService.fetchSnapshot()

        codex = await codexSnapshot
        claude = await claudeSnapshot
        await syncResetNotifications()
    }

    private func applyDemoSnapshots(now: Date) {
        codex = demoService.codexSnapshot(now: now, scenario: demoScenario)
        claude = demoService.claudeSnapshot(now: now, scenario: demoScenario)
    }

    private func syncResetNotifications() async {
        await resetNotificationService.syncResetNotifications(
            codex: codex,
            claude: claude,
            enabled: resetNotificationsEnabled
        )
    }

    private func codexSetupStatus(from snapshot: ProviderSnapshot) -> CodexSetupStatus? {
        guard snapshot.provider == .codex else {
            return nil
        }

        if case .ready = snapshot.state, !snapshot.buckets.isEmpty {
            return CodexSetupStatus(
                cliInstalled: true,
                signedIn: true,
                planType: snapshot.planType,
                bucketCount: snapshot.buckets.count,
                detail: nil
            )
        }

        return nil
    }
}
