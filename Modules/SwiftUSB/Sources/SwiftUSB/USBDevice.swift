import CLibUSB
import Foundation
import Logging

extension USBDevice {
  internal static let logger = Logger(label: "io.github.xsyetopz.swiftusb.USBDevice")
}

public final class USBDevice: @unchecked Sendable {
  internal let device: OpaquePointer
  public let bLength: UInt8
  public let bDescriptorType: UInt8
  public let bcdUSB: UInt16
  public let bDeviceClass: UInt8
  public let bDeviceSubClass: UInt8
  public let bDeviceProtocol: UInt8
  public let bMaxPacketSize0: UInt8
  public let idVendor: UInt16
  public let idProduct: UInt16
  public let bcdDevice: UInt16
  public let iManufacturer: UInt8
  public let iProduct: UInt8
  public let iSerialNumber: UInt8
  public let bNumConfigurations: UInt8
  public let bus: UInt8
  public let address: UInt8
  public let port: UInt8
  public let speed: USBSpeed

  private var cachedHandle: USBDeviceHandle?

  internal init(device: OpaquePointer, descriptor: libusb_device_descriptor) {
    self.device = device
    self.bLength = descriptor.bLength
    self.bDescriptorType = descriptor.bDescriptorType
    self.bcdUSB = descriptor.bcdUSB
    self.bDeviceClass = descriptor.bDeviceClass
    self.bDeviceSubClass = descriptor.bDeviceSubClass
    self.bDeviceProtocol = descriptor.bDeviceProtocol
    self.bMaxPacketSize0 = descriptor.bMaxPacketSize0
    self.idVendor = descriptor.idVendor
    self.idProduct = descriptor.idProduct
    self.bcdDevice = descriptor.bcdDevice
    self.iManufacturer = descriptor.iManufacturer
    self.iProduct = descriptor.iProduct
    self.iSerialNumber = descriptor.iSerialNumber
    self.bNumConfigurations = descriptor.bNumConfigurations

    self.bus = libusb_get_bus_number(device)
    self.address = libusb_get_device_address(device)
    self.port = libusb_get_port_number(device)
    self.speed = USBSpeed(libusb_get_device_speed(device))
  }

  public var deviceClass: UInt8 {
    bDeviceClass
  }

  public var deviceSubClass: UInt8 {
    bDeviceSubClass
  }

  public var deviceProtocol: UInt8 {
    bDeviceProtocol
  }

  public var manufacturer: String? {
    guard iManufacturer > 0 else {
      return nil
    }
    return nil
  }

  public var product: String? {
    guard iProduct > 0 else {
      return nil
    }
    return nil
  }

  public var serialNumber: String? {
    guard iSerialNumber > 0 else {
      return nil
    }
    return nil
  }

  public func open() throws -> USBDeviceHandle {
    let vendorProduct = String(format: "%04X:%04X", idVendor, idProduct)
    Self.logger.debug("Opening device \(vendorProduct)")
    var handle: OpaquePointer?
    let result = libusb_open(device, &handle)
    try USBError.check(result)
    guard let h = handle else {
      Self.logger.error("Failed to open device - handle is nil")
      throw USBError(message: "Failed to open device")
    }
    Self.logger.debug("Successfully opened device")
    return USBDeviceHandle(handle: h)
  }

  public func openWithCapture() throws -> USBDeviceHandle {
    let vendorProduct = String(format: "%04X:%04X", idVendor, idProduct)
    Self.logger.debug("Opening device with capture \(vendorProduct)")
    var handle: OpaquePointer?
    let result = libusb_open(device, &handle)
    try USBError.check(result)
    guard let h = handle else {
      Self.logger.error("Failed to open device with capture - handle is nil")
      throw USBError(message: "Failed to open device")
    }

    let handleObj = USBDeviceHandle(handle: h)

    if #available(macOS 11.0, *) {
      Self.logger.debug("Detaching kernel driver for interface 0")
      try handleObj.detachKernelDriver(interface: 0)
    }

