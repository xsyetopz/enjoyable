import Combine
import Configuration
import Core
import SwiftUI

@MainActor
final class MappingViewModel: ObservableObject {
  @Published public var selectedButton: String?
  @Published public var isRecording: Bool = false
  @Published public var recordedKeyCode: UInt16 = 0
  @Published public var recordedModifier: KeyModifier = .none

  @Published public var selectedDevice: GamepadDevice?
  @Published public var selectedTab: MainTab = .devices
  @Published public var currentProfile: Profile?
  @Published public var buttonStates: [String: Bool] = [:]
  @Published public var searchText: String = ""

  @Published public var availableKeys: [KeyOption] = []
  public let standardButtons = GamepadConstants.Button.allNames

  private let _profileStore: ProfileStore

  init(profileStore: ProfileStore = ProfileStore()) {
    self._profileStore = profileStore
    _loadAvailableKeys()
  }

  private func _loadAvailableKeys() {
    availableKeys = [
      KeyOption(name: "A", keyCode: Constants.KeyCode.Letter.a),
      KeyOption(name: "S", keyCode: Constants.KeyCode.Letter.s),
      KeyOption(name: "D", keyCode: Constants.KeyCode.Letter.d),
      KeyOption(name: "F", keyCode: Constants.KeyCode.Letter.f),
      KeyOption(name: "W", keyCode: Constants.KeyCode.Letter.w),
      KeyOption(name: "Space", keyCode: Constants.KeyCode.Special.space),
      KeyOption(name: "Return", keyCode: Constants.KeyCode.Special.returnKey),
      KeyOption(name: "Escape", keyCode: Constants.KeyCode.Special.escape),
      KeyOption(name: "Tab", keyCode: Constants.KeyCode.Special.tab),
      KeyOption(name: "Backspace", keyCode: Constants.KeyCode.Special.backspace),
      KeyOption(name: "Q", keyCode: Constants.KeyCode.Letter.q),
      KeyOption(name: "E", keyCode: Constants.KeyCode.Letter.e),
      KeyOption(name: "R", keyCode: Constants.KeyCode.Letter.r),
      KeyOption(name: "T", keyCode: Constants.KeyCode.Letter.t),
      KeyOption(name: "Y", keyCode: Constants.KeyCode.Letter.y),
      KeyOption(name: "U", keyCode: 0x20),
      KeyOption(name: "I", keyCode: 0x22),
      KeyOption(name: "O", keyCode: 0x1F),
      KeyOption(name: "P", keyCode: 0x23),
      KeyOption(name: "1", keyCode: Constants.KeyCode.Number.one),
      KeyOption(name: "2", keyCode: Constants.KeyCode.Number.two),
      KeyOption(name: "3", keyCode: Constants.KeyCode.Number.three),
      KeyOption(name: "4", keyCode: Constants.KeyCode.Number.four),
      KeyOption(name: "5", keyCode: Constants.KeyCode.Number.five),
      KeyOption(name: "6", keyCode: Constants.KeyCode.Number.six),
      KeyOption(name: "7", keyCode: Constants.KeyCode.Number.seven),
      KeyOption(name: "8", keyCode: Constants.KeyCode.Number.eight),
      KeyOption(name: "9", keyCode: Constants.KeyCode.Number.nine),
      KeyOption(name: "0", keyCode: Constants.KeyCode.Number.zero),
      KeyOption(name: "Z", keyCode: Constants.KeyCode.Letter.z),
      KeyOption(name: "X", keyCode: Constants.KeyCode.Letter.x),
      KeyOption(name: "C", keyCode: Constants.KeyCode.Letter.c),
      KeyOption(name: "V", keyCode: Constants.KeyCode.Letter.v),
      KeyOption(name: "B", keyCode: Constants.KeyCode.Letter.b),
      KeyOption(name: "N", keyCode: 0x2D),
      KeyOption(name: "M", keyCode: 0x2E),
      KeyOption(name: "G", keyCode: Constants.KeyCode.Letter.g),
      KeyOption(name: "H", keyCode: Constants.KeyCode.Letter.h),
    ]
  }

