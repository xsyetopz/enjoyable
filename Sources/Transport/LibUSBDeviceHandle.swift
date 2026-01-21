import Foundation
import LibUSB

final class LibUSBDeviceHandle: DeviceHandle, Sendable {
  private final class State: @unchecked Sendable {
    var isOpen: Bool = false
    var deviceHandle: OpaquePointer?
    var detachedDriver: Bool = false
  }

  private let vendorId: UInt16
  private let productId: UInt16
  private let interfaceNumber: Int32
  private let endpointIn: UInt8
  private let endpointOut: UInt8

  private let state = State()
  private let lock = NSLock()

  nonisolated(unsafe) private static var context: OpaquePointer?
  nonisolated(unsafe) private static var contextLock = NSLock()

  init(
    vendorId: UInt16,
    productId: UInt16,
    interfaceNumber: Int32 = 0,
    endpointIn: UInt8,
    endpointOut: UInt8
  ) {
    self.vendorId = vendorId
    self.productId = productId
    self.interfaceNumber = interfaceNumber
    self.endpointIn = endpointIn
    self.endpointOut = endpointOut
  }

  deinit {
    close()
  }

  private static func getContext() throws -> OpaquePointer {
    contextLock.lock()
    defer { contextLock.unlock() }

    if let ctx = context {
      return ctx
    }

    var ctx: OpaquePointer?
    let result = libusb_init(&ctx)
    guard result == LIBUSB_SUCCESS, let validCtx = ctx else {
      NSLog("[LibUSBDeviceHandle] Failed to init libusb: \(result)")
      throw TransportError.openFailed
    }

    context = validCtx
    return validCtx
  }

  func open() throws {
    try withLock {
      guard !state.isOpen else { return }

      let ctx = try Self.getContext()

      guard let handle = libusb_open_device_with_vid_pid(ctx, vendorId, productId) else {
        NSLog("[LibUSBDeviceHandle] Failed to open device VID=\(vendorId), PID=\(productId)")
        NSLog(
          "[LibUSBDeviceHandle] You may need to install libusb via `brew install libusb`"
        )
        throw TransportError.deviceNotFound
      }

      state.deviceHandle = handle

      let resetResult = libusb_reset_device(handle)
      if resetResult == LIBUSB_SUCCESS {
        usleep(500_000)
      } else {
        NSLog("[LibUSBDeviceHandle] Device reset failed: \(resetResult) (cycling anyway)")
      }

      let driverActive = libusb_kernel_driver_active(handle, interfaceNumber)
      if driverActive == 1 {
        NSLog("[LibUSBDeviceHandle] Kernel driver active, detaching...")
        let detachResult = libusb_detach_kernel_driver(handle, interfaceNumber)
        if detachResult == LIBUSB_SUCCESS {
          state.detachedDriver = true
        } else {
          NSLog("[LibUSBDeviceHandle] Failed to detach kernel driver: \(detachResult)")
        }
      } else {
        NSLog("[LibUSBDeviceHandle] No kernel driver active")
      }

      let claimResult = libusb_claim_interface(handle, interfaceNumber)
      guard claimResult == LIBUSB_SUCCESS else {
        NSLog("[LibUSBDeviceHandle] Failed to claim interface: \(claimResult)")
        close()
        throw TransportError.openFailed
      }

      state.isOpen = true
    }
  }

  func close() {
    lock.lock()
    defer { lock.unlock() }

    guard state.isOpen, let handle = state.deviceHandle else { return }

    let releaseResult = libusb_release_interface(handle, interfaceNumber)
    if releaseResult != LIBUSB_SUCCESS {
      NSLog("[LibUSBDeviceHandle] Failed to release interface: \(releaseResult)")
    }

    if state.detachedDriver {
      let attachResult = libusb_attach_kernel_driver(handle, interfaceNumber)
      if attachResult == LIBUSB_SUCCESS {
        NSLog("[LibUSBDeviceHandle] Kernel driver reattached")
      } else {
        NSLog("[LibUSBDeviceHandle] Failed to reattach kernel driver: \(attachResult)")
      }
      state.detachedDriver = false
    }

    libusb_close(handle)
    state.deviceHandle = nil
    state.isOpen = false

    NSLog("[LibUSBDeviceHandle] Device closed")
  }

  func read(_ length: Int) throws -> Data {
    try withLock {
      guard state.isOpen, let handle = state.deviceHandle else {
        throw TransportError.deviceDisconnected
      }

      var buffer = [UInt8](repeating: 0, count: length)
      var actualLength: Int32 = 0

      let result = buffer.withUnsafeMutableBufferPointer { bufferPtr in
        libusb_interrupt_transfer(
          handle,
          endpointIn,
          bufferPtr.baseAddress,
          Int32(length),
          &actualLength,
          1000
        )
      }

      guard result == LIBUSB_SUCCESS || result == LIBUSB_ERROR_TIMEOUT else {
        throw TransportError.readFailed(status: IOReturn(result))
      }

      return Data(buffer.prefix(Int(actualLength)))
    }
  }

  func write(_ data: Data) throws {
    try withLock {
      guard state.isOpen, let handle = state.deviceHandle else {
        throw TransportError.deviceDisconnected
      }

      var buffer = [UInt8](data)
      var actualLength: Int32 = 0
      let bufferCount = buffer.count

      let result = buffer.withUnsafeMutableBufferPointer { bufferPtr in
        libusb_interrupt_transfer(
          handle,
          endpointOut,
          bufferPtr.baseAddress,
          Int32(bufferCount),
          &actualLength,
          1000
        )
      }

      guard result == LIBUSB_SUCCESS else {
        NSLog("[LibUSBDeviceHandle] Write failed: \(result)")
        throw TransportError.writeFailed(status: IOReturn(result))
      }

      guard actualLength == bufferCount else {
        NSLog("[LibUSBDeviceHandle] Partial write: \(actualLength)/\(bufferCount)")
        throw TransportError.writeFailed(status: -1)
      }
    }
  }

  func registerInputCallback(_ callback: @escaping (Data) -> Void) throws {
  }

  private func withLock<T>(_ block: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try block()
  }
}
