public enum ConnectionState: Sendable, Equatable {
  case disconnected
  case connecting
  case connected
  case error
}

public struct GamepadDevice: Sendable, Equatable, Identifiable {
  public let id: String
  public let vendorID: UInt16
  public let productID: UInt16
  public let deviceName: String
  public let connectionState: ConnectionState

  public init(
    vendorID: UInt16,
    productID: UInt16,
    deviceName: String,
    connectionState: ConnectionState
  ) {
    self.id = "\(vendorID)-\(productID)"
    self.vendorID = vendorID
    self.productID = productID
    self.deviceName = deviceName
    self.connectionState = connectionState
  }
}

extension GamepadDevice {
  public var isXbox: Bool {
    _isXboxVendor(vendorID)
  }

  public var isPlayStation: Bool {
    vendorID == USBConstants.Vendor.sony
  }

  public var isNintendo: Bool {
    vendorID == USBConstants.Vendor.nintendo
  }

  public var isGeneric: Bool {
    !isXbox && !isPlayStation && !isNintendo
  }
}

extension GamepadDevice {
  private func _isXboxVendor(_ vendorID: UInt16) -> Bool {
    switch vendorID {
    case USBConstants.Vendor.microsoft,
      USBConstants.Vendor.madCatz,
      USBConstants.Vendor.logitech,
      USBConstants.Vendor.pdp,
      USBConstants.Vendor.razer,
      USBConstants.Vendor.hori,
      USBConstants.Vendor.razerAlt,
      USBConstants.Vendor.gamesir:
      return true
    default:
      return false
    }
  }
}
