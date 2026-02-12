import Foundation

public enum Constants {
  public enum Profile {
    public static let currentVersion: Int = AppConstants.Profile.currentVersion
    public static let defaultProfileName: String = AppConstants.Profile.defaultName
    public static let fileExtension: String = AppConstants.Profile.fileExtension
    public static let directoryName: String = AppConstants.Profile.directoryName
  }

  public enum FileName {
    public static let invalidCharacters: CharacterSet = AppConstants.FileName.invalidCharacters
  }

  public enum FileIO {
    public static let timeoutSeconds: TimeInterval = AppConstants.FileIO.timeoutSeconds
    public static let loadSeconds: TimeInterval = AppConstants.FileIO.loadSeconds
    public static let saveSeconds: TimeInterval = AppConstants.FileIO.saveSeconds
  }

  public enum Input {
    public static let triggerThreshold: UInt8 = AppConstants.Input.triggerThreshold
    public static let mouseSensitivity: Double = AppConstants.Input.mouseSensitivity
    public static let mouseDeadzone: Double = AppConstants.Input.mouseDeadzone
    public static let scrollSensitivity: Double = AppConstants.Input.scrollSensitivity
    public static let scrollDeadzone: Double = AppConstants.Input.scrollDeadzone
  }

  public enum Format {
    public static let usbDeviceID: String = AppConstants.Format.usbDeviceID
  }

  public enum KeyCode {
    public static let unmapped: UInt16 = KeyCodeConstants.unmapped
    public enum Letter {
      public static let a: UInt16 = KeyCodeConstants.Letter.a
      public static let s: UInt16 = KeyCodeConstants.Letter.s
      public static let d: UInt16 = KeyCodeConstants.Letter.d
      public static let f: UInt16 = KeyCodeConstants.Letter.f
      public static let h: UInt16 = KeyCodeConstants.Letter.h
      public static let g: UInt16 = KeyCodeConstants.Letter.g
      public static let z: UInt16 = KeyCodeConstants.Letter.z
      public static let x: UInt16 = KeyCodeConstants.Letter.x
      public static let c: UInt16 = KeyCodeConstants.Letter.c
      public static let v: UInt16 = KeyCodeConstants.Letter.v
      public static let b: UInt16 = KeyCodeConstants.Letter.b
      public static let q: UInt16 = KeyCodeConstants.Letter.q
      public static let w: UInt16 = KeyCodeConstants.Letter.w
      public static let e: UInt16 = KeyCodeConstants.Letter.e
      public static let r: UInt16 = KeyCodeConstants.Letter.r
      public static let y: UInt16 = KeyCodeConstants.Letter.y
      public static let t: UInt16 = KeyCodeConstants.Letter.t
    }
    public enum Number {
      public static let one: UInt16 = KeyCodeConstants.Number.one
      public static let two: UInt16 = KeyCodeConstants.Number.two
      public static let three: UInt16 = KeyCodeConstants.Number.three
      public static let four: UInt16 = KeyCodeConstants.Number.four
      public static let five: UInt16 = KeyCodeConstants.Number.five
      public static let six: UInt16 = KeyCodeConstants.Number.six
      public static let seven: UInt16 = KeyCodeConstants.Number.seven
      public static let eight: UInt16 = KeyCodeConstants.Number.eight
      public static let nine: UInt16 = KeyCodeConstants.Number.nine
      public static let zero: UInt16 = KeyCodeConstants.Number.zero
    }
    public enum Special {
      public static let space: UInt16 = KeyCodeConstants.Special.space
      public static let returnKey: UInt16 = KeyCodeConstants.Special.returnKey
      public static let tab: UInt16 = KeyCodeConstants.Special.tab
      public static let escape: UInt16 = KeyCodeConstants.Special.escape
      public static let backspace: UInt16 = KeyCodeConstants.Special.backspace
    }
  }

  public enum USBTimeout {
    public static let enumerationMs: UInt32 = USBConstants.Timeout.enumerationMs
    public static let usbMs: UInt32 = USBConstants.Timeout.usbMs
    public static let controlTransferMs: UInt32 = USBConstants.Timeout.controlTransferMs
    public static let interruptTransferMs: UInt32 = USBConstants.Timeout.interruptTransferMs
    public static let monitoringMs: UInt32 = USBConstants.Timeout.monitoringMs
    public static let pollIntervalNs: UInt64 = USBConstants.Timeout.pollIntervalNs
  }

  public enum USBVendor {
    public static let microsoft: UInt16 = USBConstants.Vendor.microsoft
    public static let madCatz: UInt16 = USBConstants.Vendor.madCatz
    public static let logitech: UInt16 = USBConstants.Vendor.logitech
    public static let pdp: UInt16 = USBConstants.Vendor.pdp
    public static let razer: UInt16 = USBConstants.Vendor.razer
    public static let hori: UInt16 = USBConstants.Vendor.hori
    public static let razerAlt: UInt16 = USBConstants.Vendor.razerAlt
    public static let gamesir: UInt16 = USBConstants.Vendor.gamesir
    public static let sony: UInt16 = USBConstants.Vendor.sony
    public static let nintendo: UInt16 = USBConstants.Vendor.nintendo
    public static let bitdo: UInt16 = USBConstants.Vendor.bitdo
  }

  public enum USBDeviceName {
    public static let xbox360: [UInt16: String] = USBConstants.DeviceName.xbox360
    public static let xboxOne: [UInt16: String] = USBConstants.DeviceName.xboxOne
    public static let xboxWireless: [UInt16: String] = USBConstants.DeviceName.xboxWireless
    public static let xboxAdaptive: [UInt16: String] = USBConstants.DeviceName.xboxAdaptive
    public static let dualShock4: [UInt16: String] = USBConstants.DeviceName.dualShock4
    public static let dualSense: [UInt16: String] = USBConstants.DeviceName.dualSense
    public static let dualSenseEdge: [UInt16: String] = USBConstants.DeviceName.dualSenseEdge
    public static let switchPro: [UInt16: String] = USBConstants.DeviceName.switchPro
    public static let switchJoyCon: [UInt16: String] = USBConstants.DeviceName.switchJoyCon
  }
}
