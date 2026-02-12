import Configuration
import Core
import CoreGraphics
import Foundation
import Infrastructure
import Protocol

public actor AppCoordinator {
  private let _usbDeviceManager: USBDeviceManager
  private let _profileService: ProfileService
  private let _inputRouter: InputRouter
  private let _outputService: OutputService
  private var _activeProfiles: [Core.USBDeviceID: Profile] = [:]
  private var _deviceToProfileMapping: [Core.USBDeviceID: String] = [:]
  private let _eventHandler: @Sendable (AppCoordinatorEvent) -> Void
  private var _inputEventContinuation: AsyncStream<InputRouter.ParsedInput>.Continuation?

  public init(
    usbDeviceManager: USBDeviceManager,
    profileService: ProfileService,
    inputRouter: InputRouter,
    outputService: OutputService,
    eventHandler: @escaping @Sendable (AppCoordinatorEvent) -> Void = { _ in }
  ) {
    self._usbDeviceManager = usbDeviceManager
    self._profileService = profileService
    self._inputRouter = inputRouter
    self._outputService = outputService
    self._eventHandler = eventHandler
  }

  public func start() async throws {
    let allProfiles = try await _profileService.loadAllProfiles()
    for profile in allProfiles {
      if let deviceID = profile.deviceID {
        _deviceToProfileMapping[deviceID] = profile.name
      }
    }
  }

  public func stop() async {
    try? await _outputService.releaseAllInputs()

    let virtualDeviceIDs = await _outputService.getAllVirtualDeviceIDs()
    for deviceID in virtualDeviceIDs {
      try? await _outputService.destroyVirtualDevice(for: deviceID)
    }
  }

  public func handleDeviceEvent(_ event: USBDeviceManager.USBDeviceEvent) async {
    switch event.type {
    case .connected:
      await _handleDeviceConnected(event)
    case .disconnected:
      await _handleDeviceDisconnected(event)
    case .inputReceived:
      await _handleInputReceived(event)
    case .error:
      await _handleDeviceError(event)
    }
  }

  private func _handleDeviceConnected(_ event: USBDeviceManager.USBDeviceEvent) async {
    guard let deviceID = event.deviceID else { return }

    let profileName = _deviceToProfileMapping[deviceID]
    let profile: Profile

    if let name = profileName {
      if let loadedProfile = try? await _profileService.loadProfile(named: name) {
        profile = loadedProfile
      } else {
        profile = Profile.default
      }
    } else {
      profile = Profile.default
    }

    _activeProfiles[deviceID] = profile

    await _inputRouter.registerDevice(deviceID: deviceID, profile: profile)

    let coordinatorEvent = AppCoordinatorEvent(
      type: .deviceConnected,
      device: event.device,
      profile: profile
    )
    _eventHandler(coordinatorEvent)
  }

  private func _handleDeviceDisconnected(_ event: USBDeviceManager.USBDeviceEvent) async {
    guard let deviceID = event.deviceID else { return }

    _activeProfiles.removeValue(forKey: deviceID)

    await _inputRouter.unregisterDevice(deviceID: deviceID)

    try? await _outputService.releaseAllInputs()

    let coordinatorEvent = AppCoordinatorEvent(
      type: .deviceDisconnected,
      device: event.device
    )
    _eventHandler(coordinatorEvent)
  }

  private func _handleInputReceived(_ event: USBDeviceManager.USBDeviceEvent) async {
    guard let report = event.report else {
      return
    }

    guard let deviceID = event.deviceID else { return }

    let profile = _activeProfiles[deviceID] ?? Profile.default

    let parsedInput = await _inputRouter.parseInput(
      deviceID: deviceID,
      report: report,
      profile: profile
    )

    do {
      try await _outputService.processOutput(input: parsedInput)
    } catch {
    }

    _inputEventContinuation?.yield(parsedInput)

    let coordinatorEvent = AppCoordinatorEvent(
      type: .inputProcessed,
      device: event.device,
      input: parsedInput
    )
    _eventHandler(coordinatorEvent)
  }

  private func _handleDeviceError(_ event: USBDeviceManager.USBDeviceEvent) async {
    let coordinatorEvent = AppCoordinatorEvent(
      type: .deviceError,
      device: event.device,
      error: event.error
    )
    _eventHandler(coordinatorEvent)
  }

  public func switchProfile(for deviceID: Core.USBDeviceID, to profileName: String) async throws {
    let profile = try await _profileService.loadProfile(named: profileName)

    _activeProfiles[deviceID] = profile
    _deviceToProfileMapping[deviceID] = profileName

    await _inputRouter.updateProfile(deviceID: deviceID, profile: profile)

    let coordinatorEvent = AppCoordinatorEvent(
      type: .profileChanged,
      device: await _usbDeviceManager.getDevice(deviceID),
      profile: profile
    )
    _eventHandler(coordinatorEvent)
  }

  public func setProfile(_ profile: Profile, for deviceID: Core.USBDeviceID?) async {
    if let deviceID = deviceID {
      _activeProfiles[deviceID] = profile
      _deviceToProfileMapping[deviceID] = profile.name
      await _inputRouter.updateProfile(deviceID: deviceID, profile: profile)
    }
  }

  public func getActiveProfile(for deviceID: Core.USBDeviceID) -> Profile? {
    _activeProfiles[deviceID]
  }

  public func getAllActiveDevices() async -> [GamepadDevice] {
    await _usbDeviceManager.getConnectedDevices()
  }

  public func mapButtonDown(buttonIdentifier: String) async throws {
    guard let mapping = _findButtonMapping(for: buttonIdentifier) else {
      throw AppCoordinatorError.invalidMapping("No mapping found for button: \(buttonIdentifier)")
    }

    let key = _activeInputKey(for: buttonIdentifier)
    guard _activeInputs[key] != true else {
      return
    }

    let inputState = InputRouter.InputState(
      buttonIdentifier: mapping.buttonIdentifier,
      keyCode: mapping.keyCode,
      modifier: mapping.modifier,
      isPressed: true
    )

    let deviceID = Core.USBDeviceID(vendorID: 0, productID: 0)
    let parsedInput = InputRouter.ParsedInput(
      deviceID: deviceID,
      timestamp: Date(),
      inputs: [inputState]
    )

    try await _outputService.processOutput(input: parsedInput)
    _activeInputs[key] = true
  }

  public func mapButtonUp(buttonIdentifier: String) async throws {
    guard let mapping = _findButtonMapping(for: buttonIdentifier) else {
      throw AppCoordinatorError.invalidMapping("No mapping found for button: \(buttonIdentifier)")
    }

    let key = _activeInputKey(for: buttonIdentifier)
    guard _activeInputs[key] == true else {
      return
    }

    let inputState = InputRouter.InputState(
      buttonIdentifier: mapping.buttonIdentifier,
      keyCode: mapping.keyCode,
      modifier: mapping.modifier,
      isPressed: false
    )

    let deviceID = Core.USBDeviceID(vendorID: 0, productID: 0)
    let parsedInput = InputRouter.ParsedInput(
      deviceID: deviceID,
      timestamp: Date(),
      inputs: [inputState]
    )

    try await _outputService.processOutput(input: parsedInput)
    _activeInputs[key] = false
  }

  public func moveMouse(deltaX: Double, deltaY: Double) async throws {
    do {
      try await _outputService.postMouseMove(deltaX: deltaX, deltaY: deltaY)
    } catch {
      throw AppCoordinatorError.mouseOperationFailed(
        "Move operation failed: \(error.localizedDescription)"
      )
    }
  }

  public func scrollMouse(deltaX: Double, deltaY: Double) async throws {
    do {
      try await _outputService.postMouseScroll(deltaX: deltaX, deltaY: deltaY)
    } catch {
      throw AppCoordinatorError.mouseOperationFailed(
        "Scroll operation failed: \(error.localizedDescription)"
      )
    }
  }

  public func clickMouse(button: CGEventAdapter.MouseButton, clickCount: Int = 1) async throws {
    do {
      try await _outputService.postMouseClick(button: button, clickCount: clickCount)
    } catch {
      throw AppCoordinatorError.mouseOperationFailed(
        "Click operation failed: \(error.localizedDescription)"
      )
    }
  }

  private func _findButtonMapping(for buttonIdentifier: String) -> Core.ButtonMapping? {
    for profile in _activeProfiles.values {
      if let mapping = profile.buttonMappings.first(where: {
        $0.buttonIdentifier == buttonIdentifier
      }) {
        return mapping
      }
    }
    return nil
  }

  private func _activeInputKey(for buttonIdentifier: String) -> String {
    "direct_\(buttonIdentifier)"
  }

  private var _activeInputs: [String: Bool] = [:]

  public func inputEventStream() -> AsyncStream<InputRouter.ParsedInput> {
    AsyncStream { continuation in
      self._inputEventContinuation = continuation
      continuation.onTermination = { @Sendable _ in
      }
    }
  }
}

