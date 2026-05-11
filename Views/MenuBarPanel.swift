import AppKit
import SwiftUI

struct MenuBarPanel: View {
    @Environment(\.dismiss) private var dismiss
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
                Text(LimitFormatters.updatedText(store.codex.updatedAt ?? store.claude.updatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button("Open Window") {
                    openMainWindowFromPopup()
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

    private func openMainWindowFromPopup() {
        let popupWindow = NSApp.keyWindow
        openWindow(id: "main")
        dismiss()
        focusMainWindowSoon(closing: popupWindow)
    }

    private func focusMainWindowSoon(closing popupWindow: NSWindow?) {
        DispatchQueue.main.async {
            closePopupIfNeeded(popupWindow)
            focusMainWindow()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            closePopupIfNeeded(popupWindow)
            focusMainWindow()
        }
    }

    private func closePopupIfNeeded(_ window: NSWindow?) {
        guard let window, window.title != "Limit Lens" else {
            return
        }

        window.orderOut(nil)
    }

    private func focusMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        guard let window = NSApp.windows.first(where: { $0.title == "Limit Lens" }) else {
            return
        }

        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
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
                    .foregroundStyle(primaryValue == "--" ? .secondary : .primary)
            }

            if let window = primaryWindow, let used = window.usedPercent {
                ProgressView(value: max(0, min(used / 100, 1)))
                    .tint(color(for: used))
                Text(
                    LimitFormatters.exactResetText(
                        window.resetsAt,
                        windowLabel: weeklyLabel(for: window),
                        durationMinutes: window.durationMinutes
                    )
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(weeklyFallbackText)
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
        return windows.first { window in
            window.label.localizedCaseInsensitiveContains("Weekly")
                || window.durationMinutes == 10_080
        }
    }

    private var primaryValue: String {
        guard let used = primaryWindow?.usedPercent else {
            return "--"
        }

        return LimitFormatters.percentString(used)
    }

    private var weeklyFallbackText: String {
        switch snapshot.state {
        case .ready:
            if primaryWindow == nil {
                return "Weekly window unavailable"
            }

            return "Weekly percentage unavailable"
        default:
            return snapshot.detail
        }
    }

    private func weeklyLabel(for window: LimitWindow) -> String {
        if window.label.localizedCaseInsensitiveContains("all-model") {
            return "Weekly all-model"
        }

        return "Weekly"
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
