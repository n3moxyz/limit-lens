import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: LimitStore

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedProvider) {
                ForEach(ProviderKind.allCases) { provider in
                    ProviderRow(snapshot: snapshot(for: provider))
                        .tag(provider)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Limits")
            .toolbar {
                ToolbarItemGroup {
                    Toggle(
                        isOn: Binding(
                            get: { store.isDemoMode },
                            set: { store.setDemoMode($0) }
                        )
                    ) {
                        Label("Demo Mode", systemImage: "sparkles")
                    }
                    .toggleStyle(.button)
                    .help("Use deterministic sample data")
                    .accessibilityLabel("Demo mode")
                    .accessibilityValue(store.isDemoMode ? "On" : "Off")
                    .accessibilityHint("Switches between deterministic sample data and live command output")
                    .accessibilityIdentifier("toolbar-demo-mode-toggle")

                    Button {
                        Task { await store.refreshNow() }
                    } label: {
                        Label("Refresh Limits", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing)
                    .help("Refresh limits")
                    .accessibilityLabel("Refresh limits")
                    .accessibilityHint("Checks Codex and Claude usage limits now")
                    .accessibilityIdentifier("refresh-limits-button")
                }
            }
        } detail: {
            ProviderDetailView(snapshot: store.selectedSnapshot)
        }
    }

    private func snapshot(for provider: ProviderKind) -> ProviderSnapshot {
        switch provider {
        case .codex: store.codex
        case .claude: store.claude
        }
    }
}

private struct ProviderRow: View {
    var snapshot: ProviderSnapshot

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: snapshot.provider.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.provider.rawValue)
                    .lineLimit(1)

                Text(rowSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snapshot.provider.rawValue) provider")
        .accessibilityValue(rowSubtitle)
        .accessibilityIdentifier("provider-row-\(snapshot.provider.rawValue.lowercased())")
    }

    private var rowSubtitle: String {
        if let plan = snapshot.planType, !plan.isEmpty {
            return "\(snapshot.state.label) · \(plan)"
        }

        return snapshot.state.label
    }
}
