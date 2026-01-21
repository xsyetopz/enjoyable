@preconcurrency import CoreFoundation
import Foundation

enum Constants {
  enum USB {
    static let gameSirG7SEVendorId: UInt16 = 0x3537
    static let gameSirG7SEProductId: UInt16 = 0x1010
    static let xboxOneVendorId: UInt16 = 0x045E
    static let xboxOne2016ProductId: UInt16 = 0x02EA
    static let xboxSeriesXProductId: UInt16 = 0x0B12
    static let defaultInterfaceNumber: UInt8 = 0
    static let defaultAlternateSetting: UInt8 = 0
    static let defaultMaxPacketSize: UInt16 = 64

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

  enum HID {
    static let dualShock4VendorId: UInt16 = 0x054C
    static let dualShock4ProductId: UInt16 = 0x05C4
    static let dualSenseVendorId: UInt16 = 0x054C
    static let dualSenseProductId: UInt16 = 0x0CE6
    static let proControllerVendorId: UInt16 = 0x057E
    static let proControllerProductId: UInt16 = 0x2009
    static let joyConVendorId: UInt16 = 0x057E
    static let joyConProductId: UInt16 = 0x2006
  }

  enum ProtocolConfig {
    static let gipReportSize: Int = 36
    static let xinputReportSize: Int = 14
    static let xinputExtendedReportSize: Int = 17
    static let hidReportSize: Int = 64

    static let gipEndpointIn: UInt8 = 0x81
    static let gipEndpointOut: UInt8 = 0x02
    static let pollRateHz: UInt8 = 0x08

    static let handshakeTimeoutMs: UInt64 = 100
    static let identificationTimeoutMs: UInt64 = 100
    static let enableTimeoutMs: UInt64 = 100

    static let maxRetryCount: Int = 3
  }

  enum DeadZones {
    static let leftStickDefault: Float = 0.2395
    static let rightStickDefault: Float = 0.2652
    static let triggersDefault: Float = 0.0
  }

  enum Input {
    static let stickRangeMin: Int16 = -32767
    static let stickRangeMax: Int16 = 32767
    static let triggerRange: UInt8 = 255
  }

  enum IO {
    static let iokitMainPortDefault: mach_port_t = 0
    static let kernSuccess: KernReturn = 0
    static let ioReturnSuccess: KernReturn = 0
    static let ioUSBTransactionReturned: KernReturn = Int32(bitPattern: 0xe000_4010)
  }

  enum Timing {
    static let retryDelayMs: UInt64 = 50
    static let readErrorDelayMs: UInt64 = 1
    static let recoverableErrorDelayMs: UInt64 = 100
  }

  enum ReportType {
    static let gipInput: UInt8 = 0x02
    static let gipAuthentication: UInt8 = 0x04
    static let gipRumble: UInt8 = 0x09
    static let gipLED: UInt8 = 0x0A
    static let gipModeSwitch: UInt8 = 0x01
  }

  enum GIPCommand {
    static let handshake: UInt8 = 0x01
    static let identification: UInt8 = 0x02
    static let enableInput: UInt8 = 0x05
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
    static let developerModeEnabled = "developerModeEnabled"
    static let launchAtLogin = "launchAtLogin"
    static let showConnectionNotifications = "showConnectionNotifications"
    static let passthroughMode = "passthroughMode"
  }

  enum SFSymbols {
    static let gameControllerFill = "gamecontroller.fill"
    static let gameController = "gamecontroller"
    static let hammerFill = "hammer.fill"
    static let docTextFill = "doc.text.fill"
    static let sparkles = "sparkles"
    static let squareAndArrowDown = "square.and.arrow.down"
    static let link = "link"
    static let docOnDoc = "doc.on.doc"
    static let docText = "doc.text"
    static let antennaRadiowavesLeftAndRight = "antenna.radiowaves.left.and.right"
    static let playFill = "play.fill"
    static let stopFill = "stop.fill"
    static let trash = "trash"
    static let waveformPath = "waveform.path"
    static let waveformPathEcg = "waveform.path.ecg"
    static let speedometer = "speedometer"
    static let handPointUpFill = "hand.point.up.fill"
    static let circle1Fill = "1.circle.fill"
    static let circle2Fill = "2.circle.fill"
    static let circle3Fill = "3.circle.fill"
    static let circle4Fill = "4.circle.fill"
    static let checkmarkCircleFill = "checkmark.circle.fill"
    static let infoCircleFill = "info.circle.fill"
    static let cableConnector = "cable.connector"
    static let cableConnectorSlash = "cable.connector.slash"
    static let arrowClockwise = "arrow.clockwise"
  }

  enum FormatStrings {
    static let hexFourDigits = "%04X"
    static let hexTwoDigits = "%02X"
    static let timestamp = "HH:mm:ss.SSS"
  }

