import Core
import CoreGraphics
import Foundation

public actor KeyboardEventGenerator {
  private let _eventSource: CGEventSource
  private var _pressedKeys: Set<UInt16>
  private var _modifierState: ModifierState
  private var _keyRepeatDelay: TimeInterval
  private var _keyRepeatInterval: TimeInterval

  public init() throws {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
      throw KeyboardEventGeneratorError.permissionDenied
    }
    self._eventSource = source
    self._pressedKeys = []
    self._modifierState = ModifierState()
    self._keyRepeatDelay = 0.5
    self._keyRepeatInterval = 0.05
  }

  public func pressKey(_ keyCode: UInt16, modifier: KeyModifier = .none) throws {
    try _validateKeyCode(keyCode)
    _pressedKeys.insert(keyCode)
    _updateModifierState(modifier, pressed: true)
    try _postKeyEvent(keyCode: keyCode, keyDown: true, modifier: modifier)
  }

  public func releaseKey(_ keyCode: UInt16, modifier: KeyModifier = .none) throws {
    try _validateKeyCode(keyCode)
    _pressedKeys.remove(keyCode)
    _updateModifierState(modifier, pressed: false)
    try _postKeyEvent(keyCode: keyCode, keyDown: false, modifier: modifier)
  }

  public func tapKey(
    _ keyCode: UInt16,
    modifier: KeyModifier = .none,
    duration: TimeInterval = 0.05
  ) async throws {
    try pressKey(keyCode, modifier: modifier)
    try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    try releaseKey(keyCode, modifier: modifier)
  }

  public func typeString(_ string: String) async throws {
    for character in string {
      try await _typeCharacter(character)
    }
  }

  public func pressModifier(_ modifier: KeyModifier) throws {
    switch modifier {
    case .command:
      try pressKey(0x37, modifier: .none)
    case .control:
      try pressKey(0x3B, modifier: .none)
    case .option:
      try pressKey(0x3A, modifier: .none)
    case .shift:
      try pressKey(0x38, modifier: .none)
    case .none:
      break
    }
  }

  public func releaseModifier(_ modifier: KeyModifier) throws {
    switch modifier {
    case .command:
      try releaseKey(0x37, modifier: .none)
    case .control:
      try releaseKey(0x3B, modifier: .none)
    case .option:
      try releaseKey(0x3A, modifier: .none)
    case .shift:
      try releaseKey(0x38, modifier: .none)
    case .none:
      break
    }
  }

  public func holdModifier(_ modifier: KeyModifier) throws {
    try pressModifier(modifier)
  }

  public func releaseAllModifiers() {
    for modifier in [KeyModifier.command, .control, .option, .shift] {
      try? releaseModifier(modifier)
    }
  }

  public func releaseAllKeys() {
    let keysToRelease = _pressedKeys
    for keyCode in keysToRelease {
      try? releaseKey(keyCode, modifier: .none)
    }
    _pressedKeys.removeAll()
    _modifierState = ModifierState()
  }

  public func isKeyPressed(_ keyCode: UInt16) -> Bool {
    _pressedKeys.contains(keyCode)
  }

  public func getPressedKeys() -> Set<UInt16> {
    _pressedKeys
  }

  public func getModifierState() -> ModifierState {
    _modifierState
  }

  public func setKeyRepeat(delay: TimeInterval, interval: TimeInterval) {
    _keyRepeatDelay = delay
    _keyRepeatInterval = interval
  }

  public func generateKeyDownEvent(_ keyCode: UInt16, flags: CGEventFlags = []) throws {
    guard
      let event = CGEvent(
        keyboardEventSource: _eventSource,
        virtualKey: keyCode,
        keyDown: true
      )
    else {
      throw KeyboardEventGeneratorError.eventCreationFailed
    }
    event.flags = flags
    event.post(tap: .cghidEventTap)
  }

  public func generateKeyUpEvent(_ keyCode: UInt16, flags: CGEventFlags = []) throws {
    guard
      let event = CGEvent(
        keyboardEventSource: _eventSource,
        virtualKey: keyCode,
        keyDown: false
      )
    else {
      throw KeyboardEventGeneratorError.eventCreationFailed
    }
    event.flags = flags
    event.post(tap: .cghidEventTap)
  }

  private func _typeCharacter(_ character: Character) async throws {
    let scalar = character.unicodeScalars.first!
    let keyCode = _characterToKeyCode(scalar)
    if keyCode != KeyCodeConstants.unmapped {
      try await tapKey(keyCode, modifier: .none)
    } else {
      _ = character
    }
  }

  private func _characterToKeyCode(_ scalar: Unicode.Scalar) -> UInt16 {
    let value = scalar.value
    switch value {
    case 97...122:
      return UInt16(value - 93)
    case 65...90:
      return UInt16(value - 61)
    case 48...57:
      return UInt16(value - 19)
    case 32:
      return KeyCodeConstants.Special.space
    case 10:
      return KeyCodeConstants.Special.returnKey
    case 9:
      return KeyCodeConstants.Special.tab
    case 27:
      return KeyCodeConstants.Special.escape
    case 127:
      return KeyCodeConstants.Special.backspace
    case 63232:
      return 0x3E
    case 63233:
      return 0x3D
    case 63234:
      return 0x3B
    case 63235:
      return 0x3C
    default:
      return KeyCodeConstants.unmapped
    }
  }

  private func _validateKeyCode(_ keyCode: UInt16) throws {
    guard keyCode != KeyCodeConstants.unmapped else {
      throw KeyboardEventGeneratorError.invalidKeyCode
    }
  }

  private func _postKeyEvent(keyCode: UInt16, keyDown: Bool, modifier: KeyModifier) throws {
    guard
      let event = CGEvent(
        keyboardEventSource: _eventSource,
        virtualKey: keyCode,
        keyDown: keyDown
      )
    else {
      throw KeyboardEventGeneratorError.eventCreationFailed
    }
    event.flags = _buildEventFlags(with: modifier)
    event.post(tap: .cghidEventTap)
  }

  private func _updateModifierState(_ modifier: KeyModifier, pressed: Bool) {
    switch modifier {
    case .command:
      _modifierState.command = pressed
    case .control:
      _modifierState.control = pressed
    case .option:
      _modifierState.option = pressed
    case .shift:
      _modifierState.shift = pressed
    case .none:
      break
    }
  }

  private func _buildEventFlags(with modifier: KeyModifier) -> CGEventFlags {
    var flags = _modifierState.toCGEventFlags()
    switch modifier {
    case .none:
      break
    case .command:
      flags.insert(.maskCommand)
    case .control:
      flags.insert(.maskControl)
    case .option:
      flags.insert(.maskAlternate)
    case .shift:
      flags.insert(.maskShift)
    }
    return flags
  }
}

