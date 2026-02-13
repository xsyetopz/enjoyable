// swift-tools-version: 6.2
import PackageDescription

/// SwiftUSB package configuration.
public let kPackage = Package(
  name: "SwiftUSB",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "SwiftUSB",
      targets: ["SwiftUSB"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-testing.git", branch: "main"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0")
  ],
  targets: [
    .target(
      name: "SwiftUSB",
      dependencies: [
        "CLibUSB",
        .product(name: "Logging", package: "swift-log")
      ],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .systemLibrary(
      name: "CLibUSB",
      pkgConfig: "libusb-1.0",
      providers: [
        .brew(["libusb"]),
        .apt(["libusb-1.0-0-dev"]),
      ]
    ),
  ]
)