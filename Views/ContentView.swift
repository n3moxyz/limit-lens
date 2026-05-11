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
                ToolbarItem {
                    Button {
                        Task { await store.refreshNow() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing)
                    .help("Refresh limits")
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
    }

    private var rowSubtitle: String {
        if let plan = snapshot.planType, !plan.isEmpty {
            return "\(snapshot.state.label) · \(plan)"
        }

        return snapshot.state.label
    }
}
