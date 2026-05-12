import Foundation
import UserNotifications

final class ResetNotificationService: NSObject, UNUserNotificationCenterDelegate {
    private static let usagePrefix = "limit-lens-usage-"
    private static let resetWarningPrefix = "limit-lens-reset-warning-"
    private static let legacyResetPrefix = "limit-lens-reset-"
    private static let scheduledNotificationIDsDefaultsKey = "LimitLensScheduledNotificationIDs"
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func syncNotifications(
        codex: ProviderSnapshot,
        claude: ProviderSnapshot,
        preferences: LimitNotificationPreferences
    ) async {
        let preferences = preferences.normalized()
        guard preferences.isEnabled else {
            await cancelResetNotifications()
            return
        }

        guard await ensureAuthorization() else { return }

        let events = Self.notificationEvents(from: [codex, claude], preferences: preferences)
        let pendingIDs = Set(await pendingManagedNotificationIDs())
        var knownIDs = scheduledNotificationIDs().union(pendingIDs)
        let eventIDs = Set(events.map(\.id))
        let staleIDs = pendingIDs.filter { !eventIDs.contains($0) }
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(staleIDs))
        }

        for event in events {
            guard !knownIDs.contains(event.id) else { continue }

            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.body
            content.sound = .default

            let date = max(event.date, Date().addingTimeInterval(1))
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: event.id, content: content, trigger: trigger)
            if (try? await add(request)) != nil {
                knownIDs.insert(event.id)
            }
        }

        saveScheduledNotificationIDs(knownIDs.intersection(eventIDs))
    }

    func cancelResetNotifications() async {
        let ids = await pendingManagedNotificationIDs()
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
        saveScheduledNotificationIDs([])
    }

    func deliverDemoLimitPressure() async -> NotificationDeliveryResult {
        await deliverDemoEvent(
            id: "limit-lens-demo-limit-\(UUID().uuidString)",
            title: "Codex is almost limited",
            body: "Demo: Codex is at 97%. Route planning and review to Claude, and save Codex for computer-use work."
        )
    }

    func deliverDemoResetAvailable() async -> NotificationDeliveryResult {
        await deliverDemoEvent(
            id: "limit-lens-demo-reset-\(UUID().uuidString)",
            title: "Codex is available again",
            body: "Demo: the Codex 5-hour window reset. It is a good moment to spend Codex on desktop or browser control."
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    static func notificationEvents(
        from snapshots: [ProviderSnapshot],
        preferences: LimitNotificationPreferences,
        now: Date = Date()
    ) -> [LimitNotificationEvent] {
        let preferences = preferences.normalized()
        guard preferences.isEnabled else { return [] }

        return snapshots.flatMap { snapshot in
            snapshot.buckets.flatMap { bucket in
                bucket.windows.flatMap { window in
                    notificationEvents(
                        snapshot: snapshot,
                        bucket: bucket,
                        window: window,
                        preferences: preferences,
                        now: now
                    )
                }
            }
        }
    }

    private static func notificationEvents(
        snapshot: ProviderSnapshot,
        bucket: LimitBucket,
        window: LimitWindow,
        preferences: LimitNotificationPreferences,
        now: Date
    ) -> [LimitNotificationEvent] {
        var events: [LimitNotificationEvent] = []
        let providerKey = eventKey(snapshot.provider.rawValue)
        let bucketKey = eventKey(bucket.id)
        let windowKey = eventKey(window.label)
        let resetKey = window.resetsAt.map { String(Int($0.timeIntervalSince1970)) } ?? "unknown-reset"
        let resetIsCurrent = window.resetsAt.map { $0.timeIntervalSince(now) > 1 } ?? true

        if preferences.usageThresholdEnabled,
           resetIsCurrent,
           let usedPercent = window.usedPercent,
           usedPercent >= Double(preferences.usageThresholdPercent) {
            events.append(
                LimitNotificationEvent(
                    id: "\(usagePrefix)\(providerKey)-\(bucketKey)-\(windowKey)-\(resetKey)-\(preferences.usageThresholdPercent)",
                    title: "\(snapshot.provider.rawValue) usage is near limit",
                    body: "\(window.label) is at \(LimitFormatters.percentString(usedPercent)), above your \(preferences.usageThresholdPercent)% alert.",
                    date: now.addingTimeInterval(1),
                    kind: .usageThreshold
                )
            )
        }

        if preferences.resetWarningEnabled,
           preferences.includesResetWarning(for: snapshot.provider, window: window),
           let resetDate = window.resetsAt,
           resetDate.timeIntervalSince(now) > 1,
           window.usedPercent != nil {
            let resetID = Int(resetDate.timeIntervalSince1970)
            let alertDate = max(
                now.addingTimeInterval(1),
                resetDate.addingTimeInterval(-preferences.resetWarningLeadTime)
            )
            let remaining = LimitFormatters.coarseDuration(resetDate.timeIntervalSince(now))

            events.append(
                LimitNotificationEvent(
                    id: "\(resetWarningPrefix)\(providerKey)-\(bucketKey)-\(windowKey)-\(resetID)-\(preferences.resetWarningLeadHours)h",
                    title: "\(snapshot.provider.rawValue) resets soon",
                    body: "\(window.label) resets in \(remaining).",
                    date: alertDate,
                    kind: .resetWarning
                )
            )
        }

        return events
    }

    private static func eventKey(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let normalized = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return normalized.isEmpty ? "unknown" : normalized
    }

    private func deliverDemoEvent(id: String, title: String, body: String) async -> NotificationDeliveryResult {
        guard await ensureAuthorization() else {
            return .denied
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await add(request)
            return .scheduled
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func ensureAuthorization() async -> Bool {
        let settings = await notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return ((try? await requestAuthorization()) ?? false)
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: granted)
            }
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func pendingManagedNotificationIDs() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(
                    returning: requests
                        .map(\.identifier)
                        .filter(Self.isManagedNotificationID)
                )
            }
        }
    }

    private static func isManagedNotificationID(_ id: String) -> Bool {
        id.hasPrefix(usagePrefix)
            || id.hasPrefix(resetWarningPrefix)
            || id.hasPrefix(legacyResetPrefix)
    }

    private func scheduledNotificationIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.scheduledNotificationIDsDefaultsKey) ?? [])
    }

    private func saveScheduledNotificationIDs(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids).sorted(), forKey: Self.scheduledNotificationIDsDefaultsKey)
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume()
            }
        }
    }
}

enum LimitNotificationEventKind: Equatable {
    case usageThreshold
    case resetWarning
}

struct LimitNotificationEvent: Equatable {
    var id: String
    var title: String
    var body: String
    var date: Date
    var kind: LimitNotificationEventKind
}
