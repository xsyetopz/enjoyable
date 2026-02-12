import Foundation

public enum HIDUsagePageTag: UInt8 {
  case genericDesktop = 0x01
  case gameControls = 0x05
  case button = 0x09
  case pid = 0x0F
}

public enum HIDGenericDesktopUsage: UInt8 {
  case pointer = 0x01
  case mouse = 0x02
  case joystick = 0x04
  case gamePad = 0x05
  case keyboard = 0x06
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
  case vx = 0x40
  case vy = 0x41
  case vz = 0x42
  case vbrx = 0x43
  case vbry = 0x44
  case vbrz = 0x45
  case vno = 0x46
  case systemControl = 0x80
  case powerDown = 0x81
  case sleep = 0x82
  case wakeUp = 0x83
  case rightArrow = 0xE0
  case leftArrow = 0xE1
  case upArrow = 0xE2
  case downArrow = 0xE3
}

public enum HIDButtonUsage: UInt8 {
  case button1 = 0x01
  case button2 = 0x02
  case button3 = 0x03
  case button4 = 0x04
  case button5 = 0x05
  case button6 = 0x06
  case button7 = 0x07
  case button8 = 0x08
  case button9 = 0x09
  case button10 = 0x0A
  case button11 = 0x0B
  case button12 = 0x0C
  case button13 = 0x0D
  case button14 = 0x0E
  case button15 = 0x0F
  case button16 = 0x10
}

public enum HIDPIDUsage: UInt8 {
  case physicalInterfaceDevice = 0x21
  case normal = 0x22
  case setEffectReport = 0x23
  case effectBlockIndex = 0x24
  case deviceManaged = 0x25
}

public enum HIDCollectionTag: UInt8 {
  case physical = 0x00
  case application = 0x01
  case logical = 0x02
  case report = 0x03
  case namedArray = 0x04
  case usageSwitch = 0x05
  case usageModifier = 0x06
  case end = 0xC0
}

public enum HIDInputOutputTag: UInt8 {
  case dataVarAbs = 0x02
  case constVarAbs = 0x42
  case dataVarRel = 0x06
}

public enum HIDGlobalTag: UInt8 {
  case logicalMinimum = 0x15
  case logicalMaximum = 0x25
  case physicalMinimum = 0x35
  case physicalMaximum = 0x45
  case unitExponent = 0x55
  case unit = 0x65
  case reportSize = 0x75
  case reportID = 0x85
  case reportCount = 0x95
  case push = 0xA4
  case pop = 0xB4
}

public enum HIDLocalTag: UInt8 {
  case usage = 0x09
  case usageMinimum = 0x19
  case usageMaximum = 0x29
}

public enum XboxControllerReport {
  public static let reportID: UInt8 = 0x00

  public static let buttonStateBits: Int = 16

  public static let axisValueBytes: Int = 4
  public static let triggerValueBytes: Int = 2

  public static let reportSize: Int = 20

  public enum LEDPattern {
    public static let off: UInt8 = 0x00
    public static let on: UInt8 = 0x01
    public static let blinkFast: UInt8 = 0x02
    public static let blinkSlow: UInt8 = 0x03
    public static let player1: UInt8 = 0x04
    public static let player2: UInt8 = 0x05
    public static let player3: UInt8 = 0x06
    public static let player4: UInt8 = 0x07
    public static let breathing: UInt8 = 0x0A
    public static let custom: UInt8 = 0x0B
  }

  public enum Rumble {
    public static let reportID: UInt8 = 0x00
    public static let leftMotorOffset: Int = 1
    public static let rightMotorOffset: Int = 2
    public static let reservedOffset: Int = 3
  }
}

public enum ModifierKeyConstants {
  public static let command: UInt16 = 0x37
  public static let control: UInt16 = 0x3B
  public static let option: UInt16 = 0x3A
  public static let shift: UInt16 = 0x38
  public static let capsLock: UInt16 = 0x39
}
