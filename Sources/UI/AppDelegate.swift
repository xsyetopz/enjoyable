import AppKit
import SwiftUI

@main
struct EnjoyableApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var engine: ControllerEngine?
  private var eventMapper: EventMapper?
  private var eventSynthesizer: EventSynthesizer?
  private var statusItem: NSStatusItem?
  private var devicesMenu: NSMenu?
  private var settingsWindow: SettingsWindow?
  private var accessibilityErrorLogged: Bool = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    setupStatusItem()
    setupAccessibilityMenuItem()
    setupPassthroughModeObserver()

    checkAccessibilityPermissions()

    let eventSynthesizer = EventSynthesizer()
    let eventMapper = EventMapper()
    let engine = ControllerEngine()

    self.eventSynthesizer = eventSynthesizer
    self.eventMapper = eventMapper
    self.engine = engine

    let defaultMapping = Mapping(
      id: "default",
      name: "Default Mapping",
      controllerId: "*",
      inputMappings: [:]
    )

    eventMapper.loadMapping(defaultMapping)

    engine.onInputEvent = { [weak self, weak engine] deviceId, event in
      guard let self = self, engine != nil else { return }

      Task {
        let keyEvents = eventMapper.map(event)

        for keyEvent in keyEvents {
          do {
            switch keyEvent.action {
            case .press:
              try self.eventSynthesizer?.synthesizeKeyDown(keyCode: keyEvent.keyCode)
            case .release:
              try self.eventSynthesizer?.synthesizeKeyUp(keyCode: keyEvent.keyCode)
            }
          } catch OutputError.accessibilityPermissionDenied {
            if !self.accessibilityErrorLogged {
              self.accessibilityErrorLogged = true
            }
          } catch {
            NSLog("[AppDelegate] Failed to execute action: \(error)")
          }
        }
      }
    }
    engine.onDeviceAdded = { [weak self, weak engine] device in
      guard let self = self, engine != nil else { return }
      Task { await self.updateDevicesList() }
    }
    engine.onDeviceRemoved = { [weak self, weak engine] deviceId in
      guard let self = self, engine != nil else { return }
      Task { await self.updateDevicesList() }
    }

    Task {
      do {
        try await engine.start()
        await updateDevicesList()
      } catch {
        NSLog("[AppDelegate] Failed to start engine: \(error)")
      }
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  func applicationWillTerminate(_ notification: Notification) {
    Task {
      try? await engine?.stop()
    }
  }

  private func setupStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = statusItem?.button {
      button.image = NSImage(
        systemSymbolName: Constants.SFSymbols.gameControllerFill,
        accessibilityDescription: Constants.AppMetadata.name
      )
      button.toolTip = Constants.AppMetadata.name
    }

    devicesMenu = NSMenu()

    statusItem?.menu = devicesMenu
  }

  @MainActor
  private func updateDevicesList() async {
    guard let menu = devicesMenu else { return }

    menu.removeAllItems()

    let devices = await engine?.getDevices() ?? []
    if devices.isEmpty {
      let noDevicesItem = NSMenuItem(
        title: Constants.UIStrings.Menu.noControllers,
        action: nil,
        keyEquivalent: ""
      )
      noDevicesItem.isEnabled = false
      menu.addItem(noDevicesItem)
    } else {
      for device in devices {
        let vidString = String(format: Constants.FormatStrings.hexFourDigits, device.info.vendorId)
        let pidString = String(format: Constants.FormatStrings.hexFourDigits, device.info.productId)
        let item = NSMenuItem(
          title: "\(device.info.name) (\(vidString):\(pidString))",
          action: nil,
          keyEquivalent: ""
        )
        item.image = NSImage(
          systemSymbolName: Constants.SFSymbols.gameController,
          accessibilityDescription: nil
        )
        menu.addItem(item)
      }
    }

    menu.addItem(NSMenuItem.separator())

    let settingsItem = NSMenuItem(
      title: Constants.UIStrings.Menu.settings,
      action: #selector(openSettings),
      keyEquivalent: ","
    )
    settingsItem.target = self
    menu.addItem(settingsItem)

    menu.addItem(NSMenuItem.separator())

    let quitItem = NSMenuItem(
      title: Constants.UIStrings.Menu.quit,
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    quitItem.target = NSApplication.shared
    menu.addItem(quitItem)
  }

  private func setupPassthroughModeObserver() {
    let passthroughMode = UserDefaults.standard.bool(
      forKey: Constants.UserDefaultsKeys.passthroughMode
    )
    engine?.passthroughMode = passthroughMode

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(passthroughModeChanged(_:)),
      name: Notification.Name(Constants.NotificationNames.passthroughModeChanged),
      object: nil
    )
  }

  @objc private func passthroughModeChanged(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
      let enabled = userInfo["enabled"] as? Bool
    else {
      return
    }

    engine?.passthroughMode = enabled
  }

  @objc private func openSettings() {
    if settingsWindow == nil {
      settingsWindow = SettingsWindow()
    }
    settingsWindow?.show()
  }

  private func setupAccessibilityMenuItem() {
    let accessibilityItem = NSMenuItem(
      title: Constants.UIStrings.Menu.openAccessibilitySettings,
      action: #selector(openAccessibilitySettings),
      keyEquivalent: ""
    )

    guard let menu = devicesMenu else { return }

    let hasSeparator = menu.items.contains { $0.isSeparatorItem }

    if !hasSeparator {
      menu.addItem(NSMenuItem.separator())
    }

    menu.insertItem(accessibilityItem, at: 0)
  }

  @objc private func openAccessibilitySettings() {
    guard let url = URL(string: Constants.URLSchemes.accessibilitySettings) else { return }
    NSWorkspace.shared.open(url)
  }

  private func checkAccessibilityPermissions() {
    let trusted = AXIsProcessTrusted()

    if !trusted {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText =
          "Enjoyable needs Accessibility permissions to send keyboard and mouse events to other applications like PCSX2.\\n\\nPlease grant permissions in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
          self.openAccessibilitySettings()
        }
      }
    }
  }
}

extension EventSynthesizer {
  func performAction(_ action: OutputAction) async throws {
    switch action.type {
    case .keyPress:
      guard let keyCode = action.keyCode else { return }
      let flags = action.keyFlags ?? 0
      try synthesizeKeyPress(keyCode: keyCode, flags: flags)
      try synthesizeKeyRelease(keyCode: keyCode)

    case .mouseMove:
      guard let x = action.mouseX, let y = action.mouseY else { return }
      try synthesizeMouseMove(x: x, y: y)

    case .mouseButton:
      guard let button = action.mouseButton,
        let state = action.mouseButtonState
      else {
        return
      }
      try synthesizeMouseButton(button: button, state: state)

    case .mouseScroll:
      guard let deltaX = action.scrollDeltaX,
        let deltaY = action.scrollDeltaY
      else {
        return
      }
      try synthesizeMouseScroll(deltaX: deltaX, deltaY: deltaY)
    }
  }
}
