import AppKit
import SwiftUI

struct MenuBarMeterLabel: View {
    var codex: ProviderSnapshot
    var claude: ProviderSnapshot

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(nsImage: renderedImage)
            .accessibilityLabel("Limit Lens")
            .accessibilityValue("\(MenuBarMeterPresentation.accessibilitySummary(for: codex)); \(MenuBarMeterPresentation.accessibilitySummary(for: claude))")
            .accessibilityHint("Shows consumed Codex and Claude limit percentages")
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
        MenuBarMeterPresentation.usedPercent(for: snapshot)
    }

    private var fillColor: Color {
        guard snapshot.state.isUsable, let usedPercent else {
            return textColor.opacity(0.26)
        }

        return LimitTheme.menuBarUsageColor(for: usedPercent)
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

enum MenuBarMeterPresentation {
    static func usedPercent(for snapshot: ProviderSnapshot) -> Double? {
        let windows = snapshot.buckets.flatMap(\.windows)
        let preferredWindow = preferredWindow(in: windows)

        return preferredWindow?.usedPercent ?? windows.first(where: { $0.usedPercent != nil })?.usedPercent
    }

    static func accessibilitySummary(for snapshot: ProviderSnapshot) -> String {
        let windows = snapshot.buckets.flatMap(\.windows)
        guard let window = preferredWindow(in: windows) ?? windows.first(where: { $0.usedPercent != nil }) else {
            return "\(snapshot.provider.rawValue) \(snapshot.state.label), \(snapshot.headline)"
        }

        let usage = window.usedPercent.map { "\(LimitFormatters.percentString($0)) used" } ?? "usage not reported"
        return "\(snapshot.provider.rawValue) \(snapshot.state.label), \(accessibilityLabel(for: window)) \(usage)"
    }

    private static func preferredWindow(in windows: [LimitWindow]) -> LimitWindow? {
        windows.first { window in
            window.label.localizedCaseInsensitiveContains("Weekly")
                || window.durationMinutes == 10_080
        } ?? windows.first { window in
            window.label.localizedCaseInsensitiveContains("5-hour")
                || window.durationMinutes == 300
        }
    }

    private static func accessibilityLabel(for window: LimitWindow) -> String {
        if window.label.localizedCaseInsensitiveContains("all-model") {
            return "weekly all-model"
        }

        if window.label.localizedCaseInsensitiveContains("Weekly") || window.durationMinutes == 10_080 {
            return "weekly"
        }

        if window.label.localizedCaseInsensitiveContains("5-hour") || window.durationMinutes == 300 {
            return "5-hour"
        }

        return window.label
    }
}
