import Configuration
import Core
import Foundation

public final class HIDReportParser: @unchecked Sendable {
  private var _descriptor: HIDReportDescriptor?
  private var _configReportDescriptor: ConfigReportDescriptor?
  private var _fieldMappings: [Int: FieldMapping] = [:]
  private var _previousButtonStates: [Int: Bool] = [:]
  private var _previousAxisValues: [Int: Int16] = [:]
  private var _previousTriggerValues: [Int: UInt8] = [:]
  private var _previousDPadStates: [Int: (DPadDirection, DPadDirection)] = [:]
  private var _previousHatSwitchValues: [Int: UInt16] = [:]
  private var _reportID: UInt8 = 0
  private var _timestamp: UInt64 = 0
  private let _lock = NSLock()

  public init() {
  }

  public func configure(with descriptor: HIDReportDescriptor) {
    _lock.lock()
    defer { _lock.unlock() }

    _descriptor = descriptor
    _fieldMappings = HIDFieldMappingBuilder(descriptor: descriptor).buildMappings()
    _configReportDescriptor = nil
  }

  public func configure(with configDescriptor: Configuration.ReportDescriptor) {
    _lock.lock()
    defer { _lock.unlock() }

    var configFields: [ConfigReportField] = []

    if let field = configDescriptor.field(named: "buttons") {
      configFields.append(
        ConfigReportField(
          name: field.name,
          byte: field.byte,
          bitOffset: field.bitOffset,
          bitLength: field.bitLength,
          type: FieldType.unsigned
        )
      )
    }

    if let field = configDescriptor.field(named: "dpad") {
      configFields.append(
        ConfigReportField(
          name: field.name,
          byte: field.byte,
          bitOffset: field.bitOffset,
          bitLength: field.bitLength,
          type: FieldType.bitfield
        )
      )
    }

    for axisName in ["leftStickX", "leftStickY", "rightStickX", "rightStickY"] {
      if let field = configDescriptor.field(named: axisName) {
        configFields.append(
          ConfigReportField(
            name: field.name,
            byte: field.byte,
            bitOffset: field.bitOffset,
            bitLength: field.bitLength,
            type: FieldType.unsigned
          )
        )
      }
    }

    for triggerName in ["leftTrigger", "rightTrigger"] {
      if let field = configDescriptor.field(named: triggerName) {
        configFields.append(
          ConfigReportField(
            name: field.name,
            byte: field.byte,
            bitOffset: field.bitOffset,
            bitLength: field.bitLength,
            type: FieldType.unsigned
          )
        )
      }
    }

    _configReportDescriptor = ConfigReportDescriptor(
      reportSize: configDescriptor.reportSize,
      fields: configFields
    )
    _fieldMappings = _buildConfigFieldMappings(from: _configReportDescriptor!)
    _descriptor = nil
  }

  private func _buildConfigFieldMappings(
    from configDescriptor: ConfigReportDescriptor
  ) -> [Int: FieldMapping] {
    var mappings: [Int: FieldMapping] = [:]
    var fieldIndex = 0

    for field in configDescriptor.fields {
      let mapping = FieldMapping(
        usagePage: .genericDesktop,
        usage: _usageForFieldName(field.name),
        bitOffset: field.bitOffset,
        bitLength: field.bitLength,
        reportOffset: field.byte,
        isSigned: field.type == .signed,
        logicalMinimum: Int16(field.type == .signed ? -128 : 0),
        logicalMaximum: Int16(field.type == .signed ? 127 : 255)
      )
      mappings[fieldIndex] = mapping
      fieldIndex += 1
    }

    return mappings
  }

  private func _usageForFieldName(_ name: String) -> UInt16 {
    switch name.lowercased() {
    case "buttons", "button":
      return UInt16(HIDLocalTag.usage.rawValue)
    case "dpad":
      return UInt16(HIDGenericDesktopUsage.hatSwitch.rawValue)
    case "leftstickx", "leftx":
      return UInt16(HIDGenericDesktopUsage.x.rawValue)
    case "leftsticky", "lefty":
      return UInt16(HIDGenericDesktopUsage.y.rawValue)
    case "rightstickx", "rightx":
      return UInt16(HIDGenericDesktopUsage.rx.rawValue)
    case "rightsticky", "righty":
      return UInt16(HIDGenericDesktopUsage.ry.rawValue)
    case "lefttrigger", "lt":
      return UInt16(HIDGenericDesktopUsage.z.rawValue)
    case "righttrigger", "rt":
      return UInt16(HIDGenericDesktopUsage.rz.rawValue)
    default:
      return UInt16(HIDGenericDesktopUsage.x.rawValue)
    }
  }

  public func parse(report: Data) -> [InputEvent] {
    _lock.lock()
    defer { _lock.unlock() }

    _timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)

    var events: [InputEvent] = []

    if report.isEmpty {
      return events
    }

