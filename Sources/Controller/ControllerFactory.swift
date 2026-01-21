import Foundation

final class ControllerFactory: Sendable {
  private let indexLoader: ControllerIndexLoader
  private let protocolDetector: ProtocolDetector
  private let transport: TransportProtocol

  init(
    transport: TransportProtocol,
    indexLoader: ControllerIndexLoader = ControllerIndexLoader(),
    protocolDetector: ProtocolDetector = ProtocolDetector()
  ) {
    self.transport = transport
    self.indexLoader = indexLoader
    self.protocolDetector = protocolDetector
  }

  func create(candidate: DeviceCandidate) async throws -> ControllerDevice {
    NSLog(
      "[ControllerFactory] Looking up config for VID=\(candidate.vendorId), PID=\(candidate.productId)"
    )
    let config = try getConfiguration(
      vendorId: candidate.vendorId,
      productId: candidate.productId
    )

    let endpointIn = config.endpoints?.in ?? 0x81
    let endpointOut = config.endpoints?.out ?? 0x02

    var deviceOpened = false
    var lastError: Error?

    NSLog("[ControllerFactory] Attempting libusb device access...")
    let libusbDevice = LibUSBDeviceHandle(
      vendorId: candidate.vendorId,
      productId: candidate.productId,
      endpointIn: endpointIn,
      endpointOut: endpointOut
    )
    do {
      try libusbDevice.open()
      transport.registerDevice(candidate.id, device: libusbDevice)
      deviceOpened = true
    } catch {
      NSLog("[ControllerFactory] libusb failed: \(error)")
      lastError = error
    }

    if !deviceOpened && config.protocolType == .gip {
      NSLog("[ControllerFactory] Attempting HID device access for GIP protocol...")
      let hidDevice = HIDDeviceHandle(
        vendorId: candidate.vendorId,
        productId: candidate.productId
      )
      do {
        try hidDevice.open()
        transport.registerDevice(candidate.id, device: hidDevice)
        deviceOpened = true
      } catch {
        NSLog("[ControllerFactory] HID failed: \(error)")
        lastError = error
      }
    }

    if !deviceOpened, let ioObject = candidate.ioObject {
      NSLog("[ControllerFactory] Attempting IOKit USB device access...")
      let usbDevice = USBDeviceHandle(
        ioObject: ioObject,
        endpointIn: endpointIn,
        endpointOut: endpointOut
      )
      do {
        try usbDevice.open()
        transport.registerDevice(candidate.id, device: usbDevice)
        deviceOpened = true
      } catch {
        NSLog("[ControllerFactory] IOKit USB failed: \(error)")
        lastError = error
      }
    }

    guard deviceOpened else {
      NSLog("[ControllerFactory] All device access methods failed")
      throw lastError
        ?? ControllerError.deviceNotSupported(
          vid: VendorId(candidate.vendorId),
          pid: ProductId(candidate.productId)
        )
    }

    let protocolHandler = createProtocolHandler(config: config)

    let device = ControllerDevice(
      candidate: candidate,
      transport: transport,
      protocolHandler: protocolHandler,
      config: config
    )

    return device
  }

  func getConfiguration(vendorId: VendorId, productId: ProductId) throws -> ControllerConfig {
    guard let config = try indexLoader.lookup(vendorId: vendorId, productId: productId) else {
      throw ControllerError.deviceNotSupported(vid: vendorId, pid: productId)
    }

    return config
  }

  func createWithAutoDetection(
    candidate: DeviceCandidate,
    ioObject: IOObject?
  ) async throws -> ControllerDevice {
    guard
      let detected = await protocolDetector.detectController(
        vendorId: candidate.vendorId,
        productId: candidate.productId,
        ioObject: ioObject
      )
    else {
      throw ControllerError.deviceNotSupported(vid: candidate.vendorId, pid: candidate.productId)
    }

    let transport = USBTransport()
    let protocolHandler = createProtocolHandler(config: detected.config)

    let device = ControllerDevice(
      candidate: candidate,
      transport: transport,
      protocolHandler: protocolHandler,
      config: detected.config
    )

    return device
  }

  private func createProtocolHandler(config: ControllerConfig) -> ProtocolHandlerProtocol {
    switch config.protocolType {
    case .gip:
      return GIPProtocolHandler(config: config)
    case .xinput:
      return XInputProtocolHandler(config: config)
    case .hid:
      return HIDProtocolHandler(config: config)
    case .switchHID:
      return SwitchHIDProtocolHandler(config: config)
    case .ps4HID:
      return PS4HIDProtocolHandler(config: config)
    case .ps5HID:
      return PS5HIDProtocolHandler(config: config)
    }
  }
}