  func startRecording(for button: String) {
    selectedButton = button
    isRecording = true
    recordedKeyCode = 0
    recordedModifier = .none
  }

  func stopRecording() {
    isRecording = false
  }

  func recordKeyPress(keyCode: UInt16, modifier: KeyModifier) {
    recordedKeyCode = keyCode
    recordedModifier = modifier
  }

  func saveMapping(for button: String) -> ButtonMapping? {
    guard let selectedButton = selectedButton else { return nil }
    return ButtonMapping(
      buttonIdentifier: selectedButton,
      keyCode: recordedKeyCode,
      modifier: recordedModifier
    )
  }

  func clearMapping(for button: String) {
    if selectedButton == button {
      selectedButton = nil
      isRecording = false
      recordedKeyCode = 0
      recordedModifier = .none
    }
  }

  func saveCurrentProfile() async {
    guard let profile = currentProfile else { return }
    do {
      try await _profileStore.saveProfile(profile)
    } catch {
      NSLog("Failed to save profile: \(error)")
    }
  }

  func updateButtonMapping(for buttonIdentifier: String, mapping: ButtonMapping) {
    guard var profile = currentProfile else { return }
    var mappings = profile.buttonMappings
    if let index = mappings.firstIndex(where: { $0.buttonIdentifier == buttonIdentifier }) {
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

  func keyCodeToString(_ keyCode: UInt16) -> String {
    switch keyCode {
    case Constants.KeyCode.Letter.a: return "A"
    case Constants.KeyCode.Letter.s: return "S"
    case Constants.KeyCode.Letter.d: return "D"
    case Constants.KeyCode.Letter.f: return "F"
    case Constants.KeyCode.Letter.h: return "H"
    case Constants.KeyCode.Letter.g: return "G"
    case Constants.KeyCode.Letter.z: return "Z"
    case Constants.KeyCode.Letter.x: return "X"
    case Constants.KeyCode.Letter.c: return "C"
    case Constants.KeyCode.Letter.v: return "V"
    case Constants.KeyCode.Letter.b: return "B"
    case Constants.KeyCode.Letter.q: return "Q"
    case Constants.KeyCode.Letter.w: return "W"
    case Constants.KeyCode.Letter.e: return "E"
    case Constants.KeyCode.Letter.r: return "R"
    case Constants.KeyCode.Letter.y: return "Y"
    case Constants.KeyCode.Letter.t: return "T"
    case Constants.KeyCode.Number.one: return "1"
    case Constants.KeyCode.Number.two: return "2"
    case Constants.KeyCode.Number.three: return "3"
    case Constants.KeyCode.Number.four: return "4"
    case Constants.KeyCode.Number.five: return "5"
    case Constants.KeyCode.Number.six: return "6"
    case Constants.KeyCode.Number.seven: return "7"
    case Constants.KeyCode.Number.eight: return "8"
    case Constants.KeyCode.Number.nine: return "9"
    case Constants.KeyCode.Number.zero: return "0"
    case Constants.KeyCode.Special.space: return "Space"
    case Constants.KeyCode.Special.returnKey: return "Return"
    case Constants.KeyCode.Special.tab: return "Tab"
    case Constants.KeyCode.Special.escape: return "Escape"
    case Constants.KeyCode.Special.backspace: return "Backspace"
    case 0x20: return "U"
    case 0x22: return "I"
    case 0x1F: return "O"
    case 0x23: return "P"
    case 0x2D: return "N"
    case 0x2E: return "M"
    default: return "Key \(keyCode)"
    }
  }

  func modifierToString(_ modifier: KeyModifier) -> String {
    switch modifier {
    case .none: return ""
    case .command: return "⌘"
    case .control: return "⌃"
    case .option: return "⌥"
    case .shift: return "⇧"
    }
  }
}

struct KeyOption: Identifiable {
  let id = UUID()
  let name: String
  let keyCode: UInt16
}
