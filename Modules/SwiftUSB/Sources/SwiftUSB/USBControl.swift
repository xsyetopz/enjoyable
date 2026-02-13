import Foundation
import Logging

extension USBControl {
  internal static let logger = Logger(label: "io.github.xsyetopz.swiftusb.USBControl")
}

public enum USBControlRecipient {
  case device
  case interface
  case endpoint
}

public enum USBControl {
  public static let endpointHalt: UInt16 = 0
  public static let deviceRemoteWakeup: UInt16 = 1
  public static let functionSuspend: UInt16 = 0
  public static let u1Enable: UInt16 = 48
  public static let u2Enable: UInt16 = 49
  public static let ltmEnable: UInt16 = 50

  public static let getStatusRequest: UInt8 = 0x00
  public static let clearFeatureRequest: UInt8 = 0x01
  public static let setFeatureRequest: UInt8 = 0x03
  public static let getDescriptorRequest: UInt8 = 0x06
  public static let setDescriptorRequest: UInt8 = 0x07
  public static let getConfigurationRequest: UInt8 = 0x08
  public static let getInterfaceRequest: UInt8 = 0x0A

  private static func makeRequestType(
    direction: UInt8,
    type: UInt8,
    recipient: UInt8
  ) -> UInt8 {
    direction | type | recipient
  }

  public static func getStatus(
    on handle: USBDeviceHandle,
    recipient: USBControlRecipient,
    interface: Int? = nil
  ) throws -> UInt16 {
    let (bmRequestType, wIndex) = parseRecipient(recipient, direction: 0x80, interface: interface)

    Self.logger.debug(
      "getStatus - type=0x\(String(format: "%02X", bmRequestType)) request=0x00 index=\(wIndex)"
    )

    let data = try handle.controlTransfer(
      requestType: bmRequestType,
      request: getStatusRequest,
      value: 0,
      index: wIndex,
      data: nil
    )

    guard data.count >= 2 else {
      Self.logger.debug("getStatus - insufficient data returned")
      throw USBError(code: -99, context: "Control transfer returned insufficient data")
    }

    let status = UInt16(data[0]) | (UInt16(data[1]) << 8)
    Self.logger.debug("getStatus - status=0x\(String(format: "%04X", status))")
    return status
  }

  public static func clearFeature(
    on handle: USBDeviceHandle,
    feature: UInt16,
    recipient: USBControlRecipient,
    interface: Int? = nil
  ) throws {
    let (bmRequestType, wIndex) = parseRecipient(recipient, direction: 0x00, interface: interface)

    Self.logger.debug(
      "clearFeature - type=0x\(String(format: "%02X", bmRequestType)) request=0x01 feature=\(feature) index=\(wIndex)"
    )

    if feature == endpointHalt {
      try handle.clearHalt(endpoint: UInt8(wIndex))
    } else {
      _ = try handle.controlTransfer(
        requestType: bmRequestType,
        request: clearFeatureRequest,
        value: feature,
        index: wIndex,
        data: nil
      )
    }

    Self.logger.debug("clearFeature - completed successfully")
  }

  public static func setFeature(
    on handle: USBDeviceHandle,
    feature: UInt16,
    recipient: USBControlRecipient,
    interface: Int? = nil
  ) throws {
    let (bmRequestType, wIndex) = parseRecipient(recipient, direction: 0x00, interface: interface)

    Self.logger.debug(
      "setFeature - type=0x\(String(format: "%02X", bmRequestType)) request=0x03 feature=\(feature) index=\(wIndex)"
    )

    _ = try handle.controlTransfer(
      requestType: bmRequestType,
      request: setFeatureRequest,
      value: feature,
      index: wIndex,
      data: nil
    )

    Self.logger.debug("setFeature - completed successfully")
  }

  public static func getDescriptor(
    on handle: USBDeviceHandle,
    type: UInt8,
    index: UInt8,
    length: Int
  ) throws -> Data {
    try getDescriptor(
      on: handle,
      type: type,
      index: index,
      languageID: 0,
      length: length
    )
  }

