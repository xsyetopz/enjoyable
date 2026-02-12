@preconcurrency import Core
import Foundation
@preconcurrency import LibUSB

public enum LibUSBAdapterError: LocalizedError {
  case usbError(LibUSB.USBError)
  case deviceNotFound
  case notConnected
  case invalidEndpoint
  case permissionDenied
  case noDevicesFound
  case initializationFailed(String)

  public var errorDescription: String? {
    switch self {
    case .usbError(let error):
      return error.errorDescription
    case .deviceNotFound:
      return "Device not found"
    case .notConnected:
      return "Device not connected"
    case .invalidEndpoint:
      return "Invalid endpoint"
    case .permissionDenied:
      return "Permission denied"
    case .noDevicesFound:
      return "No devices found"
    case .initializationFailed(let reason):
      return "Device initialization failed: \(reason)"
    }
  }
}

extension LibUSBAdapterError {
  func toUSBError(
    _ error: LibUSBAdapterError,
    deviceName: String? = nil
  ) -> Core.USBError {
    switch error {
    case .usbError(let usbError):
      switch usbError {
      case .access:
        return USBError.accessDenied(vendorID: 0, productID: 0)
      case .noDevice:
        return USBError.deviceDisconnected(deviceName: deviceName ?? "Unknown Device")
      case .busy:
        return USBError.deviceInUseByAnotherApp(
          deviceName: deviceName ?? "Unknown Device",
          appName: nil
        )
      case .timeout:
        return USBError.readTimeout(deviceName: deviceName ?? "Unknown Device")
      default:
        return USBError.busError(
          deviceName: deviceName ?? "Unknown Device",
          underlyingError: usbError.localizedDescription
        )
      }
    case .deviceNotFound:
      return USBError.deviceNotResponding(deviceName: deviceName ?? "Unknown Device")
    case .notConnected:
      return USBError.deviceNotResponding(deviceName: deviceName ?? "Unknown Device")
    case .invalidEndpoint:
      return USBError.invalidReportDescriptor(deviceName: deviceName ?? "Unknown Device")
    case .permissionDenied:
      return USBError.accessDenied(vendorID: 0, productID: 0)
    case .noDevicesFound:
      return USBError.scanFailed(underlyingError: "No USB devices found")
    case .initializationFailed(let reason):
      print("Initialization failed: \(reason)")
      return USBError.configurationError(
        deviceName: deviceName ?? "Unknown Device",
        configurationNumber: 0
      )
    }
  }
}

