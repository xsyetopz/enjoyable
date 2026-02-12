import Core
import Foundation

public struct ParsedInput: Sendable, Equatable {
  public let events: [InputEvent]
  public let timestamp: UInt64
  public let parserType: ParserType
  public let deviceInfo: DeviceInfo?

  public init(
    events: [InputEvent],
    timestamp: UInt64,
    parserType: ParserType,
    deviceInfo: DeviceInfo? = nil
  ) {
    self.events = events
    self.timestamp = timestamp
    self.parserType = parserType
    self.deviceInfo = deviceInfo
  }

  public var isEmpty: Bool { events.isEmpty }
  public var buttonEvents: [InputEvent] { events.filter { $0.isButtonEvent } }
  public var axisEvents: [InputEvent] { events.filter { $0.isAxisEvent } }
}

public enum ParserType: Sendable, Equatable {
  case hidDescriptor
  case xInput
  case gip
  case playStation
  case generic
  case unknown
}

public struct DeviceInfo: Sendable, Equatable, Codable {
  public let vendorID: UInt16?
  public let productID: UInt16?
  public let productName: String?
  public let manufacturerName: String?
  public let serialNumber: String?
  public let versionNumber: UInt16?

  public init(
    vendorID: UInt16? = nil,
    productID: UInt16? = nil,
    productName: String? = nil,
    manufacturerName: String? = nil,
    serialNumber: String? = nil,
    versionNumber: UInt16? = nil
  ) {
    self.vendorID = vendorID
    self.productID = productID
    self.productName = productName
    self.manufacturerName = manufacturerName
    self.serialNumber = serialNumber
    self.versionNumber = versionNumber
  }
}

public struct InputStateSnapshot: Sendable {
  public let buttonStates: [ButtonIdentifier: Bool]
  public let axisStates: [AxisIdentifier: Float]
  public let triggerStates: [TriggerIdentifier: Float]
  public let dpadStates: [Int: (DPadDirection, DPadDirection)]
  public let hatSwitchStates: [Int: HatSwitchAngle]
  public let timestamp: UInt64

  public init(
    buttonStates: [ButtonIdentifier: Bool] = [:],
    axisStates: [AxisIdentifier: Float] = [:],
    triggerStates: [TriggerIdentifier: Float] = [:],
    dpadStates: [Int: (DPadDirection, DPadDirection)] = [:],
    hatSwitchStates: [Int: HatSwitchAngle] = [:],
    timestamp: UInt64 = 0
  ) {
    self.buttonStates = buttonStates
    self.axisStates = axisStates
    self.triggerStates = triggerStates
    self.dpadStates = dpadStates
    self.hatSwitchStates = hatSwitchStates
    self.timestamp = timestamp
  }

  public static var empty: InputStateSnapshot {
    InputStateSnapshot()
  }

  public func buttonPressed(_ button: ButtonIdentifier) -> Bool {
    buttonStates[button] ?? false
  }

  public func axisValue(_ axis: AxisIdentifier) -> Float {
    axisStates[axis] ?? 0.0
  }

  public func triggerValue(_ trigger: TriggerIdentifier) -> Float {
    triggerStates[trigger] ?? 0.0
  }

  public func dpadState(dpadID: Int) -> (DPadDirection, DPadDirection) {
    dpadStates[dpadID] ?? (.neutral, .neutral)
  }

  public func hatSwitchAngle(hatID: Int) -> HatSwitchAngle {
    hatSwitchStates[hatID] ?? .neutral
  }

  public static func == (lhs: InputStateSnapshot, rhs: InputStateSnapshot) -> Bool {
    guard lhs.buttonStates.count == rhs.buttonStates.count,
      lhs.axisStates.count == rhs.axisStates.count,
      lhs.triggerStates.count == rhs.triggerStates.count,
      lhs.dpadStates.count == rhs.dpadStates.count,
      lhs.hatSwitchStates.count == rhs.hatSwitchStates.count
    else {
      return false
    }

    for (key, lhsValue) in lhs.buttonStates {
      guard rhs.buttonStates[key] == lhsValue else { return false }
    }
    for (key, lhsValue) in lhs.axisStates {
      guard rhs.axisStates[key] == lhsValue else { return false }
    }
    for (key, lhsValue) in lhs.triggerStates {
      guard rhs.triggerStates[key] == lhsValue else { return false }
    }
    for (key, lhsValue) in lhs.dpadStates {
      guard let rhsValue = rhs.dpadStates[key], rhsValue == lhsValue else { return false }
    }
    for (key, lhsValue) in lhs.hatSwitchStates {
      guard rhs.hatSwitchStates[key] == lhsValue else { return false }
    }

    return lhs.timestamp == rhs.timestamp
  }
}

public struct InputProcessingConfig: Sendable, Equatable {
  public let deadzone: Float
  public let sensitivity: Float
  public let triggerThreshold: Float
  public let stickButtonThreshold: Float
  public let timestampMultiplier: UInt64

  public init(
    deadzone: Float = 0.1,
    sensitivity: Float = 1.0,
    triggerThreshold: Float = 0.1,
    stickButtonThreshold: Float = 0.9,
    timestampMultiplier: UInt64 = 1_000_000
  ) {
    self.deadzone = deadzone
    self.sensitivity = sensitivity
    self.triggerThreshold = triggerThreshold
    self.stickButtonThreshold = stickButtonThreshold
    self.timestampMultiplier = timestampMultiplier
  }

  public static var `default`: InputProcessingConfig {
    InputProcessingConfig()
  }
}

public struct ParseResult: Sendable, Equatable {
  public let success: Bool
  public let events: [InputEvent]
  public let parserType: ParserType
  public let error: String?

  public init(success: Bool, events: [InputEvent], parserType: ParserType, error: String? = nil) {
    self.success = success
    self.events = events
    self.parserType = parserType
    self.error = error
  }

  public static func success(events: [InputEvent], parserType: ParserType) -> ParseResult {
    ParseResult(success: true, events: events, parserType: parserType, error: nil)
  }

  public static func failure(_ error: String) -> ParseResult {
    ParseResult(success: false, events: [], parserType: .unknown, error: error)
  }
}
