import CLibUSB
import Foundation

private final class ContextStorage {
  let context: OpaquePointer

  init(context: OpaquePointer) {
    self.context = context
  }

  deinit {
    libusb_exit(context)
  }
}

public actor USBContext: @unchecked Sendable {
  private let _storage: ContextStorage

  public init() throws {
    var ctx: OpaquePointer?
    let result = libusb_init(&ctx)

    guard result == 0, let context = ctx else {
      throw USBError(result)
    }

    self._storage = ContextStorage(context: context)
  }

  public var context: OpaquePointer {
    _storage.context
  }

  public func setDebug(level: DebugLevel) {
    libusb_set_debug(_storage.context, Int32(level.rawValue))
  }

  public func getDeviceList() throws -> [USBDevice] {
    var deviceList: UnsafeMutablePointer<OpaquePointer?>?
    let count = libusb_get_device_list(_storage.context, &deviceList)

    guard count >= 0, let unwrappedList = deviceList else {
      throw USBError(Int32(count))
    }

    defer {
      libusb_free_device_list(deviceList, 0)
    }

    var devices: [USBDevice] = []

    for i in 0..<Int(count) {
      let devicePtr = unwrappedList.advanced(by: i).pointee
      if let device = devicePtr {
        devices.append(try USBDevice(device: device, context: self))
      }
    }

    return devices
  }

  public func findDevices(
    vendorID: UInt16? = nil,
    productID: UInt16? = nil
  ) throws -> [USBDevice] {
    let allDevices = try getDeviceList()

    return allDevices.filter { device in
      if let vendorID = vendorID, device.deviceID.vendorID != vendorID {
        return false
      }
      if let productID = productID, device.deviceID.productID != productID {
        return false
      }
      return true
    }
  }

  public func findDevice(
    vendorID: UInt16,
    productID: UInt16
  ) throws -> USBDevice? {
    let devices = try findDevices(vendorID: vendorID, productID: productID)
    return devices.first
  }

  public func findDevice(deviceID: USBDeviceID) throws -> USBDevice? {
    try findDevice(vendorID: deviceID.vendorID, productID: deviceID.productID)
  }

  public func handleEvents(timeout: UInt32 = Config.Timeout.defaultTransfer) throws {
    var tv = _timevalWithMilliseconds(timeout)
    let result = libusb_handle_events_timeout(_storage.context, &tv)

    guard result == 0 else {
      throw USBError(result)
    }
  }

  public func handleEventsCompleted(completed: UnsafeMutablePointer<Int32>) throws {
    let result = libusb_handle_events_completed(_storage.context, completed)

    guard result == 0 else {
      throw USBError(result)
    }
  }

  public func waitForEvent(
    timeout: UInt32 = Config.Timeout.defaultTransfer
  ) throws {
    var tv = _timevalWithMilliseconds(timeout)
    let result = libusb_wait_for_event(_storage.context, &tv)

    guard result >= 0 else {
      throw USBError(result)
    }
  }

  private static let _millisecondsPerSecond: UInt32 = 1000
  private static let _microsecondsPerMillisecond: UInt32 = 1000

  private func _timevalWithMilliseconds(_ milliseconds: UInt32) -> timeval {
    var tv = timeval()
    tv.tv_sec = time_t(milliseconds / Self._millisecondsPerSecond)
    tv.tv_usec = suseconds_t(
      (milliseconds % Self._millisecondsPerSecond) * Self._microsecondsPerMillisecond
    )
    return tv
  }
}

public enum DebugLevel: Int32, Sendable {
  case none = 0
  case error = 1
  case warning = 2
  case info = 3
  case debug = 4
}
