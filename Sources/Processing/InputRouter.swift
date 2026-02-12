import Configuration
import Core
import Foundation
import Protocol

public actor InputRouter {
  private var _deviceProfiles: [USBDeviceID: Profile] = [:]
  private var _deviceConfigurations: [USBDeviceID: DeviceConfiguration] = [:]
  private var _buttonStates: [USBDeviceID: [String: Bool]] = [:]
  private var _axisStates: [USBDeviceID: [AxisIdentifier: Float]] = [:]
  private var _parsers: [USBDeviceID: HIDReportParser] = [:]
  private var _inputProcessor: InputProcessor?
  private let _eventHandler: @Sendable (InputRouterEvent) -> Void
  
  public init(
    inputProcessor: InputProcessor? = nil,
    eventHandler: @escaping @Sendable (InputRouterEvent) -> Void = { _ in }
  ) {
    self._inputProcessor = inputProcessor
    self._eventHandler = eventHandler
  }
  
  public func registerDevice(deviceID: USBDeviceID, profile: Profile, configuration: DeviceConfiguration?) async {
    _deviceProfiles[deviceID] = profile
    _buttonStates[deviceID] = [:]
    _axisStates[deviceID] = [:]
    
    if let configuration = configuration {
      _deviceConfigurations[deviceID] = configuration
      _setupParser(for: deviceID, configuration: configuration)
    }
    
    let event = InputRouterEvent(
      type: .deviceRegistered,
      deviceID: deviceID,
      message: "Registered device \(deviceID.stringValue) with profile"
    )
    _eventHandler(event)
  }
  
  private func _setupParser(for deviceID: USBDeviceID, configuration: DeviceConfiguration) {
    let parser = HIDReportParser()
    
    if let reportDescriptor = configuration.reportDescriptor.fields, !reportDescriptor.isEmpty {
      let configDescriptor = ConfigReportDescriptor(
        reportSize: configuration.reportDescriptor.reportSize,
        fields: reportDescriptor
      )
      parser.configure(with: configDescriptor)
    }
    
    _parsers[deviceID] = parser
  }
  
  public func unregisterDevice(deviceID: USBDeviceID) async {
    _deviceProfiles.removeValue(forKey: deviceID)
    _deviceConfigurations.removeValue(forKey: deviceID)
    _buttonStates.removeValue(forKey: deviceID)
    _axisStates.removeValue(forKey: deviceID)
    _parsers.removeValue(forKey: deviceID)
    
    let event = InputRouterEvent(
      type: .deviceUnregistered,
      deviceID: deviceID,
      message: "Unregistered device \(deviceID.stringValue)"
    )
    _eventHandler(event)
  }
  
  public func updateProfile(deviceID: USBDeviceID, profile: Profile) async {
    _deviceProfiles[deviceID] = profile
  }
  
  public func updateConfiguration(deviceID: USBDeviceID, configuration: DeviceConfiguration) async {
    _deviceConfigurations[deviceID] = configuration
    _setupParser(for: deviceID, configuration: configuration)
  }
  
  public func processInput(
    deviceID: USBDeviceID,
    report: [UInt8],
    profile: Profile
  ) async -> [InputEvent] {
    var events: [InputEvent] = []
    
    guard let parser = _parsers[deviceID] else {
      let errorEvent = InputRouterEvent(
        type: .routingError,
        deviceID: deviceID,
        error: InputRouterError.noParserForDevice,
        message: "No parser found for device \(deviceID.stringValue)"
      )
      _eventHandler(errorEvent)
      return events
    }
    
    let reportData = Data(report)
    let parsedEvents = parser.parse(report: reportData)
    
    for var event in parsedEvents {
      if let configuration = _deviceConfigurations[deviceID] {
        event = await _processEvent(event, deviceID: deviceID, configuration: configuration)
      }
      
      events.append(event)
    }
    
    if !events.isEmpty {
      let routingEvent = InputRouterEvent(
        type: .inputRouted,
        deviceID: deviceID,
        eventCount: events.count,
        message: "Routed \(events.count) events from device \(deviceID.stringValue)"
      )
      _eventHandler(routingEvent)
    }
    
    return events
  }
  
  private func _processEvent(_ event: InputEvent, deviceID: USBDeviceID, configuration: DeviceConfiguration) async -> InputEvent {
    if let processor = _inputProcessor {
      switch event {
      case .axisMove(let axisEvent):
        return await processor.processAxisEvent(axisEvent, configuration: configuration)
      case .triggerMove(let triggerEvent):
        return await processor.processTriggerEvent(triggerEvent, configuration: configuration)
      default:
        break
      }
    }
    
    return event
  }
  
  public func parseInput(
    deviceID: USBDeviceID,
    report: [UInt8],
    profile: Profile
  ) async -> ParsedInput {
    var inputs: [InputState] = []
    
    guard let parser = _parsers[deviceID] else {
      return ParsedInput(
        deviceID: deviceID,
        timestamp: Date(),
        inputs: inputs
      )
    }
    
    let reportData = Data(report)
    let events = parser.parse(report: reportData)
    
    let buttonMappings = profile.buttonMappings
    
    for event in events {
      switch event {
      case .buttonPress(let buttonEvent), .buttonRelease(let buttonEvent):
        let inputState = _createInputState(from: buttonEvent, deviceID: deviceID, profile: profile)
        inputs.append(inputState)
        
      case .axisMove(let axisEvent):
        let inputState = _createAxisInputState(from: axisEvent, deviceID: deviceID, profile: profile)
        inputs.append(inputState)
        
      case .triggerMove(let triggerEvent):
        let inputState = _createTriggerInputState(from: triggerEvent, deviceID: deviceID, profile: profile)
        inputs.append(inputState)
        
      case .dpadMove(let dpadEvent):
        let inputState = _createDPadInputState(from: dpadEvent, deviceID: deviceID, profile: profile)
        inputs.append(inputState)
        
      default:
        break
      }
    }
    
    let parsedInput = ParsedInput(
      deviceID: deviceID,
      timestamp: Date(),
      inputs: inputs
    )
    
    let event = InputRouterEvent(
      type: .inputParsed,
      input: parsedInput
    )
    _eventHandler(event)
    
    return parsedInput
  }
  
  private func _createInputState(from buttonEvent: ButtonEvent, deviceID: USBDeviceID, profile: Profile) -> InputState {
    let buttonIdentifier = buttonEvent.buttonID.displayName
    let previousState = _buttonStates[deviceID]?[buttonIdentifier] ?? false
    
    if buttonEvent.isPressed != previousState {
      _buttonStates[deviceID]?[buttonIdentifier] = buttonEvent.isPressed
    }
    
    let mapping = profile.buttonMappings.first { $0.buttonIdentifier == buttonIdentifier }
    
    return InputState(
      buttonIdentifier: buttonIdentifier,
      keyCode: mapping?.keyCode ?? Constants.KeyCode.unmapped,
      modifier: mapping?.modifier ?? .none,
      isPressed: buttonEvent.isPressed
    )
  }
  
  private func _createAxisInputState(from axisEvent: AxisEvent, deviceID: USBDeviceID, profile: Profile) -> InputState {
    let axisIdentifier = axisEvent.axisID.displayName
    _axisStates[deviceID]?[axisEvent.axisID] = axisEvent.value
    
    let mapping = profile.axisMappings.first { $0.axisIdentifier == axisIdentifier }
    
    return InputState(
      buttonIdentifier: axisIdentifier,
      keyCode: mapping?.keyCode ?? Constants.KeyCode.unmapped,
      modifier: mapping?.modifier ?? .none,
      isPressed: false,
      axisValue: axisEvent.value
    )
  }
  
  private func _createTriggerInputState(from triggerEvent: TriggerEvent, deviceID: USBDeviceID, profile: Profile) -> InputState {
    let triggerIdentifier = triggerEvent.triggerID.displayName
    let mapping = profile.buttonMappings.first { $0.buttonIdentifier == triggerIdentifier }
    
    return InputState(
      buttonIdentifier: triggerIdentifier,
      keyCode: mapping?.keyCode ?? Constants.KeyCode.unmapped,
      modifier: mapping?.modifier ?? .none,
      isPressed: triggerEvent.isPressed,
      axisValue: triggerEvent.value
    )
  }
  
  private func _createDPadInputState(from dpadEvent: DPadEvent, deviceID: USBDeviceID, profile: Profile) -> InputState {
    let dpadIdentifier = "DPad_\(dpadEvent.horizontal.displayName)_\(dpadEvent.vertical.displayName)"
    let isPressed = dpadEvent.horizontal.isPressed || dpadEvent.vertical.isPressed
    
    return InputState(
      buttonIdentifier: dpadIdentifier,
      keyCode: Constants.KeyCode.unmapped,
      modifier: .none,
      isPressed: isPressed
    )
  }
  
  public func getButtonState(deviceID: USBDeviceID, buttonIdentifier: String) -> Bool {
    return _buttonStates[deviceID]?[buttonIdentifier] ?? false
  }
  
  public func getAxisState(deviceID: USBDeviceID, axis: AxisIdentifier) -> Float? {
    return _axisStates[deviceID]?[axis]
  }
  
  public func resetButtonStates(for deviceID: USBDeviceID) async {
    _buttonStates[deviceID]?.removeAll()
    _axisStates[deviceID]?.removeAll()
  }
  
  public func getActiveDeviceIDs() -> [USBDeviceID] {
    Array(_deviceProfiles.keys)
  }
  
  public func getProfile(for deviceID: USBDeviceID) -> Profile? {
    _deviceProfiles[deviceID]
  }
  
  public func getConfiguration(for deviceID: USBDeviceID) -> DeviceConfiguration? {
    _deviceConfigurations[deviceID]
  }
}

