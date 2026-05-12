import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LimitStore

    var body: some View {
        Form {
            Section("Startup") {
                LaunchAtLoginSettings(launchAtLogin: store.launchAtLogin)
            }

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
                    Text(LimitFormatters.coarseDuration(UsagePoller.defaultNormalInterval))
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

                Button {
                    store.openNotificationSettings()
                } label: {
                    Label("Open Notification Settings", systemImage: "gear")
                }
                .accessibilityLabel("Open notification settings")
                .accessibilityIdentifier("open-notification-settings-button")

                Text("Limit Lens can notify you when a reported Codex or Claude window becomes available again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
