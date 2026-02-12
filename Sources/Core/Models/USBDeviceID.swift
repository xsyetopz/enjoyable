public struct USBDeviceID: Sendable, Hashable, Equatable, Codable {
  public let vendorID: UInt16
  public let productID: UInt16

  public init(vendorID: UInt16, productID: UInt16) {
    self.vendorID = vendorID
    self.productID = productID
  }
}

extension USBDeviceID {
  public var stringValue: String {
    _hexString(from: vendorID) + ":" + _hexString(from: productID)
  }

  public static func from(_ string: String) -> USBDeviceID? {
    let components = string.split(separator: ":")
    guard components.count == 2,
      let vendor = UInt16(components[0], radix: 16),
      let product = UInt16(components[1], radix: 16)
    else {
      return nil
    }
    return USBDeviceID(vendorID: vendor, productID: product)
  }

  private func _hexString(from value: UInt16) -> String {
    let digits = Array("0123456789ABCDEF")
    let digit1 = digits[Int(value >> 12)]
    let digit2 = digits[Int((value >> 8) & 0x0F)]
    let digit3 = digits[Int((value >> 4) & 0x0F)]
    let digit4 = digits[Int(value & 0x0F)]
    return String(digit1) + String(digit2) + String(digit3) + String(digit4)
  }
}
