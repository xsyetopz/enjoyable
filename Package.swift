// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Enjoyable",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .executable(
      name: "Enjoyable",
      targets: ["Enjoyable"]
    )
  ],
  dependencies: [],
  targets: [
    .systemLibrary(
      name: "LibUSB",
      path: "Sources/CLibUSB",
      pkgConfig: "libusb-1.0"
    ),
    .executableTarget(
      name: "Enjoyable",
      dependencies: ["LibUSB"],
      path: "Sources",
      exclude: ["CLibUSB"],
      linkerSettings: [
        .linkedFramework("IOKit"),
        .linkedFramework("ApplicationServices"),
        .linkedFramework("CoreGraphics"),
        .linkedFramework("AppKit"),
        .linkedFramework("SwiftUI"),
        .linkedFramework("Combine"),
        .linkedFramework("IOUSBHost"),
        .unsafeFlags(["-L/opt/homebrew/lib", "-L/usr/local/lib"]),
        .linkedLibrary("usb-1.0"),
      ]
    ),
  ]
)
