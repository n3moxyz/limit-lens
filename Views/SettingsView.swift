import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LimitStore

    var body: some View {
        Form {
            Section("Startup") {
                LaunchAtLoginSettings(launchAtLogin: store.launchAtLogin)
            }

            Section("Notifications") {
                Toggle(
                    isOn: Binding(
                        get: { store.notificationPreferences.isEnabled },
                        set: { store.setNotificationsEnabled($0) }
                    )
                ) {
                    Label("Limit Alerts", systemImage: "bell.badge")
                }
                .accessibilityLabel("Limit alerts")
                .accessibilityHint("Schedules usage and reset warning notifications")
                .accessibilityIdentifier("limit-alerts-toggle")

                Toggle(
                    isOn: Binding(
                        get: { store.notificationPreferences.usageThresholdEnabled },
                        set: { store.setUsageThresholdNotificationsEnabled($0) }
                    )
                ) {
                    Label("Usage Threshold", systemImage: "gauge")
                }
                .disabled(!store.notificationPreferences.isEnabled)
                .accessibilityLabel("Usage threshold alerts")
                .accessibilityHint("Notifies when a usage window reaches the selected percentage")
                .accessibilityIdentifier("usage-threshold-alerts-toggle")

                LabeledContent("Notify at") {
                    Stepper(
                        value: Binding(
                            get: { store.notificationPreferences.usageThresholdPercent },
                            set: { store.setUsageThresholdPercent($0) }
                        ),
                        in: LimitNotificationPreferences.usageThresholdRange,
                        step: 5
                    ) {
                        Text("\(store.notificationPreferences.usageThresholdPercent)%")
                            .monospacedDigit()
                    }
                    .disabled(
                        !store.notificationPreferences.isEnabled
                            || !store.notificationPreferences.usageThresholdEnabled
                    )
                    .accessibilityLabel("Usage threshold percentage")
                    .accessibilityValue("\(store.notificationPreferences.usageThresholdPercent) percent")
                    .accessibilityIdentifier("usage-threshold-stepper")
                }

                Toggle(
                    isOn: Binding(
                        get: { store.notificationPreferences.resetWarningEnabled },
                        set: { store.setResetWarningNotificationsEnabled($0) }
                    )
                ) {
                    Label("Reset Warning", systemImage: "clock")
                }
                .disabled(!store.notificationPreferences.isEnabled)
                .accessibilityLabel("Reset warning alerts")
                .accessibilityHint("Notifies before a usage window resets")
                .accessibilityIdentifier("reset-warning-alerts-toggle")

                LabeledContent("Before reset") {
                    Stepper(
                        value: Binding(
                            get: { store.notificationPreferences.resetWarningLeadHours },
                            set: { store.setResetWarningLeadHours($0) }
                        ),
                        in: LimitNotificationPreferences.resetWarningLeadHoursRange,
                        step: 1
                    ) {
                        Text("\(store.notificationPreferences.resetWarningLeadHours)h")
                            .monospacedDigit()
                    }
                    .disabled(
                        !store.notificationPreferences.isEnabled
                            || !store.notificationPreferences.resetWarningEnabled
                    )
                    .accessibilityLabel("Reset warning lead time")
                    .accessibilityValue("\(store.notificationPreferences.resetWarningLeadHours) hours")
                    .accessibilityIdentifier("reset-warning-lead-stepper")
                }

                LabeledContent("Notify for") {
                    ResetWarningWindowPicker()
                        .disabled(
                            !store.notificationPreferences.isEnabled
                                || !store.notificationPreferences.resetWarningEnabled
                        )
                }

                Button {
                    store.openNotificationSettings()
                } label: {
                    Label("Open Notification Settings", systemImage: "gear")
                }
                .accessibilityLabel("Open notification settings")
                .accessibilityIdentifier("open-notification-settings-button")
            }

            Section("Codex Setup") {
                LabeledContent("CLI") {
                    Text(store.codexSetupStatus.cliLabel)
                        .foregroundStyle(LimitTheme.setupColor(isReady: store.codexSetupStatus.cliInstalled))
                }

                LabeledContent("ChatGPT account") {
                    Text(store.codexSetupStatus.accountLabel)
                        .foregroundStyle(LimitTheme.setupColor(isReady: store.codexSetupStatus.signedIn))
                }

                if let planType = store.codexSetupStatus.planType {
                    LabeledContent("Plan") {
                        Text(planType)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Rate limits") {
                    Text(store.codexSetupStatus.limitsLabel)
                        .foregroundStyle(LimitTheme.setupColor(isReady: store.codexSetupStatus.bucketCount > 0))
                }

                Text(store.codexSetupStatus.nextStep)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let message = store.codexSetupMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AdaptiveSettingsActions {
                    Button {
                        store.openCodexLoginInTerminal()
                    } label: {
                        Label("Open ChatGPT Login", systemImage: "terminal")
                    }
                    .accessibilityLabel("Open ChatGPT login")
                    .accessibilityIdentifier("open-codex-login-button")

                    Button {
                        Task {
                            await store.refreshCodexSetupStatus()
                            await store.refreshNow()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing)
                    .help("Refresh Codex setup")
                    .accessibilityLabel("Refresh Codex setup")
                    .accessibilityIdentifier("refresh-codex-setup-button")
                }
            }

            Section("Claude Setup") {
                LabeledContent("Signed in") {
                    Text(store.claudeSetupStatus.isSignedIn ? "Yes" : "No")
                        .foregroundStyle(LimitTheme.setupColor(isReady: store.claudeSetupStatus.isSignedIn))
                }

                LabeledContent("Bridge") {
                    Text(store.claudeSetupStatus.bridgeLabel)
                        .foregroundStyle(LimitTheme.setupColor(isReady: store.claudeSetupStatus.bridgeInstalled))
                }

                LabeledContent("Live cache") {
                    Text(store.claudeSetupStatus.cacheLabel)
                        .foregroundStyle(LimitTheme.setupColor(isReady: store.claudeSetupStatus.cacheHasFreshLimits))
                }

                Text(store.claudeSetupStatus.nextStep)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let message = store.claudeSetupMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AdaptiveSettingsActions {
                    Button {
                        store.openClaudeLoginInTerminal()
                    } label: {
                        Label("Open Claude Login", systemImage: "terminal")
                    }
                    .accessibilityLabel("Open Claude login")
                    .accessibilityIdentifier("open-claude-login-button")

                    Button {
                        Task { await store.installClaudeStatuslineBridge() }
                    } label: {
                        Label("Install Bridge", systemImage: "link")
                    }
                    .disabled(store.isInstallingClaudeBridge)
                    .accessibilityLabel("Install Claude statusline bridge")
                    .accessibilityIdentifier("install-claude-bridge-button")

                    Button {
                        Task {
                            await store.refreshClaudeSetupStatus()
                            await store.refreshNow()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing)
                    .help("Refresh Claude setup")
                    .accessibilityLabel("Refresh Claude setup")
                    .accessibilityIdentifier("refresh-claude-setup-button")
                }
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
        .frame(maxWidth: 620, alignment: .leading)
        .task {
            await store.refreshSetupStatuses()
        }
    }
}

private struct ResetWarningWindowPicker: View {
    @EnvironmentObject private var store: LimitStore

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 8) {
            GridRow {
                Text("Codex")
                    .foregroundStyle(.secondary)
                ResetWarningWindowToggle(window: .codexFiveHour)
                ResetWarningWindowToggle(window: .codexWeekly)
            }

            GridRow {
                Text("Claude")
                    .foregroundStyle(.secondary)
                ResetWarningWindowToggle(window: .claudeFiveHour)
                ResetWarningWindowToggle(window: .claudeWeekly)
            }
        }
        .font(.callout)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reset-warning-window-picker")
    }
}

private struct ResetWarningWindowToggle: View {
    @EnvironmentObject private var store: LimitStore

    var window: ResetWarningWindow

    var body: some View {
        Toggle(
            window.title,
            isOn: Binding(
                get: { store.notificationPreferences.resetWarningWindows.contains(window) },
                set: { store.setResetWarningWindow(window, enabled: $0) }
            )
        )
        .toggleStyle(.checkbox)
        .accessibilityLabel("\(window.provider.rawValue) \(window.title) reset warning")
        .accessibilityIdentifier("reset-warning-window-\(window.rawValue)")
    }
}

private struct LaunchAtLoginSettings: View {
    @ObservedObject var launchAtLogin: LaunchAtLogin

    var body: some View {
        Toggle(
            isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            )
        ) {
            Label("Launch at Login", systemImage: "power")
        }
        .accessibilityLabel("Launch at login")
        .accessibilityHint("Starts Limit Lens automatically when you sign in to macOS")
        .accessibilityIdentifier("launch-at-login-toggle")

        if let error = launchAtLogin.lastError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AdaptiveSettingsActions<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                content
            }

            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
    }
}
