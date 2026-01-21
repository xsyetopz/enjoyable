@preconcurrency import Dispatch
import Foundation

final class ControllerEngine: Sendable {
  private final class State: @unchecked Sendable {
    var isRunning = false
    var passthroughMode = false
    var onDeviceAdded: ((ControllerDevice) -> Void)?
    var onDeviceRemoved: ((DeviceId) -> Void)?
    var onInputEvent: ((DeviceId, InputEvent) -> Void)?
  }

  private let transport: TransportProtocol
  private let factory: ControllerFactory
  private let registry: DeviceRegistry

  private let state = State()
  private let lock = NSLock()

  var onDeviceAdded: ((ControllerDevice) -> Void)? {
    get { withLock { state.onDeviceAdded } }
    set { withLock { state.onDeviceAdded = newValue } }
  }
  var onDeviceRemoved: ((DeviceId) -> Void)? {
    get { withLock { state.onDeviceRemoved } }
    set { withLock { state.onDeviceRemoved = newValue } }
  }
  var onInputEvent: ((DeviceId, InputEvent) -> Void)? {
    get { withLock { state.onInputEvent } }
    set { withLock { state.onInputEvent = newValue } }
  }

  var passthroughMode: Bool {
    get { withLock { state.passthroughMode } }
    set {
      let oldValue = withLock { state.passthroughMode }
      withLock { state.passthroughMode = newValue }
      if oldValue != newValue {
        Task {
          await handlePassthroughModeChange(enabled: newValue)
        }
      }
    }
  }

  init(
    transport: TransportProtocol = USBTransport(),
    factory: ControllerFactory? = nil,
    registry: DeviceRegistry = DeviceRegistry()
  ) {
    self.transport = transport
    self.factory = factory ?? ControllerFactory(transport: transport)
    self.registry = registry
  }

  func start() async throws {
    guard !getIsRunning() else { return }
    setIsRunning(true)

    try await transport.start()

    if !passthroughMode {
      let existingDevices = try await transport.enumerate()

      for candidate in existingDevices {
        await handleDeviceArrival(candidate)
      }
    } else {
      NSLog("[ControllerEngine] Passthrough mode enabled, not capturing devices")
    }
  }

  func stop() async throws {
    setIsRunning(false)

    let devices = await registry.getAll()
    for device in devices {
      try? await device.stop()
    }

    try await transport.stop()
  }

  func getDevices() async -> [ControllerDevice] {
    return await registry.getAll()
  }

  func getDevice(_ id: DeviceId) async -> ControllerDevice? {
    return await registry.get(id)
  }

  private func handleInputEvent(deviceId: DeviceId, event: InputEvent) async {
    let callback = getOnInputEvent()
    if let callback = callback {
      await MainActor.run { callback(deviceId, event) }
    }
  }

  private func handleDeviceArrival(_ candidate: DeviceCandidate) async {
    if passthroughMode {
      NSLog(
        "[ControllerEngine] Passthrough mode enabled, skipping device: [VID=\(candidate.vendorId), PID=\(candidate.productId)]..."
      )
      return
    }

    do {
      NSLog("[ControllerEngine] Creating device...")
      let device = try await factory.create(candidate: candidate)

      device.onInputEvent = { [weak self, device] event in
        guard let self = self else { return }
        Task {
          await self.handleInputEvent(deviceId: device.id, event: event)
        }
      }

      NSLog("[ControllerEngine] Starting device...")
      try await device.start()

      NSLog("[ControllerEngine] Registering device...")
      await registry.register(device)

      let callback = getOnDeviceAdded()
      if let callback = callback {
        await MainActor.run { callback(device) }
      }
    } catch {
      NSLog("[ControllerEngine] Failed to create device: \(error)")
    }
  }

  private func handleDeviceRemoval(_ deviceId: DeviceId) async {
    if let device = await registry.get(deviceId) {
      try? await device.stop()
      await registry.unregister(deviceId)

      let callback = getOnDeviceRemoved()
      if let callback = callback {
        await MainActor.run { callback(deviceId) }
      }
    }
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

  private func getOnInputEvent() -> ((DeviceId, InputEvent) -> Void)? {
    withLock { state.onInputEvent }
  }

  private func getOnDeviceAdded() -> ((ControllerDevice) -> Void)? {
    withLock { state.onDeviceAdded }
  }

  private func getOnDeviceRemoved() -> ((DeviceId) -> Void)? {
    withLock { state.onDeviceRemoved }
  }

  private func handlePassthroughModeChange(enabled: Bool) async {
    if enabled {
      NSLog("[ControllerEngine] Releasing all devices for native operation...")
      let devices = await registry.getAll()
      for device in devices {
        try? await device.stop()
        await registry.unregister(device.id)
      }
    } else {
      NSLog("[ControllerEngine] Re-capturing devices...")
      let candidates = try? await transport.enumerate()
      if let candidates = candidates {
        for candidate in candidates {
          await handleDeviceArrival(candidate)
        }
      }
    }
  }
}
