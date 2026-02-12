import Core
import Foundation

public struct ParserFactory {
  private let _capabilities: ParserCapabilities

  public init(capabilities: ParserCapabilities = .fullSupport) {
    self._capabilities = capabilities
  }

  public func createParser(for descriptor: HIDReportDescriptor) -> (any ReportParser)? {
    guard _capabilities.supportsDescriptorParsing else { return nil }
    return HIDReportParser(descriptor: descriptor)
  }

  public func createXInputParser() -> (any ReportParser)? {
    guard _capabilities.supportsXInput else { return nil }
    return XInputParser()
  }

  public func createGIPParser() -> (any ReportParser)? {
    guard _capabilities.supportsGIP else { return nil }
    return GIPParser()
  }

  public func createPlayStationParser() -> (any ReportParser)? {
    guard _capabilities.supportsPlayStation else { return nil }
    return PlayStationParser()
  }

  public func createGenericParser() -> (any ReportParser)? {
    guard _capabilities.supportsGenericHID else { return nil }
    return GenericHIDParser()
  }

  public func selectParser(
    for report: Data,
    descriptor: HIDReportDescriptor? = nil
  ) -> (any ReportParser)? {
    if let descriptor = descriptor, _capabilities.supportsDescriptorParsing {
      let parser = createParser(for: descriptor)
      if parser?.canParse(report) == true {
        return parser
      }
    }

    if _capabilities.supportsXInput {
      let parser = createXInputParser()
      if parser?.canParse(report) == true {
        return parser
      }
    }
    if _capabilities.supportsGIP {
      let parser = createGIPParser()
      if parser?.canParse(report) == true {
        return parser
      }
    }
    if _capabilities.supportsPlayStation {
      let parser = createPlayStationParser()
      if parser?.canParse(report) == true {
        return parser
      }
    }
    if _capabilities.supportsGenericHID {
      return createGenericParser()
    }

    return nil
  }

  public func allParsers() -> [any ReportParser] {
    var parsers: [any ReportParser] = []

    if _capabilities.supportsDescriptorParsing {
      parsers.append(HIDReportParser(descriptor: HIDReportDescriptor(items: [])))
    }
    if _capabilities.supportsXInput {
      parsers.append(XInputParser())
    }
    if _capabilities.supportsGIP {
      parsers.append(GIPParser())
    }
    if _capabilities.supportsPlayStation {
      parsers.append(PlayStationParser())
    }
    if _capabilities.supportsGenericHID {
      parsers.append(GenericHIDParser())
    }

    return parsers
  }
}

public final class PlayStationParser: @unchecked Sendable {
  private var _previousButtonStates: [Int: Bool] = [:]
  private var _previousAxisValues: [Int: Int16] = [:]
  private var _previousHatSwitchValues: [Int: UInt16] = [:]
  private var _timestamp: UInt64 = 0
  private let _lock = NSLock()

  public init() {}

  public func parse(report: Data) -> [InputEvent] {
    _lock.lock()
    defer { _lock.unlock() }

    _timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)

    var events: [InputEvent] = []

    guard report.count >= 8 else { return events }

    let buttonByte0 = report[0]
    let buttonByte1 = report.count > 1 ? report[1] : 0
    let leftStickX = report.count > 2 ? Int8(bitPattern: report[2]) : 0
    let leftStickY = report.count > 3 ? Int8(bitPattern: report[3]) : 0
    let rightStickX = report.count > 4 ? Int8(bitPattern: report[4]) : 0
    let rightStickY = report.count > 5 ? Int8(bitPattern: report[5]) : 0
    let dpadHat = report.count > 6 ? report[6] : 0
    let shoulderButtons = report.count > 7 ? report[7] : 0

    let faceButtonBits = buttonByte0 & 0x0F
    let shoulderBits = shoulderButtons & 0x03
    let triggerBits = buttonByte1 & 0x03

    guard
      faceButtonBits != 0 || shoulderBits != 0 || triggerBits != 0 || leftStickX != 0
        || leftStickY != 0
    else {
      return events
    }

    _parseButton(&events, bit: 0x01, buttonID: .x, stateIndex: -10)
    _parseButton(&events, bit: 0x02, buttonID: .a, stateIndex: -11)
    _parseButton(&events, bit: 0x04, buttonID: .b, stateIndex: -12)
    _parseButton(&events, bit: 0x08, buttonID: .y, stateIndex: -13)
    _parseButton(
      &events,
      bit: 0x01,
      buttonID: .leftShoulder,
      stateIndex: -14,
      sourceByte: shoulderButtons
    )
    _parseButton(
      &events,
      bit: 0x02,
      buttonID: .rightShoulder,
      stateIndex: -15,
      sourceByte: shoulderButtons
    )
    _parseButton(
      &events,
      bit: 0x01,
      buttonID: .leftTrigger,
      stateIndex: -16,
      sourceByte: buttonByte1
    )
    _parseButton(
      &events,
      bit: 0x02,
      buttonID: .rightTrigger,
      stateIndex: -17,
      sourceByte: buttonByte1
    )

