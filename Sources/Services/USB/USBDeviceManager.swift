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
    if deviceID.vendorID == 0x045E || deviceID.vendorID == 0x3537 {
      let ledPacket: [UInt8] = [0x09, 0x09, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00]
      do {
        _ = try await _adapter.writeReport(deviceID: libUSBDeviceID, data: ledPacket)
      } catch {
      }
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
    guard deviceID.vendorID == 0x045E || deviceID.vendorID == 0x3537 else {
      return
    }

    let task = Task {
      await _keepaliveLoop(deviceID: deviceID, libUSBDeviceID: libUSBDeviceID)
    }

    _keepaliveTasks[deviceID] = task
  }

  private func _cancelKeepaliveTask(for deviceID: Core.USBDeviceID) async {
    guard let task = _keepaliveTasks.removeValue(forKey: deviceID) else {
      return
    }

    task.cancel()
    _ = await task.value
  }

  private func _keepaliveLoop(deviceID: Core.USBDeviceID, libUSBDeviceID: LibUSB.USBDeviceID) async
  {
    let motorCommand: [UInt8] = [0x09, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00]

    do {
      _ = try await _adapter.writeReport(deviceID: libUSBDeviceID, data: motorCommand)
    } catch {
    }

    while !Task.isCancelled {
      do {
        try await Task.sleep(nanoseconds: 30_000_000_000)

        guard _connectedDevices[deviceID] != nil else {
          break
        }

        _ = try await _adapter.writeReport(deviceID: libUSBDeviceID, data: motorCommand)
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
