import ArgumentParser
import Configuration
import Core
import Foundation
import Infrastructure
import Rainbow
import Services

struct StatusCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "status",
    abstract: "Show driver status and connected devices"
  )

  @Flag(name: .shortAndLong, help: "Show detailed information")
  var verbose: Bool = false

  func run() async throws {

    let isRunning = DaemonControl.isDaemonRunning()

    print(_bold("Enjoyable Gamepad Driver Status"))
    print(String(repeating: "─", count: 40))
    print()

    print("Daemon: ", terminator: "")
    if isRunning {
      print(_green("Running"))
    } else {
      print(_red("Not Running"))
    }

    print()

    if isRunning {
      print(_bold("Connected Devices:"))
      print(String(repeating: "─", count: 20))

      let connectedDevices = try await _getConnectedDevices()
      if connectedDevices.isEmpty {
        print("  No devices connected")
      } else {
        for device in connectedDevices {
          _printDevice(device, verbose: verbose)
        }
      }

      print()

      let profileStore = ProfileStore()
      let profiles = try await profileStore.loadAllProfiles()
      print(_bold("Loaded Profiles:"))
      print(String(repeating: "─", count: 20))
      print("  \(profiles.count) profile(s)")

      if !profiles.isEmpty {
        for profile in profiles.prefix(5) {
          print("    - \(profile.name)")
        }
        if profiles.count > 5 {
          print("    ... and \(profiles.count - 5) more")
        }
      }
    } else {
      print(_yellow("Start the daemon to see connected devices"))
      print("  Run: enjoyable start")
    }
  }

  private func _getConnectedDevices() async throws -> [GamepadDevice] {
    let libUSBAdapter = try LibUSBAdapter()
    return try await libUSBAdapter.scanDevices()
  }

  private func _printDevice(_ device: GamepadDevice, verbose: Bool) {
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

    print("  \(_color("●", stateColor)) \(device.deviceName) (\(deviceType))")

    if verbose {
      let deviceID = String(format: Constants.Format.usbDeviceID, device.vendorID, device.productID)
      print("     ID: \(deviceID)")
      print("     State: \(_color(String(describing: device.connectionState), stateColor))")
    }
  }

  private func _green(_ text: String) -> String {
    return text.green
  }

  private func _red(_ text: String) -> String {
    return text.red
  }

  private func _yellow(_ text: String) -> String {
    return text.yellow
  }

  private func _bold(_ text: String) -> String {
    return text.bold
  }

  private func _color(_ text: String, _ color: NamedColor) -> String {
    return text.applyingColor(color)
  }
}
