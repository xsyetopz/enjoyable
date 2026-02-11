import CLibUSB
import Foundation

public final class USBDevice: @unchecked Sendable {
  private let _device: OpaquePointer
  private weak var _context: USBContext?

  public let deviceID: USBDeviceID
  public let busNumber: UInt8
  public let portNumber: UInt8
  public let deviceAddress: UInt8
  public let speed: DeviceSpeed
  public let descriptor: libusb_device_descriptor

  init(device: OpaquePointer, context: USBContext) throws {
    self._device = device
    libusb_ref_device(device)
    self._context = context

    var descriptor = libusb_device_descriptor()
    let result = libusb_get_device_descriptor(device, &descriptor)

    guard result == 0 else {
      throw USBError(result)
    }

    self.descriptor = descriptor
    self.deviceID = USBDeviceID(
      vendorID: descriptor.idVendor,
      productID: descriptor.idProduct
    )
    self.busNumber = libusb_get_bus_number(device)
    self.portNumber = libusb_get_port_number(device)
    self.deviceAddress = libusb_get_device_address(device)

    let rawSpeed = UInt8(libusb_get_device_speed(device))
    self.speed = DeviceSpeed(rawValue: rawSpeed) ?? .unknown
  }

  deinit {
    libusb_unref_device(_device)
  }

  internal var rawDevice: OpaquePointer {
    _device
  }

  public func open() throws -> USBDeviceHandle {
    var handle: OpaquePointer?
    let result = libusb_open(_device, &handle)

    guard result == 0, let unwrappedHandle = handle else {
      throw USBError(result)
    }

    return USBDeviceHandle(handle: unwrappedHandle, device: self)
  }

  public func getActiveConfigurationDescriptor() throws -> ConfigurationDescriptor {
    var config: UnsafeMutablePointer<libusb_config_descriptor>?
    let result = libusb_get_active_config_descriptor(_device, &config)

    guard result == 0, let unwrappedConfig = config else {
      throw USBError(result)
    }

    return ConfigurationDescriptor(descriptor: unwrappedConfig)
  }

  public func getConfigurationDescriptor(index: UInt8) throws -> ConfigurationDescriptor {
    var config: UnsafeMutablePointer<libusb_config_descriptor>?
    let result = libusb_get_config_descriptor(_device, index, &config)

    guard result == 0, let unwrappedConfig = config else {
      throw USBError(result)
    }

    return ConfigurationDescriptor(descriptor: unwrappedConfig)
  }

  public func getManufacturerString(handle: USBDeviceHandle) throws -> String? {
    var descriptor = libusb_device_descriptor()
    let result = libusb_get_device_descriptor(_device, &descriptor)

    guard result == 0 else {
      throw USBError(result)
    }

    return try _getStringDescriptor(index: descriptor.iManufacturer, handle: handle)
  }

  public func getProductString(handle: USBDeviceHandle) throws -> String? {
    var descriptor = libusb_device_descriptor()
    let result = libusb_get_device_descriptor(_device, &descriptor)

    guard result == 0 else {
      throw USBError(result)
    }

    return try _getStringDescriptor(index: descriptor.iProduct, handle: handle)
  }

  public func getSerialNumberString(handle: USBDeviceHandle) throws -> String? {
    var descriptor = libusb_device_descriptor()
    let result = libusb_get_device_descriptor(_device, &descriptor)

    guard result == 0 else {
      throw USBError(result)
    }

    return try _getStringDescriptor(index: descriptor.iSerialNumber, handle: handle)
  }

  private func _getStringDescriptor(index: UInt8, handle: USBDeviceHandle) throws -> String? {
    guard index > 0 else { return nil }

    var buffer = [UInt8](repeating: 0, count: 256)
    let result = libusb_get_string_descriptor_ascii(
      handle._handle,
      index,
      &buffer,
      Int32(buffer.count)
    )

    guard result > 0 else { return nil }

    let trimmed = buffer.prefix(while: { $0 != 0 })
    return String(bytes: trimmed, encoding: .utf8) ?? "unknown"
  }
}

extension USBDevice: CustomStringConvertible {
  public var description: String {
    """
    USBDevice(
      deviceID: \(deviceID),
      bus: \(busNumber),
      port: \(portNumber),
      address: \(deviceAddress),
      speed: \(speed)
    )
    """
  }
}

public enum DeviceSpeed: UInt8, Sendable, CustomStringConvertible {
  case unknown = 0
  case low = 1
  case full = 2
  case high = 3
  case superSpeed = 4
  case superSpeedPlus = 5

