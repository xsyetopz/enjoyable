import Core
import Foundation
import IOKit

public actor VirtualHIDService {
  private var _virtualDevices: [UUID: VirtualGamepad] = [:]
  private var _deviceQueue: DispatchQueue?
  private let _eventHandler: @Sendable (VirtualHIDEvent) -> Void
  
  public init(
    eventHandler: @escaping @Sendable (VirtualHIDEvent) -> Void = { _ in }
  ) {
    self._eventHandler = eventHandler
    self._deviceQueue = DispatchQueue(label: "com.enjoyable.virtualhid", qos: .userInteractive)
  }
  
  public func createVirtualGamepad(
    vendorID: UInt16,
    productID: UInt16,
    productName: String,
    manufacturer: String = "Enjoyable"
  ) async throws -> UUID {
    let deviceID = UUID()
    
    let virtualGamepad = try await VirtualGamepad.create(
      vendorID: vendorID,
      productID: productID,
      productName: productName,
      manufacturer: manufacturer,
      eventHandler: { [weak self] event in
        Task { @MainActor in
          self?._eventHandler(event)
        }
      }
    )
    
    _virtualDevices[deviceID] = virtualGamepad
    
    let event = VirtualHIDEvent(
      type: .deviceCreated,
      deviceID: deviceID,
      vendorID: vendorID,
      productID: productID
    )
    _eventHandler(event)
    
    return deviceID
  }
  
  public func destroyVirtualGamepad(deviceID: UUID) async throws {
    guard let gamepad = _virtualDevices.removeValue(forKey: deviceID) else {
      throw VirtualHIDError.deviceNotFound
    }
    
    await gamepad.destroy()
    
    let event = VirtualHIDEvent(
      type: .deviceDestroyed,
      deviceID: deviceID
    )
    _eventHandler(event)
  }
  
  public func sendOutputReport(
    deviceID: UUID,
    leftMotor: Float,
    rightMotor: Float,
    ledPattern: LEDPattern? = nil
  ) async throws {
    guard let gamepad = _virtualDevices[deviceID] else {
      throw VirtualHIDError.deviceNotFound
    }
    
    try await gamepad.sendRumble(leftMotor: leftMotor, rightMotor: rightMotor)
    
    if let ledPattern = ledPattern {
      try await gamepad.sendLED(pattern: ledPattern)
    }
  }
  
  public func getVirtualDeviceCount() -> Int {
    _virtualDevices.count
  }
}

public struct VirtualHIDEvent: Sendable {
  public let type: EventType
  public let deviceID: UUID?
  public let vendorID: UInt16?
  public let productID: UInt16?
  public let error: (any Error)?
  
  public init(
    type: EventType,
    deviceID: UUID? = nil,
    vendorID: UInt16? = nil,
    productID: UInt16? = nil,
    error: (any Error)? = nil
  ) {
    self.type = type
    self.deviceID = deviceID
    self.vendorID = vendorID
    self.productID = productID
    self.error = error
  }
  
  public enum EventType: Sendable {
    case deviceCreated
    case deviceDestroyed
    case outputReportSent
    case error
  }
}

public enum VirtualHIDError: Error, Sendable, Equatable {
  case deviceNotFound
  case deviceCreationFailed
  case reportSendFailed
  case invalidConfiguration
}

public enum LEDPattern: Sendable {
  case off
  case on
  case blink(fast: Bool)
  case player(playerNumber: Int)
  case breathing
  case custom(frequencies: [UInt8])
}