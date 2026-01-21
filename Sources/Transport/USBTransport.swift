@preconcurrency import Foundation
import IOKit
import IOUSBHost

final class USBTransport: TransportProtocol, @unchecked Sendable {
  private final class State: @unchecked Sendable {
    var notificationPort: IONotificationPortRef?
    var arrivalIterator: IOIterator = 0
    var removalIterator: IOIterator = 0
    var isRunning: Bool = false
    var registeredDevices: [DeviceId: any DeviceHandle] = [:]
    var onDeviceDiscovered: ((DeviceCandidate) -> Void)?
    var onDeviceRemoved: ((DeviceId) -> Void)?
  }

  private let state = State()
  private let lock = NSLock()

  var onDeviceDiscovered: ((DeviceCandidate) -> Void)? {
    get { withLock { state.onDeviceDiscovered } }
    set { withLock { state.onDeviceDiscovered = newValue } }
  }

  var onDeviceRemoved: ((DeviceId) -> Void)? {
    get { withLock { state.onDeviceRemoved } }
    set { withLock { state.onDeviceRemoved = newValue } }
  }

  init() {}

  func start() async throws {
    guard !getIsRunning() else { return }
    setIsRunning(true)

    state.notificationPort = IONotificationPortCreate(kIOMainPortDefault)

    let matchingDict = IOServiceMatching("IOUSBDevice") as NSMutableDictionary

    IOServiceAddMatchingNotification(
      state.notificationPort,
      kIOFirstMatchNotification,
      matchingDict,
      { context, iterator in
        guard context != nil else { return }
        let transport = Unmanaged<USBTransport>.fromOpaque(context!).takeUnretainedValue()
        Task {
          await transport.handleDeviceArrival(iterator)
        }
      },
      UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
      &state.arrivalIterator
    )

    let removalMatchingDict = IOServiceMatching("IOUSBDevice") as NSMutableDictionary

    IOServiceAddMatchingNotification(
      state.notificationPort,
      kIOTerminatedNotification,
      removalMatchingDict,
      { context, iterator in
        guard context != nil else { return }
        let transport = Unmanaged<USBTransport>.fromOpaque(context!).takeUnretainedValue()
        Task {
          await transport.handleDeviceRemoval(iterator)
        }
      },
      UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
      &state.removalIterator
    )

    IONotificationPortSetDispatchQueue(state.notificationPort, DispatchQueue.main)

    await handleDeviceArrival(state.arrivalIterator)
  }

  func stop() async throws {
    guard getIsRunning() else { return }
    setIsRunning(false)

    if state.arrivalIterator != 0 {
      if IOObjectRelease(state.arrivalIterator) != KERN_SUCCESS {
        NSLog("[USBTransport] Failed to release IO object")
      }
      setArrivalIterator(0)
    }

    if state.removalIterator != 0 {
      if IOObjectRelease(state.removalIterator) != KERN_SUCCESS {
        NSLog("[USBTransport] Failed to release IO object")
      }
      setRemovalIterator(0)
    }

    if let port = state.notificationPort {
      IONotificationPortDestroy(port)
      setNotificationPort(nil)
    }

    let deviceIds = getRegisteredDeviceIds()
    for deviceId in deviceIds {
      unregisterDevice(deviceId)
    }
  }

  func enumerate() async throws -> [DeviceCandidate] {
    var iterator: IOIterator = 0

    // `IOServiceGetMatchingServices` eats dict (per Apple docs)
    // Swift ARC, for some reason, DOES NOT know this, so... we manually add extra retain:
    // - `IOServiceMatching` returns +1, Swift manages it
    // - `passRetained` adds +1 (now +2 total)
    // - `IOServiceGetMatchingServices` consumes -1 (now +1)
    // - Swift ARC releases -1 when func returns (now 0)
    let dict = IOServiceMatching("IOUSBDevice")!
    _ = Unmanaged.passRetained(dict as CFDictionary)
    let result = IOServiceGetMatchingServices(kIOMainPortDefault, dict, &iterator)

    guard result == KERN_SUCCESS, iterator != 0 else {
      throw TransportError.enumerationFailed
    }

    var candidates: [DeviceCandidate] = []
    let detector = ProtocolDetector()

    while true {
      let device = IOIteratorNext(iterator)
      if device == 0 { break }

      if let vid: VendorId = device.getCFProperty(Constants.IOKitKeys.idVendorString),
        let pid: ProductId = device.getCFProperty(Constants.IOKitKeys.idProductString)
      {

        let detected = await detector.detectController(
          vendorId: vid,
          productId: pid,
          ioObject: device
        )
        let protocolType = detected?.protocolType ?? .xinput

        let name: String =
          device.getCFProperty(Constants.IOKitKeys.usbProductString) ?? "Unknown"
        let manufacturer: String =
          device.getCFProperty(Constants.IOKitKeys.usbVendorString) ?? ""
        let serialNumber: String =
          device.getCFProperty(Constants.IOKitKeys.usbSerialNumberString) ?? ""

        let candidate = DeviceCandidate(
          id: UUID(),
          transportType: .usb,
          protocolType: protocolType,
          vendorId: vid,
          productId: pid,
          name: name,
          manufacturer: manufacturer.isEmpty ? nil : manufacturer,
          serialNumber: serialNumber.isEmpty ? nil : serialNumber,
          ioObject: device
        )

        candidates.append(candidate)
      }

      if IOObjectRelease(device) != KERN_SUCCESS {
        NSLog("[USBTransport] Failed to release IO object")
      }
    }

    if iterator != 0 {
      let _ = IOObjectRelease(iterator)
    }

    let cleanCandidates = candidates.map { candidate in
      DeviceCandidate(
        id: candidate.id,
        transportType: candidate.transportType,
        protocolType: candidate.protocolType,
        vendorId: candidate.vendorId,
        productId: candidate.productId,
        name: "\(candidate.name)",
        manufacturer: candidate.manufacturer.map { "\($0)" },
        serialNumber: candidate.serialNumber.map { "\($0)" },
        ioObject: candidate.ioObject
      )
    }

    return cleanCandidates
  }

