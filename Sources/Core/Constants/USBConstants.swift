import Foundation

public enum USBConstants {
  public enum Vendor {
    public static let microsoft: UInt16 = 0x045E
    public static let madCatz: UInt16 = 0x0738
    public static let logitech: UInt16 = 0x046D
    public static let pdp: UInt16 = 0x0E6F
    public static let razer: UInt16 = 0x24C6
    public static let hori: UInt16 = 0x0F0D
    public static let razerAlt: UInt16 = 0x1532
    public static let gamesir: UInt16 = 0x3537
    public static let sony: UInt16 = 0x054C
    public static let nintendo: UInt16 = 0x057E
    public static let bitdo: UInt16 = 0x2DC8
  }

  public enum Timeout {
    public static let enumerationMs: UInt32 = 5000
    public static let usbMs: UInt32 = 1000
    public static let controlTransferMs: UInt32 = 100
    public static let interruptTransferMs: UInt32 = 100
    public static let monitoringMs: UInt32 = 1000
    public static let pollIntervalNs: UInt64 = 500_000_000
  }

  public enum DeviceName {
    public static let xbox360: [UInt16: String] = [0x028E: "Xbox 360 Controller"]
    public static let xboxOne: [UInt16: String] = [0x02A1: "Xbox One Controller"]
    public static let xboxWireless: [UInt16: String] = [0x02FF: "Xbox Wireless Controller"]
    public static let xboxAdaptive: [UInt16: String] = [0x0B13: "Xbox Adaptive Controller"]
    public static let dualShock4: [UInt16: String] = [0x05C4: "DualShock 4"]
    public static let dualSense: [UInt16: String] = [0x09CC: "DualSense"]
    public static let dualSenseEdge: [UInt16: String] = [0x0CE6: "DualSense Edge"]
    public static let switchPro: [UInt16: String] = [0x2009: "Nintendo Switch Pro Controller"]
    public static let switchJoyCon: [UInt16: String] = [0x2006: "Nintendo Switch Joy-Con"]
  }
}
