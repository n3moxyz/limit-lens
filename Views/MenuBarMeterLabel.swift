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
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: 112, height: 18))
        image.isTemplate = false
        return image
    }

    private var composite: some View {
        HStack(spacing: 7) {
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
    private static let meterWidth: Double = 40
    private static let meterHeight: Double = 11

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
                    .fill(textColor.opacity(snapshot.state.isUsable ? 0.20 : 0.10))
                    .frame(width: Self.meterWidth, height: Self.meterHeight)

                Capsule()
                    .fill(fillColor)
                    .frame(width: fillWidth, height: Self.meterHeight)

                Text(percentText)
                    .font(.system(size: 8, weight: .semibold).monospacedDigit())
                    .foregroundStyle(snapshot.state.isUsable ? textColor : textColor.opacity(0.45))
                    .frame(width: Self.meterWidth, alignment: .center)
            }
            .overlay {
                Capsule()
                    .strokeBorder(textColor.opacity(snapshot.state.isUsable ? 0.22 : 0.16), lineWidth: 0.75)
            }
        }
        .frame(height: 15)
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

        return MenuBarMeterSizing.fillWidth(for: usedPercent, meterWidth: Self.meterWidth)
    }

    private var percentText: String {
        guard let usedPercent else {
            return "--"
        }

        return "\(Int(usedPercent.rounded()))%"
    }

    private var usedPercent: Double? {
        let windows = snapshot.buckets.flatMap(\.windows)
        let preferredWindow = windows.first { window in
            window.label.localizedCaseInsensitiveContains("Weekly")
                || window.durationMinutes == 10_080
        } ?? windows.first { window in
            window.label.localizedCaseInsensitiveContains("5-hour")
                || window.durationMinutes == 300
        }

        return preferredWindow?.usedPercent ?? windows.first(where: { $0.usedPercent != nil })?.usedPercent
    }

    private var fillColor: Color {
        guard snapshot.state.isUsable, let usedPercent else {
            return textColor.opacity(0.26)
        }

        switch usedPercent {
        case 85...:
            return .red
        case 65..<85:
            return .orange
        default:
            return Color(red: 0.08, green: 0.48, blue: 1.0)
        }
    }
}

enum MenuBarMeterSizing {
    static func fillWidth(for usedPercent: Double, meterWidth: Double) -> Double {
        let fillFraction = max(0, min(1, usedPercent / 100))
        let rawWidth = meterWidth * fillFraction

        guard usedPercent > 0 else {
            return 0
        }

        return usedPercent < 5 ? max(1, rawWidth) : rawWidth
    }
}
