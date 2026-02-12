// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Enjoyable",
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
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.0"),
    .package(url: "https://github.com/onevcat/Rainbow.git", from: "4.0.0"),
  ],
  targets: [
    .target(
      name: "Core",
      dependencies: [],
      path: "Sources/Core",
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
        .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
      ]
    ),
    .target(
      name: "Configuration",
      dependencies: ["Core", .product(name: "Rainbow", package: "Rainbow")],
      path: "Sources/Configuration",
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
        .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
      ],
      linkerSettings: [
        .linkedFramework("CoreGraphics")
      ]
    ),
    .target(
      name: "Protocol",
      dependencies: ["Core", "LibUSB"],
      path: "Sources/Protocol",
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
        .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
      ]
    ),
    .target(
      name: "Output",
      dependencies: ["Core", "Configuration"],
      path: "Sources/Output",
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
        .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
      ],
      linkerSettings: [
        .linkedFramework("GameController"),
        .linkedFramework("CoreGraphics"),
        .linkedFramework("ApplicationServices"),
      ]
    ),
    .target(
      name: "Infrastructure",
      dependencies: ["Core", "Configuration", "LibUSB"],
      path: "Sources/Infrastructure",
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
        .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
      ],
      linkerSettings: [
        .linkedFramework("CoreGraphics")
      ]
    ),
    .target(
      name: "Services",
      dependencies: [
        "Core", "Configuration", "LibUSB", "Protocol", "Output", "Infrastructure",
        .product(name: "Rainbow", package: "Rainbow"),
      ],
      path: "Sources/Services",
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
        .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
      ]
    ),
    .target(
      name: "Application",
      dependencies: [
        "Core", "Configuration", "Services",
      ],
      path: "Sources/Application",
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
        .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
      ],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("Foundation"),
      ]
    ),
    .executableTarget(
      name: "CLI",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Rainbow", package: "Rainbow"),
        "Core", "Configuration", "Protocol", "Output", "Services", "Application",
      ],
      path: "Sources/CLI",
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
        .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
      ],
      linkerSettings: [
        .linkedFramework("GameController"),
        .linkedFramework("IOKit"),
        .linkedFramework("ApplicationServices"),
        .linkedFramework("CoreGraphics"),
        .linkedFramework("AppKit"),
        .linkedFramework("IOUSBHost"),
        .unsafeFlags(["-L/opt/homebrew/lib", "-L/usr/local/lib"], .when(platforms: [.macOS])),
        .linkedLibrary("usb-1.0"),
      ]
    ),
    .executableTarget(
      name: "GUI",
      dependencies: [
        "Core", "Configuration", "Protocol", "Output", "Services", "Application", "Infrastructure",
        "LibUSB",
      ],
      path: "Sources/GUI",
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
        .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
      ],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("SwiftUI"),
        .linkedFramework("Combine"),
        .linkedFramework("GameController"),
        .linkedFramework("IOKit"),
        .linkedFramework("IOUSBHost"),
        .linkedFramework("CoreGraphics"),
        .unsafeFlags(["-L/opt/homebrew/lib", "-L/usr/local/lib"], .when(platforms: [.macOS])),
        .linkedLibrary("usb-1.0"),
      ]
    ),
    .target(
      name: "LibUSB",
      dependencies: [
        .target(name: "CLibUSB")
      ],
      path: "Modules/LibUSB/Sources/LibUSB",
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
        .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
      ]
    ),
    .systemLibrary(
      name: "CLibUSB",
      path: "Modules/LibUSB/Sources/CLibUSB",
      pkgConfig: "libusb-1.0",
      providers: [
        .brew(["libusb"]),
        .apt(["libusb-1.0-0-dev"]),
      ]
    ),
  ]
)
