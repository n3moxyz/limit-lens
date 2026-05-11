import SwiftUI

struct SuggestedRouteCard: View {
    var route: SuggestedRoute
    var showsDemoControls = false
    var onSimulateLimitPressure: () -> Void = {}
    var onSimulateResetAvailable: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

                if showsDemoControls {
                    DemoEventControls(
                        onSimulateLimitPressure: onSimulateLimitPressure,
                        onSimulateResetAvailable: onSimulateResetAvailable
                    )
                }
            }

            Text(route.rationale)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suggested route")
        .accessibilityValue("\(route.title). \(route.recommendation). \(route.rationale)")
        .accessibilityIdentifier("suggested-route-card")
    }

    private var tint: Color {
        SuggestedRouteColor.color(named: route.tintName)
    }
}

struct SuggestedRouteMini: View {
    var route: SuggestedRoute
    var showsDemoControls = false
    var onSimulateLimitPressure: () -> Void = {}
    var onSimulateResetAvailable: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(route.title, systemImage: route.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SuggestedRouteColor.color(named: route.tintName))

            Text(route.recommendation)
                .font(.caption.weight(.medium))
                .lineLimit(2)

            Text(route.rationale)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if showsDemoControls {
                DemoEventControls(
                    onSimulateLimitPressure: onSimulateLimitPressure,
                    onSimulateResetAvailable: onSimulateResetAvailable
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suggested route")
        .accessibilityValue("\(route.title). \(route.recommendation). \(route.rationale)")
        .accessibilityIdentifier("menu-suggested-route")
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

private enum SuggestedRouteColor {
    static func color(named name: String) -> Color {
        switch name {
        case "blue":
            return .blue
        case "green":
            return .green
        case "orange":
            return .orange
        case "purple":
            return .purple
        case "red":
            return .red
        default:
            return .secondary
        }
    }
}
