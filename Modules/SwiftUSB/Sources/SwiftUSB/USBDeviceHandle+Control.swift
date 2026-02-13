import CLibUSB
import Foundation
import Logging

public extension USBDeviceHandle {
  func controlTransfer(
    requestType: UInt8,
    request: UInt8,
    value: UInt16,
    index: UInt16,
    data: Data? = nil,
    timeout: UInt32 = 5000
  ) throws -> Data {
    let buffer = [UInt8](data ?? Data())
    let length = buffer.count
    let isInput = (requestType & 0x80) != 0

    let message =
      "Control transfer: type=\(requestType) request=\(request) value=\(value) "
      + "index=\(index) length=\(length) timeout=\(timeout)"
    USBDeviceHandle.logger.debug(Logger.Message(stringLiteral: message))

    guard isInput else {
      let result = buffer.withUnsafeBufferPointer { ptr in
        libusb_control_transfer(
          handle,
          requestType,
          request,
          value,
          index,
          UnsafeMutablePointer(mutating: ptr.baseAddress),
          UInt16(length),
          timeout
        )
      }
      if result < 0 {
        USBDeviceHandle.logger.error("Control transfer failed with error \(result)")
        throw USBError(code: result)
      }
      USBDeviceHandle.logger.debug("Control transfer completed: \(Int(result)) bytes")
      return Data()
    }
    var receiveBuffer = [UInt8](repeating: 0, count: max(length, 64))
    let bufferCount = UInt16(receiveBuffer.count)
    let result = receiveBuffer.withUnsafeMutableBufferPointer { ptr in
      libusb_control_transfer(
        handle,
        requestType,
        request,
        value,
        index,
        ptr.baseAddress,
        bufferCount,
        timeout
      )
    }
    if result < 0 {
      USBDeviceHandle.logger.error("Control transfer failed with error \(result)")
      throw USBError(code: result)
    }
    let resultData = Data(receiveBuffer[0..<Int(result)])
    USBDeviceHandle.logger.debug("Control transfer completed: \(Int(result)) bytes")
    return resultData
  }
}

public enum USBRequestType {
}

public extension USBRequestType {
  static let `in`: UInt8 = 0x80
  static let out: UInt8 = 0x00
  static let standard: UInt8 = 0x00
  static let `class`: UInt8 = 0x20
  static let vendor: UInt8 = 0x40
  static let reserved: UInt8 = 0x60
  static let device: UInt8 = 0x00
  static let interface: UInt8 = 0x01
  static let endpoint: UInt8 = 0x02
  static let other: UInt8 = 0x03
}

public enum USBRequest {
}

public extension USBRequest {
  static let getStatus: UInt8 = 0x00
  static let clearFeature: UInt8 = 0x01
  static let setFeature: UInt8 = 0x03
  static let setAddress: UInt8 = 0x05
  static let getDescriptor: UInt8 = 0x06
  static let setDescriptor: UInt8 = 0x07
  static let getConfiguration: UInt8 = 0x08
  static let setConfiguration: UInt8 = 0x09
  static let getInterface: UInt8 = 0x0A
  static let setInterface: UInt8 = 0x0B
  static let synchFrame: UInt8 = 0x0C
}

public enum USBDescriptorType {
}

public extension USBDescriptorType {
  static let device: UInt8 = 0x01
  static let configuration: UInt8 = 0x02
  static let string: UInt8 = 0x03
  static let interface: UInt8 = 0x04
  static let endpoint: UInt8 = 0x05
  static let deviceQualifier: UInt8 = 0x06
  static let otherSpeedConfiguration: UInt8 = 0x07
  static let interfacePower: UInt8 = 0x08
  static let otg: UInt8 = 0x09
  static let debug: UInt8 = 0x0A
  static let interfaceAssociation: UInt8 = 0x0B
  static let bos: UInt8 = 0x0F
  static let deviceCapability: UInt8 = 0x10
  static let ssEndpointCompanion: UInt8 = 0x30
}
