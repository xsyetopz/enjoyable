import Combine
import Core
import Infrastructure
import Services
import SwiftUI

@MainActor
final class DevicesViewModel: ObservableObject {
  @Published var devices: [GamepadDevice] = []
  @Published var selectedDevice: GamepadDevice?
  @Published var isRefreshing: Bool = false
  @Published var errorMessage: String?
  @Published var showingDeviceConfiguration: Bool = false
  @Published var deviceToConfigure: GamepadDevice?

  private var _cancellables = Set<AnyCancellable>()
  private var _usbDeviceService: USBService?
  private weak var _appState: AppState?

  init() {
    if let service = sharedUSBDeviceService {
      self._usbDeviceService = service
    }
  }

  func setAppState(_ appState: AppState) {
    self._appState = appState
    _observeDeviceChanges(appState)
  }

  func setUSBDeviceService(_ service: USBService) {
    self._usbDeviceService = service
  }

  private func _observeDeviceChanges(_ appState: AppState) {
    appState.$connectedDevices
      .receive(on: DispatchQueue.main)
      .sink { [weak self] devices in
        self?.devices = devices
      }
      .store(in: &_cancellables)
  }

  func refreshDevices() async {
    isRefreshing = true
    errorMessage = nil

    do {
      let service = _usbDeviceService ?? sharedUSBDeviceService
      if let service = service {
        await service.startScanning()
        let connectedDevices = await service.getConnectedDevices()
        devices = connectedDevices
      }
    }

    isRefreshing = false
  }

  func selectDevice(_ device: GamepadDevice) {
    selectedDevice = device
  }

  func configureDevice(_ device: GamepadDevice) {
    selectedDevice = device
    deviceToConfigure = device
    showingDeviceConfiguration = true
  }

  func dismissDeviceConfiguration() {
    showingDeviceConfiguration = false
    deviceToConfigure = nil
  }

  func deviceCount(for state: ConnectionState) -> Int {
    devices.filter { $0.connectionState == state }.count
  }
}
