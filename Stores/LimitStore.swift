import Foundation

@MainActor
final class LimitStore: ObservableObject {
    private static let demoModeDefaultsKey = "LimitLensDemoModeEnabled"

    @Published var codex = ProviderSnapshot.loading(.codex)
    @Published var claude = ProviderSnapshot.loading(.claude)
    @Published var selectedProvider: ProviderKind = .codex
    @Published var isRefreshing = false
    @Published var isDemoMode: Bool {
        didSet {
            UserDefaults.standard.set(isDemoMode, forKey: Self.demoModeDefaultsKey)
        }
    }

    private let codexService = CodexLimitService()
    private let claudeService = ClaudeLimitService()
    private let demoService = DemoLimitService()
    private var pollingTask: Task<Void, Never>?

    init() {
        let requestedDemoMode = ProcessInfo.processInfo.arguments.contains("--demo")
            || ProcessInfo.processInfo.environment["LIMIT_LENS_DEMO_MODE"] == "1"

        isDemoMode = requestedDemoMode
            || UserDefaults.standard.bool(forKey: Self.demoModeDefaultsKey)
    }

    var selectedSnapshot: ProviderSnapshot {
        switch selectedProvider {
        case .codex: codex
        case .claude: claude
        }
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

        Task {
            await refreshNow()
        }
    }

    func refreshNow() async {
        guard !isRefreshing else { return }

        let demoMode = isDemoMode
        isRefreshing = true
        defer { isRefreshing = false }

        if demoMode {
            let now = Date()
            codex = demoService.codexSnapshot(now: now)
            claude = demoService.claudeSnapshot(now: now)
            return
        }

        async let codexSnapshot = codexService.fetchSnapshot()
        async let claudeSnapshot = claudeService.fetchSnapshot()

        codex = await codexSnapshot
        claude = await claudeSnapshot
    }
}
