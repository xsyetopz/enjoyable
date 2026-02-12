import Configuration
import Foundation

public actor ConfigurationStore {
  private let _profileStore: ProfileStore
  private let _configurationURL: URL

  public init(profileStore: ProfileStore) {
    self._profileStore = profileStore

    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    self._configurationURL = documentsPath.appendingPathComponent("enjoyable_config.json")
  }

  public func saveConfiguration(_ config: DriverConfiguration) async throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(config)
    try data.write(to: _configurationURL, options: Data.WritingOptions.atomic)
  }

  public func loadConfiguration() async throws -> DriverConfiguration {
    guard FileManager.default.fileExists(atPath: _configurationURL.path) else {
      return DriverConfiguration.default
    }

    let data = try Data(contentsOf: _configurationURL)
    let decoder = JSONDecoder()
    return try decoder.decode(DriverConfiguration.self, from: data)
  }

  public func saveProfile(_ profile: Profile) async throws {
    try await _profileStore.saveProfile(profile)
  }

  public func loadProfile(named name: String) async throws -> Profile {
    try await _profileStore.loadProfile(named: name)
  }

  public func loadAllProfiles() async throws -> [Profile] {
    try await _profileStore.loadAllProfiles()
  }

  public func deleteProfile(named name: String) async throws {
    try await _profileStore.deleteProfile(named: name)
  }

  public func listProfileNames() async throws -> [String] {
    try await _profileStore.listProfileNames()
  }

  public func profileExists(named name: String) async throws -> Bool {
    try await _profileStore.profileExists(named: name)
  }

  public func createDefaultProfile() async throws -> Profile {
    try await _profileStore.createDefaultProfile()
  }

  public func profilesDirectory() async -> URL {
    await _profileStore.profilesDirectory()
  }
}
