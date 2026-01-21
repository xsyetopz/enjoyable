import Foundation

enum EnjoyableError: Error, LocalizedError {
  case transport(TransportError)
  case controller(ControllerError)
  case output(OutputError)
  case configuration(ConfigurationError)

  var errorDescription: String? {
    switch self {
    case .transport(let error):
      return error.localizedDescription
    case .controller(let error):
      return error.localizedDescription
    case .output(let error):
      return error.localizedDescription
    case .configuration(let error):
      return error.localizedDescription
    }
  }
}

enum TransportError: Error, LocalizedError {
  case enumerationFailed
  case interfaceNotFound
  case deviceDisconnected
  case readFailed(status: IOReturn)
  case writeFailed(status: IOReturn)
  case openFailed
  case deviceNotFound
  case propertyNotFound

  var errorDescription: String? {
    switch self {
    case .enumerationFailed:
      return "Failed to enumerate devices"
    case .interfaceNotFound:
      return "USB interface not found"
    case .deviceDisconnected:
      return "Device disconnected"
    case .readFailed(let status):
      return "Read failed with status: \(status)"
    case .writeFailed(let status):
      return "Write failed with status: \(status)"
    case .openFailed:
      return "Failed to open USB device"
    case .deviceNotFound:
      return "USB device not found"
    case .propertyNotFound:
      return "USB property not found"
    }
  }
}

enum ControllerError: Error, LocalizedError {
  case deviceNotSupported(vid: VendorId, pid: ProductId)
  case featureNotSupported(feature: String)

  var errorDescription: String? {
    switch self {
    case .deviceNotSupported(let vid, let pid):
      return "Unsupported device: VID 0x\(String(vid, radix: 16)), PID 0x\(String(pid, radix: 16))"
    case .featureNotSupported(let feature):
      return "Feature not supported: \(feature)"
    }
  }
}

enum OutputError: Error, LocalizedError {
  case accessibilityPermissionDenied

  var errorDescription: String? {
    switch self {
    case .accessibilityPermissionDenied:
      return "Accessibility permissions denied"
    }
  }
}

enum ConfigurationError: Error, LocalizedError {
  case invalidJSON(error: String)
  case fileNotFound(path: String)

  var errorDescription: String? {
    switch self {
    case .invalidJSON(let error):
      return "Invalid JSON: \(error)"
    case .fileNotFound(let path):
      return "File not found: \(path)"
    }
  }
}
