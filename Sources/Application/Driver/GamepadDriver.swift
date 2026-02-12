import AppKit
import Configuration
import Core
import Foundation
import Infrastructure
import Services

public actor GamepadDriver {
  private let _usbAdapter: LibUSBAdapter
  private let _outputAdapter: CGEventAdapter
  private let _profileStore: ProfileStore
  private var _driverStateManager: DriverStateManager?
  private var _configurationManager: ConfigurationManager?
  private var _driverCoordinator: DriverCoordinator?
  private var _profileCoordinator: ProfileCoordinator?
  private var _sleepObserver: (any NSObjectProtocol)?
  private var _wakeObserver: (any NSObjectProtocol)?

  public init() throws {
    self._usbAdapter = try LibUSBAdapter()
    self._outputAdapter = try CGEventAdapter()
    self._profileStore = ProfileStore()
  }

  public func start() async throws {
    guard await _driverStateManager?.transition(to: .starting) == true else {
      throw DriverStateManager.StateError.operationNotAllowed
    }

    _initializeDependencies()
    _startSystemEventMonitoring()
    try await _driverCoordinator?.start()
    await _profileCoordinator?.startAutoProfileFeature()
    await _profileCoordinator?.startAppContextFeature()
    _ = await _driverStateManager?.transition(to: .running)
  }

  public func stop() async throws {
    guard await _driverStateManager?.transition(to: .stopping) == true else {
      throw DriverStateManager.StateError.operationNotAllowed
    }

    await _profileCoordinator?.stopAllFeatures()
    try await _driverCoordinator?.stop()
    _stopSystemEventMonitoring()
    _cleanupDependencies()
    _ = await _driverStateManager?.transition(to: .stopped)
  }

  public func pause() async throws {
    guard await _driverStateManager?.transition(to: .pausing) == true else {
      throw DriverStateManager.StateError.operationNotAllowed
    }
    _ = await _driverStateManager?.transition(to: .paused)
  }

  public func resume() async throws {
    guard await _driverStateManager?.transition(to: .running) == true else {
      throw DriverStateManager.StateError.operationNotAllowed
    }
  }

  public func getState() async -> DriverState {
    await _driverStateManager?.getState() ?? .stopped
  }

  public func getConnectedDevices() async -> [GamepadDevice] {
    await _driverCoordinator?.getConnectedDevices() ?? []
  }

  public func getActiveProfile() async -> Profile? {
    await _configurationManager?.getActiveProfile()
  }

  public func setActiveProfile(_ profile: Profile, deviceID: Core.USBDeviceID?) async {
    await _configurationManager?.setActiveProfile(profile, for: deviceID)
  }

  public func loadProfile(named name: String) async throws -> Profile {
    try await _configurationManager?.loadProfile(named: name) ?? Profile.default
  }

  public func saveProfile(_ profile: Profile) async throws {
    try await _configurationManager?.saveProfile(profile)
  }

  public func addStateChangeHandler(_ handler: @escaping (DriverState) -> Void) {
    Task {
      await _driverStateManager?.addStateChangeHandler(handler)
    }
  }

  public nonisolated func deviceChangeStream() -> AsyncStream<ProfileCoordinator.DeviceChangeEvent>
  {
    AsyncStream { _ in }
  }

  public nonisolated func appChangeStream() -> AsyncStream<ProfileCoordinator.AppChangeEvent> {
    AsyncStream { _ in }
  }

  private func _initializeDependencies() {
    _driverStateManager = DriverStateManager()
    _configurationManager = ConfigurationManager(profileStore: _profileStore)

    let usbService = USBService(adapter: _usbAdapter)
    let contextDetector = ContextDetector()
    let mappingEngine = MappingEngine()
    let mappingStore = MappingStore()
    let contextStore = ContextStore()

    let usbDeviceManager = USBDeviceManager(adapter: _usbAdapter)
    let appCoordinator = AppCoordinator(
      usbDeviceManager: usbDeviceManager,
      profileService: ProfileService(profileStore: _profileStore) { _ in },
      inputRouter: InputRouter { _ in },
      outputService: OutputService(cgEventAdapter: _outputAdapter) { _ in },
      eventHandler: { _ in }
    )

    _driverCoordinator = try? DriverCoordinator()
    _profileCoordinator = ProfileCoordinator(
      usbService: usbService,
      appCoordinator: appCoordinator,
      contextDetector: contextDetector,
      configurationManager: _configurationManager!,
      mappingEngine: mappingEngine,
      mappingStore: mappingStore,
      contextStore: contextStore
    )
  }

  private func _cleanupDependencies() {
    _driverStateManager = nil
    _configurationManager = nil
    _driverCoordinator = nil
    _profileCoordinator = nil
  }

  private func _startSystemEventMonitoring() {
    let notificationCenter = NSWorkspace.shared.notificationCenter
    _sleepObserver = notificationCenter.addObserver(
      forName: NSWorkspace.willSleepNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task {
        await self?._handleSystemSleep()
      }
    }

    _wakeObserver = notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task {
        await self?._handleSystemWake()
      }
    }
  }

  private func _stopSystemEventMonitoring() {
    if let sleepObserver = _sleepObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver)
    }
    if let wakeObserver = _wakeObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
    }
    _sleepObserver = nil
    _wakeObserver = nil
  }

  private func _handleSystemSleep() async {
    do {
      try await pause()
    } catch {
      print("Error pausing driver before sleep: \(error)")
    }
  }

  private func _handleSystemWake() async {
    do {
      try await resume()
    } catch {
      print("Error resuming driver after wake: \(error)")
    }
  }
}

extension GamepadDriver {
  public enum DriverError: LocalizedError {
    case initializationFailed
    case startFailed
    case stopFailed
    case invalidState

    public var errorDescription: String? {
      switch self {
      case .initializationFailed:
        return "Failed to initialize driver"
      case .startFailed:
        return "Failed to start driver"
      case .stopFailed:
        return "Failed to stop driver"
      case .invalidState:
        return "Invalid driver state"
      }
    }
  }
}