    _parseAxis(&events, rawValue: leftStickX, axisID: .leftStickX, stateIndex: -5)
    _parseAxis(&events, rawValue: leftStickY, axisID: .leftStickY, stateIndex: -6)
    _parseAxis(&events, rawValue: rightStickX, axisID: .rightStickX, stateIndex: -7)
    _parseAxis(&events, rawValue: rightStickY, axisID: .rightStickY, stateIndex: -8)

    let hatAngle = HatSwitchAngle.fromValue(dpadHat)
    let previousHat = _previousHatSwitchValues[0] ?? 0
    if hatAngle.angleDegrees != previousHat {
      _previousHatSwitchValues[0] = hatAngle.angleDegrees
      events.append(.hatSwitch(HatSwitchEvent(hatID: 0, angle: hatAngle, timestamp: _timestamp)))
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

  private func _parseAxis(
    _ events: inout [InputEvent],
    rawValue: Int8,
    axisID: AxisIdentifier,
    stateIndex: Int
  ) {
    let value = rawValue != 0 ? Float(rawValue) / 127.0 : 0.0
    let previousValue = _previousAxisValues[stateIndex] ?? 0
    if abs(value - Float(previousValue) / 127.0) > 0.01 {
      _previousAxisValues[stateIndex] = Int16(rawValue)
      events.append(
        .axisMove(
          AxisEvent(axisID: axisID, value: value, rawValue: Int16(rawValue), timestamp: _timestamp)
        )
      )
    }
  }
}

extension PlayStationParser: ReportParser {
  public var parserType: ParserType { .playStation }

  public func canParse(_ report: Data) -> Bool {
    guard report.count >= 8 else { return false }

    let buttonByte0 = report[0]
    let buttonByte1 = report.count > 1 ? report[1] : 0
    let shoulderButtons = report.count > 7 ? report[7] : 0

    let faceButtonBits = buttonByte0 & 0x0F
    let shoulderBits = shoulderButtons & 0x03
    let triggerBits = buttonByte1 & 0x03

    return faceButtonBits != 0 || shoulderBits != 0 || triggerBits != 0
  }
}

public final class GenericHIDParser: @unchecked Sendable {
  private var _previousButtonStates: [Int: Bool] = [:]
  private var _previousAxisValues: [Int: Int16] = [:]
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
    let axisCount = min(report.count - 1, 4)
    var axisIndex = 0

    let buttonBits = buttonByte & 0x0F
    let dpadBits = (buttonByte >> 4) & 0x0F

    var hasAxisMovement = false
    for i in 0..<axisCount {
      let axisValue = Int8(bitPattern: report[i + 1])
      if axisValue != 0 {
        hasAxisMovement = true
        break
      }
    }

    guard buttonBits != 0 || dpadBits != 0 || hasAxisMovement else { return events }

    for i in 0..<axisCount {
      let axisValue = Int8(bitPattern: report[i + 1])
      if axisValue != 0 {
        let axisID: AxisIdentifier
        switch axisIndex {
        case 0: axisID = .leftStickX
        case 1: axisID = .leftStickY
        case 2: axisID = .rightStickX
        case 3: axisID = .rightStickY
        default: axisID = .custom(UInt8(axisIndex))
        }

        let normalizedValue = Float(axisValue) / 127.0
        let previousAxis = _previousAxisValues[-20 - axisIndex] ?? 0
        if abs(normalizedValue - Float(previousAxis) / 127.0) > 0.01 {
          _previousAxisValues[-20 - axisIndex] = Int16(axisValue)
          events.append(
            .axisMove(
              AxisEvent(
                axisID: axisID,
                value: normalizedValue,
                rawValue: Int16(axisValue),
                timestamp: _timestamp
              )
            )
          )
        }
        axisIndex += 1
      }
    }

    _parseButton(&events, bit: 0x01, buttonID: .a, stateIndex: -20)
    _parseButton(&events, bit: 0x02, buttonID: .b, stateIndex: -21)
    _parseButton(&events, bit: 0x04, buttonID: .x, stateIndex: -22)
    _parseButton(&events, bit: 0x08, buttonID: .y, stateIndex: -23)

    let dpadH = (buttonByte >> 4) & 0x03
    let dpadV = (buttonByte >> 6) & 0x03
    let horizontal = _dpadFromGeneric(dpadH)
    let vertical = _dpadFromGeneric(dpadV)
    let previousDPad = _previousDPadStates[1] ?? (.neutral, .neutral)
    if previousDPad != (horizontal, vertical) {
      _previousDPadStates[1] = (horizontal, vertical)
      events.append(
        .dpadMove(
          DPadEvent(dpadID: 1, horizontal: horizontal, vertical: vertical, timestamp: _timestamp)
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

  private func _dpadFromGeneric(_ value: UInt8) -> DPadDirection {
    switch value {
    case 1: return .right
    case 2: return .down
    case 3: return .left
    default: return .neutral
    }
  }
}

extension GenericHIDParser: ReportParser {
  public var parserType: ParserType { .generic }

  public func canParse(_ report: Data) -> Bool {
    guard report.count >= 8 else { return false }

    let buttonByte = report[0]
    let buttonBits = buttonByte & 0x0F
    let dpadBits = (buttonByte >> 4) & 0x0F

    return buttonBits != 0 || dpadBits != 0
  }
}
