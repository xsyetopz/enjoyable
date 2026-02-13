import CLibUSB
import Dispatch
import Foundation
import Logging

extension USBContext {
  internal static let logger = Logger(label: "io.github.xsyetopz.swiftusb.USBContext")
}

public final class USBContext: @unchecked Sendable {
  private let context: OpaquePointer
  private let eventQueue: DispatchQueue

  public init() throws {
    var ctx: OpaquePointer?
    let result = libusb_init(&ctx)
    if result < 0 {
      Self.logger.error(
        "Failed to initialize USB context: \(String(cString: libusb_error_name(result)))"
      )
      throw USBError(code: result)
    }
    guard let context = ctx else {
      Self.logger.error("Failed to initialize USB context - null context returned")
      throw USBError(message: "Failed to initialize USB context")
    }
    self.context = context
    self.eventQueue = DispatchQueue(label: "swiftusb.events", qos: .utility)
    startEventHandling()
    Self.logger.debug("Initialized successfully")
  }

  deinit {
    libusb_exit(context)
    Self.logger.debug("Deinitialized")
  }

  private func startEventHandling() {
    eventQueue.async { [weak self] in
      guard let self else {
        return
      }
      while true {
        var timeout = timeval(tv_sec: 0, tv_usec: 100_000)
        let result = libusb_handle_events_timeout(self.context, &timeout)
        guard result >= 0 else {
          Self.logger.warning("Event handling error: \(String(cString: libusb_error_name(result)))")
          continue
        }
      }
    }
  }

  public func findDevices(
    vendorID: UInt16? = nil,
    productID: UInt16? = nil,
    deviceClass: UInt8? = nil,
    findAll: Bool = true
  ) -> AsyncStream<USBDevice> {
    AsyncStream { [weak self] continuation in
      guard let self else {
        continuation.finish()
        return
      }

      guard let deviceListPtr = self.prepareDeviceList() else {
        continuation.finish()
        return
      }

      defer {
        libusb_free_device_list(deviceListPtr.pointee, 1)
        deviceListPtr.deallocate()
        Self.logger.debug("Device list operations complete")
      }

      logFilterInformation(vendorID: vendorID, productID: productID, deviceClass: deviceClass)

      let deviceCount = self.processDeviceList(
        deviceListPtr: deviceListPtr,
        vendorID: vendorID,
        productID: productID,
        deviceClass: deviceClass,
        findAll: findAll,
        continuation: continuation
      )

      Self.logger.debug("Search complete - found \(deviceCount) device(s)")
      continuation.finish()
    }
  }

  public func findDevice(vendorID: UInt16, productID: UInt16) async -> USBDevice? {
    let vendorHex = String(format: "%04X", vendorID)
    let productHex = String(format: "%04X", productID)
    let message = "Searching for device vendor=0x\(vendorHex), product=0x\(productHex)"
    Self.logger.debug(Logger.Message(stringLiteral: message))

    var found: USBDevice?
    for await device in findDevices(vendorID: vendorID, productID: productID, findAll: false) {
      found = device
      break
    }

    if found != nil {
      Self.logger.debug("Found requested device")
    } else {
      Self.logger.debug("Device not found")
    }

    return found
  }

  private func prepareDeviceList() -> UnsafeMutablePointer<UnsafeMutablePointer<OpaquePointer?>?>? {
    let deviceListPtr = UnsafeMutablePointer<UnsafeMutablePointer<OpaquePointer?>?>.allocate(
      capacity: 1
    )
    let count = libusb_get_device_list(self.context, deviceListPtr)

    guard count >= 0 else {
      Self.logger.error(
        "Failed to get device list: \(String(cString: libusb_error_name(Int32(count))))"
      )
      deviceListPtr.deallocate()
      return nil
    }

    guard count > 0 else {
      Self.logger.debug("No USB devices found")
      deviceListPtr.deallocate()
      return nil
    }

    Self.logger.debug("Found \(count) USB device(s)")
    return deviceListPtr
  }