  public var description: String {
    switch self {
    case .unknown: return "Unknown"
    case .low: return "Low Speed (1.5 Mbps)"
    case .full: return "Full Speed (12 Mbps)"
    case .high: return "High Speed (480 Mbps)"
    case .superSpeed: return "Super Speed (5 Gbps)"
    case .superSpeedPlus: return "Super Speed+ (10 Gbps)"
    }
  }
}

public final class ConfigurationDescriptor: @unchecked Sendable {
  private let _descriptor: UnsafeMutablePointer<libusb_config_descriptor>

  init(descriptor: UnsafeMutablePointer<libusb_config_descriptor>) {
    self._descriptor = descriptor
  }

  deinit {
    libusb_free_config_descriptor(_descriptor)
  }

  public var configurationValue: UInt8 {
    _descriptor.pointee.bConfigurationValue
  }

  public var interfaceCount: UInt8 {
    _descriptor.pointee.bNumInterfaces
  }

  public var attributes: UInt8 {
    _descriptor.pointee.bmAttributes
  }

  public var maxPower: UInt8 {
    _descriptor.pointee.MaxPower
  }

  public var isSelfPowered: Bool {
    (attributes & 0x40) != 0
  }

  public var remoteWakeup: Bool {
    (attributes & 0x20) != 0
  }

  public func getInterfaces() -> [InterfaceDescriptor] {
    var interfaces: [InterfaceDescriptor] = []

    for i in 0..<Int(interfaceCount) {
      let interfacePtr = _descriptor.pointee.interface.advanced(by: i)
      let altSettingCount = Int(interfacePtr.pointee.num_altsetting)

      for j in 0..<altSettingCount {
        let altSettingPtr = interfacePtr.pointee.altsetting.advanced(by: j)
        interfaces.append(InterfaceDescriptor(descriptor: altSettingPtr))
      }
    }

    return interfaces
  }
}

public struct InterfaceDescriptor {
  private let _descriptor: UnsafePointer<libusb_interface_descriptor>

  init(descriptor: UnsafePointer<libusb_interface_descriptor>) {
    self._descriptor = descriptor
  }

  public var interfaceNumber: UInt8 {
    _descriptor.pointee.bInterfaceNumber
  }

  public var alternateSetting: UInt8 {
    _descriptor.pointee.bAlternateSetting
  }

  public var interfaceClass: UInt8 {
    _descriptor.pointee.bInterfaceClass
  }

  public var interfaceSubClass: UInt8 {
    _descriptor.pointee.bInterfaceSubClass
  }

  public var interfaceProtocol: UInt8 {
    _descriptor.pointee.bInterfaceProtocol
  }

  public var endpointCount: UInt8 {
    _descriptor.pointee.bNumEndpoints
  }

  public var interfaceString: UInt8 {
    _descriptor.pointee.iInterface
  }

  public func getEndpoints() -> [EndpointDescriptor] {
    var endpoints: [EndpointDescriptor] = []

    for i in 0..<Int(endpointCount) {
      let endpointPtr = _descriptor.pointee.endpoint.advanced(by: i)
      endpoints.append(EndpointDescriptor(descriptor: endpointPtr))
    }

    return endpoints
  }
}

public struct EndpointDescriptor {
  private let _descriptor: UnsafePointer<libusb_endpoint_descriptor>

  init(descriptor: UnsafePointer<libusb_endpoint_descriptor>) {
    self._descriptor = descriptor
  }

  public var address: UInt8 {
    _descriptor.pointee.bEndpointAddress
  }

  public var attributes: UInt8 {
    _descriptor.pointee.bmAttributes
  }

  public var maxPacketSize: UInt16 {
    _descriptor.pointee.wMaxPacketSize
  }

  public var interval: UInt8 {
    _descriptor.pointee.bInterval
  }

  public var direction: EndpointDirection {
    address & Config.Endpoint.directionMask != 0 ? .input : .out
  }

  public var transferType: TransferType {
    TransferType(rawValue: attributes & 0x03) ?? .control
  }

  public var endpointNumber: UInt8 {
    address & Config.Endpoint.addressMask
  }
}

public enum EndpointDirection: UInt8, Sendable {
  case out = 0
  case input = 1

  public var description: String {
    switch self {
    case .out: return "OUT"
    case .input: return "IN"
    }
  }
}

public enum TransferType: UInt8, Sendable {
  case control = 0
  case isochronous = 1
  case bulk = 2
  case interrupt = 3

  public var description: String {
    switch self {
    case .control: return "Control"
    case .isochronous: return "Isochronous"
    case .bulk: return "Bulk"
    case .interrupt: return "Interrupt"
    }
  }
}
