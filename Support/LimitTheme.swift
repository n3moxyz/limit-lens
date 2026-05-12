import SwiftUI

enum LimitTheme {
    static let usageNominalColor = Color(red: 0.66, green: 0.48, blue: 1.0)
    static let usageWarningColor = Color.orange
    static let usageCriticalColor = Color.red

    static func usageColor(for percent: Double) -> Color {
        switch percent {
        case 85...:
            return usageCriticalColor
        case 65..<85:
            return usageWarningColor
        default:
            return usageNominalColor
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
