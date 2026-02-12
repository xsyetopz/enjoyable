import Configuration
import Core
import Foundation
import Infrastructure
import LibUSB

public actor USBDeviceManager {
  private let _adapter: LibUSBAdapter
  private let _configMatcher: ConfigurationMatcher
  private var _connectedDevices: [Core.USBDeviceID: GamepadDevice] = [:]
  private var _deviceConfigurations: [Core.USBDeviceID: DeviceConfiguration] = [:]
  private var _deviceReadTasks: [Core.USBDeviceID: Task<Void, Never>] = [:]
  private var _keepaliveTasks: [Core.USBDeviceID: Task<Void, Never>] = [:]
  private let _eventHandler: @Sendable (USBDeviceEvent) -> Void

  public init(
    adapter: LibUSBAdapter,
    eventHandler: @escaping @Sendable (USBDeviceEvent) -> Void = { _ in }
  ) {
    self._adapter = adapter
    self._configMatcher = ConfigurationMatcher()
    self._eventHandler = eventHandler
  }

  public func start() async throws {
    try await rescanDevices()
  }

  public func stop() async {
    for deviceID in _keepaliveTasks.keys {
      await _cancelKeepaliveTask(for: deviceID)
    }
    for deviceID in _deviceReadTasks.keys {
      await _cancelReadTask(for: deviceID)
    }
  }

  public func rescanDevices() async throws {
    let detectedDevices = try await _adapter.scanDevices()

    if detectedDevices.isEmpty {
      return
    }

    for detectedDevice in detectedDevices {
      let deviceID = Core.USBDeviceID(
        vendorID: detectedDevice.vendorID,
        productID: detectedDevice.productID
      )

      if _connectedDevices[deviceID] == nil {
        await _connectDevice(deviceID: deviceID, detectedDevice: detectedDevice)
      }
    }
  }

  public func connect(deviceID: Core.USBDeviceID) async throws -> GamepadDevice {
    let libUSBDeviceID = LibUSB.USBDeviceID(
      vendorID: deviceID.vendorID,
      productID: deviceID.productID
    )

    let device = try await _adapter.connect(deviceID: libUSBDeviceID)
    _connectedDevices[deviceID] = device

    if let config = _configMatcher.bestConfiguration(
      vendorId: Int(deviceID.vendorID),
      productId: Int(deviceID.productID)
    ) {
      _deviceConfigurations[deviceID] = config
    }

    return device
  }

  public func disconnect(deviceID: Core.USBDeviceID) async throws {
    await _disconnectDevice(deviceID: deviceID)
  }

  public func getConnectedDevices() -> [GamepadDevice] {
    Array(_connectedDevices.values)
  }

  public func isConnected(_ deviceID: Core.USBDeviceID) -> Bool {
    _connectedDevices[deviceID] != nil
  }

  public func getDevice(_ deviceID: Core.USBDeviceID) -> GamepadDevice? {
    _connectedDevices[deviceID]
  }

  public func disconnectAll() async {
    let deviceIDs = Array(_connectedDevices.keys)
    for deviceID in deviceIDs {
      await _disconnectDevice(deviceID: deviceID)
    }
  }

  private func _connectDevice(deviceID: Core.USBDeviceID, detectedDevice: GamepadDevice) async {
    do {
      let libUSBDeviceID = LibUSB.USBDeviceID(
        vendorID: deviceID.vendorID,
        productID: deviceID.productID
      )

      if await _adapter.isDeviceOpen(deviceID: libUSBDeviceID) {
        return
      }

      let connectedDevice = try await _adapter.connect(deviceID: libUSBDeviceID)

      var updatedDevice = connectedDevice
      updatedDevice = GamepadDevice(
        vendorID: connectedDevice.vendorID,
        productID: connectedDevice.productID,
        deviceName: connectedDevice.deviceName,
        connectionState: .connected
      )

      _connectedDevices[deviceID] = updatedDevice

      if let config = _configMatcher.bestConfiguration(
        vendorId: Int(deviceID.vendorID),
        productId: Int(deviceID.productID)
      ) {
        _deviceConfigurations[deviceID] = config
      }

      let event = USBDeviceEvent(
        type: .connected,
        device: updatedDevice
      )
      _eventHandler(event)

      await _startReadTask(for: deviceID)
      await _enableControllerLED(deviceID: deviceID, libUSBDeviceID: libUSBDeviceID)
      await _startKeepaliveTask(for: deviceID, libUSBDeviceID: libUSBDeviceID)
    } catch {
      let failedDevice = GamepadDevice(
        vendorID: detectedDevice.vendorID,
        productID: detectedDevice.productID,
        deviceName: detectedDevice.deviceName,
        connectionState: .error
      )

      _connectedDevices[deviceID] = failedDevice

      let event = USBDeviceEvent(
        type: .error,
        device: failedDevice,
        error: error
      )
      _eventHandler(event)
    }
  }

  private func _enableControllerLED(
    deviceID: Core.USBDeviceID,
    libUSBDeviceID: LibUSB.USBDeviceID
  ) async {
    guard let config = _deviceConfigurations[deviceID] else {
      return
    }

    await _sendLEDOnCommand(deviceID: deviceID, libUSBDeviceID: libUSBDeviceID, config: config)
  }

  private func _sendLEDOnCommand(
    deviceID: Core.USBDeviceID,
    libUSBDeviceID: LibUSB.USBDeviceID,
    config: DeviceConfiguration
  ) async {
    guard
      let ledStep = config.initialization.first(where: { step in
        step.description.lowercased().contains("led")
          && (step.type == .control || step.type == .interrupt || step.type == .gip)
      })
    else {
      return
    }

    guard let dataBytes = ledStep.dataBytes else {
      return
    }

    do {
      _ = try await _adapter.writeReport(deviceID: libUSBDeviceID, data: [UInt8](dataBytes))
    } catch {
    }
  }

  private func _disconnectDevice(deviceID: Core.USBDeviceID) async {
    await _cancelKeepaliveTask(for: deviceID)
    await _cancelReadTask(for: deviceID)

    do {
      let libUSBDeviceID = LibUSB.USBDeviceID(
        vendorID: deviceID.vendorID,
        productID: deviceID.productID
      )
      _ = await _adapter.disconnect(deviceID: libUSBDeviceID)
    }

    guard let disconnectedDevice = _connectedDevices.removeValue(forKey: deviceID) else {
      return
    }

    _deviceConfigurations.removeValue(forKey: deviceID)

    let event = USBDeviceEvent(
      type: .disconnected,
      device: disconnectedDevice
    )
    _eventHandler(event)
  }

  private func _startReadTask(for deviceID: Core.USBDeviceID) async {
    let task = Task {
      await _continuousReadLoop(deviceID: deviceID)
    }

    _deviceReadTasks[deviceID] = task
  }

  private func _cancelReadTask(for deviceID: Core.USBDeviceID) async {
    guard let task = _deviceReadTasks.removeValue(forKey: deviceID) else {
      return
    }

    task.cancel()
    _ = await task.value
  }

  private func _startKeepaliveTask(
    for deviceID: Core.USBDeviceID,
    libUSBDeviceID: LibUSB.USBDeviceID
  ) async {
    guard let config = _deviceConfigurations[deviceID] else {
      return
    }

    guard _shouldStartKeepalive(config: config) else {
      return
    }

    let task = Task {
      await _keepaliveLoop(deviceID: deviceID, libUSBDeviceID: libUSBDeviceID, config: config)
    }

    _keepaliveTasks[deviceID] = task
  }

  private func _shouldStartKeepalive(config: DeviceConfiguration) -> Bool {
    return config.hasQuirk(named: "keepalive")
  }

  private func _getKeepalivePacket(config: DeviceConfiguration) -> [UInt8]? {
    if let keepaliveStep = config.initialization.first(where: { step in
      step.description.lowercased().contains("keepalive")
    }) {
      return keepaliveStep.dataBytes.map { [UInt8]($0) }
    }

    if let keepaliveQuirk = config.quirks.first(where: { $0.name == "keepalive" && $0.isEnabled() })
    {
      if let packetParam = keepaliveQuirk.parameter(named: "packet"),
        let packetString = packetParam.stringValue
      {
        return _parseHexString(packetString)
      }
    }

    return nil
  }

  private func _parseHexString(_ hexString: String) -> [UInt8]? {
    var bytes = [UInt8]()
    var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
    if hex.hasPrefix("0x") {
      hex = String(hex.dropFirst(2))
    }
    var index = hex.startIndex
    while index < hex.endIndex {
      let end = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
      if let byte = UInt8(hex[index..<end], radix: 16) {
        bytes.append(byte)
      }
      index = end
    }
    return bytes.isEmpty ? nil : bytes
  }

  private func _cancelKeepaliveTask(for deviceID: Core.USBDeviceID) async {
    guard let task = _keepaliveTasks.removeValue(forKey: deviceID) else {
      return
    }

    task.cancel()
    _ = await task.value
  }

  private func _keepaliveLoop(
    deviceID: Core.USBDeviceID,
    libUSBDeviceID: LibUSB.USBDeviceID,
    config: DeviceConfiguration
  ) async {
    guard let keepalivePacket = _getKeepalivePacket(config: config) else {
      return
    }

    do {
      _ = try await _adapter.writeReport(deviceID: libUSBDeviceID, data: keepalivePacket)
    } catch {
    }

    while !Task.isCancelled {
      do {
        try await Task.sleep(nanoseconds: 30_000_000_000)

        guard _connectedDevices[deviceID] != nil else {
          break
        }

        _ = try await _adapter.writeReport(deviceID: libUSBDeviceID, data: keepalivePacket)
      } catch {
      }
    }
  }

  private func _continuousReadLoop(deviceID: Core.USBDeviceID) async {
    let reportLength = 64
    var consecutiveErrors = 0
    let maxConsecutiveErrors = 5

    while !Task.isCancelled {
      do {
        let libUSBDeviceID = LibUSB.USBDeviceID(
          vendorID: deviceID.vendorID,
          productID: deviceID.productID
        )
        let report = try await _adapter.readReport(
          deviceID: libUSBDeviceID,
          length: reportLength
        )

        consecutiveErrors = 0
        await _processReport(deviceID: deviceID, report: report)
      } catch {
        consecutiveErrors += 1
        if consecutiveErrors >= maxConsecutiveErrors {
          await _handleReadError(deviceID: deviceID, error: error)
          break
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
      }
    }
  }

  private func _processReport(deviceID: Core.USBDeviceID, report: [UInt8]) async {
    guard let device = _connectedDevices[deviceID] else {
      return
    }

    let event = USBDeviceEvent(
      type: .inputReceived,
      device: device,
      report: report
    )
    _eventHandler(event)
  }

  private func _handleReadError(deviceID: Core.USBDeviceID, error: any Error) async {
    await _disconnectDevice(deviceID: deviceID)
  }
}

extension USBDeviceManager {
  public struct USBDeviceEvent: Sendable {
    public let type: EventType
    public let device: GamepadDevice
    public let report: [UInt8]?
    public let error: (any Error)?

    public init(
      type: EventType,
      device: GamepadDevice,
      report: [UInt8]? = nil,
      error: (any Error)? = nil
    ) {
      self.type = type
      self.device = device
      self.report = report
      self.error = error
    }
  }

  public enum EventType: Sendable {
    case connected
    case disconnected
    case inputReceived
    case error
  }
}
