import Foundation

public enum USBError: Error, LocalizedError, Sendable {
  case accessDenied(vendorID: UInt16, productID: UInt16)
  case deviceDisconnected(deviceName: String)
  case deviceInUseByAnotherApp(deviceName: String, appName: String?)
  case unsupportedDevice(vendorID: UInt16, productID: UInt16, deviceName: String)
  case readTimeout(deviceName: String)
  case writeTimeout(deviceName: String)
  case malformedReport(deviceName: String, expectedLength: Int, actualLength: Int)
  case kernelDriverDetached(deviceName: String)
  case configurationError(deviceName: String, configurationNumber: UInt8)
  case interfaceClaimFailed(deviceName: String, interfaceNumber: UInt8)
  case invalidReportDescriptor(deviceName: String)
  case deviceNotResponding(deviceName: String)
  case busError(deviceName: String, underlyingError: String)
  case scanFailed(underlyingError: String)

  public var title: String {
    switch self {
    case .accessDenied: return "USB Device Access Denied"
    case .deviceDisconnected: return "Device Disconnected"
    case .deviceInUseByAnotherApp: return "Device in Use by Another Application"
    case .unsupportedDevice: return "Unsupported Device"
    case .readTimeout: return "Read Timeout"
    case .writeTimeout: return "Write Timeout"
    case .malformedReport: return "Malformed Report"
    case .kernelDriverDetached: return "Kernel Driver Detached"
    case .configurationError: return "Configuration Error"
    case .interfaceClaimFailed: return "Interface Claim Failed"
    case .invalidReportDescriptor: return "Invalid Report Descriptor"
    case .deviceNotResponding: return "Device Not Responding"
    case .busError: return "USB Bus Error"
    case .scanFailed: return "Device Scan Failed"
    }
  }

  public var message: String {
    switch self {
    case .accessDenied(let vendorID, let productID):
      return
        "Access to USB device (Vendor: 0x\(String(format: "%04X", vendorID)), Product: 0x\(String(format: "%04X", productID))) was denied."
    case .deviceDisconnected(let deviceName):
      return "The gamepad '\(deviceName)' was unexpectedly disconnected."
    case .deviceInUseByAnotherApp(let deviceName, let appName):
      if let appName = appName {
        return "The gamepad '\(deviceName)' is currently being used by '\(appName)'."
      } else {
        return "The gamepad '\(deviceName)' is currently being used by another application."
      }
    case .unsupportedDevice(let vendorID, let productID, let deviceName):
      return
        "The device '\(deviceName)' (Vendor: 0x\(String(format: "%04X", vendorID)), Product: 0x\(String(format: "%04X", productID))) is not a supported gamepad."
    case .readTimeout(let deviceName):
      return "No data was received from '\(deviceName)' within the expected time."
    case .writeTimeout(let deviceName):
      return "Data could not be sent to '\(deviceName)' within the expected time."
    case .malformedReport(let deviceName, let expectedLength, let actualLength):
      return
        "Received a malformed report from '\(deviceName)'. Expected \(expectedLength) bytes but received \(actualLength) bytes."
    case .kernelDriverDetached(let deviceName):
      return "The kernel driver for '\(deviceName)' was unexpectedly detached."
    case .configurationError(let deviceName, let configurationNumber):
      return "Failed to get configuration \(configurationNumber) for device '\(deviceName)'."
    case .interfaceClaimFailed(let deviceName, let interfaceNumber):
      return "Failed to claim interface \(interfaceNumber) for device '\(deviceName)'."
    case .invalidReportDescriptor(let deviceName):
      return "The HID report descriptor for '\(deviceName)' is invalid or unsupported."
    case .deviceNotResponding(let deviceName):
      return "Device '\(deviceName)' is not responding to commands."
    case .busError(let deviceName, let underlyingError):
      return
        "A USB bus error occurred while communicating with '\(deviceName)': \(underlyingError)."
    case .scanFailed(let underlyingError):
      return "Failed to scan for devices: \(underlyingError)."
    }
  }

  public var recoverySuggestion: String {
    switch self {
    case .accessDenied:
      return
        "1. Disconnect and reconnect the device\n2. Try a different USB port\n3. Close other applications that might be using the device\n4. Check that the USB cable is not damaged"
    case .deviceDisconnected:
      return
        "1. Check that the USB cable is securely connected\n2. Try a different USB port\n3. Try a different USB cable if available\n4. Restart Enjoyable"
    case .deviceInUseByAnotherApp:
      return
        "1. Identify which application is using the device\n2. Close that application\n3. Restart Enjoyable"
    case .unsupportedDevice:
      return
        "This device is not currently supported. Check if there's a firmware update or report this device to the developers."
    case .readTimeout, .writeTimeout:
      return
        "1. Disconnect and reconnect the device\n2. Try a different USB port\n3. Check if the device works on another computer"
    case .malformedReport:
      return
        "1. Update the device firmware to the latest version\n2. Try a different USB cable\n3. Connect the device directly to the computer"
    case .kernelDriverDetached:
      return
        "1. Disconnect and reconnect the device\n2. Restart Enjoyable\n3. If the issue persists after macOS updates, try restarting your computer"
    case .configurationError, .interfaceClaimFailed:
      return
        "1. Try connecting the device to a different USB port\n2. Check if the device works on another operating system\n3. Update the device firmware"
    case .invalidReportDescriptor:
      return
        "1. Update the device firmware to the latest version\n2. Try a different device\n3. Report this issue to the device manufacturer"
    case .deviceNotResponding:
      return
        "1. Disconnect and reconnect the device\n2. Try a different USB port\n3. Check if the device works on another computer\n4. Update the device firmware"
    case .busError:
      return
        "1. Try a different USB port\n2. Use a different USB cable\n3. Avoid USB hubs if possible\n4. Check for conflicting USB drivers"
    case .scanFailed:
      return
        "1. Check USB connections\n2. Try different USB ports\n3. Restart Enjoyable\n4. Check for USB driver issues"
    }
  }

  public var errorDescription: String? {
    "\(title): \(message)"
  }

  public var primaryAction: String {
    switch self {
    case .accessDenied: return "Retry Connection"
    case .deviceDisconnected: return "Reconnect Device"
    case .deviceInUseByAnotherApp: return "Show Running Apps"
    case .unsupportedDevice: return "View Supported Devices"
    case .readTimeout, .writeTimeout: return "Retry Operation"
    case .malformedReport: return "Update Firmware"
    case .kernelDriverDetached: return "Reconnect Device"
    case .configurationError, .interfaceClaimFailed: return "Retry Connection"
    case .invalidReportDescriptor: return "Check Device"
    case .deviceNotResponding: return "Reset Device"
    case .busError: return "Change USB Port"
    case .scanFailed: return "Retry Scan"
    }
  }

  public var isRetryable: Bool {
    switch self {
    case .deviceDisconnected, .deviceInUseByAnotherApp, .unsupportedDevice:
      return false
    default:
      return true
    }
  }
}
