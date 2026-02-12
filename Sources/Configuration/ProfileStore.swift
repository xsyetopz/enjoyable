import Core
import Foundation

public enum ProfileStoreError: Error, Sendable {
  case directoryCreationFailed(underlying: any Error)
  case fileReadFailed(path: String, underlying: any Error)
  case fileWriteFailed(path: String, underlying: any Error)
  case fileDeleteFailed(path: String, underlying: any Error)
  case directoryEnumerationFailed(underlying: any Error)
  case profileCorrupted(name: String, underlying: any Error)
  case unsupportedVersion(version: Int)
  case invalidFileName(name: String)
}

public actor ProfileStore {
  private let _fileManager: FileManager
  private let _profilesDirectory: URL
  private let _encoder: JSONEncoder
  private let _decoder: JSONDecoder

  public init(
    fileManager: FileManager = .default,
    profilesDirectory: URL? = nil
  ) {
    self._fileManager = fileManager
    self._encoder = JSONEncoder()
    self._decoder = JSONDecoder()

    let applicationSupport = fileManager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!
    let baseDirectory = applicationSupport.appendingPathComponent(Constants.Profile.directoryName)
    self._profilesDirectory = profilesDirectory ?? baseDirectory

    _encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  }

  private func _ensureDirectoryExists() throws {
    guard !_fileManager.fileExists(atPath: _profilesDirectory.path) else { return }

    do {
      try _fileManager.createDirectory(
        at: _profilesDirectory,
        withIntermediateDirectories: true
      )
    } catch {
      throw ProfileStoreError.directoryCreationFailed(underlying: error)
    }
  }

  private func _sanitizeFileName(_ name: String) -> String {
    return name.components(separatedBy: Constants.FileName.invalidCharacters).joined(separator: "_")
  }

  private func _profileFileURL(for name: String) -> URL {
    let sanitizedName = _sanitizeFileName(name)
    return _profilesDirectory.appendingPathComponent(
      "\(sanitizedName).\(Constants.Profile.fileExtension)"
    )
  }

  private func _validateProfile(_ profile: Profile) throws {
    guard profile.version <= Constants.Profile.currentVersion else {
      throw ProfileStoreError.unsupportedVersion(version: profile.version)
    }
  }

  private func _migrateProfile(_ profile: Profile) -> Profile {
    if profile.version < Constants.Profile.currentVersion {
      return Profile(
        name: profile.name,
        deviceID: profile.deviceID,
        buttonMappings: profile.buttonMappings,
        version: Constants.Profile.currentVersion
      )
    }
    return profile
  }

  public func loadAllProfiles() async throws -> [Profile] {
    try _ensureDirectoryExists()

    let files = try _fileManager.contentsOfDirectory(
      at: _profilesDirectory,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    )

    var profiles: [Profile] = []
    for file in files where file.pathExtension == Constants.Profile.fileExtension {
      do {
        let data = try Data(
          contentsOf: file,
          options: .mappedIfSafe
        )

        var profile = try _decoder.decode(Profile.self, from: data)
        try _validateProfile(profile)
        profile = _migrateProfile(profile)

        profiles.append(profile)
      } catch {
        let fileName = file.lastPathComponent
        throw ProfileStoreError.profileCorrupted(name: fileName, underlying: error)
      }
    }

    return profiles.sorted { $0.name < $1.name }
  }

  public func loadProfile(named name: String) async throws -> Profile {
    try _ensureDirectoryExists()

    let fileURL = _profileFileURL(for: name)

    guard _fileManager.fileExists(atPath: fileURL.path) else {
      throw ProfileStoreError.fileReadFailed(path: fileURL.path, underlying: NSError())
    }

    do {
      let data = try Data(
        contentsOf: fileURL,
        options: .mappedIfSafe
      )

      var profile = try _decoder.decode(Profile.self, from: data)
      try _validateProfile(profile)
      profile = _migrateProfile(profile)

      return profile
    } catch {
      throw ProfileStoreError.profileCorrupted(name: name, underlying: error)
    }
  }

  public func saveProfile(_ profile: Profile) async throws {
    try _ensureDirectoryExists()
    try _validateProfile(profile)

    let fileURL = _profileFileURL(for: profile.name)

    do {
      let data = try _encoder.encode(profile)
      try data.write(to: fileURL, options: .atomic)
    } catch {
      throw ProfileStoreError.fileWriteFailed(path: fileURL.path, underlying: error)
    }
  }

  public func deleteProfile(named name: String) async throws {
    try _ensureDirectoryExists()

    let fileURL = _profileFileURL(for: name)

    guard _fileManager.fileExists(atPath: fileURL.path) else { return }

    do {
      try _fileManager.removeItem(at: fileURL)
    } catch {
      throw ProfileStoreError.fileDeleteFailed(path: fileURL.path, underlying: error)
    }
  }

  public func profileExists(named name: String) async throws -> Bool {
    try _ensureDirectoryExists()

    let fileURL = _profileFileURL(for: name)
    return _fileManager.fileExists(atPath: fileURL.path)
  }

  public func listProfileNames() async throws -> [String] {
    try _ensureDirectoryExists()

    let files = try _fileManager.contentsOfDirectory(
      at: _profilesDirectory,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    )

    let names =
      files
      .filter { $0.pathExtension == Constants.Profile.fileExtension }
      .compactMap { url -> String? in
        do {
          let data = try Data(contentsOf: url, options: .mappedIfSafe)
          let profile = try _decoder.decode(Profile.self, from: data)
          return profile.name
        } catch {
          return nil
        }
      }

    return names.sorted()
  }

  public func createDefaultProfile() async throws -> Profile {
    let defaultProfile = Profile.default

    let exists = try await profileExists(named: defaultProfile.name)

    if !exists {
      try await saveProfile(defaultProfile)
    }

    return defaultProfile
  }

  public func profilesDirectory() -> URL {
    _profilesDirectory
  }
}
