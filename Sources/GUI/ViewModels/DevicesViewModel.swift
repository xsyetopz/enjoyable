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

  private var _refreshTimer: Timer?
  private var _usbDeviceService: USBService?

  init() {
    _startAutoRefresh()
  }

  func setUSBDeviceService(_ service: USBService) {
    self._usbDeviceService = service
  }

  func refreshDevices() async {
    isRefreshing = true
    errorMessage = nil

    do {
      if let service = _usbDeviceService {
        await service.startScanning()
        devices = await service.getConnectedDevices()
      }
    }

    isRefreshing = false
  }

  private func _startAutoRefresh() {
    _refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        await self?.refreshDevices()
      }
    }
  }

  func selectDevice(_ device: GamepadDevice) {
    selectedDevice = device
  }

  func configureDevice(_ device: GamepadDevice) {
    selectedDevice = device
  }

  func deviceCount(for state: ConnectionState) -> Int {
    devices.filter { $0.connectionState == state }.count
  }
}
