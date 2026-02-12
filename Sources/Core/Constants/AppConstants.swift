import Foundation

public enum AppConstants {
  public enum Profile {
    public static let currentVersion: Int = 1
    public static let defaultName: String = "Default"
    public static let fileExtension: String = "json"
    public static let directoryName: String = "Enjoyable"
  }

  public enum FileIO {
    public static let timeoutSeconds: TimeInterval = 5.0
    public static let loadSeconds: TimeInterval = 2.0
    public static let saveSeconds: TimeInterval = 2.0
  }

  public enum Input {
    public static let triggerThreshold: UInt8 = 128
    public static let mouseSensitivity: Double = 2.0
    public static let mouseDeadzone: Double = 0.15
    public static let scrollSensitivity: Double = 1.0
    public static let scrollDeadzone: Double = 0.2
  }

  public enum Format {
    public static let usbDeviceID: String = "%04X:%04X"
  }

  public enum FileName {
    public static let invalidCharacters: CharacterSet = {
      var set = CharacterSet(charactersIn: ":/\\?*|\"<>")
      set.formUnion(.controlCharacters)
      return set
    }()
  }
}
