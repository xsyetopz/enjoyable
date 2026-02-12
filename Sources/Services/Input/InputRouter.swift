import Configuration
import Core
import Foundation
import Protocol

public actor InputRouter {
  private var _deviceProfiles: [USBDeviceID: Profile] = [:]
  private var _buttonStates: [USBDeviceID: [String: Bool]] = [:]
  private let _eventHandler: @Sendable (InputRouterEvent) -> Void

  public init(
    eventHandler: @escaping @Sendable (InputRouterEvent) -> Void = { _ in }
  ) {
    self._eventHandler = eventHandler
  }

  public func registerDevice(deviceID: USBDeviceID, profile: Profile) async {
    _deviceProfiles[deviceID] = profile
    _buttonStates[deviceID] = [:]
  }

  public func unregisterDevice(deviceID: USBDeviceID) async {
    _deviceProfiles.removeValue(forKey: deviceID)
    _buttonStates.removeValue(forKey: deviceID)
  }

  public func updateProfile(deviceID: USBDeviceID, profile: Profile) async {
    _deviceProfiles[deviceID] = profile
  }

  public func parseInput(
    deviceID: USBDeviceID,
    report: [UInt8],
    profile: Profile
  ) async -> ParsedInput {
    var inputs: [InputState] = []

    let buttonMappings = profile.buttonMappings
    let maxButtonBits = report.count >= 2 ? (report.count - 2) * 8 : 0
    let buttonCount = min(maxButtonBits, 12)

    for i in 0..<buttonCount {
      let byteIndex = 2 + (i / 8)
      let bitIndex = i % 8

      guard byteIndex < report.count else {
        break
      }

      let isPressed = (report[byteIndex] >> bitIndex) & 0x01 == 0x01
      let buttonIdentifier = "Button_\(i)"

      let previousState = _buttonStates[deviceID]?[buttonIdentifier] ?? false

      if isPressed != previousState {
        let inputState = InputState(
          buttonIdentifier: buttonIdentifier,
          keyCode: Constants.KeyCode.unmapped,
          modifier: .none,
          isPressed: isPressed
        )
        inputs.append(inputState)

        _buttonStates[deviceID]?[buttonIdentifier] = isPressed
      }

      if let mapping = buttonMappings.first(where: { $0.buttonIdentifier == buttonIdentifier }) {
        if isPressed != previousState {
          let mappedInputState = InputState(
            buttonIdentifier: mapping.buttonIdentifier,
            keyCode: mapping.keyCode,
            modifier: mapping.modifier,
            isPressed: isPressed
          )
          inputs.append(mappedInputState)
        }
      }
    }

    let axisCount = 4
    for i in 0..<axisCount {
      let axisIndex = 2 + i
      guard axisIndex < report.count else {
        break
      }

      let axisValue = report[axisIndex]
      let axisIdentifier = "Axis_\(i)"

      let normalizedValue = Double(axisValue) / 255.0

      let inputState = InputState(
        buttonIdentifier: axisIdentifier,
        keyCode: Constants.KeyCode.unmapped,
        modifier: .none,
        isPressed: false,
        axisValue: normalizedValue
      )
      inputs.append(inputState)
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

  public func getButtonState(deviceID: USBDeviceID, buttonIdentifier: String) -> Bool {
    return _buttonStates[deviceID]?[buttonIdentifier] ?? false
  }

  public func resetButtonStates(for deviceID: USBDeviceID) async {
    _buttonStates[deviceID]?.removeAll()
  }

  public func getActiveDeviceIDs() -> [USBDeviceID] {
    Array(_deviceProfiles.keys)
  }

  public func getProfile(for deviceID: USBDeviceID) -> Profile? {
    _deviceProfiles[deviceID]
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
    public let input: ParsedInput?

    public init(
      type: EventType,
      input: ParsedInput? = nil
    ) {
      self.type = type
      self.input = input
    }
  }

  public enum EventType: Sendable {
    case inputParsed
    case routingError
  }
}
