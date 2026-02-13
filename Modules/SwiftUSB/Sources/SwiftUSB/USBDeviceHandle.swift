import CLibUSB
import Foundation
import Logging

public final class USBDeviceHandle: @unchecked Sendable {
  internal static let logger = Logger(label: "io.github.xsyetopz.swiftusb.USBDeviceHandle")
  internal let handle: OpaquePointer
  internal var claimedInterfaces: Set<Int>

  private var isHandleOpen: Bool = true

  internal init(handle: OpaquePointer) {
    self.handle = handle
    self.claimedInterfaces = []
  }

  deinit {
    for interface in claimedInterfaces {
      libusb_release_interface(handle, Int32(interface))
    }
    libusb_close(handle)
    isHandleOpen = false
  }

  public var isOpen: Bool {
    isHandleOpen
  }

  public func claimInterface(_ number: Int) throws {
    Self.logger.debug("Claiming interface \(number)")
    let result = libusb_claim_interface(handle, Int32(number))
    try USBError.check(result)
    claimedInterfaces.insert(number)
    Self.logger.debug("Successfully claimed interface \(number)")
  }

  public func releaseInterface(_ number: Int) throws {
    Self.logger.debug("Releasing interface \(number)")
    let result = libusb_release_interface(handle, Int32(number))
    try USBError.check(result)
    claimedInterfaces.remove(number)
    Self.logger.debug("Successfully released interface \(number)")
  }

  public func detachKernelDriver(interface: Int) throws {
    Self.logger.debug("Detaching kernel driver from interface \(interface)")
    if #available(macOS 11.0, *) {
      let result = libusb_detach_kernel_driver(handle, Int32(interface))
      if result == 0 {
        Self.logger.debug("Kernel driver detached from interface \(interface)")
      } else if result == -5 {
        Self.logger.debug("No kernel driver active on interface \(interface)")
      } else {
        Self.logger.debug(
          "Failed to detach kernel driver from interface \(interface): error \(result)"
        )
        try USBError.check(result)
      }
    }
  }

  public func isKernelDriverActive(interface: Int) throws -> Bool {
    Self.logger.debug("Checking if kernel driver is active on interface \(interface)")
    if #available(macOS 11.0, *) {
      let result = libusb_kernel_driver_active(handle, Int32(interface))
      try USBError.check(result)
      let isActive = result == 1
      Self.logger.debug("Kernel driver active on interface \(interface): \(isActive)")
      return isActive
    }
    return false
  }

  public func setConfiguration(_ configuration: Int) throws {
    Self.logger.debug("Setting configuration \(configuration)")
    let result = libusb_set_configuration(handle, Int32(configuration))
    try USBError.check(result)
    Self.logger.debug("Configuration set to \(configuration)")
  }

  public func getConfiguration() throws -> Int {
    Self.logger.debug("Getting current configuration")
    var configuration: Int32 = 0
    let result = libusb_get_configuration(handle, &configuration)
    try USBError.check(result)
    Self.logger.debug("Current configuration: \(configuration)")
    return Int(configuration)
  }

  public func setInterfaceAltSetting(interface: Int, alternateSetting: Int) throws {
    Self.logger.debug("Setting alt setting \(alternateSetting) for interface \(interface)")
    let result = libusb_set_interface_alt_setting(handle, Int32(interface), Int32(alternateSetting))
    try USBError.check(result)
    Self.logger.debug("Alt setting set to \(alternateSetting) for interface \(interface)")
  }

  public func clearHalt(endpoint: UInt8) throws {
    Self.logger.debug("Clearing halt on endpoint \(endpoint)")
    let result = libusb_clear_halt(handle, endpoint)
    try USBError.check(result)
    Self.logger.debug("Halt cleared on endpoint \(endpoint)")
  }

  public func resetDevice() throws {
    Self.logger.debug("Resetting device")
    let result = libusb_reset_device(handle)
    if result < 0 {
      Self.logger.debug("Device reset failed with error \(result)")
      try USBError.check(result)
    } else {
      isHandleOpen = false
      Self.logger.debug("Device reset successfully")
    }
  }
}
