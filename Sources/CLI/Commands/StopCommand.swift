import ArgumentParser
import Core
import Foundation
import Rainbow

struct StopCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "stop",
    abstract: "Stop the Enjoyable gamepad driver daemon"
  )

  @Flag(name: .shortAndLong, help: "Force kill the daemon")
  var force: Bool = false

  func run() async throws {

    guard DaemonControl.isDaemonRunning() else {
      print("Daemon is not running.")
      return
    }

    if force {
      let task = Process()
      task.launchPath = "/bin/launchctl"
      task.arguments = ["kill", "TERM", "com.yukkurigames.Enjoyable.driver"]

      try task.run()
      task.waitUntilExit()

      if task.terminationStatus == 0 {
        print("Daemon stopped successfully.")
      } else {
        throw DaemonControl.DaemonError.stopFailed("Force kill failed")
      }
    } else {
      try DaemonControl.stopDaemon()
      print("Daemon stopped successfully.")
    }
  }
}
