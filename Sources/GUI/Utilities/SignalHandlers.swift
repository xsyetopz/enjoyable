import AppKit
import Core
import Foundation
import Services

@MainActor
enum SignalHandlers {
  fileprivate static nonisolated(unsafe) var _sharedUSBDeviceServiceRef: USBService?

  static func setup() {
    signal(SIGINT) { _ in
      Task { @MainActor in
        await _cleanupAndExit()
      }
    }

    signal(SIGTERM) { _ in
      Task { @MainActor in
        await _cleanupAndExit()
      }
    }

    NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification,
      object: nil,
      queue: .main
    ) { _ in
      Task {
        await _cleanupAndExit()
      }
    }
  }

  static func setService(_ service: USBService?) {
    _sharedUSBDeviceServiceRef = service
  }
}

@MainActor
private func _cleanupAndExit() async {
  if let service = SignalHandlers._sharedUSBDeviceServiceRef {
    let devices = await service.getConnectedDevices()
    for device in devices {
      try? await service.disconnect(
        deviceID: Core.USBDeviceID(vendorID: device.vendorID, productID: device.productID)
      )
    }
  }

  try? await Task.sleep(nanoseconds: 100_000_000)

  NSApp.terminate(nil)
}
