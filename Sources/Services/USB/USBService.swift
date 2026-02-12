import Configuration
import Core
import Foundation
import Infrastructure
import LibUSB

  public actor USBService {
  private let _adapter: LibUSBAdapter
  private let _deviceManager: USBDeviceManager
  private let _discovery: USBDiscovery
  private var _scanTask: Task<Void, Never>?

  public init(
    adapter: LibUSBAdapter,
    eventHandler: @escaping @Sendable (USBDiscovery.DeviceMonitorEvent) -> Void = { _ in }
  ) {
    self._adapter = adapter
    self._deviceManager = USBDeviceManager(adapter: adapter)
    self._discovery = USBDiscovery(adapter: adapter, eventHandler: eventHandler)
  }

  public func startScanning(interval: UInt32 = Constants.USBTimeout.monitoringMs) {
    guard _scanTask == nil else { return }

    _scanTask = Task {
      await _discovery.startScanning(interval: interval)
    }
  }

  public func stopScanning() {
    _scanTask?.cancel()
    _scanTask = nil
  }

  public func connect(deviceID: Core.USBDeviceID) async throws -> GamepadDevice {
    try await _deviceManager.connect(deviceID: deviceID)
  }

  public func disconnect(deviceID: Core.USBDeviceID) async throws {
    try await _deviceManager.disconnect(deviceID: deviceID)
  }

  public func isConnected(deviceID: Core.USBDeviceID) async -> Bool {
    await _deviceManager.isConnected(deviceID)
  }

  public func getConnectedDevices() async -> [GamepadDevice] {
    await _deviceManager.getConnectedDevices()
  }

  public func getDevice(deviceID: Core.USBDeviceID) async -> GamepadDevice? {
    await _deviceManager.getDevice(deviceID)
  }

  public func deviceDiscoveryStream() async -> AsyncStream<[GamepadDevice]> {
    await _discovery.discoveryStream()
  }
}

extension USBService {
  public enum ServiceError: LocalizedError {
    case deviceNotFound
    case connectionFailed
    case scanFailed

    public var errorDescription: String? {
      switch self {
      case .deviceNotFound:
        return "Device not found"
      case .connectionFailed:
        return "Failed to connect to device"
      case .scanFailed:
        return "Failed to scan for devices"
      }
    }
  }

  public func toUSBError(_ error: ServiceError, deviceName: String? = nil) -> Core.USBError {
    switch error {
    case .deviceNotFound:
      if let deviceName = deviceName {
        return .deviceDisconnected(deviceName: deviceName)
      }
      return .scanFailed(underlyingError: "No devices found")
    case .connectionFailed:
      if let deviceName = deviceName {
        return .deviceNotResponding(deviceName: deviceName)
      }
      return .deviceNotResponding(deviceName: "Unknown")
    case .scanFailed:
      return .scanFailed(underlyingError: "USB scan operation failed")
    }
  }
}
