import SwiftUI

struct MenuBarPanel: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: LimitStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            SuggestedRouteMini(
                route: store.suggestedRoute,
                showsDemoControls: store.isDemoMode,
                notificationStatusMessage: store.notificationStatusMessage,
                showsNotificationSettingsAction: store.showsNotificationSettingsAction,
                onSimulateLimitPressure: store.simulateDemoLimitPressure,
                onSimulateResetAvailable: store.simulateDemoResetAvailable,
                onOpenNotificationSettings: store.openNotificationSettings
            )

            MiniProvider(snapshot: store.codex)
            MiniProvider(snapshot: store.claude)

            Divider()

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.secondary)

                    Text("Demo")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { store.isDemoMode },
                            set: { store.setDemoMode($0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
                .help("Use deterministic sample data")
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Demo mode")
                .accessibilityValue(store.isDemoMode ? "On" : "Off")
                .accessibilityHint("Switches between deterministic sample data and live command output")
                .accessibilityIdentifier("menu-demo-mode-toggle")

                Text(LimitFormatters.updatedText(store.codex.updatedAt ?? store.claude.updatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(snapshot.provider.rawValue, systemImage: snapshot.provider.systemImage)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(primaryValue)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(primaryValue == "Unknown" ? .secondary : .primary)
            }

            if let window = primaryWindow, let used = window.usedPercent {
                ProgressView(value: max(0, min(used / 100, 1)))
                    .tint(color(for: used))
                Text(LimitFormatters.resetText(window.resetsAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(snapshot.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snapshot.provider.rawValue) menu summary")
        .accessibilityValue("\(snapshot.state.label). \(snapshot.headline). \(snapshot.detail)")
        .accessibilityIdentifier("menu-summary-\(snapshot.provider.rawValue.lowercased())")
    }

    private var primaryWindow: LimitWindow? {
        let windows = snapshot.buckets.flatMap(\.windows)
        return windows.first { $0.label.contains("Weekly all-model") }
            ?? windows.first { $0.label.contains("5-hour") }
            ?? windows.first
    }

    private var primaryValue: String {
        LimitFormatters.percentString(primaryWindow?.usedPercent)
    }

    private func color(for percent: Double) -> Color {
        switch percent {
        case 85...:
            return .red
        case 65..<85:
            return .orange
        default:
            return .green
        }
    }
}
