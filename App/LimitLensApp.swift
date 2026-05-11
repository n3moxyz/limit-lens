import AppKit
import SwiftUI

@main
struct LimitLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = LimitStore()

    var body: some Scene {
        WindowGroup("Limit Lens", id: "main") {
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
        } label: {
            Label(store.menuBarTitle, systemImage: "speedometer")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
