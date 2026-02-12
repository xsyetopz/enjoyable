import Foundation

public enum ProfileError: Error, LocalizedError, Sendable {
  case loadFailed(profileName: String, underlyingError: String)
  case saveFailed(profileName: String, underlyingError: String)
  case deleteFailed(profileName: String, underlyingError: String)
  case duplicateFailed(profileName: String, underlyingError: String)
  case invalidFormat(profileName: String)
  case versionMismatch(profileName: String, expected: Int, found: Int)

  public var title: String {
    switch self {
    case .loadFailed: return "Failed to Load Profile"
    case .saveFailed: return "Failed to Save Profile"
    case .deleteFailed: return "Failed to Delete Profile"
    case .duplicateFailed: return "Failed to Duplicate Profile"
    case .invalidFormat: return "Invalid Profile Format"
    case .versionMismatch: return "Profile Version Mismatch"
    }
  }

  public var message: String {
    switch self {
    case .loadFailed(let profileName, let underlyingError):
      return "Failed to load profile '\(profileName)': \(underlyingError)."
    case .saveFailed(let profileName, let underlyingError):
      return "Failed to save profile '\(profileName)': \(underlyingError)."
    case .deleteFailed(let profileName, let underlyingError):
      return "Failed to delete profile '\(profileName)': \(underlyingError)."
    case .duplicateFailed(let profileName, let underlyingError):
      return "Failed to duplicate profile '\(profileName)': \(underlyingError)."
    case .invalidFormat(let profileName):
      return "Profile '\(profileName)' has an invalid format."
    case .versionMismatch(let profileName, let expected, let found):
      return "Profile '\(profileName)' has version \(found) but expected version \(expected)."
    }
  }

  public var recoverySuggestion: String {
    switch self {
    case .loadFailed, .invalidFormat, .versionMismatch:
      return
        "1. Verify the profile file exists and is not corrupted\n2. Check file permissions\n3. Try recreating the profile\n4. If the file was created on another system, check for compatibility issues"
    case .saveFailed:
      return
        "1. Check that you have write permissions to the profile directory\n2. Verify there is sufficient disk space\n3. Close any other applications that might have the file open\n4. Try saving with a different name"
    case .deleteFailed:
      return
        "1. Check file permissions\n2. Ensure the file is not locked by another application\n3. Try deleting from Finder"
    case .duplicateFailed:
      return
        "1. Check that the source profile exists\n2. Verify write permissions to the destination\n3. Ensure the new profile name is valid"
    }
  }

  public var errorDescription: String? {
    "\(title): \(message)"
  }

  public var primaryAction: String {
    switch self {
    case .loadFailed, .invalidFormat, .versionMismatch: return "Open Profiles"
    case .saveFailed: return "Retry Save"
    case .deleteFailed: return "Retry Delete"
    case .duplicateFailed: return "Retry Duplicate"
    }
  }

  public var isRetryable: Bool {
    switch self {
    case .invalidFormat, .versionMismatch:
      return false
    default:
      return true
    }
  }
}
