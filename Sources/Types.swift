import CoreFoundation
import Foundation

typealias DeviceId = UUID
typealias VendorId = UInt16
typealias ProductId = UInt16

typealias ButtonSet = Set<GamepadButton>
typealias KeyCode = UInt64

typealias IOObject = io_object_t
extension IOObject {
  func getStringProperty(_ key: CFString) -> String? {
    guard let unmanagedRef = IORegistryEntryCreateCFProperty(self, key, kCFAllocatorDefault, 0)
    else {
      return nil
    }

    defer {
      unmanagedRef.release()
    }

    let cfValue = unmanagedRef.takeUnretainedValue()
    guard CFGetTypeID(cfValue) == CFStringGetTypeID() else { return nil }

    let cfString = (cfValue as! CFString)
    return (cfString as NSString) as String
  }

  func getUInt16Property(_ key: CFString) -> UInt16? {
    guard let unmanagedRef = IORegistryEntryCreateCFProperty(self, key, kCFAllocatorDefault, 0)
    else {
      return nil
    }

    defer {
      unmanagedRef.release()
    }

    let cfValue = unmanagedRef.takeUnretainedValue()
    return cfValue as? UInt16
  }

  func getCFProperty<T>(_ key: CFString) -> T? {
    if T.self == String.self {
      return getStringProperty(key) as? T
    } else if T.self == UInt16.self {
      return getUInt16Property(key) as? T
    }

    guard let unmanagedRef = IORegistryEntryCreateCFProperty(self, key, kCFAllocatorDefault, 0)
    else {
      return nil
    }
    let cfValue = unmanagedRef.takeRetainedValue()
    return cfValue as? T
  }
}

typealias IOIterator = io_iterator_t
typealias IORegistryEntry = io_registry_entry_t

typealias KernReturn = kern_return_t

enum TransportType {
  case usb
  case bluetooth
  case hid
}

enum ProtocolType: String, Codable {
  case gip = "GIP"
  case xinput = "XInput"
  case hid = "HID"
  case switchHID = "SwitchHID"
  case ps4HID = "PS4HID"
  case ps5HID = "PS5HID"
}

enum ConnectionType {
  case usb
  case bluetooth
  case wired
}

enum GamepadButton: String, Codable, Sendable, CaseIterable {
  case a, b, x, y
  case leftShoulder, rightShoulder
  case leftTrigger, rightTrigger
  case back, start
  case leftStick, rightStick
  case guide
  case share, view
  case dPadUp, dPadDown, dPadLeft, dPadRight
  case mute
}

enum DPadDirection: Sendable {
  case north, northEast, east, southEast
  case south, southWest, west, northWest
  case centered
}

enum ActionType {
  case keyPress
  case mouseMove
  case mouseButton
  case mouseScroll
}

struct StickPosition: Sendable {
  var x: Float
  var y: Float
}

struct ControllerFeatures: Codable {
  var vibration: Bool?
  var rgb: Bool?
  var touchpad: Bool?
  var hapticFeedback: Bool?
}

struct DeadZones: Codable {
  var leftStick: Float?
  var rightStick: Float?
  var triggers: Float?
}

struct InitStep: Codable {
  var type: StepType
  var data: [UInt8]?
  var delayMs: UInt32?
  var expectedResponse: [UInt8]?
}

enum StepType: String, Codable {
  case write
  case read
  case delay
  case waitForAck
}

struct ButtonMappingEntry: Codable {
  var button: String
  var byte: Int
  var bit: Int?
  var usage: UInt32?
}

struct ReportFormat: Codable {
  var buttonMappingFormat: String
  var fields: [FieldMapping]
}

struct FieldMapping: Codable {
  var name: String
  var offset: Int
  var size: Int
  var type: String
}

struct ControllerCapabilities {
  var buttonCount: Int
  var analogStickCount: Int
  var triggerCount: Int
  var hasTouchpad: Bool
  var hasGyro: Bool
  var hasRumble: Bool
  var hasRGB: Bool
}

struct DeviceCandidate: Sendable {
  var id: DeviceId
  var transportType: TransportType
  var protocolType: ProtocolType
  var vendorId: VendorId
  var productId: ProductId
  var name: String
  var manufacturer: String?
  var serialNumber: String?
  var ioObject: IOObject?
}

struct ControllerInfo: Sendable {
  var id: DeviceId
  var name: String
  var vendorId: VendorId
  var productId: ProductId
  var protocolType: ProtocolType
  var connectionType: ConnectionType
  var capabilities: ControllerCapabilities
}

struct InputEvent: Sendable {
  var buttons: ButtonSet
  var dPadDirection: DPadDirection
  var leftTrigger: Float?
  var rightTrigger: Float?
  var leftStick: StickPosition?
  var rightStick: StickPosition?
  var timestamp: Date
}

struct OutputAction {
  var type: ActionType
  var keyCode: KeyCode?
  var keyFlags: UInt64?
  var mouseX: CGFloat?
  var mouseY: CGFloat?
  var mouseButton: UInt32?
  var mouseButtonState: UInt32?
  var scrollDeltaX: CGFloat?
  var scrollDeltaY: CGFloat?
}

struct Mapping {
  var id: String
  var name: String
  var controllerId: String
  var inputMappings: [String: OutputAction]
}
