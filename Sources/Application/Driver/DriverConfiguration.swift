import Foundation

public struct DriverConfiguration: Sendable, Equatable, Encodable, Decodable {
  public var autoProfileEnabled: Bool
  public var appContextEnabled: Bool
  public var pollingInterval: TimeInterval
  public var chordTimeout: TimeInterval
  public var macroTimeout: TimeInterval

  public init(
    autoProfileEnabled: Bool = true,
    appContextEnabled: Bool = true,
    pollingInterval: TimeInterval = 1.0,
    chordTimeout: TimeInterval = 0.5,
    macroTimeout: TimeInterval = 5.0
  ) {
    self.autoProfileEnabled = autoProfileEnabled
    self.appContextEnabled = appContextEnabled
    self.pollingInterval = pollingInterval
    self.chordTimeout = chordTimeout
    self.macroTimeout = macroTimeout
  }

  public static let `default` = DriverConfiguration()
}