extension KeyboardEventGenerator {
  public struct ModifierState: Sendable {
    public var command: Bool
    public var control: Bool
    public var option: Bool
    public var shift: Bool

    public init() {
      self.command = false
      self.control = false
      self.option = false
      self.shift = false
    }

    public func toCGEventFlags() -> CGEventFlags {
      var flags: CGEventFlags = []
      if command {
        flags.insert(.maskCommand)
      }
      if control {
        flags.insert(.maskControl)
      }
      if option {
        flags.insert(.maskAlternate)
      }
      if shift {
        flags.insert(.maskShift)
      }
      return flags
    }

    public var isEmpty: Bool {
      !command && !control && !option && !shift
    }
  }
}

extension KeyboardEventGenerator {
  public enum KeyboardEventGeneratorError: LocalizedError {
    case permissionDenied
    case invalidKeyCode
    case eventCreationFailed
    case postingFailed
    case unsupportedKey

    public var errorDescription: String? {
      switch self {
      case .permissionDenied:
        return "Permission denied: Cannot access event system"
      case .invalidKeyCode:
        return "Invalid key code provided"
      case .eventCreationFailed:
        return "Failed to create CGEvent"
      case .postingFailed:
        return "Failed to post event to system"
      case .unsupportedKey:
        return "Key is not supported for this operation"
      }
    }
  }
}
