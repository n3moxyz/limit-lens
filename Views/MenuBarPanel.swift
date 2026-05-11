import SwiftUI

struct MenuBarPanel: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: LimitStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Limit Lens")
                    .font(.headline)

                Spacer()

                Button {
                    Task { await store.refreshNow() }
                } label: {
                    Label("Refresh Limits", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.isRefreshing)
                .help("Refresh now")
                .accessibilityLabel("Refresh limits")
                .accessibilityHint("Checks Codex and Claude usage limits now")
                .accessibilityIdentifier("menu-refresh-limits-button")
            }

            Toggle(
                isOn: Binding(
                    get: { store.isDemoMode },
                    set: { store.setDemoMode($0) }
                )
            ) {
                Label("Demo Mode", systemImage: "sparkles")
            }
            .help("Use deterministic sample data")
            .accessibilityLabel("Demo mode")
            .accessibilityValue(store.isDemoMode ? "On" : "Off")
            .accessibilityHint("Switches between deterministic sample data and live command output")
            .accessibilityIdentifier("menu-demo-mode-toggle")

            SuggestedRouteMini(route: store.suggestedRoute)

            MiniProvider(snapshot: store.codex)
            Divider()
            MiniProvider(snapshot: store.claude)

            HStack {
                Text(LimitFormatters.updatedText(store.codex.updatedAt ?? store.claude.updatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Open Window") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                .font(.caption)
                .help("Open Limit Lens window")
                .accessibilityLabel("Open Limit Lens window")
                .accessibilityIdentifier("open-main-window-button")
            }
        }
        .padding(16)
        .accessibilityIdentifier("menu-bar-panel")
    }
}

private struct MiniProvider: View {
    var snapshot: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(snapshot.provider.rawValue, systemImage: snapshot.provider.systemImage)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(snapshot.state.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(snapshot.headline)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(snapshot.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let window = snapshot.buckets.first?.windows.first, let used = window.usedPercent {
                ProgressView(value: max(0, min(used / 100, 1)))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snapshot.provider.rawValue) menu summary")
        .accessibilityValue("\(snapshot.state.label). \(snapshot.headline). \(snapshot.detail)")
        .accessibilityIdentifier("menu-summary-\(snapshot.provider.rawValue.lowercased())")
    }
}
