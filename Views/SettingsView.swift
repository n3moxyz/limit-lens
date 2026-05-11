import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LimitStore

    var body: some View {
        Form {
            Section("Demo") {
                Toggle(
                    isOn: Binding(
                        get: { store.isDemoMode },
                        set: { store.setDemoMode($0) }
                    )
                ) {
                    Label("Demo Mode", systemImage: "sparkles")
                }
                .accessibilityLabel("Demo mode")
                .accessibilityHint("Uses deterministic sample data instead of live command output")
                .accessibilityIdentifier("demo-mode-toggle")

                Text("Use deterministic sample data for Codex and Claude during live demos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Refresh") {
                HStack {
                    Text("Interval")
                    Spacer()
                    Text("30 seconds")
                        .foregroundStyle(.secondary)
                }

                Button("Refresh Now") {
                    Task { await store.refreshNow() }
                }
                .disabled(store.isRefreshing)
                .accessibilityLabel("Refresh limits now")
                .accessibilityHint("Checks Codex and Claude usage limits now")
                .accessibilityIdentifier("settings-refresh-limits-button")
            }

            Section("Notifications") {
                Toggle(
                    isOn: Binding(
                        get: { store.resetNotificationsEnabled },
                        set: { store.setResetNotificationsEnabled($0) }
                    )
                ) {
                    Label("Reset Alerts", systemImage: "bell")
                }
                .accessibilityLabel("Reset alerts")
                .accessibilityHint("Schedules a notification when a usage window resets")
                .accessibilityIdentifier("reset-alerts-toggle")

                Text("Limit Lens can notify you when a reported Codex or Claude window becomes available again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Command Sources") {
                LabeledContent("Codex") {
                    Text("codex app-server")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Claude") {
                    Text("claude auth status + statusline bridge + local history")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }
}
