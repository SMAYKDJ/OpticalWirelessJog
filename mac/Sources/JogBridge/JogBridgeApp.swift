import AppKit
import SwiftUI

@main
struct JogBridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = BridgeController()

    var body: some Scene {
        WindowGroup("Optical Wireless Jog") {
            DiagnosticsView()
                .environmentObject(controller)
                .frame(minWidth: 940, minHeight: 680)
        }
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Necessário quando executado via `swift run` (sem bundle .app).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
