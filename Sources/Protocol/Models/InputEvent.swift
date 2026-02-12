import Core
import Foundation

public enum InputEvent: Sendable, Equatable, Hashable {
  case buttonPress(ButtonEvent)
  case buttonRelease(ButtonEvent)
  case axisMove(AxisEvent)
  case dpadMove(DPadEvent)
  case triggerMove(TriggerEvent)
  case hatSwitch(HatSwitchEvent)
}

public struct ButtonEvent: Sendable, Equatable, Codable, Hashable {
  public let buttonID: ButtonIdentifier
  public let isPressed: Bool
  public let timestamp: UInt64

  public init(buttonID: ButtonIdentifier, isPressed: Bool, timestamp: UInt64) {
    self.buttonID = buttonID
    self.isPressed = isPressed
    self.timestamp = timestamp
  }
}

public struct AxisEvent: Sendable, Equatable, Codable, Hashable {
  public let axisID: AxisIdentifier
  public let value: Float
  public let rawValue: Int16
  public let timestamp: UInt64

  public init(axisID: AxisIdentifier, value: Float, rawValue: Int16, timestamp: UInt64) {
    self.axisID = axisID
    self.value = value
    self.rawValue = rawValue
    self.timestamp = timestamp
  }
}

public struct DPadEvent: Sendable, Equatable, Codable, Hashable {
  public let dpadID: Int
  public let horizontal: DPadDirection
  public let vertical: DPadDirection
  public let timestamp: UInt64

  public init(dpadID: Int, horizontal: DPadDirection, vertical: DPadDirection, timestamp: UInt64) {
    self.dpadID = dpadID
    self.horizontal = horizontal
    self.vertical = vertical
    self.timestamp = timestamp
  }
}

public struct TriggerEvent: Sendable, Equatable, Codable, Hashable {
  public let triggerID: TriggerIdentifier
  public let value: Float
  public let rawValue: UInt8
  public let isPressed: Bool
  public let timestamp: UInt64

  public init(
    triggerID: TriggerIdentifier,
    value: Float,
    rawValue: UInt8,
    isPressed: Bool,
    timestamp: UInt64
  ) {
    self.triggerID = triggerID
    self.value = value
    self.rawValue = rawValue
    self.isPressed = isPressed
    self.timestamp = timestamp
  }
}

public struct HatSwitchEvent: Sendable, Equatable, Codable, Hashable {
  public let hatID: Int
  public let angle: HatSwitchAngle
  public let timestamp: UInt64

  public init(hatID: Int, angle: HatSwitchAngle, timestamp: UInt64) {
    self.hatID = hatID
    self.angle = angle
    self.timestamp = timestamp
  }
}

public enum ButtonIdentifier: Sendable, Equatable, Codable, Hashable {
  case a
  case b
  case x
  case y
  case leftShoulder
  case rightShoulder
  case leftTrigger
  case rightTrigger
  case leftStick
  case rightStick
  case start
  case back
  case guide
  case leftStickUp
  case leftStickDown
  case leftStickLeft
  case leftStickRight
  case rightStickUp
  case rightStickDown
  case rightStickLeft
  case rightStickRight
  case dpadUp
  case dpadDown
  case dpadLeft
  case dpadRight
  case custom(UInt8)

  public var displayName: String {
    switch self {
    case .a: return "A"
    case .b: return "B"
    case .x: return "X"
    case .y: return "Y"
    case .leftShoulder: return "LB"
    case .rightShoulder: return "RB"
    case .leftTrigger: return "LT"
    case .rightTrigger: return "RT"
    case .leftStick: return "L3"
    case .rightStick: return "R3"
    case .start: return "Start"
    case .back: return "Back"
    case .guide: return "Guide"
    case .leftStickUp: return "LS Up"
    case .leftStickDown: return "LS Down"
    case .leftStickLeft: return "LS Left"
    case .leftStickRight: return "LS Right"
    case .rightStickUp: return "RS Up"
    case .rightStickDown: return "RS Down"
    case .rightStickLeft: return "RS Left"
    case .rightStickRight: return "RS Right"
    case .dpadUp: return "DPad Up"
    case .dpadDown: return "DPad Down"
    case .dpadLeft: return "DPad Left"
    case .dpadRight: return "DPad Right"
    case .custom(let id): return "Button \(id)"
    }
  }
}

