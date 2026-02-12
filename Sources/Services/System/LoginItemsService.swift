import Foundation
import ServiceManagement

public actor LoginItemsService {
  private let _bundleIdentifier: String
  private let _launchAgentLabel = "com.yukkurigames.Enjoyable"
  private let _launchAgentFileName = "com.yukkurigames.Enjoyable.plist"

  public var isStartAtLoginEnabled: Bool {
    get async {
      if #available(macOS 13.0, *) {
        return _checkSMAppServiceStatus()
      } else {
        return _checkLaunchAgentStatus()
      }
    }
  }

  public init(bundleIdentifier: String) {
    self._bundleIdentifier = bundleIdentifier
  }

  public func enableStartAtLogin() async throws {
    if #available(macOS 13.0, *) {
      try await _enableWithSMAppService()
    } else {
      try _enableWithLaunchAgent()
    }
  }

  public func disableStartAtLogin() async throws {
    if #available(macOS 13.0, *) {
      try await _disableWithSMAppService()
    } else {
      try _disableWithLaunchAgent()
    }
  }

  @available(macOS 13.0, *)
  private func _enableWithSMAppService() async throws {
    let registration = SMAppService.mainApp
    do {
      try registration.register()
    } catch {
      throw LoginItemsError.registrationFailed(error.localizedDescription)
    }
  }

  @available(macOS 13.0, *)
  private func _disableWithSMAppService() async throws {
    let registration = SMAppService.mainApp
    do {
      try await registration.unregister()
    } catch {
      throw LoginItemsError.unregistrationFailed(error.localizedDescription)
    }
  }

  @available(macOS 13.0, *)
  private func _checkSMAppServiceStatus() -> Bool {
    let status = SMAppService.mainApp.status
    return status == .enabled
  }

  private func _enableWithLaunchAgent() throws {
    let plistContent = _createLaunchAgentPlist()
    let filePath = try _getLaunchAgentFilePath()

    do {
      try plistContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    } catch {
      throw LoginItemsError.writeFailed(error.localizedDescription)
    }
  }

  private func _disableWithLaunchAgent() throws {
    let filePath = try _getLaunchAgentFilePath()
    let fileManager = FileManager.default

    if fileManager.fileExists(atPath: filePath) {
      do {
        try fileManager.removeItem(atPath: filePath)
      } catch {
        throw LoginItemsError.removeFailed(error.localizedDescription)
      }
    }
  }

  private func _checkLaunchAgentStatus() -> Bool {
    let filePath = try? _getLaunchAgentFilePath()
    guard let path = filePath else { return false }
    return FileManager.default.fileExists(atPath: path)
  }

  private func _createLaunchAgentPlist() -> String {
    guard
      let appPath = Bundle.main.bundlePath.addingPercentEncoding(
        withAllowedCharacters: .urlPathAllowed
      )
    else {
      return _fallbackPlistContent()
    }

    return """
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>\(_launchAgentLabel)</string>
        <key>ProgramArguments</key>
        <array>
          <string>\(appPath)</string>
          <string>--hide</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <false/>
      </dict>
      </plist>
      """
  }

  private func _fallbackPlistContent() -> String {
    return """
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>\(_launchAgentLabel)</string>
        <key>ProgramArguments</key>
        <array>
          <string>/Applications/Enjoyable.app/Contents/MacOS/Enjoyable</string>
          <string>--hide</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <false/>
      </dict>
      </plist>
      """
  }

  private func _getLaunchAgentFilePath() throws -> String {
    guard
      let libraryPath = FileManager.default.urls(
        for: .libraryDirectory,
        in: .userDomainMask
      ).first
    else {
      throw LoginItemsError.libraryPathNotFound
    }

    let launchAgentsPath = libraryPath.appendingPathComponent("LaunchAgents")
    let filePath = launchAgentsPath.appendingPathComponent(_launchAgentFileName).path

    if !FileManager.default.fileExists(atPath: launchAgentsPath.path) {
      try FileManager.default.createDirectory(
        at: launchAgentsPath,
        withIntermediateDirectories: true
      )
    }

    return filePath
  }
}

enum LoginItemsError: LocalizedError {
  case registrationFailed(String)
  case unregistrationFailed(String)
  case writeFailed(String)
  case removeFailed(String)
  case libraryPathNotFound

  var errorDescription: String? {
    switch self {
    case .registrationFailed(let reason):
      return "Failed to register login item: \(reason)"
    case .unregistrationFailed(let reason):
      return "Failed to unregister login item: \(reason)"
    case .writeFailed(let reason):
      return "Failed to write login item file: \(reason)"
    case .removeFailed(let reason):
      return "Failed to remove login item file: \(reason)"
    case .libraryPathNotFound:
      return "Could not find library directory"
    }
  }
}
