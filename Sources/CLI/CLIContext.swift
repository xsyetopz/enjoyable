import Configuration
import Core
import Foundation
import Rainbow

public struct CLIContext {
  public let profileStore: ProfileStore
  public let fileManager: FileManager
  public let outputStyle: OutputStyle

  public init(
    profileStore: ProfileStore? = nil,
    fileManager: FileManager = .default,
    outputStyle: OutputStyle = .auto
  ) {
    self.profileStore = profileStore ?? ProfileStore()
    self.fileManager = fileManager
    self.outputStyle = outputStyle
  }

  public enum OutputStyle {
    case auto
    case plain
    case colored
  }

  public func color(_ string: String, _ style: NamedColor) -> String {
    guard outputStyle != .plain else { return string }
    return string.applyingColor(style)
  }

  public func bold(_ string: String) -> String {
    guard outputStyle != .plain else { return string }
    return string.bold
  }

  public func success(_ message: String) {
    print(color("✓", .green), color(message, .white))
  }

  public func error(_ message: String) {
    print(color("✗", .red), color(message, .white))
  }

  public func info(_ message: String) {
    print(color("●", .cyan), color(message, .white))
  }

  public func warning(_ message: String) {
    print(color("⚠", .yellow), color(message, .white))
  }

  public func header(_ message: String) {
    print(bold(color(message, .magenta)))
    print(bold(String(repeating: "─", count: message.count)))
  }

  public func section(_ title: String) {
    print(bold(color("[\(title)]", .blue)))
  }

  public func deviceInfo(_ device: GamepadDevice) {
    let stateColor: NamedColor
    switch device.connectionState {
    case .connected:
      stateColor = .green
    case .connecting:
      stateColor = .yellow
    case .disconnected:
      stateColor = .lightBlack
    case .error:
      stateColor = .red
    }

    let deviceType: String
    if device.isXbox {
      deviceType = "Xbox"
    } else if device.isPlayStation {
      deviceType = "PlayStation"
    } else if device.isNintendo {
      deviceType = "Nintendo"
    } else {
      deviceType = "Generic"
    }

    let deviceID = String(format: Constants.Format.usbDeviceID, device.vendorID, device.productID)

    print("  \(color("●", stateColor)) \(device.deviceName) (\(deviceType))")
    print("     ID: \(deviceID)")
    print("     State: \(color(String(describing: device.connectionState), stateColor))")
  }
}

public struct ExitCodes {
  public static let success: Int32 = 0
  public static let generalError: Int32 = 1
  public static let invalidArgument: Int32 = 2
  public static let daemonNotRunning: Int32 = 3
  public static let daemonAlreadyRunning: Int32 = 4
  public static let deviceNotFound: Int32 = 5
  public static let profileNotFound: Int32 = 6
  public static let profileSaveFailed: Int32 = 7
  public static let operationCancelled: Int32 = 8
  public static let permissionDenied: Int32 = 9
}

public struct DaemonControl {
  private static let _daemonIdentifier = "com.yukkurigames.Enjoyable.driver"
  private static let _daemonPath = "/Library/LaunchAgents/com.yukkurigames.Enjoyable.driver.plist"

  public static func isDaemonRunning() -> Bool {
    let task = Process()
    task.launchPath = "/bin/launchctl"
    task.arguments = ["list"]

    let pipe = Pipe()
    task.standardOutput = pipe

    do {
      try task.run()
      task.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      guard let output = String(data: data, encoding: .utf8) else { return false }

      return output.contains(_daemonIdentifier)
    } catch {
      return false
    }
  }

  public static func startDaemon() throws {
    let plistPath = "/Library/LaunchAgents/com.yukkurigames.Enjoyable.driver.plist"

    guard FileManager.default.fileExists(atPath: plistPath) else {
      throw DaemonError.plistNotFound
    }

    let task = Process()
    task.launchPath = "/bin/launchctl"
    task.arguments = ["load", plistPath]

    let errorPipe = Pipe()
    task.standardError = errorPipe

    do {
      try task.run()
      task.waitUntilExit()

      guard task.terminationStatus == 0 else {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
        throw DaemonError.launchFailed(errorMessage)
      }
    } catch {
      throw DaemonError.launchFailed(error.localizedDescription)
    }
  }

  public static func stopDaemon() throws {
    let task = Process()
    task.launchPath = "/bin/launchctl"
    task.arguments = ["unload", _daemonPath]

    let errorPipe = Pipe()
    task.standardError = errorPipe

    do {
      try task.run()
      task.waitUntilExit()

      guard task.terminationStatus == 0 else {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
        throw DaemonError.stopFailed(errorMessage)
      }
    } catch {
      throw DaemonError.stopFailed(error.localizedDescription)
    }
  }

  public static func restartDaemon() throws {
    if isDaemonRunning() {
      try stopDaemon()
      Thread.sleep(forTimeInterval: 0.5)
    }
    try startDaemon()
  }

  public enum DaemonError: Error, LocalizedError {
    case plistNotFound
    case launchFailed(String)
    case stopFailed(String)

    public var errorDescription: String? {
      switch self {
      case .plistNotFound:
        return "Daemon launch agent plist not found at \(_daemonPath)"
      case .launchFailed(let message):
        return "Failed to launch daemon: \(message)"
      case .stopFailed(let message):
        return "Failed to stop daemon: \(message)"
      }
    }
  }
}
