import Configuration
import Core
import Foundation
import Infrastructure
import Services

public actor ProfileCoordinator {
  private let _usbService: USBService
  private let _appCoordinator: AppCoordinator
  private let _contextDetector: ContextDetector
  private let _configurationManager: ConfigurationManager
  private let _mappingEngine: MappingEngine
  private let _mappingStore: MappingStore
  private let _contextStore: ContextStore
  private var _deviceChangeContinuation: AsyncStream<DeviceChangeEvent>.Continuation?
  private var _appChangeContinuation: AsyncStream<AppChangeEvent>.Continuation?
  private var _featureTasks: [Task<Void, Never>]

  public init(
    usbService: USBService,
    appCoordinator: AppCoordinator,
    contextDetector: ContextDetector,
    configurationManager: ConfigurationManager,
    mappingEngine: MappingEngine,
    mappingStore: MappingStore,
    contextStore: ContextStore
  ) {
    self._usbService = usbService
    self._appCoordinator = appCoordinator
    self._contextDetector = contextDetector
    self._configurationManager = configurationManager
    self._mappingEngine = mappingEngine
    self._mappingStore = mappingStore
    self._contextStore = contextStore
    self._featureTasks = []
  }

  public func startAutoProfileFeature() {
    let task = Task { [weak self] in
      guard let self = self else { return }

      let stream = await self._usbService.deviceDiscoveryStream()

      for await devices in stream {
        await self._handleDeviceChange(devices: devices)
      }
    }

    _featureTasks.append(task)
  }

  public func startAppContextFeature() {
    let task = Task { [weak self] in
      guard let self = self else { return }

      await self._contextDetector.startDetection { [weak self] context in
        Task { [weak self] in
          await self?._handleAppChange(context: context)
        }
      }
    }

    _featureTasks.append(task)
  }

  public func stopAllFeatures() {
    for task in _featureTasks {
      task.cancel()
    }
    _featureTasks.removeAll()

    Task { [weak self] in
      await self?._usbService.stopScanning()
      await self?._contextDetector.stopDetection()
    }
  }

  public func deviceChangeStream() -> AsyncStream<DeviceChangeEvent> {
    AsyncStream { continuation in
      _deviceChangeContinuation = continuation
      continuation.onTermination = { @Sendable _ in }
    }
  }

  public func appChangeStream() -> AsyncStream<AppChangeEvent> {
    AsyncStream { continuation in
      _appChangeContinuation = continuation
      continuation.onTermination = { @Sendable _ in }
    }
  }

  public func switchProfile(_ profile: Profile, deviceID: Core.USBDeviceID?) async {
    await _configurationManager.setActiveProfile(profile, for: deviceID)
    await _appCoordinator.setProfile(profile, for: deviceID)
  }

  public func executeMapping(actions: [MappingEngine.MappingAction]) async throws {
    for action in actions {
      try await _executeMappingAction(action: action)
    }
  }

  private func _handleDeviceChange(devices: [GamepadDevice]) async {
    for device in devices {
      let deviceID = Core.USBDeviceID(vendorID: device.vendorID, productID: device.productID)
      _deviceChangeContinuation?.yield(.connected(deviceID: deviceID))
      await _autoSwitchProfile(deviceID: deviceID)
    }
  }

  private func _handleAppChange(context: ContextStore.AppContext?) async {
    _appChangeContinuation?.yield(.changed(context: context))

    if let bundleIdentifier = context?.bundleIdentifier {
      await _autoSwitchProfileForApp(bundleIdentifier)
    }
  }

  private func _autoSwitchProfile(deviceID: Core.USBDeviceID) async {
    if let profile = await _configurationManager.findProfile(
      for: deviceID,
      appBundleIdentifier: nil
    ) {
      await switchProfile(profile, deviceID: deviceID)
    }
  }

  private func _autoSwitchProfileForApp(_ bundleIdentifier: String) async {
    let devices = await _usbService.getConnectedDevices()

    for device in devices {
      let deviceID = Core.USBDeviceID(vendorID: device.vendorID, productID: device.productID)
      if let profile = await _configurationManager.findProfile(
        for: deviceID,
        appBundleIdentifier: bundleIdentifier
      ) {
        await switchProfile(profile, deviceID: deviceID)
        return
      }
    }
  }

  private func _executeMappingAction(action: MappingEngine.MappingAction) async throws {
    switch action {
    case .map(let mapping):
      try await _appCoordinator.mapButtonDown(buttonIdentifier: mapping.buttonIdentifier)

    case .release(let mapping):
      try await _appCoordinator.mapButtonUp(buttonIdentifier: mapping.buttonIdentifier)

    case .macro(let macroAction, _):
      try await _executeMacroAction(action: macroAction)
    }
  }

  private func _executeMacroAction(action: MappingEngine.MacroAction) async throws {
    switch action {
    case .keyDown(let keyCode, _):
      try await _appCoordinator.mapButtonDown(buttonIdentifier: String(keyCode))

    case .keyUp(let keyCode, _):
      try await _appCoordinator.mapButtonUp(buttonIdentifier: String(keyCode))

    case .wait(let duration):
      try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

    case .mouseMove(let deltaX, let deltaY):
      try await _appCoordinator.moveMouse(deltaX: deltaX, deltaY: deltaY)

    case .mouseScroll(let deltaX, let deltaY):
      try await _appCoordinator.scrollMouse(deltaX: deltaX, deltaY: deltaY)

    case .mouseClick(_):
      try await _appCoordinator.clickMouse(button: CGEventAdapter.MouseButton.left)
    }
  }
}

extension ProfileCoordinator {
  public enum DeviceChangeEvent: Sendable {
    case connected(deviceID: Core.USBDeviceID)
    case disconnected(deviceID: Core.USBDeviceID)
    case error(deviceID: Core.USBDeviceID, message: String)
  }

  public enum AppChangeEvent: Sendable {
    case changed(context: ContextStore.AppContext?)
  }
}

extension ProfileCoordinator {
  public enum ProfileCoordinatorError: LocalizedError {
    case featureStartFailed
    case mappingExecutionFailed
    case autoProfileFailed

    public var errorDescription: String? {
      switch self {
      case .featureStartFailed:
        return "Failed to start feature"
      case .mappingExecutionFailed:
        return "Failed to execute mapping"
      case .autoProfileFailed:
        return "Auto-profile switching failed"
      }
    }
  }
}
