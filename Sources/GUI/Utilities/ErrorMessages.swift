import Foundation

enum ErrorMessages {
  enum USB {
    static let permissionDenied = "USB access denied. Please grant permission in System Settings."
    static let accessDenied = "USB access denied. Please check device permissions."
    static let deviceDisconnected = "Device was disconnected."
  }

  static func usbInitializationFailed(_ error: String) -> String {
    "Failed to initialize USB: \(error)"
  }

  static func usbServiceInitializationFailed(_ error: String) -> String {
    "Failed to initialize USB service: \(error)"
  }

  static func usbAccessError(for deviceName: String) -> String {
    "USB access error for \(deviceName)"
  }

  static func usbError(_ error: String) -> String {
    "USB error: \(error)"
  }

  static func communicationError(for deviceName: String) -> String {
    "Communication error with \(deviceName)"
  }

  static func initializationFailed(deviceName: String, reason: String) -> String {
    "Failed to initialize \(deviceName): \(reason)"
  }

  static func deviceError(_ error: String) -> String {
    "Device error: \(error)"
  }

  static func refreshFailed(_ error: String) -> String {
    "Failed to refresh devices: \(error)"
  }

  static func loadProfilesFailed(_ error: String) -> String {
    "Failed to load profiles: \(error)"
  }

  static func saveProfileFailed(_ error: String) -> String {
    "Failed to save profile: \(error)"
  }

  static func deleteProfileFailed(_ error: String) -> String {
    "Failed to delete profile: \(error)"
  }

  static func duplicateProfileFailed(_ error: String) -> String {
    "Failed to duplicate profile: \(error)"
  }
}
