import Foundation

public enum Config {
  public enum Timeout {
    public static let infinite: UInt32 = 0
    public static let defaultTransfer: UInt32 = 1000
    public static let shortTransfer: UInt32 = 100
    public static let longTransfer: UInt32 = 5000
    public static let deviceOpen: UInt32 = 2000
    public static let deviceClose: UInt32 = 1000
    public static let controlTransfer: UInt32 = 2000
    public static let bulkTransfer: UInt32 = 5000
    public static let interruptTransfer: UInt32 = 1000
    public static let isoTransfer: UInt32 = 1000
  }

  public enum Device {
    public static let maxPacketSize: Int = 512
    public static let maxEndpoints: Int = 32
    public static let maxInterfaces: Int = 32
    public static let maxConfigurations: Int = 8
    public static let maxAltSettings: Int = 32
  }

  public enum Transfer {
    public static let maxBufferLength: Int = 65536
    public static let minBufferLength: Int = 1
    public static let isoPacketSize: Int = 1024
    public static let maxIsoPackets: Int = 8
  }

  public enum String {
    public static let maxLanguageCount: Int = 128
    public static let maxStringLength: Int = 256
    public static let defaultLanguage: UInt16 = 0x0409
  }

  public enum Descriptor {
    public static let device: UInt8 = 1
    public static let configuration: UInt8 = 2
    public static let string: UInt8 = 3
    public static let interface: UInt8 = 4
    public static let endpoint: UInt8 = 5
    public static let bos: UInt8 = 15
    public static let deviceCapability: UInt8 = 16
    public static let hid: UInt8 = 0x21
    public static let report: UInt8 = 0x22
    public static let physical: UInt8 = 0x23
  }

  public enum Class {
    public static let perInterface: UInt8 = 0x00
    public static let audio: UInt8 = 0x01
    public static let communication: UInt8 = 0x02
    public static let hid: UInt8 = 0x03
    public static let physical: UInt8 = 0x05
    public static let image: UInt8 = 0x06
    public static let printer: UInt8 = 0x07
    public static let massStorage: UInt8 = 0x08
    public static let hub: UInt8 = 0x09
    public static let data: UInt8 = 0x0a
    public static let smartCard: UInt8 = 0x0b
    public static let contentSecurity: UInt8 = 0x0d
    public static let video: UInt8 = 0x0e
    public static let personalHealthcare: UInt8 = 0x0f
    public static let audioVideo: UInt8 = 0x10
    public static let billboard: UInt8 = 0x11
    public static let usbTypeCBridge: UInt8 = 0x12
    public static let diagnostic: UInt8 = 0xdc
    public static let wireless: UInt8 = 0xe0
    public static let misc: UInt8 = 0xef
    public static let applicationSpecific: UInt8 = 0xfe
    public static let vendorSpecific: UInt8 = 0xff
  }

  public enum Endpoint {
    public static let directionMask: UInt8 = 0x80
    public static let addressMask: UInt8 = 0x0f
    public static let numberShift: UInt8 = 0
    public static let inDirection: UInt8 = 0x80
    public static let outDirection: UInt8 = 0x00
  }

  public enum RequestType {
    public static let typeMask: UInt8 = 0x60
    public static let recipientMask: UInt8 = 0x1f
    public static let standard: UInt8 = 0x00
    public static let classType: UInt8 = 0x20
    public static let vendor: UInt8 = 0x40
    public static let reserved: UInt8 = 0x60
  }

  public enum Recipient {
    public static let device: UInt8 = 0x00
    public static let interface: UInt8 = 0x01
    public static let endpoint: UInt8 = 0x02
    public static let other: UInt8 = 0x03
  }

  public enum Request {
    public static let getStatus: UInt8 = 0x00
    public static let clearFeature: UInt8 = 0x01
    public static let setFeature: UInt8 = 0x03
    public static let setAddress: UInt8 = 0x05
    public static let getDescriptor: UInt8 = 0x06
    public static let setDescriptor: UInt8 = 0x07
    public static let getConfiguration: UInt8 = 0x08
    public static let setConfiguration: UInt8 = 0x09
    public static let getInterface: UInt8 = 0x0a
    public static let setInterface: UInt8 = 0x0b
    public static let synchFrame: UInt8 = 0x0c
  }
}
