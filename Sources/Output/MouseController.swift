import AppKit
import CoreGraphics
import Foundation

public actor MouseController {
  private var _currentPosition: CGPoint
  private var _buttonStates: [MouseButton: Bool]
  private let _lock: NSLock
  private var _lastClickTime: [MouseButton: Date]
  private var _lastClickPosition: [MouseButton: CGPoint]
  private let _doubleClickDistance: Double
  private let _doubleClickInterval: TimeInterval

  public init() {
    self._currentPosition = .zero
    self._buttonStates = [.left: false, .right: false, .middle: false]
    self._lock = NSLock()
    self._lastClickTime = [:]
    self._lastClickPosition = [:]
    self._doubleClickDistance = 5.0
    self._doubleClickInterval = 0.5
    Task {
      await _updatePositionFromSystem()
    }
  }

  public func getPosition() -> CGPoint {
    _lock.lock()
    defer { _lock.unlock() }
    return _currentPosition
  }

  public func setPosition(_ position: CGPoint) {
    _lock.lock()
    defer { _lock.unlock() }
    let clampedPosition = _clampToScreen(position)
    _currentPosition = clampedPosition
  }

  public func moveTo(x: Double, y: Double) {
    _lock.lock()
    defer { _lock.unlock() }
    let newPosition = CGPoint(x: x, y: y)
    _currentPosition = _clampToScreen(newPosition)
  }

  public func moveBy(deltaX: Double, deltaY: Double) {
    _lock.lock()
    defer { _lock.unlock() }
    let newX = _currentPosition.x + deltaX
    let newY = _currentPosition.y + deltaY
    _currentPosition = _clampToScreen(CGPoint(x: newX, y: newY))
  }

  public func isButtonPressed(_ button: MouseButton) -> Bool {
    _lock.lock()
    defer { _lock.unlock() }
    return _buttonStates[button] ?? false
  }

  public func pressButton(_ button: MouseButton) {
    _lock.lock()
    defer { _lock.unlock() }
    _buttonStates[button] = true
  }

  public func releaseButton(_ button: MouseButton) {
    _lock.lock()
    defer { _lock.unlock() }
    _buttonStates[button] = false
  }

  public func clickButton(_ button: MouseButton) -> Int {
    _lock.lock()
    defer { _lock.unlock() }
    let now = Date()
    let position = _currentPosition
    var clickCount = 1
    if let lastTime = _lastClickTime[button], let lastPosition = _lastClickPosition[button] {
      let timeDiff = now.timeIntervalSince(lastTime)
      let distance = hypot(position.x - lastPosition.x, position.y - lastPosition.y)
      if timeDiff <= _doubleClickInterval && distance <= _doubleClickDistance {
        clickCount = 2
      }
    }
    _lastClickTime[button] = now
    _lastClickPosition[button] = position
    _buttonStates[button] = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      Task {
        await self._releaseButtonAsync(button)
      }
    }
    return clickCount
  }

  private func _releaseButtonAsync(_ button: MouseButton) {
    _lock.lock()
    defer { _lock.unlock() }
    _buttonStates[button] = false
  }

  public func getButtonStates() -> [MouseButton: Bool] {
    _lock.lock()
    defer { _lock.unlock() }
    return _buttonStates
  }

  public func resetButtonStates() {
    _lock.lock()
    defer { _lock.unlock() }
    for button in _buttonStates.keys {
      _buttonStates[button] = false
    }
  }

  public func getClickInfo(
    for button: MouseButton
  ) -> (clickCount: Int, position: CGPoint, time: Date)? {
    _lock.lock()
    defer { _lock.unlock() }
    guard let time = _lastClickTime[button], let position = _lastClickPosition[button] else {
      return nil
    }
    return (1, position, time)
  }

  private func _updatePositionFromSystem() {
    let event = CGEvent(
      mouseEventSource: nil,
      mouseType: .mouseMoved,
      mouseCursorPosition: .zero,
      mouseButton: .left
    )
    _lock.lock()
    _currentPosition = event?.location ?? .zero
    _lock.unlock()
  }

  private func _clampToScreen(_ position: CGPoint) -> CGPoint {
    guard let screen = NSScreen.main else {
      return position
    }
    let frame = screen.frame
    let clampedX = max(frame.minX, min(position.x, frame.maxX))
    let clampedY = max(frame.minY, min(position.y, frame.maxY))
    return CGPoint(x: clampedX, y: clampedY)
  }
}

extension MouseController {
  public enum MouseButton: String, Sendable, CaseIterable {
    case left
    case right
    case middle

    public var cgButton: CGMouseButton {
      switch self {
      case .left:
        return .left
      case .right:
        return .right
      case .middle:
        return .center
      }
    }

    public var eventTypeDown: CGEventType {
      switch self {
      case .left:
        return .leftMouseDown
      case .right:
        return .rightMouseDown
      case .middle:
        return .otherMouseDown
      }
    }

    public var eventTypeUp: CGEventType {
      switch self {
      case .left:
        return .leftMouseUp
      case .right:
        return .rightMouseUp
      case .middle:
        return .otherMouseUp
      }
    }
  }
}