extension USBDeviceManager.USBDeviceEvent {
  var deviceID: Core.USBDeviceID? {
    guard let device = self.device else { return nil }
    return Core.USBDeviceID(
      vendorID: device.vendorID,
      productID: device.productID
    )
  }
}

extension AppCoordinator {
  public struct AppCoordinatorEvent: Sendable {
    public let type: EventType
    public let device: GamepadDevice?
    public let profile: Profile?
    public let input: InputRouter.ParsedInput?
    public let error: (any Error)?

    public init(
      type: EventType,
      device: GamepadDevice? = nil,
      profile: Profile? = nil,
      input: InputRouter.ParsedInput? = nil,
      error: (any Error)? = nil
    ) {
      self.type = type
      self.device = device
      self.profile = profile
      self.input = input
      self.error = error
    }
  }

  public enum EventType: Sendable {
    case deviceConnected
    case deviceDisconnected
    case inputProcessed
    case profileChanged
    case deviceError
  }

  public enum AppCoordinatorError: Error, LocalizedError {
    case invalidMapping(String)
    case mouseOperationFailed(String)
    case deviceNotFound

    public var errorDescription: String? {
      switch self {
      case .invalidMapping(let message):
        return "Invalid button mapping: \(message)"
      case .mouseOperationFailed(let message):
        return "Mouse operation failed: \(message)"
      case .deviceNotFound:
        return "Device not found"
      }
    }
  }
}
