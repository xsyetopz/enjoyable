import Foundation

public enum DriverState: Sendable, Equatable {
  case stopped
  case starting
  case running
  case pausing
  case paused
  case stopping
  case error(message: String)

  public var isActive: Bool {
    switch self {
    case .running, .paused:
      return true
    default:
      return false
    }
  }

  public var canTransition: Bool {
    switch self {
    case .stopped, .paused:
      return true
    default:
      return false
    }
  }
}
