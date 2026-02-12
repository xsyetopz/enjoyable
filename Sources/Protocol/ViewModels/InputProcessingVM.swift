import Core
import Foundation

public actor InputProcessingVM {
  private var _buttonStates: [ButtonIdentifier: Bool] = [:]
  private var _axisStates: [AxisIdentifier: Float] = [:]
  private var _triggerStates: [TriggerIdentifier: Float] = [:]
  private var _dpadStates: [Int: (DPadDirection, DPadDirection)] = [:]
  private var _hatSwitchStates: [Int: HatSwitchAngle] = [:]
  private var _stickButtonStates: [ButtonIdentifier: Bool] = [:]
  private var _lastEventTimestamp: UInt64 = 0
  private let _deviceID: USBDeviceID
  private var _dirtyFlags: DirtyFlags
  private let _config: InputProcessingConfig
  private var _statistics: ParserStatistics

  public init(deviceID: USBDeviceID, config: InputProcessingConfig = .default) {
    self._deviceID = deviceID
    self._config = config
    self._dirtyFlags = DirtyFlags()
    self._statistics = ParserStatistics(parserType: .unknown)
    Task {
      await _initializeDefaultStates()
    }
  }

  private func _initializeDefaultStates() {
    for button in ButtonIdentifier.allCases {
      _buttonStates[button] = false
    }
    for axis in AxisIdentifier.allCases {
      _axisStates[axis] = 0.0
    }
    for trigger in TriggerIdentifier.allCases {
      _triggerStates[trigger] = 0.0
    }
    _dpadStates[0] = (.neutral, .neutral)
    _hatSwitchStates[0] = .neutral
    for stickButton in [ButtonIdentifier.leftStick, ButtonIdentifier.rightStick] {
      _stickButtonStates[stickButton] = false
    }
  }

  public func getButtonState(_ button: ButtonIdentifier) -> Bool {
    _buttonStates[button] ?? false
  }

  public func getAxisState(_ axis: AxisIdentifier) -> Float {
    _axisStates[axis] ?? 0.0
  }

  public func getTriggerState(_ trigger: TriggerIdentifier) -> Float {
    _triggerStates[trigger] ?? 0.0
  }

  public func getDPadState(dpadID: Int) -> (DPadDirection, DPadDirection) {
    _dpadStates[dpadID] ?? (.neutral, .neutral)
  }

  public func getHatSwitchState(hatID: Int) -> HatSwitchAngle {
    _hatSwitchStates[hatID] ?? .neutral
  }

  public func getStickButtonState(_ button: ButtonIdentifier) -> Bool {
    _stickButtonStates[button] ?? false
  }

  public func updateButton(_ button: ButtonIdentifier, pressed: Bool, timestamp: UInt64) {
    let previousState = _buttonStates[button] ?? false
    guard previousState != pressed else { return }
    _buttonStates[button] = pressed
    _lastEventTimestamp = timestamp
    _dirtyFlags.setButtonDirty(button)
  }

  public func updateAxis(_ axis: AxisIdentifier, value: Float, rawValue: Int16, timestamp: UInt64) {
    let previousValue = _axisStates[axis] ?? 0.0
    guard abs(previousValue - value) >= 0.001 else { return }
    _axisStates[axis] = value
    _lastEventTimestamp = timestamp
    _dirtyFlags.setAxisDirty(axis)
    _updateStickButtonStates()
  }

  public func updateTrigger(
    _ trigger: TriggerIdentifier,
    value: Float,
    rawValue: UInt8,
    timestamp: UInt64
  ) {
    let previousValue = _triggerStates[trigger] ?? 0.0
    guard abs(previousValue - value) >= 0.001 else { return }
    _triggerStates[trigger] = value
    _lastEventTimestamp = timestamp
    _dirtyFlags.setTriggerDirty(trigger)
  }

  public func updateDPad(
    dpadID: Int,
    horizontal: DPadDirection,
    vertical: DPadDirection,
    timestamp: UInt64
  ) {
    let previousState = _dpadStates[dpadID] ?? (.neutral, .neutral)
    guard previousState != (horizontal, vertical) else { return }
    _dpadStates[dpadID] = (horizontal, vertical)
    _lastEventTimestamp = timestamp
    _dirtyFlags.setDPadDirty(dpadID)
  }

  public func updateHatSwitch(hatID: Int, angle: HatSwitchAngle, timestamp: UInt64) {
    let previousAngle = _hatSwitchStates[hatID] ?? .neutral
    guard previousAngle != angle else { return }
    _hatSwitchStates[hatID] = angle
    _lastEventTimestamp = timestamp
    _dirtyFlags.setHatSwitchDirty(hatID)
  }

  private func _updateStickButtonStates() {
    let leftX = abs(_axisStates[.leftStickX] ?? 0.0)
    let leftY = abs(_axisStates[.leftStickY] ?? 0.0)
    let rightX = abs(_axisStates[.rightStickX] ?? 0.0)
    let rightY = abs(_axisStates[.rightStickY] ?? 0.0)
    let leftPressed = leftX >= _config.stickButtonThreshold || leftY >= _config.stickButtonThreshold
    let rightPressed =
      rightX >= _config.stickButtonThreshold || rightY >= _config.stickButtonThreshold
    guard _stickButtonStates[.leftStick] != leftPressed else { return }
    guard _stickButtonStates[.rightStick] != rightPressed else { return }
    _stickButtonStates[.leftStick] = leftPressed
    _stickButtonStates[.rightStick] = rightPressed
    if leftPressed { _dirtyFlags.setButtonDirty(.leftStick) }
    if rightPressed { _dirtyFlags.setButtonDirty(.rightStick) }
  }

  public func getChangedEvents() -> [InputEvent] {
    var events: [InputEvent] = []
    let timestamp = _lastEventTimestamp

    for button in ButtonIdentifier.allCases where _dirtyFlags.isButtonDirty(button) {
      let isPressed = _buttonStates[button] ?? false
      events.append(
        isPressed
          ? .buttonPress(ButtonEvent(buttonID: button, isPressed: isPressed, timestamp: timestamp))
          : .buttonRelease(
            ButtonEvent(buttonID: button, isPressed: isPressed, timestamp: timestamp)
          )
      )
    }

    for axis in AxisIdentifier.allCases where _dirtyFlags.isAxisDirty(axis) {
      let value = _axisStates[axis] ?? 0.0
      let rawValue = Int16(value * 32767.0)
      events.append(
        .axisMove(AxisEvent(axisID: axis, value: value, rawValue: rawValue, timestamp: timestamp))
      )
    }

    for trigger in TriggerIdentifier.allCases where _dirtyFlags.isTriggerDirty(trigger) {
      let value = _triggerStates[trigger] ?? 0.0
      let rawValue = UInt8(value * 255.0)
      let isPressed = value >= _config.triggerThreshold
      events.append(
        .triggerMove(
          TriggerEvent(
            triggerID: trigger,
            value: value,
            rawValue: rawValue,
            isPressed: isPressed,
            timestamp: timestamp
          )
        )
      )
    }

    for dpadID in _dpadStates.keys where _dirtyFlags.isDPadDirty(dpadID) {
      let state = _dpadStates[dpadID] ?? (.neutral, .neutral)
      events.append(
        .dpadMove(
          DPadEvent(dpadID: dpadID, horizontal: state.0, vertical: state.1, timestamp: timestamp)
        )
      )
    }

    for hatID in _hatSwitchStates.keys where _dirtyFlags.isHatSwitchDirty(hatID) {
      let angle = _hatSwitchStates[hatID] ?? .neutral
      events.append(.hatSwitch(HatSwitchEvent(hatID: hatID, angle: angle, timestamp: timestamp)))
    }

    _dirtyFlags.clearAll()
    return events
  }

  public func hasChanges() -> Bool {
    !_dirtyFlags.isEmpty
  }

  public func reset() {
    Task {
      await _initializeDefaultStates()
    }
    _dirtyFlags.clearAll()
  }

  public func getDeviceID() -> USBDeviceID {
    _deviceID
  }

  public func getLastTimestamp() -> UInt64 {
    _lastEventTimestamp
  }

  public func getSnapshot() -> InputStateSnapshot {
    InputStateSnapshot(
      buttonStates: _buttonStates,
      axisStates: _axisStates,
      triggerStates: _triggerStates,
      dpadStates: _dpadStates,
      hatSwitchStates: _hatSwitchStates,
      timestamp: _lastEventTimestamp
    )
  }

  public func getStatistics() -> ParserStatistics {
    _statistics
  }

  public func recordParse(events: [InputEvent], parseTime: TimeInterval) {
    _statistics.recordParse(events: events, parseTime: parseTime)
  }

  public func recordError() {
    _statistics.recordError()
  }
}

