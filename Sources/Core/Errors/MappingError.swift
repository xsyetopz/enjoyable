import Foundation

public enum MappingError: Error, LocalizedError, Sendable {
  case engineError(underlyingError: String)
  case invalidMapping(buttonIdentifier: String, reason: String)
  case duplicateMapping(buttonIdentifier: String)
  case orphanedMapping(buttonIdentifier: String)
  case circularDependency(mappingID: String)
  case invalidTarget(mappingID: String, target: String)

  public var title: String {
    switch self {
    case .engineError: return "Mapping Engine Error"
    case .invalidMapping: return "Invalid Mapping"
    case .duplicateMapping: return "Duplicate Mapping"
    case .orphanedMapping: return "Orphaned Mapping"
    case .circularDependency: return "Circular Dependency"
    case .invalidTarget: return "Invalid Target"
    }
  }

  public var message: String {
    switch self {
    case .engineError(let underlyingError):
      return "Mapping engine encountered an error: \(underlyingError)."
    case .invalidMapping(let buttonIdentifier, let reason):
      return "Invalid mapping for button '\(buttonIdentifier)': \(reason)."
    case .duplicateMapping(let buttonIdentifier):
      return
        "Duplicate mapping for button '\(buttonIdentifier)'. Only one mapping per button is allowed."
    case .orphanedMapping(let buttonIdentifier):
      return "Mapping for button '\(buttonIdentifier)' has no corresponding button on the device."
    case .circularDependency(let mappingID):
      return "Circular dependency detected in mapping '\(mappingID)'."
    case .invalidTarget(let mappingID, let target):
      return "Mapping '\(mappingID)' has an invalid target: '\(target)'."
    }
  }

  public var recoverySuggestion: String {
    switch self {
    case .engineError:
      return
        "1. Review your mapping configuration for invalid entries\n2. Try resetting to default mappings\n3. Restart Enjoyable\n4. Check the mapping file for syntax errors"
    case .invalidMapping, .duplicateMapping, .orphanedMapping, .invalidTarget:
      return
        "1. Review the mapping configuration\n2. Remove or fix the invalid mapping\n3. Try resetting to default mappings"
    case .circularDependency:
      return
        "1. Review the mapping chain\n2. Remove the circular reference\n3. Try resetting to default mappings"
    }
  }

  public var errorDescription: String? {
    "\(title): \(message)"
  }

  public var primaryAction: String {
    switch self {
    case .engineError: return "Reset Mappings"
    case .invalidMapping, .duplicateMapping, .orphanedMapping, .invalidTarget:
      return "Edit Mappings"
    case .circularDependency: return "Fix Dependencies"
    }
  }

  public var isRetryable: Bool {
    true
  }
}
