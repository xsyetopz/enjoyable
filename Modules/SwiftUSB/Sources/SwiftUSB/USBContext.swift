import CLibUSB
import Dispatch
import Foundation

public final class USBContext: @unchecked Sendable {
  private let context: OpaquePointer
  private let eventQueue: DispatchQueue

  public init() throws {
    var ctx: OpaquePointer?
    let result = libusb_init(&ctx)
    if result < 0 {
      NSLog("[SwiftUSB] Context: Failed to initialize USB context: %s", libusb_error_name(result))
      throw USBError(code: result)
    }
    guard let context = ctx else {
      NSLog("[SwiftUSB] Context: Failed to initialize USB context - null context returned")
      throw USBError(message: "Failed to initialize USB context")
    }
    self.context = context
    self.eventQueue = DispatchQueue(label: "swiftusb.events", qos: .utility)
    startEventHandling()
    NSLog("[SwiftUSB] Context: Initialized successfully")
  }

  deinit {
    libusb_exit(context)
    NSLog("[SwiftUSB] Context: Deinitialized")
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
          NSLog("[SwiftUSB] Context: Event handling error: %s", libusb_error_name(result))
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
        NSLog("[SwiftUSB] Context: Device list operations complete")
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

      NSLog(
        "[SwiftUSB] Context: Search complete - found %d device(s)",
        deviceCount
      )
      continuation.finish()
    }
  }

  public func findDevice(vendorID: UInt16, productID: UInt16) async -> USBDevice? {
    NSLog(
      "[SwiftUSB] Context: Searching for device vendor=0x%04X, product=0x%04X",
      vendorID,
      productID
    )

    var found: USBDevice?
    for await device in findDevices(vendorID: vendorID, productID: productID, findAll: false) {
      found = device
      break
    }

    if found != nil {
      NSLog("[SwiftUSB] Context: Found requested device")
    } else {
      NSLog("[SwiftUSB] Context: Device not found")
    }

    return found
  }

  private func prepareDeviceList() -> UnsafeMutablePointer<UnsafeMutablePointer<OpaquePointer?>?>? {
    let deviceListPtr = UnsafeMutablePointer<UnsafeMutablePointer<OpaquePointer?>?>.allocate(
      capacity: 1
    )
    let count = libusb_get_device_list(self.context, deviceListPtr)

    guard count >= 0 else {
      NSLog("[SwiftUSB] Context: Failed to get device list: %s", libusb_error_name(Int32(count)))
      deviceListPtr.deallocate()
      return nil
    }

    guard count > 0 else {
      NSLog("[SwiftUSB] Context: No USB devices found")
      deviceListPtr.deallocate()
      return nil
    }

    NSLog("[SwiftUSB] Context: Found %d USB device(s)", count)
    return deviceListPtr
  }

  private func logFilterInformation(
    vendorID: UInt16?,
    productID: UInt16?,
    deviceClass: UInt8?
  ) {
    if let vid = vendorID {
      NSLog("[SwiftUSB] Context: Filtering by vendor ID: 0x%04X", vid)
    }
    if let pid = productID {
      NSLog("[SwiftUSB] Context: Filtering by product ID: 0x%04X", pid)
    }
    if let dc = deviceClass {
      NSLog("[SwiftUSB] Context: Filtering by device class: %d", dc)
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
      NSLog("[SwiftUSB] Context: Device list pointer is null")
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

      NSLog("[SwiftUSB] Context: Matching device found at index %d", i)
      continuation.yield(USBDevice(device: device, descriptor: descriptor.pointee))
      deviceCount += 1

      if !findAll {
        NSLog("[SwiftUSB] Context: First matching device found, stopping search")
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
      NSLog(
        "[SwiftUSB] Context: Failed to get descriptor for device at index %d: %s",
        index,
        libusb_error_name(result)
      )
      descriptor.deallocate()
      return nil
    }

    let vid = descriptor.pointee.idVendor
    let pid = descriptor.pointee.idProduct
    let devClass = descriptor.pointee.bDeviceClass

    NSLog(
      "[SwiftUSB] Context: Device[%d] vendor=0x%04X, product=0x%04X, class=%d",
      index,
      vid,
      pid,
      devClass
    )

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
      NSLog(
        "[SwiftUSB] Context: Skipping device[%d] - vendor mismatch (0x%04X != 0x%04X)",
        index,
        vid,
        filterVID
      )
      return false
    }

    if let filterPID = productID, pid != filterPID {
      NSLog(
        "[SwiftUSB] Context: Skipping device[%d] - product mismatch (0x%04X != 0x%04X)",
        index,
        pid,
        filterPID
      )
      return false
    }

    if let filterClass = deviceClass, devClass != filterClass {
      NSLog(
        "[SwiftUSB] Context: Skipping device[%d] - class mismatch (%d != %d)",
        index,
        devClass,
        filterClass
      )
      return false
    }

    return true
  }
}
