import Foundation

struct ControllerConfig: Codable {
  let id: String
  let name: String
  let vendorId: VendorId
  let productId: ProductId
  let transport: String
  let protocolTypeStr: String
  let reportSize: Int
  let manufacturer: String?
  let endpoints: Endpoints?
  let features: ControllerFeatures?
  let deadZones: DeadZones?
  let protocolConfig: ProtocolConfigData?
  let buttonMapping: [ButtonMappingEntry]?
  let reportFormat: ReportFormat?
  let initSequence: [InitializationStep]?

  var transportType: TransportType {
    switch transport.lowercased() {
    case "usb": return .usb
    case "bluetooth": return .bluetooth
    case "hid": return .hid
    default: return .usb
    }
  }

  var protocolType: ProtocolType {
    ProtocolType(rawValue: protocolTypeStr) ?? .gip
  }
}

struct Endpoints: Codable {
  let `in`: UInt8?
  let out: UInt8?
}

struct ProtocolConfigData: Codable {
  let pollRate: UInt8?
  let handshakeRequired: Bool?
}
