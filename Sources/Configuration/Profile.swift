import Core
import Foundation

public struct Profile: Sendable, Equatable, Codable, Identifiable {
  public let id: String
  public let name: String
  public let deviceID: USBDeviceID?
  public let buttonMappings: [ButtonMapping]
  public let version: Int

  public init(
    name: String,
    deviceID: USBDeviceID?,
    buttonMappings: [ButtonMapping],
    version: Int = Constants.Profile.currentVersion
  ) {
    self.id = name
    self.name = name
    self.deviceID = deviceID
    self.buttonMappings = buttonMappings
    self.version = version
  }
}

extension Profile {
  public static let `default` = Profile(
    name: Constants.Profile.defaultProfileName,
    deviceID: nil,
    buttonMappings: [],
    version: Constants.Profile.currentVersion
  )

  public func withName(_ name: String) -> Profile {
    Profile(
      name: name,
      deviceID: deviceID,
      buttonMappings: buttonMappings,
      version: version
    )
  }

  public func withDeviceID(_ deviceID: USBDeviceID?) -> Profile {
    Profile(
      name: name,
      deviceID: deviceID,
      buttonMappings: buttonMappings,
      version: version
    )
  }

  public func withButtonMappings(_ mappings: [ButtonMapping]) -> Profile {
    Profile(
      name: name,
      deviceID: deviceID,
      buttonMappings: mappings,
      version: version
    )
  }
}
