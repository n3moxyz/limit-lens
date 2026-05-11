import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LimitStore

    var body: some View {
        Form {
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
            }

            Section("Command Sources") {
                LabeledContent("Codex") {
                    Text("codex app-server")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Claude") {
                    Text("claude auth status + local history")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }
}
