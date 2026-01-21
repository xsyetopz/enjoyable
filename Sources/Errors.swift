import Foundation

enum EnjoyableError: Error, LocalizedError {
  case transport(TransportError)
  case protocolError(ProtocolError)
  case controller(ControllerError)
  case output(OutputError)
  case configuration(ConfigurationError)

  var errorDescription: String? {
    switch self {
    case .transport(let error):
      return error.localizedDescription
    case .protocolError(let error):
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
  case notificationPortCreationFailed
  case notificationRegistrationFailed
  case enumerationFailed
  case interfaceNotFound
  case deviceDisconnected
  case readFailed(status: IOReturn)
  case writeFailed(status: IOReturn)
  case interfaceClaimFailed
  case openFailed
  case deviceNotFound
  case endpointNotFound
  case timeout
  case notImplemented
  case propertyNotFound

  var errorDescription: String? {
    switch self {
    case .notificationPortCreationFailed:
      return "Failed to create IOKit notification port"
    case .notificationRegistrationFailed:
      return "Failed to register IOKit notification"
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
    case .interfaceClaimFailed:
      return "Failed to claim USB interface"
    case .openFailed:
      return "Failed to open USB device"
    case .deviceNotFound:
      return "USB device not found"
    case .endpointNotFound:
      return "USB endpoint not found"
    case .timeout:
      return "USB operation timed out"
    case .notImplemented:
      return "Method not implemented"
    case .propertyNotFound:
      return "USB property not found"
    }
  }
}

enum ProtocolError: Error, LocalizedError {
  case invalidReportSize(expected: Int, actual: Int)
  case malformedData(offset: Int)
  case outOfRangeValue(field: String, value: String)
  case checksumMismatch
  case unsupportedCommand(command: UInt8)
  case handshakeFailed
  case identificationFailed
  case enableFailed
  case modeSwitchFailed
  case invalidResponse

  var errorDescription: String? {
    switch self {
    case .invalidReportSize(let expected, let actual):
      return "Invalid report size: expected \(expected), got \(actual)"
    case .malformedData(let offset):
      return "Malformed data at offset \(offset)"
    case .outOfRangeValue(let field, let value):
      return "Value \(value) out of range for field \(field)"
    case .checksumMismatch:
      return "Checksum mismatch"
    case .unsupportedCommand(let command):
      return "Unsupported command: 0x\(String(command, radix: 16))"
    case .handshakeFailed:
      return "Handshake failed"
    case .identificationFailed:
      return "Identification failed"
    case .enableFailed:
      return "Failed to enable input reports"
    case .modeSwitchFailed:
      return "Mode switch failed"
    case .invalidResponse:
      return "Invalid response from device"
    }
  }
}

enum ControllerError: Error, LocalizedError {
  case InitFailed
  case deviceNotSupported(vid: VendorId, pid: ProductId)
  case commandFailed(reason: String)
  case featureNotSupported(feature: String)
  case unsupportedProtocol(protocol: String)

  var errorDescription: String? {
    switch self {
    case .InitFailed:
      return "Controller initialization failed"
    case .deviceNotSupported(let vid, let pid):
      return "Unsupported device: VID 0x\(String(vid, radix: 16)), PID 0x\(String(pid, radix: 16))"
    case .commandFailed(let reason):
      return "Command failed: \(reason)"
    case .featureNotSupported(let feature):
      return "Feature not supported: \(feature)"
    case .unsupportedProtocol(let protocolType):
      return "Unsupported protocol: \(protocolType)"
    }
  }
}

enum OutputError: Error, LocalizedError {
  case accessibilityPermissionDenied
  case eventSynthesisFailed(eventType: UInt32)
  case mappingNotFound(mappingId: String)
  case invalidMappingConfiguration(reason: String)

  var errorDescription: String? {
    switch self {
    case .accessibilityPermissionDenied:
      return "Accessibility permissions denied. Please grant accessibility permissions."
    case .eventSynthesisFailed(let eventType):
      return "Failed to synthesize event type: \(eventType)"
    case .mappingNotFound(let id):
      return "Mapping not found: \(id)"
    case .invalidMappingConfiguration(let reason):
      return "Invalid mapping configuration: \(reason)"
    }
  }
}

enum ConfigurationError: Error, LocalizedError {
  case indexLoadFailed(path: String)
  case invalidSchemaVersion(version: Int)
  case missingRequiredField(field: String)
  case invalidJSON(error: String)
  case fileNotFound(path: String)

  var errorDescription: String? {
    switch self {
    case .indexLoadFailed(let path):
      return "Failed to load index from: \(path)"
    case .invalidSchemaVersion(let version):
      return "Invalid schema version: \(version)"
    case .missingRequiredField(let field):
      return "Missing required field: \(field)"
    case .invalidJSON(let error):
      return "Invalid JSON: \(error)"
    case .fileNotFound(let path):
      return "File not found: \(path)"
    }
  }
}
