import Core
import Foundation

public final class GIPParser: @unchecked Sendable {
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

    guard report.count >= 15 else { return events }

    let buttonByte0 = report[0]
    let buttonByte1 = report.count > 1 ? report[1] : 0

    let buttonBits = buttonByte0 & 0x0F
    let dpadBits = (buttonByte0 >> 4) & 0x0F

    guard buttonBits != 0 || dpadBits != 0 || buttonByte1 != 0 else { return events }

    let leftStickX = report.count > 4 ? Int16(report[4] | (report[5] << 8)) : 0
    let leftStickY = report.count > 6 ? Int16(report[6] | (report[7] << 8)) : 0
    let rightStickX = report.count > 8 ? Int16(report[8] | (report[9] << 8)) : 0
    let rightStickY = report.count > 10 ? Int16(report[10] | (report[11] << 8)) : 0
    let leftTrigger = report.count > 12 ? report[12] : 0
    let rightTrigger = report.count > 13 ? report[13] : 0
    let dpadH = report.count > 14 ? Int8(bitPattern: report[14]) : 0
    let dpadV = report.count > 15 ? Int8(bitPattern: report[15]) : 0

    _parseButton(&events, bit: 0x01, buttonID: .a, stateIndex: -100)
    _parseButton(&events, bit: 0x02, buttonID: .b, stateIndex: -101)
    _parseButton(&events, bit: 0x04, buttonID: .x, stateIndex: -102)
    _parseButton(&events, bit: 0x08, buttonID: .y, stateIndex: -103)
    _parseButton(&events, bit: 0x10, buttonID: .leftShoulder, stateIndex: -104)
    _parseButton(&events, bit: 0x20, buttonID: .rightShoulder, stateIndex: -105)
    _parseButton(&events, bit: 0x01, buttonID: .back, stateIndex: -106, sourceByte: buttonByte1)
    _parseButton(&events, bit: 0x02, buttonID: .start, stateIndex: -107, sourceByte: buttonByte1)

    _parseTrigger(&events, rawValue: leftTrigger, triggerID: .left, stateIndex: -10)
    _parseTrigger(&events, rawValue: rightTrigger, triggerID: .right, stateIndex: -11)

    _parseAxis(&events, rawValue: leftStickX, axisID: .leftStickX, stateIndex: -10)
    _parseAxis(&events, rawValue: leftStickY, axisID: .leftStickY, stateIndex: -11)
    _parseAxis(&events, rawValue: rightStickX, axisID: .rightStickX, stateIndex: -12)
    _parseAxis(&events, rawValue: rightStickY, axisID: .rightStickY, stateIndex: -13)

    let horizontal = _dpadFromHorizontal(dpadH)
    let vertical = _dpadFromVertical(dpadV)
    let previousDPad = _previousDPadStates[2] ?? (.neutral, .neutral)
    if previousDPad != (horizontal, vertical) {
      _previousDPadStates[2] = (horizontal, vertical)
      events.append(
        .dpadMove(
          DPadEvent(dpadID: 2, horizontal: horizontal, vertical: vertical, timestamp: _timestamp)
        )
      )
    }

    return events
  }

  private func _parseButton(
    _ events: inout [InputEvent],
    bit: UInt8,
    buttonID: ButtonIdentifier,
    stateIndex: Int,
    sourceByte: UInt8? = nil
  ) {
    let byte = sourceByte ?? 0
    let checkByte = sourceByte != nil ? byte : 0
    let effectiveBit = sourceByte != nil ? bit : bit

    if (checkByte & effectiveBit) != 0 && _previousButtonStates[stateIndex] != true {
      _previousButtonStates[stateIndex] = true
      events.append(
        .buttonPress(ButtonEvent(buttonID: buttonID, isPressed: true, timestamp: _timestamp))
      )
    } else if (checkByte & effectiveBit) == 0 && _previousButtonStates[stateIndex] != false {
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

extension GIPParser: ReportParser {
  public var parserType: ParserType { .gip }

  public func canParse(_ report: Data) -> Bool {
    guard report.count >= 15 else { return false }

    let buttonByte0 = report[0]
    let buttonByte1 = report.count > 1 ? report[1] : 0

    let buttonBits = buttonByte0 & 0x0F
    let dpadBits = (buttonByte0 >> 4) & 0x0F

    return buttonBits != 0 || dpadBits != 0 || buttonByte1 != 0
  }
}
