import AppKit
import CoreGraphics

enum InputMonitoringPermission {
  static func check() -> Bool {
    let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
    guard
      CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: { _, _, _, _ in nil },
        userInfo: nil
      ) != nil
    else {
      return false
    }
    return true
  }

  @MainActor
  static func showAlertAndExit() {
    let alert = NSAlert()
    alert.messageText = "Input Monitoring Access Required"
    alert.informativeText =
      "Enjoyable requires access to Input Monitoring to process gamepad input events. This permission is essential for the application to function.\n\nTo grant access:\n\n1. Open System Settings and navigate to Privacy & Security > Input Monitoring\n2. Click the Add button (+)\n3. Select Enjoyable from the application list\n4. Enable the toggle switch\n5. Relaunch Enjoyable"
    alert.alertStyle = .critical
    alert.addButton(withTitle: "Open System Settings")
    alert.addButton(withTitle: "Quit")

    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring"
      ) {
        NSWorkspace.shared.open(url)
      }
    }
    NSApp.terminate(nil)
  }
}