    Self.logger.debug("Successfully opened device with capture")
    return handleObj
  }

  public func isKernelDriverActive(interface: Int) throws -> Bool {
    var handle: OpaquePointer?
    let openResult = libusb_open(device, &handle)
    try USBError.check(openResult)
    guard let h = handle else {
      throw USBError(message: "Failed to open device for kernel driver check")
    }
    defer { libusb_close(h) }

    let result = libusb_kernel_driver_active(h, Int32(interface))
    try USBError.check(result)

    let isActive = result == 1
    Self.logger.debug("Kernel driver active for interface \(interface): \(isActive)")
    return isActive
  }

  public func reset() throws {
    let vendorProduct = String(format: "%04X:%04X", idVendor, idProduct)
    Self.logger.debug("Resetting device \(vendorProduct)")
    var handle: OpaquePointer?
    let openResult = libusb_open(device, &handle)
    try USBError.check(openResult)
    guard let h = handle else {
      throw USBError(message: "Failed to open device for reset")
    }
    defer { libusb_close(h) }

    let result = libusb_reset_device(h)
    try USBError.check(result)
    Self.logger.debug("Device reset successfully")
  }

  public func clearHalt(endpoint: UInt8) throws {
    Self.logger.debug("Clearing halt on endpoint 0x\(String(format: "%02X", endpoint))")
    var handle: OpaquePointer?
    let openResult = libusb_open(device, &handle)
    try USBError.check(openResult)
    guard let h = handle else {
      throw USBError(message: "Failed to open device for clear halt")
    }
    defer { libusb_close(h) }

    let result = libusb_clear_halt(h, endpoint)
    try USBError.check(result)
    Self.logger.debug("Cleared halt on endpoint 0x\(String(format: "%02X", endpoint))")
  }

  public func getStringDescriptor(index: Int, langID: UInt16? = nil) throws -> String {
    let langIDText = langID.map { String($0) } ?? "default"
    Self.logger.debug("Getting string descriptor at index \(index), langID: \(langIDText)")

    var handle: OpaquePointer?
    let openResult = libusb_open(device, &handle)
    try USBError.check(openResult)
    guard let h = handle else {
      throw USBError(message: "Failed to open device for string descriptor")
    }
    defer { libusb_close(h) }

    var buffer = [UInt8](repeating: 0, count: 256)

    let result = libusb_get_string_descriptor_ascii(h, UInt8(index), &buffer, 256)

    if result < 0 {
      Self.logger.error("Failed to get string descriptor - error \(result)")
      try USBError.check(result)
    }

    let stringData = buffer.prefix(Int(result))
    if let str = String(bytes: Array(stringData), encoding: .utf8) {
      Self.logger.debug("Got string descriptor: \(str)")
      return str
    }

    Self.logger.error("Failed to decode string descriptor")
    throw USBError(message: "Failed to decode string descriptor")
  }

  public func getManufacturer() throws -> String {
    guard iManufacturer > 0 else {
      throw USBError(message: "No manufacturer string descriptor")
    }
    return try getStringDescriptor(index: Int(iManufacturer))
  }

  public func getProduct() throws -> String {
    guard iProduct > 0 else {
      throw USBError(message: "No product string descriptor")
    }
    return try getStringDescriptor(index: Int(iProduct))
  }

  public func getSerialNumber() throws -> String {
    guard iSerialNumber > 0 else {
      throw USBError(message: "No serial number string descriptor")
    }
    return try getStringDescriptor(index: Int(iSerialNumber))
  }

  public func getActiveConfiguration() throws -> Int {
    var handle: OpaquePointer?
    let openResult = libusb_open(device, &handle)
    try USBError.check(openResult)
    guard let h = handle else {
      throw USBError(message: "Failed to open device for configuration")
    }
    defer { libusb_close(h) }

    var configuration: Int32 = 0
    let result = libusb_get_configuration(h, &configuration)
    try USBError.check(result)

    Self.logger.debug("Active configuration: \(configuration)")
    return Int(configuration)
  }

  public func getConfigurationDescriptor(index: Int) throws -> USBConfigurationDescriptor {
    var handle: OpaquePointer?
    let openResult = libusb_open(device, &handle)
    try USBError.check(openResult)
    guard let h = handle else {
      throw USBError(message: "Failed to open device for configuration descriptor")
    }
    defer { libusb_close(h) }

    var configDesc: UnsafeMutablePointer<libusb_config_descriptor>?
    let result = libusb_get_config_descriptor(device, UInt8(index), &configDesc)
    try USBError.check(result)

    guard let desc = configDesc else {
      throw USBError(message: "Failed to get configuration descriptor")
    }
    defer { libusb_free_config_descriptor(desc) }

    Self.logger.debug("Got configuration descriptor at index \(index)")
    return USBConfigurationDescriptor(descriptor: desc.pointee)
  }

  private func getHandle() throws -> USBDeviceHandle {
    if let handle = cachedHandle, handle.isOpen {
      return handle
    }
    let handle = try open()
    cachedHandle = handle
    return handle
  }

  public func read(
    endpoint: UInt8,
    length: Int,
    timeout: UInt32 = 5000
  ) throws -> Data {
    let handle = try getHandle()
    return try handle.readBulk(endpoint: endpoint, length: length, timeout: timeout)
  }

  public func write(
    endpoint: UInt8,
    data: Data,
    timeout: UInt32 = 5000
  ) throws -> Int {
    let handle = try getHandle()
    return try handle.bulkTransfer(endpoint: endpoint, data: data, timeout: timeout)
  }

  public func setConfiguration(_ configuration: Int) throws {
    let handle = try getHandle()
    try handle.setConfiguration(configuration)
  }

  public func getActiveConfiguration() throws -> UInt8 {
    let handle = try getHandle()
    return UInt8(try handle.getConfiguration())
  }

  public func isKernelDriverActiveUsingHandle(interface: Int) throws -> Bool {
    let handle = try getHandle()
    return try handle.isKernelDriverActive(interface: interface)
  }

  public func detachKernelDriver(interface: Int) throws {
    let handle = try getHandle()
    try handle.detachKernelDriver(interface: interface)
  }

  public func claimInterface(_ number: Int) throws {
    let handle = try getHandle()
    try handle.claimInterface(number)
  }

  public func releaseInterface(_ number: Int) throws {
    let handle = try getHandle()
    try handle.releaseInterface(number)
  }

  deinit {
    cachedHandle = nil
  }
}

