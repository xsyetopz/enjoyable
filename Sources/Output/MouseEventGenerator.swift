import AppKit
import CoreGraphics
import Foundation

public actor MouseEventGenerator {
  private let _eventSource: CGEventSource
  private let _mouseController: MouseController
  private var _lastScrollPosition: CGPoint
  private var _scrollMultiplier: Double
  private var _movementScale: Double

  public init(mouseController: MouseController) throws {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
      throw MouseEventGeneratorError.permissionDenied
    }
    self._eventSource = source
    self._mouseController = mouseController
    self._lastScrollPosition = .zero
    self._scrollMultiplier = 1.0
    self._movementScale = 1.0
  }

  public func generateMove(to position: CGPoint) async throws {
    try _validatePosition(position)
    guard
      let event = CGEvent(
        mouseEventSource: _eventSource,
        mouseType: .mouseMoved,
        mouseCursorPosition: position,
        mouseButton: .left
      )
    else {
      throw MouseEventGeneratorError.eventCreationFailed
    }
    event.flags = _getCurrentModifierFlags()
    event.post(tap: .cghidEventTap)
    await _mouseController.setPosition(position)
  }

  public func generateMove(deltaX: Double, deltaY: Double) async throws {
    let currentPosition = await _mouseController.getPosition()
    let newX = currentPosition.x + (deltaX * _movementScale)
    let newY = currentPosition.y + (deltaY * _movementScale)
    let clampedPosition = _clampPosition(CGPoint(x: newX, y: newY))
    try await generateMove(to: clampedPosition)
  }

  public func generateButtonDown(_ button: MouseController.MouseButton) async throws {
    let position = await _mouseController.getPosition()
    guard
      let event = CGEvent(
        mouseEventSource: _eventSource,
        mouseType: button.eventTypeDown,
        mouseCursorPosition: position,
        mouseButton: button.cgButton
      )
    else {
      throw MouseEventGeneratorError.eventCreationFailed
    }
    event.flags = _getCurrentModifierFlags()
    event.post(tap: .cghidEventTap)
    await _mouseController.pressButton(button)
  }

  public func generateButtonUp(_ button: MouseController.MouseButton) async throws {
    let position = await _mouseController.getPosition()
    guard
      let event = CGEvent(
        mouseEventSource: _eventSource,
        mouseType: button.eventTypeUp,
        mouseCursorPosition: position,
        mouseButton: button.cgButton
      )
    else {
      throw MouseEventGeneratorError.eventCreationFailed
    }
    event.flags = _getCurrentModifierFlags()
    event.post(tap: .cghidEventTap)
    await _mouseController.releaseButton(button)
  }

  public func generateClick(_ button: MouseController.MouseButton, clickCount: Int = 1) async throws
  {
    try await generateButtonDown(button)
    try await Task.sleep(nanoseconds: _clickDurationNanoseconds(clickCount))
    try await generateButtonUp(button)
  }

  public func generateDoubleClick(_ button: MouseController.MouseButton) async throws {
    try await generateClick(button, clickCount: 2)
  }

  public func generateScroll(deltaX: Double, deltaY: Double) async throws {
    let position = await _mouseController.getPosition()
    if #available(macOS 13.0, *) {
      try _generateModernScroll(deltaX: deltaX, deltaY: deltaY, position: position)
    } else {
      try _generateLegacyScroll(deltaX: deltaX, deltaY: deltaY, position: position)
    }
  }

  public func generateScrollVertical(_ deltaY: Double) async throws {
    try await generateScroll(deltaX: 0, deltaY: deltaY)
  }

  public func generateScrollHorizontal(_ deltaX: Double) async throws {
    try await generateScroll(deltaX: deltaX, deltaY: 0)
  }

  public func generateWheelScroll(_ deltaY: Double) async throws {
    try await generateScrollVertical(deltaY * _scrollMultiplier)
  }

  public func setScrollSensitivity(_ sensitivity: Double) {
    _scrollMultiplier = sensitivity
  }

  public func setMovementScale(_ scale: Double) {
    _movementScale = scale
  }

  public func getCurrentPosition() async -> CGPoint {
    await _mouseController.getPosition()
  }

  public func getButtonState(_ button: MouseController.MouseButton) async -> Bool {
    await _mouseController.isButtonPressed(button)
  }

  public func resetButtonStates() async throws {
    let states = await _mouseController.getButtonStates()
    for (button, isPressed) in states where isPressed {
      try await generateButtonUp(button)
    }
    await _mouseController.resetButtonStates()
  }

  @available(macOS 13.0, *)
  private func _generateModernScroll(deltaX: Double, deltaY: Double, position: CGPoint) throws {
    guard
      let event = CGEvent(
        mouseEventSource: _eventSource,
        mouseType: .scrollWheel,
        mouseCursorPosition: position,
        mouseButton: .left
      )
    else {
      throw MouseEventGeneratorError.eventCreationFailed
    }
    event.flags = _getCurrentModifierFlags()
    event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: deltaY)
    event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: deltaX)
    event.post(tap: .cghidEventTap)
  }

  private func _generateLegacyScroll(deltaX: Double, deltaY: Double, position: CGPoint) throws {
    guard
      let event = CGEvent(
        mouseEventSource: _eventSource,
        mouseType: .scrollWheel,
        mouseCursorPosition: position,
        mouseButton: .left
      )
    else {
      throw MouseEventGeneratorError.eventCreationFailed
    }
    event.flags = _getCurrentModifierFlags()
    event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(deltaY))
    event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(deltaX))
    event.post(tap: .cghidEventTap)
  }

  private func _validatePosition(_ position: CGPoint) throws {
    let screenBounds = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
    guard
      position.x >= screenBounds.minX && position.x <= screenBounds.maxX
        && position.y >= screenBounds.minY && position.y <= screenBounds.maxY
    else {
      throw MouseEventGeneratorError.positionOutOfBounds
    }
  }

  private func _clampPosition(_ position: CGPoint) -> CGPoint {
    let screenBounds = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let clampedX = max(screenBounds.minX, min(position.x, screenBounds.maxX))
    let clampedY = max(screenBounds.minY, min(position.y, screenBounds.maxY))
    return CGPoint(x: clampedX, y: clampedY)
  }

  private func _getCurrentModifierFlags() -> CGEventFlags {
    return []
  }

  private func _clickDurationNanoseconds(_ clickCount: Int) -> UInt64 {
    let baseDuration: TimeInterval = 0.05
    let duration = baseDuration * Double(clickCount)
    return UInt64(duration * 1_000_000_000)
  }
}

extension MouseEventGenerator {
  public enum MouseEventGeneratorError: LocalizedError {
    case permissionDenied
    case eventCreationFailed
    case positionOutOfBounds
    case invalidButton
    case postingFailed

    public var errorDescription: String? {
      switch self {
      case .permissionDenied:
        return "Permission denied: Cannot access event system"
      case .eventCreationFailed:
        return "Failed to create CGEvent"
      case .positionOutOfBounds:
        return "Mouse position is out of screen bounds"
      case .invalidButton:
        return "Invalid mouse button specified"
      case .postingFailed:
        return "Failed to post event to system"
      }
    }
  }
}
