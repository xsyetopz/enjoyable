import Foundation
import IOKit.hid

final class HIDDeviceHandle: DeviceHandle, Sendable {
  private final class State: @unchecked Sendable {
    var isOpen: Bool = false
    var device: IOHIDDevice?
    var inputReportCallback: ((Data) -> Void)?
  }

  private let state = State()
  private let lock = NSLock()
  private let vendorId: UInt16
  private let productId: UInt16

  init(vendorId: UInt16, productId: UInt16) {
    self.vendorId = vendorId
    self.productId = productId
  }

  deinit {
    close()
  }

  func open() throws {
    try withLock {
      guard !state.isOpen else { return }

      NSLog("[HIDDeviceHandle] Requesting HID access permissions...")
      let accessResult = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
      if !accessResult {
        NSLog(
          "[HIDDeviceHandle] Grant `Input Monitoring` permission in `System Settings > Privacy & Security > Input Monitoring`"
        )
      }

      let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

      IOHIDManagerSetDeviceMatching(manager, nil)

      NSLog("[HIDDeviceHandle] Opening HID manager...")
      let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
      guard openResult == kIOReturnSuccess else {
        if openResult == -536_870_174 {  // kIOReturnNotPrivileged
          NSLog(
            "[HIDDeviceHandle] Permission denied accessing HID; try running as root or adding proper entitlements"
          )
        } else {
          NSLog("[HIDDeviceHandle] Failed to open HID manager with error: \(openResult)")
        }
        throw TransportError.openFailed
      }

      guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        NSLog("[HIDDeviceHandle] No HID devices found at all")
        throw TransportError.deviceNotFound
      }

      var foundDevice: IOHIDDevice?
      for device in deviceSet {
        if let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int,
          let pid = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int
        {
          if vid == Int(vendorId) && pid == Int(productId) {
            foundDevice = device
            break
          }
        }
      }

      guard let hidDevice = foundDevice else {
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        NSLog(
          "[HIDDeviceHandle] No matching HID device found for VID=\(vendorId), PID=\(productId)"
        )
        throw TransportError.deviceNotFound
      }

      var deviceOpenResult = IOHIDDeviceOpen(hidDevice, IOOptionBits(kIOHIDOptionsTypeNone))
      if deviceOpenResult != kIOReturnSuccess {
        NSLog("[HIDDeviceHandle] Non-exclusive open failed, trying with seize...")
        deviceOpenResult = IOHIDDeviceOpen(hidDevice, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
      }

      guard deviceOpenResult == kIOReturnSuccess else {
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        NSLog("[HIDDeviceHandle] Failed to open HID device: \(deviceOpenResult)")
        throw TransportError.openFailed
      }

      state.device = hidDevice
      state.isOpen = true
    }
  }

  func close() {
    lock.lock()
    defer { lock.unlock() }

    guard state.isOpen, let device = state.device else { return }

    IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    state.device = nil
    state.isOpen = false
  }

  func read(_ length: Int) throws -> Data {
    try withLock {
      guard state.isOpen, let device = state.device else {
        throw TransportError.deviceDisconnected
      }

      var buffer = [UInt8](repeating: 0, count: length)
      var reportLength = length

      let result = IOHIDDeviceGetReport(
        device,
        kIOHIDReportTypeInput,
        0,
        &buffer,
        &reportLength
      )

      guard result == kIOReturnSuccess else {
        throw TransportError.readFailed(status: result)
      }

      return Data(buffer.prefix(reportLength))
    }
  }

  func write(_ data: Data) throws {
    try withLock {
      guard state.isOpen, let device = state.device else {
        throw TransportError.deviceDisconnected
      }

      var buffer = [UInt8](data)
      let result = IOHIDDeviceSetReport(
        device,
        kIOHIDReportTypeOutput,
        CFIndex(buffer[0]),
        &buffer,
        buffer.count
      )

      guard result == kIOReturnSuccess else {
        NSLog("[HIDDeviceHandle] Write failed: \(result)")
        throw TransportError.writeFailed(status: result)
      }
    }
  }

  func setInputReportCallback(_ callback: @escaping (Data) -> Void) {
    lock.lock()
    state.inputReportCallback = callback
    lock.unlock()

    guard let device = state.device else { return }

    var buffer = [UInt8](repeating: 0, count: 64)
    let context = Unmanaged.passUnretained(self).toOpaque()
    IOHIDDeviceRegisterInputReportCallback(
      device,
      &buffer,
      buffer.count,
      { context, result, sender, type, reportID, report, reportLength in
        guard let context = context else { return }
        let handle = Unmanaged<HIDDeviceHandle>.fromOpaque(context).takeUnretainedValue()

        if result == kIOReturnSuccess {
          let data = Data(bytes: report, count: reportLength)
          handle.lock.lock()
          let callback = handle.state.inputReportCallback
          handle.lock.unlock()
          callback?(data)
        }
      },
      context
    )
  }

  private func withLock<T>(_ body: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
  }
}