  func read(deviceId: DeviceId, endpoint: UInt8, length: Int) async throws -> Data {
    let device = getDevice(deviceId)
    guard let device = device else {
      throw TransportError.deviceDisconnected
    }

    return try await withCheckedThrowingContinuation { continuation in
      do {
        let data = try device.read(length)
        continuation.resume(returning: data)
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  func write(deviceId: DeviceId, endpoint: UInt8, data: Data) async throws {
    let device = getDevice(deviceId)
    guard let device = device else {
      throw TransportError.deviceDisconnected
    }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      do {
        try device.write(data)
        continuation.resume()
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  func registerDevice(_ deviceId: DeviceId, device: any DeviceHandle) {
    withLock { state.registeredDevices[deviceId] = device }
  }

  func unregisterDevice(_ deviceId: DeviceId) {
    let _ = withLock { state.registeredDevices.removeValue(forKey: deviceId) }
  }

  private func handleDeviceArrival(_ iterator: IOIterator) async {
    let detector = ProtocolDetector()

    while true {
      let device = IOIteratorNext(iterator)
      if device == 0 { break }

      do {
        let candidate = try await createDeviceCandidate(device, detector: detector)
        let callback = getOnDeviceDiscovered()
        if let callback = callback {
          await MainActor.run { callback(candidate) }
        }
      } catch {
        NSLog("[USBTransport] Failed to create device candidate: \(error.localizedDescription)")
      }

      if IOObjectRelease(device) != KERN_SUCCESS {
        NSLog("[USBTransport] Failed to release IO object")
      }
    }
  }

  private func handleDeviceRemoval(_ iterator: IOIterator) async {
    while true {
      let device = IOIteratorNext(iterator)
      if device == 0 { break }

      let deviceId = deviceIdFromIOObject(device)
      let callback = getOnDeviceRemoved()
      if let callback = callback {
        await MainActor.run { callback(deviceId) }
      }

      if IOObjectRelease(device) != KERN_SUCCESS {
        NSLog("[USBTransport] Failed to release IO object")
      }
    }
  }

  private func createDeviceCandidate(
    _ ioObject: IOObject,
    detector: ProtocolDetector
  ) async throws -> DeviceCandidate {
    guard let vid: VendorId = ioObject.getCFProperty(Constants.IOKitKeys.idVendorString),
      let pid: ProductId = ioObject.getCFProperty(Constants.IOKitKeys.idProductString)
    else { throw TransportError.propertyNotFound }

    let detectedProtocol = await detector.detectController(
      vendorId: vid,
      productId: pid,
      ioObject: ioObject
    )
    let protocolType = detectedProtocol?.protocolType ?? .xinput

    let name: String =
      ioObject.getCFProperty(Constants.IOKitKeys.usbProductString) ?? "Unknown"
    let manufacturer: String? = ioObject.getCFProperty(Constants.IOKitKeys.usbVendorString)
    let serialNumber: String? = ioObject.getCFProperty(
      Constants.IOKitKeys.usbSerialNumberString
    )
    return DeviceCandidate(
      id: UUID(),
      transportType: .usb,
      protocolType: protocolType,
      vendorId: vid,
      productId: pid,
      name: name,
      manufacturer: manufacturer,
      serialNumber: serialNumber,
      ioObject: ioObject
    )
  }

  private func deviceIdFromIOObject(_ ioObject: IOObject) -> DeviceId {
    if let vid: VendorId = ioObject.getCFProperty(Constants.IOKitKeys.idVendorString),
      let pid: ProductId = ioObject.getCFProperty(Constants.IOKitKeys.idProductString),
      let serial: String = ioObject.getCFProperty(Constants.IOKitKeys.usbSerialNumberString)
    {
      let combined = "\(vid):\(pid):\(serial)"
      return UUID(uuidString: combined.replacingOccurrences(of: "-", with: "")) ?? UUID()
    }
    return UUID()
  }

  private func withLock<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }

  private func getIsRunning() -> Bool {
    withLock { state.isRunning }
  }

  private func setIsRunning(_ value: Bool) {
    withLock { state.isRunning = value }
  }

  private func getDevice(_ deviceId: DeviceId) -> (any DeviceHandle)? {
    withLock { state.registeredDevices[deviceId] }
  }

  private func getRegisteredDeviceIds() -> [DeviceId] {
    withLock { Array(state.registeredDevices.keys) }
  }

  private func getOnDeviceDiscovered() -> ((DeviceCandidate) -> Void)? {
    withLock { state.onDeviceDiscovered }
  }

  private func getOnDeviceRemoved() -> ((DeviceId) -> Void)? {
    withLock { state.onDeviceRemoved }
  }

  private func setArrivalIterator(_ value: IOIterator) {
    withLock { state.arrivalIterator = value }
  }

  private func setRemovalIterator(_ value: IOIterator) {
    withLock { state.removalIterator = value }
  }

  private func setNotificationPort(_ value: IONotificationPortRef?) {
    withLock { state.notificationPort = value }
  }
}
