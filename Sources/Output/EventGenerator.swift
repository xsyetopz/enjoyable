import Configuration
import Core
import CoreGraphics
import Foundation

public actor EventGenerator {
  private let _keyboardGenerator: KeyboardEventGenerator
  private let _mouseController: MouseController
  private let _mouseEventGenerator: MouseEventGenerator
  private var _activeProfile: Profile
  private let _profileStore: ProfileStore
  private var _buttonMappingCache: [String: ButtonMapping]
  private var _inputState: InputState

  public init(profileStore: ProfileStore) async throws {
    self._keyboardGenerator = try KeyboardEventGenerator()
    self._mouseController = MouseController()
    self._mouseEventGenerator = try MouseEventGenerator(mouseController: _mouseController)
    self._activeProfile = Profile.default
    self._profileStore = profileStore
    self._buttonMappingCache = [:]
    self._inputState = InputState()
    try await _loadDefaultProfile()
  }

  public func processGamepadInput(_ input: GamepadInput) async throws {
    let mapping = _getMapping(for: input.buttonIdentifier)
    switch input.inputType {
    case .button:
      try await _handleButtonInput(input, mapping: mapping)
    case .axis:
      try await _handleAxisInput(input, mapping: mapping)
    case .trigger:
      try await _handleTriggerInput(input, mapping: mapping)
    case .dpad:
      try await _handleDpadInput(input, mapping: mapping)
    }
  }

  public func processButtonPress(_ buttonIdentifier: String, pressed: Bool) async throws {
    let mapping = _getMapping(for: buttonIdentifier)
    if pressed {
      try await _handleButtonPress(mapping)
    } else {
      try await _handleButtonRelease(mapping)
    }
  }

  public func processAxisChange(_ axisIdentifier: String, value: Double) async throws {
    let mapping = _getMapping(for: axisIdentifier)
    try await _handleAxisChange(mapping, value: value)
  }

  public func setActiveProfile(_ profile: Profile) {
    _activeProfile = profile
    _rebuildMappingCache()
  }

  public func loadProfile(named name: String) async throws {
    let profile = try await _profileStore.loadProfile(named: name)
    setActiveProfile(profile)
  }

  public func getActiveProfile() -> Profile {
    return _activeProfile
  }

  public func getInputState() -> InputState {
    return _inputState
  }

  public func resetAllStates() async throws {
    try await _keyboardGenerator.releaseAllKeys()
    try await _mouseEventGenerator.resetButtonStates()
    _inputState = InputState()
  }

  public func executeMapping(_ mapping: ButtonMapping, action: MappingAction) async throws {
    switch action {
    case .keyPress:
      try await _keyboardGenerator.tapKey(mapping.keyCode, modifier: mapping.modifier)
    case .keyHold:
      try await _keyboardGenerator.pressKey(mapping.keyCode, modifier: mapping.modifier)
    case .keyRelease:
      try await _keyboardGenerator.releaseKey(mapping.keyCode, modifier: mapping.modifier)
    case .mouseMove:
      try await _mouseEventGenerator.generateMove(deltaX: 0, deltaY: 0)
    case .mouseClick:
      try await _mouseEventGenerator.generateClick(.left)
    case .mouseScroll:
      try await _mouseEventGenerator.generateScroll(deltaX: 0, deltaY: 1)
    }
  }

  public func typeText(_ text: String) async throws {
    try await _keyboardGenerator.typeString(text)
  }

  public func sendKeystroke(_ keyCode: UInt16, modifier: KeyModifier = .none) async throws {
    try await _keyboardGenerator.tapKey(keyCode, modifier: modifier)
  }

  public func moveMouse(to position: CGPoint) async throws {
    try await _mouseEventGenerator.generateMove(to: position)
  }

  public func moveMouse(deltaX: Double, deltaY: Double) async throws {
    try await _mouseEventGenerator.generateMove(deltaX: deltaX, deltaY: deltaY)
  }

  public func clickMouse(
    _ button: MouseController.MouseButton = .left,
    clickCount: Int = 1
  ) async throws {
    try await _mouseEventGenerator.generateClick(button, clickCount: clickCount)
  }

  public func scrollMouse(deltaX: Double, deltaY: Double) async throws {
    try await _mouseEventGenerator.generateScroll(deltaX: deltaX, deltaY: deltaY)
  }

  public func holdKey(_ keyCode: UInt16, modifier: KeyModifier = .none) async throws {
    try await _keyboardGenerator.pressKey(keyCode, modifier: modifier)
  }

  public func releaseKey(_ keyCode: UInt16, modifier: KeyModifier = .none) async throws {
    try await _keyboardGenerator.releaseKey(keyCode, modifier: modifier)
  }

  public func pressModifier(_ modifier: KeyModifier) async throws {
    try await _keyboardGenerator.holdModifier(modifier)
  }

  public func releaseModifier(_ modifier: KeyModifier) async throws {
    try await _keyboardGenerator.releaseModifier(modifier)
  }

  public func getMousePosition() async -> CGPoint {
    await _mouseEventGenerator.getCurrentPosition()
  }

  public func getKeyboardState() async -> KeyboardEventGenerator.ModifierState {
    await _keyboardGenerator.getModifierState()
  }

  public func getMouseButtonStates() async -> [MouseController.MouseButton: Bool] {
    await _mouseController.getButtonStates()
  }

  private func _loadDefaultProfile() async throws {
    do {
      let profile = try await _profileStore.createDefaultProfile()
      setActiveProfile(profile)
    } catch {
    }
  }

  private func _getMapping(for buttonIdentifier: String) -> ButtonMapping {
    return _buttonMappingCache[buttonIdentifier] ?? ButtonMapping.empty
  }

  private func _rebuildMappingCache() {
    _buttonMappingCache = [:]
    for mapping in _activeProfile.buttonMappings {
      _buttonMappingCache[mapping.buttonIdentifier] = mapping
    }
  }

  private func _handleButtonInput(_ input: GamepadInput, mapping: ButtonMapping) async throws {
    if mapping.keyCode == Constants.KeyCode.unmapped {
      return
    }
    if input.value > 0.5 {
      try await _handleButtonPress(mapping)
    } else {
      try await _handleButtonRelease(mapping)
    }
  }

  private func _handleAxisInput(_ input: GamepadInput, mapping: ButtonMapping) async throws {
    let deadzone = 0.15
    let value = abs(input.value)
    if value > deadzone {
      let normalizedValue = (value - deadzone) / (1.0 - deadzone)
      try await _handleAxisChange(mapping, value: normalizedValue * input.value)
    } else {
      try await _handleAxisChange(mapping, value: 0)
    }
  }

  private func _handleTriggerInput(_ input: GamepadInput, mapping: ButtonMapping) async throws {
    let deadzone = 0.15
    let value = input.value
    if value > deadzone {
      let normalizedValue = (value - deadzone) / (1.0 - deadzone)
      try await _handleAxisChange(mapping, value: normalizedValue)
    } else {
      try await _handleAxisChange(mapping, value: 0)
    }
  }

  private func _handleDpadInput(_ input: GamepadInput, mapping: ButtonMapping) async throws {
    let deadzone = 0.5
    let value = input.value
    if abs(value) > deadzone {
      try await _handleAxisChange(mapping, value: value)
    } else {
      try await _handleAxisChange(mapping, value: 0)
    }
  }

  private func _handleButtonPress(_ mapping: ButtonMapping) async throws {
    _inputState.buttons[mapping.buttonIdentifier] = true
    try await _keyboardGenerator.pressKey(mapping.keyCode, modifier: mapping.modifier)
  }

  private func _handleButtonRelease(_ mapping: ButtonMapping) async throws {
    _inputState.buttons[mapping.buttonIdentifier] = false
    try await _keyboardGenerator.releaseKey(mapping.keyCode, modifier: mapping.modifier)
  }

  private func _handleAxisChange(_ mapping: ButtonMapping, value: Double) async throws {
    _inputState.axes[mapping.buttonIdentifier] = value
    if mapping.keyCode == Constants.KeyCode.unmapped {
      return
    }
    let keyCode = mapping.keyCode
    if value > 0 {
      try await _keyboardGenerator.pressKey(keyCode, modifier: mapping.modifier)
    } else {
      try await _keyboardGenerator.releaseKey(keyCode, modifier: mapping.modifier)
    }
  }
}