extension InputProcessingVM {
  public struct DirtyFlags: Sendable {
    private var _buttonMask: UInt64 = 0
    private var _axisMask: UInt64 = 0
    private var _triggerMask: UInt64 = 0
    private var _dpadMask: UInt64 = 0
    private var _hatSwitchMask: UInt64 = 0

    public init() {}

    public mutating func setButtonDirty(_ button: ButtonIdentifier) {
      let index = _buttonIndex(button)
      _buttonMask |= (1 << index)
    }

    public mutating func setAxisDirty(_ axis: AxisIdentifier) {
      let index = _axisIndex(axis)
      _axisMask |= (1 << index)
    }

    public mutating func setTriggerDirty(_ trigger: TriggerIdentifier) {
      let index = _triggerIndex(trigger)
      _triggerMask |= (1 << index)
    }

    public mutating func setDPadDirty(_ dpadID: Int) {
      _dpadMask |= (1 << min(dpadID, 63))
    }

    public mutating func setHatSwitchDirty(_ hatID: Int) {
      _hatSwitchMask |= (1 << min(hatID, 63))
    }

    public mutating func clearAll() {
      _buttonMask = 0
      _axisMask = 0
      _triggerMask = 0
      _dpadMask = 0
      _hatSwitchMask = 0
    }