    let reportData: Data
    if report.first == _reportID && report.count > 1 {
      reportData = report.dropFirst()
    } else {
      reportData = report
    }

    if let configDescriptor = _configReportDescriptor {
      let configEvents = _parseConfigReport(reportData, configDescriptor: configDescriptor)
      events.append(contentsOf: configEvents)
    } else if !_fieldMappings.isEmpty {
      var descriptorEvents: [InputEvent] = []
      for (fieldIndex, mapping) in _fieldMappings {
        let value = FieldValueExtractor.extract(from: reportData, mapping: mapping)
        if let event = _createEvent(fieldIndex: fieldIndex, mapping: mapping, value: value) {
          descriptorEvents.append(event)
        }
      }
      events.append(contentsOf: descriptorEvents)
    }

    return events
  }

  private func _parseConfigReport(
    _ report: Data,
    configDescriptor: ConfigReportDescriptor
  ) -> [InputEvent] {
    var events: [InputEvent] = []

    for field in configDescriptor.fields {
      guard field.byte < report.count else { continue }

      let value = _extractFieldValue(report: report, field: field)

      if let event = _createConfigEvent(field: field, value: value) {
        events.append(event)
      }
    }

    return events
  }

  private func _extractFieldValue(report: Data, field: ConfigReportField) -> Int32 {
    switch field.type {
    case .unsigned:
      return Int32(report[field.byte])
    case .signed:
      return Int32(Int8(bitPattern: report[field.byte]))
    case .bitfield:
      return Int32(report[field.byte] >> field.bitOffset) & Int32((1 << field.bitLength) - 1)
    case .boolean:
      return (report[field.byte] >> field.bitOffset) & 0x01 == 0x01 ? 1 : 0
    }
  }

  private func _createConfigEvent(field: ConfigReportField, value: Int32) -> InputEvent? {
    let normalizedValue: Float

    switch field.type {
    case .unsigned:
      normalizedValue = Float(value) / 255.0
    case .signed:
      normalizedValue = Float(value) / 127.0
    case .bitfield:
      normalizedValue = Float(value) / Float((1 << field.bitLength) - 1)
    case .boolean:
      normalizedValue = Float(value)
    }

    let fieldName = field.name.lowercased()

    if fieldName == "buttons" {
      return _createButtonEventsFromBits(value: value, field: field)
    } else if fieldName == "dpad" {
      return _createDPadEvent(value: value, field: field)
    } else if fieldName.hasSuffix("x") || fieldName.hasSuffix("y") {
      let axisID = _mapFieldNameToAxis(field.name)
      if let axis = axisID {
        let mapping = FieldMapping(
          usagePage: .genericDesktop,
          usage: _usageForFieldName(field.name),
          bitOffset: field.bitOffset,
          bitLength: field.bitLength,
          reportOffset: field.byte,
          isSigned: field.type == .signed,
          logicalMinimum: Int16(field.type == .signed ? -128 : 0),
          logicalMaximum: Int16(field.type == .signed ? 127 : 255)
        )
        return _createAxisEvent(
          fieldIndex: field.byte,
          axisID: axis,
          value: normalizedValue,
          mapping: mapping
        )
      }
    } else if fieldName.hasPrefix("lefttrigger") || fieldName.hasPrefix("lt") {
      let mapping = FieldMapping(
        usagePage: .genericDesktop,
        usage: 0x32,
        bitOffset: field.bitOffset,
        bitLength: field.bitLength,
        reportOffset: field.byte,
        isSigned: false,
        logicalMinimum: 0,
        logicalMaximum: 255
      )
      return _createTriggerEvent(
        fieldIndex: field.byte,
        triggerID: .left,
        value: normalizedValue,
        mapping: mapping
      )
    } else if fieldName.hasPrefix("righttrigger") || fieldName.hasPrefix("rt") {
      let mapping = FieldMapping(
        usagePage: .genericDesktop,
        usage: 0x35,
        bitOffset: field.bitOffset,
        bitLength: field.bitLength,
        reportOffset: field.byte,
        isSigned: false,
        logicalMinimum: 0,
        logicalMaximum: 255
      )
      return _createTriggerEvent(
        fieldIndex: field.byte,
        triggerID: .right,
        value: normalizedValue,
        mapping: mapping
      )
    }

    return nil
  }

  private func _createButtonEventsFromBits(value: Int32, field: ConfigReportField) -> InputEvent? {
    return nil
  }

  private func _createDPadEvent(value: Int32, field: ConfigReportField) -> InputEvent? {
    let dpadValue = UInt8(value)
    let horizontal = _dpadValueToHorizontal(dpadValue)
    let vertical = _dpadValueToVertical(dpadValue)

    return .dpadMove(
      DPadEvent(dpadID: 0, horizontal: horizontal, vertical: vertical, timestamp: _timestamp)
    )
  }

  private func _dpadValueToHorizontal(_ value: UInt8) -> DPadDirection {
    switch value & 0x03 {
    case 0x01: return .right
    case 0x02: return .left
    default: return .neutral
    }
  }

  private func _dpadValueToVertical(_ value: UInt8) -> DPadDirection {
    switch (value >> 2) & 0x03 {
    case 0x01: return .down
    case 0x02: return .up
    default: return .neutral
    }
  }

  private func _mapFieldNameToAxis(_ fieldName: String) -> AxisIdentifier? {
    switch fieldName.lowercased() {
    case "leftstickx", "leftx": return .leftStickX
    case "leftsticky", "lefty": return .leftStickY
    case "rightstickx", "rightx": return .rightStickX
    case "rightsticky", "righty": return .rightStickY
    default: return nil
    }
  }

  private func _createEvent(
    fieldIndex: Int,
    mapping: FieldMapping,
    value: Int32
  ) -> InputEvent? {
    let buttonIdentifier = UsageMapper.mapToButton(
      usagePage: mapping.usagePage,
      usage: mapping.usage
    )
    let axisIdentifier = UsageMapper.mapToAxis(usagePage: mapping.usagePage, usage: mapping.usage)
    let triggerIdentifier = UsageMapper.mapToTrigger(
      usagePage: mapping.usagePage,
      usage: mapping.usage
    )

    if let buttonID = buttonIdentifier {
      return _createButtonEvent(fieldIndex: fieldIndex, buttonID: buttonID, value: value)
    } else if let axisID = axisIdentifier {
      return _createAxisEvent(
        fieldIndex: fieldIndex,
        axisID: axisID,
        value: Float(value) / 32767.0,
        mapping: mapping
      )
    } else if let triggerID = triggerIdentifier {
      return _createTriggerEvent(
        fieldIndex: fieldIndex,
        triggerID: triggerID,
        value: Float(value) / 255.0,
        mapping: mapping
      )
    }

    return nil
  }

  private func _createButtonEvent(
    fieldIndex: Int,
    buttonID: ButtonIdentifier,
    value: Int32
  ) -> InputEvent? {
    let isPressed = value != 0
    let previousState = _previousButtonStates[fieldIndex] ?? false
    guard previousState != isPressed else { return nil }
    _previousButtonStates[fieldIndex] = isPressed
    return isPressed
      ? .buttonPress(ButtonEvent(buttonID: buttonID, isPressed: true, timestamp: _timestamp))
      : .buttonRelease(ButtonEvent(buttonID: buttonID, isPressed: false, timestamp: _timestamp))
  }

  private func _createAxisEvent(
    fieldIndex: Int,
    axisID: AxisIdentifier,
    value: Float,
    mapping: FieldMapping
  ) -> InputEvent? {
    let intValue = Int32(value * 32767)
    let normalizedValue = ValueNormalizer.normalizeAxis(intValue, mapping: mapping)
    let previousValue = _previousAxisValues[fieldIndex] ?? 0
    guard abs(normalizedValue - Float(previousValue) / 32767.0) > 0.01 else { return nil }
    _previousAxisValues[fieldIndex] = Int16(intValue)
    return .axisMove(
      AxisEvent(
        axisID: axisID,
        value: normalizedValue,
        rawValue: Int16(intValue),
        timestamp: _timestamp
      )
    )
  }

  private func _createTriggerEvent(
    fieldIndex: Int,
    triggerID: TriggerIdentifier,
    value: Float,
    mapping: FieldMapping
  ) -> InputEvent? {
    let intValue = Int32(value * 255)
    let normalizedValue = ValueNormalizer.normalizeTrigger(intValue, mapping: mapping)
    let previousValue = _previousTriggerValues[fieldIndex] ?? 0
    guard abs(normalizedValue - Float(previousValue) / 255.0) > 0.01 else { return nil }
    _previousTriggerValues[fieldIndex] = UInt8(intValue)
    let isPressed = normalizedValue >= 0.1
    return .triggerMove(
      TriggerEvent(
        triggerID: triggerID,
        value: normalizedValue,
        rawValue: UInt8(intValue),
        isPressed: isPressed,
        timestamp: _timestamp
      )
    )
  }
}

struct ConfigReportDescriptor {
  let reportSize: Int
  let fields: [ConfigReportField]

  init(reportSize: Int, fields: [ConfigReportField]) {
    self.reportSize = reportSize
    self.fields = fields
  }
}

struct ConfigReportField {
  let name: String
  let byte: Int
  let bitOffset: Int
  let bitLength: Int
  let type: FieldType
}

enum FieldType: String {
  case unsigned
  case signed
  case bitfield
  case boolean
}

extension HIDReportParser: ReportParser {
  public var parserType: ParserType { .hidDescriptor }

  public func canParse(_ report: Data) -> Bool {
    !report.isEmpty && (_fieldMappings.isEmpty == false || _configReportDescriptor != nil)
  }
}
