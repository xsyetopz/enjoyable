import Core
import Foundation
import Infrastructure
import Protocol

public actor OutputService {
  private let _cgEventAdapter: CGEventAdapter
  private let _keyboardService: KeyboardService
  private let _mouseService: MouseService
  private var _activeInputs: [String: Bool] = [:]
  private var _virtualHIDService: VirtualHIDService?
  private var _virtualDeviceIDs: [Core.USBDeviceID: UUID] = [:]
  private let _eventHandler: @Sendable (OutputServiceEvent) -> Void
  
  public init(
    cgEventAdapter: CGEventAdapter,
    virtualHIDService: VirtualHIDService? = nil,
    eventHandler: @escaping @Sendable (OutputServiceEvent) -> Void = { _ in }
  ) {
    self._cgEventAdapter = cgEventAdapter
    self._keyboardService = KeyboardService(adapter: cgEventAdapter)
    self._mouseService = MouseService(adapter: cgEventAdapter)
    self._virtualHIDService = virtualHIDService
    self._eventHandler = eventHandler
  }
  
  public func setVirtualHIDService(_ service: VirtualHIDService?) {
    _virtualHIDService = service
  }
  
  public func createVirtualDevice(for deviceID: Core.USBDeviceID, vendorID: UInt16, productID: UInt16, productName: String) async throws {
    guard let virtualHIDService = _virtualHIDService else {
      throw OutputServiceError.virtualHIDNotAvailable
    }
    
    let deviceUUID = try await virtualHIDService.createVirtualGamepad(
      vendorID: vendorID,
      productID: productID,
      productName: productName
    )
    
    _virtualDeviceIDs[deviceID] = deviceUUID
    
    let event = OutputServiceEvent(
      type: .virtualDeviceCreated,
      deviceID: deviceID
    )
    _eventHandler(event)
  }
  
  public func destroyVirtualDevice(for deviceID: Core.USBDeviceID) async throws {
    guard let virtualHIDService = _virtualHIDService else {
      throw OutputServiceError.virtualHIDNotAvailable
    }

    guard let deviceUUID = _virtualDeviceIDs.removeValue(forKey: deviceID) else {
      throw OutputServiceError.deviceNotFound
    }

    try await virtualHIDService.sendOutputReport(
      deviceID: deviceUUID,
      leftMotor: 0,
      rightMotor: 0,
      ledPattern: .off
    )

    try await virtualHIDService.destroyVirtualGamepad(deviceID: deviceUUID)

    let event = OutputServiceEvent(
      type: .virtualDeviceDestroyed,
      deviceID: deviceID
    )
    _eventHandler(event)
  }
  
  public func processOutput(input: InputRouter.ParsedInput) async throws {
    for inputState in input.inputs {
      try await _processInputState(inputState, deviceID: input.deviceID)
    }
  }
  
  public func processEvents(_ events: [InputEvent], for deviceID: Core.USBDeviceID) async throws {
    for event in events {
      try await _processEvent(event, deviceID: deviceID)
    }
  }
  
  private func _processEvent(_ event: InputEvent, deviceID: Core.USBDeviceID) async throws {
    switch event {
    case .buttonPress(let buttonEvent):
      try await _handleButtonPress(buttonEvent, deviceID: deviceID)
    case .buttonRelease(let buttonEvent):
      try await _handleButtonRelease(buttonEvent, deviceID: deviceID)
    case .axisMove(let axisEvent):
      try await _handleAxisMove(axisEvent, deviceID: deviceID)
    case .triggerMove(let triggerEvent):
      try await _handleTriggerMove(triggerEvent, deviceID: deviceID)
    case .dpadMove(let dpadEvent):
      try await _handleDPadMove(dpadEvent, deviceID: deviceID)
    default:
      break
    }
  }
  
  private func _handleButtonPress(_ event: ButtonEvent, deviceID: Core.USBDeviceID) async throws {
    let key = "\(deviceID.stringValue)_\(event.buttonID.displayName)"
    guard _activeInputs[key] != true else { return }
    
    _activeInputs[key] = true
    
    if let virtualDeviceID = _virtualDeviceIDs[deviceID] {
      try await _sendVirtualButtonPress(deviceID: virtualDeviceID, button: event.buttonID, isPressed: true)
    }
    
    let outputEvent = OutputServiceEvent(
      type: .buttonDown,
      deviceID: deviceID,
      buttonID: event.buttonID
    )
    _eventHandler(outputEvent)
  }
  
  private func _handleButtonRelease(_ event: ButtonEvent, deviceID: Core.USBDeviceID) async throws {
    let key = "\(deviceID.stringValue)_\(event.buttonID.displayName)"
    guard _activeInputs[key] == true else { return }
    
    _activeInputs[key] = false
    
    if let virtualDeviceID = _virtualDeviceIDs[deviceID] {
      try await _sendVirtualButtonPress(deviceID: virtualDeviceID, button: event.buttonID, isPressed: false)
    }
    
    let outputEvent = OutputServiceEvent(
      type: .buttonUp,
      deviceID: deviceID,
      buttonID: event.buttonID
    )
    _eventHandler(outputEvent)
  }
  
  private func _handleAxisMove(_ event: AxisEvent, deviceID: Core.USBDeviceID) async throws {
    let key = "\(deviceID.stringValue)_\(event.axisID.displayName)"
    let previousValue = _activeInputs[key].flatMap { Float($0 ? 1 : 0) } ?? event.value
    guard abs(event.value - previousValue) > 0.01 else { return }
    
    _activeInputs[key] = event.value > 0.01
    
    if let virtualDeviceID = _virtualDeviceIDs[deviceID] {
      try await _sendVirtualAxisMove(deviceID: virtualDeviceID, axis: event.axisID, value: event.value)
    }
    
    let outputEvent = OutputServiceEvent(
      type: .axisMoved,
      deviceID: deviceID,
      axisID: event.axisID,
      axisValue: event.value
    )
    _eventHandler(outputEvent)
  }
  
  private func _handleTriggerMove(_ event: TriggerEvent, deviceID: Core.USBDeviceID) async throws {
    let key = "\(deviceID.stringValue)_\(event.triggerID.displayName)"
    let previousValue = _activeInputs[key].flatMap { Float($0 ? 1 : 0) } ?? event.value
    guard abs(event.value - previousValue) > 0.01 else { return }
    
    _activeInputs[key] = event.isPressed
    
    if let virtualDeviceID = _virtualDeviceIDs[deviceID] {
      try await _sendVirtualTriggerMove(deviceID: virtualDeviceID, trigger: event.triggerID, value: event.value)
    }
    
    let outputEvent = OutputServiceEvent(
      type: .triggerMoved,
      deviceID: deviceID,
      triggerID: event.triggerID,
      triggerValue: event.value
    )
    _eventHandler(outputEvent)
  }
  
  private func _handleDPadMove(_ event: DPadEvent, deviceID: Core.USBDeviceID) async throws {
    let outputEvent = OutputServiceEvent(
      type: .dpadMoved,
      deviceID: deviceID,
      dpadHorizontal: event.horizontal,
      dpadVertical: event.vertical
    )
    _eventHandler(outputEvent)
  }
  
  private func _sendVirtualButtonPress(deviceID: UUID, button: ButtonIdentifier, isPressed: Bool) async throws {
    guard let virtualHIDService = _virtualHIDService else {
      throw OutputServiceError.virtualHIDNotAvailable
    }
    
    try await virtualHIDService.sendOutputReport(
      deviceID: deviceID,
      leftMotor: 0,
      rightMotor: 0
    )
  }
  
  private func _sendVirtualAxisMove(deviceID: UUID, axis: AxisIdentifier, value: Float) async throws {
  }
  
  private func _sendVirtualTriggerMove(deviceID: UUID, trigger: TriggerIdentifier, value: Float) async throws {
  }
  
  public func sendRumble(deviceID: Core.USBDeviceID, leftMotor: Float, rightMotor: Float) async throws {
    guard let virtualHIDService = _virtualHIDService else {
      throw OutputServiceError.virtualHIDNotAvailable
    }
    
    guard let virtualDeviceID = _virtualDeviceIDs[deviceID] else {
      throw OutputServiceError.deviceNotFound
    }
    
    try await virtualHIDService.sendOutputReport(
      deviceID: virtualDeviceID,
      leftMotor: leftMotor,
      rightMotor: rightMotor
    )
    
    let outputEvent = OutputServiceEvent(
      type: .rumbleSent,
      deviceID: deviceID,
      leftMotor: leftMotor,
      rightMotor: rightMotor
    )
    _eventHandler(outputEvent)
  }
  
  public func sendLED(deviceID: Core.USBDeviceID, pattern: LEDPattern) async throws {
    guard let virtualHIDService = _virtualHIDService else {
      throw OutputServiceError.virtualHIDNotAvailable
    }
    
    guard let virtualDeviceID = _virtualDeviceIDs[deviceID] else {
      throw OutputServiceError.deviceNotFound
    }
    
    try await virtualHIDService.sendOutputReport(
      deviceID: virtualDeviceID,
      leftMotor: 0,
      rightMotor: 0,
      ledPattern: pattern
    )
    
    let outputEvent = OutputServiceEvent(
      type: .ledSent,
      deviceID: deviceID,
      ledPattern: pattern
    )
    _eventHandler(outputEvent)
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

  public func getAllVirtualDeviceIDs() -> [Core.USBDeviceID] {
    Array(_virtualDeviceIDs.keys)
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
    public let buttonID: ButtonIdentifier?
    public let axisID: AxisIdentifier?
    public let axisValue: Float?
    public let triggerID: TriggerIdentifier?
    public let triggerValue: Float?
    public let dpadHorizontal: DPadDirection?
    public let dpadVertical: DPadDirection?
    public let leftMotor: Float?
    public let rightMotor: Float?
    public let ledPattern: LEDPattern?
    
    public init(
      type: EventType,
      keyCode: UInt16? = nil,
      modifier: KeyModifier? = nil,
      mouseButton: CGEventAdapter.MouseButton? = nil,
      clickCount: Int? = nil,
      scrollDeltaX: Double? = nil,
      scrollDeltaY: Double? = nil,
      deviceID: Core.USBDeviceID? = nil,
      buttonID: ButtonIdentifier? = nil,
      axisID: AxisIdentifier? = nil,
      axisValue: Float? = nil,
      triggerID: TriggerIdentifier? = nil,
      triggerValue: Float? = nil,
      dpadHorizontal: DPadDirection? = nil,
      dpadVertical: DPadDirection? = nil,
      leftMotor: Float? = nil,
      rightMotor: Float? = nil,
      ledPattern: LEDPattern? = nil
    ) {
      self.type = type
      self.keyCode = keyCode
      self.modifier = modifier
      self.mouseButton = mouseButton
      self.clickCount = clickCount
      self.scrollDeltaX = scrollDeltaX
      self.scrollDeltaY = scrollDeltaY
      self.deviceID = deviceID
      self.buttonID = buttonID
      self.axisID = axisID
      self.axisValue = axisValue
      self.triggerID = triggerID
      self.triggerValue = triggerValue
      self.dpadHorizontal = dpadHorizontal
      self.dpadVertical = dpadVertical
      self.leftMotor = leftMotor
      self.rightMotor = rightMotor
      self.ledPattern = ledPattern
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
    case buttonDown
    case buttonUp
    case axisMoved
    case triggerMoved
    case dpadMoved
    case rumbleSent
    case ledSent
    case virtualDeviceCreated
    case virtualDeviceDestroyed
    case outputError
  }
}

public enum OutputServiceError: Error, Sendable, Equatable {
  case virtualHIDNotAvailable
  case deviceNotFound
  case invalidOutput
  case transmissionFailed
}