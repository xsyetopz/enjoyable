// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "OpenGameControllerDriver",
  platforms: [
    .macOS(.v12)
  ],
  products: [
    .executable(
      name: "enjoyable-cli",
      targets: ["CLI"]
    ),
    .executable(
      name: "enjoyable",
      targets: ["GUI"]
    ),
  ],
  dependencies: [],
  targets: []
)