    public func isButtonDirty(_ button: ButtonIdentifier) -> Bool {
      let index = _buttonIndex(button)
      return (_buttonMask >> index) & 1 == 1
    }

    public func isAxisDirty(_ axis: AxisIdentifier) -> Bool {
      let index = _axisIndex(axis)
      return (_axisMask >> index) & 1 == 1
    }

    public func isTriggerDirty(_ trigger: TriggerIdentifier) -> Bool {
      let index = _triggerIndex(trigger)
      return (_triggerMask >> index) & 1 == 1
    }

    public func isDPadDirty(_ dpadID: Int) -> Bool {
      guard dpadID >= 0 && dpadID < 64 else { return false }
      return (_dpadMask >> dpadID) & 1 == 1
    }

    public func isHatSwitchDirty(_ hatID: Int) -> Bool {
      guard hatID >= 0 && hatID < 64 else { return false }
      return (_hatSwitchMask >> hatID) & 1 == 1
    }

    public var isEmpty: Bool {
      _buttonMask == 0 && _axisMask == 0 && _triggerMask == 0 && _dpadMask == 0
        && _hatSwitchMask == 0
    }

    private func _buttonIndex(_ button: ButtonIdentifier) -> Int {
      switch button {
      case .a: return 0
      case .b: return 1
      case .x: return 2
      case .y: return 3
      case .leftShoulder: return 4
      case .rightShoulder: return 5
      case .leftTrigger: return 6
      case .rightTrigger: return 7
      case .leftStick: return 8
      case .rightStick: return 9
      case .start: return 10
      case .back: return 11
      case .guide: return 12
      case .leftStickUp: return 13
      case .leftStickDown: return 14
      case .leftStickLeft: return 15
      case .leftStickRight: return 16
      case .rightStickUp: return 17
      case .rightStickDown: return 18
      case .rightStickLeft: return 19
      case .rightStickRight: return 20
      case .dpadUp: return 21
      case .dpadDown: return 22
      case .dpadLeft: return 23
      case .dpadRight: return 24
      case .custom(let id): return 25 + Int(id)
      }
    }

    private func _axisIndex(_ axis: AxisIdentifier) -> Int {
      switch axis {
      case .leftStickX: return 0
      case .leftStickY: return 1
      case .rightStickX: return 2
      case .rightStickY: return 3
      case .leftTrigger: return 4
      case .rightTrigger: return 5
      case .custom(let id): return 6 + Int(id)
      }
    }

    private func _triggerIndex(_ trigger: TriggerIdentifier) -> Int {
      switch trigger {
      case .left: return 0
      case .right: return 1
      case .custom(let id): return 2 + Int(id)
      }
    }
  }
}
