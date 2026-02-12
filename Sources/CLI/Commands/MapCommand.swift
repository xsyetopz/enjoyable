import ArgumentParser
import Configuration
import Core
import Foundation
import Rainbow

struct MapCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "map",
    abstract: "Interactive button mapping configuration"
  )

  @Argument(help: "The profile name to edit")
  var profileName: String

  @Option(name: .shortAndLong, help: "Button identifier to map")
  var button: String?

  @Option(name: .shortAndLong, help: "Key code (hex or decimal)")
  var key: String?

  @Option(name: .shortAndLong, help: "Modifier key (command, control, option, shift)")
  var modifier: String?

  @Flag(name: .shortAndLong, help: "Interactive mode")
  var interactive: Bool = false

  @Flag(name: .shortAndLong, help: "Remove a mapping")
  var remove: Bool = false

  func run() async throws {

    let profileStore = ProfileStore()

    guard try await profileStore.profileExists(named: profileName) else {
      print("Profile '\(profileName)' not found.")
      print("Create it first with: enjoyable profile-create \(profileName)")
      throw CLIError.profileNotFound(profileName)
    }

    var profile = try await profileStore.loadProfile(named: profileName)

    if interactive {
      try await _runInteractiveMode(&profile, profileStore: profileStore)
    } else if let button = button {
      try await _runSingleMapping(
        button: button,
        key: key,
        modifier: modifier,
        remove: remove,
        profile: &profile,
        profileStore: profileStore
      )
    } else {
      print(_bold("Button Mappings for Profile: \(profileName)"))
      print(String(repeating: "─", count: 50))
      print()

      if profile.buttonMappings.isEmpty {
        print("No mappings configured.")
        print()
        print("Add a mapping:")
        print("  enjoyable map \(profileName) --button A --key 0x00")
        print()
        print("Or enter interactive mode:")
        print("  enjoyable map \(profileName) --interactive")
      } else {
        print("Current mappings:")
        print()
        for mapping in profile.buttonMappings {
          _printMapping(mapping)
        }
        print()
        print("Total: \(profile.buttonMappings.count) mapping(s)")
      }
    }
  }

  private func _runInteractiveMode(
    _ profile: inout Profile,
    profileStore: ProfileStore
  ) async throws {
    print(_bold("Interactive Mapping Mode"))
    print(String(repeating: "─", count: 40))
    print()
    print("Press a button on your gamepad to detect it.")
    print("Type 'done' when finished, 'cancel' to abort.")
    print()

    var mappings: [ButtonMapping] = Array(profile.buttonMappings)

    while true {
      print()
      print(_bold("Mapping \(mappings.count + 1):"))
      print("Button identifier (e.g., A, B, X, Y, L1, R1): ", terminator: "")

      guard let buttonIdentifier = readLine(), buttonIdentifier.lowercased() != "done" else {
        break
      }

      guard !buttonIdentifier.isEmpty else {
        print("Invalid button identifier.")
        continue
      }

      print("Key code (hex, e.g., 0x00 for A, or name: a, s, d): ", terminator: "")

      guard let keyInput = readLine() else {
        continue
      }

      let keyCode = try _parseKeyCode(keyInput)

      print("Modifier (command, control, option, shift, or none): ", terminator: "")

      guard let modifierInput = readLine() else {
        continue
      }

      let modifier = _parseModifier(modifierInput)

      let mapping = ButtonMapping(
        buttonIdentifier: buttonIdentifier,
        keyCode: keyCode,
        modifier: modifier
      )

      mappings.append(mapping)
      print("Mapping added: \(buttonIdentifier) → Key 0x\(String(format: "%04X", keyCode))")
    }

    if mappings.count != profile.buttonMappings.count {
      profile = profile.withButtonMappings(mappings)
      try await profileStore.saveProfile(profile)
      print()
      print("Profile updated with \(mappings.count) mapping(s).")
    } else {
      print("No changes made.")
    }
  }

  private func _runSingleMapping(
    button: String,
    key: String?,
    modifier: String?,
    remove: Bool,
    profile: inout Profile,
    profileStore: ProfileStore
  ) async throws {
    guard let keyInput = key else {
      print("Error: --key is required when using --button")
      print("Usage: enjoyable map \(profileName) --button A --key 0x00")
      throw CLIError.mappingFailed("Missing key argument")
    }

    var mappings = Array(profile.buttonMappings)

    if remove {
      mappings.removeAll { $0.buttonIdentifier == button }
      print("Removed mapping for '\(button)'.")
    } else {
      let keyCode = try _parseKeyCode(keyInput)
      let modifierValue = _parseModifier(modifier ?? "none")

      let newMapping = ButtonMapping(
        buttonIdentifier: button,
        keyCode: keyCode,
        modifier: modifierValue
      )

      mappings.removeAll { $0.buttonIdentifier == button }
      mappings.append(newMapping)
      print("Set mapping: \(button) → Key 0x\(String(format: "%04X", keyCode))")
    }

    profile = profile.withButtonMappings(mappings)
    try await profileStore.saveProfile(profile)
    print("Profile saved.")
  }

  private func _parseKeyCode(_ input: String) throws -> UInt16 {
    let cleanedInput = input.trimmingCharacters(in: .whitespaces).lowercased()

    if cleanedInput.hasPrefix("0x") {
      guard let value = UInt16(cleanedInput.dropFirst(2), radix: 16) else {
        throw CLIError.mappingFailed("Invalid hex key code: \(input)")
      }
      return value
    }

    if let value = UInt16(cleanedInput) {
      return value
    }

    let keyMap: [String: UInt16] = [
      "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03,
      "h": 0x04, "g": 0x05, "z": 0x06, "x": 0x07,
      "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
      "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10,
      "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14,
      "4": 0x15, "5": 0x17, "6": 0x16, "7": 0x1A,
      "8": 0x1C, "9": 0x19, "0": 0x1D, "space": 0x31,
      "return": 0x24, "tab": 0x30, "escape": 0x35,
      "backspace": 0x33, "delete": 0x33,
    ]

    guard let keyCode = keyMap[cleanedInput] else {
      throw CLIError.mappingFailed("Unknown key name: \(input)")
    }

    return keyCode
  }

  private func _parseModifier(_ input: String) -> KeyModifier {
    let cleanedInput = input.trimmingCharacters(in: .whitespaces).lowercased()

    switch cleanedInput {
    case "command", "cmd":
      return .command
    case "control", "ctrl":
      return .control
    case "option", "alt":
      return .option
    case "shift":
      return .shift
    default:
      return .none
    }
  }

  private func _printMapping(_ mapping: ButtonMapping) {
    let modifierString: String
    switch mapping.modifier {
    case .none:
      modifierString = ""
    case .command:
      modifierString = "⌘ "
    case .control:
      modifierString = "⌃ "
    case .option:
      modifierString = "⌥ "
    case .shift:
      modifierString = "⇧ "
    }

    print(
      "  \(_bold(mapping.buttonIdentifier)): \(modifierString)Key 0x\(String(format: "%04X", mapping.keyCode))"
    )
  }

  private func _bold(_ text: String) -> String {
    return text.bold
  }
}
