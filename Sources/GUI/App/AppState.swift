import Combine
import Configuration
import Core
import Infrastructure
import Services
import SwiftUI

@MainActor
final class AppState: ObservableObject {
  @Published var connectedDevices: [GamepadDevice] = []
  @Published var selectedDevice: GamepadDevice?
  @Published var profiles: [Profile] = []
  @Published var currentProfile: Profile?
  @Published var selectedTab: MainTab = .devices
  @Published var showAboutPanel: Bool = false
  @Published var appearanceMode: AppearanceMode = .system
  @Published var startAtLogin: Bool = false
  @Published var showNotifications: Bool = true
  @Published var minimizeToTray: Bool = true
  @Published var isLoading: Bool = false
  @Published var errorMessage: String?
  @Published var buttonStates: [String: Bool] = [:]

  private let _profileStore: ProfileStore
  private let _loginItemsService: LoginItemsService
  private var _usbDeviceService: USBService?
  private var _inputStreamTask: Task<Void, Never>?
  private var _deviceDiscoveryTask: Task<Void, Never>?
  private var _appCoordinator: AppCoordinator?
  private var _isInitialLaunch: Bool = true
  private var _previousDevices: Set<Core.USBDeviceID> = []

  init(
    profileStore: ProfileStore = ProfileStore(),
    loginItemsService: LoginItemsService? = nil
  ) {
    self._profileStore = profileStore
    self._loginItemsService =
      loginItemsService
      ?? LoginItemsService(
        bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.yukkurigames.Enjoyable"
      )
    _loadSettings()
    _initializeUSBDeviceService()
    _setupLoginItems()

    Task {
      await loadProfiles()
      await refreshDevices()
    }
  }

  private func _initializeUSBDeviceService() {
    do {
      let libUSBAdapter = try LibUSBAdapter()
      let service = USBService(
        adapter: libUSBAdapter,
        eventHandler: { [weak self] event in
          Task { @MainActor in
            self?._handleUSBDeviceEvent(event)
          }
        }
      )
      self._usbDeviceService = service
      sharedUSBDeviceService = service
      _startRealInputListening(service: service)

      Task {
        await service.startScanning()
        _subscribeToDeviceDiscovery(service: service)
      }
    } catch {
      errorMessage = AppStateErrorHandler.handleInitializationError(error, _isInitialLaunch)
    }
  }

  private func _subscribeToDeviceDiscovery(service: USBService) {
    _deviceDiscoveryTask = Task { [weak self] in
      guard let self = self else { return }
      let stream = await service.deviceDiscoveryStream()

      for await devices in stream {
        await MainActor.run { [weak self] in
          self?._processDeviceDiscovery(devices)
        }
      }
    }
  }

  private func _processDeviceDiscovery(_ devices: [GamepadDevice]) {
    let currentDeviceIDs = Set(
      devices.map {
        Core.USBDeviceID(
          vendorID: $0.vendorID,
          productID: $0.productID
        )
      }
    )

    let newDevices = currentDeviceIDs.subtracting(_previousDevices)
    let removedDevices = _previousDevices.subtracting(currentDeviceIDs)

    for device in devices {
      let deviceID = Core.USBDeviceID(
        vendorID: device.vendorID,
        productID: device.productID
      )

      if newDevices.contains(deviceID) {
        let event = USBDiscovery.DeviceMonitorEvent(
          type: .deviceDetected,
          device: device
        )
        _handleUSBDeviceEvent(event)
      }
    }

    for deviceID in removedDevices {
      let event = USBDiscovery.DeviceMonitorEvent(
        type: .deviceRemoved,
        deviceID: deviceID
      )
      _handleUSBDeviceEvent(event)
    }

    _previousDevices = currentDeviceIDs
  }