extension EventGenerator {
  public enum MappingAction {
    case keyPress
    case keyHold
    case keyRelease
    case mouseMove
    case mouseClick
    case mouseScroll
  }
}

extension EventGenerator {
  public struct GamepadInput: Sendable, Equatable {
    public let buttonIdentifier: String
    public let inputType: InputType
    public let value: Double
    public let timestamp: Date

    public init(
      buttonIdentifier: String,
      inputType: InputType,
      value: Double,
      timestamp: Date = .now
    ) {
      self.buttonIdentifier = buttonIdentifier
      self.inputType = inputType
      self.value = value
      self.timestamp = timestamp
    }

    public enum InputType: String, Sendable {
      case button
      case axis
      case trigger
      case dpad
    }
  }
}

extension EventGenerator {
  public struct InputState: Sendable {
    public var buttons: [String: Bool]
    public var axes: [String: Double]
    public var lastUpdate: Date

    public init() {
      self.buttons = [:]
      self.axes = [:]
      self.lastUpdate = .now
    }

    public var activeButtonCount: Int {
      buttons.values.filter { $0 }.count
    }

    public var activeAxesCount: Int {
      axes.values.filter { $0 != 0 }.count
    }

    public mutating func updateButton(_ identifier: String, pressed: Bool) {
      buttons[identifier] = pressed
      lastUpdate = .now
    }

    public mutating func updateAxis(_ identifier: String, value: Double) {
      axes[identifier] = value
      lastUpdate = .now
    }

    public func isButtonActive(_ identifier: String) -> Bool {
      buttons[identifier] ?? false
    }

    public func getAxisValue(_ identifier: String) -> Double {
      axes[identifier] ?? 0.0
    }
  }
}

extension EventGenerator {
  public enum EventGeneratorError: LocalizedError {
    case profileLoadFailed(name: String)
    case eventGenerationFailed(underlying: any Error)
    case invalidMapping(buttonIdentifier: String)
    case stateCorrupted

    public var errorDescription: String? {
      switch self {
      case .profileLoadFailed(let name):
        return "Failed to load profile: \(name)"
      case .eventGenerationFailed(let error):
        return "Event generation failed: \(error.localizedDescription)"
      case .invalidMapping(let buttonIdentifier):
        return "Invalid button mapping: \(buttonIdentifier)"
      case .stateCorrupted:
        return "Internal state is corrupted"
      }
    }
  }
}
