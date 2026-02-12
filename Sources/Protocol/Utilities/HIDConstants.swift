import Core
import Foundation

public enum HIDUsagePage: UInt16, Sendable, Equatable, Codable {
  case genericDesktop = 0x01
  case gameControls = 0x05
  case keyboard = 0x07
  case leds = 0x08
  case button = 0x09
  case consumer = 0x0C

  public init(rawValue: UInt16) {
    switch rawValue {
    case 0x01: self = .genericDesktop
    case 0x05: self = .gameControls
    case 0x07: self = .keyboard
    case 0x08: self = .leds
    case 0x09: self = .button
    case 0x0C: self = .consumer
    default: self = .genericDesktop
    }
  }
}

public enum HIDGenericDesktopUsage: UInt16, Sendable, Equatable, Codable {
  case pointer = 0x01
  case mouse = 0x02
  case joystick = 0x04
  case gamePad = 0x05
  case keyboard = 0x06
  case keypad = 0x07
  case x = 0x30
  case y = 0x31
  case z = 0x32
  case rx = 0x33
  case ry = 0x34
  case rz = 0x35
  case slider = 0x36
  case dial = 0x37
  case wheel = 0x38
  case hatSwitch = 0x39
  case start = 0x3D
  case select = 0x3E

  public init(rawValue: UInt16) {
    switch rawValue {
    case 0x01: self = .pointer
    case 0x02: self = .mouse
    case 0x04: self = .joystick
    case 0x05: self = .gamePad
    case 0x06: self = .keyboard
    case 0x07: self = .keypad
    case 0x30: self = .x
    case 0x31: self = .y
    case 0x32: self = .z
    case 0x33: self = .rx
    case 0x34: self = .ry
    case 0x35: self = .rz
    case 0x36: self = .slider
    case 0x37: self = .dial
    case 0x38: self = .wheel
    case 0x39: self = .hatSwitch
    case 0x3D: self = .start
    case 0x3E: self = .select
    default: self = .pointer
    }
  }
}

public enum HIDCollectionType: UInt8, Sendable, Equatable, Codable {
  case physical = 0x00
  case application = 0x01
  case logical = 0x02
  case report = 0x03
  case namedArray = 0x04
  case usageSwitch = 0x05
  case usageModifier = 0x06

  public init(rawValue: UInt8) {
    switch rawValue {
    case 0x00: self = .physical
    case 0x01: self = .application
    case 0x02: self = .logical
    case 0x03: self = .report
    case 0x04: self = .namedArray
    case 0x05: self = .usageSwitch
    case 0x06: self = .usageModifier
    default: self = .physical
    }
  }
}

public struct ButtonMapping: Sendable, Equatable {
  public let usagePage: HIDUsagePage
  public let usage: UInt16
  public let buttonID: ButtonIdentifier

  public init(usagePage: HIDUsagePage, usage: UInt16, buttonID: ButtonIdentifier) {
    self.usagePage = usagePage
    self.usage = usage
    self.buttonID = buttonID
  }

  public static let standardMappings: [ButtonMapping] = [
    ButtonMapping(usagePage: .button, usage: 1, buttonID: .a),
    ButtonMapping(usagePage: .button, usage: 2, buttonID: .b),
    ButtonMapping(usagePage: .button, usage: 3, buttonID: .x),
    ButtonMapping(usagePage: .button, usage: 4, buttonID: .y),
    ButtonMapping(usagePage: .button, usage: 5, buttonID: .leftShoulder),
    ButtonMapping(usagePage: .button, usage: 6, buttonID: .rightShoulder),
    ButtonMapping(usagePage: .button, usage: 7, buttonID: .leftTrigger),
    ButtonMapping(usagePage: .button, usage: 8, buttonID: .rightTrigger),
    ButtonMapping(usagePage: .button, usage: 9, buttonID: .back),
    ButtonMapping(usagePage: .button, usage: 10, buttonID: .start),
    ButtonMapping(usagePage: .button, usage: 11, buttonID: .leftStick),
    ButtonMapping(usagePage: .button, usage: 12, buttonID: .rightStick),
    ButtonMapping(usagePage: .genericDesktop, usage: 0x3D, buttonID: .start),
    ButtonMapping(usagePage: .genericDesktop, usage: 0x3E, buttonID: .back),
  ]
}

