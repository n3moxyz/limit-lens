import AppKit
import SwiftUI

@main
struct LimitLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: LimitStore

    init() {
        let store = LimitStore()
        store.start()
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        Window("Limit Lens", id: "main") {
            ContentView()
                .environmentObject(store)
                .task { store.start() }
                .frame(minWidth: 680, minHeight: 480)
        }
        .defaultSize(width: 760, height: 560)

        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(store)
                .frame(width: 340)
                .task { store.start() }
                .onAppear { store.setPollingActive(true) }
                .onDisappear { store.setPollingActive(false) }
        } label: {
            MenuBarMeterLabel(codex: store.codex, claude: store.claude)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }

        NSApp.setActivationPolicy(.accessory)
    }
}
