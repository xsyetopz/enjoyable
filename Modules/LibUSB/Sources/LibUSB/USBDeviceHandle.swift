import CLibUSB
import Foundation

public final class USBDeviceHandle: @unchecked Sendable {
  internal let _handle: OpaquePointer
  private weak var _device: USBDevice?

  init(handle: OpaquePointer, device: USBDevice) {
    self._handle = handle
    self._device = device
  }

  public func close() {
    libusb_close(_handle)
  }

  public var device: USBDevice {
    guard let device = _device else {
      fatalError("USBDeviceHandle accessed after device was deallocated")
    }
    return device
  }

  public func getConfiguration() throws -> UInt8 {
    var config: Int32 = 0
    let result = libusb_get_configuration(_handle, &config)

    guard result == 0 else {
      throw USBError(result)
    }

    return UInt8(config)
  }

  public func setConfiguration(configuration: UInt8) throws {
    let result = libusb_set_configuration(_handle, Int32(configuration))

    guard result == 0 else {
      throw USBError(result)
    }
  }

  public func setConfiguration(_ index: UInt8) throws {
    let result = libusb_set_configuration(_handle, Int32(index))
    guard result == 0 else {
      throw USBError(result)
    }
  }

  public func getActiveConfigurationDescriptor() throws -> ConfigurationDescriptor {
    var config: UnsafeMutablePointer<libusb_config_descriptor>?
    let result = libusb_get_active_config_descriptor(_device?.rawDevice, &config)
    guard result == 0, let unwrappedConfig = config else {
      throw USBError(result)
    }
    return ConfigurationDescriptor(descriptor: unwrappedConfig)
  }

  public func getStringDescriptor(_ index: UInt8) throws -> String {
    var buffer: [UInt8] = Array(repeating: 0, count: 256)
    let transferred = libusb_get_string_descriptor_ascii(
      _handle,
      index,
      &buffer,
      Int32(buffer.count)
    )
    guard transferred > 0 else {
      throw USBError(transferred)
    }
    let trimmed = buffer.prefix(while: { $0 != 0 })
    return String(bytes: trimmed, encoding: .utf8) ?? "unknown"
  }

  public func claimInterface(interfaceNumber: UInt8) throws {
    let result = libusb_claim_interface(_handle, Int32(interfaceNumber))

    guard result == 0 else {
      throw USBError(result)
    }
  }

  public func releaseInterface(interfaceNumber: UInt8) throws {
    let result = libusb_release_interface(_handle, Int32(interfaceNumber))

    guard result == 0 else {
      throw USBError(result)
    }
  }

  public func setInterfaceAltSetting(
    interfaceNumber: UInt8,
    alternateSetting: UInt8
  ) throws {
    let result = libusb_set_interface_alt_setting(
      _handle,
      Int32(interfaceNumber),
      Int32(alternateSetting)
    )

    guard result == 0 else {
      throw USBError(result)
    }
  }

  public func clearHalt(endpointAddress: UInt8) throws {
    let result = libusb_clear_halt(_handle, endpointAddress)

    guard result == 0 else {
      throw USBError(result)
    }
  }

  public func resetDevice() throws {
    let result = libusb_reset_device(_handle)

    guard result == 0 else {
      throw USBError(result)
    }
  }

  public func kernelDriverActive(interfaceNumber: UInt8) -> Bool {
    libusb_kernel_driver_active(_handle, Int32(interfaceNumber)) == 1
  }

  public func detachKernelDriver(interfaceNumber: UInt8) throws {
    let result = libusb_detach_kernel_driver(_handle, Int32(interfaceNumber))

    guard result == 0 else {
      throw USBError(result)
    }
  }

  public func attachKernelDriver(interfaceNumber: UInt8) throws {
    let result = libusb_attach_kernel_driver(_handle, Int32(interfaceNumber))

    guard result == 0 else {
      throw USBError(result)
    }
  }

  public func setAutoDetachKernelDriver(enable: Bool) throws {
    let result = libusb_set_auto_detach_kernel_driver(_handle, enable ? 1 : 0)

    guard result == 0 else {
      throw USBError(result)
    }
  }