public struct AxisMapping: Sendable, Equatable {
  public let usagePage: HIDUsagePage
  public let usage: UInt16
  public let axisID: AxisIdentifier

  public init(usagePage: HIDUsagePage, usage: UInt16, axisID: AxisIdentifier) {
    self.usagePage = usagePage
    self.usage = usage
    self.axisID = axisID
  }

  public static let standardMappings: [AxisMapping] = [
    AxisMapping(usagePage: .genericDesktop, usage: 0x30, axisID: .leftStickX),
    AxisMapping(usagePage: .genericDesktop, usage: 0x31, axisID: .leftStickY),
    AxisMapping(usagePage: .genericDesktop, usage: 0x32, axisID: .leftTrigger),
    AxisMapping(usagePage: .genericDesktop, usage: 0x33, axisID: .rightStickX),
    AxisMapping(usagePage: .genericDesktop, usage: 0x34, axisID: .rightStickY),
    AxisMapping(usagePage: .genericDesktop, usage: 0x35, axisID: .rightTrigger),
    AxisMapping(usagePage: .genericDesktop, usage: 0x36, axisID: .custom(0)),
    AxisMapping(usagePage: .genericDesktop, usage: 0x37, axisID: .custom(1)),
  ]
}

public struct TriggerMapping: Sendable, Equatable {
  public let usagePage: HIDUsagePage
  public let usage: UInt16
  public let triggerID: TriggerIdentifier

  public init(usagePage: HIDUsagePage, usage: UInt16, triggerID: TriggerIdentifier) {
    self.usagePage = usagePage
    self.usage = usage
    self.triggerID = triggerID
  }

  public static let standardMappings: [TriggerMapping] = [
    TriggerMapping(usagePage: .genericDesktop, usage: 0x32, triggerID: .left),
    TriggerMapping(usagePage: .genericDesktop, usage: 0x35, triggerID: .right),
  ]
}

public enum ReportFormatConstants {
  public static let minimumReportSize = 8
  public static let maximumReportSize = 64

  public static let xInputReportSize = 20
  public static let gipReportSize = 16
  public static let playStationReportSize = 8

  public enum ButtonMasks {
    public static let a: UInt8 = 0x01
    public static let b: UInt8 = 0x02
    public static let x: UInt8 = 0x04
    public static let y: UInt8 = 0x08
    public static let leftShoulder: UInt8 = 0x10
    public static let rightShoulder: UInt8 = 0x20
    public static let back: UInt8 = 0x40
    public static let start: UInt8 = 0x80
  }

  public enum Normalization {
    public static let signedMax = 32767.0
    public static let unsignedMax = 255.0
    public static let triggerThreshold = 0.1
    public static let stickButtonThreshold = 0.9
    public static let deadzone = 0.01
  }

  public enum Timestamp {
    public static let multiplier: UInt64 = 1_000_000
  }
}

public enum GamepadVendorID: UInt16, Sendable {
  case microsoft = 0x045E
  case sony = 0x054C
  case nintendo = 0x057E
  case logitech = 0x046D
  case razer = 0x1532
  case steam = 0x28DE
  case madCatz = 0x0738
}

public enum GamepadProductID: UInt16, Sendable {
  // Microsoft Xbox controllers
  case xbox360Wireless = 0x0719
  case xbox360Wired = 0x028E
  case xboxOneWireless = 0x02DD
  case xboxOneWired = 0x02FD
  case xboxSeriesX = 0x0B13

  // Sony PlayStation controllers
  case dualShock4 = 0x09CC
  case dualShock4USB = 0x05C5
  case dualSense = 0x0CE6

  // Nintendo controllers
  case switchProController = 0x2009
  case switchJoyConL = 0x2006
  case switchJoyConR = 0x2007

  // Third-party controllers
  case logitechF310 = 0xC21D
  case logitechF710 = 0xC21F
  case razerWolverine = 0x0221
  case steamController = 0x11FF
}