public enum USBSpeed {
  case unknown
  case low
  case full
  case high
  case superSpeed
  case superSpeedPlus

  internal init(_ libusbSpeed: Int32) {
    if libusbSpeed == Int32(LIBUSB_SPEED_LOW.rawValue) {
      self = .low
    } else if libusbSpeed == Int32(LIBUSB_SPEED_FULL.rawValue) {
      self = .full
    } else if libusbSpeed == Int32(LIBUSB_SPEED_HIGH.rawValue) {
      self = .high
    } else if libusbSpeed == Int32(LIBUSB_SPEED_SUPER.rawValue) {
      self = .superSpeed
    } else if libusbSpeed == Int32(LIBUSB_SPEED_SUPER_PLUS.rawValue) {
      self = .superSpeedPlus
    } else {
      self = .unknown
    }
  }

  public var description: String {
    switch self {
    case .unknown:
      return "Unknown"

    case .low:
      return "1.5 Mbps (Low Speed)"

    case .full:
      return "12 Mbps (Full Speed)"

    case .high:
      return "480 Mbps (High Speed)"

    case .superSpeed:
      return "5 Gbps (Super Speed)"

    case .superSpeedPlus:
      return "10 Gbps (Super Speed +)"
    }
  }
}

public struct USBConfigurationDescriptor: @unchecked Sendable {
  internal let descriptor: libusb_config_descriptor

  internal init(descriptor: libusb_config_descriptor) {
    self.descriptor = descriptor
  }

  public var bLength: UInt8 {
    descriptor.bLength
  }

  public var bDescriptorType: UInt8 {
    descriptor.bDescriptorType
  }

  public var wTotalLength: UInt16 {
    descriptor.wTotalLength
  }

  public var bNumInterfaces: UInt8 {
    descriptor.bNumInterfaces
  }

  public var bConfigurationValue: UInt8 {
    descriptor.bConfigurationValue
  }

  public var iConfiguration: UInt8 {
    descriptor.iConfiguration
  }

  public var bmAttributes: UInt8 {
    descriptor.bmAttributes
  }

  public var maxPower: UInt8 {
    descriptor.MaxPower
  }
}

public extension USBDevice {
  static func findAll(
    vendorID: UInt16? = nil,
    productID: UInt16? = nil,
    deviceClass: UInt8? = nil
  ) async throws -> [USBDevice] {
    let context = try USBContext()
    var devices: [USBDevice] = []
    for await device in context.findDevices(
      vendorID: vendorID,
      productID: productID,
      deviceClass: deviceClass,
      findAll: true
    ) {
      devices.append(device)
    }
    return devices
  }

  static func find(
    vendorID: UInt16? = nil,
    productID: UInt16? = nil,
    deviceClass: UInt8? = nil
  ) async throws -> USBDevice? {
    let context = try USBContext()
    for await device in context.findDevices(
      vendorID: vendorID,
      productID: productID,
      deviceClass: deviceClass,
      findAll: false
    ) {
      return device
    }
    return nil
  }
}
