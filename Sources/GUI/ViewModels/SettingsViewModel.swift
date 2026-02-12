import Combine
import Services
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
  @Published var appearanceMode: AppearanceMode = .system
  @Published var startAtLogin: Bool = false
  @Published var showNotifications: Bool = true
  @Published var minimizeToTray: Bool = true
  @Published var deviceRefreshRate: Double = 0.1
  @Published var autoConnect: Bool = true
  @Published var showDebugInfo: Bool = false

  private let _defaults = UserDefaults.standard
  private let _appearanceModeKey = "appearanceMode"
  private let _showNotificationsKey = "showNotifications"
  private let _minimizeToTrayKey = "minimizeToTray"
  private let _deviceRefreshRateKey = "deviceRefreshRate"
  private let _autoConnectKey = "autoConnect"
  private let _showDebugInfoKey = "showDebugInfo"

  init() {
    loadSettings()
  }

  func loadSettings() {
    appearanceMode =
      AppearanceMode(rawValue: _defaults.string(forKey: _appearanceModeKey) ?? "system") ?? .system
    showNotifications = _defaults.bool(forKey: _showNotificationsKey)
    minimizeToTray = _defaults.bool(forKey: _minimizeToTrayKey)
    deviceRefreshRate = _defaults.double(forKey: _deviceRefreshRateKey)
    autoConnect = _defaults.bool(forKey: _autoConnectKey)
    showDebugInfo = _defaults.bool(forKey: _showDebugInfoKey)

    if deviceRefreshRate == 0 {
      deviceRefreshRate = 0.1
    }

    _updateStartAtLoginStatus()
  }

  func saveSettings() {
    _defaults.set(appearanceMode.rawValue, forKey: _appearanceModeKey)
    _defaults.set(showNotifications, forKey: _showNotificationsKey)
    _defaults.set(minimizeToTray, forKey: _minimizeToTrayKey)
    _defaults.set(deviceRefreshRate, forKey: _deviceRefreshRateKey)
    _defaults.set(autoConnect, forKey: _autoConnectKey)
    _defaults.set(showDebugInfo, forKey: _showDebugInfoKey)
  }

  func setAppearanceMode(_ mode: AppearanceMode) {
    appearanceMode = mode
    saveSettings()
  }

  func setStartAtLogin(_ enabled: Bool) {
    startAtLogin = enabled
    if let bundleID = Bundle.main.bundleIdentifier {
      Task {
        do {
          if enabled {
            try await LoginItemsService(bundleIdentifier: bundleID).enableStartAtLogin()
          } else {
            try await LoginItemsService(bundleIdentifier: bundleID).disableStartAtLogin()
          }
        } catch {
          print("Failed to update login item: \(error)")
        }
      }
    }
    saveSettings()
  }

  private func _updateStartAtLoginStatus() {
    if let bundleID = Bundle.main.bundleIdentifier {
      Task {
        startAtLogin = await LoginItemsService(bundleIdentifier: bundleID).isStartAtLoginEnabled
      }
    }
  }

  func setShowNotifications(_ enabled: Bool) {
    showNotifications = enabled
    saveSettings()
  }

  func setMinimizeToTray(_ enabled: Bool) {
    minimizeToTray = enabled
    saveSettings()
  }

  func setDeviceRefreshRate(_ rate: Double) {
    deviceRefreshRate = rate
    saveSettings()
  }

  func setAutoConnect(_ enabled: Bool) {
    autoConnect = enabled
    saveSettings()
  }

  func setShowDebugInfo(_ enabled: Bool) {
    showDebugInfo = enabled
    saveSettings()
  }

  func resetToDefaults() {
    appearanceMode = .system
    showNotifications = true
    minimizeToTray = true
    deviceRefreshRate = 0.1
    autoConnect = true
    showDebugInfo = false
    saveSettings()
  }

  var refreshRateOptions: [Double] {
    [0.05, 0.1, 0.25, 0.5, 1.0]
  }

  func formattedRefreshRate(_ rate: Double) -> String {
    if rate >= 1.0 {
      return "\(Int(rate))s"
    }
    return "\(Int(rate * 1000))ms"
  }
}
