import Configuration
import Core
import Foundation

public actor InputProcessor {
  private var _axisCalibration: [AxisIdentifier: AxisCalibration] = [:]
  private var _triggerCalibration: [TriggerIdentifier: TriggerCalibration] = [:]
  private var _deadzoneSettings: DeadzoneSettings = DeadzoneSettings()
  private let _eventHandler: @Sendable (InputProcessorEvent) -> Void
  
  public init(
    eventHandler: @escaping @Sendable (InputProcessorEvent) -> Void = { _ in }
  ) {
    self._eventHandler = eventHandler
  }
  
  public func applyConfiguration(_ configuration: DeviceConfiguration) {
    _applyDeadzoneSettings(from: configuration)
    _applyCalibrationSettings(from: configuration)
  }
  
  private func _applyDeadzoneSettings(from configuration: DeviceConfiguration) {
    if let deadzoneConfig = configuration.quirks.first(where: { $0.name == "apply_deadzone" }),
       let deadzoneParam = deadzoneConfig.parameter(named: "deadzone") {
      let deadzoneValue = Float(deadzoneParam.doubleValue ?? 0.1)
      _deadzoneSettings = DeadzoneSettings(
        leftStick: deadzoneValue,
        rightStick: deadzoneValue,
        triggers: deadzoneValue * 0.5
      )
    }
  }
  
  private func _applyCalibrationSettings(from configuration: DeviceConfiguration) {
    _axisCalibration.removeAll()
    _triggerCalibration.removeAll()
    
    for field in configuration.reportDescriptor.fields {
      if field.name.hasSuffix("X") || field.name.hasSuffix("Y") {
        let axisIdentifier = _mapFieldNameToAxis(field.name)
        if let axis = axisIdentifier {
          _axisCalibration[axis] = AxisCalibration(
            min: 0,
            max: 255,
            center: 128
          )
        }
      }
    }
  }
  
  private func _mapFieldNameToAxis(_ fieldName: String) -> AxisIdentifier? {
    switch fieldName.lowercased() {
    case "leftstickx", "leftx": return .leftStickX
    case "leftsticky", "lefty": return .leftStickY
    case "rightstickx", "rightx": return .rightStickX
    case "rightsticky", "righty": return .rightStickY
    case "lefttrigger", "lt": return .leftTrigger
    case "righttrigger", "rt": return .rightTrigger
    default: return nil
    }
  }
  
  public func processAxisEvent(_ event: AxisEvent, configuration: DeviceConfiguration?) async -> AxisEvent {
    var processedValue = event.value
    
    if let calibration = _axisCalibration[event.axisID] {
      processedValue = _applyCalibration(to: processedValue, calibration: calibration)
    }
    
    let deadzone = _deadzoneSettings.deadzone(for: event.axisID)
    processedValue = _applyDeadzone(to: processedValue, deadzone: deadzone)
    
    if abs(processedValue - event.value) > 0.001 {
      let processedEvent = AxisEvent(
        axisID: event.axisID,
        value: processedValue,
        rawValue: Int16(processedValue * 32767),
        timestamp: event.timestamp
      )
      
      let processorEvent = InputProcessorEvent(
        type: .axisProcessed,
        axisEvent: processedEvent,
        originalValue: event.value,
        message: "Processed axis \(event.axisID.displayName): \(event.value) -> \(processedValue)"
      )
      _eventHandler(processorEvent)
      
      return processedEvent
    }
    
    return event
  }
  
  public func processTriggerEvent(_ event: TriggerEvent, configuration: DeviceConfiguration?) async -> TriggerEvent {
    var processedValue = event.value
    
    if let calibration = _triggerCalibration[event.triggerID] {
      processedValue = _applyCalibration(to: processedValue, calibration: calibration)
    }
    
    let deadzone = _deadzoneSettings.deadzone(for: event.triggerID)
    processedValue = _applyDeadzone(to: processedValue, deadzone: deadzone)
    
    let isPressed = processedValue >= 0.1
    
    if abs(processedValue - event.value) > 0.001 || event.isPressed != isPressed {
      let processedEvent = TriggerEvent(
        triggerID: event.triggerID,
        value: processedValue,
        rawValue: UInt8(processedValue * 255),
        isPressed: isPressed,
        timestamp: event.timestamp
      )
      
      let processorEvent = InputProcessorEvent(
        type: .triggerProcessed,
        triggerEvent: processedEvent,
        originalValue: event.value,
        message: "Processed trigger \(event.triggerID.displayName): \(event.value) -> \(processedValue)"
      )
      _eventHandler(processorEvent)
      
      return processedEvent
    }
    
    return event
  }
  
  public func processButtonEvent(_ event: ButtonEvent) async -> ButtonEvent {
    return event
  }
  
  public func processDPadEvent(_ event: DPadEvent) async -> DPadEvent {
    return event
  }
  
  private func _applyDeadzone(to value: Float, deadzone: Float) -> Float {
    let absValue = abs(value)
    
    guard absValue > deadzone else {
      return 0.0
    }
    
    let adjustedValue = (absValue - deadzone) / (1.0 - deadzone)
    return value >= 0 ? adjustedValue : -adjustedValue
  }
  
  private func _applyCalibration(to value: Float, calibration: AxisCalibration) -> Float {
    let range = Float(calibration.max - calibration.min)
    guard range != 0 else { return value }
    
    let centeredValue = Float(value) * 2.0 - 1.0
    return centeredValue
  }
  
  public func setAxisCalibration(_ calibration: AxisCalibration, for axis: AxisIdentifier) {
    _axisCalibration[axis] = calibration
  }
  
  public func setTriggerCalibration(_ calibration: TriggerCalibration, for trigger: TriggerIdentifier) {
    _triggerCalibration[trigger] = calibration
  }
  
  public func setDeadzone(_ deadzone: Float, for axis: AxisIdentifier) {
    switch axis {
    case .leftStickX, .leftStickY:
      _deadzoneSettings.leftStick = deadzone
    case .rightStickX, .rightStickY:
      _deadzoneSettings.rightStick = deadzone
    case .leftTrigger:
      _deadzoneSettings.triggers = deadzone
    case .rightTrigger:
      _deadzoneSettings.triggers = deadzone
    default:
      break
    }
  }
  
  public func getCalibration(for axis: AxisIdentifier) -> AxisCalibration? {
    _axisCalibration[axis]
  }
  
  public func getDeadzone(for axis: AxisIdentifier) -> Float {
    _deadzoneSettings.deadzone(for: axis)
  }
}