  private func _startRealInputListening(service: USBService) {
    do {
      let profileStore = ProfileStore()
      let inputRouter = InputRouter { _ in }
      let cgAdapter = try CGEventAdapter()
      let outputService = OutputService(cgEventAdapter: cgAdapter) { _ in }
      let profileService = ProfileService(profileStore: profileStore) { _ in }
      let appCoordinator: AppCoordinator
      do {
        let libUSBAdapter = try LibUSBAdapter()
        appCoordinator = AppCoordinator(
          usbDeviceManager: USBDeviceManager(adapter: libUSBAdapter),
          profileService: profileService,
          inputRouter: inputRouter,
          outputService: outputService,
          eventHandler: { [weak self] event in
            Task { @MainActor in
              self?._handleAppCoordinatorEvent(event)
            }
          }
        )
      } catch {
        appCoordinator = AppCoordinator(
          usbDeviceManager: USBDeviceManager(adapter: try LibUSBAdapter()),
          profileService: profileService,
          inputRouter: inputRouter,
          outputService: outputService,
          eventHandler: { [weak self] event in
            Task { @MainActor in
              self?._handleAppCoordinatorEvent(event)
            }
          }
        )
      }
      self._appCoordinator = appCoordinator

      _inputStreamTask = Task { [weak self] in
        guard let self = self else { return }
        let stream = await appCoordinator.inputEventStream()

        for await parsedInput in stream {
          self._processRealInput(parsedInput)
        }
      }
    } catch {
    }
  }

  private func _handleAppCoordinatorEvent(_ event: AppCoordinator.AppCoordinatorEvent) {
    switch event.type {
    case .deviceConnected, .deviceDisconnected, .inputProcessed, .profileChanged, .deviceError:
      // NOTE: already handled by device discovery subscription
      break
    }
  }

  private func _processRealInput(_ parsedInput: InputRouter.ParsedInput) {
    var newStates = buttonStates

    for input in parsedInput.inputs {
      let buttonName = GamepadConstants.Button.mapFromRawIdentifier(input.buttonIdentifier)
      newStates[buttonName] = input.isPressed
    }

    buttonStates = newStates
  }

  private func _handleUSBDeviceEvent(_ event: USBDiscovery.DeviceMonitorEvent) {
    switch event.type {
    case .deviceDetected:
      _isInitialLaunch = false
      if let device = event.device,
        !connectedDevices.contains(where: {
          $0.vendorID == device.vendorID && $0.productID == device.productID
        })
      {
        connectedDevices.append(device)
        Task {
          do {
            let connectedDevice = try await self._usbDeviceService?.connect(
              deviceID: Core.USBDeviceID(vendorID: device.vendorID, productID: device.productID)
            )
            if let connected = connectedDevice {
              await MainActor.run {
                var devices = self.connectedDevices
                if let index = devices.firstIndex(where: {
                  $0.vendorID == device.vendorID && $0.productID == device.productID
                }) {
                  devices[index] = connected
                  self.connectedDevices = devices
                }
              }
            }
          } catch {
            print("Failed to connect to device: \(error.localizedDescription)")
          }
        }
      }
      Task {
        if let device = event.device {
          await _appCoordinator?.handleDeviceEvent(
            USBDeviceManager.USBDeviceEvent(
              type: .connected,
              device: device,
              report: nil,
              error: nil
            )
          )
        }
      }
    case .deviceRemoved:
      if let deviceID = event.deviceID {
        connectedDevices.removeAll {
          $0.vendorID == deviceID.vendorID && $0.productID == deviceID.productID
        }
      }
      Task {
        if let device = event.device {
          await _appCoordinator?.handleDeviceEvent(
            USBDeviceManager.USBDeviceEvent(
              type: .disconnected,
              device: device,
              report: nil,
              error: nil
            )
          )
        }
      }
    case .scanError:
      let errorDescription = AppStateErrorHandler.handleDeviceEventError(event, _isInitialLaunch)
      if let description = errorDescription, !description.isEmpty {
        errorMessage = description
      }
      Task {
        if let device = event.device {
          await _appCoordinator?.handleDeviceEvent(
            USBDeviceManager.USBDeviceEvent(
              type: .error,
              device: device,
              report: nil,
              error: event.error
            )
          )
        }
      }
    }
  }

  private func _setupLoginItems() {
    Task {
      do {
        startAtLogin = await _loginItemsService.isStartAtLoginEnabled
      }
    }
  }

