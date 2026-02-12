import ArgumentParser
import Foundation
import Rainbow

@available(macOS 12, *)
@main
struct EnjoyableCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "enjoyable",
    abstract: "Enjoyable - Gamepad driver for macOS",
    version: "1.0.0",
    subcommands: [
      StartCommand.self,
      StopCommand.self,
      StatusCommand.self,
      ListDevicesCommand.self,
      ProfileListCommand.self,
      ProfileLoadCommand.self,
      ProfileCreateCommand.self,
      ProfileDeleteCommand.self,
      MapCommand.self,
    ],
    defaultSubcommand: StatusCommand.self
  )

  @Option(name: .shortAndLong, help: "Output style (auto, plain, colored)")
  var outputStyle: String = "auto"

  @Flag(name: .shortAndLong, help: "Enable verbose output")
  var verbose: Bool = false

  mutating func run() async throws {
    if verbose {
      print("OpenGamepadDriver CLI v1.0.0")
      print()
    }
  }
}