  public func controlTransfer(
    requestType: UInt8,
    request: UInt8,
    value: UInt16,
    index: UInt16,
    data: UnsafeMutableRawPointer?,
    length: UInt16,
    timeout: UInt32 = Config.Timeout.defaultTransfer
  ) throws -> Int {
    let transferred = libusb_control_transfer(
      _handle,
      requestType,
      request,
      value,
      index,
      data?.assumingMemoryBound(to: UInt8.self),
      length,
      timeout
    )

    guard transferred >= 0 else {
      throw USBError(Int32(transferred))
    }

    return Int(transferred)
  }

  public func bulkTransfer(
    endpointAddress: UInt8,
    data: UnsafeMutableRawPointer?,
    length: Int,
    timeout: UInt32 = Config.Timeout.bulkTransfer
  ) throws -> Int {
    var transferred: Int32 = 0
    let result = libusb_bulk_transfer(
      _handle,
      endpointAddress,
      data?.assumingMemoryBound(to: UInt8.self),
      Int32(length),
      &transferred,
      timeout
    )

    guard result == 0 else {
      throw USBError(result)
    }

    return Int(transferred)
  }

  public func interruptTransfer(
    endpointAddress: UInt8,
    data: UnsafeMutableRawPointer?,
    length: Int,
    timeout: UInt32 = Config.Timeout.interruptTransfer
  ) throws -> Int {
    var transferred: Int32 = 0
    let result = libusb_interrupt_transfer(
      _handle,
      endpointAddress,
      data?.assumingMemoryBound(to: UInt8.self),
      Int32(length),
      &transferred,
      timeout
    )

    guard result == 0 else {
      throw USBError(result)
    }

    return Int(transferred)
  }
}

extension USBDeviceHandle {
  func readControl(
    requestType: UInt8,
    request: UInt8,
    value: UInt16,
    index: UInt16,
    length: UInt16,
    timeout: UInt32 = Config.Timeout.controlTransfer
  ) throws -> [UInt8] {
    var buffer = [UInt8](repeating: 0, count: Int(length))
    let bytesRead = try controlTransfer(
      requestType: requestType | 0x80,
      request: request,
      value: value,
      index: index,
      data: &buffer,
      length: length,
      timeout: timeout
    )

    return Array(buffer.prefix(bytesRead))
  }

  public func writeControl(
    requestType: UInt8,
    request: UInt8,
    value: UInt16,
    index: UInt16,
    data: [UInt8],
    timeout: UInt32 = Config.Timeout.controlTransfer
  ) throws -> Int {
    var buffer = data
    return try controlTransfer(
      requestType: requestType,
      request: request,
      value: value,
      index: index,
      data: &buffer,
      length: UInt16(data.count),
      timeout: timeout
    )
  }

  func readBulk(
    endpointAddress: UInt8,
    length: Int,
    timeout: UInt32 = Config.Timeout.bulkTransfer
  ) throws -> [UInt8] {
    var buffer = [UInt8](repeating: 0, count: length)
    let bytesRead = try bulkTransfer(
      endpointAddress: endpointAddress,
      data: &buffer,
      length: length,
      timeout: timeout
    )

    return Array(buffer.prefix(bytesRead))
  }

  func writeBulk(
    endpointAddress: UInt8,
    data: [UInt8],
    timeout: UInt32 = Config.Timeout.bulkTransfer
  ) throws -> Int {
    var buffer = data
    return try bulkTransfer(
      endpointAddress: endpointAddress,
      data: &buffer,
      length: data.count,
      timeout: timeout
    )
  }

  func readInterrupt(
    endpointAddress: UInt8,
    length: Int,
    timeout: UInt32 = Config.Timeout.interruptTransfer
  ) throws -> [UInt8] {
    var buffer = [UInt8](repeating: 0, count: length)
    let bytesRead = try interruptTransfer(
      endpointAddress: endpointAddress,
      data: &buffer,
      length: length,
      timeout: timeout
    )

    return Array(buffer.prefix(bytesRead))
  }

  public func writeInterrupt(
    endpointAddress: UInt8,
    data: [UInt8],
    timeout: UInt32 = Config.Timeout.interruptTransfer
  ) throws -> Int {
    var buffer = data
    return try interruptTransfer(
      endpointAddress: endpointAddress,
      data: &buffer,
      length: data.count,
      timeout: timeout
    )
  }
}

extension USBDeviceHandle: CustomStringConvertible {
  public var description: String {
    let config = (try? getConfiguration()) ?? 0
    return """
      USBDeviceHandle(
        device: \(device),
        configuration: \(config)
      )
      """
  }
}
