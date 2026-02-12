import Configuration
import Core
import Foundation

public actor ProfileService {
  private let _profileStore: ProfileStore
  private let _validator: ProfileValidator
  private var _profileCache: [String: Profile] = [:]
  private var _currentProfile: Profile
  private let _eventHandler: @Sendable (ProfileServiceEvent) -> Void

  public init(
    profileStore: ProfileStore,
    validator: ProfileValidator = ProfileValidator(),
    eventHandler: @escaping @Sendable (ProfileServiceEvent) -> Void = { _ in }
  ) {
    self._profileStore = profileStore
    self._validator = validator
    self._currentProfile = Profile.default
    self._eventHandler = eventHandler
  }

  public func initialize() async throws {
    let allProfiles = try await _profileStore.loadAllProfiles()

    for profile in allProfiles {
      _profileCache[profile.name] = profile
    }

    let defaultProfile = try await _profileStore.createDefaultProfile()
    _profileCache[defaultProfile.name] = defaultProfile
    _currentProfile = defaultProfile

    let event = ProfileServiceEvent(
      type: .initialized,
      profile: defaultProfile
    )
    _eventHandler(event)
  }

  public func loadAllProfiles() async throws -> [Profile] {
    let profiles = try await _profileStore.loadAllProfiles()

    for profile in profiles {
      _profileCache[profile.name] = profile
    }

    return profiles
  }

  public func loadProfile(named name: String) async throws -> Profile {
    if let cachedProfile = _profileCache[name] {
      return cachedProfile
    }

    let profile = try await _profileStore.loadProfile(named: name)
    _profileCache[name] = profile

    return profile
  }

  public func saveProfile(_ profile: Profile) async throws {
    try _validator.validate(profile)

    try await _profileStore.saveProfile(profile)
    _profileCache[profile.name] = profile

    if _currentProfile.name == profile.name {
      _currentProfile = profile
    }

    let event = ProfileServiceEvent(
      type: .profileSaved,
      profile: profile
    )
    _eventHandler(event)
  }

  public func deleteProfile(named name: String) async throws {
    try await _profileStore.deleteProfile(named: name)
    _profileCache.removeValue(forKey: name)

    if _currentProfile.name == name {
      _currentProfile = Profile.default
    }

    let event = ProfileServiceEvent(
      type: .profileDeleted,
      profileName: name
    )
    _eventHandler(event)
  }

  public func switchToProfile(named name: String) async throws {
    let profile = try await loadProfile(named: name)
    _currentProfile = profile

    let event = ProfileServiceEvent(
      type: .profileSwitched,
      profile: profile
    )
    _eventHandler(event)
  }

  public func getCurrentProfile() -> Profile {
    _currentProfile
  }

  public func updateCurrentProfile(_ profile: Profile) async throws {
    var updatedProfile = profile
    updatedProfile = Profile(
      name: profile.name,
      deviceID: profile.deviceID,
      buttonMappings: profile.buttonMappings,
      version: profile.version
    )

    try await saveProfile(updatedProfile)
  }

  public func addButtonMapping(_ mapping: ButtonMapping, to profileName: String) async throws {
    var profile = try await loadProfile(named: profileName)

    var mappings = profile.buttonMappings
    mappings.append(mapping)

    profile = Profile(
      name: profile.name,
      deviceID: profile.deviceID,
      buttonMappings: mappings,
      version: profile.version
    )

    try await saveProfile(profile)
  }

  public func removeButtonMapping(
    identifier: String,
    from profileName: String
  ) async throws {
    var profile = try await loadProfile(named: profileName)

    var mappings = profile.buttonMappings
    mappings.removeAll { $0.buttonIdentifier == identifier }

    profile = Profile(
      name: profile.name,
      deviceID: profile.deviceID,
      buttonMappings: mappings,
      version: profile.version
    )

    try await saveProfile(profile)
  }

  public func getProfileForDevice(_ deviceID: USBDeviceID) async throws -> Profile {
    let allProfiles = try await loadAllProfiles()

    for profile in allProfiles {
      if profile.deviceID == deviceID {
        return profile
      }
    }

    return _currentProfile
  }

  public func assignProfile(_ profileName: String, to deviceID: USBDeviceID) async throws {
    var profile = try await loadProfile(named: profileName)

    profile = Profile(
      name: profile.name,
      deviceID: deviceID,
      buttonMappings: profile.buttonMappings,
      version: profile.version
    )

    try await saveProfile(profile)
  }
}

extension ProfileService {
  public struct ProfileServiceEvent: Sendable {
    public let type: EventType
    public let profile: Profile?
    public let profileName: String?

    public init(
      type: EventType,
      profile: Profile? = nil,
      profileName: String? = nil
    ) {
      self.type = type
      self.profile = profile
      self.profileName = profileName
    }
  }

  public enum EventType: Sendable {
    case initialized
    case profileSwitched
    case profileSaved
    case profileDeleted
    case profileError
  }
}
