import Configuration
import Core
import Foundation

public struct MappingValidator {
  public init() {}

  public func validate(_ profile: Profile) -> ValidationResult {
    var errors: [String] = []
    var warnings: [String] = []

    for mapping in profile.buttonMappings {
      if mapping.buttonIdentifier.isEmpty {
        errors.append("Empty button identifier found")
      }

      if let validationError = _validateMapping(mapping) {
        errors.append(validationError)
      }
    }

    return ValidationResult(errors: errors, warnings: warnings)
  }

  public func validateButtonIdentifier(_ identifier: String) -> Bool {
    !identifier.isEmpty && identifier.count <= 100
  }

  public func validateMacro(_ macro: MappingEngine.MacroDefinition) -> Bool {
    !macro.name.isEmpty && !macro.actions.isEmpty
  }

  private func _validateMapping(_ mapping: ButtonMapping) -> String? {
    if mapping.buttonIdentifier.contains(" ") && !mapping.buttonIdentifier.contains("+") {
      return "Button identifier '\(mapping.buttonIdentifier)' contains spaces"
    }
    return nil
  }
}

extension MappingValidator {
  public struct ValidationResult: Sendable {
    public let errors: [String]
    public let warnings: [String]

    public var isValid: Bool {
      errors.isEmpty
    }

    public var hasIssues: Bool {
      !errors.isEmpty || !warnings.isEmpty
    }
  }
}
