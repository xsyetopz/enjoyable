import Combine
import Core
import Infrastructure
import Services
import SwiftUI

@MainActor
final class DevicesViewModel: ObservableObject {
  @Published var _devices: [GamepadDevice] = []
  @Published var _selectedDevice: GamepadDevice?
  @Published var _isRefreshing: Bool = false
  @Published var _errorMessage: String?

  private var _refreshTimer: Timer?
  private var _usbDeviceService: USBService?

  init() {
    _startAutoRefresh()
  }

  func setUSBDeviceService(_ service: USBService) {
    self._usbDeviceService = service
  }

  func refreshDevices() async {
    _isRefreshing = true
    _errorMessage = nil

    do {
      if let service = _usbDeviceService {
        await service.startScanning()
        _devices = await service.getConnectedDevices()
      }
    }

    _isRefreshing = false
  }

  private func _startAutoRefresh() {
    _refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        await self?.refreshDevices()
      }
    }
  }

  func selectDevice(_ device: GamepadDevice) {
    _selectedDevice = device
  }

  func deviceCount(for state: ConnectionState) -> Int {
    _devices.filter { $0.connectionState == state }.count
  }
}
