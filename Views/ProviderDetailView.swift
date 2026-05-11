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
                        .foregroundStyle(.red)
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

                Text(LimitFormatters.percentString(window.usedPercent))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(window.usedPercent == nil ? .secondary : .primary)
            }

            if let usedPercent = window.usedPercent {
                ProgressView(value: max(0, min(usedPercent / 100, 1)))
                    .tint(color(for: usedPercent))
                    .accessibilityLabel("\(window.label) usage")
                    .accessibilityValue(LimitFormatters.percentString(window.usedPercent))
            } else {
                ProgressView(value: 0)
                    .tint(.secondary)
                    .accessibilityLabel("\(window.label) usage")
                    .accessibilityValue("Unknown")
            }

            Text(LimitFormatters.resetText(window.resetsAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(window.label)
        .accessibilityValue("\(LimitFormatters.percentString(window.usedPercent)). \(LimitFormatters.resetText(window.resetsAt))")
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

private struct MetricTile: View {
    var metric: UsageMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(metric.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(metric.value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let detail = metric.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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
        switch state {
        case .loading:
            return .secondary
        case .ready:
            return .green
        case .unavailable:
            return .orange
        case .failed:
            return .red
        }
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
