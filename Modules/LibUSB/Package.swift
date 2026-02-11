// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "LibUSB",
  platforms: [
    .macOS(.v11)
  ],
  products: [
    .library(
      name: "LibUSB",
      type: .static,
      targets: ["LibUSB"]
    )
  ],
  targets: [
    .target(
      name: "LibUSB",
      dependencies: ["CLibUSB"],
      path: "Sources/LibUSB",
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
      ]
    ),
    .systemLibrary(
      name: "CLibUSB",
      path: "Sources/CLibUSB",
      pkgConfig: "libusb-1.0",
      providers: [
        .brew(["libusb"]),
        .apt(["libusb-1.0-0-dev"]),
      ]
    ),
  ]
)