public struct InputProcessorEvent: Sendable {
  public let type: EventType
  public let axisEvent: AxisEvent?
  public let triggerEvent: TriggerEvent?
  public let originalValue: Float?
  public let message: String
  
  public init(
    type: EventType,
    axisEvent: AxisEvent? = nil,
    triggerEvent: TriggerEvent? = nil,
    originalValue: Float? = nil,
    message: String = ""
  ) {
    self.type = type
    self.axisEvent = axisEvent
    self.triggerEvent = triggerEvent
    self.originalValue = originalValue
    self.message = message
  }
  
  public enum EventType: Sendable {
    case axisProcessed
    case triggerProcessed
    case calibrationUpdated
    case deadzoneUpdated
  }
}

struct DeadzoneSettings {
  var leftStick: Float = 0.1
  var rightStick: Float = 0.1
  var triggers: Float = 0.05
  
  func deadzone(for axis: AxisIdentifier) -> Float {
    switch axis {
    case .leftStickX, .leftStickY:
      return leftStick
    case .rightStickX, .rightStickY:
      return rightStick
    case .leftTrigger, .rightTrigger:
      return triggers
    default:
      return 0.1
    }
  }
}

struct AxisCalibration {
  let min: Int
  let max: Int
  let center: Int
}

struct TriggerCalibration {
  let min: Int
  let max: Int
  let center: Int
}