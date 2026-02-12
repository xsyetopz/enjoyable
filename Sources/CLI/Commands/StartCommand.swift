import ArgumentParser
import Core
import Foundation
import Rainbow

struct StartCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "start",
    abstract: "Start the Enjoyable gamepad driver daemon"
  )

  @Flag(name: .shortAndLong, help: "Restart the daemon if already running")
  var restart: Bool = false

  @Flag(name: .shortAndLong, help: "Verbose output")
  var verbose: Bool = false

  func run() async throws {

    if restart {
      if DaemonControl.isDaemonRunning() {
        print("Restarting daemon...")
        try DaemonControl.restartDaemon()
        print("Daemon restarted successfully.")
      } else {
        print("Daemon not running, starting...")
        try DaemonControl.startDaemon()
        print("Daemon started successfully.")
      }
    } else {
      if DaemonControl.isDaemonRunning() {
        print("Daemon is already running.")
        return
      }

      try DaemonControl.startDaemon()
      print("Daemon started successfully.")
    }
  }
}
