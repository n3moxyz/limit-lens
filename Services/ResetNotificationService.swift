import Foundation
import UserNotifications

final class ResetNotificationService: NSObject, UNUserNotificationCenterDelegate {
    private static let resetPrefix = "limit-lens-reset-"
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func syncResetNotifications(codex: ProviderSnapshot, claude: ProviderSnapshot, enabled: Bool) async {
        guard enabled else {
            await cancelResetNotifications()
            return
        }

        guard await ensureAuthorization() else { return }

        let events = resetEvents(from: [codex, claude])
        let pendingIDs = await pendingResetNotificationIDs()
        let eventIDs = Set(events.map(\.id))
        let staleIDs = pendingIDs.filter { !eventIDs.contains($0) }
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)
        }

        for event in events {
            guard !pendingIDs.contains(event.id) else { continue }

            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.body
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: event.date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: event.id, content: content, trigger: trigger)
            try? await add(request)
        }
    }

    func cancelResetNotifications() async {
        let ids = await pendingResetNotificationIDs()
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
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

    private func resetEvents(from snapshots: [ProviderSnapshot]) -> [ResetNotificationEvent] {
        let now = Date()

        return snapshots.flatMap { snapshot in
            snapshot.buckets.flatMap { bucket in
                bucket.windows.compactMap { window in
                    guard let resetDate = window.resetsAt,
                          resetDate.timeIntervalSince(now) > 1,
                          window.usedPercent != nil else {
                        return nil
                    }

                    let safeWindowID = window.label
                        .lowercased()
                        .replacingOccurrences(of: " ", with: "-")
                        .replacingOccurrences(of: "/", with: "-")
                    let resetID = Int(resetDate.timeIntervalSince1970)

                    return ResetNotificationEvent(
                        id: "\(Self.resetPrefix)\(snapshot.provider.rawValue.lowercased())-\(bucket.id)-\(safeWindowID)-\(resetID)",
                        title: "\(snapshot.provider.rawValue) reset is ready",
                        body: "\(window.label) usage has reset. \(snapshot.provider.rawValue) is available for the next task.",
                        date: resetDate
                    )
                }
            }
        }
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

    private func pendingResetNotificationIDs() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(
                    returning: requests
                        .map(\.identifier)
                        .filter { $0.hasPrefix(Self.resetPrefix) }
                )
            }
        }
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

private struct ResetNotificationEvent {
    var id: String
    var title: String
    var body: String
    var date: Date
}
