import Core
import Services

enum AppStateErrorHandler {
  static func handleInitializationError(
    _ error: any Error,
    _ isInitialLaunch: Bool
  ) -> String? {
    if let usbError = error as? USBError {
      switch usbError {
      case .accessDenied:
        return isInitialLaunch ? nil : ErrorMessages.USB.accessDenied
      default:
        return ErrorMessages.usbInitializationFailed(usbError.localizedDescription)
      }
    }
    return "Failed to initialize USB service: \(error.localizedDescription)"
  }

  static func handleDeviceEventError(
    _ event: USBDiscovery.DeviceMonitorEvent,
    _ isInitialLaunch: Bool
  ) -> String? {
    guard let error = event.error else {
      if let device = event.device {
        return "Device error: \(device.deviceName)"
      } else if let deviceID = event.deviceID {
        return "Device error: \(deviceID.vendorID):\(deviceID.productID)"
      }
      return "Unknown device error"
    }

    if let usbError = error as? USBError {
      switch usbError {
      case .accessDenied:
        return isInitialLaunch
          ? "" : ErrorMessages.usbAccessError(for: event.device?.deviceName ?? "Unknown")
      case .deviceDisconnected:
        return ErrorMessages.USB.deviceDisconnected
      case .busError(let deviceName, _):
        return ErrorMessages.communicationError(for: deviceName)
      default:
        return ErrorMessages.usbError(usbError.localizedDescription)
      }
    }

    return ErrorMessages.deviceError(error.localizedDescription)
  }
}
