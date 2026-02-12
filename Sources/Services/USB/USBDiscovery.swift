import Core
import Foundation
import Infrastructure

public actor USBDiscovery {
  private let _adapter: LibUSBAdapter
  private var _scanTask: Task<Void, Never>?
  private var _deviceContinuation: AsyncStream<[GamepadDevice]>.Continuation?
  private var _lastKnownDevices: Set<Core.USBDeviceID> = []
  private let _eventHandler: @Sendable (DeviceMonitorEvent) -> Void

  public init(
    adapter: LibUSBAdapter,
    eventHandler: @escaping @Sendable (DeviceMonitorEvent) -> Void = { _ in }
  ) {
    self._adapter = adapter
    self._eventHandler = eventHandler
  }

  public func startScanning(interval: UInt32 = Constants.USBTimeout.monitoringMs) {
    guard _scanTask == nil else { return }

    _scanTask = Task {
      await _monitoringLoop(interval: interval)
    }
  }

  public func stopScanning() {
    _scanTask?.cancel()
    _scanTask = nil
  }

  public func performImmediateScan() async throws -> [GamepadDevice] {
    try await _adapter.scanDevices()
  }

  public func discoveryStream() -> AsyncStream<[GamepadDevice]> {
    AsyncStream { continuation in
      _deviceContinuation = continuation
      continuation.onTermination = { @Sendable _ in
      }
    }
  }

  private func _monitoringLoop(interval: UInt32) async {
    let scanInterval = UInt64(interval) * 1_000_000

    while !Task.isCancelled {
      do {
        let currentDevices = try await _adapter.scanDevices()
        let currentDeviceIDs = Set(
          currentDevices.map {
            Core.USBDeviceID(
              vendorID: $0.vendorID,
              productID: $0.productID
            )
          }
        )

        let newDevices = currentDeviceIDs.subtracting(_lastKnownDevices)
        let removedDevices = _lastKnownDevices.subtracting(currentDeviceIDs)

        for device in currentDevices {
          let deviceID = Core.USBDeviceID(
            vendorID: device.vendorID,
            productID: device.productID
          )

          if newDevices.contains(deviceID) {
            let event = DeviceMonitorEvent(
              type: .deviceDetected,
              device: device
            )
            _eventHandler(event)
          }
        }

        for deviceID in removedDevices {
          let event = DeviceMonitorEvent(
            type: .deviceRemoved,
            deviceID: deviceID
          )
          _eventHandler(event)
        }

        _lastKnownDevices = currentDeviceIDs
        _deviceContinuation?.yield(currentDevices)
      } catch {
        let event = DeviceMonitorEvent(
          type: .scanError,
          error: error
        )
        _eventHandler(event)
      }

      do {
        try await Task.sleep(nanoseconds: scanInterval)
      } catch {
        break
      }
    }
  }
}

extension USBDiscovery {
  public struct DeviceMonitorEvent: Sendable {
    public let type: EventType
    public let device: GamepadDevice?
    public let deviceID: Core.USBDeviceID?
    public let error: (any Error)?

    public init(
      type: EventType,
      device: GamepadDevice? = nil,
      deviceID: Core.USBDeviceID? = nil,
      error: (any Error)? = nil
    ) {
      self.type = type
      self.device = device
      self.deviceID = deviceID
      self.error = error
    }
  }

  public enum EventType: Sendable {
    case deviceDetected
    case deviceRemoved
    case scanError
  }
}
