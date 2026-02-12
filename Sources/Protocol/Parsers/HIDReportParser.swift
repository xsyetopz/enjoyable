import Core
import Foundation

public final class HIDReportParser: @unchecked Sendable {
  private let _descriptor: HIDReportDescriptor
  private var _fieldMappings: [Int: FieldMapping] = [:]
  private var _previousButtonStates: [Int: Bool] = [:]
  private var _previousAxisValues: [Int: Int16] = [:]
  private var _previousTriggerValues: [Int: UInt8] = [:]
  private var _previousDPadStates: [Int: (DPadDirection, DPadDirection)] = [:]
  private var _previousHatSwitchValues: [Int: UInt16] = [:]
  private var _reportID: UInt8 = 0
  private var _timestamp: UInt64 = 0
  private let _lock = NSLock()

  public init(descriptor: HIDReportDescriptor) {
    self._descriptor = descriptor
    self._fieldMappings = HIDFieldMappingBuilder(descriptor: descriptor).buildMappings()
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

    var descriptorEvents: [InputEvent] = []
    for (fieldIndex, mapping) in _fieldMappings {
      let value = FieldValueExtractor.extract(from: reportData, mapping: mapping)
      if let event = _createEvent(fieldIndex: fieldIndex, mapping: mapping, value: value) {
        descriptorEvents.append(event)
      }
    }

    if !descriptorEvents.isEmpty {
      return descriptorEvents
    }

    return events
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
        value: value,
        mapping: mapping
      )
    } else if let triggerID = triggerIdentifier {
      return _createTriggerEvent(
        fieldIndex: fieldIndex,
        triggerID: triggerID,
        value: value,
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
    value: Int32,
    mapping: FieldMapping
  ) -> InputEvent? {
    let normalizedValue = ValueNormalizer.normalizeAxis(value, mapping: mapping)
    let previousValue = _previousAxisValues[fieldIndex] ?? 0
    guard abs(normalizedValue - Float(previousValue) / 32767.0) > 0.01 else { return nil }
    _previousAxisValues[fieldIndex] = Int16(value)
    return .axisMove(
      AxisEvent(
        axisID: axisID,
        value: normalizedValue,
        rawValue: Int16(value),
        timestamp: _timestamp
      )
    )
  }

  private func _createTriggerEvent(
    fieldIndex: Int,
    triggerID: TriggerIdentifier,
    value: Int32,
    mapping: FieldMapping
  ) -> InputEvent? {
    let normalizedValue = ValueNormalizer.normalizeTrigger(value, mapping: mapping)
    let previousValue = _previousTriggerValues[fieldIndex] ?? 0
    guard abs(normalizedValue - Float(previousValue) / 255.0) > 0.01 else { return nil }
    _previousTriggerValues[fieldIndex] = UInt8(value)
    let isPressed = normalizedValue >= 0.1
    return .triggerMove(
      TriggerEvent(
        triggerID: triggerID,
        value: normalizedValue,
        rawValue: UInt8(value),
        isPressed: isPressed,
        timestamp: _timestamp
      )
    )
  }
}

extension HIDReportParser: ReportParser {
  public var parserType: ParserType { .hidDescriptor }

  public func canParse(_ report: Data) -> Bool {
    !report.isEmpty && !_fieldMappings.isEmpty
  }
}
