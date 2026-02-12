import Core
import Foundation

public enum ParserHelpers {
  public static func dataToBytes(_ data: Data) -> [UInt8] {
    [UInt8](data)
  }

  public static func bytesToData(_ bytes: [UInt8]) -> Data {
    Data(bytes)
  }

  public static func extractInt16LE(_ bytes: [UInt8], at index: Int) -> Int16 {
    guard index + 1 < bytes.count else { return 0 }
    return Int16(bitPattern: UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8))
  }

  public static func extractUInt16LE(_ bytes: [UInt8], at index: Int) -> UInt16 {
    guard index + 1 < bytes.count else { return 0 }
    return UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
  }

  public static func extractInt8(_ byte: UInt8) -> Int8 {
    Int8(bitPattern: byte)
  }

  public static func extractBits(from byte: UInt8, startBit: Int, bitCount: Int) -> UInt8 {
    let mask = UInt8(((1 << bitCount) - 1) << startBit)
    return UInt8((byte & mask) >> startBit)
  }

  public static func isBitSet(_ byte: UInt8, bit: Int) -> Bool {
    (byte >> bit) & 1 == 1
  }

  public static func setBit(_ byte: UInt8, bit: Int) -> UInt8 {
    byte | (1 << bit)
  }

  public static func clearBit(_ byte: UInt8, bit: Int) -> UInt8 {
    byte & ~(1 << bit)
  }

  public static func normalizeSigned16(_ value: Int16) -> Float {
    guard value != 0 else { return 0.0 }
    return Float(value) / 32767.0
  }

  public static func normalizeUnsigned8(_ value: UInt8) -> Float {
    Float(value) / 255.0
  }

  public static func normalizeSigned8(_ value: Int8) -> Float {
    guard value != 0 else { return 0.0 }
    return Float(value) / 127.0
  }

  public static func applyDeadzone(_ value: Float, deadzone: Float) -> Float {
    let absValue = abs(value)
    guard absValue > deadzone else { return 0.0 }
    let sign: Float = value >= 0 ? 1.0 : -1.0
    return sign * ((absValue - deadzone) / (1.0 - deadzone))
  }

  public static func clamp(_ value: Float, min minValue: Float, max maxValue: Float) -> Float {
    Swift.min(maxValue, Swift.max(value, minValue))
  }

  public static func generateTimestamp() -> UInt64 {
    UInt64(Date().timeIntervalSince1970 * 1_000_000)
  }

  public static func generateTimestamp(multiplier: UInt64) -> UInt64 {
    UInt64(Date().timeIntervalSince1970 * Double(multiplier))
  }

  public static func validateReportSize(_ report: Data, minimum: Int) -> Bool {
    report.count >= minimum
  }

  public static func validateReportSize(_ report: Data, maximum: Int) -> Bool {
    report.count <= maximum
  }

  public static func validateReportSize(_ report: Data, minimum: Int, maximum: Int) -> Bool {
    report.count >= minimum && report.count <= maximum
  }

  public static func dpadFromHorizontal(_ value: Int8) -> DPadDirection {
    switch value {
    case -1: return .left
    case 1: return .right
    default: return .neutral
    }
  }

  public static func dpadFromVertical(_ value: Int8) -> DPadDirection {
    switch value {
    case -1: return .down
    case 1: return .up
    default: return .neutral
    }
  }

  public static func dpadFromGeneric(_ value: UInt8) -> DPadDirection {
    switch value {
    case 1: return .right
    case 2: return .down
    case 3: return .left
    default: return .neutral
    }
  }

  public static func combineDPad(
    horizontal: DPadDirection,
    vertical: DPadDirection
  ) -> (DPadDirection, DPadDirection) {
    (horizontal, vertical)
  }

  public static func stateChanged(previous: Bool, current: Bool) -> Bool {
    previous != current
  }

  public static func valueChanged(previous: Float, current: Float, threshold: Float = 0.001) -> Bool
  {
    abs(previous - current) >= threshold
  }

  public static func directionChanged(previous: DPadDirection, current: DPadDirection) -> Bool {
    previous != current
  }

  public static func filterButtonEvents(_ events: [InputEvent]) -> [InputEvent] {
    events.filter { $0.isButtonEvent }
  }

  public static func filterAxisEvents(_ events: [InputEvent]) -> [InputEvent] {
    events.filter { $0.isAxisEvent }
  }

  public static func groupEventsByType(_ events: [InputEvent]) -> [InputEvent: [InputEvent]] {
    var grouped: [InputEvent: [InputEvent]] = [:]
    for event in events {
      let key = _eventCategoryKey(for: event)
      grouped[key, default: []].append(event)
    }
    return grouped
  }

  private static func _eventCategoryKey(for event: InputEvent) -> InputEvent {
    switch event {
    case .buttonPress, .buttonRelease:
      return .buttonPress(ButtonEvent(buttonID: .a, isPressed: true, timestamp: 0))
    case .axisMove:
      return .axisMove(AxisEvent(axisID: .leftStickX, value: 0, rawValue: 0, timestamp: 0))
    case .triggerMove:
      return .triggerMove(
        TriggerEvent(triggerID: .left, value: 0, rawValue: 0, isPressed: false, timestamp: 0)
      )
    case .dpadMove:
      return .dpadMove(DPadEvent(dpadID: 0, horizontal: .neutral, vertical: .neutral, timestamp: 0))
    case .hatSwitch:
      return .hatSwitch(HatSwitchEvent(hatID: 0, angle: .neutral, timestamp: 0))
    }
  }

  public static func measureTime(_ block: () -> Void) -> TimeInterval {
    let startTime = CFAbsoluteTimeGetCurrent()
    block()
    return CFAbsoluteTimeGetCurrent() - startTime
  }

  public static func formatParseTime(_ time: TimeInterval) -> String {
    if time < 0.001 {
      return String(format: "%.2f μs", time * 1_000_000)
    } else if time < 0.01 {
      return String(format: "%.2f ms", time * 1000)
    } else {
      return String(format: "%.3f s", time)
    }
  }
}

public struct StateTracker<T: Equatable & Sendable>: Sendable, Equatable {
  private var _previousValue: T
  private var _currentValue: T

  public init(initialValue: T) {
    self._previousValue = initialValue
    self._currentValue = initialValue
  }

  public var current: T { _currentValue }
  public var previous: T { _previousValue }
  public var hasChanged: Bool { _previousValue != _currentValue }

  public mutating func update(_ newValue: T) {
    _previousValue = _currentValue
    _currentValue = newValue
  }

  public mutating func reset(to value: T) {
    _previousValue = value
    _currentValue = value
  }
}

public struct CircularBuffer<T> {
  private var _buffer: [T?]
  private var _head: Int
  private var _count: Int
  private let _capacity: Int
  private let _lock = NSLock()

  public init(capacity: Int) {
    self._capacity = capacity
    self._buffer = [T?](repeating: nil, count: capacity)
    self._head = 0
    self._count = 0
  }

  public mutating func push(_ value: T) {
    _lock.lock()
    defer { _lock.unlock() }

    _buffer[_head] = value
    _head = (_head + 1) % _capacity
    _count = min(_count + 1, _capacity)
  }

  public func peek(offset: Int = 0) -> T? {
    _lock.lock()
    defer { _lock.unlock() }

    guard offset < _count else { return nil }
    let index = (_head - 1 - offset + _capacity) % _capacity
    return _buffer[index]
  }

  public var isEmpty: Bool { _count == 0 }
  public var count: Int { _count }
  public var capacity: Int { _capacity }
}
