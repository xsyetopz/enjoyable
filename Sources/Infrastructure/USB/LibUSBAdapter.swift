import Configuration
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
      NSLog("[LibUSBAdapter] Initialization failed: \(reason)")
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
  private let _configMatcher: ConfigurationMatcher

  public init() throws {
    self._context = try USBContext()
    self._configMatcher = ConfigurationMatcher()
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
    NSLog("[LibUSBAdapter] connect() called for \(deviceID.vendorID):\(deviceID.productID)")
    
    if _connectedDevices[deviceID] != nil {
      if let cachedDevice = _deviceCache[deviceID] {
        return Core.GamepadDevice(
          vendorID: deviceID.vendorID,
          productID: deviceID.productID,
          deviceName: _getDeviceName(from: cachedDevice),
          connectionState: .connected
        )
      }
    }
    
    var device: LibUSB.USBDevice?

    if let cachedDevice = _deviceCache[deviceID] {
      device = cachedDevice
    } else {
      device = try await _findDevice(deviceID: deviceID)
    }

    guard let foundDevice = device else {
      NSLog("[LibUSBAdapter] Device not found in cache or USB scan")
      throw LibUSBAdapterError.usbError(.noDevice)
    }

    NSLog("[LibUSBAdapter] Found device, attempting to open...")
    let handle = try foundDevice.open()
    NSLog("[LibUSBAdapter] Device opened successfully")
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

    do {
      try handle.setAutoDetachKernelDriver(enable: true)
      NSLog("[LibUSBAdapter] Auto-detach kernel driver enabled")
    } catch {
      NSLog("[LibUSBAdapter] Failed to enable auto-detach kernel driver: \(error)")
    }

    let kernelDriverActive = handle.kernelDriverActive(interfaceNumber: 0)
    if kernelDriverActive {
      do {
        try handle.detachKernelDriver(interfaceNumber: 0)
        NSLog("[LibUSBAdapter] Kernel driver detached from interface 0")
      } catch _ as LibUSB.USBError {
        NSLog("[LibUSBAdapter] LibUSB error while detaching kernel driver (continuing)")
      } catch {
        throw LibUSBAdapterError.initializationFailed(
          "Failed to detach kernel driver from interface 0: \(error)"
        )
      }
    } else {
      NSLog("[LibUSBAdapter] No kernel driver active on interface 0")
    }

    do {
      try handle.setConfiguration(configuration: 1)
    } catch {
      NSLog("[LibUSBAdapter] Failed to set configuration: \(error)")
    }

    do {
      try handle.claimInterface(interfaceNumber: 0)
    } catch let error as LibUSB.USBError {
      throw LibUSBAdapterError.initializationFailed("Failed to claim interface 0: \(error)")
    } catch {
      throw LibUSBAdapterError.initializationFailed("Failed to claim interface 0: \(error)")
    }

    let config = _configMatcher.bestConfiguration(
      vendorId: Int(deviceID.vendorID),
      productId: Int(deviceID.productID)
    )

    if config == nil {
      NSLog(
        "[LibUSBAdapter] No configuration found for device \(deviceID.vendorID):\(deviceID.productID)"
      )
    } else {
      NSLog(
        "[LibUSBAdapter] Found config: \(config?.device.name ?? "unknown"), init steps: \(config?.initialization.count ?? 0)"
      )
    }

    if let initialization = config?.initialization {
      for (index, step) in initialization.enumerated() {
        NSLog("[LibUSBAdapter] Executing init step \(index): \(step.description)")
        do {
          try await _executeInitStep(step, handle: handle, device: device)
          NSLog("[LibUSBAdapter] Step \(index) completed")
        } catch {
          NSLog("[LibUSBAdapter] Step \(index) failed: \(error)")
          throw error
        }
      }
    }

    if let quirks = config?.quirks {
      for quirk in quirks {
        if quirk.isEnabled() {
          try await _applyQuirk(quirk, handle: handle, device: device)
        }
      }
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
      NSLog("[LibUSBAdapter] Failed to get active configuration descriptor: \(error)")
    }

    return 0x02
  }

  private func _executeInitStep(
    _ step: InitStep,
    handle: LibUSB.USBDeviceHandle,
    device: LibUSB.USBDevice
  ) async throws {
    let timeout = UInt32(step.timeout ?? 1000)

    switch step.type {
    case .control:
      if let dataBytes = step.dataBytes {
        let bmRequestType = UInt8(step.requestType ?? 0x21)
        let bRequest = UInt8(step.request ?? 0x09)
        let wValue = UInt16(step.value ?? 0x0200)
        let wIndex = UInt16(step.index ?? 0)

        _ = try handle.writeControl(
          requestType: bmRequestType,
          request: bRequest,
          value: wValue,
          index: wIndex,
          data: [UInt8](dataBytes),
          timeout: timeout
        )
      }

    case .interrupt:
      if let endpointAddress = step.endpoint {
        if let dataBytes = step.dataBytes {
          _ = try handle.writeInterrupt(
            endpointAddress: UInt8(endpointAddress),
            data: [UInt8](dataBytes),
            timeout: timeout
          )
        }
      }

    case .bulk:
      if let endpointAddress = step.endpoint {
        if let dataBytes = step.dataBytes {
          _ = try handle.writeBulk(
            endpointAddress: UInt8(endpointAddress),
            data: [UInt8](dataBytes),
            timeout: timeout
          )
        }
      }

    case .gip:
      if let dataBytes = step.dataBytes {
        let endpoint = _findGIPOutEndpoint(device: device)
        NSLog(
          "[LibUSBAdapter] Sending GIP packet to endpoint 0x%02X: %@",
          endpoint,
          dataBytes.map { String(format: "%02X", $0) }.joined()
        )
        _ = try handle.writeInterrupt(
          endpointAddress: endpoint,
          data: [UInt8](dataBytes),
          timeout: timeout
        )
        NSLog("[LibUSBAdapter] GIP packet sent")
      }
    }

    if let command = step.command, command.contains("delay") {
      let delayMs = step.timeout ?? 50
      try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
    }
  }

  private func _applyQuirk(
    _ quirk: DeviceQuirk,
    handle: LibUSB.USBDeviceHandle,
    device: LibUSB.USBDevice
  ) async throws {
    switch quirk.name {
    case "delayedInit":
      if let delayParam = quirk.parameter(named: "delayMs") {
        let delayMs = delayParam.intValue ?? delayParam.doubleValue.map { Int($0) } ?? 50
        try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
      }
    case "skipKernelDriver":
      break
    case "customEndpoint":
      if let endpointParam = quirk.parameter(named: "interruptIn") {
        _ = endpointParam.intValue
      }

    default:
      break
    }
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

      do {
        try handle.releaseInterface(interfaceNumber: 0)
        NSLog("[LibUSBAdapter] Released interface 0 for device \(deviceID)")
      } catch {
        NSLog("[LibUSBAdapter] Failed to release interface 0: \(error)")
      }

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
      NSLog("[LibUSBAdapter] Failed to send GIP LED off packet: \(error)")
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
      NSLog("[LibUSBAdapter] Failed to get active configuration descriptor: \(error)")
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
      NSLog("[LibUSBAdapter] Failed to get active configuration descriptor: \(error)")
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
