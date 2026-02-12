import Core
import Foundation

public actor USBWatchdog {
  private var _deviceMonitors: [USBDeviceID: DeviceMonitor] = [:]
  private var _watchdogTask: Task<Void, Never>?
  private let _stallTimeout: TimeInterval
  private let _checkInterval: TimeInterval
  private let _maxStallCount: Int
  private let _eventHandler: @Sendable (WatchdogEvent) -> Void

  public init(
    stallTimeout: TimeInterval = 5.0,
    checkInterval: TimeInterval = 1.0,
    maxStallCount: Int = 3,
    eventHandler: @escaping @Sendable (WatchdogEvent) -> Void = { _ in }
  ) {
    self._stallTimeout = stallTimeout
    self._checkInterval = checkInterval
    self._maxStallCount = maxStallCount
    self._eventHandler = eventHandler
  }

  public func startMonitoring(
    deviceID: USBDeviceID,
    reconnectHandler: @Sendable @escaping (USBDeviceID) async throws -> Void
  ) {
    guard _deviceMonitors[deviceID] == nil else {
      return
    }

    let monitor = DeviceMonitor(
      deviceID: deviceID,
      stallTimeout: _stallTimeout,
      maxStallCount: _maxStallCount,
      reconnectHandler: reconnectHandler,
      eventHandler: _eventHandler
    )

    _deviceMonitors[deviceID] = monitor

    if _watchdogTask == nil {
      _startWatchdogLoop()
    }
  }

  public func stopMonitoring(deviceID: USBDeviceID) {
    _deviceMonitors.removeValue(forKey: deviceID)

    if _deviceMonitors.isEmpty {
      _stopWatchdogLoop()
    }
  }

  public func recordActivity(deviceID: USBDeviceID) {
    _deviceMonitors[deviceID]?.recordActivity()
  }

  public func recordStall(deviceID: USBDeviceID) {
    _deviceMonitors[deviceID]?.recordStall()
  }

  public func getMonitorStatus(deviceID: USBDeviceID) -> MonitorStatus? {
    _deviceMonitors[deviceID]?.status
  }

  private func _startWatchdogLoop() {
    _watchdogTask = Task { [weak self] in
      guard let self = self else { return }

      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: UInt64(self._checkInterval * 1_000_000_000))

        await self._checkAllDevices()
      }
    }
  }

  private func _stopWatchdogLoop() {
    _watchdogTask?.cancel()
    _watchdogTask = nil
  }

  private func _checkAllDevices() async {
    let currentTime = Date()
    var stalledDevices: [USBDeviceID] = []

    for (deviceID, monitor) in _deviceMonitors {
      if monitor.isStalled(currentTime: currentTime) {
        stalledDevices.append(deviceID)
      }
    }

    for deviceID in stalledDevices {
      await _handleStalledDevice(deviceID: deviceID)
    }
  }

  private func _handleStalledDevice(deviceID: USBDeviceID) async {
    guard let monitor = _deviceMonitors[deviceID] else {
      return
    }

    let stallCount = monitor.incrementStallCount()

    let event = WatchdogEvent(
      type: .stallDetected,
      deviceID: deviceID,
      stallCount: stallCount,
      message: "USB device \(deviceID.stringValue) has stalled (\(stallCount)/\(_maxStallCount))"
    )
    _eventHandler(event)

    if stallCount >= _maxStallCount {
      let reconnectEvent = WatchdogEvent(
        type: .initiatingReconnect,
        deviceID: deviceID,
        message: "Initiating reconnection for stalled device \(deviceID.stringValue)"
      )
      _eventHandler(reconnectEvent)

      do {
        try await monitor.reconnect()

        let successEvent = WatchdogEvent(
          type: .reconnectSuccess,
          deviceID: deviceID,
          message: "Successfully reconnected device \(deviceID.stringValue)"
        )
        _eventHandler(successEvent)
      } catch {
        let failureEvent = WatchdogEvent(
          type: .reconnectFailed,
          deviceID: deviceID,
          error: error,
          message:
            "Failed to reconnect device \(deviceID.stringValue): \(error.localizedDescription)"
        )
        _eventHandler(failureEvent)

        _deviceMonitors.removeValue(forKey: deviceID)
      }
    }
  }
}

private class DeviceMonitor: @unchecked Sendable {
  let deviceID: USBDeviceID
  private let _stallTimeout: TimeInterval
  private let _maxStallCount: Int
  private var _reconnectHandler: @Sendable (USBDeviceID) async throws -> Void
  private var _eventHandler: @Sendable (WatchdogEvent) -> Void

  private var _lastActivityTime: Date
  private var _stallCount: Int
  private let _lock = NSLock()

  init(
    deviceID: USBDeviceID,
    stallTimeout: TimeInterval,
    maxStallCount: Int,
    reconnectHandler: @escaping @Sendable (USBDeviceID) async throws -> Void,
    eventHandler: @escaping @Sendable (WatchdogEvent) -> Void
  ) {
    self.deviceID = deviceID
    self._stallTimeout = stallTimeout
    self._maxStallCount = maxStallCount
    self._reconnectHandler = reconnectHandler
    self._eventHandler = eventHandler
    self._lastActivityTime = Date()
    self._stallCount = 0
  }

  func recordActivity() {
    _lock.lock()
    defer { _lock.unlock() }
    _lastActivityTime = Date()
  }

  func recordStall() {
    _lock.lock()
    defer { _lock.unlock() }
    _stallCount += 1
  }

  func isStalled(currentTime: Date) -> Bool {
    _lock.lock()
    defer { _lock.unlock() }
    return currentTime.timeIntervalSince(_lastActivityTime) > _stallTimeout
  }

  func incrementStallCount() -> Int {
    _lock.lock()
    defer { _lock.unlock() }
    _stallCount += 1
    return _stallCount
  }

  func reconnect() async throws {
    try await _reconnectHandler(deviceID)

    _lastActivityTime = Date()
  }

  var status: MonitorStatus {
    _lock.lock()
    defer { _lock.unlock() }
    return MonitorStatus(
      deviceID: deviceID,
      lastActivityTime: _lastActivityTime,
      stallCount: _stallCount,
      isStalled: Date().timeIntervalSince(_lastActivityTime) > _stallTimeout
    )
  }
}

public struct WatchdogEvent: Sendable {
  public let type: EventType
  public let deviceID: USBDeviceID?
  public let stallCount: Int?
  public let error: (any Error)?
  public let message: String

  public init(
    type: EventType,
    deviceID: USBDeviceID? = nil,
    stallCount: Int? = nil,
    error: (any Error)? = nil,
    message: String = ""
  ) {
    self.type = type
    self.deviceID = deviceID
    self.stallCount = stallCount
    self.error = error
    self.message = message
  }

  public enum EventType: Sendable {
    case stallDetected
    case initiatingReconnect
    case reconnectSuccess
    case reconnectFailed
    case deviceRegistered
    case deviceUnregistered
  }
}

public struct MonitorStatus: Sendable {
  public let deviceID: USBDeviceID
  public let lastActivityTime: Date
  public let stallCount: Int
  public let isStalled: Bool

  public var timeSinceLastActivity: TimeInterval {
    Date().timeIntervalSince(lastActivityTime)
  }
}
