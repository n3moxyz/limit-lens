import SwiftUI

enum LimitTheme {
    static let usageNominalColor = Color.green
    static let usageWarningColor = Color(red: 0.92, green: 0.18, blue: 0.16)
    static let usageCriticalColor = Color(red: 0.68, green: 0.04, blue: 0.05)
    static let usageMaxedColor = Color(red: 0.38, green: 0.0, blue: 0.02)

    static func usageColor(for percent: Double) -> Color {
        switch usageTone(for: percent) {
        case .nominal:
            return usageNominalColor
        case .warning:
            return usageWarningColor
        case .critical:
            return usageCriticalColor
        case .maxed:
            return usageMaxedColor
        }
    }

    static func menuBarUsageColor(for percent: Double) -> Color {
        usageColor(for: percent)
    }

    static func usageTone(for percent: Double) -> UsageTone {
        switch percent {
        case 100...:
            return .maxed
        case 95..<100:
            return .critical
        case 85..<95:
            return .warning
        default:
            return .nominal
        }
    }

    static var unavailableUsageColor: Color {
        .secondary
    }

    static func stateColor(for state: SnapshotState) -> Color {
        switch state {
        case .loading:
            return .secondary
        case .ready:
            return .green
        case .stale:
            return .orange
        case .unavailable:
            return .orange
        case .failed:
            return .red
        }
    }

    static func setupColor(isReady: Bool) -> Color {
        isReady ? .secondary : .orange
    }

    static func suggestedRouteColor(named name: String) -> Color {
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

enum UsageTone: Equatable {
    case nominal
    case warning
    case critical
    case maxed
}
