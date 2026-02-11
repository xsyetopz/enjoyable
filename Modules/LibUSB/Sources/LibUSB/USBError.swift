import CLibUSB
import Foundation

public enum USBError: LocalizedError {
  case io
  case inputOutput
  case invalidParam
  case access
  case noDevice
  case notFound
  case busy
  case timeout
  case overflow
  case pipe
  case interrupted
  case noMemory
  case notSupported
  case configuration
  case other(Int32)
  case unknown

  public var errorDescription: String? {
    switch self {
    case .io:
      return "Input/output error"
    case .inputOutput:
      return "Input/output error"
    case .invalidParam:
      return "Invalid parameter"
    case .access:
      return "Access denied (insufficient permissions)"
    case .noDevice:
      return "No such device (it may have been disconnected)"
    case .notFound:
      return "Entity not found"
    case .busy:
      return "Resource busy"
    case .timeout:
      return "Operation timed out"
    case .overflow:
      return "Overflow"
    case .pipe:
      return "Pipe error"
    case .interrupted:
      return "System call interrupted (perhaps due to signal)"
    case .noMemory:
      return "Insufficient memory"
    case .notSupported:
      return "Operation not supported or unimplemented on this platform"
    case .configuration:
      return "Configuration error"
    case .other(let code):
      return "Other error (code: \(code))"
    case .unknown:
      return "Unknown error"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .access:
      return "Check file permissions or run with elevated privileges"
    case .noDevice:
      return "Verify device is connected and not in use by another application"
    case .busy:
      return "Close other applications using device and retry"
    case .timeout:
      return "Increase timeout value or check device responsiveness"
    case .notSupported:
      return "Verify operation is supported on this platform/device"
    default:
      return nil
    }
  }

  init(_ errorCode: Int32) {
    let code = Int32(bitPattern: UInt32(truncatingIfNeeded: errorCode))
    switch code {
    case -1:
      self = .io
    case -2:
      self = .invalidParam
    case -3:
      self = .access
    case -4:
      self = .noDevice
    case -5:
      self = .notFound
    case -6:
      self = .busy
    case -7:
      self = .timeout
    case -8:
      self = .overflow
    case -9:
      self = .pipe
    case -10:
      self = .interrupted
    case -11:
      self = .noMemory
    case -12:
      self = .notSupported
    default:
      self = .other(errorCode)
    }
  }
}
