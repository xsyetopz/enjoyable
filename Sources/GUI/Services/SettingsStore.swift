import Combine
import SwiftUI

final class SettingsStore: ObservableObject {
  @Published var appearanceMode: AppearanceMode = .system
  @Published var showNotifications: Bool = true
  @Published var minimizeToTray: Bool = true

  private let _userDefaults: UserDefaults
  private let _appearanceModeKey = "appearanceMode"
  private let _showNotificationsKey = "showNotifications"
  private let _minimizeToTrayKey = "minimizeToTray"

  init(userDefaults: UserDefaults = .standard) {
    self._userDefaults = userDefaults
    loadSettings()
  }

  func loadSettings() {
    appearanceMode =
      AppearanceMode(rawValue: _userDefaults.string(forKey: _appearanceModeKey) ?? "System")
      ?? .system
    showNotifications = _userDefaults.bool(forKey: _showNotificationsKey)
    minimizeToTray = _userDefaults.bool(forKey: _minimizeToTrayKey)
  }

  func saveSettings() {
    _userDefaults.set(appearanceMode.rawValue, forKey: _appearanceModeKey)
    _userDefaults.set(showNotifications, forKey: _showNotificationsKey)
    _userDefaults.set(minimizeToTray, forKey: _minimizeToTrayKey)
  }

  func updateAppearanceMode(_ mode: AppearanceMode) {
    appearanceMode = mode
    saveSettings()
  }

  func updateShowNotifications(_ enabled: Bool) {
    showNotifications = enabled
    saveSettings()
  }

  func updateMinimizeToTray(_ enabled: Bool) {
    minimizeToTray = enabled
    saveSettings()
  }
}
