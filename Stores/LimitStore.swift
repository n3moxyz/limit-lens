import Foundation

@MainActor
final class LimitStore: ObservableObject {
    private static let demoModeDefaultsKey = "LimitLensDemoModeEnabled"
    private static let resetNotificationsDefaultsKey = "LimitLensResetNotificationsEnabled"

    @Published var codex = ProviderSnapshot.loading(.codex)
    @Published var claude = ProviderSnapshot.loading(.claude)
    @Published var selectedProvider: ProviderKind = .codex
    @Published var isRefreshing = false
    @Published var isDemoMode: Bool {
        didSet {
            UserDefaults.standard.set(isDemoMode, forKey: Self.demoModeDefaultsKey)
        }
    }
    @Published var resetNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(resetNotificationsEnabled, forKey: Self.resetNotificationsDefaultsKey)
        }
    }
    @Published var demoNotificationStatus: String?

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
            || UserDefaults.standard.bool(forKey: Self.demoModeDefaultsKey)
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
        demoNotificationStatus = "Queuing demo notification..."

        Task {
            let result = await resetNotificationService.deliverDemoLimitPressure()
            demoNotificationStatus = result.demoStatusMessage
            await syncResetNotifications()
        }
    }

    func simulateDemoResetAvailable() {
        guard isDemoMode else { return }

        demoScenario = .available
        applyDemoSnapshots(now: Date())
        demoNotificationStatus = "Queuing demo notification..."

        Task {
            let result = await resetNotificationService.deliverDemoResetAvailable()
            demoNotificationStatus = result.demoStatusMessage
            await syncResetNotifications()
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
}
