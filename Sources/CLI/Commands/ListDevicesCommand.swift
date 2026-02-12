import ArgumentParser
import Core
import Foundation
import Infrastructure
import Rainbow
import Services

struct ListDevicesCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list-devices",
    abstract: "List detected gamepad devices"
  )

  @Flag(name: .shortAndLong, help: "Show detailed information")
  var verbose: Bool = false

  @Flag(name: .shortAndLong, help: "Show only connected devices")
  var connectedOnly: Bool = false

  func run() async throws {

    print(_bold("Detected Gamepad Devices"))
    print(String(repeating: "─", count: 40))
    print()

    let devices = try await _getConnectedDevices()

    let filteredDevices =
      connectedOnly
      ? devices.filter { $0.connectionState == .connected }
      : devices

    if filteredDevices.isEmpty {
      print("No gamepad devices found.")
      print()
      print("Tips:")
      print("  - Connect your gamepad via USB or Bluetooth")
      print("  - Make sure the daemon is running: enjoyable start")
      print("  - Check if your gamepad is supported")
    } else {
      print("Found \(filteredDevices.count) device(s):")
      print()

      for device in filteredDevices {
        _printDevice(device, verbose: verbose)
        print()
      }

      let connectedCount = filteredDevices.filter { $0.connectionState == .connected }.count
      print(_bold("Summary:"))
      print("  Connected: \(connectedCount)")
      print("  Total: \(filteredDevices.count)")
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

    print("  \(_color("●", stateColor)) \(device.deviceName)")
    print("     Type: \(deviceType)")
    print("     State: \(_color(String(describing: device.connectionState), stateColor))")

    if verbose {
      let deviceID = String(format: Constants.Format.usbDeviceID, device.vendorID, device.productID)
      print("     Vendor ID: 0x\(String(format: "%04X", device.vendorID))")
      print("     Product ID: 0x\(String(format: "%04X", device.productID))")
      print("     Device ID: \(deviceID)")
    }
  }

  private func _bold(_ text: String) -> String {
    return text.bold
  }

  private func _color(_ text: String, _ color: NamedColor) -> String {
    return text.applyingColor(color)
  }
}
