import Foundation
import IOKit
import IOKit.usb
import IOUSBHost

final class USBDeviceHandle: DeviceHandle, Sendable {
  private final class State: @unchecked Sendable {
    var isOpen: Bool = false
    var deviceInterface: UnsafeMutableRawPointer?
    var interfaceInterface: UnsafeMutableRawPointer?
  }

  private let ioObject: IOObject
  private let endpointIn: UInt8
  private let endpointOut: UInt8

  private let state = State()
  private let lock = NSLock()

  init(ioObject: IOObject, endpointIn: UInt8, endpointOut: UInt8) {
    self.ioObject = ioObject
    self.endpointIn = endpointIn
    self.endpointOut = endpointOut
  }

  deinit {
    close()
  }

  func open() throws {
    try withLock {
      guard !state.isOpen else { return }

      var plugInInterfacePtr: UnsafeMutableRawPointer?

      let score = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
      defer { score.deallocate() }

      guard let deviceTypeID = Constants.USB.ioUSBDeviceUserClientTypeID,
        let pluginInterfaceID = Constants.USB.ioCFPlugInInterfaceID
      else {
        throw TransportError.openFailed
      }

      let createResult = IOCreatePlugInInterfaceForServiceRaw(
        ioObject,
        deviceTypeID,
        pluginInterfaceID,
        &plugInInterfacePtr,
        score
      )

      guard createResult == Constants.IO.ioReturnSuccess,
        let plugInInterfaceRaw = plugInInterfacePtr
      else {
        NSLog("[USBDeviceHandle] Failed to create plugin interface: \(createResult)")
        throw TransportError.openFailed
      }

      defer {
        if IODestroyPlugInInterface(plugInInterfaceRaw) != KERN_SUCCESS {
          NSLog("[USBDeviceHandle] Failed to destroy plug-in interface")
        }
      }

      guard let queryInterface = IOKitInterface.getQueryInterface(plugInInterfaceRaw) else {
        throw TransportError.deviceNotFound
      }

      guard let deviceInterfaceID = Constants.USB.ioUSBDeviceInterfaceID else {
        throw TransportError.deviceNotFound
      }

      let deviceQuery = queryInterface(plugInInterfaceRaw, deviceInterfaceID)

      guard let deviceRawPtr = deviceQuery else {
        throw TransportError.deviceNotFound
      }

      state.deviceInterface = deviceRawPtr

      guard let openDevice = IOKitInterface.getDeviceOpen(deviceRawPtr) else {
        throw TransportError.openFailed
      }

      let openResult = openDevice(deviceRawPtr, 0)

      guard openResult == Constants.IO.ioReturnSuccess else {
        NSLog("[USBDeviceHandle] Failed to open device: \(openResult)")
        throw TransportError.openFailed
      }

      guard let interface = tryFindAndClaimInterface() else {
        if let closeDevice = IOKitInterface.getDeviceClose(deviceRawPtr) {
          if closeDevice(deviceRawPtr) != KERN_SUCCESS {
            NSLog("[USBDeviceHandle] Failed to close device")
          }
        }
        state.deviceInterface = nil
        throw TransportError.interfaceNotFound
      }

      state.interfaceInterface = interface
      state.isOpen = true
    }
  }

  func close() {
    lock.lock()
    defer { lock.unlock() }

    guard state.isOpen else { return }

    if let interfaceRawPtr = state.interfaceInterface {
      if let closeInterface = IOKitInterface.getInterfaceClose(interfaceRawPtr) {
        if closeInterface(interfaceRawPtr) != KERN_SUCCESS {
          NSLog("[USBDeviceHandle] Failed to close interface")
        }
      }
      state.interfaceInterface = nil
    }

    if let deviceRawPtr = state.deviceInterface {
      if let closeDevice = IOKitInterface.getDeviceClose(deviceRawPtr) {
        if closeDevice(deviceRawPtr) != KERN_SUCCESS {
          NSLog("[USBDeviceHandle] Failed to close device")
        }
      }
      state.deviceInterface = nil
    }

    state.isOpen = false
  }

  func read(_ length: Int) throws -> Data {
    try withLock {
      guard state.isOpen, let interfaceRawPtr = state.interfaceInterface else {
        throw TransportError.deviceDisconnected
      }

      guard let readPipe = IOKitInterface.getReadPipe(interfaceRawPtr) else {
        throw TransportError.deviceDisconnected
      }

      var buffer = [UInt8](repeating: 0, count: length)
      var bytesRead: UInt32 = 0

      let result = withUnsafeMutableBytes(of: &buffer) { bufferPtr in
        readPipe(
          interfaceRawPtr,
          endpointIn,
          bufferPtr.baseAddress,
          UInt32(length),
          &bytesRead,
          UnsafeMutableRawPointer(bitPattern: 0),
          UnsafeMutableRawPointer(bitPattern: 0),
          UnsafeMutableRawPointer(bitPattern: 0)
        )
      }

      guard
        result == Constants.IO.ioReturnSuccess || result == Constants.IO.ioUSBTransactionReturned
      else {
        throw TransportError.readFailed(status: result)
      }

      return Data(buffer.prefix(Int(bytesRead)))
    }
  }

