import SwiftUI

struct ProviderDetailView: View {
    @State private var isDiagnosticsExpanded = false

    var snapshot: ProviderSnapshot
    var route: SuggestedRoute
    var showsDemoControls = false
    var notificationStatusMessage: String?
    var showsNotificationSettingsAction = false
    var onSimulateLimitPressure: () -> Void = {}
    var onSimulateResetAvailable: () -> Void = {}
    var onOpenNotificationSettings: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SuggestedRouteCard(
                    route: route,
                    showsDemoControls: showsDemoControls,
                    notificationStatusMessage: notificationStatusMessage,
                    showsNotificationSettingsAction: showsNotificationSettingsAction,
                    onSimulateLimitPressure: onSimulateLimitPressure,
                    onSimulateResetAvailable: onSimulateResetAvailable,
                    onOpenNotificationSettings: onOpenNotificationSettings
                )

                HeaderView(snapshot: snapshot)

                if !snapshot.buckets.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Limits")
                            .font(.headline)

                        ForEach(snapshot.buckets) { bucket in
                            BucketCard(bucket: bucket)
                        }
                    }
                }

                if !snapshot.metrics.isEmpty {
                    DisclosureGroup(isExpanded: $isDiagnosticsExpanded) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            ForEach(snapshot.metrics) { metric in
                                MetricTile(metric: metric)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text(snapshot.provider == .codex ? "Diagnostics" : "Signals")
                            .font(.headline)
                    }
                    .accessibilityIdentifier("diagnostics-disclosure")
                }

                SourceNote(provider: snapshot.provider)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("\(snapshot.provider.rawValue.lowercased())-detail-view")
        }
    }
}

private struct HeaderView: View {
    var snapshot: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: snapshot.provider.systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.provider.rawValue)
                        .font(.largeTitle.weight(.semibold))
                        .lineLimit(1)

                    Text(LimitFormatters.updatedText(snapshot.updatedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatePill(state: snapshot.state)
            }

            Text(snapshot.headline)
                .font(.title2.weight(.semibold))

            Text(snapshot.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snapshot.provider.rawValue) status")
        .accessibilityValue("\(snapshot.headline). \(snapshot.detail)")
    }
}

private struct BucketCard: View {
    var bucket: LimitBucket

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(bucket.title)
                        .font(.headline)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let reachedType = bucket.reachedType {
                    Text(reachedType)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LimitTheme.stateColor(for: .failed(reachedType)))
                }
            }

            ForEach(bucket.windows) { window in
                WindowUsageRow(window: window)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(bucket.title)
        .accessibilityIdentifier("bucket-card-\(bucket.id)")
    }

    private var subtitle: String? {
        let parts: [String] = [bucket.planType, bucket.creditSummary].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct WindowUsageRow: View {
    var window: LimitWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(window.label)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text(usageLabel)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(window.usedPercent == nil ? .secondary : .primary)
            }

            if let usedPercent = window.usedPercent {
                ProgressView(value: max(0, min(usedPercent / 100, 1)))
                    .tint(LimitTheme.usageColor(for: usedPercent))
                    .accessibilityLabel("\(window.label) usage")
                    .accessibilityValue(LimitFormatters.percentString(window.usedPercent))
            } else {
                UnreportedUsageBar()
            }

            Text(footnoteLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(window.label)
        .accessibilityValue("\(usageAccessibilityValue). \(footnoteLabel)")
    }

    private var usageLabel: String {
        guard let usedPercent = window.usedPercent else {
            return "Not reported"
        }

        return LimitFormatters.percentString(usedPercent)
    }

    private var usageAccessibilityValue: String {
        guard let usedPercent = window.usedPercent else {
            return "Usage not reported"
        }

        return LimitFormatters.percentString(usedPercent)
    }

    private var footnoteLabel: String {
        guard window.usedPercent == nil else {
            return exactResetText
        }

        guard window.resetsAt != nil else {
            return "Usage and reset time not reported"
        }

        return "Usage not reported · \(exactResetText)"
    }

    private var exactResetText: String {
        LimitFormatters.exactResetText(
            window.resetsAt,
            windowLabel: resetWindowLabel,
            durationMinutes: window.durationMinutes
        )
    }

    private var resetWindowLabel: String {
        if window.label.localizedCaseInsensitiveContains("Weekly all-model") {
            return "Weekly all-model"
        }

        if window.label.localizedCaseInsensitiveContains("5-hour") {
            return "5-hour"
        }

        if window.label.localizedCaseInsensitiveContains("Weekly") {
            return "Weekly"
        }

        return window.label
    }
}

private struct UnreportedUsageBar: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(LimitTheme.unavailableUsageColor.opacity(0.18))
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(LimitTheme.unavailableUsageColor.opacity(0.32), lineWidth: 1)
            }
            .frame(height: 6)
            .accessibilityLabel("Usage")
            .accessibilityValue("Not reported")
    }
}

private struct MetricTile: View {
    var metric: UsageMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(metric.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .help(metric.title)

            Text(metric.value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .help(metric.value)

            if let detail = metric.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .help(detail)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(metric.title)
        .accessibilityValue([metric.value, metric.detail].compactMap { $0 }.joined(separator: ". "))
        .accessibilityIdentifier("metric-\(metric.id)")
    }
}

private struct StatePill: View {
    var state: SnapshotState

    var body: some View {
        Text(state.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel("State")
            .accessibilityValue(state.label)
    }

    private var color: Color {
        LimitTheme.stateColor(for: state)
    }
}

private struct SourceNote: View {
    var provider: ProviderKind

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Link(linkLabel, destination: docsURL)
                Spacer()
            }
            .font(.caption)
        }
        .padding(.top, 4)
    }

    private var note: String {
        switch provider {
        case .codex:
            return "Codex is read from the local app-server account/rateLimits/read endpoint, so the percentages come from your signed-in Codex account."
        case .claude:
            return "Claude live usage is read from the documented Claude Code statusline rate_limits payload when the optional Limit Lens bridge is installed. Claude currently exposes 5-hour and 7-day all-model windows there; the separate Sonnet-only weekly Settings bar is not included."
        }
    }

    private var linkLabel: String {
        switch provider {
        case .codex:
            return "Open source docs"
        case .claude:
            return "Open usage dashboard"
        }
    }

    private var docsURL: URL {
        switch provider {
        case .codex:
            return URL(string: "https://developers.openai.com/codex/app-server#6-rate-limits-chatgpt")!
        case .claude:
            return URL(string: "https://claude.ai/settings/usage")!
        }
    }
}
