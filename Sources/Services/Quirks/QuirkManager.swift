import Configuration
import Core
import Foundation

public actor QuirkManager {
  private var _appliedQuirks: [USBDeviceID: [String: AppliedQuirk]] = [:]
  private let _quirkRegistry: QuirkRegistry
  private let _eventHandler: @Sendable (QuirkEvent) -> Void
  
  public init(
    eventHandler: @escaping @Sendable (QuirkEvent) -> Void = { _ in }
  ) {
    self._eventHandler = eventHandler
    self._quirkRegistry = QuirkRegistry()
  }
  
  public func applyQuirks(for deviceID: USBDeviceID, configuration: DeviceConfiguration) async throws {
    var appliedQuirks: [String: AppliedQuirk] = [:]
    
    for quirkConfig in configuration.quirks where quirkConfig.enabled {
      if let quirk = _quirkRegistry.getQuirk(named: quirkConfig.name) {
        let appliedQuirk = AppliedQuirk(
          configuration: quirkConfig,
          quirk: quirk
        )
        
        try await quirk.apply(for: deviceID, configuration: configuration, parameters: quirkConfig.parameters)
        appliedQuirks[quirkConfig.name] = appliedQuirk
        
        let event = QuirkEvent(
          type: .quirkApplied,
          deviceID: deviceID,
          quirkName: quirkConfig.name,
          message: "Applied quirk '\(quirkConfig.name)' to device \(deviceID.stringValue)"
        )
        _eventHandler(event)
      }
    }
    
    _appliedQuirks[deviceID] = appliedQuirks
  }
  
  public func removeQuirks(for deviceID: USBDeviceID) async {
    guard let appliedQuirks = _appliedQuirks.removeValue(forKey: deviceID) else {
      return
    }
    
    for (name, appliedQuirk) in appliedQuirks {
      await appliedQuirk.quirk.remove(for: deviceID)
      
      let event = QuirkEvent(
        type: .quirkRemoved,
        deviceID: deviceID,
        quirkName: name,
        message: "Removed quirk '\(name)' from device \(deviceID.stringValue)"
      )
      _eventHandler(event)
    }
  }
  
  public func hasQuirk(for deviceID: USBDeviceID, named name: String) -> Bool {
    _appliedQuirks[deviceID]?[name] != nil
  }
  
  public func getQuirkParameter(for deviceID: USBDeviceID, quirkName: String, parameterName: String) -> QuirkParameter? {
    _appliedQuirks[deviceID]?[quirkName]?.configuration.parameter(named: parameterName)
  }
  
  public func updateQuirkParameter(
    for deviceID: USBDeviceID,
    quirkName: String,
    parameterName: String,
    value: QuirkParameter
  ) async throws {
    guard let appliedQuirk = _appliedQuirks[deviceID]?[quirkName] else {
      throw QuirkError.quirkNotFound
    }
    
    try await appliedQuirk.quirk.updateParameter(
      for: deviceID,
      parameterName: parameterName,
      value: value
    )
  }
  
  public func getAppliedQuirks(for deviceID: USBDeviceID) -> [String] {
    guard let keys = _appliedQuirks[deviceID]?.keys else { return [] }
    return Array(keys)
  }
}

private struct AppliedQuirk {
  let configuration: DeviceQuirk
  let quirk: any Quirk
}

public struct QuirkEvent: Sendable {
  public let type: EventType
  public let deviceID: USBDeviceID?
  public let quirkName: String?
  public let message: String
  
  public init(
    type: EventType,
    deviceID: USBDeviceID? = nil,
    quirkName: String? = nil,
    message: String = ""
  ) {
    self.type = type
    self.deviceID = deviceID
    self.quirkName = quirkName
    self.message = message
  }
  
  public enum EventType: Sendable {
    case quirkApplied
    case quirkRemoved
    case quirkParameterUpdated
    case quirkError
  }
}

public enum QuirkError: Error, Sendable, Equatable {
  case quirkNotFound
  case quirkApplicationFailed
  case invalidParameter
  case unsupportedQuirk
}

protocol Quirk: Sendable {
  var name: String { get }
  var description: String { get }
  
  func apply(for deviceID: USBDeviceID, configuration: DeviceConfiguration, parameters: [String: QuirkParameter]?) async throws
  func remove(for deviceID: USBDeviceID) async
  func updateParameter(for deviceID: USBDeviceID, parameterName: String, value: QuirkParameter) async throws
}

private class QuirkRegistry {
  private var _quirks: [String: any Quirk] = [:]
  
  init() {
    _registerBuiltInQuirks()
  }
  