  enum WindowDimensions {
    static let settingsWidth: CGFloat = 500
    static let settingsHeight: CGFloat = 400
    static let configGeneratorWidth: CGFloat = 900
    static let configGeneratorHeight: CGFloat = 700
    static let protocolDebuggerWidth: CGFloat = 800
    static let protocolDebuggerHeight: CGFloat = 600
    static let inputLoggerWidth: CGFloat = 800
    static let inputLoggerHeight: CGFloat = 600
    static let buttonMapperWidth: CGFloat = 900
    static let buttonMapperHeight: CGFloat = 700
    static let debugExporterWidth: CGFloat = 900
    static let debugExporterHeight: CGFloat = 700
    static let usbInspectorWidth: CGFloat = 700
    static let usbInspectorHeight: CGFloat = 600
    static let devicesListWidth: CGFloat = 600
    static let devicesListHeight: CGFloat = 400
  }

  enum ProtocolTestData {
    enum GIP {
      static let handshake = "05 20 00 01 00"
      static let handshakeDescription = "GIP Handshake, Sequence 1, Length 5"
      static let identify = "0A 20 00 03 00 01 14"
      static let identifyDescription = "GIP Identify, Sequence 3, Controller ID 0x14"
      static let enableInput = "06 20 00 02 01 00"
      static let enableInputDescription = "GIP Enable Input, Poll Rate 8ms"
    }

    enum XInput {
      static let initCommand = "01 03 00"
      static let initDescription = "XInput Init, Report Size 3"
    }

    enum HID {
      static let noInitRequired = "No init required"
      static let standardHIDMode = "Standard HID mode"
    }
  }

  enum Timeouts {
    static let usbWriteTimeoutMs: UInt32 = 1000
    static let protocolTestDelayNs: UInt64 = 100_000_000
    static let rateCalculationIntervalNs: UInt64 = 1_000_000_000
  }

  enum UILimits {
    static let maxLogEntries = 1000
    static let maxReportDisplaySize = 64
  }

  enum FileNames {
    static let inputLog = "input_log.txt"
    static let debugInfoPrefix = "debug_info_"
    static let debugInfoExtension = ".md"
  }

  enum NotificationNames {
    static let developerModeChanged = "developerModeChanged"
    static let passthroughModeChanged = "passthroughModeChanged"
  }

  enum URLSchemes {
    static let accessibilitySettings =
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    static let githubIssues = "https://github.com/xsyetopz/enjoyable/issues/new"
  }

  enum AppMetadata {
    static let version = "2.0.0"
    static let name = "Enjoyable"
  }

  enum UIStrings {
    enum Menu {
      static let noControllers = "No Controllers"
      static let settings = "Settings..."
      static let quit = "Quit Enjoyable"
      static let developerTools = "Developer Tools"
      static let usbDeviceInspector = "USB Device Inspector"
      static let protocolDebugger = "Protocol Debugger"
      static let inputLogger = "Input Logger"
      static let buttonMapper = "Button Mapper"
      static let generateConfig = "Generate Config"
      static let exportDebugInfo = "Export Debug Info"
      static let openAccessibilitySettings = "Open Accessibility Settings..."
    }

    enum WindowTitles {
      static let settings = "Enjoyable Settings"
      static let configGenerator = "Config Generator"
      static let protocolDebugger = "Protocol Debugger"
      static let inputLogger = "Input Logger"
      static let buttonMapper = "Button Mapper"
      static let debugExporter = "Export Debug Info"
      static let usbInspector = "USB Device Inspector"
    }

    enum Status {
      static let ready = "Ready"
      static let running = "Running..."
      static let complete = "Complete"
      static let stopped = "Stopped"
      static let cleared = "Cleared"
      static let copiedToClipboard = "Copied to clipboard"
    }

    enum Buttons {
      static let generateConfig = "Generate Config"
      static let saveToFile = "Save to File"
      static let submitToGitHub = "Submit to GitHub"
      static let copy = "Copy"
      static let clear = "Clear"
      static let sendInitSequence = "Send Init Sequence"
      static let stop = "Stop"
      static let saveMapping = "Save Mapping"
      static let clearAll = "Clear All"
      static let generateDebugInfo = "Generate Debug Info"
      static let copyToClipboard = "Copy to Clipboard"
      static let refresh = "Refresh"
    }

    enum EmptyStates {
      static let noControllersConnected = "No controllers connected"
      static let connectUSBController = "Connect USB controller to get started"
      static let noUSBDevicesFound = "No USB devices found"
      static let connectUSBControllerToInspect = "Connect USB controller to inspect"
      static let noConfigGenerated = "No config generated"
      static let fillFormAndGenerate = "Fill in form and click 'Generate Config'"
      static let noResponses = "No responses"
      static let sendInitSequenceToSeeResponses = "Send initialization sequence to see responses"
      static let noInputReports = "No input reports"
      static let pressButtonsToSeeReports = "Press buttons on your controller to see input reports"
      static let noDebugInfoGenerated = "No debug info generated"
      static let clickGenerateToCollectInfo =
        "Click 'Generate Debug Info' to collect system and device information"
    }

    enum Labels {
      static let reportsPerSec = "reports/sec"
      static let paused = "Paused"
      static let currentMappings = "Current Mappings"
      static let noMappingsYet = "No mappings yet"
      static let currentReport = "Current Report"
      static let noChangesDetected = "No changes detected"
      static let byteChanged = "Byte"
      static let changed = "changed"
      static let old = "Old:"
      static let new = "New:"
      static let bit = "Bit"
      static let instructions = "Instructions"
    }
  }
}
