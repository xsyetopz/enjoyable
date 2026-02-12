import AppKit
import Configuration
import Core
import Foundation
import Infrastructure
import Services

public actor DriverCoordinator {
  private let _usbAdapter: LibUSBAdapter
  private let _outputAdapter: CGEventAdapter
  private let _profileStore: ProfileStore
  private var _usbService: USBService?
  private var _appCoordinator: AppCoordinator?
  private var _usbDiscovery: USBDiscovery?
  private var _contextDetector: ContextDetector?
  private var _configurationManager: ConfigurationManager?
  private var _mappingEngine: MappingEngine?
  private var _mappingStore: MappingStore?
  private var _contextStore: ContextStore?
  private var _driverStateManager: DriverStateManager?
  private var _sleepObserver: (any NSObjectProtocol)?
  private var _wakeObserver: (any NSObjectProtocol)?
  private var _systemEventTask: Task<Void, Never>?

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
    try? await _appCoordinator?.start()
    _startSystemEventMonitoring()
    _startDeviceScanning()

    _ = await _driverStateManager?.transition(to: .running)
  }

  public func stop() async throws {
    guard await _driverStateManager?.transition(to: .stopping) == true else {
      throw DriverStateManager.StateError.operationNotAllowed
    }

    _stopSystemEventMonitoring()
    _stopDeviceScanning()
    _cleanupDependencies()

    _ = await _driverStateManager?.transition(to: .stopped)
  }

  public func pause() async throws {
    guard await _driverStateManager?.transition(to: .pausing) == true else {
      throw DriverStateManager.StateError.operationNotAllowed
    }

    await _usbService?.stopScanning()
    _ = await _driverStateManager?.transition(to: .paused)
  }

  public func resume() async throws {
    guard await _driverStateManager?.transition(to: .running) == true else {
      throw DriverStateManager.StateError.operationNotAllowed
    }

    await _usbService?.startScanning()
  }

  public func getState() async -> DriverState {
    await _driverStateManager?.getState() ?? .stopped
  }

  public func getConnectedDevices() async -> [GamepadDevice] {
    await _usbService?.getConnectedDevices() ?? []
  }

  public func getActiveProfile() async -> Profile? {
    await _configurationManager?.getActiveProfile()
  }

  public func setActiveProfile(_ profile: Profile, deviceID: Core.USBDeviceID?) async {
    await _configurationManager?.setActiveProfile(profile, for: deviceID)
    await _appCoordinator?.setProfile(profile, for: deviceID)
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

  private func _initializeDependencies() {
    _usbService = USBService(adapter: _usbAdapter)
    _usbDiscovery = USBDiscovery(adapter: _usbAdapter) { _ in }
    _contextDetector = ContextDetector()
    _mappingEngine = MappingEngine()
    _mappingStore = MappingStore()
    _contextStore = ContextStore()
    _driverStateManager = DriverStateManager()

    let usbDeviceManager = USBDeviceManager(adapter: _usbAdapter)

    _appCoordinator = AppCoordinator(
      usbDeviceManager: usbDeviceManager,
      profileService: ProfileService(profileStore: _profileStore) { _ in },
      inputRouter: InputRouter { _ in },
      outputService: OutputService(cgEventAdapter: _outputAdapter) { _ in },
      eventHandler: { [weak self] event in
        Task { [weak self] in
          await self?._handleAppCoordinatorEvent(event)
        }
      }
    )

    _configurationManager = ConfigurationManager(profileStore: _profileStore)
  }

  private func _cleanupDependencies() {
    Task {
      await _usbDiscovery?.stopScanning()
      await _contextDetector?.stopDetection()
    }
    _usbService = nil
    _appCoordinator = nil
    _usbDiscovery = nil
    _contextDetector = nil
    _configurationManager = nil
    _mappingEngine = nil
    _mappingStore = nil
    _contextStore = nil
    _driverStateManager = nil
  }

  private func _startDeviceScanning() {
    Task {
      await _usbService?.startScanning()
      await _usbDiscovery?.startScanning()
      await _startContextDetection()
    }
  }

  private func _stopDeviceScanning() {
    Task {
      await _usbService?.stopScanning()
      await _usbDiscovery?.stopScanning()
    }
  }

  private func _startContextDetection() async {
    guard let contextDetector = _contextDetector else { return }

    await contextDetector.startDetection { [weak self] context in
      Task { [weak self] in
        await self?._handleContextChange(context)
      }
    }
  }

  private func _handleContextChange(_ context: ContextStore.AppContext?) async {
    guard let context = context else { return }
    await _contextStore?.updateContext(context)
  }

  private func _startSystemEventMonitoring() {
    let notificationCenter = NSWorkspace.shared.notificationCenter

    _sleepObserver = notificationCenter.addObserver(
      forName: NSWorkspace.willSleepNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { [weak self] in
        await self?._handleSystemSleep()
      }
    }

    _wakeObserver = notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { [weak self] in
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
    await _usbService?.stopScanning()
  }

  private func _handleSystemWake() async {
    await _usbService?.startScanning()
  }

  private func _handleAppCoordinatorEvent(_ event: AppCoordinator.AppCoordinatorEvent) async {
    switch event.type {
    case .deviceConnected:
      break
    case .deviceDisconnected:
      break
    case .inputProcessed:
      break
    case .profileChanged:
      break
    case .deviceError:
      break
    }
  }
}

extension DriverCoordinator {
  public enum CoordinatorError: LocalizedError {
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