  private func _registerBuiltInQuirks() {
    _quirks["delay_after_init"] = DelayAfterInitQuirk()
    _quirks["no_keepalive"] = NoKeepaliveQuirk()
    _quirks["vendor_specific_led"] = VendorSpecificLEDQuirk()
    _quirks["apply_deadzone"] = ApplyDeadzoneQuirk()
    _quirks["auto_detect_layout"] = AutoDetectLayoutQuirk()
    _quirks["gip_protocol"] = GIPProtocolQuirk()
  }
  
  func getQuirk(named name: String) -> (any Quirk)? {
    _quirks[name]
  }
}

private class DelayAfterInitQuirk: @unchecked Sendable, Quirk {
  let name = "delay_after_init"
  let description = "Adds a delay after device initialization"
  
  private var _delayDuration: TimeInterval = 0.1
  
  func apply(for deviceID: USBDeviceID, configuration: DeviceConfiguration, parameters: [String: QuirkParameter]?) async throws {
    if let delayParam = parameters?["delay"] {
      _delayDuration = delayParam.doubleValue ?? 0.1
    }
    
    try await Task.sleep(nanoseconds: UInt64(_delayDuration * 1_000_000_000))
  }
  
  func remove(for deviceID: USBDeviceID) async {
    _delayDuration = 0.1
  }
  
  func updateParameter(for deviceID: USBDeviceID, parameterName: String, value: QuirkParameter) async throws {
    if parameterName == "delay" {
      _delayDuration = value.doubleValue ?? 0.1
    }
  }
}

private class NoKeepaliveQuirk: @unchecked Sendable, Quirk {
  let name = "no_keepalive"
  let description = "Disables keepalive packets for this device"
  
  func apply(for deviceID: USBDeviceID, configuration: DeviceConfiguration, parameters: [String: QuirkParameter]?) async throws {
  }
  
  func remove(for deviceID: USBDeviceID) async {
  }
  
  func updateParameter(for deviceID: USBDeviceID, parameterName: String, value: QuirkParameter) async throws {
  }
}

private class VendorSpecificLEDQuirk: @unchecked Sendable, Quirk {
  let name = "vendor_specific_led"
  let description = "Enables vendor-specific LED control"
  
  private var _ledPattern: UInt8 = 0x01
  
  func apply(for deviceID: USBDeviceID, configuration: DeviceConfiguration, parameters: [String: QuirkParameter]?) async throws {
    if let patternParam = parameters?["pattern"] {
      _ledPattern = UInt8(patternParam.intValue ?? 1)
    }
  }
  
  func remove(for deviceID: USBDeviceID) async {
    _ledPattern = 0x01
  }
  
  func updateParameter(for deviceID: USBDeviceID, parameterName: String, value: QuirkParameter) async throws {
    if parameterName == "pattern" {
      _ledPattern = UInt8(value.intValue ?? 1)
    }
  }
}

private class ApplyDeadzoneQuirk: @unchecked Sendable, Quirk {
  let name = "apply_deadzone"
  let description = "Applies deadzone to analog inputs"
  
  private var _deadzone: Float = 0.1
  
  func apply(for deviceID: USBDeviceID, configuration: DeviceConfiguration, parameters: [String: QuirkParameter]?) async throws {
    if let deadzoneParam = parameters?["deadzone"] {
      _deadzone = Float(deadzoneParam.doubleValue ?? 0.1)
    }
  }
  
  func remove(for deviceID: USBDeviceID) async {
    _deadzone = 0.1
  }
  
  func updateParameter(for deviceID: USBDeviceID, parameterName: String, value: QuirkParameter) async throws {
    if parameterName == "deadzone" {
      _deadzone = Float(value.doubleValue ?? 0.1)
    }
  }
}

private class AutoDetectLayoutQuirk: @unchecked Sendable, Quirk {
  let name = "auto_detect_layout"
  let description = "Automatically detects controller layout"
  
  func apply(for deviceID: USBDeviceID, configuration: DeviceConfiguration, parameters: [String: QuirkParameter]?) async throws {
  }
  
  func remove(for deviceID: USBDeviceID) async {
  }
  
  func updateParameter(for deviceID: USBDeviceID, parameterName: String, value: QuirkParameter) async throws {
  }
}

private class GIPProtocolQuirk: @unchecked Sendable, Quirk {
  let name = "gip_protocol"
  let description = "Enables GIP (Gamepad Interface Protocol) support"
  
  func apply(for deviceID: USBDeviceID, configuration: DeviceConfiguration, parameters: [String: QuirkParameter]?) async throws {
  }
  
  func remove(for deviceID: USBDeviceID) async {
  }
  
  func updateParameter(for deviceID: USBDeviceID, parameterName: String, value: QuirkParameter) async throws {
  }
}