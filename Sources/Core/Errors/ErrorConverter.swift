import Foundation

public enum ErrorConverter {
  public static func convert(_ error: any Error) -> any Error {
    if let knownError = error as? USBError {
      return knownError
    }
    if let knownError = error as? ValidationError {
      return knownError
    }
    if let knownError = error as? MappingError {
      return knownError
    }
    if let knownError = error as? ProfileError {
      return knownError
    }

    return _createGenericError(error)
  }

  private static func _createGenericError(_ error: any Error) -> any Error {
    let errorDescription = error.localizedDescription
    if errorDescription.contains("permission") || errorDescription.contains("access") {
      return USBError.accessDenied(vendorID: 0, productID: 0)
    }
    if errorDescription.contains("timeout") {
      return USBError.readTimeout(deviceName: "Unknown Device")
    }
    if errorDescription.contains("disconnect") || errorDescription.contains("remove") {
      return USBError.deviceDisconnected(deviceName: "Unknown Device")
    }
    if errorDescription.contains("not found") || errorDescription.contains("missing") {
      return USBError.deviceNotResponding(deviceName: "Unknown Device")
    }
    if errorDescription.contains("busy") || errorDescription.contains("in use") {
      return USBError.deviceInUseByAnotherApp(deviceName: "Unknown Device", appName: nil)
    }

    return ProfileError.loadFailed(profileName: "Unknown", underlyingError: errorDescription)
  }
}

extension Error {
  public var convertedError: any Error {
    ErrorConverter.convert(self)
  }
}
