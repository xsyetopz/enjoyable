import Configuration
import Core
import Foundation

public struct ProfileValidator {
  public init() {}

  public func validate(_ profile: Profile) throws {
    try _validateName(profile.name)
    try _validateMappings(profile.buttonMappings)
  }

  private func _validateName(_ name: String) throws {
    guard !name.isEmpty else {
      throw ValidationError.emptyName
    }

    guard name.count <= 100 else {
      throw ValidationError.nameTooLong
    }

    let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>")
    if name.unicodeScalars.contains(where: { invalidCharacters.contains($0) }) {
      throw ValidationError.invalidCharacters
    }
  }

  private func _validateMappings(_ mappings: [ButtonMapping]) throws {
    let identifiers = Set(mappings.map { $0.buttonIdentifier })

    guard mappings.count == identifiers.count else {
      throw ValidationError.duplicateMappings
    }

    for mapping in mappings {
      try _validateMapping(mapping)
    }
  }

  private func _validateMapping(_ mapping: ButtonMapping) throws {
    guard !mapping.buttonIdentifier.isEmpty else {
      throw ValidationError.emptyMappingIdentifier
    }

    guard mapping.keyCode != Constants.KeyCode.unmapped || mapping.modifier != .none else {
      throw ValidationError.invalidMapping
    }
  }
}

extension ProfileValidator {
  public enum ValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case invalidCharacters
    case duplicateMappings
    case emptyMappingIdentifier
    case invalidMapping

    public var errorDescription: String? {
      switch self {
      case .emptyName:
        return "Profile name cannot be empty"
      case .nameTooLong:
        return "Profile name exceeds maximum length of 100 characters"
      case .invalidCharacters:
        return "Profile name contains invalid characters"
      case .duplicateMappings:
        return "Profile contains duplicate button mappings"
      case .emptyMappingIdentifier:
        return "Button mapping has empty identifier"
      case .invalidMapping:
        return "Button mapping has no valid key code or modifier"
      }
    }
  }
}
