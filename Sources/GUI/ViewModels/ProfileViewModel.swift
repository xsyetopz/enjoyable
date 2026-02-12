import Combine
import Configuration
import Core
import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
  @Published var profiles: [Profile] = []
  @Published var currentProfile: Profile?
  @Published var isLoading: Bool = false
  @Published var isSaving: Bool = false
  @Published var errorMessage: String?
  @Published var searchText: String = ""

  private let _profileStore: ProfileStore

  init(profileStore: ProfileStore = ProfileStore()) {
    self._profileStore = profileStore
    Task {
      await loadProfiles()
    }
  }

  var filteredProfiles: [Profile] {
    if searchText.isEmpty {
      return profiles
    }
    return profiles.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
  }

  func loadProfiles() async {
    isLoading = true
    errorMessage = nil

    do {
      profiles = try await _profileStore.loadAllProfiles()
      if profiles.isEmpty {
        let defaultProfile = Profile.default
        try await _profileStore.saveProfile(defaultProfile)
        profiles = [defaultProfile]
      }
      if currentProfile == nil {
        currentProfile = profiles.first
      }
    } catch {
      errorMessage = "Failed to load profiles: \(error.localizedDescription)"
    }

    isLoading = false
  }

  func createProfile(name: String) async {
    let newProfile = Profile(
      name: name.isEmpty ? "Profile \(profiles.count + 1)" : name,
      deviceID: nil,
      buttonMappings: []
    )

    do {
      try await _profileStore.saveProfile(newProfile)
      profiles.append(newProfile)
      currentProfile = newProfile
    } catch {
      errorMessage = "Failed to create profile: \(error.localizedDescription)"
    }
  }

  func saveProfile(_ profile: Profile) async {
    isSaving = true
    errorMessage = nil

    do {
      try await _profileStore.saveProfile(profile)
      if let index = profiles.firstIndex(where: { $0.name == profile.name }) {
        profiles[index] = profile
      }
    } catch {
      errorMessage = "Failed to save profile: \(error.localizedDescription)"
    }

    isSaving = false
  }

  func deleteProfile(_ profile: Profile) async {
    errorMessage = nil

    do {
      try await _profileStore.deleteProfile(named: profile.name)
      profiles.removeAll { $0.name == profile.name }
      if currentProfile?.name == profile.name {
        currentProfile = profiles.first
      }
    } catch {
      errorMessage = ErrorMessages.deleteProfileFailed(error.localizedDescription)
    }
  }

  func selectProfile(_ profile: Profile) {
    currentProfile = profile
  }

  func duplicateProfile(_ profile: Profile) async {
    let duplicateName = "\(profile.name) Copy"
    let duplicateProfile = Profile(
      name: duplicateName,
      deviceID: profile.deviceID,
      buttonMappings: profile.buttonMappings
    )

    do {
      try await _profileStore.saveProfile(duplicateProfile)
      profiles.append(duplicateProfile)
    } catch {
      errorMessage = ErrorMessages.duplicateProfileFailed(error.localizedDescription)
    }
  }

  func updateProfileName(_ name: String) {
    guard var profile = currentProfile else { return }
    profile = profile.withName(name)
    currentProfile = profile
  }

  func updateProfileDevice(_ deviceID: USBDeviceID?) {
    guard var profile = currentProfile else { return }
    profile = profile.withDeviceID(deviceID)
    currentProfile = profile
  }

  func addButtonMapping(_ mapping: ButtonMapping) {
    guard var profile = currentProfile else { return }
    var mappings = profile.buttonMappings
    if let index = mappings.firstIndex(where: { $0.buttonIdentifier == mapping.buttonIdentifier }) {
      mappings[index] = mapping
    } else {
      mappings.append(mapping)
    }
    profile = profile.withButtonMappings(mappings)
    currentProfile = profile
  }

  func removeButtonMapping(for buttonIdentifier: String) {
    guard var profile = currentProfile else { return }
    let mappings = profile.buttonMappings.filter { $0.buttonIdentifier != buttonIdentifier }
    profile = profile.withButtonMappings(mappings)
    currentProfile = profile
  }

  func exportProfile(_ profile: Profile) -> URL? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    guard let data = try? encoder.encode(profile) else {
      return nil
    }

    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "\(profile.name).json"
    )
    try? data.write(to: tempURL)
    return tempURL
  }

  func importProfile(from url: URL) async {
    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      var profile = try decoder.decode(Profile.self, from: data)
      profile = profile.withName("\(profile.name) (Imported)")

      try await _profileStore.saveProfile(profile)
      profiles.append(profile)
    } catch {
      errorMessage = "Failed to import profile: \(error.localizedDescription)"
    }
  }
}