extension InputRouter {
  public struct ParsedInput: Sendable {
    public let deviceID: USBDeviceID
    public let timestamp: Date
    public let inputs: [InputState]
    
    public init(
      deviceID: USBDeviceID,
      timestamp: Date,
      inputs: [InputState]
    ) {
      self.deviceID = deviceID
      self.timestamp = timestamp
      self.inputs = inputs
    }
  }
  
  public struct InputState: Sendable {
    public let buttonIdentifier: String
    public let keyCode: UInt16
    public let modifier: KeyModifier
    public let isPressed: Bool
    public let axisValue: Double?
    
    public init(
      buttonIdentifier: String,
      keyCode: UInt16,
      modifier: KeyModifier,
      isPressed: Bool,
      axisValue: Double? = nil
    ) {
      self.buttonIdentifier = buttonIdentifier
      self.keyCode = keyCode
      self.modifier = modifier
      self.isPressed = isPressed
      self.axisValue = axisValue
    }
  }
}

extension InputRouter {
  public struct InputRouterEvent: Sendable {
    public let type: EventType
    public let deviceID: USBDeviceID?
    public let input: ParsedInput?
    public let eventCount: Int?
    public let error: (any Error)?
    public let message: String
    
    public init(
      type: EventType,
      deviceID: USBDeviceID? = nil,
      input: ParsedInput? = nil,
      eventCount: Int? = nil,
      error: (any Error)? = nil,
      message: String = ""
    ) {
      self.type = type
      self.deviceID = deviceID
      self.input = input
      self.eventCount = eventCount
      self.error = error
      self.message = message
    }
  }
  
  public enum EventType: Sendable {
    case deviceRegistered
    case deviceUnregistered
    case inputParsed
    case inputRouted
    case routingError
  }
}

public enum InputRouterError: Error, Sendable, Equatable {
  case noParserForDevice
  case invalidReportFormat
  case processingFailed
}