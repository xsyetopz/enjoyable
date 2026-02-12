public enum KeyModifier: UInt8, Sendable, Equatable, Codable {
  case none = 0
  case command = 1
  case control = 2
  case option = 3
  case shift = 4
}

public struct ButtonMapping: Sendable, Equatable, Codable {
  public let buttonIdentifier: String
  public let keyCode: UInt16
  public let modifier: KeyModifier

  public init(
    buttonIdentifier: String,
    keyCode: UInt16,
    modifier: KeyModifier = .none
  ) {
    self.buttonIdentifier = buttonIdentifier
    self.keyCode = keyCode
    self.modifier = modifier
  }
}

extension ButtonMapping {
  public static let empty = ButtonMapping(
    buttonIdentifier: "",
    keyCode: KeyCodeConstants.unmapped,
    modifier: .none
  )
}
