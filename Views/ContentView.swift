import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: LimitStore
    @State private var selectedPane: MainPane = .provider(.codex)

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: Binding(
                    get: { selectedPane },
                    set: { selectPane($0) }
                )) {
                    ForEach(ProviderKind.allCases) { provider in
                        ProviderRow(snapshot: snapshot(for: provider))
                            .tag(MainPane.provider(provider))
                    }
                }
                .listStyle(.sidebar)

                Divider()

                SidebarFooter(
                    isDemoMode: Binding(
                        get: { store.isDemoMode },
                        set: { store.setDemoMode($0) }
                    ),
                    isSettingsSelected: selectedPane == .settings,
                    onSettings: { selectPane(.settings) }
                )
            }
            .navigationTitle("Limits")
        } detail: {
            switch selectedPane {
            case .provider:
                ProviderDetailView(
                    snapshot: store.selectedSnapshot,
                    route: store.suggestedRoute,
                    isRefreshing: store.isRefreshing,
                    showsDemoControls: store.isDemoMode,
                    notificationStatusMessage: store.notificationStatusMessage,
                    showsNotificationSettingsAction: store.showsNotificationSettingsAction,
                    onRefresh: {
                        Task { await store.refreshNow() }
                    },
                    onSimulateLimitPressure: store.simulateDemoLimitPressure,
                    onSimulateResetAvailable: store.simulateDemoResetAvailable,
                    onOpenNotificationSettings: store.openNotificationSettings
                )

            case .settings:
                SettingsDetailView()
            }
        }
        .background(MainWindowIdentifierView())
    }

    private func selectPane(_ pane: MainPane) {
        selectedPane = pane

        if case let .provider(provider) = pane {
            store.selectedProvider = provider
        }
    }

    private func snapshot(for provider: ProviderKind) -> ProviderSnapshot {
        switch provider {
        case .codex: store.codex
        case .claude: store.claude
        }
    }
}

private enum MainPane: Hashable {
    case provider(ProviderKind)
    case settings
}

private struct SidebarFooter: View {
    @Binding var isDemoMode: Bool
    var isSettingsSelected: Bool
    var onSettings: () -> Void

    var body: some View {
        HStack {
            Button {
                onSettings()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 34, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                isSettingsSelected ? Color.accentColor.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .foregroundStyle(isSettingsSelected ? .primary : .secondary)
            .help("Settings")
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("sidebar-settings-button")

            Spacer(minLength: 8)

            Toggle(isOn: $isDemoMode) {
                Label("Demo", systemImage: "sparkles")
                    .font(.caption.weight(.medium))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelStyle(.titleAndIcon)
            .fixedSize()
            .help("Demo mode")
            .accessibilityLabel("Demo mode")
            .accessibilityValue(isDemoMode ? "On" : "Off")
            .accessibilityHint("Switches between deterministic sample data and live command output")
            .accessibilityIdentifier("sidebar-demo-mode-toggle")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct SettingsDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title2.weight(.semibold))

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()

            SettingsView()
        }
        .accessibilityIdentifier("settings-detail-view")
    }
}

private struct MainWindowIdentifierView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        setIdentifier(on: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        setIdentifier(on: nsView)
    }

    private func setIdentifier(on view: NSView) {
        DispatchQueue.main.async {
            view.window?.identifier = LimitWindowIdentifiers.main
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
                    .help(rowSubtitle)
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
