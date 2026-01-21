import AppKit
import ServiceManagement
import SwiftUI

final class SettingsWindow: NSWindow, ObservableObject {
  @Published var showConnectionNotifications: Bool = false
  @Published var passthroughMode: Bool = false {
    didSet {
      UserDefaults.standard.set(passthroughMode, forKey: Constants.UserDefaultsKeys.passthroughMode)
      NotificationCenter.default.post(
        name: .passthroughModeChanged,
        object: nil,
        userInfo: ["enabled": passthroughMode]
      )
    }
  }

  init() {
    super.init(
      contentRect: NSRect(
        x: 0,
        y: 0,
        width: Constants.WindowDimensions.settingsWidth,
        height: Constants.WindowDimensions.settingsHeight
      ),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )

    self.title = Constants.UIStrings.WindowTitles.settings
    self.isReleasedWhenClosed = false
    self.center()

    showConnectionNotifications = UserDefaults.standard.bool(
      forKey: Constants.UserDefaultsKeys.showConnectionNotifications
    )
    passthroughMode = UserDefaults.standard.bool(
      forKey: Constants.UserDefaultsKeys.passthroughMode
    )

    let settingsView = SettingsView()
      .environmentObject(self)

    let hostingController = NSHostingController(rootView: settingsView)
    self.contentViewController = hostingController
  }

  private func updateLoginItem(enabled: Bool) {
    if #available(macOS 13.0, *) {
      do {
        if enabled {
          try SMAppService.mainApp.register()
        } else {
          try SMAppService.mainApp.unregister()
        }
      } catch {
        NSLog("[SettingsWindow] Failed to update login item: \(error)")
      }
    }
  }

  func show() {
    makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}

extension Notification.Name {
  static let passthroughModeChanged = Notification.Name(
    Constants.NotificationNames.passthroughModeChanged
  )
}
