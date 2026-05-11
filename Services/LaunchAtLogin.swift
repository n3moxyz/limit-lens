import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var lastError: String?

    init() {
        refreshFromSystem()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        refreshFromSystem()
    }

    private func refreshFromSystem() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
