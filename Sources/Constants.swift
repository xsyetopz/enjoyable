@preconcurrency import CoreFoundation
import Foundation

enum Constants {
  enum USB {
    static let usbIn: UInt8 = 0x80
    static let usbOut: UInt8 = 0x00

    static let ioCFPlugInInterfaceID = CFUUIDGetConstantUUIDWithBytes(
      nil,
      0xC2,
      0x44,
      0xE8,
      0x58,
      0x10,
      0x9A,
      0x11,
      0xD4,
      0x91,
      0xD4,
      0x00,
      0x50,
      0xE4,
      0x60,
      0xD8,
      0x72
    )

    static let ioUSBDeviceUserClientTypeID = CFUUIDGetConstantUUIDWithBytes(
      nil,
      0x2D,
      0x97,
      0x86,
      0xC7,
      0x9B,
      0xF4,
      0x11,
      0xD5,
      0x08,
      0x00,
      0x00,
      0x39,
      0x37,
      0x53,
      0x66,
      0x01
    )

    static let ioUSBDeviceInterfaceID = CFUUIDGetConstantUUIDWithBytes(
      nil,
      0x05,
      0xC7,
      0x5A,
      0x47,
      0x9A,
      0xF9,
      0x11,
      0xD5,
      0x08,
      0x00,
      0x00,
      0x39,
      0x37,
      0x53,
      0x66,
      0x01
    )

    static let ioUSBInterfaceUserClientTypeID = CFUUIDGetConstantUUIDWithBytes(
      nil,
      0x2D,
      0x97,
      0x86,
      0xC8,
      0x9B,
      0xF4,
      0x11,
      0xD5,
      0x08,
      0x00,
      0x00,
      0x39,
      0x37,
      0x53,
      0x66,
      0x01
    )

    static let ioUSBInterfaceInterfaceID = CFUUIDGetConstantUUIDWithBytes(
      nil,
      0x73,
      0xC9,
      0x7A,
      0xE8,
      0x9A,
      0xF9,
      0x11,
      0xD5,
      0x08,
      0x00,
      0x00,
      0x39,
      0x37,
      0x53,
      0x66,
      0x01
    )
  }

  enum ProtocolConfig {
    static let gipReportSize: Int = 36

    static let gipEndpointIn: UInt8 = 0x81
    static let gipEndpointOut: UInt8 = 0x02
  }

  enum DeadZones {
    static let leftStickDefault: Float = 0.2395
    static let rightStickDefault: Float = 0.2652
  }

  enum Input {
    static let stickRangeMin: Int16 = -32767
    static let stickRangeMax: Int16 = 32767
    static let triggerRange: UInt8 = 255
  }

  enum IO {
    static let ioReturnSuccess: KernReturn = 0
    static let ioUSBTransactionReturned: KernReturn = Int32(bitPattern: 0xe000_4010)
  }

  enum ReportType {
    static let gipInput: UInt8 = 0x02
    static let gipRumble: UInt8 = 0x09
  }

  enum IOKitKeys {
    static let ioUSBDeviceClassName = "IOUSBDevice" as CFString
    static let idVendorString = "idVendor" as CFString
    static let idProductString = "idProduct" as CFString
    static let usbProductString = "kUSBProductString" as CFString
    static let usbVendorString = "kUSBVendorString" as CFString
    static let usbSerialNumberString = "kUSBSerialNumberString" as CFString
  }

  enum UserDefaultsKeys {
    static let showConnectionNotifications = "showConnectionNotifications"
    static let passthroughMode = "passthroughMode"
  }

  enum SFSymbols {
    static let gameControllerFill = "gamecontroller.fill"
    static let gameController = "gamecontroller"
  }

  enum FormatStrings {
    static let hexFourDigits = "%04X"
    static let timestamp = "HH:mm:ss.SSS"
  }

  enum WindowDimensions {
    static let settingsWidth: CGFloat = 500
    static let settingsHeight: CGFloat = 400
    static let devicesListWidth: CGFloat = 600
    static let devicesListHeight: CGFloat = 400
  }

  enum NotificationNames {
    static let passthroughModeChanged = "passthroughModeChanged"
  }

  enum URLSchemes {
    static let accessibilitySettings =
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  }

  enum AppMetadata {
    static let version = "2.0.0"
    static let name = "Enjoyable"
  }

  enum UIStrings {
    enum Menu {
      static let noControllers = "No controllers"
      static let settings = "Settings..."
      static let quit = "Quit Enjoyable"
      static let openAccessibilitySettings = "Open Accessibility Settings..."
    }

    enum WindowTitles {
      static let settings = "Enjoyable Settings"
    }

    enum EmptyStates {
      static let noControllersConnected = "No controllers connected"
      static let connectUSBController = "Connect USB controller to get started"
    }
  }
}
