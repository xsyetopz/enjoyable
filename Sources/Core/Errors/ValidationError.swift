import Foundation

public enum ValidationError: Error, LocalizedError, Sendable {
  case invalidConfigurationValue(key: String, value: String, reason: String)
  case outOfRange(key: String, value: Double, min: Double, max: Double)
  case invalidFormat(key: String, value: String, expectedFormat: String)
  case missingRequiredField(key: String)
  case tooManyItems(key: String, count: Int, maxAllowed: Int)
  case duplicateItem(key: String, value: String)

  public var title: String {
    switch self {
    case .invalidConfigurationValue: return "Invalid Configuration Value"
    case .outOfRange: return "Value Out of Range"
    case .invalidFormat: return "Invalid Format"
    case .missingRequiredField: return "Missing Required Field"
    case .tooManyItems: return "Too Many Items"
    case .duplicateItem: return "Duplicate Item"
    }
  }

  public var message: String {
    switch self {
    case .invalidConfigurationValue(let key, let value, let reason):
      return "Invalid value '\(value)' for configuration key '\(key)': \(reason)."
    case .outOfRange(let key, let value, let min, let max):
      return "Value \(value) for key '\(key)' is out of range. Must be between \(min) and \(max)."
    case .invalidFormat(let key, let value, let expectedFormat):
      return "Value '\(value)' for key '\(key)' does not match expected format: \(expectedFormat)."
    case .missingRequiredField(let key):
      return "Required configuration field '\(key)' is missing."
    case .tooManyItems(let key, let count, let maxAllowed):
      return "Too many items for key '\(key)'. Found \(count), maximum allowed is \(maxAllowed)."
    case .duplicateItem(let key, let value):
      return "Duplicate value '\(value)' for key '\(key)'."
    }
  }

  public var recoverySuggestion: String {
    switch self {
    case .invalidConfigurationValue, .outOfRange, .invalidFormat:
      return
        "Check the configuration value and ensure it matches the expected format. Refer to the documentation for valid values. Reset to default if unsure."
    case .missingRequiredField:
      return
        "Add the missing required field to the configuration. Check the documentation for required fields."
    case .tooManyItems:
      return
        "Reduce the number of items to be within the allowed limit. Remove or consolidate items."
    case .duplicateItem:
      return "Remove the duplicate item or use a unique value."
    }
  }

  public var errorDescription: String? {
    "\(title): \(message)"
  }

  public var primaryAction: String {
    switch self {
    case .invalidConfigurationValue, .outOfRange, .invalidFormat, .missingRequiredField:
      return "Edit Configuration"
    case .tooManyItems, .duplicateItem:
      return "Remove Duplicates"
    }
  }

  public var isRetryable: Bool {
    true
  }
}
