import CLibUSB
import Foundation

public struct USBDeviceID: Hashable, Sendable {
  public let vendorID: UInt16
  public let productID: UInt16

  public init(vendorID: UInt16, productID: UInt16) {
    self.vendorID = vendorID
    self.productID = productID
  }

  public var description: String {
    String(format: "VID:0x%04X PID:0x%04X", vendorID, productID)
  }

  public static func vendor(_ vendorID: UInt16, product productID: UInt16) -> USBDeviceID {
    USBDeviceID(vendorID: vendorID, productID: productID)
  }

  public static func == (lhs: USBDeviceID, rhs: USBDeviceID) -> Bool {
    lhs.vendorID == rhs.vendorID && lhs.productID == rhs.productID
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(vendorID)
    hasher.combine(productID)
  }
}

extension USBDeviceID {
  static let any = USBDeviceID(vendorID: 0, productID: 0)

  func matches(_ deviceID: USBDeviceID) -> Bool {
    self == .any || self == deviceID
  }
}