  public static func getDescriptor(
    on handle: USBDeviceHandle,
    type: UInt8,
    index: UInt8,
    languageID: UInt16,
    length: Int
  ) throws -> Data {
    let wValue = UInt16(type) << 8 | UInt16(index)
    let bmRequestType = makeRequestType(direction: 0x80, type: 0x00, recipient: 0x00)

    Self.logger.debug(
      "getDescriptor - type=0x\(String(format: "%02X", bmRequestType)) descType=0x\(String(format: "%02X", type)) descIndex=\(index) langID=\(languageID) length=\(length)"
    )

    let data = try handle.controlTransfer(
      requestType: bmRequestType,
      request: getDescriptorRequest,
      value: wValue,
      index: languageID,
      data: nil,
      timeout: UInt32(length * 10 + 1000)
    )

    if data.count < 2 {
      Self.logger.debug("getDescriptor - invalid descriptor returned")
      throw USBError(code: -99, context: "Invalid descriptor returned")
    }

    Self.logger.debug("getDescriptor - received \(data.count) bytes")
    return data
  }

  public static func setDescriptor(
    on handle: USBDeviceHandle,
    descriptor: Data,
    type: UInt8,
    index: UInt8,
    languageID: UInt16? = nil
  ) throws {
    let wValue = UInt16(type) << 8 | UInt16(index)
    let wIndex = languageID ?? 0
    let bmRequestType = makeRequestType(direction: 0x00, type: 0x00, recipient: 0x00)

    Self.logger.debug(
      "setDescriptor - type=0x\(String(format: "%02X", bmRequestType)) descType=0x\(String(format: "%02X", type)) descIndex=\(index) langID=\(wIndex) length=\(descriptor.count)"
    )

    _ = try handle.controlTransfer(
      requestType: bmRequestType,
      request: setDescriptorRequest,
      value: wValue,
      index: wIndex,
      data: descriptor
    )

    Self.logger.debug("setDescriptor - completed successfully")
  }

  public static func getConfiguration(on handle: USBDeviceHandle) throws -> UInt8 {
    let bmRequestType = makeRequestType(direction: 0x80, type: 0x00, recipient: 0x00)

    Self.logger.debug(
      "getConfiguration - type=0x\(String(format: "%02X", bmRequestType)) request=0x08"
    )

    let data = try handle.controlTransfer(
      requestType: bmRequestType,
      request: getConfigurationRequest,
      value: 0,
      index: 0,
      data: nil
    )

    guard let firstByte = data.first else {
      Self.logger.debug("getConfiguration - no data returned")
      throw USBError(code: -99, context: "Control transfer returned no data")
    }

    Self.logger.debug("getConfiguration - configuration=\(firstByte)")
    return firstByte
  }

  public static func setConfiguration(
    on handle: USBDeviceHandle,
    configuration: Int
  ) throws {
    Self.logger.debug("setConfiguration - configuration=\(configuration)")

    try handle.setConfiguration(configuration)
  }

  public static func getInterface(
    on handle: USBDeviceHandle,
    interfaceNumber: Int
  ) throws -> UInt8 {
    let bmRequestType = makeRequestType(direction: 0x81, type: 0x00, recipient: 0x01)

    Self.logger.debug(
      "getInterface - type=0x\(String(format: "%02X", bmRequestType)) request=0x0A interface=\(interfaceNumber)"
    )

    let data = try handle.controlTransfer(
      requestType: bmRequestType,
      request: getInterfaceRequest,
      value: 0,
      index: UInt16(interfaceNumber),
      data: nil
    )

    guard let firstByte = data.first else {
      Self.logger.debug("getInterface - no data returned")
      throw USBError(code: -99, context: "Control transfer returned no data")
    }

    Self.logger.debug("getInterface - altSetting=\(firstByte)")
    return firstByte
  }

  public static func setInterface(
    on handle: USBDeviceHandle,
    interfaceNumber: Int,
    alternateSetting: Int
  ) throws {
    Self.logger.debug(
      "setInterface - interface=\(interfaceNumber) alternateSetting=\(alternateSetting)"
    )

    try handle.setInterfaceAltSetting(
      interface: interfaceNumber,
      alternateSetting: alternateSetting
    )
  }

  private static func parseRecipient(
    _ recipient: USBControlRecipient,
    direction: UInt8,
    interface: Int?
  ) -> (bmRequestType: UInt8, wIndex: UInt16) {
    let recipientValue: UInt8
    let wIndex: UInt16

    switch recipient {
    case .device:
      recipientValue = 0x00
      wIndex = 0

    case .interface:
      recipientValue = 0x01
      wIndex = UInt16(interface ?? 0)

    case .endpoint:
      recipientValue = 0x02
      wIndex = UInt16(interface ?? 0)
    }

    let bmRequestType = makeRequestType(direction: direction, type: 0x00, recipient: recipientValue)
    return (bmRequestType, wIndex)
  }
}
