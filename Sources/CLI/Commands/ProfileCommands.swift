import ArgumentParser
import Configuration
import Core
import Foundation
import Rainbow

struct ProfileListCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "profile-list",
    abstract: "List all available profiles"
  )

  @Flag(name: .shortAndLong, help: "Show detailed information")
  var verbose: Bool = false

  func run() async throws {

    let profileStore = ProfileStore()
    let profiles = try await profileStore.loadAllProfiles()

    if profiles.isEmpty {
      print("No profiles found.")
      print()
      print("Create a new profile with:")
      print("  enjoyable profile-create <name>")
    } else {
      print("Found \(profiles.count) profile(s):")
      print()

      for profile in profiles {
        _printProfile(profile, verbose: verbose)
        print()
      }
    }
  }

  private func _printProfile(_ profile: Profile, verbose: Bool) {
    print("  \(_bold(profile.name))")

    if let deviceID = profile.deviceID {
      print("     Device: \(deviceID.stringValue)")
    } else {
      print("     Device: All devices")
    }

    print("     Mappings: \(profile.buttonMappings.count) button(s)")

    if verbose && !profile.buttonMappings.isEmpty {
      print("     Buttons:")
      for mapping in profile.buttonMappings.prefix(5) {
        print(
          "       - \(mapping.buttonIdentifier) → Key 0x\(String(format: "%04X", mapping.keyCode))"
        )
      }
      if profile.buttonMappings.count > 5 {
        print("       ... and \(profile.buttonMappings.count - 5) more")
      }
    }
  }

  private func _bold(_ text: String) -> String {
    return text.bold
  }
}

struct ProfileLoadCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "profile-load",
    abstract: "Load a profile by name"
  )

  @Argument(help: "The name of the profile to load")
  var name: String

  @Flag(name: .shortAndLong, help: "Activate the profile immediately")
  var activate: Bool = false

  func run() async throws {
    let profileStore = ProfileStore()

    guard try await profileStore.profileExists(named: name) else {
      print("Profile '\(name)' not found.")
      print()
      print("Available profiles:")
      let profiles = try await profileStore.listProfileNames()
      if profiles.isEmpty {
        print("  (none)")
      } else {
        for profileName in profiles {
          print("  - \(profileName)")
        }
      }
      throw CLIError.profileNotFound(name)
    }

    let profile = try await profileStore.loadProfile(named: name)
    print("Profile '\(name)' loaded successfully.")
    print()
    print("  Device: \(profile.deviceID?.stringValue ?? "All devices")")
    print("  Mappings: \(profile.buttonMappings.count) button(s)")

    if activate {
      print()
      print("Profile activated.")
    }
  }
}

struct ProfileCreateCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "profile-create",
    abstract: "Create a new profile"
  )

  @Argument(help: "The name for the new profile")
  var name: String

  @Option(name: .shortAndLong, help: "Device ID to target (format: VENDOR:PRODUCT)")
  var device: String?

  @Flag(name: .shortAndLong, help: "Create from default profile")
  var fromDefault: Bool = false

  func run() async throws {
    let profileStore = ProfileStore()

    if try await profileStore.profileExists(named: name) {
      print("Profile '\(name)' already exists.")
      print("Use a different name or delete the existing profile first.")
      throw CLIError.profileAlreadyExists(name)
    }

    let deviceID: USBDeviceID?
    if let deviceString = device {
      guard let parsedID = USBDeviceID.from(deviceString) else {
        print("Invalid device ID format: \(deviceString)")
        print("Expected format: VENDOR:PRODUCT (e.g., 045E:028E)")
        throw CLIError.invalidDeviceID(deviceString)
      }
      deviceID = parsedID
    } else {
      deviceID = nil
    }

    let profile: Profile
    if fromDefault {
      profile = Profile.default.withName(name).withDeviceID(deviceID)
    } else {
      profile = Profile(
        name: name,
        deviceID: deviceID,
        buttonMappings: []
      )
    }

    try await profileStore.saveProfile(profile)

    print("Profile '\(name)' created successfully.")
    print()
    print("  Name: \(profile.name)")
    print("  Device: \(profile.deviceID?.stringValue ?? "All devices")")
    print("  Mappings: \(profile.buttonMappings.count)")
    print()
    print("Edit mappings with:")
    print("  enjoyable map \(name)")
  }
}

struct ProfileDeleteCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "profile-delete",
    abstract: "Delete a profile by name"
  )

  @Argument(help: "The name of the profile to delete")
  var name: String

  @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
  var force: Bool = false

  func run() async throws {
    let profileStore = ProfileStore()

    guard try await profileStore.profileExists(named: name) else {
      print("Profile '\(name)' not found.")
      throw CLIError.profileNotFound(name)
    }

    if !force {
      print("Delete profile '\(name)'? (y/N)")
      guard let input = readLine(), input.lowercased() == "y" else {
        print("Cancelled.")
        return
      }
    }

    try await profileStore.deleteProfile(named: name)
    print("Profile '\(name)' deleted successfully.")
  }
}

enum CLIError: Error, LocalizedError {
  case profileNotFound(String)
  case profileAlreadyExists(String)
  case invalidDeviceID(String)
  case mappingFailed(String)

  var errorDescription: String? {
    switch self {
    case .profileNotFound(let name):
      return "Profile '\(name)' not found"
    case .profileAlreadyExists(let name):
      return "Profile '\(name)' already exists"
    case .invalidDeviceID(let id):
      return "Invalid device ID format: \(id)"
    case .mappingFailed(let message):
      return "Mapping failed: \(message)"
    }
  }
}
