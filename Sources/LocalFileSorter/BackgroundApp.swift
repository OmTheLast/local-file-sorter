import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--background") {
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
                for window in NSApp.windows { window.orderOut(nil) }
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.regular)
        for window in NSApp.windows where window.canBecomeKey { window.makeKeyAndOrderFront(nil) }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}
struct SorterMenu: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text(model.automation ? "Sorting new downloads automatically" : "Automatic sorting paused")
        Button("Open File Sorter") {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button(model.automation ? "Pause sorting" : "Resume sorting") {
            if model.automation { model.pause() } else { model.enableAutomation() }
        }.disabled(!model.automation && model.busy)
        Button("Open Sorted Files") { model.reveal(model.settings.destination) }
        Divider()
        Button("Quit File Sorter") { NSApp.terminate(nil) }
    }
}