  private func logFilterInformation(
    vendorID: UInt16?,
    productID: UInt16?,
    deviceClass: UInt8?
  ) {
    if let vid = vendorID {
      Self.logger.trace("Filtering by vendor ID: 0x\(String(format: "%04X", vid))")
    }
    if let pid = productID {
      Self.logger.trace("Filtering by product ID: 0x\(String(format: "%04X", pid))")
    }
    if let dc = deviceClass {
      Self.logger.trace("Filtering by device class: \(dc)")
    }
  }

  private func processDeviceList(
    deviceListPtr: UnsafeMutablePointer<UnsafeMutablePointer<OpaquePointer?>?>,
    vendorID: UInt16?,
    productID: UInt16?,
    deviceClass: UInt8?,
    findAll: Bool,
    continuation: AsyncStream<USBDevice>.Continuation
  ) -> Int {
    guard let deviceList = deviceListPtr.pointee else {
      Self.logger.error("Device list pointer is null")
      return 0
    }

    let count = libusb_get_device_list(self.context, deviceListPtr)
    var deviceCount = 0

    for i in 0..<Int(count) {
      guard let device = deviceList[i] else {
        continue
      }

      guard let descriptor = self.createDescriptor(for: device, at: i) else {
        continue
      }

      if !deviceMatchesFilters(
        descriptor: descriptor.pointee,
        vendorID: vendorID,
        productID: productID,
        deviceClass: deviceClass,
        index: i
      ) {
        descriptor.deallocate()
        continue
      }

      Self.logger.debug("Matching device found at index \(i)")
      continuation.yield(USBDevice(device: device, descriptor: descriptor.pointee))
      deviceCount += 1

      if !findAll {
        Self.logger.debug("First matching device found, stopping search")
        break
      }
    }

    return deviceCount
  }

  private func createDescriptor(
    for device: OpaquePointer,
    at index: Int
  ) -> UnsafeMutablePointer<libusb_device_descriptor>? {
    let descriptor = UnsafeMutablePointer<libusb_device_descriptor>.allocate(capacity: 1)
    let result = libusb_get_device_descriptor(device, descriptor)

    guard result == 0 else {
      let errorMessage =
        "Failed to get descriptor for device at index \(index): "
        + "\(String(cString: libusb_error_name(result)))"
      Self.logger.error(Logger.Message(stringLiteral: errorMessage))
      descriptor.deallocate()
      return nil
    }

    let vid = descriptor.pointee.idVendor
    let pid = descriptor.pointee.idProduct
    let devClass = descriptor.pointee.bDeviceClass

    let vendorHex = String(format: "%04X", vid)
    let productHex = String(format: "%04X", pid)
    let message =
      "Device[\(index)] vendor=0x\(vendorHex), " + "product=0x\(productHex), class=\(devClass)"
    Self.logger.debug(Logger.Message(stringLiteral: message))

    return descriptor
  }

  private func deviceMatchesFilters(
    descriptor: libusb_device_descriptor,
    vendorID: UInt16?,
    productID: UInt16?,
    deviceClass: UInt8?,
    index: Int
  ) -> Bool {
    let vid = descriptor.idVendor
    let pid = descriptor.idProduct
    let devClass = descriptor.bDeviceClass

    if let filterVID = vendorID, vid != filterVID {
      let vidHex = String(format: "%04X", vid)
      let filterHex = String(format: "%04X", filterVID)
      let message =
        "Skipping device[\(index)] - vendor mismatch " + "(0x\(vidHex) != 0x\(filterHex))"
      Self.logger.trace(Logger.Message(stringLiteral: message))
      return false
    }

    if let filterPID = productID, pid != filterPID {
      let pidHex = String(format: "%04X", pid)
      let filterHex = String(format: "%04X", filterPID)
      let message =
        "Skipping device[\(index)] - product mismatch " + "(0x\(pidHex) != 0x\(filterHex))"
      Self.logger.trace(Logger.Message(stringLiteral: message))
      return false
    }

    if let filterClass = deviceClass, devClass != filterClass {
      Self.logger.trace(
        "Skipping device[\(index)] - class mismatch (\(devClass) != \(filterClass))"
      )
      return false
    }

    return true
  }
}
