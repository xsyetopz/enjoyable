import Configuration
import Core
import Foundation

public actor ConfigurationManager {
  private let _profileStore: ProfileStore
  private var _loadedProfiles: [String: Profile]
  private var _activeProfile: Profile?
  private var _activeDeviceID: USBDeviceID?
  private var _profileChangeHandler: ((Profile?, USBDeviceID?) -> Void)?

  public init(profileStore: ProfileStore) {
    self._profileStore = profileStore
    self._loadedProfiles = [:]
    self._activeProfile = nil
    self._activeDeviceID = nil
  }

  public func loadAllProfiles() async throws -> [Profile] {
    let profiles = try await _profileStore.loadAllProfiles()
    for profile in profiles {
      _loadedProfiles[profile.name] = profile
    }
    return profiles
  }

  public func loadProfile(named name: String) async throws -> Profile {
    let profile = try await _profileStore.loadProfile(named: name)
    _loadedProfiles[name] = profile
    return profile
  }

  public func saveProfile(_ profile: Profile) async throws {
    try await _profileStore.saveProfile(profile)
    _loadedProfiles[profile.name] = profile
  }

  public func deleteProfile(named name: String) async throws {
    try await _profileStore.deleteProfile(named: name)
    _loadedProfiles.removeValue(forKey: name)
    if _activeProfile?.name == name {
      _activeProfile = nil
    }
  }

  public func getProfile(named name: String) -> Profile? {
    _loadedProfiles[name]
  }

  public func setActiveProfile(_ profile: Profile, for deviceID: USBDeviceID?) {
    _activeProfile = profile
    _activeDeviceID = deviceID
    _notifyProfileChange()
  }

  public func getActiveProfile() -> Profile? {
    _activeProfile
  }

  public func getActiveDeviceID() -> USBDeviceID? {
    _activeDeviceID
  }

  public func findProfile(for deviceID: USBDeviceID, appBundleIdentifier: String?) -> Profile? {
    var candidates: [Profile] = []
    for profile in _loadedProfiles.values {
      if let profileDeviceID = profile.deviceID, profileDeviceID == deviceID {
        candidates.append(profile)
      }
    }
    return candidates.first
  }

  public func createProfile(name: String, deviceID: USBDeviceID? = nil) -> Profile {
    let profile = Profile(
      name: name,
      deviceID: deviceID,
      buttonMappings: []
    )
    _loadedProfiles[name] = profile
    return profile
  }

  public func duplicateProfile(_ profile: Profile, newName: String) -> Profile {
    let newProfile = Profile(
      name: newName,
      deviceID: profile.deviceID,
      buttonMappings: profile.buttonMappings
    )
    _loadedProfiles[newName] = newProfile
    return newProfile
  }

  public func addProfileChangeHandler(_ handler: @escaping (Profile?, USBDeviceID?) -> Void) {
    _profileChangeHandler = handler
  }

  public func listProfileNames() async throws -> [String] {
    try await _profileStore.listProfileNames()
  }

  public func profileExists(named name: String) async throws -> Bool {
    try await _profileStore.profileExists(named: name)
  }

  public func createDefaultProfileIfNeeded() async throws -> Profile {
    try await _profileStore.createDefaultProfile()
  }

  public func getProfilesDirectory() async -> URL {
    await _profileStore.profilesDirectory()
  }

  private func _notifyProfileChange() {
    _profileChangeHandler?(_activeProfile, _activeDeviceID)
  }
}

extension ConfigurationManager {
  public enum ConfigurationError: LocalizedError {
    case profileNotFound(name: String)
    case saveFailed(name: String, underlying: any Error)
    case loadFailed(name: String, underlying: any Error)
    case invalidProfile

    public var errorDescription: String? {
      switch self {
      case .profileNotFound(let name):
        return "Profile not found: \(name)"
      case .saveFailed(let name, let error):
        return "Failed to save profile \(name): \(error.localizedDescription)"
      case .loadFailed(let name, let error):
        return "Failed to load profile \(name): \(error.localizedDescription)"
      case .invalidProfile:
        return "Invalid profile configuration"
      }
    }
  }
}
