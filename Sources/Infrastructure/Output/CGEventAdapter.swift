import Core
import CoreGraphics
import Foundation

public actor CGEventAdapter {
  private var _eventSource: CGEventSource?
  private var _lastMousePosition: CGPoint
  private var _pressedKeys: [UInt16]
  private var _modifierFlags: CGEventFlags
  private let _clickDurationNanoseconds: UInt64

  public init() throws {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
      throw CGEventAdapterError.permissionDenied
    }
    self._eventSource = source
    self._lastMousePosition = .zero
    self._pressedKeys = []
    self._modifierFlags = []
    self._clickDurationNanoseconds = 50_000_000
  }

  public func postKeyPress(keyCode: UInt16) throws {
    guard keyCode != Constants.KeyCode.unmapped else {
      throw CGEventAdapterError.invalidKeyCode
    }

    try _postKeyEvent(keyCode: keyCode, type: .keyDown)
    _pressedKeys.append(keyCode)
  }

  public func postKeyRelease(keyCode: UInt16) throws {
    guard keyCode != Constants.KeyCode.unmapped else {
      throw CGEventAdapterError.invalidKeyCode
    }

    try _postKeyEvent(keyCode: keyCode, type: .keyUp)
    _pressedKeys.removeAll { $0 == keyCode }
  }

  public func postKeyDown(keyCode: UInt16, modifier: KeyModifier) throws {
    guard keyCode != Constants.KeyCode.unmapped else {
      throw CGEventAdapterError.invalidKeyCode
    }

    try _postKeyEvent(keyCode: keyCode, type: .keyDown)
    _pressedKeys.append(keyCode)
  }

  public func postKeyUp(keyCode: UInt16, modifier: KeyModifier) throws {
    guard keyCode != Constants.KeyCode.unmapped else {
      throw CGEventAdapterError.invalidKeyCode
    }

    try _postKeyEvent(keyCode: keyCode, type: .keyUp)
    _pressedKeys.removeAll { $0 == keyCode }
  }

  public func releaseAllKeys() throws {
    for keyCode in _pressedKeys {
      try _postKeyEvent(keyCode: keyCode, type: .keyUp)
    }
    _pressedKeys.removeAll()
  }

  public func postKeyTap(keyCode: UInt16) async throws {
    try postKeyPress(keyCode: keyCode)
    try await Task.sleep(nanoseconds: _clickDurationNanoseconds)
    try postKeyRelease(keyCode: keyCode)
  }

  public func postMouseMove(to position: CGPoint) throws {
    guard let source = _eventSource else {
      throw CGEventAdapterError.notInitialized
    }

    guard
      let event = CGEvent(
        mouseEventSource: source,
        mouseType: .mouseMoved,
        mouseCursorPosition: position,
        mouseButton: .left
      )
    else {
      throw CGEventAdapterError.eventCreationFailed
    }

    event.flags = _modifierFlags
    event.post(tap: .cghidEventTap)
    _lastMousePosition = position
  }

  public func postMouseMove(deltaX: Double, deltaY: Double) throws {
    let newPosition = CGPoint(
      x: _lastMousePosition.x + deltaX,
      y: _lastMousePosition.y + deltaY
    )
    try postMouseMove(to: newPosition)
  }

  public func postMouseClick(button: MouseButton, clickCount: Int = 1) async throws {
    try postMouseButtonDown(button: button)
    try await Task.sleep(nanoseconds: _clickDurationNanoseconds * UInt64(clickCount))
    try postMouseButtonUp(button: button)
  }

  public func postMouseButtonDown(button: MouseButton) throws {
    guard let source = _eventSource else {
      throw CGEventAdapterError.notInitialized
    }

    guard
      let event = CGEvent(
        mouseEventSource: source,
        mouseType: button.eventTypeDown,
        mouseCursorPosition: _lastMousePosition,
        mouseButton: button.cgButton
      )
    else {
      throw CGEventAdapterError.eventCreationFailed
    }

    event.flags = _modifierFlags
    event.post(tap: .cghidEventTap)
  }

  public func postMouseButtonUp(button: MouseButton) throws {
    guard let source = _eventSource else {
      throw CGEventAdapterError.notInitialized
    }

    guard
      let event = CGEvent(
        mouseEventSource: source,
        mouseType: button.eventTypeUp,
        mouseCursorPosition: _lastMousePosition,
        mouseButton: button.cgButton
      )
    else {
      throw CGEventAdapterError.eventCreationFailed
    }

    event.flags = _modifierFlags
    event.post(tap: .cghidEventTap)
  }

  public func postMouseScroll(deltaX: Double, deltaY: Double) throws {
    try postScrollWheel(deltaX: deltaX, deltaY: deltaY)
  }

  public func postScrollWheel(deltaX: Double, deltaY: Double) throws {
    guard let source = _eventSource else {
      throw CGEventAdapterError.notInitialized
    }

    guard
      let event = CGEvent(
        mouseEventSource: source,
        mouseType: .scrollWheel,
        mouseCursorPosition: _lastMousePosition,
        mouseButton: .left
      )
    else {
      throw CGEventAdapterError.eventCreationFailed
    }

    event.flags = _modifierFlags

    if #available(macOS 13.0, *) {
      _postModernScrollEvent(event: event, deltaX: deltaX, deltaY: deltaY)
    } else {
      _postLegacyScrollEvent(event: event, deltaX: deltaX, deltaY: deltaY)
    }

    event.post(tap: .cghidEventTap)
  }

  public func getCurrentMousePosition() -> CGPoint {
    _lastMousePosition
  }

  public func isKeyPressed(_ keyCode: UInt16) -> Bool {
    _pressedKeys.contains(keyCode)
  }

  public func getModifierFlags() -> CGEventFlags {
    _modifierFlags
  }

  public func setModifierFlags(_ flags: CGEventFlags) {
    _modifierFlags = flags
  }

  private func _postKeyEvent(keyCode: UInt16, type: CGEventType) throws {
    guard let source = _eventSource else {
      throw CGEventAdapterError.notInitialized
    }

    guard
      let event = CGEvent(
        keyboardEventSource: source,
        virtualKey: keyCode,
        keyDown: type == .keyDown
      )
    else {
      throw CGEventAdapterError.eventCreationFailed
    }

    event.flags = _modifierFlags
    event.post(tap: .cghidEventTap)
  }

  private func _postModernScrollEvent(event: CGEvent, deltaX: Double, deltaY: Double) {
    event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: deltaY)
    event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: deltaX)
  }

  private func _postLegacyScrollEvent(event: CGEvent, deltaX: Double, deltaY: Double) {
    event.flags = _modifierFlags
    event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(deltaY))
    event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(deltaX))
    event.post(tap: .cghidEventTap)
  }

  private func _validateKeyCode(_ keyCode: UInt16) throws {
    guard keyCode != Constants.KeyCode.unmapped else {
      throw CGEventAdapterError.invalidKeyCode
    }
  }
}

extension CGEventAdapter {
  public enum MouseButton: UInt8, Sendable, CaseIterable {
    case left = 0
    case right = 1
    case middle = 2

    public var cgButton: CGMouseButton {
      CGMouseButton(rawValue: UInt32(rawValue)) ?? .left
    }

    public var eventTypeDown: CGEventType {
      switch self {
      case .left: return .leftMouseDown
      case .right: return .rightMouseDown
      case .middle: return .otherMouseDown
      }
    }

    public var eventTypeUp: CGEventType {
      switch self {
      case .left: return .leftMouseUp
      case .right: return .rightMouseUp
      case .middle: return .otherMouseUp
      }
    }
  }

  public enum CGEventAdapterError: Error, LocalizedError {
    case permissionDenied
    case notInitialized
    case eventCreationFailed
    case invalidKeyCode
    case postingFailed

    public var errorDescription: String? {
      switch self {
      case .permissionDenied:
        return "Permission denied: Cannot access event system"
      case .notInitialized:
        return "CGEventAdapter not properly initialized"
      case .eventCreationFailed:
        return "Failed to create CGEvent"
      case .invalidKeyCode:
        return "Invalid key code provided"
      case .postingFailed:
        return "Failed to post event to system"
      }
    }
  }
}
