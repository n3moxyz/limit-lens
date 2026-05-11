import Foundation

enum LimitFormatters {
    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static let compactNumber: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    static let exactResetTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a zzz"
        return formatter
    }()

    static func percentString(_ value: Double?) -> String {
        guard let value else { return "Unknown" }
        return "\(Int(value.rounded()))%"
    }

    static func number(_ value: Int) -> String {
        compactNumber.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func resetText(_ date: Date?) -> String {
        guard let date else { return "Reset unknown" }

        if date.timeIntervalSinceNow <= 0 {
            return "Reset now"
        }

        return "Resets \(relative.localizedString(for: date, relativeTo: Date()))"
    }

    static func exactResetText(_ date: Date?, windowLabel: String, durationMinutes: Int?) -> String {
        guard let date else { return "\(windowLabel) reset unknown" }
        let resetDate = nextResetDate(from: date, durationMinutes: durationMinutes)
        return "\(windowLabel) resets \(exactResetTime.string(from: resetDate))"
    }

    private static func nextResetDate(from date: Date, durationMinutes: Int?) -> Date {
        guard let durationMinutes, durationMinutes > 0 else {
            return date
        }

        var resetDate = date
        let interval = TimeInterval(durationMinutes * 60)
        let now = Date()

        while resetDate.timeIntervalSince(now) <= 0 {
            resetDate = resetDate.addingTimeInterval(interval)
        }

        return resetDate
    }

    static func updatedText(_ date: Date?) -> String {
        guard let date else { return "Never refreshed" }
        return "Updated \(relative.localizedString(for: date, relativeTo: Date()))"
    }

    static func windowLabel(minutes: Int?) -> String {
        guard let minutes else { return "Window" }

        switch minutes {
        case 300:
            return "5-hour"
        case 1_440:
            return "Daily"
        case 10_080:
            return "Weekly"
        case let value where value < 60:
            return "\(value)m"
        case let value where value % 60 == 0:
            return "\(value / 60)h"
        default:
            return "\(minutes)m"
        }
    }
}