  private func _loadSettings() {
    let defaults = UserDefaults.standard
    appearanceMode =
      AppearanceMode(
        rawValue: defaults.string(forKey: "appearanceMode") ?? "System"
      ) ?? .system
    showNotifications = defaults.bool(forKey: "showNotifications")
    minimizeToTray = defaults.bool(forKey: "minimizeToTray")
  }

  func saveSettings() {
    let defaults = UserDefaults.standard
    defaults.set(appearanceMode.rawValue, forKey: "appearanceMode")
    defaults.set(showNotifications, forKey: "showNotifications")
    defaults.set(minimizeToTray, forKey: "minimizeToTray")
  }

  func refreshDevices() async {
    do {
      if let service = _usbDeviceService {
        connectedDevices = await service.getConnectedDevices()
      }
    }
  }

  func loadProfiles() async {
    isLoading = true
    do {
      profiles = try await _profileStore.loadAllProfiles()
      if profiles.isEmpty {
        let defaultProfile = Profile.default
        try await _profileStore.saveProfile(defaultProfile)
        profiles = [defaultProfile]
      }
      if currentProfile == nil {
        currentProfile = profiles.first
      }
    } catch {
      errorMessage = ErrorMessages.loadProfilesFailed(error.localizedDescription)
    }
    isLoading = false
  }

  func createNewProfile() {
    let newProfile = Profile(
      name: "Profile \(profiles.count + 1)",
      deviceID: nil,
      buttonMappings: []
    )
    profiles.append(newProfile)
    currentProfile = newProfile
    selectedTab = .profiles
  }

  func saveCurrentProfile() async {
    guard let profile = currentProfile else { return }
    do {
      try await _profileStore.saveProfile(profile)
      if let index = profiles.firstIndex(where: { $0.name == profile.name }) {
        profiles[index] = profile
      }
    } catch {
      errorMessage = ErrorMessages.saveProfileFailed(error.localizedDescription)
    }
  }

  func deleteProfile(_ profile: Profile) async {
    do {
      try await _profileStore.deleteProfile(named: profile.name)
      profiles.removeAll { $0.name == profile.name }
      if currentProfile?.name == profile.name {
        currentProfile = profiles.first
      }
    } catch {
      errorMessage = ErrorMessages.deleteProfileFailed(error.localizedDescription)
    }
  }

  func selectProfile(_ profile: Profile) {
    currentProfile = profile
  }

  func updateButtonMapping(for buttonIdentifier: String, mapping: ButtonMapping) {
    guard var profile = currentProfile else { return }
    var mappings = profile.buttonMappings
    if let index = mappings.firstIndex(where: { $0.buttonIdentifier == buttonIdentifier }) {
      mappings[index] = mapping
    } else {
      mappings.append(mapping)
    }
    profile = profile.withButtonMappings(mappings)
    currentProfile = profile
  }

  func removeButtonMapping(for buttonIdentifier: String) {
    guard var profile = currentProfile else { return }
    let mappings = profile.buttonMappings.filter { $0.buttonIdentifier != buttonIdentifier }
    profile = profile.withButtonMappings(mappings)
    currentProfile = profile
  }

  func setStartAtLogin(_ enabled: Bool) {
    startAtLogin = enabled
    Task {
      do {
        if enabled {
          try await _loginItemsService.enableStartAtLogin()
        } else {
          try await _loginItemsService.disableStartAtLogin()
        }
      } catch {
        await MainActor.run {
          self.startAtLogin = false
          errorMessage = error.localizedDescription
        }
      }
    }
  }

  func dismissError() {
    errorMessage = nil
  }

  func configureDevice(_ device: GamepadDevice) async {
    await MainActor.run {
      selectedDevice = device
      selectedTab = .mapping
    }
  }
}

enum MainTab: String, CaseIterable {
  case devices = "Devices"
  case profiles = "Profiles"
  case mapping = "Mapping"
  case settings = "Settings"

  var systemIcon: String {
    switch self {
    case .devices: return "gamecontroller.fill"
    case .profiles: return "person.crop.rectangle.stack.fill"
    case .mapping: return "slider.horizontal.3"
    case .settings: return "gearshape.fill"
    }
  }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
  case system = "System"
  case light = "Light"
  case dark = "Dark"

  var id: String { rawValue }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
}
