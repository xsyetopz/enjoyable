import Core
import Foundation

public final class XInputParser: @unchecked Sendable {
  private var _previousButtonStates: [Int: Bool] = [:]
  private var _previousAxisValues: [Int: Int16] = [:]
  private var _previousTriggerValues: [Int: UInt8] = [:]
  private var _previousDPadStates: [Int: (DPadDirection, DPadDirection)] = [:]
  private var _timestamp: UInt64 = 0
  private let _lock = NSLock()

  public init() {}

  public func parse(report: Data) -> [InputEvent] {
    _lock.lock()
    defer { _lock.unlock() }

    _timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)

    var events: [InputEvent] = []

    guard report.count >= 8 else { return events }

    let buttonByte = report[0]
    let leftStickX = report.count > 1 ? Int16(report[1]) : 0
    let leftStickY = report.count > 2 ? Int16(report[2]) : 0
    let rightStickX = report.count > 3 ? Int16(report[3]) : 0
    let rightStickY = report.count > 4 ? Int16(report[4]) : 0
    let leftTrigger = report.count > 5 ? UInt8(report[5]) : 0
    let rightTrigger = report.count > 6 ? UInt8(report[6]) : 0
    let dpadH = report.count > 7 ? Int8(bitPattern: report[7]) : 0
    let dpadV = report.count > 8 ? Int8(bitPattern: report[8]) : 0

    let buttonBits = buttonByte & 0x0F
    let shoulderBits = (buttonByte >> 4) & 0x03
    let systemBits = (buttonByte >> 6) & 0x03

    guard
      buttonBits != 0 || shoulderBits != 0 || systemBits != 0 || leftStickX != 0 || leftStickY != 0
    else {
      return events
    }

    _parseButton(&events, bit: ReportFormatConstants.ButtonMasks.a, buttonID: .a, stateIndex: -1)
    _parseButton(&events, bit: ReportFormatConstants.ButtonMasks.b, buttonID: .b, stateIndex: -2)
    _parseButton(&events, bit: ReportFormatConstants.ButtonMasks.x, buttonID: .x, stateIndex: -3)
    _parseButton(&events, bit: ReportFormatConstants.ButtonMasks.y, buttonID: .y, stateIndex: -4)
    _parseButton(
      &events,
      bit: ReportFormatConstants.ButtonMasks.leftShoulder,
      buttonID: .leftShoulder,
      stateIndex: -5
    )
    _parseButton(
      &events,
      bit: ReportFormatConstants.ButtonMasks.rightShoulder,
      buttonID: .rightShoulder,
      stateIndex: -6
    )
    _parseButton(
      &events,
      bit: ReportFormatConstants.ButtonMasks.back,
      buttonID: .back,
      stateIndex: -7
    )
    _parseButton(
      &events,
      bit: ReportFormatConstants.ButtonMasks.start,
      buttonID: .start,
      stateIndex: -8
    )

    _parseTrigger(&events, rawValue: leftTrigger, triggerID: .left, stateIndex: -1)
    _parseTrigger(&events, rawValue: rightTrigger, triggerID: .right, stateIndex: -2)

    _parseAxis(&events, rawValue: leftStickX, axisID: .leftStickX, stateIndex: -1)
    _parseAxis(&events, rawValue: leftStickY, axisID: .leftStickY, stateIndex: -2)
    _parseAxis(&events, rawValue: rightStickX, axisID: .rightStickX, stateIndex: -3)
    _parseAxis(&events, rawValue: rightStickY, axisID: .rightStickY, stateIndex: -4)

    let horizontal = _dpadFromHorizontal(dpadH)
    let vertical = _dpadFromVertical(dpadV)
    let previousDPad = _previousDPadStates[0] ?? (.neutral, .neutral)
    if previousDPad != (horizontal, vertical) {
      _previousDPadStates[0] = (horizontal, vertical)
      events.append(
        .dpadMove(
          DPadEvent(dpadID: 0, horizontal: horizontal, vertical: vertical, timestamp: _timestamp)
        )
      )
    }

    return events
  }

  private func _parseButton(
    _ events: inout [InputEvent],
    bit: UInt8,
    buttonID: ButtonIdentifier,
    stateIndex: Int
  ) {
    if (bit & 0xFF) != 0 && _previousButtonStates[stateIndex] != true {
      _previousButtonStates[stateIndex] = true
      events.append(
        .buttonPress(ButtonEvent(buttonID: buttonID, isPressed: true, timestamp: _timestamp))
      )
    } else if (bit & 0xFF) == 0 && _previousButtonStates[stateIndex] != false {
      _previousButtonStates[stateIndex] = false
      events.append(
        .buttonRelease(ButtonEvent(buttonID: buttonID, isPressed: false, timestamp: _timestamp))
      )
    }
  }

  private func _parseTrigger(
    _ events: inout [InputEvent],
    rawValue: UInt8,
    triggerID: TriggerIdentifier,
    stateIndex: Int
  ) {
    let value = Float(rawValue) / 255.0
    let previousValue = _previousTriggerValues[stateIndex] ?? 0
    if abs(value - Float(previousValue) / 255.0) > 0.01 {
      _previousTriggerValues[stateIndex] = rawValue
      events.append(
        .triggerMove(
          TriggerEvent(
            triggerID: triggerID,
            value: value,
            rawValue: rawValue,
            isPressed: value >= 0.1,
            timestamp: _timestamp
          )
        )
      )
    }
  }

  private func _parseAxis(
    _ events: inout [InputEvent],
    rawValue: Int16,
    axisID: AxisIdentifier,
    stateIndex: Int
  ) {
    let value = rawValue != 0 ? Float(rawValue) / 32767.0 : 0.0
    let previousValue = _previousAxisValues[stateIndex] ?? 0
    if abs(value - Float(previousValue) / 32767.0) > 0.01 {
      _previousAxisValues[stateIndex] = rawValue
      events.append(
        .axisMove(
          AxisEvent(axisID: axisID, value: value, rawValue: rawValue, timestamp: _timestamp)
        )
      )
    }
  }

  private func _dpadFromHorizontal(_ value: Int8) -> DPadDirection {
    switch value {
    case -1: return .left
    case 1: return .right
    default: return .neutral
    }
  }

  private func _dpadFromVertical(_ value: Int8) -> DPadDirection {
    switch value {
    case -1: return .down
    case 1: return .up
    default: return .neutral
    }
  }
}

extension XInputParser: ReportParser {
  public var parserType: ParserType { .xInput }

  public func canParse(_ report: Data) -> Bool {
    guard report.count >= 8 else { return false }

    let buttonByte = report[0]
    let buttonBits = buttonByte & 0x0F
    let shoulderBits = (buttonByte >> 4) & 0x03
    let systemBits = (buttonByte >> 6) & 0x03

    return buttonBits != 0 || shoulderBits != 0 || systemBits != 0
  }
}
