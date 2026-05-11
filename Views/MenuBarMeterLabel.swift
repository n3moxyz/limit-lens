import AppKit
import SwiftUI

struct MenuBarMeterLabel: View {
    var codex: ProviderSnapshot
    var claude: ProviderSnapshot

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(nsImage: renderedImage)
            .accessibilityLabel("Limit Lens")
            .accessibilityValue("\(accessibilitySummary(for: codex)); \(accessibilitySummary(for: claude))")
    }

    private var renderedImage: NSImage {
        let renderer = ImageRenderer(content: composite)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: 92, height: 18))
        image.isTemplate = false
        return image
    }

    private var composite: some View {
        HStack(spacing: 6) {
            ProviderMenuMeter(
                label: "Cx",
                snapshot: codex,
                textColor: monoColor
            )

            ProviderMenuMeter(
                label: "Cl",
                snapshot: claude,
                textColor: monoColor
            )
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
        .fixedSize()
    }

    private var monoColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private func accessibilitySummary(for snapshot: ProviderSnapshot) -> String {
        "\(snapshot.provider.rawValue) \(snapshot.state.label), \(snapshot.headline)"
    }
}

private struct ProviderMenuMeter: View {
    private static let meterWidth: Double = 30
    private static let meterHeight: Double = 7

    var label: String
    var snapshot: ProviderSnapshot
    var textColor: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold).monospaced())
                .foregroundStyle(textColor)
                .frame(width: 12, alignment: .trailing)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(textColor.opacity(snapshot.state.isUsable ? 0.18 : 0.10))
                    .frame(width: Self.meterWidth, height: Self.meterHeight)

                Capsule()
                    .fill(fillColor)
                    .frame(width: fillWidth, height: Self.meterHeight)
            }
            .overlay {
                Capsule()
                    .strokeBorder(textColor.opacity(snapshot.state.isUsable ? 0.22 : 0.16), lineWidth: 0.75)
            }

            Text(percentText)
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(snapshot.state.isUsable ? textColor : textColor.opacity(0.45))
                .frame(width: 22, alignment: .leading)
        }
        .frame(height: 14)
    }

    private var fillFraction: Double {
        guard let usedPercent else {
            return 0
        }

        return max(0, min(1, usedPercent / 100))
    }

    private var fillWidth: Double {
        guard let usedPercent else {
            return 0
        }

        let rawWidth = Self.meterWidth * fillFraction
        return usedPercent > 0 ? max(2.5, rawWidth) : 0
    }

    private var percentText: String {
        guard let usedPercent else {
            return "--"
        }

        return "\(Int(usedPercent.rounded()))"
    }

    private var usedPercent: Double? {
        let windows = snapshot.buckets.flatMap(\.windows)
        let preferredWindow = windows.first { window in
            window.label.localizedCaseInsensitiveContains("Weekly all-model")
                || window.label.localizedCaseInsensitiveContains("5-hour")
                || window.durationMinutes == 300
        }

        return preferredWindow?.usedPercent ?? windows.first(where: { $0.usedPercent != nil })?.usedPercent
    }

    private var fillColor: Color {
        guard snapshot.state.isUsable else {
            return textColor.opacity(0.26)
        }

        guard let usedPercent else {
            return textColor.opacity(0.26)
        }

        return LimitTheme.usageColor(for: usedPercent)
    }
}
