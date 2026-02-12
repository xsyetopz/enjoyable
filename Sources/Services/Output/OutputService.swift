import Core
import Foundation
import Infrastructure

public actor OutputService {
  private let _cgEventAdapter: CGEventAdapter
  private let _keyboardService: KeyboardService
  private let _mouseService: MouseService
  private var _activeInputs: [String: Bool] = [:]
  private let _eventHandler: @Sendable (OutputServiceEvent) -> Void

  public init(
    cgEventAdapter: CGEventAdapter,
    eventHandler: @escaping @Sendable (OutputServiceEvent) -> Void = { _ in }
  ) {
    self._cgEventAdapter = cgEventAdapter
    self._keyboardService = KeyboardService(adapter: cgEventAdapter)
    self._mouseService = MouseService(adapter: cgEventAdapter)
    self._eventHandler = eventHandler
  }

  public func processOutput(input: InputRouter.ParsedInput) async throws {
    for inputState in input.inputs {
      try await _processInputState(inputState, deviceID: input.deviceID)
    }
  }

  private func _processInputState(
    _ inputState: InputRouter.InputState,
    deviceID: Core.USBDeviceID
  ) async throws {
    if let axisValue = inputState.axisValue {
      try await _processAxisInput(
        identifier: inputState.buttonIdentifier,
        value: axisValue
      )
    } else {
      try await _processButtonInput(inputState, deviceID: deviceID)
    }
  }

  private func _processButtonInput(
    _ inputState: InputRouter.InputState,
    deviceID: Core.USBDeviceID
  ) async throws {
    guard inputState.keyCode != Constants.KeyCode.unmapped else {
      return
    }

    let key = "\(deviceID.stringValue)_\(inputState.buttonIdentifier)"
    let wasPressed = _activeInputs[key] ?? false

    if inputState.isPressed && !wasPressed {
      try await _keyboardService.postKeyDown(
        keyCode: inputState.keyCode,
        modifier: inputState.modifier
      )
      _activeInputs[key] = true

      let event = OutputServiceEvent(
        type: .keyDown,
        keyCode: inputState.keyCode,
        modifier: inputState.modifier
      )
      _eventHandler(event)
    } else if !inputState.isPressed && wasPressed {
      try await _keyboardService.postKeyUp(
        keyCode: inputState.keyCode,
        modifier: inputState.modifier
      )
      _activeInputs[key] = false

      let event = OutputServiceEvent(
        type: .keyUp,
        keyCode: inputState.keyCode,
        modifier: inputState.modifier
      )
      _eventHandler(event)
    }
  }

  private func _processAxisInput(identifier: String, value: Double) async throws {
    let threshold = Constants.Input.mouseDeadzone

    if value > threshold {
      let deltaX = value * Constants.Input.mouseSensitivity * 10
      try await _mouseService.postMouseMove(deltaX: deltaX, deltaY: 0)
    } else if value < -threshold {
      let deltaX = value * Constants.Input.mouseSensitivity * 10
      try await _mouseService.postMouseMove(deltaX: deltaX, deltaY: 0)
    }
  }

  public func releaseAllInputs() async throws {
    for key in _activeInputs.keys {
      if _activeInputs[key] == true {
        let components = key.split(separator: "_")
        guard components.count >= 2 else {
          continue
        }

        let keyCode = Constants.KeyCode.unmapped

        try? await _keyboardService.postKeyUp(keyCode: keyCode, modifier: KeyModifier.none)
      }
    }

    _activeInputs.removeAll()

    try await _keyboardService.releaseAllKeys()

    let event = OutputServiceEvent(type: .allReleased)
    _eventHandler(event)
  }

  public func releaseInputs(for deviceID: Core.USBDeviceID) async throws {
    let prefix = deviceID.stringValue + "_"

    for key in _activeInputs.keys where key.hasPrefix(prefix) {
      if _activeInputs[key] == true {
        let keyCode = Constants.KeyCode.unmapped

        try? await _keyboardService.postKeyUp(keyCode: keyCode, modifier: KeyModifier.none)
      }
    }

    let keysToRemove = _activeInputs.keys.filter { $0.hasPrefix(prefix) }
    for key in keysToRemove {
      _activeInputs.removeValue(forKey: key)
    }

    let event = OutputServiceEvent(
      type: .deviceReleased,
      deviceID: deviceID
    )
    _eventHandler(event)
  }

  public func postMouseClick(button: CGEventAdapter.MouseButton, clickCount: Int = 1) async throws {
    try await _mouseService.postMouseClick(button: button, clickCount: clickCount)

    let event = OutputServiceEvent(
      type: .mouseClick,
      mouseButton: button,
      clickCount: clickCount
    )
    _eventHandler(event)
  }

  public func postMouseScroll(deltaX: Double, deltaY: Double) async throws {
    try await _mouseService.postMouseScroll(deltaX: deltaX, deltaY: deltaY)

    let event = OutputServiceEvent(
      type: .mouseScroll,
      scrollDeltaX: deltaX,
      scrollDeltaY: deltaY
    )
    _eventHandler(event)
  }

  public func postMouseMove(deltaX: Double, deltaY: Double) async throws {
    try await _mouseService.postMouseMove(deltaX: deltaX, deltaY: deltaY)

    let event = OutputServiceEvent(
      type: .mouseMove,
      scrollDeltaX: deltaX,
      scrollDeltaY: deltaY
    )
    _eventHandler(event)
  }

  public func getInputState(identifier: String, for deviceID: Core.USBDeviceID) -> Bool {
    let key = deviceID.stringValue + "_" + identifier
    return _activeInputs[key] ?? false
  }
}

extension OutputService {
  public struct OutputServiceEvent: Sendable {
    public let type: EventType
    public let keyCode: UInt16?
    public let modifier: KeyModifier?
    public let mouseButton: CGEventAdapter.MouseButton?
    public let clickCount: Int?
    public let scrollDeltaX: Double?
    public let scrollDeltaY: Double?
    public let deviceID: Core.USBDeviceID?

    public init(
      type: EventType,
      keyCode: UInt16? = nil,
      modifier: KeyModifier? = nil,
      mouseButton: CGEventAdapter.MouseButton? = nil,
      clickCount: Int? = nil,
      scrollDeltaX: Double? = nil,
      scrollDeltaY: Double? = nil,
      deviceID: Core.USBDeviceID? = nil
    ) {
      self.type = type
      self.keyCode = keyCode
      self.modifier = modifier
      self.mouseButton = mouseButton
      self.clickCount = clickCount
      self.scrollDeltaX = scrollDeltaX
      self.scrollDeltaY = scrollDeltaY
      self.deviceID = deviceID
    }
  }

  public enum EventType: Sendable {
    case keyDown
    case keyUp
    case mouseClick
    case mouseScroll
    case mouseMove
    case allReleased
    case deviceReleased
    case outputError
  }
}
