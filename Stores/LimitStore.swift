import Foundation

@MainActor
final class LimitStore: ObservableObject {
    @Published var codex = ProviderSnapshot.loading(.codex)
    @Published var claude = ProviderSnapshot.loading(.claude)
    @Published var selectedProvider: ProviderKind = .codex
    @Published var isRefreshing = false

    private let codexService = CodexLimitService()
    private let claudeService = ClaudeLimitService()
    private var pollingTask: Task<Void, Never>?

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

        let claudePart = claude.state == .ready ? "Cl live" : "Cl --"
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

    func refreshNow() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        async let codexSnapshot = codexService.fetchSnapshot()
        async let claudeSnapshot = claudeService.fetchSnapshot()

        codex = await codexSnapshot
        claude = await claudeSnapshot
        isRefreshing = false
    }
}