public actor LibUSBAdapter {
  private let _context: USBContext
  private var _connectedDevices: [LibUSB.USBDeviceID: LibUSB.USBDeviceHandle] = [:]
  private var _deviceCache: [LibUSB.USBDeviceID: LibUSB.USBDevice] = [:]

  public init() throws {
    self._context = try USBContext()
  }

  public func scanDevices() async throws -> [Core.GamepadDevice] {
    let devices = try await _context.getDeviceList()

    return devices.compactMap { device in
      let deviceID = device.deviceID
      if _isGamepadVendor(vendorID: deviceID.vendorID) {
        _deviceCache[deviceID] = device
        return Core.GamepadDevice(
          vendorID: deviceID.vendorID,
          productID: deviceID.productID,
          deviceName: _getDeviceName(from: device),
          connectionState: .disconnected
        )
      }
      return nil
    }
  }

  private func _isGamepadVendor(vendorID: UInt16) -> Bool {
    switch vendorID {
    case 0x045E, 0x054C, 0x057E, 0x3537, 0x2DC8, 0x1532, 0x046D, 0x0738, 0x0E6F, 0x24C6, 0x0F0D:
      return true
    default:
      return false
    }
  }

  public func connect(deviceID: LibUSB.USBDeviceID) async throws -> Core.GamepadDevice {
    var device: LibUSB.USBDevice?

    if let cachedDevice = _deviceCache[deviceID] {
      device = cachedDevice
    } else {
      device = try await _findDevice(deviceID: deviceID)
    }

    guard let foundDevice = device else {
      throw LibUSBAdapterError.usbError(.noDevice)
    }

    let handle = try foundDevice.open()
    _connectedDevices[deviceID] = handle
    _deviceCache[deviceID] = foundDevice

    try await _initializeDevice(handle: handle, device: foundDevice, deviceID: deviceID)

    return Core.GamepadDevice(
      vendorID: deviceID.vendorID,
      productID: deviceID.productID,
      deviceName: _getDeviceName(from: foundDevice),
      connectionState: .connected
    )
  }

  private func _initializeDevice(
    handle: LibUSB.USBDeviceHandle,
    device: LibUSB.USBDevice,
    deviceID: LibUSB.USBDeviceID
  ) async throws {
    do {
      try handle.setConfiguration(configuration: 1)
    } catch {
    }

    let kernelDriverActive = handle.kernelDriverActive(interfaceNumber: 0)
    if kernelDriverActive {
      do {
        try handle.detachKernelDriver(interfaceNumber: 0)
      } catch _ as LibUSB.USBError {
      } catch {
        throw LibUSBAdapterError.initializationFailed(
          "Failed to detach kernel driver from interface 0: \(error)"
        )
      }
    } else {
    }

    do {
      try handle.setConfiguration(configuration: 1)
    } catch {
    }

    do {
      try handle.claimInterface(interfaceNumber: 0)
    } catch let error as LibUSB.USBError {
      throw LibUSBAdapterError.initializationFailed("Failed to claim interface 0: \(error)")
    } catch {
      throw LibUSBAdapterError.initializationFailed("Failed to claim interface 0: \(error)")
    }

    if _requiresGIPInitialization(vendorID: deviceID.vendorID) {
      try await _sendGIPInitializationPackets(handle: handle, device: device)
    }
  }

  private func _requiresGIPInitialization(vendorID: UInt16) -> Bool {
    switch vendorID {
    case 0x045E, 0x3537:
      return true
    default:
      return false
    }
  }

  private func _sendGIPInitializationPackets(
    handle: LibUSB.USBDeviceHandle,
    device: LibUSB.USBDevice
  ) async throws {
    let endpoint = _findGIPOutEndpoint(device: device)
    let gipPackets: [[UInt8]] = [
      [0x05, 0x20, 0x00, 0x01, 0x00],
      [0x0A, 0x20, 0x00, 0x03, 0x00, 0x01, 0x14],
      [0x06, 0x20, 0x00, 0x02, 0x01, 0x00],
    ]

    for (_, packet) in gipPackets.enumerated() {
      let bytesWritten = try handle.writeInterrupt(
        endpointAddress: endpoint,
        data: packet,
        timeout: LibUSB.Config.Timeout.interruptTransfer
      )

      guard bytesWritten == packet.count else {
        throw LibUSBAdapterError.usbError(.io)
      }

      try await Task.sleep(nanoseconds: 50_000_000)
    }
  }

  private func _findGIPOutEndpoint(device: LibUSB.USBDevice) -> UInt8 {
    do {
      let config = try device.getActiveConfigurationDescriptor()
      for interface in config.getInterfaces() {
        let interfaceNumber = interface.interfaceNumber

        if interfaceNumber == 0 {
          for endpoint in interface.getEndpoints() {
            let epAddr = endpoint.address
            let epType = endpoint.transferType
            let epDir = endpoint.direction

            if epType == .interrupt && epDir == .out {
              return epAddr
            }
          }
        }
      }
    } catch {
    }

    return 0x02
  }

  private func _findDevice(deviceID: LibUSB.USBDeviceID) async throws -> LibUSB.USBDevice? {
    let allDevices = try await _context.getDeviceList()
    return allDevices.first { $0.deviceID == deviceID }
  }

  private func _getDeviceName(from device: LibUSB.USBDevice) -> String {
    do {
      let handle = try device.open()
      defer { handle.close() }

      if let product = try? device.getProductString(handle: handle) {
        return product
      }
    } catch {
    }

    return String(
      format: "USB Device %04X:%04X",
      device.deviceID.vendorID,
      device.deviceID.productID
    )
  }

  public func isDeviceOpen(deviceID: LibUSB.USBDeviceID) -> Bool {
    _connectedDevices[deviceID] != nil
  }

  public func disconnect(deviceID: LibUSB.USBDeviceID) async {
    if let handle = _connectedDevices[deviceID] {
      await _sendGIPLEDOff(handle: handle, deviceID: deviceID)

      handle.close()
      _connectedDevices.removeValue(forKey: deviceID)
      _deviceCache.removeValue(forKey: deviceID)
    }
  }

  private func _sendGIPLEDOff(handle: LibUSB.USBDeviceHandle, deviceID: LibUSB.USBDeviceID) async {
    guard deviceID.vendorID == 0x3537 || deviceID.vendorID == 0x045E else {
      return
    }

    let ledOffPacket: [UInt8] = [0x09, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

    do {
      guard let device = _deviceCache[deviceID] else {
        return
      }

      let endpoint = _findInterruptOutEndpoint(device: device)
      _ = try handle.writeInterrupt(
        endpointAddress: endpoint,
        data: ledOffPacket,
        timeout: LibUSB.Config.Timeout.interruptTransfer
      )
    } catch {
    }
  }

  public func readReport(
    deviceID: LibUSB.USBDeviceID,
    length: Int,
    timeout: UInt32 = Core.Constants.USBTimeout.interruptTransferMs
  ) async throws -> [UInt8] {
    guard let handle = _connectedDevices[deviceID] else {
      throw LibUSBAdapterError.notConnected
    }

    guard let device = _deviceCache[deviceID] else {
      throw LibUSBAdapterError.notConnected
    }

    let endpoint = _findInterruptInEndpoint(device: device)
    var buffer = [UInt8](repeating: 0, count: length)

    let bytesRead = try handle.interruptTransfer(
      endpointAddress: endpoint,
      data: &buffer,
      length: length,
      timeout: timeout
    )

    return Array(buffer.prefix(bytesRead))
  }

  private func _findInterruptInEndpoint(device: LibUSB.USBDevice) -> UInt8 {
    do {
      let config = try device.getActiveConfigurationDescriptor()
      for interface in config.getInterfaces() {
        for endpoint in interface.getEndpoints() {
          let epAddr = endpoint.address
          let epType = endpoint.transferType
          let epDir = endpoint.direction

          if epType == .interrupt && epDir == .input {
            return epAddr
          }
        }
      }
    } catch {
    }

    return 0x81
  }

  public func writeReport(
    deviceID: LibUSB.USBDeviceID,
    data: [UInt8],
    timeout: UInt32 = Core.Constants.USBTimeout.interruptTransferMs
  ) async throws -> Int {
    guard let handle = _connectedDevices[deviceID] else {
      throw LibUSBAdapterError.notConnected
    }

    guard let device = _deviceCache[deviceID] else {
      throw LibUSBAdapterError.notConnected
    }

    let endpoint = _findInterruptOutEndpoint(device: device)
    return try handle.writeInterrupt(endpointAddress: endpoint, data: data, timeout: timeout)
  }

  private func _findInterruptOutEndpoint(device: LibUSB.USBDevice) -> UInt8 {
    do {
      let config = try device.getActiveConfigurationDescriptor()
      for interface in config.getInterfaces() {
        for endpoint in interface.getEndpoints() {
          let epAddr = endpoint.address
          let epType = endpoint.transferType
          let epDir = endpoint.direction

          if epType == .interrupt && epDir == .out {
            return epAddr
          }
        }
      }
    } catch {
    }

    return 0x01
  }

  public func isConnected(_ deviceID: LibUSB.USBDeviceID) -> Bool {
    _connectedDevices[deviceID] != nil
  }

  public func getConnectedDevices() -> [LibUSB.USBDeviceID] {
    Array(_connectedDevices.keys)
  }

  public func setDebug(level: DebugLevel) async {
    await _context.setDebug(level: level.libusbLevel)
  }

  public enum DebugLevel: Sendable {
    case none
    case error
    case warning
    case info
    case debug

    var libusbLevel: LibUSB.DebugLevel {
      switch self {
      case .none: return .none
      case .error: return .error
      case .warning: return .warning
      case .info: return .info
      case .debug: return .debug
      }
    }
  }
}