public enum AxisIdentifier: Sendable, Equatable, Codable, Hashable {
  case leftStickX
  case leftStickY
  case rightStickX
  case rightStickY
  case leftTrigger
  case rightTrigger
  case custom(UInt8)

  public var displayName: String {
    switch self {
    case .leftStickX: return "Left Stick X"
    case .leftStickY: return "Left Stick Y"
    case .rightStickX: return "Right Stick X"
    case .rightStickY: return "Right Stick Y"
    case .leftTrigger: return "Left Trigger"
    case .rightTrigger: return "Right Trigger"
    case .custom(let id): return "Axis \(id)"
    }
  }
}

public enum TriggerIdentifier: Sendable, Equatable, Codable, Hashable {
  case left
  case right
  case custom(UInt8)

  public var displayName: String {
    switch self {
    case .left: return "Left Trigger"
    case .right: return "Right Trigger"
    case .custom(let id): return "Trigger \(id)"
    }
  }
}

public enum DPadDirection: Sendable, Equatable, Codable, Hashable {
  case neutral
  case up
  case upRight
  case right
  case downRight
  case down
  case downLeft
  case left
  case upLeft

  public var isPressed: Bool { self != .neutral }

  public var horizontalValue: Int8 {
    switch self {
    case .neutral, .up, .down: return 0
    case .upLeft, .left, .downLeft: return -1
    case .upRight, .right, .downRight: return 1
    }
  }

  public var verticalValue: Int8 {
    switch self {
    case .neutral, .left, .right: return 0
    case .upLeft, .up, .upRight: return 1
    case .downLeft, .down, .downRight: return -1
    }
  }
}

public enum HatSwitchAngle: Sendable, Equatable, Codable, Hashable {
  case neutral
  case up
  case upRight
  case right
  case downRight
  case down
  case downLeft
  case left
  case upLeft

  public var angleDegrees: UInt16 {
    switch self {
    case .neutral: return 0
    case .up: return 0
    case .upRight: return 45
    case .right: return 90
    case .downRight: return 135
    case .down: return 180
    case .downLeft: return 225
    case .left: return 270
    case .upLeft: return 315
    }
  }

  public static func fromValue(_ value: UInt8) -> HatSwitchAngle {
    switch value & 0x0F {
    case 0: return .neutral
    case 1: return .upRight
    case 2: return .right
    case 3: return .downRight
    case 4: return .down
    case 5: return .downLeft
    case 6: return .left
    case 7: return .upLeft
    default: return .neutral
    }
  }
}

extension InputEvent {
  public var timestamp: UInt64 {
    switch self {
    case .buttonPress(let event): return event.timestamp
    case .buttonRelease(let event): return event.timestamp
    case .axisMove(let event): return event.timestamp
    case .dpadMove(let event): return event.timestamp
    case .triggerMove(let event): return event.timestamp
    case .hatSwitch(let event): return event.timestamp
    }
  }

  public var isButtonEvent: Bool {
    switch self {
    case .buttonPress, .buttonRelease: return true
    default: return false
    }
  }

  public var isAxisEvent: Bool {
    switch self {
    case .axisMove, .triggerMove: return true
    default: return false
    }
  }
}

extension ButtonIdentifier {
  public static var allCases: [ButtonIdentifier] {
    [
      .a, .b, .x, .y, .leftShoulder, .rightShoulder, .leftTrigger, .rightTrigger,
      .leftStick, .rightStick, .start, .back, .guide,
      .leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight,
      .rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight,
      .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
    ]
  }
}

extension AxisIdentifier {
  public static var allCases: [AxisIdentifier] {
    [.leftStickX, .leftStickY, .rightStickX, .rightStickY, .leftTrigger, .rightTrigger]
  }
}

extension TriggerIdentifier {
  public static var allCases: [TriggerIdentifier] {
    [.left, .right]
  }
}