  func write(_ data: Data) throws {
    try withLock {
      guard state.isOpen, let interfaceRawPtr = state.interfaceInterface else {
        throw TransportError.deviceDisconnected
      }

      guard let writePipe = IOKitInterface.getWritePipe(interfaceRawPtr) else {
        throw TransportError.deviceDisconnected
      }

      var buffer = [UInt8](data)
      var bytesWritten: UInt32 = 0

      let result = withUnsafeMutableBytes(of: &buffer) { bufferPtr in
        writePipe(
          interfaceRawPtr,
          endpointOut,
          bufferPtr.baseAddress,
          UInt32(data.count),
          &bytesWritten,
          Constants.Timeouts.usbWriteTimeoutMs,
          UnsafeMutableRawPointer(bitPattern: 0),
          UnsafeMutableRawPointer(bitPattern: 0)
        )
      }

      guard result == Constants.IO.ioReturnSuccess else {
        throw TransportError.writeFailed(status: result)
      }
    }
  }

  func readAsync(_ length: Int) async throws -> Data {
    return try await withCheckedThrowingContinuation { continuation in
      do {
        let data = try read(length)
        continuation.resume(returning: data)
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  func writeAsync(_ data: Data) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      do {
        try write(data)
        continuation.resume()
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  private func tryFindAndClaimInterface() -> UnsafeMutableRawPointer? {
    guard let deviceRawPtr = state.deviceInterface else { return nil }

    guard
      let createInterfaceIterator = IOKitInterface.getCreateInterfaceIterator(
        deviceRawPtr
      )
    else {
      return nil
    }

    var iterator: IOIterator = 0

    let result = createInterfaceIterator(deviceRawPtr, &iterator)
    guard result == Constants.IO.ioReturnSuccess else {
      return nil
    }

    defer {
      if iterator != 0 {
        if IOObjectRelease(iterator) != KERN_SUCCESS {
          NSLog("[USBDeviceHandle] Failed to release IO object")
        }
      }
    }

    while true {
      let interfaceObject = IOIteratorNext(iterator)
      if interfaceObject == 0 { break }

      if let interface = tryClaimInterface(interfaceObject) {
        if IOObjectRelease(interfaceObject) != KERN_SUCCESS {
          NSLog("[USBDeviceHandle] Failed to release IO object")
        }
        return interface
      }

      if IOObjectRelease(interfaceObject) != KERN_SUCCESS {
        NSLog("[USBDeviceHandle] Failed to release IO object")
      }
    }

    return nil
  }

  private func tryClaimInterface(_ interfaceObject: IOObject) -> UnsafeMutableRawPointer? {
    var plugInInterfacePtr: UnsafeMutableRawPointer?

    let score = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    defer { score.deallocate() }

    guard let interfaceUserClientTypeID = Constants.USB.ioUSBInterfaceUserClientTypeID,
      let pluginInterfaceID = Constants.USB.ioCFPlugInInterfaceID
    else {
      return nil
    }

    let createResult = IOCreatePlugInInterfaceForServiceRaw(
      interfaceObject,
      interfaceUserClientTypeID,
      pluginInterfaceID,
      &plugInInterfacePtr,
      score
    )
    guard createResult == kIOReturnSuccess,
      let plugInInterfaceRaw = plugInInterfacePtr
    else {
      return nil
    }

    defer {
      if IODestroyPlugInInterface(plugInInterfaceRaw) != KERN_SUCCESS {
        NSLog("[USBDeviceHandle] Failed to destroy plug-in interface")
      }
    }

    guard let queryInterface = IOKitInterface.getQueryInterface(plugInInterfaceRaw) else {
      return nil
    }

    guard let interfaceInterfaceID = Constants.USB.ioUSBInterfaceInterfaceID else {
      return nil
    }

    let interfaceQuery = queryInterface(
      plugInInterfaceRaw,
      interfaceInterfaceID
    )

    guard let interfaceRawPtr = interfaceQuery else {
      return nil
    }

    guard let openInterface = IOKitInterface.getInterfaceOpen(interfaceRawPtr) else {
      return nil
    }

    let openResult = openInterface(interfaceRawPtr)
    guard openResult == Constants.IO.ioReturnSuccess else {
      return nil
    }

    if interfaceHasEndpoints(interfaceRawPtr) {
      return interfaceRawPtr
    }

    if let closeInterface = IOKitInterface.getInterfaceClose(interfaceRawPtr) {
      if closeInterface(interfaceRawPtr) != KERN_SUCCESS {
        NSLog("[USBDeviceHandle] Failed to close interface")
      }
    }
    return nil
  }

  private func interfaceHasEndpoints(_ interfaceRawPtr: UnsafeMutableRawPointer) -> Bool {
    guard let getNumEndpoints = IOKitInterface.getNumEndpoints(interfaceRawPtr) else {
      return false
    }

    guard let getPipeProperties = IOKitInterface.getPipeProperties(interfaceRawPtr) else {
      return false
    }

    var numEndpoints: UInt8 = 0

    let result = getNumEndpoints(interfaceRawPtr, &numEndpoints)
    guard result == Constants.IO.ioReturnSuccess else {
      return false
    }

    var hasInEndpoint = false
    var hasOutEndpoint = false

    for i: UInt8 in 1...numEndpoints {
      var direction: UInt8 = 0
      var number: UInt8 = 0
      var transferType: UInt8 = 0
      var maxPacketSize: UInt16 = 0
      var interval: UInt8 = 0

      let result = getPipeProperties(
        interfaceRawPtr,
        i,
        &direction,
        &number,
        &transferType,
        &maxPacketSize,
        &interval
      )
      guard result == Constants.IO.ioReturnSuccess else {
        continue
      }

      if number == (endpointIn & 0x0F) && direction == Constants.USB.usbIn {
        hasInEndpoint = true
      }
      if number == endpointOut && direction == Constants.USB.usbOut {
        hasOutEndpoint = true
      }
    }

    return hasInEndpoint && hasOutEndpoint
  }

  private func withLock<T>(_ body: () throws -> T) throws -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
  }
}
