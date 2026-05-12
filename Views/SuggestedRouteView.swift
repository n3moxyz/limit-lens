import SwiftUI

struct SuggestedRouteCard: View {
    var route: SuggestedRoute
    var showsDemoControls = false
    var notificationStatusMessage: String?
    var showsNotificationSettingsAction = false
    var onSimulateLimitPressure: () -> Void = {}
    var onSimulateResetAvailable: () -> Void = {}
    var onOpenNotificationSettings: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: route.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggested Route")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(route.title)
                        .font(.headline)

                    Text(route.recommendation)
                        .font(.subheadline.weight(.medium))
                }

                Spacer()
            }

            Text(route.rationale)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if showsDemoControls {
                DemoControlsDisclosure(
                    notificationStatusMessage: notificationStatusMessage,
                    showsNotificationSettingsAction: showsNotificationSettingsAction,
                    onSimulateLimitPressure: onSimulateLimitPressure,
                    onSimulateResetAvailable: onSimulateResetAvailable,
                    onOpenNotificationSettings: onOpenNotificationSettings
                )
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suggested route")
        .accessibilityValue("\(route.title). \(route.recommendation). \(route.rationale)")
        .accessibilityIdentifier("suggested-route-card")
    }

    private var tint: Color {
        LimitTheme.suggestedRouteColor(named: route.tintName)
    }
}

struct SuggestedRouteMini: View {
    var route: SuggestedRoute
    var showsDemoControls = false
    var notificationStatusMessage: String?
    var showsNotificationSettingsAction = false
    var onSimulateLimitPressure: () -> Void = {}
    var onSimulateResetAvailable: () -> Void = {}
    var onOpenNotificationSettings: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(route.title, systemImage: route.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LimitTheme.suggestedRouteColor(named: route.tintName))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .help(route.title)

            Text(route.recommendation)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .help(route.recommendation)

            if showsDemoControls {
                DemoControlsDisclosure(
                    notificationStatusMessage: notificationStatusMessage,
                    showsNotificationSettingsAction: showsNotificationSettingsAction,
                    onSimulateLimitPressure: onSimulateLimitPressure,
                    onSimulateResetAvailable: onSimulateResetAvailable,
                    onOpenNotificationSettings: onOpenNotificationSettings
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suggested route")
        .accessibilityValue("\(route.title). \(route.recommendation)")
        .accessibilityIdentifier("menu-suggested-route")
    }
}

private struct DemoControlsDisclosure: View {
    @State private var isExpanded = false

    var notificationStatusMessage: String?
    var showsNotificationSettingsAction: Bool
    var onSimulateLimitPressure: () -> Void
    var onSimulateResetAvailable: () -> Void
    var onOpenNotificationSettings: () -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                DemoEventControls(
                    onSimulateLimitPressure: onSimulateLimitPressure,
                    onSimulateResetAvailable: onSimulateResetAvailable
                )

                if let notificationStatusMessage {
                    DemoNotificationStatus(
                        message: notificationStatusMessage,
                        showsNotificationSettingsAction: showsNotificationSettingsAction,
                        onOpenNotificationSettings: onOpenNotificationSettings
                    )
                }
            }
            .padding(.top, 6)
        } label: {
            Label("Demo controls", systemImage: "slider.horizontal.3")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("demo-controls-disclosure")
    }
}

private struct DemoNotificationStatus: View {
    var message: String
    var showsNotificationSettingsAction: Bool
    var onOpenNotificationSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(message, systemImage: "bell.badge")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if showsNotificationSettingsAction {
                Button {
                    onOpenNotificationSettings()
                } label: {
                    Label("Open Notification Settings", systemImage: "gear")
                }
                .font(.caption)
                .buttonStyle(.link)
                .accessibilityLabel("Open notification settings")
                .accessibilityIdentifier("route-open-notification-settings-button")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Demo notification status")
        .accessibilityValue(message)
        .accessibilityIdentifier("demo-notification-status")
    }
}

private struct DemoEventControls: View {
    var onSimulateLimitPressure: () -> Void
    var onSimulateResetAvailable: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button {
                onSimulateLimitPressure()
            } label: {
                Image(systemName: "exclamationmark.triangle")
                    .frame(width: 30, height: 28)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Demo: Codex approaching limit")
            .accessibilityLabel("Demo approaching limit")
            .accessibilityHint("Updates demo data and sends a limit pressure notification")
            .accessibilityIdentifier("demo-limit-pressure-button")

            Button {
                onSimulateResetAvailable()
            } label: {
                Image(systemName: "checkmark.circle")
                    .frame(width: 30, height: 28)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Demo: Codex reset available")
            .accessibilityLabel("Demo reset available")
            .accessibilityHint("Updates demo data and sends a reset available notification")
            .accessibilityIdentifier("demo-reset-available-button")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}
