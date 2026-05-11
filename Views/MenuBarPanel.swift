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
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.isRefreshing)
                .help("Refresh now")
            }

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
            }
        }
        .padding(16)
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
    }
}
