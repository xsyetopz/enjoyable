import Core
import Foundation

public struct HIDReportDescriptor: Sendable, Equatable, Codable {
  public let items: [HIDItem]
  public let reportSize: Int
  public let reportCount: Int

  public init(items: [HIDItem], reportSize: Int = 8, reportCount: Int = 1) {
    self.items = items
    self.reportSize = reportSize
    self.reportCount = reportCount
  }

  public var byteLength: Int {
    (reportSize * reportCount + 7) / 8
  }

  public func generateReport(data: [UInt8]) -> [UInt8] {
    var report = [UInt8](repeating: 0, count: byteLength)
    for (index, byte) in data.prefix(byteLength).enumerated() {
      report[index] = byte
    }
    return report
  }
}

public struct HIDItem: Sendable, Equatable, Codable {
  public let type: HIDItemType
  public let tag: UInt8
  public let data: Data?

  public init(type: HIDItemType, tag: UInt8, data: Data? = nil) {
    self.type = type
    self.tag = tag
    self.data = data
  }

  public var bytes: [UInt8] {
    var result: [UInt8] = []
    let typeValue = UInt8(type.rawValue << 2)
    let sizeIndicator = UInt8(data != nil ? 0x02 : 0x00)
    let firstByte = UInt8(typeValue | sizeIndicator | (tag & 0x03))
    result.append(firstByte)

    if let data = data {
      result.append(contentsOf: data)
    }

    return result
  }
}

public enum HIDItemType: UInt8, Sendable, Equatable, Codable {
  case main = 0x00
  case global = 0x01
  case local = 0x02
  case reserved = 0x03

  public init(rawValue: UInt8) {
    switch rawValue {
    case 0x00...0x0F: self = .main
    case 0x10...0x1F: self = .global
    case 0x20...0x2F: self = .local
    default: self = .reserved
    }
  }
}

public enum HIDMainItemTag: UInt8, Sendable, Equatable, Codable {
  case input = 0x81
  case output = 0x91
  case feature = 0xB1
  case collection = 0xA1
  case endCollection = 0xC0

  public init(rawValue: UInt8) {
    switch rawValue {
    case 0x81: self = .input
    case 0x91: self = .output
    case 0xB1: self = .feature
    case 0xA1: self = .collection
    case 0xC0: self = .endCollection
    default: self = .input
    }
  }
}

public enum HIDGlobalItemTag: UInt8, Sendable, Equatable, Codable {
  case usagePage = 0x01
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

  public init(rawValue: UInt8) {
    switch rawValue {
    case 0x01: self = .usagePage
    case 0x15: self = .logicalMinimum
    case 0x25: self = .logicalMaximum
    case 0x35: self = .physicalMinimum
    case 0x45: self = .physicalMaximum
    case 0x55: self = .unitExponent
    case 0x65: self = .unit
    case 0x75: self = .reportSize
    case 0x85: self = .reportID
    case 0x95: self = .reportCount
    case 0xA4: self = .push
    case 0xB4: self = .pop
    default: self = .usagePage
    }
  }
}

public enum HIDLocalItemTag: UInt8, Sendable, Equatable, Codable {
  case usage = 0x09
  case usageMinimum = 0x19
  case usageMaximum = 0x29
  case designatorIndex = 0x39
  case designatorMinimum = 0x49
  case designatorMaximum = 0x59
  case stringIndex = 0x79
  case stringMinimum = 0x89
  case stringMaximum = 0x99
  case delimiter = 0xA9

  public init(rawValue: UInt8) {
    switch rawValue {
    case 0x09: self = .usage
    case 0x19: self = .usageMinimum
    case 0x29: self = .usageMaximum
    case 0x39: self = .designatorIndex
    case 0x49: self = .designatorMinimum
    case 0x59: self = .designatorMaximum
    case 0x79: self = .stringIndex
    case 0x89: self = .stringMinimum
    case 0x99: self = .stringMaximum
    case 0xA9: self = .delimiter
    default: self = .usage
    }
  }
}

public struct HIDFieldFlags: Sendable, Equatable {
  public let isConstant: Bool
  public let isVariable: Bool
  public let isRelative: Bool
  public let isWrap: Bool
  public let isNonLinear: Bool
  public let noPreferred: Bool
  public let hasNullPosition: Bool
  public let volatile: Bool

  public init(
    isConstant: Bool = false,
    isVariable: Bool = true,
    isRelative: Bool = false,
    isWrap: Bool = false,
    isNonLinear: Bool = false,
    noPreferred: Bool = false,
    hasNullPosition: Bool = false,
    volatile: Bool = false
  ) {
    self.isConstant = isConstant
    self.isVariable = isVariable
    self.isRelative = isRelative
    self.isWrap = isWrap
    self.isNonLinear = isNonLinear
    self.noPreferred = noPreferred
    self.hasNullPosition = hasNullPosition
    self.volatile = volatile
  }

  public var value: UInt8 {
    var flags: UInt8 = 0
    if isConstant { flags |= 0x01 }
    if isVariable { flags |= 0x02 }
    if isRelative { flags |= 0x04 }
    if isWrap { flags |= 0x08 }
    if isNonLinear { flags |= 0x10 }
    if noPreferred { flags |= 0x20 }
    if hasNullPosition { flags |= 0x40 }
    if volatile { flags |= 0x80 }
    return flags
  }
}
