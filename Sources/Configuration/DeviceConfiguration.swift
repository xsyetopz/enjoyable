import Foundation

public enum ProtocolType: String, Codable, CaseIterable {
  case xinput = "xinput"
  case gip = "gip"
  case hid = "hid"
  case ds4 = "ds4"
}

public struct DeviceInterface: Codable, Equatable {
  let number: Int
  let classCode: UInt8?
  let subclass: UInt8?
  let protocolCode: UInt8?

  enum CodingKeys: String, CodingKey {
    case number
    case classCode = "class"
    case subclass
    case protocolCode = "protocol"
  }
}

public struct DeviceInfo: Codable, Equatable {
  public let vendorId: Int
  public let productId: Int
  public let name: String
  public let revision: String?
  let serialNumber: String?
  let interfaces: [DeviceInterface]?

  init(vendorId: Int, productId: Int, name: String = "Unknown Device") {
    self.vendorId = vendorId
    self.productId = productId
    self.name = name
    self.revision = nil
    self.serialNumber = nil
    self.interfaces = nil
  }
}

public enum InitStepType: String, Codable {
  case control = "control"
  case interrupt = "interrupt"
  case bulk = "bulk"
  case gip = "gip"
}

public enum DataTransferDirection: String, Codable {
  case inOut = "in"
  case out = "out"
}

public struct InitStep: Codable, Equatable {
  public let description: String
  public let type: InitStepType
  public let requestType: Int?
  public let request: Int?
  public let value: Int?
  public let index: Int?
  public let data: String?
  public let direction: DataTransferDirection?
  public let endpoint: Int?
  public let length: Int?
  public let timeout: Int?
  public let command: String?

  public var dataBytes: Data? {
    guard let dataString = data else { return nil }
    var bytes = [UInt8]()
    var hexString = dataString.trimmingCharacters(in: .whitespacesAndNewlines)
    if hexString.hasPrefix("0x") {
      hexString = String(hexString.dropFirst(2))
    }
    var index = hexString.startIndex
    while index < hexString.endIndex {
      let end =
        hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex) ?? hexString.endIndex
      if let byte = UInt8(hexString[index..<end], radix: 16) {
        bytes.append(byte)
      }
      index = end
    }
    return Data(bytes)
  }
}

enum FieldType: String, Codable {
  case unsigned = "unsigned"
  case signed = "signed"
  case bitfield = "bitfield"
  case boolean = "boolean"
}

struct ReportField: Codable, Equatable {
  let name: String
  let byte: Int
  let bitOffset: Int
  let bitLength: Int
  let type: FieldType
}

public struct ReportDescriptor: Codable, Equatable {
  let reportSize: Int
  let fields: [ReportField]

  func field(named name: String) -> ReportField? {
    return fields.first { $0.name == name }
  }
}

struct ConfigButtonMapping: Codable, Equatable {
  let buttonName: String
  let bitPosition: Int?
  let byte: Int?
  let bitOffset: Int?
  let bitLength: Int?
}

struct DpadMapping: Codable, Equatable {
  let byte: Int?
  let bits: [String: String]

  enum CodingKeys: String, CodingKey {
    case byte
    case bits
  }
}

struct AxisMapping: Codable, Equatable {
  let name: String
  let byte: Int
  let bitOffset: Int
  let bitLength: Int
  let invert: Bool
}

struct TriggerMapping: Codable, Equatable {
  let name: String
  let byte: Int
  let bitOffset: Int
  let bitLength: Int
  let analog: Bool
}

public struct ButtonMappings: Codable, Equatable {
  let buttons: [String: String]
  let dpad: DpadMapping?
  let axes: [String: AxisMapping]?
  let triggers: [String: TriggerMapping]?

  enum CodingKeys: String, CodingKey {
    case buttons
    case dpad
    case axes
    case triggers
  }
}

public struct QuirkParameter: Codable, Equatable {
  public let stringValue: String?
  public let doubleValue: Double?
  public let boolValue: Bool?
  public let intValue: Int?

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let stringValue = try? container.decode(String.self) {
      self.stringValue = stringValue
      self.doubleValue = nil
      self.boolValue = nil
      self.intValue = nil
    } else if let doubleValue = try? container.decode(Double.self) {
      self.stringValue = nil
      self.doubleValue = doubleValue
      self.boolValue = nil
      self.intValue = nil
    } else if let boolValue = try? container.decode(Bool.self) {
      self.stringValue = nil
      self.doubleValue = nil
      self.boolValue = boolValue
      self.intValue = nil
    } else if let intValue = try? container.decode(Int.self) {
      self.stringValue = nil
      self.doubleValue = nil
      self.boolValue = nil
      self.intValue = intValue
    } else {
      self.stringValue = nil
      self.doubleValue = nil
      self.boolValue = nil
      self.intValue = nil
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    if let stringValue = stringValue {
      try container.encode(stringValue)
    } else if let doubleValue = doubleValue {
      try container.encode(doubleValue)
    } else if let boolValue = boolValue {
      try container.encode(boolValue)
    } else if let intValue = intValue {
      try container.encode(intValue)
    } else {
      try container.encodeNil()
    }
  }
}

public struct DeviceQuirk: Codable, Equatable {
  public let name: String
  public let description: String?
  public let enabled: Bool
  public let parameters: [String: QuirkParameter]?

  public func isEnabled() -> Bool {
    return enabled
  }

  public func parameter(named name: String) -> QuirkParameter? {
    return parameters?[name]
  }
}

public struct DeviceConfiguration: Codable, Equatable {
  public let device: DeviceInfo
  public let protocolType: ProtocolType
  public let initialization: [InitStep]
  public let shutdownSteps: [InitStep]
  public let reportDescriptor: ReportDescriptor
  public let mappings: ButtonMappings
  public let quirks: [DeviceQuirk]

  enum CodingKeys: String, CodingKey {
    case device
    case protocolType = "protocol"
    case initialization
    case shutdownSteps = "shutdownSteps"
    case reportDescriptor = "reportDescriptor"
    case mappings
    case quirks
  }

  init(
    vendorId: Int,
    productId: Int,
    name: String,
    protocolType: ProtocolType
  ) {
    self.device = DeviceInfo(vendorId: vendorId, productId: productId, name: name)
    self.protocolType = protocolType
    self.initialization = []
    self.shutdownSteps = []
    self.reportDescriptor = ReportDescriptor(reportSize: 8, fields: [])
    self.mappings = ButtonMappings(buttons: [:], dpad: nil, axes: nil, triggers: nil)
    self.quirks = []
  }

  func matches(vendorId: Int, productId: Int) -> Bool {
    return self.device.vendorId == vendorId && self.device.productId == productId
  }

  func field(named name: String) -> ReportField? {
    return reportDescriptor.field(named: name)
  }

  public func hasQuirk(named name: String) -> Bool {
    return quirks.contains { $0.name == name && $0.enabled }
  }
}
